[← Library](../README.md) · [← Index](../../README.md)

# Registry

Read registry values and locate installed programs with `REG.EXE`.

| Function | Purpose |
|---|---|
| [RegQueryValue](#regqueryvalue) | Read one value (data and type) |
| [FindAppPath](#findapppath) | Full path of a program registered under *App Paths* |
| [FindInstallPath](#findinstallpath) | Install folder of a product listed in *Programs and Features* |

Tests: [`tests/test-registry.cmd`](../../tests/test-registry.cmd) (creates and removes temporary keys under `HKCU`) · Background: [docs/14-tools.md#reg](../../docs/14-tools.md#reg)

**Which lookup to use?**

| You know… | Use | Registry location |
|---|---|---|
| the executable name (`chrome.exe`, `excel.exe`) | FindAppPath | `HKCU`/`HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\<exe>` |
| the product name as shown in *Programs and Features* (`Git`, `7-Zip`) | FindInstallPath | `…\CurrentVersion\Uninstall\*` (HKLM, HKLM WOW6432Node, HKCU) |
| the vendor's own key | RegQueryValue | e.g. `HKLM\SOFTWARE\GitForWindows` → `InstallPath` |
| that it's on `PATH` | [`FindInPath`](../system/README.md#findinpath) | — |

---

### RegQueryValue

Reads a registry value into a variable, plus its type.

**Source:** [`RegQueryValue.cmd`](RegQueryValue.cmd)

**Usage**

```bat
call "%BATLIB%\registry\RegQueryValue.cmd" outVar key [valueName] [32|64]
```

| Argument | Required | Meaning |
|---|---|---|
| `outVar` | yes | Receives the data. `outVar_TYPE` receives the type (`REG_SZ`, `REG_DWORD`, …) |
| `key` | yes | Full key, e.g. `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion` (short or long root names) |
| `valueName` | no | Value to read. Omit or `""` for the key's `(Default)` value |
| `32` / `64` | no | Force the 32- or 64-bit registry view (`REG /reg:32`, `/reg:64`) |

| ERRORLEVEL | Meaning |
|---|---|
| 0 | OK |
| 1 | Usage error |
| 2 | Key or value not found (or access denied) |

**Since:** Windows XP; the 32/64 view option needs Windows 7+.

**Data formats** (as REG prints them):

| Type | Returned as | Convert |
|---|---|---|
| `REG_SZ` | text | — |
| `REG_EXPAND_SZ` | text with unexpanded `%VARS%` | `call set "v=%v%"` |
| `REG_DWORD`, `REG_QWORD` | hex, e.g. `0x2a` | `set /a "n=v"` (DWORD only — QWORD exceeds 32 bits) |
| `REG_MULTI_SZ` | items joined with `\0` | `set "v=%v:\0=;%"` |
| `REG_BINARY` | hex digits | — |

**Examples**

```bat
call "%BATLIB%\registry\RegQueryValue.cmd" BUILD "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" CurrentBuild
if %BUILD% geq 22000 (echo Windows 11) else echo Windows 10 or older

call "%BATLIB%\registry\RegQueryValue.cmd" GIT "HKLM\SOFTWARE\GitForWindows" InstallPath
if not errorlevel 1 echo Git at %GIT%
rem NOT "... InstallPath && echo %GIT%" - %GIT% would expand before the CALL runs

call "%BATLIB%\registry\RegQueryValue.cmd" V "HKCU\Software\MyApp" Timeout
if errorlevel 1 (set "V=30") else set /a "V=V"     & rem default 30, DWORD hex -> decimal

rem Read the 64-bit view from a possibly 32-bit cmd.exe
call "%BATLIB%\registry\RegQueryValue.cmd" PF "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion" ProgramFilesDir 64
```

**How it works.** Runs `REG QUERY key /v name` (or `/ve`), keeps the line containing `    REG_`, removes everything up to the type with `%line:*    REG_=%`, then splits the remainder `SZ    data` with `FOR /F "tokens=1,*"`.

**Limitations.** Leading spaces in the data are lost. Data containing `"` breaks the result. An **unset** `(Default)` value returns the localised text *(value not set)* rather than an error — REG reports success. Value names containing `    REG_` (four spaces) would confuse the parser.

---

### FindAppPath

Finds the full path of a program from its *App Paths* registration — the mechanism that lets `Win+R → excel` work without `PATH`.

**Source:** [`FindAppPath.cmd`](FindAppPath.cmd) · **Depends on:** [`RegQueryValue`](#regqueryvalue)

**Usage**

```bat
call "%BATLIB%\registry\FindAppPath.cmd" outVar exeName
```

| Argument | Required | Meaning |
|---|---|---|
| `outVar` | yes | Receives the full path of the executable (unquoted, environment variables expanded) |
| `exeName` | yes | `excel.exe` or `excel` (`.exe` is added when there is no extension) |

| ERRORLEVEL | Meaning |
|---|---|
| 0 | Found and the file exists |
| 1 | Usage error |
| 2 | Not registered |
| 3 | Registered, but the file doesn't exist |

**Since:** Windows XP.

**Examples**

```bat
call "%BATLIB%\registry\FindAppPath.cmd" EXCEL excel || (echo Excel is not installed & exit /b 1)
"%EXCEL%" /e "%REPORT%"

rem Try App Paths first, then PATH
call "%BATLIB%\registry\FindAppPath.cmd" TOOL 7z.exe || call "%BATLIB%\system\FindInPath.cmd" TOOL 7z.exe
```

**How it works.** Queries the `(Default)` value of `HKCU\…\App Paths\<exe>`, then `HKLM\…`; removes quotes; expands `%VARS%` with `CALL SET`; checks the file exists.

**Limitations.** Many programs don't register App Paths. Store/UWP apps use a different mechanism. Only the default value is read (some entries also set a `Path` value with directories to add to `PATH`).

---

### FindInstallPath

Finds the install folder of an installed product by (part of) its display name in *Programs and Features*.

**Source:** [`FindInstallPath.cmd`](FindInstallPath.cmd) · **Depends on:** [`RegQueryValue`](#regqueryvalue)

**Usage**

```bat
call "%BATLIB%\registry\FindInstallPath.cmd" outVar displayName
```

| Argument | Required | Meaning |
|---|---|---|
| `outVar` | yes | Receives the install folder (no trailing `\`). `outVar_KEY` receives the product's registry key |
| `displayName` | yes | Text contained in the product's `DisplayName`, case-insensitive (e.g. `"Notepad++"`, `"Microsoft Visual Studio Code"`) |

| ERRORLEVEL | Meaning |
|---|---|
| 0 | OK |
| 1 | Usage error |
| 2 | No product's `DisplayName` contains the text |
| 3 | Product found, but it records neither `InstallLocation` nor `DisplayIcon` |

**Since:** Windows Vista (`REG QUERY /F`).

**Examples**

```bat
call "%BATLIB%\registry\FindInstallPath.cmd" NPP "Notepad++" || (echo Notepad++ not found & exit /b 1)
"%NPP%\notepad++.exe" "%FILE%"

rem Read other details of the same product
call "%BATLIB%\registry\FindInstallPath.cmd" GITDIR "Git"
call "%BATLIB%\registry\RegQueryValue.cmd" GITVER "%GITDIR_KEY%" DisplayVersion
echo Git %GITVER% in %GITDIR%
```

**How it works.**

1. For each Uninstall root — `HKLM\SOFTWARE\…` (64-bit apps), `HKLM\SOFTWARE\WOW6432Node\…` (32-bit apps on 64-bit Windows), `HKCU\Software\…` (per-user installs) — runs `REG QUERY root /s /f "text" /d`, which lists every value whose **data** contains the text.
2. Tracks the current key from lines starting with `HKEY_` and accepts the first match on a value named `DisplayName` (matches in `Publisher`, `URLInfoAbout`, etc. are ignored).
3. Reads `InstallLocation`; if it's empty, takes the folder part of `DisplayIcon` (usually `"C:\…\app.exe",0`).

**Limitations.** First match wins — make the text specific (`"Git"` would also match `"GitHub Desktop"` if listed first). Not every installer records `InstallLocation` or `DisplayIcon`, and `DisplayIcon` sometimes points to a shared icon file elsewhere. From a **32-bit** `cmd.exe` on 64-bit Windows the first root is redirected to `WOW6432Node`, so 64-bit-only products are missed — run from 64-bit `cmd` ([docs](../../docs/03-environment.md#32-bit-vs-64-bit)). The search can take a second or two on machines with many products.
