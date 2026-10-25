[← Index](../README.md) · [← Environment](03-environment.md) · Next: [Expressions →](05-expressions.md)

# 4. Variables

Every variable is an environment variable holding a string. There are no types, no declarations, and no local scope beyond what `SETLOCAL` provides.

- [Assignment](#assignment)
- [Names](#names)
- [Reading values](#reading-values)
- [Defined, undefined and empty](#defined-undefined-and-empty)
- [Scope](#scope)
- [Listing and clearing by prefix](#listing-and-clearing-by-prefix)
- [Input: SET /P](#input-set-p)
- [Capturing command output](#capturing-command-output)
- [Arrays and structures](#arrays-and-structures)
- [Indirect access (variable variables)](#indirect-access-variable-variables)
- [Pitfalls](#pitfalls)

---

## Assignment

```bat
set "name=value"          & rem standard form - quotes delimit, are not stored
set "name="               & rem delete the variable (it becomes undefined)
set name=value            & rem unquoted: trailing spaces are stored, & | < > live
set "path=%path%;C:\Tools"
set /a "count+=1"         & rem arithmetic - see Expressions
set /p "answer=Continue? " & rem prompt for input
```

| Form | Stores |
|---|---|
| `set "x=a b "` | `a b ` (trailing space kept, since inside quotes) |
| `set "x=a b" ` | `a b` (space after the closing quote ignored) |
| `set x="a b"` | `"a b"` (quotes stored) |
| `set x = 1` | variable **`x `** = ` 1` |
| `set "x=a"b"c"` | `a"b"c` — everything up to the **last** quote |

**Always use `set "name=value"`.** It neutralises trailing whitespace and protects `& | < > ^` in the value at assignment time.

## Names

- Case-insensitive: `%Path%`, `%PATH%` and `%path%` are the same variable.
- Almost any character except `=` is allowed: `my var`, `a.b`, `x-y`, `arr[1]`, `opt_?` all work (verified). Stick to `[A-Za-z0-9_.\-\[\]]`.
- Do not start names with a digit (`%1abc%` is parsed as `%1` + `abc%`).
- Do not reuse dynamic names: `CD`, `DATE`, `TIME`, `RANDOM`, `ERRORLEVEL`, `CMDCMDLINE`, `CMDEXTVERSION` — setting them hides the live value. Also avoid `PATH`, `PATHEXT`, `TEMP`, `LIB`, `INCLUDE` (MSVC toolchain uses `LIB`/`INCLUDE`).
- Convention in this repo: library-internal names start with `_` (e.g. `_r`, `_pa_spec`) to avoid colliding with the caller.

## Reading values

| Syntax | Expanded | Safe for special characters | Current inside a block |
|---|---|---|---|
| `%name%` | Before parsing (phase 1) | No | No — parse-time value |
| `!name!` | After parsing (phase 5), needs delayed expansion | Yes | Yes |
| `call echo %%name%%` | Second pass via `CALL` | No | Yes |
| `for /f "delims=" %%V in ("!name!")` | FOR variable | Yes | Yes |

See [Parsing & escaping](02-parsing-escaping.md) for the full story.

Substring, replacement, length and other string operations are covered in [Strings](13-strings.md).

## Defined, undefined and empty

There is no "empty but defined" variable: `set "x="` deletes `x`.

```bat
if defined x echo x has a value
if not defined x echo x is undefined (or was set to nothing)
if "%x%"=="" echo empty - works, but breaks if x contains quotes
```

`if defined` is the robust test: it never expands the value, so special characters and quotes cannot break it. Default values:

```bat
if not defined OUTDIR set "OUTDIR=%CD%\out"
```

## Scope

- Without `SETLOCAL`, every `set` changes the session's environment — visible to the caller and, at an interactive prompt, after the script ends.
- `SETLOCAL` starts a scope; `ENDLOCAL` (or the end of the script/subroutine) discards changes made in it. Details: [Environment → SETLOCAL](03-environment.md#setlocal--endlocal).
- **Returning values across `ENDLOCAL`**: `endlocal & set "result=%result%"` — the right-hand side is expanded before `ENDLOCAL` executes. See [Functions → returning values](10-functions.md#returning-values).

## Listing and clearing by prefix

```bat
set OPT_                   & rem prints all variables starting with OPT_ (ERRORLEVEL 1 if none)
set OPT_ >nul 2>&1 || echo no OPT_ variables

rem Clear every variable with a prefix
for /f "delims==" %%V in ('set OPT_ 2^>nul') do set "%%V="
```

The prefix match is case-insensitive and literal (no wildcards).

## Input: SET /P

```bat
set "answer="
set /p "answer=Proceed (y/n)? "
if /i "%answer%"=="y" goto :Proceed

set /p firstLine=<"file.txt"          & rem first line of a file (max 1023 chars)
<nul set /p "=no newline after this"  & rem print without newline
```

- If the user just presses Enter (or input is empty/`NUL`), the variable is **left unchanged** and `ERRORLEVEL` becomes 1 — always clear it first.
- Leading whitespace in the prompt text is stripped (Vista+).
- For a single keypress with a timeout, use `CHOICE` ([Tools](14-tools.md#choice)).

## Capturing command output

There is no `$(...)`. Use `FOR /F`:

```bat
rem Last line wins (or first line with a GOTO/IF guard)
for /f "delims=" %%L in ('hostname') do set "HOST=%%L"

rem First line only
set "FIRST="
for /f "delims=" %%L in ('dir /b /o-d *.log 2^>nul') do if not defined FIRST set "FIRST=%%L"

rem A specific token
for /f "tokens=2 delims=:." %%A in ('chcp') do set /a "CP=%%A"

rem Via a temp file, when the command is awkward to quote
somecommand >"%TEMP%\out.txt" 2>&1
set /p RESULT=<"%TEMP%\out.txt"
```

See [Loops → FOR /F](08-loops.md#for-f-parse-text-files-and-command-output).

## Arrays and structures

There are no arrays, but names can contain `[`, `]` and `.`, so you can emulate them:

```bat
setlocal EnableDelayedExpansion
set "n=0"
for %%F in (*.txt) do (
    set "file[!n!]=%%F"
    set /a n+=1
)
set /a "last=n-1"
for /l %%i in (0,1,%last%) do echo !file[%%i]!
```

`FOR /L` bounds are plain numbers, not expressions — compute them with `SET /A` first.

Structures:

```bat
set "user.name=Ada"
set "user.role=admin"
set user.                                 & rem list all fields
for /f "tokens=1* delims==" %%K in ('set user.') do echo %%K -^> %%L
```

Associative lookup is free: `set "port[http]=80"` → `!port[%proto%]!`.

## Indirect access (variable variables)

```bat
set "varName=COMPUTERNAME"

setlocal EnableDelayedExpansion
echo !%varName%!                        & rem phase 1 gives !COMPUTERNAME!, phase 5 its value
endlocal

call echo %%%varName%%%                 & rem without delayed expansion
call set "value=%%%varName%%%"

for /f "delims=" %%N in ("%varName%") do set "value=!%%N!"   & rem inside loops (delayed on)
```

Assigning to a computed name is easy: `set "%varName%=new value"`.

## Pitfalls

- `set x = 1` creates `x ` (with a space).
- Unquoted `set` keeps trailing spaces from the line.
- `SET /P` does not clear the variable when input is empty.
- `%x%` inside a parenthesised block is the value from before the block.
- Variables named like dynamic variables (`ERRORLEVEL`, `CD`, …) hide them.
- `set "x="` deletes; there is no defined-but-empty state.
- Substring/replace on undefined variables corrupts the line ([details](02-parsing-escaping.md#percent-expansion)).

---

See also: [Expressions](05-expressions.md) · [Strings](13-strings.md) · [Functions](10-functions.md)
