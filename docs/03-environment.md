[← Index](../README.md) · [← Parsing & escaping](02-parsing-escaping.md) · Next: [Variables →](04-variables.md)

# 3. The execution environment

What `cmd.exe` gives a script: how it is started, where it is running from, which settings apply, which variables exist, and the 32/64-bit and elevation issues that trip scripts up.

- [How a script is run](#how-a-script-is-run)
- [cmd.exe switches](#cmdexe-switches)
- [Command extensions](#command-extensions)
- [SETLOCAL / ENDLOCAL](#setlocal--endlocal)
- [Script location vs working directory](#script-location-vs-working-directory)
- [Command search: PATH and PATHEXT](#command-search-path-and-pathext)
- [Environment inheritance and persistence](#environment-inheritance-and-persistence)
- [Dynamic variables](#dynamic-variables)
- [Useful standard variables](#useful-standard-variables)
- [32-bit vs 64-bit](#32-bit-vs-64-bit)
- [Elevation (UAC)](#elevation-uac)
- [Code pages](#code-pages)
- [Limits](#limits)
- [Pitfalls](#pitfalls)

---

## How a script is run

| How | Effect |
|---|---|
| `script.cmd` from a `cmd` prompt | Runs in the **same** `cmd.exe`. Without `SETLOCAL`, variable changes and `cd` leak into the prompt. `exit` (without `/b`) closes the window. |
| `call script.cmd` from another script | Runs in the same process; returns to the caller when it ends. |
| `script.cmd` (no `CALL`) from another script | **Transfers control** — the caller never resumes. Almost always a bug. |
| Double-click in Explorer | `cmd.exe /c "path\script.cmd"`; window closes as soon as the script ends. Starting directory is the script's folder. |
| "Run as administrator" | Elevated `cmd /c`; **current directory is `C:\Windows\System32`**, not the script's folder. |
| Task Scheduler / services | No console window; "Start in" may be unset (current dir = `System32`); runs under the configured account with its own environment. |
| `start "" script.cmd` | New window, new `cmd.exe`, runs in parallel. `start /wait` waits. |

**Keep the window open when double-clicked** (only then):

```bat
set "INTERACTIVE="
for %%A in (%CMDCMDLINE%) do if /i "%%~A"=="/c" set "INTERACTIVE=1"
rem ... at the end:
if defined INTERACTIVE pause
```

> Automation that runs `cmd /c script.cmd` (schedulers, CI, other tools) matches too and would hang on `PAUSE`. Only use this in scripts meant for people, or add a `--no-pause` option.

## cmd.exe switches

| Switch | Meaning |
|---|---|
| `/c cmd` | Run `cmd`, then exit. |
| `/k cmd` | Run `cmd`, then stay at the prompt. |
| `/s` | Change `/c` and `/k` quote handling: strip only the first and last quote. |
| `/q` | Echo off. |
| `/d` | Do **not** run the `AutoRun` commands (registry `...\Command Processor\AutoRun`). |
| `/a` / `/u` | Output of internal commands to pipes/files in ANSI / UTF-16LE. |
| `/e:on` / `/e:off` | Enable / disable command extensions. |
| `/v:on` / `/v:off` | Enable / disable delayed expansion. |
| `/f:on` | File/directory name completion characters. |
| `/t:fg` | Console colours. |

**Quote handling of `/c`:** if the text after `/c` starts with `"`, `cmd` keeps the quotes only when *all* of these hold: no `/s`, exactly two quotes, no special characters `&<>()@^|` between them, at least one whitespace between them, and the quoted string is the name of an executable file. Otherwise it **removes the first and last quote** and runs the rest. Hence the idiom of wrapping everything in an extra pair of quotes:

```bat
cmd /c ""C:\Program Files\Tool\tool.exe" "arg with space" > "out file.txt""
```

`AutoRun` (`HKLM` and `HKCU\Software\Microsoft\Command Processor\AutoRun`) runs on every `cmd.exe` start unless `/d` is given — check for it when a script behaves differently on one machine.

## Command extensions

Enabled by default since Windows 2000 (unless disabled by `cmd /e:off` or the `EnableExtensions` registry value). They provide almost everything modern scripts use: `SETLOCAL ENABLEEXTENSIONS`, `IF DEFINED`/`/I`/`EQU…`, `FOR /F /D /R /L`, `SET /A` and `/P`, `%~` modifiers, `CALL :label`, `GOTO :EOF`, `SHIFT /n`, `MD` creating intermediate directories, `PUSHD` to UNC paths, and more.

```bat
setlocal EnableExtensions          & rem always be explicit
if not "%CMDEXTVERSION%"=="2" (echo This script needs command extensions & exit /b 1)
```

`%CMDEXTVERSION%` is `2` on Windows 2000 and every later version.

## SETLOCAL / ENDLOCAL

```bat
setlocal [EnableExtensions | DisableExtensions] [EnableDelayedExpansion | DisableDelayedExpansion]
endlocal
```

- `SETLOCAL` snapshots the **environment, the current directory, and the extension/delayed-expansion state**. `ENDLOCAL` restores all of them (current directory restore verified).
- An implicit `ENDLOCAL` happens for every outstanding `SETLOCAL` when a script or a `CALL`ed subroutine ends — each `CALL` level has its own stack. An `ENDLOCAL` cannot pop a `SETLOCAL` from the caller's level.
- At most **32** nested `SETLOCAL`s per `CALL` level (*"Maximum setlocal recursion level reached"*).
- Getting a value **out** of a `SETLOCAL` scope needs the tunnel idiom: `endlocal & set "x=%x%"` (see [Functions → returning values](10-functions.md#returning-values)).
- Start **every** script with `setlocal EnableExtensions` (and usually `DisableDelayedExpansion`) so it behaves the same whatever the caller's settings are, and so it doesn't leak variables into an interactive prompt.

## Script location vs working directory

| Expression | Value |
|---|---|
| `%~dp0` | Drive + folder of the running script, **with trailing `\`** |
| `%~f0` | Full path of the script |
| `%~n0` / `%~nx0` | Script name without / with extension |
| `%CD%` | Current working directory (no trailing `\` except at a root) |
| `%__CD__%` | Current directory **with** trailing `\` (undocumented) |

```bat
@echo off
setlocal EnableExtensions
set "HERE=%~dp0"                         & rem capture first: SHIFT changes %0
pushd "%HERE%" || exit /b 1              & rem run relative to the script
rem ...
popd
```

- **`SHIFT` also shifts `%0`** — after one `SHIFT`, `%~dp0` is computed from `%1` (verified). Capture `%~dp0` into a variable at the top.
- Inside a `CALL :label` subroutine, `%0` is `:label` but `%~dp0` / `%~f0` still give the script's path (verified).
- **UNC paths:** `cd \\server\share` is refused (*"CMD does not support UNC paths as current directories"*). A script started from a UNC path runs with the current directory set to `C:\Windows`. `pushd \\server\share\dir` maps a temporary drive letter (from `Z:` downwards) and `popd` removes it.
- `cd` does not change drive without `/d`: `cd /d "%TARGET%"`.

## Command search: PATH and PATHEXT

When a command name has no path, `cmd.exe` looks for:

1. Internal commands (`DIR`, `COPY`, `SET`, …) — these win over any `dir.exe`.
2. The **current directory**, then each directory in `%PATH%`, in order.
3. In each directory, the name as typed, then with each extension in `%PATHEXT%` (default `.COM;.EXE;.BAT;.CMD;.VBS;.VBE;.JS;.JSE;.WSF;.WSH;.MSC`).

> **Since Vista:** if the environment variable `NoDefaultCurrentDirectoryInExePath` is defined (any value), the current directory is **not** searched (for programs started by `cmd`). Useful hardening against planted executables.

Use full paths for system tools in scripts that may run with a hostile current directory: `"%SystemRoot%\System32\robocopy.exe"`. See [`FindInPath`](../lib/system/README.md#findinpath) and the `~$PATH:` modifier ([Arguments](11-arguments.md#parameter-modifiers)).

## Environment inheritance and persistence

- A child process gets a **copy** of the environment. Nothing a child does changes its parent's environment — a script cannot set a variable in the Explorer session or in a parent PowerShell.
- `SET` changes only the current `cmd.exe` (and children started afterwards).
- Persistent variables: `setx NAME value` (user) or `setx NAME value /M` (machine, needs admin). **Since:** Windows Vista (XP via Support Tools).
  - `setx` does **not** change the current session — also `set` it if you need it now.
  - `setx` truncates values to **1024 characters** — never `setx PATH "%PATH%;..."` (it also merges user+machine PATH into one). Edit `PATH` in the registry (`HKCU\Environment`) or via System Properties instead.
- Already-running processes (including Explorer) don't see new persistent values until they re-read the environment.

## Dynamic variables

Computed on each expansion. **If you `set` a variable with one of these names, your value hides the dynamic one** — never do `set ERRORLEVEL=0`.

| Variable | Value |
|---|---|
| `%CD%` | Current directory |
| `%DATE%`, `%TIME%` | Current date/time in the **user's regional format** — never parse these if the script may run elsewhere; use [`GetTimestamp`](../lib/datetime/README.md#gettimestamp) |
| `%RANDOM%` | Integer 0–32767 |
| `%ERRORLEVEL%` | Current error level (see [Redirection & errors](12-redirection-errors.md#errorlevel-semantics)) |
| `%CMDEXTVERSION%` | `2` |
| `%CMDCMDLINE%` | The command line that started this `cmd.exe` |
| `%HIGHESTNUMANODENUMBER%` | Highest NUMA node number (**Since:** Windows 7) |
| `%=ExitCode%` | Last exit code as 8 hex digits, e.g. `00000005` (undocumented) |
| `%=ExitCodeAscii%` | Last exit code as an ASCII character (undocumented) |
| `%=C:%` | Current directory of drive C: (undocumented) |
| `%__CD__%` | Current directory with trailing `\` (undocumented) |
| `%__APPDIR__%` | Folder of `cmd.exe` with trailing `\`, e.g. `C:\Windows\System32\` (undocumented) |

## Useful standard variables

| Variable | Example | Notes |
|---|---|---|
| `%SystemRoot%` | `C:\Windows` | Prefer to `%windir%` |
| `%ComSpec%` | `C:\Windows\System32\cmd.exe` | |
| `%TEMP%`, `%TMP%` | `C:\Users\me\AppData\Local\Temp` | Per-user; for SYSTEM it is `C:\Windows\Temp` |
| `%USERPROFILE%` | `C:\Users\me` | |
| `%APPDATA%` | `...\AppData\Roaming` | |
| `%LOCALAPPDATA%` | `...\AppData\Local` | **Since:** Vista |
| `%ProgramData%` | `C:\ProgramData` | **Since:** Vista (XP: `%ALLUSERSPROFILE%\Application Data`) |
| `%PUBLIC%` | `C:\Users\Public` | **Since:** Vista |
| `%ProgramFiles%` | `C:\Program Files` | **`C:\Program Files (x86)` in a 32-bit process** on 64-bit Windows |
| `%ProgramFiles(x86)%` | `C:\Program Files (x86)` | Only defined on 64-bit Windows. Note the parentheses: quote it, especially inside blocks |
| `%ProgramW6432%` | `C:\Program Files` | 64-bit Program Files from any process (**Since:** Windows 7 / Server 2008 R2) |
| `%COMPUTERNAME%`, `%USERNAME%`, `%USERDOMAIN%` | | |
| `%OS%` | `Windows_NT` | |
| `%NUMBER_OF_PROCESSORS%` | `8` | Logical processors |
| `%PROCESSOR_ARCHITECTURE%` | `AMD64`, `x86`, `ARM64` | Of the **current process** |
| `%PROCESSOR_ARCHITEW6432%` | `AMD64` | Only defined in a 32-bit process on 64-bit Windows |

## 32-bit vs 64-bit

On 64-bit Windows a 32-bit `cmd.exe` (`C:\Windows\SysWOW64\cmd.exe`, e.g. launched by a 32-bit installer or tool) sees a different world:

| | 64-bit process | 32-bit process on 64-bit Windows |
|---|---|---|
| `%SystemRoot%\System32` | real System32 | **redirected to SysWOW64** |
| `%SystemRoot%\Sysnative` | doesn't exist | real System32 (**Since:** Vista; XP x64 needs a hotfix) |
| `HKLM\SOFTWARE` | 64-bit view | **redirected to `HKLM\SOFTWARE\WOW6432Node`** |
| `%ProgramFiles%` | `C:\Program Files` | `C:\Program Files (x86)` |

```bat
rem Detect OS bitness regardless of process bitness
set "OSARCH=%PROCESSOR_ARCHITECTURE%"
if defined PROCESSOR_ARCHITEW6432 set "OSARCH=%PROCESSOR_ARCHITEW6432%"

rem Re-launch in 64-bit cmd.exe if we're a 32-bit process on 64-bit Windows
if defined PROCESSOR_ARCHITEW6432 if exist "%SystemRoot%\Sysnative\cmd.exe" (
    "%SystemRoot%\Sysnative\cmd.exe" /c "%~f0" %*
    exit /b
)
```

For the registry, `REG` accepts `/reg:32` and `/reg:64` to pick a view explicitly (see [Tools → REG](14-tools.md#reg)).

## Elevation (UAC)

**Since:** Vista. An administrator's normal session runs with a filtered token; "Run as administrator" gives the full token.

- Detect: [`IsAdmin`](../lib/system/README.md#isadmin) (checks the High/System integrity SID via `WHOAMI /GROUPS`, falls back to `NET SESSION`).
- An elevated script starts in `System32` — always work relative to `%~dp0`.
- Mapped network drives of the normal session are **not visible** in the elevated session (separate logon session); use UNC paths.
- There is no pure-batch way to request elevation. Options outside batch: a shortcut with "Run as administrator", Task Scheduler with "Run with highest privileges", or a one-line PowerShell/VBScript `ShellExecute ... "runas"` launcher. `RUNAS` runs as a *different user*; it does not elevate.

## Code pages

The console code page determines how the bytes of the script and of command output are interpreted.

```bat
for /f "tokens=2 delims=:." %%C in ('chcp') do set /a "OLDCP=%%C"
chcp 65001 >nul          & rem UTF-8 (script file saved as UTF-8 without BOM)
rem ... work with non-ASCII paths/text ...
chcp %OLDCP% >nul
```

| Code page | Use |
|---|---|
| 437 / 850 | Default OEM console code pages (US / Western Europe) |
| 1252 | Windows ANSI (Western) — what Notepad historically saved as "ANSI" |
| 65001 | UTF-8. Works on Windows 7+, much more reliable on Windows 10+ |

`cmd /u /c dir > out.txt` writes internal-command output as UTF-16LE.

## Limits

| Limit | Value |
|---|---|
| Command line after expansion | **8191** characters (Windows XP+; 2047 on Windows 2000/NT) |
| Single environment variable | 32767 characters (but `SET` on one line is bound by the 8191 limit) |
| `SET /P` from a file | Reads the first line, at most 1023 characters (verified on Windows 11) |
| Nested `SETLOCAL` | 32 per `CALL` level |
| `FOR /F` tokens | 31 per line (`tokens=1-31`; more with tricks) |
| `SET /A` integers | 32-bit signed |

## Pitfalls

- An elevated or scheduled script starts in `System32` — use `%~dp0`.
- `SHIFT` changes `%0`; capture `%~dp0` first.
- `%DATE%`/`%TIME%` formats depend on the user's locale.
- `%ProgramFiles%` and `System32` lie to 32-bit processes.
- `setx` truncates at 1024 characters and doesn't affect the current session.
- `%ProgramFiles(x86)%` contains `)` — inside a block it ends the block unless quoted.

---

See also: [Variables](04-variables.md) · [Tools](14-tools.md) · [Pitfalls checklist](15-pitfalls.md)
