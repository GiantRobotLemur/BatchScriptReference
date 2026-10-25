[← Library](../README.md) · [← Index](../../README.md)

# System

| Function | Purpose |
|---|---|
| [IsAdmin](#isadmin) | Is the script running elevated? |
| [FindInPath](#findinpath) | Locate a program the way `cmd.exe` would |

Tests: [`tests/test-system.cmd`](../../tests/test-system.cmd)

---

### IsAdmin

Tests whether the script is running with an elevated (administrator) token, or as SYSTEM.

**Source:** [`IsAdmin.cmd`](IsAdmin.cmd)

**Usage**

```bat
call "%BATLIB%\system\IsAdmin.cmd"
```

No arguments; the answer is the ERRORLEVEL.

| ERRORLEVEL | Meaning |
|---|---|
| 0 | Elevated (High integrity) or SYSTEM |
| 2 | Not elevated |

**Since:** Windows Vista (`WHOAMI`); falls back to `NET SESSION` on XP.

**Examples**

```bat
call "%BATLIB%\system\IsAdmin.cmd" || (
    echo This script must be run as administrator. 1>&2
    exit /b 1
)

call "%BATLIB%\system\IsAdmin.cmd" && set "SCOPE=/M" || set "SCOPE="
setx MYAPP_HOME "%~dp0" %SCOPE%
```

**How it works.** `WHOAMI /GROUPS` lists the token's groups, including its mandatory integrity level: `S-1-16-12288` (High) when elevated, `S-1-16-16384` for SYSTEM; `FINDSTR` looks for either. On systems without WHOAMI (XP), `NET SESSION` — which requires admin rights — is used instead.

**Limitations.** The `NET SESSION` fallback reports "not admin" if the *Server* (LanmanServer) service is stopped. Being a member of Administrators is not the same as running elevated under UAC — this function tests the latter, which is what matters for permission checks.

---

### FindInPath

Finds a program the way `cmd.exe` resolves a command name: current directory first, then each directory on `PATH`, trying the name as given and with each `PATHEXT` extension.

**Source:** [`FindInPath.cmd`](FindInPath.cmd)

**Usage**

```bat
call "%BATLIB%\system\FindInPath.cmd" outVar program
```

| Argument | Required | Meaning |
|---|---|---|
| `outVar` | yes | Receives the full path of the first match |
| `program` | yes | `git`, `git.exe`, `build.cmd`, … |

| ERRORLEVEL | Meaning |
|---|---|
| 0 | Found |
| 1 | Usage error |
| 2 | Not found |

**Since:** Windows 2000 (no `WHERE.EXE` needed).

**Examples**

```bat
call "%BATLIB%\system\FindInPath.cmd" GIT git || (echo git is not on PATH & exit /b 1)
echo Using %GIT%

rem Prefer a tool on PATH, fall back to a known location
call "%BATLIB%\system\FindInPath.cmd" SEVENZIP 7z || set "SEVENZIP=%ProgramFiles%\7-Zip\7z.exe"
```

**How it works.** `%%~$PATH:A` searches the current directory and then `PATH` for an exact name. If that fails, the same search is repeated for `name + ext` for each extension in `%PATHEXT%` (default `.COM;.EXE;.BAT;.CMD` if unset).

**Limitations.** Doesn't see internal commands (`DIR`, `COPY`), doskey macros, or App Paths registrations (see [`FindAppPath`](../registry/README.md#findapppath)). A name containing `*` or `?` is treated as a wildcard by `FOR`. Honours the current directory even when `NoDefaultCurrentDirectoryInExePath` is set — unlike `cmd.exe` itself in that case.
