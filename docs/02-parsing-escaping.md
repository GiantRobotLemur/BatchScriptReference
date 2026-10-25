[← Index](../README.md) · [← Syntax](01-syntax.md) · Next: [Environment →](03-environment.md)

# 2. Parsing, expansion & escaping

Almost every confusing batch behaviour follows from *when* `cmd.exe` expands things. Learn the phases once and the rest is mechanical.

- [Parser phases](#parser-phases)
- [Percent expansion](#percent-expansion)
- [Delayed expansion](#delayed-expansion)
- [Escaping reference](#escaping-reference)
- [Quoting rules](#quoting-rules)
- [Escaping inside FOR /F commands and pipes](#escaping-inside-for-f-commands-and-pipes)
- [CALL: a second round of expansion](#call-a-second-round-of-expansion)
- [Recipes](#recipes)
- [Pitfalls](#pitfalls)

---

## Parser phases

Simplified from the authoritative community reverse-engineering (dbenham/jeb on Stack Overflow, *"How does the Windows Command Interpreter (CMD.EXE) parse scripts?"*):

| Phase | What happens | Consequence |
|---|---|---|
| **1. Percent expansion** | `%var%`, `%1`, `%*`, `%~f1`, `%%` → `%`. Done on the **whole line or whole parenthesised block** at once. | Values inside a block are frozen at parse time. Comments are expanded too. |
| **2. Special characters** | Tokenise; track `"` quote state; process `^` escapes; recognise `& && \| \|\| < > ( )`; identify the command; recognise labels. | Special characters *produced by phase 1* are live here (hence injection problems). |
| 3. Echo | If echo is on, the parsed command is echoed. | |
| **4. FOR variables** | `%%A` is replaced on each loop iteration. | Happens after phase 2, so special characters in FOR values are safe. |
| **5. Delayed expansion** | If enabled and the command contains `!`: `!var!` expanded; `^` is processed again in this phase. | Values are inserted **after** tokenising — safe for `& \| < > ( ) "`. |
| 6. CALL | `CALL` re-runs phase 1 (and part of 2) on the command, doubling any carets first. | Gives a second percent expansion: `call echo %%var%%`. |
| 7. Execute | | |

The two rules that matter in practice:

1. **`%var%` is expanded before the line (or block) is parsed** — so its contents can break the syntax, and inside a block it is stale.
2. **`!var!` and `%%A` are expanded after parsing** — so their contents can never break the syntax, and `!var!` is always current.

## Percent expansion

```bat
set "name=World"
echo Hello %name%            & rem Hello World
echo 100%%                   & rem 100%   (%% is a literal % in a batch file)
echo %undefined%             & rem (nothing) in a batch file
```

- In a **batch file**, an undefined `%var%` expands to nothing. At the **interactive prompt** it is left as the literal text `%var%`.
- Substring/replace on an **undefined** variable is dangerous: `%var:~0,1%` drops `%var:` but leaves the closing `%`, which then pairs with the *next* `%` on the line and swallows text between them. Always test `if defined var` **on a previous line** (or `goto` past the code) before applying `:~` or `:=` to a variable that may be undefined.

```bat
rem BROKEN when _ext is undefined - the IF on the same line does not help,
rem because expansion happens before IF runs:
if defined _ext if not "%_ext:~0,1%"=="." set "_ext=.%_ext%"

rem CORRECT:
if not defined _ext goto :skip
if not "%_ext:~0,1%"=="." set "_ext=.%_ext%"
:skip
```

## Delayed expansion

```bat
setlocal EnableDelayedExpansion
set "count=0"
for %%F in (*.txt) do (
    set /a count+=1
    echo !count!: %%F          & rem !count! is current; %count% would be 0
)
echo Total: %count%            & rem fine outside the block
endlocal
```

Ways to enable it:

| Method | Scope |
|---|---|
| `setlocal EnableDelayedExpansion` | Until matching `endlocal` / end of script or subroutine. |
| `cmd /v:on /c "..."` | That `cmd` instance. |
| Registry `HKCU\Software\Microsoft\Command Processor\DelayedExpansion` = 1 | Every `cmd.exe` — never rely on it, never assume it is off. |

Costs of enabling it:

- **`!` in data is destroyed** whenever a value passes through phase 5 — e.g. `set "line=%%L"` drops `!` from file contents, and `echo Hello!` prints `Hello`. Carets also get consumed in lines containing `!`.
- Literal `!` must be escaped (`^!` inside quotes, `^^!` outside).

**The toggling pattern** — the standard way to process arbitrary text safely:

```bat
setlocal DisableDelayedExpansion
for /f "usebackq delims=" %%L in ("%FILE%") do (
    set "line=%%L"                  & rem assign with delayed OFF: ! preserved
    setlocal EnableDelayedExpansion
    echo(!line:foo=bar!             & rem work on it with delayed ON
    endlocal                        & rem discard - changes do not survive
)
```

Results computed inside the inner `setlocal` must be tunnelled out — see [Functions → returning values](10-functions.md#returning-values).

> `endlocal & set "x=%val%"` works because `%val%` is expanded (phase 1) before `endlocal` runs. If the **caller** has delayed expansion enabled, any `!` in `val` is then stripped by phase 5 (verified). Values containing `"` break the quoting entirely.

## Escaping reference

| Character | Outside quotes | Inside `"..."` | When delayed expansion is ON |
|---|---|---|---|
| `%` | `%%` (batch file) | `%%` | `%%` |
| `^ & \| < > ( )` | `^^ ^& ^\| ^< ^> ^( ^)` | literal | `^&` etc. still work, but in a line containing `!` a literal `^` needs `^^^^` (`^^` inside quotes) |
| `!` | literal | literal | `^^!` outside quotes, `^!` inside |
| `"` | `^"` (literal, does not toggle quote state) | cannot be escaped — close the quotes, `^"`, reopen | same |
| `=` `,` `;` space | quote the argument | literal | — |
| `)` inside a block | `^)` | literal | — |

```bat
echo Fish ^& Chips ^> Pie         & rem Fish & Chips > Pie
echo "Fish & Chips > Pie"         & rem quotes are printed too
set "msg=Fish & Chips"            & rem quotes protect, and are not stored
echo(%msg%                        & rem BROKEN: & is live after expansion
setlocal EnableDelayedExpansion
echo(!msg!                        & rem safe: delayed expansion after parsing
```

**Prefer delayed expansion or FOR variables over escaping** when printing or passing data you do not control.

## Quoting rules

- `"` toggles quote state. Inside quotes `& | < > ( ) ^` are literal and spaces do not split arguments.
- Quotes are **kept** as part of arguments; `%~1` removes one surrounding pair.
- `set "var=value"`: everything between the first `"` and the **last** `"` on the line is the assignment; the quotes are not stored. `set var="value"` stores the quotes.
- A `"` inside data cannot be escaped within a quoted region. Data containing `"` is the hardest case in batch; delayed expansion is the only fully safe way to handle it.
- Programs (not `cmd`) parse their own command line, usually with the C runtime rules where `\"` is an escaped quote. So `reg add ... /d "C:\dir\"` passes `C:\dir"` plus the rest of the line — **double a trailing backslash: `"C:\dir\\"`**. The same applies to `robocopy "C:\dir\"`; write `"C:\dir\."` or drop the trailing backslash.

## Escaping inside FOR /F commands and pipes

The command inside `for /f ... in ('...')` is parsed once by your script and again by the child `cmd.exe` that runs it, so operators must be escaped for the first pass:

```bat
for /f "delims=" %%L in ('dir /b *.log 2^>nul ^| findstr /v /i "old"') do echo %%L
for /f "delims=" %%L in ('"command with spaces.exe" ^| sort') do echo %%L
```

Alternatively quote the whole command so the first pass sees a quoted string (works because FOR strips the outer quotes):

```bat
for /f "delims=" %%L in ('"dir /b *.log 2>nul | findstr /v /i "old""') do echo %%L
```

Each side of a pipe runs in a new `cmd /S /D /c` instance, which re-parses it: escapes may need doubling (`^^^&`), and delayed expansion is **off** there unless you start it with `cmd /v:on`. See [Redirection → pipes](12-redirection-errors.md#pipes).

## CALL: a second round of expansion

`CALL` repeats percent expansion, which gives indirect variable access without delayed expansion:

```bat
set "i=3"
set "arr[3]=three"
call echo %%arr[%i%]%%           & rem pass 1: %arr[3]%   pass 2: three
call set "val=%%arr[%i%]%%"      & rem val=three
set "fmt=%%SystemRoot%%\x"       & rem literal %SystemRoot%\x
call set "path2=%fmt%"           & rem C:\Windows\x - expands a stored %VAR%
```

CALL side effects:

- **Carets are doubled** before the second parse. Unquoted ones are consumed again, so `call echo ^^` prints `^`, but quoted ones survive doubled: `call echo "^"` prints `"^^"`.
- An unquoted **`/?` anywhere in the arguments makes CALL print its own help** instead of calling the target — `call script.cmd a /? b` never reaches the script. Quote it (`"/?"`) or test for `/?` before calling.
- `CALL` is slow (it re-reads the file to find labels). Avoid it in tight loops.

## Recipes

**Print a variable whatever it contains:**

```bat
setlocal EnableDelayedExpansion
echo(!var!
endlocal
```

**Read a file line by line, preserving `!` and `^`, keeping empty lines** — see [Loops → FOR /F](08-loops.md#reading-files-safely).

**Pass data containing special characters as arguments:** keep the command literal and put only the *data* in delayed-expansion variables.

```bat
set "pattern=a & b"
setlocal EnableDelayedExpansion
findstr /c:"!pattern!" file.txt       & rem safe: expanded after parsing
endlocal
```

> Do **not** store a whole command in a variable and run it as `!cmdline!`: the command token is not re-split after delayed expansion, so it fails (verified). `%cmdline%` works but re-parses any operators in the data; escape them, or keep the data separate as above.

## Pitfalls

- `%var%` inside a block is the value from **before** the block started.
- Substring/replace on undefined variables corrupts the line.
- Delayed expansion destroys `!` in data and consumes carets in lines with `!`.
- `/?` in CALL arguments, `ECHO`, `REM` — always triggers help.
- `\"` inside arguments to external programs (REG, ROBOCOPY, most EXEs).

---

See also: [Variables](04-variables.md) · [Strings](13-strings.md) · [Pitfalls checklist](15-pitfalls.md)
