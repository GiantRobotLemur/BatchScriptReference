[← Index](../README.md)

# Function library

Reusable, tested batch functions. Each function is one self-contained `.cmd` file that you can **call** from your scripts or **paste** into them as a subroutine.

## Contents

| Group | Function | Purpose | Since | Depends on |
|---|---|---|---|---|
| [Arguments](args/README.md) | [ParseArgs](args/README.md#parseargs) | Parse `/x`, `-x`, `--name value`, `/name:value` and positional arguments | 2000 | — |
| [Registry](registry/README.md) | [RegQueryValue](registry/README.md#regqueryvalue) | Read a registry value and its type | XP | — |
| | [FindAppPath](registry/README.md#findapppath) | Program path from *App Paths* | XP | RegQueryValue |
| | [FindInstallPath](registry/README.md#findinstallpath) | Install folder of an installed product | Vista | RegQueryValue |
| [Date & time](datetime/README.md) | [GetTimestamp](datetime/README.md#gettimestamp) | Locale-independent timestamp, custom format | Vista | — |
| | [TimestampName](datetime/README.md#timestampname) | Unique `prefix_YYYYMMDD_hhnnss.ext` path | Vista | GetTimestamp |
| [Files](files/README.md) | [EnsureDir](files/README.md#ensuredir) | Create a directory tree if missing | 2000 | — |
| | [NormalizePath](files/README.md#normalizepath) | Absolute, clean path | 2000 | — |
| | [GetTempFile](files/README.md#gettempfile) | Unique empty file in `%TEMP%` | 2000 | — |
| | [BackupFile](files/README.md#backupfile) | Copy a file to a timestamped name | Vista | EnsureDir, TimestampName |
| | [MirrorDir](files/README.md#mirrordir) | ROBOCOPY /MIR with sane defaults and exit codes | Vista | — |
| | [DeleteOlderThan](files/README.md#deleteolderthan) | Delete files older than N days | Vista | — |
| | [RotateFiles](files/README.md#rotatefiles) | Keep the newest N files | 2000 | — |
| [Strings](strings/README.md) | [StrLen](strings/README.md#strlen) | String length | 2000 | — |
| | [ToUpper / ToLower](strings/README.md#toupper--tolower) | Change case | 2000 | — |
| | [Trim](strings/README.md#trim) | Strip leading/trailing spaces | 2000 | — |
| [System](system/README.md) | [IsAdmin](system/README.md#isadmin) | Running elevated? | Vista (XP fallback) | — |
| | [FindInPath](system/README.md#findinpath) | Locate a program like `cmd.exe` does | 2000 | — |

"Since" is the minimum Windows version; everything works on Windows 10 and 11.

## Using the library

### 1. Call the files (recommended while developing)

Point `BATLIB` at this folder once, then call functions by path:

```bat
if not defined BATLIB set "BATLIB=%~dp0..\BatchScriptReference\lib"
call "%BATLIB%\datetime\TimestampName.cmd" LOG "%TEMP%" "%~n0" log
call "%BATLIB%\files\EnsureDir.cmd" "%OUT%" || exit /b 1
```

`BATLIB` (not `LIB`, which the Visual Studio toolchain uses for linker paths) can also be set permanently with `setx BATLIB "C:\path\to\lib"`.

### 2. Inline them (for self-contained scripts)

Add a label with the function's name at the bottom of your script and paste the file's contents below it (the `@echo off` line can be dropped). Then `call :Name …` instead of `call "%BATLIB%\…\Name.cmd" …`:

```bat
@echo off
setlocal EnableExtensions
call :StrLen LEN myVar
echo %LEN%
exit /b 0

:StrLen
:: ===== pasted from lib\strings\StrLen.cmd =====
setlocal EnableExtensions EnableDelayedExpansion
...
exit /b 0
```

This works because each function:

- refers to its arguments only via `%1`…`%n` (which `CALL :label` supplies just like a file call);
- prefixes its internal labels with its own name (`:Trim_lead`, `:ParseArgs_next`) so they can't collide;
- ends with `exit /b`.

Functions with **dependencies** call their siblings via `call "%~dp0Sibling.cmd"` (or `"%~dp0..\group\Sibling.cmd"`). When inlining one, change those lines to `call :Sibling` and inline the sibling too. The test suite verifies that `ParseArgs` works when inlined.

## Conventions

| Topic | Convention |
|---|---|
| File | One function per file, `PascalCase.cmd`, CRLF line endings, grouped by area in sub-folders |
| Header | `::` comment block: signature, purpose, ERRORLEVELs, minimum Windows version, dependencies, link to its doc entry |
| First line of the body | `setlocal EnableExtensions DisableDelayedExpansion` (or `EnableDelayedExpansion` when the algorithm needs it — never visible to the caller) |
| Outputs | **Argument 1 is the name of the output variable**. Result returned with `endlocal & set "%~1=%_r%"`. Extra outputs use the out-variable name plus a suffix (`outVar_TYPE`, `outVar_KEY`) |
| Inputs | String functions take input **by variable name** so special characters never pass through `CALL`. Paths and simple values are passed as quoted arguments |
| Action-only functions | No out-variable (e.g. `EnsureDir path`) |
| ERRORLEVEL | `0` success · `1` usage error (missing/invalid arguments) · `2`+ function-specific failure, documented per function. Boolean tests (`IsAdmin`) use 0 = true, 2 = false |
| Internal names | Variables prefixed `_` (`_r`, `_attr`); labels prefixed `FuncName_` |
| Dependencies | Only built-in Windows tools. No PowerShell, VBScript or downloads. WMIC only as a fallback |
| Tests | Every function has assertions in `tests/test-<group>.cmd` |

General limits of the return tunnel apply to every function: results containing `"` are not supported, and `!` in a result is lost if the **caller** has delayed expansion enabled ([why](../docs/10-functions.md#returning-values)).

## Testing

```bat
tests\run-tests.cmd             & rem all suites
tests\run-tests.cmd files       & rem tests\test-files*.cmd only
```

Exit code 0 when every assertion passes. The registry tests create and delete temporary keys under `HKCU`; the file tests work in `%TEMP%`.

## Adding a function

1. Create `lib/<group>/<Name>.cmd` following an existing file as the model (header block, `setlocal`, usage checks, `_`-prefixed internals, tunnelled result, `exit /b`).
2. Add assertions to `tests/test-<group>.cmd` (or a new `tests/test-<group>.cmd` — it is picked up automatically): success paths, each ERRORLEVEL, special characters.
3. Document it in `lib/<group>/README.md` using the same entry layout (Synopsis, Usage, Arguments, ERRORLEVEL, Since, Examples, How it works, Limitations), and add a row to the table above.
4. Run `tests\run-tests.cmd`.
