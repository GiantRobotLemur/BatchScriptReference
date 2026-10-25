[← Index](../README.md) · [← Functions](10-functions.md) · Next: [Redirection & errors →](12-redirection-errors.md)

# 11. Command-line arguments

How arguments reach a script (or a `CALL`ed subroutine), how to read them, and how to parse options robustly.

- [Positional parameters](#positional-parameters)
- [Argument splitting](#argument-splitting)
- [Parameter modifiers](#parameter-modifiers)
- [Testing for presence](#testing-for-presence)
- [SHIFT](#shift)
- [Iterating over arguments](#iterating-over-arguments)
- [Parsing options](#parsing-options)
- [Special characters in arguments](#special-characters-in-arguments)
- [Drag and drop](#drag-and-drop)
- [Pitfalls](#pitfalls)

---

## Positional parameters

| Reference | Value |
|---|---|
| `%0` | The script as invoked (may be relative, quoted or not) — use `%~f0` for the full path |
| `%1` … `%9` | Arguments 1–9, **including** any surrounding quotes |
| `%~1` | Argument 1 with one pair of surrounding quotes removed |
| `%*` | All arguments as one string, exactly as typed (original spacing and delimiters; verified) |

Arguments beyond the ninth are reachable only via [`SHIFT`](#shift) (or `%*`). Modifiers cannot be applied to `%*`.

Inside a `CALL :label` subroutine these refer to the subroutine's arguments; save script arguments you need later into variables at the top of the script.

## Argument splitting

`cmd.exe` splits the argument string at **unquoted** space, tab, `,`, `;` and `=` (verified):

```
script.cmd a,b;c=d   "e f"  ""  g
%1=a  %2=b  %3=c  %4=d  %5="e f"  %6=""  %7=g
%*=a,b;c=d   "e f"  ""  g
```

- Quotes group characters (including delimiters and spaces) into one argument; the quotes stay part of `%n`.
- Consequence for option syntax: `/out:file` is one argument, but `--out=file` arrives as **two** (`--out`, `file`), and `--opt=a=b` as three. Users must quote `"--opt=a=b"`.
- An external program (EXE) doesn't use these rules — it receives the raw command line and splits it itself (usually by C runtime rules, where `,;=` are ordinary characters and `\"` is an escaped quote).

## Parameter modifiers

Apply to `%0`–`%9` and to FOR variables (`%%~fI`). The textual ones work for paths that don't exist; `a`, `t`, `z` and `$PATH:` query the file system.

| Modifier | Meaning | Example for `"C:\Data\Report 1.txt"` |
|---|---|---|
| `%~1` | remove surrounding quotes | `C:\Data\Report 1.txt` |
| `%~f1` | full path (resolved against current dir, `.`/`..` collapsed) | `C:\Data\Report 1.txt` |
| `%~d1` | drive | `C:` |
| `%~p1` | path, with leading and trailing `\` | `\Data\` |
| `%~n1` | name without extension | `Report 1` |
| `%~x1` | extension with dot (last dot only) | `.txt` |
| `%~s1` | short 8.3 form of the full path (if 8.3 names exist) | `C:\Data\REPORT~1.TXT` |
| `%~a1` | attributes | `--a--------` (`d` first for directories; empty if missing) |
| `%~t1` | last-modified date/time in the **user's locale format** | `24/10/2026 19:39` |
| `%~z1` | size in bytes (for a directory, a meaningless allocation size — don't use it) | `5120` |
| `%~$PATH:1` | full path of the first match searching the current dir, then `PATH`; empty if none | `C:\Windows\System32\cmd.exe` for `cmd.exe` |
| combined | `%~dp1` folder with trailing `\`; `%~nx1` file name; `%~dp$PATH:1`; `%~ftza1` DIR-like line | |

```bat
set "SCRIPT_DIR=%~dp0"
set "INPUT=%~f1"
set "BASENAME=%~n1"
set "OUTPUT=%~dpn1.out"                  & rem same folder and name, new extension
if /i not "%~x1"==".csv" echo Expected a .csv file
if "%~a1"=="" echo %1 does not exist
```

Notes:

- `%~x1` on `archive.tar.gz` is `.gz`; on `.gitignore` the **name** is empty and the extension is `.gitignore`.
- `%~p1` / `%~dp1` end with `\`; strip it with `set "d=%~dp1" & set "d=!d:~0,-1!"` (or in two lines with `%`).
- `%~$PATH:1` requires the extension (`cmd.exe`, not `cmd`) — see [`FindInPath`](../lib/system/README.md#findinpath) for a PATHEXT-aware version.
- Using a `%~` modifier on an argument with **wildcards** is textual (no globbing): `%~f1` of `*.txt` is `C:\cwd\*.txt`.
- A malformed modifier (`%~q1`, or `%~a` followed by a non-digit) is a **fatal parse error** — even inside a `REM` comment.

## Testing for presence

```bat
if "%~1"=="" goto :Usage          & rem treats "" (empty quoted arg) as missing
if [%1]==[] goto :Usage           & rem missing only; "" counts as present
if "%~2"=="" (set "OUT=default.txt") else set "OUT=%~2"
```

`if "%1"==""` (without `~`) breaks when the argument is already quoted (`""a b""`). Always use `%~1` inside quotes.

Count arguments:

```bat
set /a ARGC=0
for %%A in (%*) do set /a ARGC+=1          & rem wrong if args contain * or ?
```

Robust version: a `SHIFT` loop in a subroutine (so the script's own `%1…` are untouched):

```bat
call :CountArgs ARGC %*
...
:CountArgs  outVar args...
setlocal
set "_out=%~1"                  & rem save it - SHIFT is about to move %1
set /a _n=-1
:CountArgs_loop
set /a _n+=1
shift
if not [%1]==[] goto :CountArgs_loop
endlocal & set "%_out%=%_n%"
exit /b
```

(Verified: `a "b c" "" * d` counts 5.)

## SHIFT

```bat
shift          & rem %1 <- %2, %2 <- %3, ... (and %0 <- %1!)
shift /2       & rem shift from %2 on: %1 (and %0) stay put
```

- `SHIFT` does **not** change `%*` (verified).
- `SHIFT` also shifts `%0`, so `%~dp0` changes — capture it first.
- `SHIFT /n` (n = 0–8) **Since:** Windows 2000 (extensions).

## Iterating over arguments

```bat
:NextArg
if [%1]==[] goto :ArgsDone
echo Argument: %~1
shift
goto :NextArg
:ArgsDone
```

Safe with wildcards and empty `""` arguments. `for %%A in (%*)` is shorter but expands `*`/`?` as file patterns and skips nothing else.

## Parsing options

**Hand-rolled** (fine for a couple of switches):

```bat
set "VERBOSE=" & set "OUT=" & set "FILES="
:Parse
if [%1]==[] goto :Parsed
if /i "%~1"=="/v"   (set "VERBOSE=1" & shift & goto :Parse)
if /i "%~1"=="-v"   (set "VERBOSE=1" & shift & goto :Parse)
if /i "%~1"=="/out" (set "OUT=%~2" & shift & shift & goto :Parse)
if "%~1"=="/?"      goto :Usage
set "FILES=%FILES% %1"
shift
goto :Parse
:Parsed
```

**Library**: [`ParseArgs`](../lib/args/README.md#parseargs) handles `/v`, `-v`, `--verbose`, `/out:x`, `/out x`, `-o x`, `--out x`, `--out=x`, `--`, positional arguments, aliases and error reporting in one call:

```bat
if "%~1"=="/?" goto :Usage           & rem before any CALL - see below
call "%BATLIB%\args\ParseArgs.cmd" OPT "o|out: v|verbose h|help" %*
if errorlevel 2 (echo %OPT_ERROR% & exit /b 1)
if defined OPT_help goto :Usage
if defined OPT_verbose echo Writing to %OPT_out%
for /l %%i in (1,1,%OPT_ARGC%) do call echo File: %%OPT_ARG%%i%%
```

`/?` handling: an unquoted `/?` anywhere in a `CALL`'s arguments makes `CALL` print its own help (verified). Check for it with `if "%~1"=="/?"` **before** passing `%*` to any `CALL`.

## Special characters in arguments

| Character | What happens |
|---|---|
| `& \| < >` | Unquoted, they are executed by the shell that starts the script, never reaching it. Quoted (`"a&b"`), they arrive — but break the script as soon as it uses `%1` unquoted. |
| `^` | Unquoted: consumed by the caller's parser. Through `CALL`: quoted carets get doubled. |
| `%` | Literal from an interactive prompt (`%x%` is expanded there if `x` is defined); from a batch file the caller must write `%%`. Through `CALL`, expanded a second time. |
| `!` | Removed if the script reads the argument with delayed expansion enabled. |
| `"` | Can't appear inside an argument in a way batch can handle safely. |
| `,` `;` `=` space tab | Split arguments unless quoted. |
| `*` `?` | Fine, unless you iterate with `for %%A in (%*)`. |

Defensive pattern: copy arguments into variables with delayed expansion **off** (`set "arg=%~1"`), then work with `!arg!` under delayed expansion.

## Drag and drop

Dropping files onto a script in Explorer runs `cmd /c script.cmd file1 file2 …` with **full paths**, quoting only those containing spaces. Paths with `&` but no spaces arrive unquoted and break the command line (a long-standing Explorer quirk). Don't assume the current directory is the files' or the script's folder — use `%~dp1` and `%~dp0`.

## Pitfalls

- Delimiters `,` `;` `=` split arguments; `--x=y` arrives as two arguments.
- `%1` keeps quotes; compare `"%~1"`, not `"%1"`.
- `/?` in `CALL` arguments; `%` and `^` mangled by `CALL`.
- `SHIFT` doesn't change `%*` but does change `%0`.
- `%~t1` is locale-formatted; `%~z1` sizes over 2 GB don't compare correctly in `IF`/`SET /A`.

---

See also: [`ParseArgs`](../lib/args/README.md#parseargs) · [Functions](10-functions.md) · [Script template](../templates/script-template.cmd)
