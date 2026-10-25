[← Index](../README.md) · [← Loops](08-loops.md) · Next: [Functions →](10-functions.md)

# 9. Branching

`GOTO`, labels, and the ways a script or subroutine ends.

- [GOTO and labels](#goto-and-labels)
- [GOTO :EOF](#goto-eof)
- [Computed GOTO](#computed-goto)
- [Dispatch tables](#dispatch-tables)
- [EXIT vs EXIT /B](#exit-vs-exit-b)
- [Exit codes seen by the outside world](#exit-codes-seen-by-the-outside-world)
- [GOTO inside blocks and loops](#goto-inside-blocks-and-loops)
- [Structuring a script with GOTO](#structuring-a-script-with-goto)
- [Pitfalls](#pitfalls)

---

## GOTO and labels

```bat
goto :Cleanup         & rem the colon is optional: goto Cleanup
...
:Cleanup
```

- Search order: from the line **after** the GOTO to the end of the file, then from the top. With duplicate labels, the first one found that way wins.
- Label names are case-insensitive; text after the name on the label line is ignored (`:Copy  src dst` documents a subroutine's arguments).
- A **missing label** prints *"The system cannot find the batch label specified - name"* and **aborts the current batch context**: at top level the script ends; in a `CALL`ed subroutine, control returns to the caller with `ERRORLEVEL` 1 (verified).
- `GOTO` re-scans the file from disk, which makes very large scripts with heavy `GOTO`/`CALL` use slow. Labels must sit on CRLF-terminated lines ([why](01-syntax.md#line-endings-and-encoding)).

## GOTO :EOF

`goto :eof` jumps to the end of the file: it returns from a `CALL`ed subroutine, or ends the script. **Since:** Windows 2000 (command extensions). It does **not** change `ERRORLEVEL` — whatever the last command left is returned (verified).

Prefer `exit /b [code]` — it does the same and states the result explicitly.

## Computed GOTO

The label can come from a variable:

```bat
goto :Step%STEP%
goto :Mode_%~1
```

Validate the value first if it comes from outside: an unknown value aborts the script, and a value containing `&` or `|` will execute code.

```bat
rem Check that a label exists before jumping
findstr /r /i /c:"^:Mode_%~1\>" "%~f0" >nul || (echo Unknown mode "%~1" & exit /b 1)
goto :Mode_%~1
```

## Dispatch tables

`CALL` to a computed label behaves like a function table with a default branch — a missing label returns `ERRORLEVEL` 1 instead of ending the script (verified):

```bat
set "CMD=%~1"
if not defined CMD goto :Usage
call :Cmd_%CMD% 2>nul || (echo Unknown command: %CMD% & goto :Usage)
exit /b %errorlevel%

:Cmd_build
echo building...
exit /b 0

:Cmd_clean
echo cleaning...
exit /b 0
```

The `||` branch also fires when a valid command fails with a non-zero code — return 0 on success, and check the label exists first (as above) if you need to tell the two apart.

## EXIT vs EXIT /B

| Command | Effect |
|---|---|
| `exit /b` | Return from the current script or subroutine; `ERRORLEVEL` unchanged |
| `exit /b N` | …and set `ERRORLEVEL` to N |
| `exit` | **Terminate `cmd.exe`** — closes an interactive window, and kills the *calling* script too |
| `exit N` | …with process exit code N |

```bat
if not exist "%INPUT%" (
    echo Input not found: %INPUT% 1>&2
    exit /b 2
)
```

- **Never use bare `EXIT` in a script** someone might `CALL` or run from a prompt. `EXIT /B` is **Since:** Windows 2000.
- `exit /b` inside a `FOR` body or `IF` block works and leaves immediately.
- After `exit /b N` in a subroutine, the caller sees `%ERRORLEVEL%` = N and `||`/`&&` react to it.
- `EXIT /B` performs the implicit `ENDLOCAL`s for its level.

## Exit codes seen by the outside world

When a script is run by another process (`cmd /c script.cmd`, Task Scheduler, CI, PowerShell), the **process exit code** is what matters, and it is not always the last `ERRORLEVEL`:

| Script ends with | `call script.cmd` → ERRORLEVEL | `cmd /c script.cmd` → exit code |
|---|---|---|
| `exit /b 3` | 3 | 3 |
| a failing command, then `goto :eof` / falling off the end | 1 | **0** (verified) |
| `exit 3` | process ends | 3 |

**Always end a script with an explicit `exit /b N`** — e.g. `exit /b %RC%` — so both callers and other processes get the right code.

## GOTO inside blocks and loops

`GOTO` from inside `( … )` abandons the rest of the block and **every enclosing `FOR` loop**, then continues at the label. That is how you "break" ([Loops → break](08-loops.md#break-and-continue)). Consequences:

- Labels **inside** blocks are unreliable as `GOTO` targets — keep labels at top level.
- You cannot jump back into a loop.
- `FOR /L` keeps counting silently after the jump.

```bat
for %%F in (*.txt) do (
    if %%~zF gtr 1000000 (
        echo Too big: %%F
        goto :Abort
    )
)
echo All files OK
exit /b 0

:Abort
exit /b 1
```

## Structuring a script with GOTO

A common, readable layout: main flow at the top, `exit /b` before the first subroutine, subroutines below.

```bat
@echo off
setlocal EnableExtensions DisableDelayedExpansion

call :ParseArgs %* || exit /b 1
call :Prepare     || goto :Fail
call :Build       || goto :Fail
call :Package     || goto :Fail
echo Done.
exit /b 0

:Fail
set "RC=%errorlevel%"
echo Failed with code %RC% 1>&2
call :Cleanup
exit /b %RC%

:ParseArgs
...
exit /b 0
```

`set "RC=%errorlevel%"` must be the first command after the label — almost any other command can reset `ERRORLEVEL`.

## Pitfalls

- A missing label aborts the script (or the current `CALL` level).
- `goto :eof` and falling off the end don't set an exit code; `cmd /c` may report 0 after a failure.
- `EXIT` without `/B` kills the caller too.
- Labels inside parenthesised blocks; `GOTO` out of `FOR /L`.
- Untrusted text in a computed label can run commands.

---

See also: [Functions](10-functions.md) · [Redirection & errors](12-redirection-errors.md)
