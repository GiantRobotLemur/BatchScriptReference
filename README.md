# BatchScriptReference

Reference and code snippets for Windows Batch scripting.

A dense reference for writing `cmd.exe` batch scripts, aimed at people who already program in other languages. It also includes a library of tested, reusable batch functions and a model script to start from. Everything here uses only what ships with Windows: no PowerShell, no downloads, no signing.

Examples were run on Windows 11. Behaviour that is surprising, undocumented, or easy to get wrong is marked *verified* where it was reproduced while writing these pages.

## Quick start

```bat
rem 1. Copy the model script and adapt it
copy templates\script-template.cmd C:\work\myproject\do-thing.cmd

rem 2. Let your scripts find the function library
setx BATLIB "C:\path\to\BatchScriptReference\lib"

rem 3. Use library functions
call "%BATLIB%\datetime\TimestampName.cmd" LOG "%TEMP%" mytool log
call "%BATLIB%\registry\FindInstallPath.cmd" GITDIR "Git" || echo Git not installed

rem 4. Check the library on a new machine
tests\run-tests.cmd
```

## Language reference

| # | Page | Covers |
|---|---|---|
| 1 | [Syntax](docs/01-syntax.md) | `.bat` vs `.cmd`, line endings, echo, comments, `&` `&&` `\|\|`, blocks, line continuation, labels |
| 2 | [Parsing, expansion & escaping](docs/02-parsing-escaping.md) | Parser phases, `%` vs `!` expansion, delayed expansion, escaping table, quoting, CALL double expansion |
| 3 | [Execution environment](docs/03-environment.md) | How scripts run, `cmd` switches, extensions, SETLOCAL, `%~dp0` vs `%CD%`, PATH search, dynamic variables, 32/64-bit, UAC, code pages, limits |
| 4 | [Variables](docs/04-variables.md) | SET forms, names, scope, defined/empty, prefixes, SET /P, capturing output, arrays, indirection |
| 5 | [Expressions](docs/05-expressions.md) | SET /A operators and precedence, octal/hex, 32-bit integers, errors, arithmetic recipes |
| 6 | [Conditional statements](docs/06-conditionals.md) | IF/ELSE layout, else-if chains, AND/OR/NOT, `&&`/`\|\|`, switch/case, conditions in loops |
| 7 | [Condition tests](docs/07-condition-tests.md) | `==`, `EQU`…`GEQ` (numeric vs string), `EXIST`, `DEFINED`, `ERRORLEVEL`, tests IF can't do |
| 8 | [Loops](docs/08-loops.md) | FOR, FOR /D /R /L /F, options, modifiers, reading files safely, break/continue, GOTO loops |
| 9 | [Branching](docs/09-branching.md) | GOTO, labels, GOTO :EOF, computed GOTO, dispatch tables, EXIT vs EXIT /B, exit codes |
| 10 | [Functions](docs/10-functions.md) | CALL :label, arguments, local scope, returning values, return codes, recursion, external scripts |
| 11 | [Command-line arguments](docs/11-arguments.md) | `%1`…`%*`, splitting rules, `%~` modifiers, SHIFT, option parsing, special characters |
| 12 | [Redirection, pipes & errors](docs/12-redirection-errors.md) | Redirection, pipes, ERRORLEVEL semantics, error-handling patterns, logging, tool exit codes |
| 13 | [Strings](docs/13-strings.md) | Substrings, replace, length, contains, trim, case, pad, split/join, special characters |
| 14 | [Built-in tools](docs/14-tools.md) | REG, ROBOCOPY, XCOPY, FORFILES, WHERE, FINDSTR, CHOICE, TIMEOUT, SC, SCHTASKS, CERTUTIL, TAR, CURL, … |
| 15 | [Pitfalls checklist](docs/15-pitfalls.md) | Every trap from the pages above in one checklist |

### Windows version notes

Features are assumed to work on **Windows XP and later** (with command extensions, which are on by default). Anything introduced later is marked:

> **Since:** Windows Vista

Everything in this repository works on Windows 10 and 11. WMIC is used only as a fallback for XP, because Microsoft has removed it from current Windows 11.

## Function library

Tested, reusable functions, one `.cmd` file each. You can call them from your scripts or paste them in. → **[lib/README.md](lib/README.md)**

| Group | Functions |
|---|---|
| [Arguments](lib/args/README.md) | [ParseArgs](lib/args/README.md#parseargs): `/x`, `-x`, `--name value`, `/name:value`, `--`, positional |
| [Registry](lib/registry/README.md) | [RegQueryValue](lib/registry/README.md#regqueryvalue) · [FindAppPath](lib/registry/README.md#findapppath) · [FindInstallPath](lib/registry/README.md#findinstallpath) |
| [Date & time](lib/datetime/README.md) | [GetTimestamp](lib/datetime/README.md#gettimestamp) (locale-independent) · [TimestampName](lib/datetime/README.md#timestampname) (unique dated file names) |
| [Files](lib/files/README.md) | [EnsureDir](lib/files/README.md#ensuredir) · [NormalizePath](lib/files/README.md#normalizepath) · [GetTempFile](lib/files/README.md#gettempfile) · [BackupFile](lib/files/README.md#backupfile) · [MirrorDir](lib/files/README.md#mirrordir) · [DeleteOlderThan](lib/files/README.md#deleteolderthan) · [RotateFiles](lib/files/README.md#rotatefiles) |
| [Strings](lib/strings/README.md) | [StrLen](lib/strings/README.md#strlen) · [ToUpper / ToLower](lib/strings/README.md#toupper--tolower) · [Trim](lib/strings/README.md#trim) |
| [System](lib/system/README.md) | [IsAdmin](lib/system/README.md#isadmin) · [FindInPath](lib/system/README.md#findinpath) |

The library's conventions: argument 1 names the output variable, results are tunnelled out through `ENDLOCAL`, and ERRORLEVEL is `0` for success, `1` for a usage error and `2`+ for other failures.

## Model script

[`templates/script-template.cmd`](templates/script-template.cmd) is a complete starting point with:

- a header
- `SETLOCAL`
- `/?` handling
- argument parsing with ParseArgs (flags, an option with a value, several positionals)
- validation with helpful errors on stderr
- a `:Log` subroutine writing timestamped lines to the console and a per-run log file
- a loop over the inputs
- a subroutine with return codes
- a single cleanup/exit path with documented exit codes

## Tests

```bat
tests\run-tests.cmd            & rem all suites; ERRORLEVEL 0 = all passed
tests\run-tests.cmd registry   & rem one suite
```

The suites are pure batch, built on the small assertion helper `tests\_assert.cmd`. The registry tests create and remove temporary keys under `HKCU`.

## Cheat sheet

```bat
@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "HERE=%~dp0"                         & rem script folder, trailing \

set "name=value"                         & rem always quote the whole assignment
set /a "n=(a+b)*2, i+=1"                 & rem 32-bit integer maths; %% for modulo
set /p "ans=Continue? "                  & rem input (unchanged if empty!)
if defined name echo set                 & rem robust "is set" test
if /i "%~1"=="/v" set "VERBOSE=1"        & rem compare args with %~1 and quotes
if exist "%DIR%\" echo is a directory
if %n% GEQ 10 (echo big) else (echo small)
if errorlevel 1 echo last command failed & rem means ERRORLEVEL >= 1

for %%F in ("%DIR%\*.log") do echo %%~nxF %%~zF
for /r "%DIR%" %%F in (*.tmp) do del "%%F"
for /l %%i in (1,1,5) do echo %%i
for /f "usebackq tokens=1,* delims==" %%K in ("app.ini") do set "CFG_%%K=%%L"
for /f "delims=" %%L in ('hostname') do set "HOST=%%L"

setlocal EnableDelayedExpansion          & rem !var! = current value inside ( ) blocks
for %%F in (*) do (set /a c+=1 & echo !c! %%F)
endlocal

call :Func result "arg" || goto :Fail    & rem subroutine with out-variable
exit /b 0

:Func  outVar arg
setlocal
set "_r=got %~2"
endlocal & set "%~1=%_r%"
exit /b 0
```

## Repository layout

```
README.md              this index
docs/                  language reference (15 pages)
lib/                   function library, one folder per group, README per group
templates/             model script
tests/                 run-tests.cmd, _assert.cmd, test-<group>.cmd
CLAUDE.md              maintenance notes for AI-assisted edits
.gitattributes         forces CRLF for .cmd/.bat (required for labels to work)
```

## License

[MIT](LICENSE)
