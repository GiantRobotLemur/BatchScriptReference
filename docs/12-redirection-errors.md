[← Index](../README.md) · [← Arguments](11-arguments.md) · Next: [Strings →](13-strings.md)

# 12. Redirection, pipes & error handling

- [Redirection operators](#redirection-operators)
- [Writing files reliably](#writing-files-reliably)
- [Pipes](#pipes)
- [ERRORLEVEL semantics](#errorlevel-semantics)
- [Success and failure: && and ||](#success-and-failure--and-)
- [Error-handling patterns](#error-handling-patterns)
- [Logging to console and file](#logging-to-console-and-file)
- [Exit codes of common tools](#exit-codes-of-common-tools)
- [Pitfalls](#pitfalls)

---

## Redirection operators

Handles: `0` stdin, `1` stdout, `2` stderr, `3`–`9` free for your own use.

| Syntax | Meaning |
|---|---|
| `cmd > file` | stdout to file (truncate). Same as `1>` |
| `cmd >> file` | stdout appended to file |
| `cmd < file` | stdin from file |
| `cmd 2> file` | stderr to file |
| `cmd > file 2>&1` | stdout and stderr to the same file (**order matters**) |
| `cmd 2>&1 > file` | stderr to the *old* stdout (console), stdout to file |
| `cmd > nul 2>&1` | discard everything |
| `cmd 2> nul` | discard errors only |
| `echo msg 1>&2` / `>&2 echo msg` | write to stderr |
| `<nul set /p "=text"` | print without newline |
| `cmd < nul` | answer "no input" to prompts (e.g. `pause`, `del` confirmations) |

- Redirection can appear anywhere in the command: `>file echo text` is the same as `echo text >file`.
- `NUL` is the null device in every directory.
- Redirection is set up before the command runs. If the target can't be opened, the command doesn't run, `||` fires, but **`ERRORLEVEL` is not changed** (verified).
- Redirecting a **block** applies to everything inside it, and opens the file once:

```bat
(
    echo [settings]
    echo name=%NAME%
    echo port=%PORT%
) > "%OUT%\app.ini"
```

## Writing files reliably

```bat
echo value 2>>log.txt        & rem WRONG: "2>>" redirects stderr - writes nothing to log
echo value >log.txt          & rem writes "value " (with the trailing space)
>log.txt echo value 2        & rem correct: "value 2", no trailing space
>>log.txt echo(%LINE%        & rem correct even if LINE is empty or "on"/"off"
type nul > empty.txt         & rem create/truncate a file
copy /b file.txt +,, >nul    & rem "touch": update the modified time
```

A digit before `>` is a handle number. **Put redirection first** (`>file echo …`) when the text may end in a digit, and to avoid trailing spaces.

## Pipes

```bat
dir /b | sort /r
type log.txt | find /c "ERROR"
ipconfig | findstr /c:"IPv4"
```

How `cmd` runs a pipe — the source of most pipe surprises:

- **Each side that is an internal command or a block runs in a new `cmd.exe /S /D /c`** — variables set there are lost:

  ```bat
  echo x | set /p "v="             & rem v is set in a child cmd...
  echo %v%                          & rem ...so not here
  ```

- The child re-parses the command, so escapes may be needed twice, and **delayed expansion is off** in the child regardless of your script's setting. To use it: `... | cmd /v:on /c "echo !var!"`.
- `ERRORLEVEL` after a pipe is the **last** command's (verified: `findstr nomatch | sort` gives 0).
- Both sides run concurrently; there's no `pipefail`. To check the first command's result, write to a temp file instead.
- Piping into a `FOR /F` is done with `in ('a ^| b')`.

## ERRORLEVEL semantics

`ERRORLEVEL` is a single global number, set by external programs on exit and by **some** internal commands — and **not changed** by many others.

Verified behaviour of internal commands on failure (Windows 11, `.cmd` file):

| Command | Sets `ERRORLEVEL` on failure | `\|\|` fires on failure |
|---|---|---|
| `DEL`, `DIR`, `CD`, `TYPE`, `MD`, `COPY`, `MOVE`, `REN`, `PUSHD` | 1 | yes |
| `RD` (missing dir) | **unchanged** | yes |
| `SET name` (no match), `SET /A` error | 1 / large code | yes |
| unknown command | 9009 | yes |
| redirection failure | **unchanged** | yes |
| `FIND`/`FINDSTR` no match (external) | 1 | yes |

Commands that leave `ERRORLEVEL` unchanged (verified): `ECHO`, `REM`, `IF` (when nothing runs), `GOTO`, `SHIFT`, `ENDLOCAL`, and `CALL` of a subroutine that ends with a bare `exit /b`. A successful `SET`, `PATH`, `ASSOC`, `FTYPE`, `PROMPT` resets it to 0 in `.cmd` files but not in `.bat` files ([details](01-syntax.md#file-types-bat-vs-cmd)). `VER` and `VOL` also reset it to 0.

Rules that follow:

- **Capture immediately:** `set "RC=%errorlevel%"` as the very next command (and remember: in a `.cmd` file that `SET` itself then resets `ERRORLEVEL` to 0 — the value is safe in `RC`).
- To reset deliberately: `cmd /c exit 0` (or `ver >nul`). To set an arbitrary value: `cmd /c exit 42`.
- Don't `set ERRORLEVEL=…` — it hides the real value from `%ERRORLEVEL%`.
- For commands that don't set `ERRORLEVEL` on failure (`RD`, redirection), use `||`.
- `if errorlevel N` = "≥ N"; misses negative codes.

## Success and failure: && and ||

```bat
md "%OUT%" 2>nul
copy /y "%SRC%" "%OUT%\" >nul || goto :CopyFailed
findstr /c:"OK" status.txt >nul && echo healthy || echo unhealthy
call :Step1 && call :Step2 && call :Step3 || echo a step failed
```

- `&&`/`||` react to the command's own success flag. For external programs and `CALL` that's the exit code (0 = success). For internal commands see the table above.
- `a && b || c`: `c` runs if `a` **or** `b` fails.
- A parenthesised group's success is that of its **last** command: `(cmd1 & cmd2) || echo …` tests `cmd2` only (verified).

## Error-handling patterns

**Fail fast:**

```bat
call :Prepare || goto :Fail
robocopy "%SRC%" "%DST%" /MIR >nul
if errorlevel 8 goto :Fail
call :Package || goto :Fail
exit /b 0

:Fail
set "RC=%errorlevel%"
>&2 echo Failed with code %RC%
exit /b %RC%
```

**Collect and continue:**

```bat
set "FAILED=0"
for %%F in (*.sql) do (
    sqlcmd -i "%%F" >nul || (set /a FAILED+=1 & >&2 echo Failed: %%F)
)
if %FAILED% gtr 0 exit /b 1
```

**Cleanup always runs** — route every exit through one label:

```bat
set "RC=0"
pushd "%WORK%" || exit /b 1
call :DoWork
set "RC=%errorlevel%"
:Cleanup
popd
if exist "%TMPFILE%" del "%TMPFILE%"
exit /b %RC%
```

> Don't shorten the first two lines to `call :DoWork || set "RC=%errorlevel%"`: `%errorlevel%` is expanded when the line is read, i.e. **before** the call runs. Use two lines, or `|| call set "RC=%%errorlevel%%"`.

Batch can't trap Ctrl+C or errors — if the user presses Ctrl+C and answers **Y** to *"Terminate batch job (Y/N)?"*, cleanup doesn't run.

**Retry:**

```bat
set /a TRY=0
:Retry
set /a TRY+=1
copy /y "\\server\share\file" . >nul 2>&1 && goto :Copied
if %TRY% geq 5 (>&2 echo Giving up & exit /b 1)
ping -n 6 127.0.0.1 >nul
goto :Retry
:Copied
```

## Logging to console and file

There's no `tee`. Options:

```bat
rem 1. A log subroutine that writes to both (see templates/script-template.cmd)
call :Log INFO "Copied %FILE%"

rem 2. Run the main part with output redirected, then show it
call :Main > "%LOG%" 2>&1
set "RC=%errorlevel%"
type "%LOG%"
exit /b %RC%

rem 3. Append each command's output, and also show it
robocopy ... >> "%LOG%" 2>&1 & type "%LOG%"   & rem crude; re-shows whole log
```

Timestamped log file name: [`TimestampName`](../lib/datetime/README.md#timestampname). Keep the last N logs: [`RotateFiles`](../lib/files/README.md#rotatefiles).

## Exit codes of common tools

| Tool | Codes |
|---|---|
| `ROBOCOPY` | **Bitmask**: 0 nothing copied, 1 files copied, 2 extra files in destination, 4 mismatches, 8 copy failures, 16 fatal. **0–7 = success**, ≥ 8 = failure. Never use `\|\|` or `if errorlevel 1` with robocopy |
| `XCOPY` | 0 ok, 1 no files found, 2 Ctrl+C, 4 init error (disk space, bad syntax), 5 write error |
| `FIND` / `FINDSTR` | 0 found, 1 not found, 2 error (FIND) |
| `CHOICE` | index of the chosen key (1, 2, …); 255 error; 0 on Ctrl+C |
| `PING` | 0 if a reply was received (but "Destination host unreachable" replies count as success on some versions — check for `TTL=`) |
| `SC`, `NET` | 0 ok; non-zero = Win32 error code (e.g. `SC` 1060 service does not exist, 1062 not started) |
| `REG` | 0 ok, 1 failure |
| `TASKKILL` | 0 ok, 128 process not found |
| `FC` | 0 same, 1 different, 2 error |
| `MSIEXEC` | 0 ok, 3010 ok but reboot required, 1602 user cancelled, 1603 fatal |
| unknown command | 9009 |

## Pitfalls

- `echo text 2>file` — a trailing digit becomes a handle number.
- `>file 2>&1`, not `2>&1 >file`.
- Variables set inside a pipe are lost; delayed expansion is off on pipe sides.
- `RD` and redirection failures don't set `ERRORLEVEL`; use `||`.
- `ERRORLEVEL` is overwritten by almost anything — capture it immediately.
- ROBOCOPY returns non-zero on success.
- A failing script run via `cmd /c` can report exit code 0 unless it ends with `exit /b N` ([details](09-branching.md#exit-codes-seen-by-the-outside-world)).

---

See also: [Branching](09-branching.md) · [Tools](14-tools.md) · [Pitfalls checklist](15-pitfalls.md)
