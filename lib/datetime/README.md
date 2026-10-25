[← Library](../README.md) · [← Index](../../README.md)

# Date & time

Locale-independent timestamps and unique, date-stamped file names.

| Function | Purpose |
|---|---|
| [GetTimestamp](#gettimestamp) | Current local date/time in a fixed, sortable format |
| [TimestampName](#timestampname) | A non-existent `prefix_YYYYMMDD_hhnnss.ext` path |

Tests: [`tests/test-datetime.cmd`](../../tests/test-datetime.cmd)

**Why not `%DATE%` / `%TIME%`?** Their format follows the user's regional settings (`24/10/2026` vs `10/24/2026` vs `2026-10-24`, `9:05:01,12` vs ` 9:05:01.12`), so substring parsing that works on one machine breaks on another — or under a service account with different settings. `WMIC OS GET LocalDateTime`, the classic fix, has been removed from current Windows 11 builds.

---

### GetTimestamp

Sets a variable to the current local date and time in a format you choose.

**Source:** [`GetTimestamp.cmd`](GetTimestamp.cmd)

**Usage**

```bat
call "%BATLIB%\datetime\GetTimestamp.cmd" outVar [format]
```

| Argument | Required | Meaning |
|---|---|---|
| `outVar` | yes | Variable to receive the formatted timestamp |
| `format` | no | Template with placeholders `YYYY` `MM` `DD` `hh` `nn` `ss` (case-insensitive). Default `YYYYMMDD_hhnnss` |

Placeholders: `YYYY` year · `MM` month · `DD` day · `hh` hour (00–23) · `nn` minutes (*n*, because `MM` is taken and replacement is case-insensitive) · `ss` seconds. All are zero-padded. Other characters are copied as-is.

| ERRORLEVEL | Meaning |
|---|---|
| 0 | OK |
| 1 | Usage error |
| 2 | Neither ROBOCOPY nor WMIC produced a valid timestamp |

**Since:** Windows Vista (ROBOCOPY). Falls back to WMIC, so it also works on XP.

**Examples**

```bat
call "%BATLIB%\datetime\GetTimestamp.cmd" TS
echo %TS%                                          & rem 20261024_193931

call "%BATLIB%\datetime\GetTimestamp.cmd" ISO "YYYY-MM-DDThh:nn:ss"
echo %ISO%                                         & rem 2026-10-24T19:39:31

call "%BATLIB%\datetime\GetTimestamp.cmd" TODAY "YYYY-MM-DD"
set "LOG=%~dp0logs\%TODAY%.log"

rem Parts for arithmetic (strip leading zeros before SET /A!)
call "%BATLIB%\datetime\GetTimestamp.cmd" HOUR "hh"
set /a "HOUR=1%HOUR% - 100"
if %HOUR% geq 18 echo Out of hours
```

**How it works.** `robocopy "|" . /njh /njs` fails immediately on the invalid source and prints its error line, which always starts with a timestamp in the fixed form `yyyy/MM/dd HH:mm:ss` (local time) regardless of locale. `FOR /F "tokens=1-6 delims=/: "` splits it into six parts; a `FINDSTR` check makes sure they form exactly 14 digits before they are used. If that fails, `WMIC OS GET LocalDateTime /VALUE` is tried. The template is filled with `CALL SET` replacements. Nothing is copied or created by the ROBOCOPY call.

**Limitations.** One-second resolution. Takes about 60 ms per call (measured; it starts ROBOCOPY), so call it once and reuse the value rather than calling it per log line. Two calls in the same second return the same value — use [TimestampName](#timestampname) when names must be unique.

---

### TimestampName

Builds a full path `dir\prefix_YYYYMMDD_hhnnss.ext` that doesn't exist yet, adding `_2`, `_3`, … when needed.

**Source:** [`TimestampName.cmd`](TimestampName.cmd) · **Depends on:** [`GetTimestamp`](#gettimestamp)

**Usage**

```bat
call "%BATLIB%\datetime\TimestampName.cmd" outVar dir [prefix] [ext]
```

| Argument | Required | Meaning |
|---|---|---|
| `outVar` | yes | Variable to receive the full path |
| `dir` | yes | Directory for the file (relative paths resolve against the current dir; `.` for current) |
| `prefix` | no | Text before the timestamp; an `_` separator is added. Omit or `""` for none |
| `ext` | no | Extension, with or without the dot. Omit or `""` for none |

| ERRORLEVEL | Meaning |
|---|---|
| 0 | OK |
| 1 | Usage error |
| 2 | Timestamp failed (see GetTimestamp) |
| 3 | No free name after `_999` |

**Since:** Windows Vista (via GetTimestamp).

**Examples**

```bat
call "%BATLIB%\datetime\TimestampName.cmd" LOGFILE "%TEMP%" "%~n0" log
rem -> C:\Users\me\AppData\Local\Temp\myscript_20261024_193931.log
>>"%LOGFILE%" echo Started

rem Unique export names, even several per second
for %%T in (users groups) do (
    call "%BATLIB%\datetime\TimestampName.cmd" OUT "D:\exports" %%T csv
    call :Export %%T
)

rem Make sure the folder exists first
call "%BATLIB%\files\EnsureDir.cmd" "D:\exports" || exit /b 1
```

**How it works.** Normalises `dir` with `%~f2`, strips a trailing `\`, gets a timestamp, then loops `IF EXIST` with an increasing suffix until it finds a free name.

**Limitations.** Neither the file nor the directory is created, so two processes running at the same second could pick the same name — create the file immediately (`type nul >"%OUT%"`) if that matters. When inlining, change `call "%~dp0GetTimestamp.cmd"` to `call :GetTimestamp` and inline that too.
