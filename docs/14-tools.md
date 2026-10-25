[← Index](../README.md) · [← Strings](13-strings.md) · Next: [Pitfalls checklist →](15-pitfalls.md)

# 14. Built-in tools

Executables that ship with Windows and fill the gaps in `cmd.exe`. Only tools available by default on Windows 10 are listed; **Since** notes mark anything introduced after XP. Run `tool /?` for the full syntax — this page covers what you need in scripts and the traps.

| Area | Tools |
|---|---|
| Registry | [REG](#reg) |
| Copying & files | [ROBOCOPY](#robocopy) · [XCOPY](#xcopy) · [FORFILES](#forfiles) · [ATTRIB](#attrib) · [MKLINK](#mklink) · [ICACLS](#icacls) · [TAR](#tar) |
| Searching | [WHERE](#where) · [FINDSTR](#findstr) · [FIND](#find) |
| Text & data | [SORT](#sort) · [CLIP](#clip) · [CERTUTIL](#certutil) · [FC](#fc) |
| Interaction & timing | [CHOICE](#choice) · [TIMEOUT](#timeout) |
| Processes, services, tasks | [TASKLIST / TASKKILL](#tasklist--taskkill) · [SC](#sc) · [SCHTASKS](#schtasks) |
| Identity & system | [WHOAMI](#whoami) · [NET](#net) · [SETX](#setx) · [HOSTNAME / VER / SYSTEMINFO](#hostname--ver--systeminfo) |
| Network | [CURL](#curl) · [PING](#ping) |
| Deprecated | [WMIC](#wmic-deprecated) |

---

## REG

Read and write the registry. **Since:** XP (2000: Support Tools).

```bat
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuild
reg query "HKCU\Software\MyApp" /ve                       & rem (Default) value
reg query "HKCU\Software\MyApp" /s                        & rem recursive
reg query "HKLM\...\Uninstall" /s /f "Git" /d             & rem search data (Vista+)
reg add "HKCU\Software\MyApp" /v Path /t REG_SZ /d "C:\Apps\MyApp\\" /f
reg add "HKCU\Software\MyApp" /v Count /t REG_DWORD /d 5 /f
reg delete "HKCU\Software\MyApp" /v Path /f
reg delete "HKCU\Software\MyApp" /f                       & rem whole key
reg export "HKCU\Software\MyApp" backup.reg /y
reg import backup.reg
```

- Root keys: `HKLM`, `HKCU`, `HKCR`, `HKU`, `HKCC` (local); `\\computer\HKLM` remote.
- Exit code: 0 success, 1 failure (missing key/value, access denied).
- **Output format** of a value line: 4 spaces, name, 4 spaces, type, 4 spaces, data. `REG_DWORD` is printed as hex (`0x2a`) — `set /a n=0x2a` converts. `REG_EXPAND_SZ` is printed unexpanded — `call set "v=%v%"` expands it. An unset `(Default)` value prints the localised text *(value not set)* with exit code 0.
- **`\"` is an escaped quote** for REG's own parser: `/d "C:\dir\"` stores `C:\dir"` plus the rest of the line. Double a trailing backslash: `/d "C:\dir\\"`. To store a quote: `/d "\"C:\x.exe\" -arg"`.
- `/f` with `/d` searches data, `/k` key names, `/v` with `/f` value names; `/e` exact, `/c` case-sensitive. Matching is a case-insensitive substring by default.
- **32/64-bit view:** `/reg:32` / `/reg:64` select the WOW64 view explicitly (present on Windows 7+). Without them, a 32-bit process sees `HKLM\SOFTWARE\WOW6432Node` as `HKLM\SOFTWARE`. Even `ProductName` differs between views on some systems (verified: *Windows 10 Pro* vs *Windows 10 Enterprise*); and note `ProductName` says "Windows 10" on Windows 11 — use `CurrentBuild` (≥ 22000 is Windows 11).
- Writing to `HKLM` needs elevation.

Library: [`RegQueryValue`](../lib/registry/README.md#regqueryvalue), [`FindAppPath`](../lib/registry/README.md#findapppath), [`FindInstallPath`](../lib/registry/README.md#findinstallpath).

## ROBOCOPY

Robust file copy. **Since:** Vista (XP/2003: Resource Kit).

```bat
robocopy "C:\src" "D:\dst" /E                              & rem copy tree incl. empty dirs
robocopy "C:\src" "D:\dst" /MIR /R:2 /W:5                   & rem mirror (DELETES extras in dst)
robocopy "C:\src" "D:\dst" *.log /S /MOV /MINAGE:30          & rem move .log files older than 30 days
robocopy "C:\src" "D:\dst" /MIR /XD .git bin obj /XF *.tmp   & rem exclusions
robocopy "C:\src" "D:\dst" /MIR /L                           & rem dry run: list only
robocopy "C:\src" "D:\dst" file.txt                          & rem copy one file (dir, dir, name!)
robocopy "C:\src" "D:\dst" /E /MT:16 /NP /NFL /NDL /LOG+:"%LOG%"
```

| Option | Meaning |
|---|---|
| `/S` / `/E` | Subdirectories (non-empty / including empty) |
| `/MIR` | `/E` + `/PURGE`: delete files/dirs in destination not in source |
| `/MOV` / `/MOVE` | Delete source files / files and dirs after copying |
| `/XF` / `/XD` | Exclude files / directories (names, paths or wildcards) |
| `/XO` `/XN` `/XC` | Exclude older / newer / changed files |
| `/MAXAGE:n` `/MINAGE:n` | Exclude files newer / older than n days (or YYYYMMDD) |
| `/R:n /W:s` | Retries and wait. **Defaults are 1,000,000 retries × 30 s** — always set them |
| `/Z` `/B` `/ZB` | Restartable / backup mode (admin) / try restartable then backup |
| `/COPY:DAT` `/DCOPY:T` `/COPYALL` | What to copy: Data, Attributes, Timestamps, S=ACLs, O=owner, U=auditing |
| `/MT[:n]` | Multithreaded, default 8 threads (**Since:** Windows 7) |
| `/L` | List only — dry run |
| `/NP /NFL /NDL /NJH /NJS` | No progress %, no file list, no dir list, no header, no summary |
| `/LOG:f` `/LOG+:f` `/UNILOG:f` `/TEE` | Log to file (overwrite / append / Unicode); `/TEE` also to console |

**Exit codes are a bitmask:** 0 nothing to do, 1 copied, 2 extras, 4 mismatches, 8 failures, 16 fatal. **< 8 is success.** Test with `if errorlevel 8`. A trailing backslash before a closing quote (`"D:\"`) is read as an escaped quote — use `"D:\."` or no trailing `\`.

Library: [`MirrorDir`](../lib/files/README.md#mirrordir). Also handy: robocopy's error line timestamp is locale-independent — [`GetTimestamp`](../lib/datetime/README.md#gettimestamp) uses it.

## XCOPY

Older copy tool, still present. Prefer ROBOCOPY.

```bat
xcopy "C:\src" "D:\dst\" /E /I /H /Y /Q        & rem tree; /I: dst is a directory
echo F| xcopy "a.txt" "D:\new\b.txt" /Y         & rem answer the "File or Directory?" prompt
xcopy "src\*" "dst\" /D /L /Y                    & rem /D /L: list files newer than dst
```

Exit codes: 0 ok, 1 no files found, 2 Ctrl+C, 4 initialisation error, 5 write error. Fails on paths > 260 characters and certain files that ROBOCOPY handles.

## FORFILES

Run a command per file, with date filtering. **Since:** Vista (2003: built-in).

```bat
forfiles /p "C:\logs" /m *.log /d -30 /c "cmd /c del @path"      & rem older than 30 days
forfiles /p "C:\logs" /s /m *.* /d +2026-01-01 /c "cmd /c echo @fdate @path"
forfiles /p "C:\logs" /m *.log /c "cmd /c if @fsize gtr 1048576 echo @file"
```

- Variables: `@file @fname @ext @path @relpath @isdir @fsize @fdate @ftime` (quoted ones: `@file @fname @ext @path @relpath`).
- `/d -N` = last modified ≤ today − N days (date only, no time). `/d +dd/mm/yyyy` uses the **locale date format**; `yyyy-mm-dd` form varies — prefer `-N`.
- Returns 1 and prints *"ERROR: No files found…"* when nothing matches; also prints a blank line first.
- **No UNC paths** for `/p` — `pushd \\server\share` first.
- `/p "C:\"` fails (`\"` again) — use `/p "C:\."`.
- `/c` interprets `0xHH` as a character: `echo 0x09` prints a TAB (see [Strings](13-strings.md#special-characters-quotes-newline-tab)).
- Slow: starts a `cmd.exe` per file.

Library: [`DeleteOlderThan`](../lib/files/README.md#deleteolderthan).

## ATTRIB

```bat
attrib +r "file.txt"                 & rem read-only
attrib -h -s "C:\path\*" /s /d       & rem unhide recursively, incl. directories
```

`+R +H +S +A` and minus; `/S` recurse, `/D` include directories, `/L` act on symlink itself.

## MKLINK

**Since:** Vista.

```bat
mklink "link.txt" "target.txt"       & rem file symlink
mklink /D "linkdir" "C:\target"      & rem directory symlink
mklink /J "junction" "C:\target"     & rem junction: local dirs only, no admin needed
mklink /H "hard.txt" "target.txt"    & rem hard link: same volume, no admin needed
```

Symlinks need admin rights or Developer Mode (**Since:** Windows 10 1703). Delete a directory link with `rd "linkdir"` — **not** `rd /s`, which may delete the target's contents.

## ICACLS

Permissions. **Since:** Vista (2003 SP2; XP: `CACLS`).

```bat
icacls "D:\data" /grant "Users:(OI)(CI)RX" /T
icacls "D:\data" /inheritance:r /grant:r "%USERNAME%:(OI)(CI)F"
icacls "D:\data" /save acl.txt /T & icacls "D:\" /restore acl.txt
icacls "D:\data" /reset /T /C /Q
```

Rights: `F` full, `M` modify, `RX` read+execute, `R`, `W`; inheritance `(OI)` files, `(CI)` folders, `(IO)` inherit only. `/T` recurse, `/C` continue on errors, `/Q` quiet. Use SIDs (`*S-1-5-32-545` = Users) for language-independent scripts.

## TAR

`bsdtar`. **Since:** Windows 10 1803.

```bat
tar -a -cf archive.zip folder        & rem -a: format from extension (zip)
tar -czf archive.tar.gz folder
tar -xf archive.zip -C "D:\out"
tar -tf archive.zip                  & rem list
```

Built-in alternative before 1803: `MAKECAB`/`EXPAND` for `.cab` files only.

## WHERE

Locate files on `PATH` or in a tree. **Since:** Vista (2003).

```bat
where git                            & rem all matches on PATH (with PATHEXT)
where /q git || echo git not installed
where /r "C:\Program Files" msbuild.exe
for /f "delims=" %%P in ('where git 2^>nul') do (set "GIT=%%P" & goto :gotgit)
```

Exit code 0 found, 1 not found, 2 error. Like `cmd`, it lists the current directory first. Pure-batch alternative: [`FindInPath`](../lib/system/README.md#findinpath).

## FINDSTR

Search text with (limited) regular expressions.

```bat
findstr /i /c:"connection failed" app.log           & rem literal phrase (with spaces)
findstr /i "error warn" app.log                     & rem error OR warn (space = OR!)
findstr /r /c:"^[0-9][0-9]*$" numbers.txt            & rem whole-line digits
findstr /s /i /m "TODO" *.cs                         & rem /m: file names only, /s: recurse
findstr /v /g:exclude.txt input.txt                  & rem drop lines matching any pattern in file
findstr /n "^" file.txt                              & rem number every line (incl. empty)
echo(%VAL%| findstr /r /x "[A-Z][A-Z0-9_]*" >nul && echo valid identifier
```

| Option | Meaning |
|---|---|
| `/c:"text"` | Literal search string (spaces included). Without it, **spaces separate alternative search strings** |
| `/r` `/l` | Regex (default) / literal |
| `/i` `/v` `/x` `/b` `/e` | Ignore case / non-matching lines / whole line / at start / at end |
| `/n` `/m` `/c` (count: use FIND) | Line numbers / file names only |
| `/s` `/g:file` `/f:file` | Recurse / patterns from file / files to search from file |

**Regex support is minimal:** `.` `*` (zero or more of the previous) `^` `$` `[class]` `[^class]` `[x-y]` `\<` `\>` `\x` escape. **No** `+`, `?`, `{n}`, `|` alternation, or groups. `[a-z]` ranges use collation order and may match some upper-case letters — list characters explicitly (`[abcdefghijklmnopqrstuvwxyz]`) when it matters. Exit code 0 = found, 1 = not found. Long lines, and searches with many literal strings, have known bugs — test on your data.

## FIND

```bat
find /i "error" app.log
find /c /v "" < file.txt             & rem count lines (incl. empty)
type file.txt | find /v "#"          & rem drop lines containing #
```

Literal only. `/c` count, `/v` invert, `/i` ignore case, `/n` line numbers. With a file argument it prints a `---------- FILE` header; read from stdin (`<`) to avoid it.

## SORT

```bat
sort /r names.txt                   & rem reverse
sort /+10 data.txt                  & rem sort by column 10 onwards
dir /b | sort /o sorted.txt
```

Case-insensitive, locale-aware. `/unique` (**Since:** Windows 10) removes duplicates. Max line length 4096 by default (`/rec`).

## CLIP

Copy stdin to the clipboard. **Since:** Vista (2003).

```bat
echo %CD%| clip
type report.txt | clip
```

No built-in paste command.

## CERTUTIL

Certificate tool with useful side features. Ships with Vista+ (XP: Admin Pack).

```bat
certutil -hashfile "setup.exe" SHA256          & rem Windows 7+: algorithm argument
certutil -encode input.bin output.b64          & rem base64 (with BEGIN/END lines)
certutil -decode input.b64 output.bin
```

Parse the hash from line 2: `for /f "skip=1 delims=" %%H in ('certutil -hashfile "%F%" SHA256') do (set "HASH=%%H" & goto :gothash)` (older versions print it with spaces — remove them: `set "HASH=%HASH: =%"`). Security tools often flag `certutil -decode`/`-urlcache` as suspicious.

## FC

```bat
fc /b a.bin b.bin >nul && echo identical
fc /l /c a.txt b.txt                  & rem text compare, ignore case
```

Exit code 0 same, 1 different, 2 error. (`COMP` is an older alternative.)

## CHOICE

Single-key prompt with optional timeout. **Since:** Vista (absent in 2000/XP).

```bat
choice /c ync /n /m "Overwrite? [Y]es [N]o [C]ancel "
if errorlevel 3 goto :Cancel
if errorlevel 2 goto :No
rem Y
choice /c yn /t 10 /d n /m "Continue (auto-No in 10s)"
```

`ERRORLEVEL` = 1-based index of the key in `/c`; test highest first. `/n` hides the `[Y,N]?` suffix, `/cs` case-sensitive. Non-interactive sessions: always supply `/t` and `/d`.

## TIMEOUT

**Since:** Vista (2003).

```bat
timeout /t 10                  & rem wait 10 s, key press skips
timeout /t 10 /nobreak >nul    & rem only Ctrl+C interrupts
timeout /t -1                  & rem wait for a key
```

**Fails immediately when stdin is redirected** (*"ERROR: Input redirection is not supported"*, exit code 1; verified) — e.g. under some schedulers or `<nul`. Portable sleep: `ping -n 11 127.0.0.1 >nul` (≈ 10 s).

## TASKLIST / TASKKILL

**Since:** XP Professional (not XP Home).

```bat
tasklist /fi "imagename eq notepad.exe" | find /i "notepad.exe" >nul && echo running
tasklist /fo csv /nh /fi "pid eq 1234"
taskkill /im notepad.exe /f
taskkill /pid 1234 /t /f           & rem with child processes
```

`TASKLIST` with no match still exits 0 and prints an *INFO:* line — test the output, not the exit code. `TASKKILL` exit code 128 = not found.

## SC

Service control. **Since:** XP.

```bat
sc query "Spooler" | find "RUNNING" >nul && echo running
sc stop "Spooler" & sc start "Spooler"
sc config "Spooler" start= demand            & rem note the space after "start="!
sc qc "Spooler"                              & rem configuration
```

`start= auto|demand|disabled|delayed-auto`: the `=` is part of the option name and **must** be followed by a space. `stop`/`start` return immediately (state *STOP_PENDING*); poll `sc query` to wait. `NET STOP name` / `NET START name` wait for completion.

## SCHTASKS

**Since:** XP.

```bat
schtasks /create /tn "MyJob" /tr "\"C:\Scripts\job.cmd\" --quiet" /sc daily /st 02:00 /ru SYSTEM /f
schtasks /run /tn "MyJob"
schtasks /query /tn "MyJob" /fo list /v
schtasks /delete /tn "MyJob" /f
```

Tasks start in `System32` with no console: use `%~dp0` in the script, log to a file, avoid `PAUSE`/`TIMEOUT`. Quote paths inside `/tr` with `\"`.

## WHOAMI

**Since:** Vista (XP: Support Tools).

```bat
whoami                              & rem DOMAIN\user
whoami /user /fo csv /nh            & rem SID
whoami /groups | find "S-1-16-12288" >nul && echo elevated
```

Library: [`IsAdmin`](../lib/system/README.md#isadmin).

## NET

```bat
net session >nul 2>&1 && echo admin          & rem classic admin check (needs Server service)
net use Z: \\server\share /persistent:no
net use Z: /delete /y
net user %USERNAME% /domain
net localgroup Administrators
```

## SETX

Persistent environment variables. **Since:** Vista (XP: Support Tools).

```bat
setx MYAPP_HOME "C:\Apps\MyApp"              & rem user
setx MYAPP_HOME "C:\Apps\MyApp" /M           & rem machine (admin)
```

Doesn't affect the current session; **truncates at 1024 characters**; never use it to append to `PATH`. See [Environment](03-environment.md#environment-inheritance-and-persistence).

## HOSTNAME / VER / SYSTEMINFO

```bat
for /f %%H in ('hostname') do set "HOST=%%H"
for /f "tokens=4-6 delims=[]. " %%a in ('ver') do set "WINVER=%%a.%%b.%%c"   & rem e.g. 10.0.26300
systeminfo /fo csv | more +1                & rem slow (seconds)
```

`VER` output wording is localised; the token positions above work for English. For the build number, prefer `reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuild`.

## CURL

**Since:** Windows 10 1803.

```bat
curl -fsSL -o "%TEMP%\file.zip" "https://example.com/file.zip" || echo download failed
curl -s -o nul -w "%%{http_code}" "https://example.com/health"
```

`-f` makes HTTP errors return non-zero. In batch files write `%%{http_code}`. Corporate proxies: `--proxy`, or `-x`.

## PING

```bat
ping -n 1 -w 1000 server01 | find "TTL=" >nul && echo reachable
ping -n 6 127.0.0.1 >nul                     & rem ~5 second sleep, works everywhere
```

Test for `TTL=` rather than the exit code: "Destination host unreachable" replies can still exit 0.

## WMIC (deprecated)

Deprecated in Windows 10 21H2, disabled by default in Windows 11 23H2/24H2, and **removed** from supported Windows 11 versions in 2026 (Microsoft KB5067470). Don't use it in new scripts; keep it only as a fallback for XP-era systems (as [`GetTimestamp`](../lib/datetime/README.md#gettimestamp) does). Replacements: `REG`, `SC`, `TASKLIST`, `ROBOCOPY` tricks — or PowerShell where allowed.

---

See also: [Library](../lib/README.md) · [Environment](03-environment.md) · [Redirection & errors](12-redirection-errors.md#exit-codes-of-common-tools)
