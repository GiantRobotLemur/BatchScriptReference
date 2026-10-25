[← Index](../README.md) · [← Condition tests](07-condition-tests.md) · Next: [Branching →](09-branching.md)

# 8. Loops

`FOR` in its five forms, plus `GOTO` loops for everything `FOR` can't express.

- [FOR basics](#for-basics)
- [FOR: lists and file wildcards](#for-lists-and-file-wildcards)
- [FOR /D: directories](#for-d-directories)
- [FOR /R: recursive](#for-r-recursive)
- [FOR /L: counting](#for-l-counting)
- [FOR /F: parse text, files and command output](#for-f-parse-text-files-and-command-output)
- [FOR variable modifiers](#for-variable-modifiers)
- [Variables inside loop bodies](#variables-inside-loop-bodies)
- [Break and continue](#break-and-continue)
- [GOTO loops: while, until, do-while](#goto-loops-while-until-do-while)
- [Recipes](#recipes)
- [Pitfalls](#pitfalls)

---

## FOR basics

```
FOR %%V IN (set) DO command
FOR /D %%V IN (set) DO command
FOR /R [[drive:]path] %%V IN (set) DO command
FOR /L %%V IN (start,step,end) DO command
FOR /F ["options"] %%V IN (source) DO command
```

- In a **batch file** the variable is `%%V`; at the **prompt** it is `%V`.
- One letter (other characters work but are fragile). **Case-sensitive**: `%%a` and `%%A` are different variables (verified). Use upper case for outer loops and keep letters distinct in nested loops — the inner loop can see the outer variable.
- FOR variables are substituted after parsing ([phase 4](02-parsing-escaping.md#parser-phases)), so their values can't break the syntax — but they are *not* safe from delayed expansion: with it enabled, `!` in a value is consumed.
- `DO` takes one command — use `( … )` for several.
- FOR variables exist only inside the body. In a `CALL`ed subroutine `%%F` is plain text — except, oddly, inside another `FOR` body there, where the caller's active `%%F` is visible (verified). Don't rely on either: pass values as arguments, `do call :Process "%%F"`.

## FOR: lists and file wildcards

```bat
for %%C in (red green "light blue") do echo %%~C
for %%F in (*.txt *.log) do echo %%F
for %%F in ("C:\Data\*.csv") do echo %%~nxF       & rem quote paths with spaces
for %%P in ("%PATH:;=" "%") do echo %%~P          & rem split PATH on ;
for %%A in (%*) do echo arg: %%~A                  & rem iterate arguments (see caveat)
```

- Items are separated by space, tab, `,`, `;` and `=` (verified: `(a,b;c=d)` gives four items). Quote items containing these.
- Items **with `*` or `?`** are file patterns: they expand to matching **files** (not directories). **Hidden and system files are skipped** (verified). Non-matching patterns produce nothing.
- Items **without** wildcards are returned as-is, whether or not a file exists.
- Iterating `%*` this way breaks if an argument contains `*` or `?` — use a `SHIFT` loop instead ([Arguments](11-arguments.md#iterating-over-arguments)).

## FOR /D: directories

```bat
for /d %%D in ("C:\Projects\*") do echo %%~nxD
for /d %%D in (build* out*) do rd /s /q "%%D"
```

Matches directories only, non-recursive; **hidden directories are skipped** (verified). Without wildcards behaves like plain `FOR`.

## FOR /R: recursive

```bat
for /r "C:\src" %%F in (*.cs *.csproj) do echo %%F
for /r %%F in (*.tmp) do del "%%F"                 & rem from the current directory
for /r "C:\src" %%D in (.) do echo %%~fD           & rem every directory, including the root
```

- The root path follows `/R`, quoted or not. It is parsed early: `for /r "%ROOT%"` works, but a FOR variable (`for /r %%R …`) or `!var!` as the root is a syntax error (verified). Inside loops, `pushd` into the directory first, or use `dir /s /b`.
- Walks **all** sub-directories (including hidden ones), but wildcard matching in each directory skips hidden/system **files** (verified).
- With a set item **without wildcards**, FOR /R yields `dir\item` for **every** directory whether or not that file exists (verified with `x.dat`). `(.)` is the idiom for "every directory".
- Order is not guaranteed sorted. For sorted, filtered or hidden-inclusive listings use `for /f ... in ('dir /s /b /a-d ...')`.

## FOR /L: counting

```bat
for /l %%i in (1,1,10) do echo %%i             & rem 1..10
for /l %%i in (10,-2,0) do echo %%i            & rem 10 8 6 4 2 0
for /l %%i in (1,1,0) do echo never            & rem no iterations
for /l %%i in (1,0,1) do echo forever          & rem step 0: infinite loop
```

- Bounds are evaluated once, as plain 32-bit integers (no expressions — compute with `SET /A` first).
- **`GOTO` out of a `FOR /L` doesn't stop it**: the loop keeps counting silently to the end (3,000,000 iterations took ~3.6 s after a `GOTO` on iteration 2, verified). For a long or open-ended loop use a `GOTO` loop instead.

## FOR /F: parse text, files and command output

```
FOR /F ["options"] %%V IN (filenameset) DO ...
FOR /F ["options"] %%V IN ("literal string") DO ...
FOR /F ["options"] %%V IN ('command') DO ...
with usebackq:
FOR /F "usebackq options" %%V IN ("file name with spaces") DO ...
FOR /F "usebackq options" %%V IN ('literal string') DO ...
FOR /F "usebackq options" %%V IN (`command`) DO ...
```

### Options

| Option | Default | Meaning |
|---|---|---|
| `delims=xyz` | space and tab | Delimiter characters. `delims=` (nothing) = whole line in one token. Must be **last** if it includes a space. |
| `tokens=n,m-p,*` | `1` | Which tokens to assign. Variables are allocated alphabetically from the one you name: `tokens=1,3*` with `%%a` gives `%%a %%b %%c`. `*` = rest of the line. Max 31 tokens. |
| `skip=n` | 0 | Skip the first n lines. `skip=0` is a **syntax error** (verified) — omit the option instead. |
| `eol=c` | `;` | Lines **starting** with `c` are ignored. One character only. |
| `usebackq` | off | Switch to the quoting scheme above. |

Rules:

- **Empty lines are always skipped** (no option changes this).
- Lines starting with `;` are skipped by default (`eol=;`) — a real trap for data files.
- Consecutive delimiters count as one; leading delimiters are skipped. So `a,,c` with `delims=,` gives tokens `a`, `c`, not an empty middle token.
- Commands run in a child `cmd /c`: escape `| > & <` with `^` inside `'...'`, or wrap the whole command in an extra pair of quotes ([details](02-parsing-escaping.md#escaping-inside-for-f-commands-and-pipes)). All output is captured **before** the first iteration runs.
- Reading a file processes it as ANSI/OEM; UTF-16 files need `type file | ...` (TYPE converts UTF-16 with BOM) — `for /f "delims=" %%L in ('type "file.txt"')`.

### Turning off eol and delims together

`eol=` can't be set to "nothing" in a quoted options string, and the quotes stop `delims=` from being last. This unquoted form, with every special character escaped, sets no delimiters and no eol character (verified: a line starting with `;` is kept):

```bat
for /f usebackq^ delims^=^ eol^= %%L in ("%FILE%") do echo(%%L
```

Or use an eol character that can't occur, e.g. `eol=:` for file names, or a line-number prefix (next section).

### Reading files safely

To keep **empty lines**, lines starting with `;`, and `!`/`^` characters intact, number the lines with `FINDSTR /N` and strip the prefix:

```bat
setlocal DisableDelayedExpansion
for /f "delims=" %%L in ('findstr /n "^" "%FILE%"') do (
    set "line=%%L"
    setlocal EnableDelayedExpansion
    set "line=!line:*:=!"                 & rem remove "123:" prefix
    echo(!line!
    endlocal
)
```

Limits: lines longer than 8191 characters are truncated; changes to variables inside the inner `setlocal` are lost (tunnel them out if needed). `FIND /N /V ""` works similarly with `[123]` prefixes.

### Parsing examples

```bat
rem key=value config file, ignoring # comments and blank lines
for /f "usebackq eol=# tokens=1,* delims==" %%K in ("%CONF%") do set "CFG_%%K=%%L"

rem CSV: third column (empty fields collapse - see Rules)
for /f "usebackq tokens=3 delims=," %%C in ("data.csv") do echo %%C

rem Command output: last line wins
for /f "delims=" %%V in ('ver') do set "VER=%%V"

rem Tokens 2-4 of a string
for /f "tokens=2-4 delims=-" %%a in ("w-x-y-z-q") do echo %%a %%b %%c   & rem x y z

rem Split at the first =, keep the rest intact
for /f "tokens=1,* delims==" %%k in ("key=val=ue") do echo %%k / %%l   & rem key / val=ue
```

## FOR variable modifiers

The same modifiers as [argument modifiers](11-arguments.md#parameter-modifiers), applied to FOR variables:

| Modifier | Gives |
|---|---|
| `%%~I` | value without surrounding quotes |
| `%%~fI` | full path |
| `%%~dI` / `%%~pI` | drive / path (with trailing `\`) |
| `%%~nI` / `%%~xI` | name / extension (with `.`) |
| `%%~sI` | short 8.3 path |
| `%%~aI` | attributes, e.g. `d----------` or `--a--------` (empty if missing) |
| `%%~tI` | last-modified date/time (**locale format**) |
| `%%~zI` | size in bytes |
| `%%~$PATH:I` | first match of the value in `PATH` (current directory first) |
| combine | `%%~dpI`, `%%~nxI`, `%%~fsI`, `%%~ftzaI` (DIR-like line) |

`%%~` modifiers query the file system; they work on non-existent paths for the purely textual ones (`f d p n x`).

## Variables inside loop bodies

The body is one block: `%var%` is expanded once, before the loop starts.

```bat
rem Wrong: prints 0 every time
set /a n=0
for %%F in (*) do (
    set /a n+=1
    echo %n%
)

rem Right (a): delayed expansion
setlocal EnableDelayedExpansion
for %%F in (*) do (
    set /a n+=1
    echo !n! %%F
)
endlocal

rem Right (b): subroutine per item - also gives a clean scope
for %%F in (*) do call :Each "%%F"
goto :eof
:Each
set /a n+=1
echo %n% %~1
exit /b
```

`set /a n+=1` itself is fine either way (`SET /A` reads variables by name at run time). Option (b) is slower (CALL re-scans the file) but immune to `!` in file names.

## Break and continue

**Break:** `GOTO` a label after the loop. This abandons the loop (and any enclosing blocks). For `FOR /L` the remaining iterations still tick silently (see above); for `FOR /F` the whole command output was already read.

```bat
set "FOUND="
for %%F in (*.cfg) do (
    findstr /c:"enabled=1" "%%F" >nul && (set "FOUND=%%F" & goto :found)
)
echo none found & exit /b 1
:found
echo first enabled config: %FOUND%
```

Never `GOTO` out of a loop inside a subroutine and expect to come back into the loop.

**Continue:** there is no `continue`. Either guard the rest of the body with `IF`, or put the body in a subroutine and `exit /b` early:

```bat
for %%F in (*.txt) do call :Handle "%%F"
goto :eof

:Handle
if %~z1 equ 0 exit /b          & rem "continue" for empty files
echo processing %~nx1
exit /b
```

## GOTO loops: while, until, do-while

```bat
rem while (cond) { ... }
set /a i=0
:while
if %i% geq 10 goto :wend
echo %i%
set /a i+=1
goto :while
:wend

rem do { ... } while (cond)  - retry up to 5 times
set /a try=0
:retry
set /a try+=1
ping -n 1 server01 >nul && goto :up
if %try% lss 5 (ping -n 3 127.0.0.1 >nul & goto :retry)
echo server01 down & exit /b 1
:up

rem Iterate positional arguments (safe with * and ?)
:argloop
if "%~1"=="" goto :argsdone
echo arg: %~1
shift
goto :argloop
:argsdone
```

GOTO loops re-read each line, so `%var%` is always current — no delayed expansion needed. They are slower than `FOR` for large counts. Put loop labels at top level, never inside `( )` blocks.

**Waiting:** `timeout /t 5 /nobreak >nul` (**Since:** Vista) fails when input is redirected (*"Input redirection is not supported"*, e.g. under some schedulers); `ping -n 6 127.0.0.1 >nul` (≈5 s) works everywhere.

## Recipes

```bat
rem Count lines in a file (includes empty lines)
for /f %%N in ('find /c /v "" ^< "%FILE%"') do set "LINES=%%N"

rem Newest file matching a pattern
set "NEWEST="
for /f "eol=: delims=" %%F in ('dir /b /a-d /o-d "*.log" 2^>nul') do if not defined NEWEST set "NEWEST=%%F"

rem All files recursively, including hidden, sorted
for /f "eol=: delims=" %%F in ('dir /b /s /a-d /on "C:\src\*.cs"') do echo %%F

rem Remove empty directories, deepest first
for /f "delims=" %%D in ('dir /b /s /ad "%ROOT%" ^| sort /r') do rd "%%D" 2>nul

rem Loop over lines of a variable that contains a list separated by ;
set "LIST=alpha;beta;gamma delta"
for %%I in ("%LIST:;=" "%") do echo %%~I

rem Total size of matching files (32-bit SET /A: wrong above 2 GB in total)
set /a TOTAL=0
for %%F in (*.log) do set /a TOTAL+=%%~zF
```

## Pitfalls

- `%var%` in loop bodies is stale; use `!var!`, a subroutine, or `SET /A` by name.
- FOR variables are case-sensitive and single-letter; at the prompt use `%V`, in files `%%V`.
- Plain `FOR`/`FOR /D` wildcards skip hidden/system items; `FOR /R` with a literal name returns non-existent paths.
- `FOR /F` skips empty lines and lines starting with `;`; `skip=0` is an error; `delims=` must be last.
- `GOTO` out of `FOR /L` keeps iterating silently.
- `!` in file names is destroyed when delayed expansion is on.
- `for %%A in (%*)` treats `*`/`?` in arguments as wildcards.

---

See also: [Branching](09-branching.md) · [Arguments](11-arguments.md) · [Strings](13-strings.md)
