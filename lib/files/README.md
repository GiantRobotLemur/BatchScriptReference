[← Library](../README.md) · [← Index](../../README.md)

# Files & directories

| Function | Purpose |
|---|---|
| [EnsureDir](#ensuredir) | Create a directory tree if it doesn't exist |
| [NormalizePath](#normalizepath) | Absolute, clean form of a path |
| [GetTempFile](#gettempfile) | Create a uniquely named empty file in `%TEMP%` |
| [BackupFile](#backupfile) | Copy a file to a timestamped name |
| [MirrorDir](#mirrordir) | Make a directory an exact copy of another (ROBOCOPY /MIR) |
| [DeleteOlderThan](#deleteolderthan) | Delete files older than N days |
| [RotateFiles](#rotatefiles) | Keep only the newest N files matching a mask |

Tests: [`tests/test-files.cmd`](../../tests/test-files.cmd) · Background: [docs/14-tools.md](../../docs/14-tools.md)

Directory tests in this group use the `~a` attribute modifier (`d` as the first character means directory; empty means missing) — it distinguishes files from directories, which `IF EXIST` alone does not.

---

### EnsureDir

Creates a directory, including missing parents, unless it already exists.

**Source:** [`EnsureDir.cmd`](EnsureDir.cmd)

**Usage**

```bat
call "%BATLIB%\files\EnsureDir.cmd" path
```

| Argument | Required | Meaning |
|---|---|---|
| `path` | yes | Directory to create; relative to the current directory if not absolute; a trailing `\` is fine |

| ERRORLEVEL | Meaning |
|---|---|
| 0 | Directory exists (already, or now) |
| 1 | Usage error |
| 2 | `path` exists as a **file** |
| 3 | Could not create (access denied, invalid name, missing drive) |

**Since:** Windows 2000.

**Examples**

```bat
call "%BATLIB%\files\EnsureDir.cmd" "%OUT%\reports\%YEAR%" || (echo Cannot create output dir & exit /b 1)

call "%BATLIB%\files\EnsureDir.cmd" "%LOGDIR%"
if errorlevel 2 echo %LOGDIR% is a file, not a directory
```

**How it works.** Reads the attribute string with `%~a1`: empty → create with `MKDIR` (which creates intermediate directories when extensions are enabled); starts with `d` → done; otherwise it's a file. After `MKDIR`, `IF EXIST "path\"` confirms the directory exists.

---

### NormalizePath

Converts a path to its absolute, canonical text form.

**Source:** [`NormalizePath.cmd`](NormalizePath.cmd)

**Usage**

```bat
call "%BATLIB%\files\NormalizePath.cmd" outVar path
```

| Argument | Required | Meaning |
|---|---|---|
| `outVar` | yes | Variable to receive the result |
| `path` | yes | Any path; needn't exist |

| ERRORLEVEL | Meaning |
|---|---|
| 0 | OK |
| 1 | Usage error |

**Since:** Windows 2000.

**Examples**

```bat
call "%BATLIB%\files\NormalizePath.cmd" ROOT "%~dp0..\.."
rem C:\work\repo\tools\build\..\.. -> C:\work\repo

call "%BATLIB%\files\NormalizePath.cmd" P "C:/Program Files/App/"
rem -> C:\Program Files\App
```

Verified results (current dir `C:\work`): `x\..\y\.\z\` → `C:\work\y\z`; `C:/Windows/System32` → `C:\Windows\System32`; `C:\` → `C:\`; `*.txt` → `C:\work\*.txt` (no wildcard expansion).

**How it works.** `%~f2` resolves against the current directory and collapses `.`/`..`; then a trailing `\` is removed unless the result is a drive root.

**Limitations.** Doesn't resolve symlinks/junctions, short names, or letter case. `C:file` (drive-relative) resolves against the current directory **of drive C:**.

---

### GetTempFile

Creates an empty file with a unique name in `%TEMP%` and returns its path.

**Source:** [`GetTempFile.cmd`](GetTempFile.cmd)

**Usage**

```bat
call "%BATLIB%\files\GetTempFile.cmd" outVar [prefix] [ext]
```

| Argument | Required | Meaning |
|---|---|---|
| `outVar` | yes | Variable to receive the full path |
| `prefix` | no | Default `tmp` |
| `ext` | no | Default `.tmp`; dot optional |

| ERRORLEVEL | Meaning |
|---|---|
| 0 | OK — the file exists and is empty |
| 1 | Usage error |
| 2 | Could not create a file in 100 attempts (`%TEMP%` missing or not writable) |

**Since:** Windows 2000.

**Examples**

```bat
call "%BATLIB%\files\GetTempFile.cmd" TMPLIST "%~n0" txt || exit /b 1
dir /b /s "%SRC%\*.cs" > "%TMPLIST%"
findstr /i /g:"%PATTERNS%" "%TMPLIST%"
del "%TMPLIST%"
```

**How it works.** Builds `%TEMP%\prefix_<RANDOM><RANDOM>.ext`, retries if it exists, then creates it with `type nul >file` to reserve the name.

**Limitations.** The exists-then-create sequence isn't atomic (very unlikely to collide; `%RANDOM%%RANDOM%` gives ~10⁹ names). The caller must delete the file.

---

### BackupFile

Copies a file next to itself (or into a backup folder) under a timestamped name.

**Source:** [`BackupFile.cmd`](BackupFile.cmd) · **Depends on:** [`EnsureDir`](#ensuredir), [`TimestampName`](../datetime/README.md#timestampname)

**Usage**

```bat
call "%BATLIB%\files\BackupFile.cmd" outVar file [destDir]
```

| Argument | Required | Meaning |
|---|---|---|
| `outVar` | yes | Variable to receive the backup's full path |
| `file` | yes | File to back up |
| `destDir` | no | Destination folder (created if missing). Default: the file's folder |

| ERRORLEVEL | Meaning |
|---|---|
| 0 | OK |
| 1 | Usage error |
| 2 | Source missing or is a directory |
| 3 | Destination can't be created, or no free name |
| 4 | Copy failed |

**Since:** Windows Vista (via GetTimestamp).

**Examples**

```bat
rem Back up a config before editing it
call "%BATLIB%\files\BackupFile.cmd" BAK "%APPDIR%\app.config" || (echo Backup failed & exit /b 1)
echo Backup: %BAK%            & rem ...\app_20261024_193931.config

rem Keep backups of data.db in one place, and only the latest 10
call "%BATLIB%\files\BackupFile.cmd" BAK "%DATA%\data.db" "%DATA%\backups"
call "%BATLIB%\files\RotateFiles.cmd" "%DATA%\backups" "data_*.db" 10
```

**How it works.** Checks the source with `%~a2`, ensures the destination, asks TimestampName for `name_TIMESTAMP.ext` (from `%~n2` and `%~x2`), then `COPY /Y /B`. `COPY` preserves the last-modified time of the original.

---

### MirrorDir

Makes `dest` an exact copy of `source` using ROBOCOPY `/MIR`.

**Source:** [`MirrorDir.cmd`](MirrorDir.cmd)

> **Destructive:** files and folders in `dest` that are not in `source` are deleted. Try it with `/L` (list only) first.

**Usage**

```bat
call "%BATLIB%\files\MirrorDir.cmd" source dest [robocopy options...]
```

| Argument | Required | Meaning |
|---|---|---|
| `source` | yes | Existing source directory |
| `dest` | yes | Destination directory (created if missing) |
| options | no | Extra ROBOCOPY options appended after the defaults `/MIR /R:2 /W:5 /NP` |

| ERRORLEVEL | Meaning |
|---|---|
| 0 | Success (ROBOCOPY returned 0–7) |
| 1 | Usage error |
| 2 | Source is missing or not a directory |
| 8–16 | ROBOCOPY's failure code, unchanged (8 = some copies failed, 16 = fatal) |

**Since:** Windows Vista (ROBOCOPY).

**Examples**

```bat
rem Quiet mirror with exclusions, logged
call "%BATLIB%\files\MirrorDir.cmd" "%SRC%" "\\nas\backup\proj" /XD .git node_modules /XF *.tmp /NFL /NDL /LOG+:"%LOG%"
if errorlevel 1 (echo Mirror failed: %errorlevel% & exit /b 1)

rem Dry run: what would change?
call "%BATLIB%\files\MirrorDir.cmd" "%SRC%" "%DST%" /L
```

**How it works.** Validates the source, rewrites a trailing `\` as `\.` (so `"D:\"` isn't read by ROBOCOPY as an escaped quote), collects the remaining arguments with `SHIFT /3`, runs ROBOCOPY, and maps its bitmask exit code: below 8 is success.

**Limitations.** ROBOCOPY's console output is passed through — add `/NFL /NDL /NJH /NJS` or redirect to silence it. Retries are reduced to 2 × 5 s (ROBOCOPY's default is 1,000,000 × 30 s); override with your own `/R:` `/W:`.

---

### DeleteOlderThan

Deletes files matching a mask whose last-modified **date** is at least N days ago.

**Source:** [`DeleteOlderThan.cmd`](DeleteOlderThan.cmd)

**Usage**

```bat
call "%BATLIB%\files\DeleteOlderThan.cmd" dir mask days [/S]
```

| Argument | Required | Meaning |
|---|---|---|
| `dir` | yes | Directory to clean (not UNC — see limitations) |
| `mask` | yes | File mask, e.g. `*.log` or `*` |
| `days` | yes | Non-negative integer. `0` deletes everything matching, including today's files |
| `/S` | no | Also clean sub-directories (directories themselves are kept) |

| ERRORLEVEL | Meaning |
|---|---|
| 0 | OK, including "nothing to delete" |
| 1 | Usage error, or `days` not a number |
| 2 | `dir` missing or not a directory |

**Since:** Windows Vista (FORFILES).

**Examples**

```bat
rem Nightly cleanup: logs older than 14 days, recursively
call "%BATLIB%\files\DeleteOlderThan.cmd" "%APPDATA%\MyApp\logs" "*.log" 14 /S

rem UNC share: map it temporarily
pushd "\\server\share\drop" && (
    call "%BATLIB%\files\DeleteOlderThan.cmd" "." "*.zip" 30
    popd
)
```

**How it works.** Validates that `days` contains only digits (`FOR /F "delims=0123456789"` yields a token only if there's another character), then runs `FORFILES /P dir /M mask /D -days /C "cmd /c if @isdir==FALSE del /f /q @path"`. FORFILES' "no files found" error and exit code 1 are ignored.

**Limitations.** Granularity is whole days by calendar date, not 24-hour periods. FORFILES doesn't accept UNC paths. Deletion errors (locked or read-only files — `/F` handles read-only) are silent. Starts a `cmd.exe` per matching file: slow for thousands of files.

---

### RotateFiles

Keeps the newest N files matching a mask and deletes the rest.

**Source:** [`RotateFiles.cmd`](RotateFiles.cmd)

**Usage**

```bat
call "%BATLIB%\files\RotateFiles.cmd" dir mask keep
```

| Argument | Required | Meaning |
|---|---|---|
| `dir` | yes | Directory containing the files |
| `mask` | yes | File mask, e.g. `backup_*.zip` |
| `keep` | yes | Number of newest files to keep (`0` deletes all matches) |

| ERRORLEVEL | Meaning |
|---|---|
| 0 | OK |
| 1 | Usage error, or `keep` not a number |
| 2 | `dir` missing or not a directory |

**Since:** Windows 2000.

**Examples**

```bat
rem After writing a new log, keep the last 7
call "%BATLIB%\datetime\TimestampName.cmd" LOG "%LOGDIR%" "%~n0" log
call :Main > "%LOG%" 2>&1
call "%BATLIB%\files\RotateFiles.cmd" "%LOGDIR%" "%~n0_*.log" 7
```

**How it works.** `DIR /B /A-D /O-D` lists matching files newest first; `FOR /F "skip=N eol=: delims="` skips the first N and deletes the rest (`eol=:` because `:` can't occur in a file name, unlike the default `;`). `skip=0` is a syntax error, so the option is omitted when `keep` is 0. Leading zeros in `keep` are stripped.

**Limitations.** Order is by last-modified time; files with equal times are ordered arbitrarily. On volumes with 8.3 names, masks also match short names (`*.log` can match `x.logx`). Non-recursive.
