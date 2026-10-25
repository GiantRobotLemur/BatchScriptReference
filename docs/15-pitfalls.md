[← Index](../README.md) · [← Built-in tools](14-tools.md)

# 15. Pitfalls & best-practice checklist

Every trap documented in this reference, in one place. Each was reproduced on Windows 11 while writing these pages unless marked otherwise.

## Before you start

- [ ] File is `.cmd`, saved with **CRLF** line endings and **no BOM** — [Syntax](01-syntax.md#line-endings-and-encoding)
- [ ] First lines: `@echo off` and `setlocal EnableExtensions DisableDelayedExpansion` — [Environment](03-environment.md#setlocal--endlocal)
- [ ] `set "HERE=%~dp0"` captured before any `SHIFT` — [Environment](03-environment.md#script-location-vs-working-directory)
- [ ] Work relative to `%~dp0`, not the current directory (elevated/scheduled runs start in `System32`)
- [ ] Ends with an explicit `exit /b N` — [Branching](09-branching.md#exit-codes-seen-by-the-outside-world)

## Parsing & expansion

| Trap | Fix |
|---|---|
| `%var%` inside `( … )` is the value from before the block | `!var!`, `if defined`, `if errorlevel`, or a subroutine — [Parsing](02-parsing-escaping.md#delayed-expansion) |
| `%var%` on the same line as the `set` that changes it is stale (`set "x=1" & echo %x%`) | Separate lines |
| `%var:~0,1%` / `%var:a=b%` on an **undefined** variable eats the rest of the line | `if not defined var goto :skip` on the line before — [Parsing](02-parsing-escaping.md#percent-expansion) |
| `%~` (or bad modifier) inside a `REM` / `::` comment aborts the script | Don't write `%~` in comments — [Syntax](01-syntax.md#comments) |
| `REM /? …`, `ECHO /?`, `CALL … /? …` print help instead | Never start comments with `/?`; quote `"/?"` in CALL args |
| `::` comments inside blocks (two in a row, or before `)`) break the block | Use `REM` in blocks |
| Unescaped `)` in a block (`echo (x)`, `%ProgramFiles(x86)%`) closes it | `^)` or quotes |
| Delayed expansion strips `!` from data (file names, file lines, arguments) | Toggle it: assign with it off, process with it on — [Loops](08-loops.md#reading-files-safely) |
| A command stored in a variable and run as `!cmd!` fails | Keep commands literal; put only data in variables — [Parsing](02-parsing-escaping.md#recipes) |
| Trailing space after `^` breaks line continuation | Nothing after the `^` |

## Variables & expressions

| Trap | Fix |
|---|---|
| `set x = 1` creates variable `x ` | `set "x=1"` — [Variables](04-variables.md#assignment) |
| `SET /P` keeps the old value on empty input | Clear the variable first |
| Naming a variable `ERRORLEVEL`, `CD`, `DATE`, `LIB`… | Use distinctive names |
| `08`, `09` are invalid (octal) in `SET /A` | Strip leading zeros — [Expressions](05-expressions.md#numbers-decimal-hex-octal) |
| `set /a x=1<<4` unquoted | Quote the expression |
| `%` in `SET /A` in a batch file | `%%` |
| 32-bit wrap-around; no floats; truncating division | Fixed-point; check ranges |
| `set /a "n=%input%"` accepts `abc` as 0 | Validate digits with `FOR /F "delims=0123456789"` |

## Conditions

| Trap | Fix |
|---|---|
| `if "10" GTR "9"` is false (string compare) | Don't quote numbers — [Condition tests](07-condition-tests.md#comparison-operators) |
| `if 08 EQU 8` is false | Strip leading zeros |
| `if 2147483648 GTR 2147483647` is false (saturation) | Compare big numbers as padded strings |
| String `LSS/GTR` is collation order (`a LSS B`) | Don't rely on it for byte order |
| `if %v%==x` with empty or spaced `v` | `if "%v%"=="x"` / `if defined v` |
| `else` not on the `)` line | `) else (` — [Conditionals](06-conditionals.md#else-and-block-layout) |
| `if errorlevel 1` misses negative exit codes | `if !errorlevel! neq 0` |
| `if exist "dir"` true for files too | `if exist "dir\"` |

## Loops

| Trap | Fix |
|---|---|
| FOR variables are case-sensitive; `%%V` in files vs `%V` at prompt | — [Loops](08-loops.md#for-basics) |
| Wildcard `FOR`/`FOR /D` skip hidden & system items | `for /f … in ('dir /b /a …')` |
| `FOR /R` with a non-wildcard name returns paths that don't exist | Use wildcards, or test `if exist` |
| `FOR /F` skips empty lines and lines starting with `;` | `findstr /n "^"` prefix trick; `eol=` choice |
| `skip=0` is a syntax error | Omit the option |
| `GOTO` out of `FOR /L` keeps iterating silently | Use a `GOTO` loop for early exit |
| `for %%A in (%*)` expands `*`/`?` | `SHIFT` loop — [Arguments](11-arguments.md#iterating-over-arguments) |
| `FOR /R` root can't be a FOR variable or `!var!` | `pushd` first |
| Wildcards match 8.3 short names (`*.htm` → `.html`) on volumes with 8.3 names | Filter the extension again with `if /i "%%~xF"==".htm"` |

## Functions, branching, arguments

| Trap | Fix |
|---|---|
| Main code falls into the first subroutine | `exit /b` before the first label — [Functions](10-functions.md#defining-and-calling) |
| `goto :label` instead of `call :label` | `call` to return |
| Missing label aborts the script / call level | Validate computed labels — [Branching](09-branching.md#computed-goto) |
| `exit` (no `/b`) kills the caller and the window | `exit /b` |
| `cmd /c script` reports 0 after a failure that ended with `goto :eof` | End with `exit /b %RC%` |
| `CALL` mangles `%`, `^`, `/?` in arguments | Pass variable names — [Functions](10-functions.md#arguments) |
| `call :label` inside `FOR /F ('…')` fails | Self-dispatch: `('"%~f0" :label')` |
| Recursion beyond ~335 levels aborts everything | Loops instead of recursion |
| `CALL` costs ~3 ms each | Inline hot loops |
| `endlocal & set` loses `!` if the caller has delayed expansion on, breaks on `"` | FOR tunnel / by-reference — [Functions](10-functions.md#returning-values) |
| `--opt=a=b` arrives as three arguments (`=` is a delimiter) | Quote it: `"--opt=a=b"` — [Arguments](11-arguments.md#argument-splitting) |
| After `SHIFT`, `%~1` is no longer your out-variable name | Save `%~1` first |

## Redirection, errors, tools

| Trap | Fix |
|---|---|
| `echo text 2>file` redirects stderr | `>file echo text 2` — [Redirection](12-redirection-errors.md#writing-files-reliably) |
| `echo text >file` writes a trailing space | Redirection first |
| `2>&1 >file` order | `>file 2>&1` |
| Variables set inside a pipe are lost; delayed expansion is off there | Temp file or `FOR /F` — [Redirection](12-redirection-errors.md#pipes) |
| `RD` and failed redirections don't set `ERRORLEVEL` | Use `\|\|` |
| `ERRORLEVEL` overwritten by the next command (`SET` in `.cmd` resets it) | Capture immediately |
| ROBOCOPY returns 1–7 on success | `if errorlevel 8` — [Tools](14-tools.md#robocopy) |
| `"C:\dir\"` passed to REG/ROBOCOPY/most EXEs: `\"` is an escaped quote | `"C:\dir\\"` or `"C:\dir\."` |
| `TIMEOUT` fails with redirected input | `ping -n N 127.0.0.1 >nul` |
| `FORFILES` rejects UNC paths | `pushd \\server\share` |
| `%DATE%`/`%TIME%` and `%~t` are locale-formatted | [`GetTimestamp`](../lib/datetime/README.md#gettimestamp) |
| `TASKLIST` exits 0 when nothing matches | Test its output |
| `setx` truncates to 1024 chars | Never `setx PATH "%PATH%;…"` |
| `WMIC` is gone from current Windows 11 | `REG`, `ROBOCOPY` tricks — [Tools](14-tools.md#wmic-deprecated) |
| 32-bit processes see `SysWOW64` and `WOW6432Node` | `Sysnative`, `/reg:64` — [Environment](03-environment.md#32-bit-vs-64-bit) |
| `call script.cmd` vs `script.cmd` | Without `CALL` the caller never resumes |
| Editing a script while it runs | Don't — `cmd` re-reads the file as it goes |

---

[← Index](../README.md)
