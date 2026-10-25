[← Index](../README.md) · [← Expressions](05-expressions.md) · Next: [Condition tests →](07-condition-tests.md)

# 6. Conditional statements

The structure of `IF` / `ELSE` and the other ways to execute code conditionally. The individual **tests** (`EXIST`, `DEFINED`, comparisons, `ERRORLEVEL`) are covered in [Condition tests](07-condition-tests.md).

- [IF syntax](#if-syntax)
- [ELSE and block layout](#else-and-block-layout)
- [ELSE IF chains](#else-if-chains)
- [AND, OR, NOT](#and-or-not)
- [Conditional operators && and ||](#conditional-operators--and-)
- [Switch / case](#switch--case)
- [Conditionals inside loops and blocks](#conditionals-inside-loops-and-blocks)
- [Pitfalls](#pitfalls)

---

## IF syntax

```
IF [NOT] condition command
IF [NOT] condition (command) ELSE (command)
```

where *condition* is one of:

```
[/I] string1 == string2
[/I] string1 compare-op string2      compare-op: EQU NEQ LSS LEQ GTR GEQ
EXIST path
DEFINED variable
ERRORLEVEL number
CMDEXTVERSION number
```

The command after the condition is everything to the end of the line, **including** any `&` chains:

```bat
if "%MODE%"=="debug" echo one & echo two      & rem both run only in debug mode
(if "%MODE%"=="debug" echo one) & echo two    & rem "two" always runs
```

## ELSE and block layout

`ELSE` must be on the **same line** as the closing `)` of the IF branch. Valid layouts:

```bat
if exist "%F%" (echo found) else (echo missing)

if exist "%F%" (
    echo found
) else (
    echo missing
)

if exist "%F%" (
    echo found
) else echo missing

if exist "%F%" (echo found) else echo missing
```

Invalid:

```bat
if exist "%F%" echo found else echo missing   & rem "else echo missing" is echoed!
if exist "%F%" (
    echo found
)
else (                                         & rem 'else' is not recognized as a command
    echo missing
)
```

Without parentheses, `else` is just more text for the IF's command.

## ELSE IF chains

There is no `ELSEIF` keyword, but `else` followed by another `if` works:

```bat
if "%LEVEL%"=="1" (
    set "NAME=low"
) else if "%LEVEL%"=="2" (
    set "NAME=medium"
) else if "%LEVEL%"=="3" (
    set "NAME=high"
) else (
    set "NAME=unknown"
)
```

The whole chain is one command — parsed (and `%`-expanded) once, like any block.

## AND, OR, NOT

**NOT:** `if not exist "%F%" ...`, `if not defined X ...`, `if not "%a%"=="%b%" ...`. Note `if not errorlevel 1` means *errorlevel < 1*.

**AND** — nest the conditions:

```bat
if exist "%SRC%" if not exist "%DST%" copy "%SRC%" "%DST%"

if defined A if defined B (
    echo both defined
)
```

An `ELSE` attaches to the **innermost** IF, so an AND with an ELSE needs a flag:

```bat
set "ok="
if exist "%SRC%" if not exist "%DST%" set "ok=1"
if defined ok (copy "%SRC%" "%DST%") else (echo Nothing to do)
```

**OR** — use a flag, or `GOTO`:

```bat
set "match="
if /i "%EXT%"==".jpg" set "match=1"
if /i "%EXT%"==".png" set "match=1"
if defined match echo image

rem Membership test with FOR (no wildcards in the list!)
set "match="
for %%E in (.jpg .jpeg .png .gif) do if /i "%EXT%"=="%%E" set "match=1"

rem Substring trick: is EXT in the list?
set "LIST=;.jpg;.jpeg;.png;.gif;"
if not "!LIST:;%EXT%;=!"=="!LIST!" echo image     & rem needs delayed expansion
```

## Conditional operators && and ||

`&&` runs the next command if the previous one succeeded, `||` if it failed. Ideal for one-liners around commands that report success properly:

```bat
mkdir "%OUT%" 2>nul
copy /y "%SRC%" "%OUT%\" >nul || (echo Copy failed & exit /b 1)
findstr /i /c:"ERROR" "%LOG%" >nul && set "HAS_ERRORS=1"
call :Validate "%INPUT%" || goto :Usage
```

`a && b || c` is not a true ternary: if `b` fails, `c` runs too. And note that some internal commands set `ERRORLEVEL` but don't signal failure to `||`, and vice versa — see [Redirection & errors](12-redirection-errors.md#errorlevel-semantics).

## Switch / case

Dispatch on a value with `GOTO` to a computed label:

```bat
call :Case_%ACTION% 2>nul || (echo Unknown action: %ACTION% & exit /b 1)
exit /b 0

:Case_start
echo starting
exit /b 0

:Case_stop
echo stopping
exit /b 0
```

With `CALL`, an unknown label prints *"The system cannot find the batch label specified"* (hidden by `2>nul`) and returns an error, so the `||` branch handles the default. Validate `%ACTION%` first if it comes from the user: characters such as `&` would be executed. See [Branching → dispatch](09-branching.md#dispatch-tables).

## Conditionals inside loops and blocks

All `%var%` references in a block are expanded **once**, when the block is parsed:

```bat
set "found=0"
for %%F in (*.log) do (
    set "found=1"
    if "%found%"=="1" echo never printed - %found% is still 0 here
)
```

Fixes, in order of preference:

```bat
rem 1. IF DEFINED reads the current state - no expansion needed
set "found="
for %%F in (*.log) do (
    set "found=1"
    if defined found echo works
)

rem 2. IF ERRORLEVEL reads the current errorlevel
for %%F in (*.log) do (
    findstr /c:"ERROR" "%%F" >nul
    if not errorlevel 1 echo %%F has errors
)

rem 3. Delayed expansion
setlocal EnableDelayedExpansion
for %%F in (*.log) do (
    set /a n+=1
    if !n! gtr 10 echo more than ten
)

rem 4. Move the body into a subroutine - %var% is then fresh on every call
for %%F in (*.log) do call :Check "%%F"
```

## Pitfalls

- `else` must follow `)` on the same line; without parentheses it is not a keyword.
- The IF command runs to the end of the line, including `&` chains.
- `ELSE` binds to the innermost `IF` in a nested AND.
- `%var%` inside blocks is stale — use `if defined`, `if errorlevel`, `!var!` or a subroutine.
- `if %var%==value` breaks when `var` is empty or contains spaces — quote both sides.

---

See also: [Condition tests](07-condition-tests.md) · [Branching](09-branching.md)
