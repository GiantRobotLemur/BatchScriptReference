[← Index](../README.md) · [← Branching](09-branching.md) · Next: [Command-line arguments →](11-arguments.md)

# 10. Functions

Batch has no functions — it has labels you can `CALL`, which get their own arguments and their own `SETLOCAL` stack. With a few conventions that is enough to write reusable, testable routines like those in [`lib/`](../lib/README.md).

- [Defining and calling](#defining-and-calling)
- [Arguments](#arguments)
- [Local scope](#local-scope)
- [Returning values](#returning-values)
- [Return codes](#return-codes)
- [Recursion](#recursion)
- [External scripts as functions](#external-scripts-as-functions)
- [The library convention](#the-library-convention)
- [Performance](#performance)
- [Pitfalls](#pitfalls)

---

## Defining and calling

```bat
@echo off
setlocal EnableExtensions

call :Greet "World"
call :Greet "Batch" || echo Greet failed
exit /b 0                       & rem <-- stop here, or execution falls into :Greet

:Greet  name
echo Hello, %~1!
exit /b 0
```

- `call :Label args` starts a new **batch context**: new `%0`…`%9`/`%*`, new `SETLOCAL` stack, and `exit /b` / `goto :eof` return to the line after the `CALL`.
- Without `CALL`, `goto :Label` just jumps — no return.
- **Put `exit /b` before the first subroutine.** Otherwise the main code runs straight into it.
- `%0` is `:Label` inside the subroutine, but `%~dp0`/`%~f0` still give the script file.

## Arguments

Exactly like script arguments ([Arguments](11-arguments.md)): `%1`…`%9`, `%*`, `SHIFT`, and the `%~` modifiers (`%~f1`, `%~nx1`, …).

```bat
call :CopyTo "C:\src\file.txt" "D:\backup"

:CopyTo  file destDir
copy /y "%~1" "%~2\%~nx1" >nul
exit /b
```

CALL re-parses the line, so arguments are mangled in ways a direct script invocation is not (verified):

| You write | Subroutine receives |
|---|---|
| `call :f "a^b"` | `"a^^b"` — quoted carets are doubled |
| `call :f a^^b` | `ab` — unquoted carets are consumed |
| `call :f 100%%` | `%` starts a second expansion — garbles the rest of the line |
| `call :f a /? b` | nothing — CALL prints its own help |

**Pass data by reference** to avoid all of this: give the subroutine the *name* of a variable and let it read the value with delayed expansion.

```bat
set "text=50%% off & free ^shipping!"
call :Shout text                 & rem prints: 50% off & free ^shipping!

:Shout  varName
setlocal EnableDelayedExpansion
echo(!%~1!                     & rem prints the exact value
endlocal
exit /b
```

(Set `text` with delayed expansion **disabled** to keep the `!`; verified output shown.)

## Local scope

Start every non-trivial subroutine with `SETLOCAL`; the implicit `ENDLOCAL` when it returns discards its temporaries and restores the current directory.

```bat
:Process  file
setlocal
set "tmp=%TEMP%\work.tmp"
pushd "%~dp1"
rem ... use tmp freely ...
popd
exit /b 0                      & rem tmp is gone; caller's environment untouched
```

Name temporaries with a prefix (`_` in this repo) if a subroutine deliberately does **not** use `SETLOCAL`.

## Returning values

### 1. Out-variable + tunnel (the standard)

Caller passes the name of the variable to receive the result; the subroutine computes in a local scope and "tunnels" the value through `ENDLOCAL`:

```bat
call :Square result 12
echo %result%                  & rem 144

:Square  outVar n
setlocal
set /a "_r=%~2 * %~2"
endlocal & set "%~1=%_r%"
exit /b 0
```

Why it works: the whole line is percent-expanded **before** `endlocal` runs, so `%_r%` is replaced by the value while it still exists; then `endlocal` discards the scope and `set` runs in the caller's scope.

Multiple results — one line, several sets:

```bat
endlocal & set "%~1=%_dir%" & set "%~2=%_name%" & set "%~3=%_ext%"
```

Limits of the simple tunnel (verified):

- Values containing `"` break the quoting.
- If the **caller** has delayed expansion enabled, `!` in the value is removed (and carets adjacent to it).
- Values with `& | < > ^ %` are fine (inside the quotes).

### 2. FOR-variable tunnel (safer for special characters)

```bat
:GetValue  outVar
setlocal EnableDelayedExpansion
set "_r=..."
for /f "delims=" %%R in ("!_r!") do endlocal & set "%~1=%%R"
exit /b
```

The value travels in a FOR variable, so quotes and operators are inert. Caveats: if `_r` is empty the loop doesn't run, so the `ENDLOCAL` doesn't happen inside the loop and **the out-variable is left unchanged** (verified) — clear it first or handle the empty case; a value starting with `;` (the default `eol`) is also dropped. `!` is still lost if the caller has delayed expansion on.

### 3. Many results with a prefix

When a routine produces many variables (like [`ParseArgs`](../lib/args/README.md#parseargs)), build them inside `SETLOCAL` with a common prefix and replay them all after `ENDLOCAL`:

```bat
(
    for /f "delims=" %%V in ('set %PREFIX%_ 2^>nul') do (endlocal & set "%%V")
    exit /b %RC%
)
```

The parenthesised block is parsed once, so `%PREFIX%` and `%RC%` are read before the first `ENDLOCAL`. The first iteration's `ENDLOCAL` returns to the caller's scope; later ones are no-ops (an `ENDLOCAL` can't pop the caller's `SETLOCAL`).

### 4. Standard output

`FOR /F` runs its command in a child `cmd.exe` that is **not** in batch context, so `('call :Hostname')` fails with *"Invalid attempt to call batch label outside of batch script"* (verified). Re-invoke the script itself with a dispatch line at the top:

```bat
@echo off
if "%~1"==":Hostname" goto :Hostname      & rem dispatcher - first line after @echo off
...
for /f "delims=" %%L in ('"%~f0" :Hostname') do set "HOST=%%L"
...
:Hostname
echo my-host
exit /b
```

Natural for external commands, but slow for subroutines (a new `cmd.exe` per call) and the subroutine can't change the caller's variables. Prefer out-variables.

## Return codes

```bat
:Validate  file
if not exist "%~1" exit /b 2
if %~z1 equ 0      exit /b 3
exit /b 0
```

```bat
call :Validate "%F%"
if errorlevel 3 (echo empty) else if errorlevel 2 (echo missing) else echo ok

call :Validate "%F%" || exit /b      & rem propagate failure, keep the code
```

Use 0 for success. The library reserves 1 for usage errors and 2+ for function-specific failures — see [lib/README](../lib/README.md#conventions).

To return a value *and* a code: `endlocal & set "%~1=%_r%" & exit /b 3` — but put `exit /b` on its own line if you want to be sure about precedence, e.g.:

```bat
endlocal & set "%~1=%_r%"
exit /b 3
```

## Recursion

```bat
:Factorial  outVar n
setlocal
if %~2 leq 1 (endlocal & set "%~1=1" & exit /b)
set /a "_n=%~2 - 1"
call :Factorial _sub %_n%
set /a "_r=%~2 * _sub"
endlocal & set "%~1=%_r%"
exit /b
```

Recursion depth is limited by `cmd.exe`'s stack: around **335 levels** on Windows 11 (verified), after which the **whole script is aborted** with *"BATCH RECURSION exceeds STACK limits"*. Convert deep recursion to `GOTO` loops with an explicit counter.

## External scripts as functions

| Invocation | Environment | Return | Use for |
|---|---|---|---|
| `call other.cmd args` | **shared** (unless `other.cmd` uses `SETLOCAL`) | `ERRORLEVEL` from `exit /b N` | Library functions, includes |
| `cmd /c other.cmd args` | isolated copy | process exit code (use explicit `exit /b N`) | Untrusted or messy scripts |
| `other.cmd args` (no CALL) | shared | **never returns** | Never — it's a bug |
| `start "" /wait other.cmd` | isolated, new window | exit code | Interactive tools |

`%~dp0` inside the called script refers to **its** folder — use that to find sibling files.

## The library convention

Every function in [`lib/`](../lib/README.md) follows one pattern, so they can be called as files *or* pasted in as subroutines:

```bat
@echo off
:: FuncName  outVar arg ...
setlocal EnableExtensions DisableDelayedExpansion
if "%~1"=="" exit /b 1                      & rem usage error
... compute _r ...
endlocal & set "%~1=%_r%"
exit /b 0
```

```bat
rem As a file
call "%BATLIB%\strings\StrLen.cmd" LEN myVar

rem Inlined: paste the file below a label in your script
call :StrLen LEN myVar
...
:StrLen
<contents of StrLen.cmd>
```

Internal labels are prefixed with the function name (`:Trim_lead`) so inlined functions can't collide. Functions that depend on siblings call them via `%~dp0`; when inlining those, change the `call "%~dp0X.cmd"` to `call :X` and inline `X` too. Details: [lib/README](../lib/README.md).

## Performance

`CALL` (to a label or a file) costs about **3 ms** each on a typical machine (1,000 calls to an empty subroutine ≈ 3.2 s, verified) because `cmd.exe` re-reads the script to find the label. Inside loops over thousands of items, inline the body (with delayed expansion) instead of calling a subroutine per item.

## Pitfalls

- Missing `exit /b` before the first subroutine → main code falls through into it.
- `goto :Label` instead of `call :Label` → never returns.
- `%`, `^` and `/?` in `CALL` arguments are mangled — pass variable names instead.
- Tunnelled values with `"`; `!` lost when the caller has delayed expansion on.
- The FOR tunnel leaves the out-variable unchanged when the value is empty.
- Deep recursion aborts the whole script.
- A subroutine without `SETLOCAL` leaks every variable it touches.

---

See also: [Arguments](11-arguments.md) · [Library](../lib/README.md) · [Parsing & escaping](02-parsing-escaping.md)
