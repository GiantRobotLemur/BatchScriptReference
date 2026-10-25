[← Index](../README.md) · [← Conditional statements](06-conditionals.md) · Next: [Loops →](08-loops.md)

# 7. Condition tests

Every test `IF` can perform, with the exact semantics and traps of each.

- [String equality: ==](#string-equality-)
- [Comparison operators](#comparison-operators)
- [EXIST](#exist)
- [DEFINED](#defined)
- [ERRORLEVEL](#errorlevel)
- [CMDEXTVERSION](#cmdextversion)
- [Tests IF can't do directly](#tests-if-cant-do-directly)
- [Quick reference](#quick-reference)

---

## String equality: ==

```bat
if "%a%"=="%b%" echo same
if /i "%ext%"==".TXT" echo text file     & rem /I: case-insensitive
if not "%~1"=="" echo got an argument
```

- `==` is **always a string comparison**, exact and case-sensitive unless `/I`. `if 1==01` is false.
- Spaces around `==` are allowed: `if "%a%" == "%b%"`.
- **Always quote both sides.** Unquoted, an empty value gives `if ==x` (syntax error) and a value with spaces splits into extra tokens. The quotes are compared too, so quote both sides the same way.
- Quoting does not protect against a value that itself contains `"` — use `if defined` or delayed expansion (`if "!a!"=="!b!"`) for untrusted data.
- Use `%~1` (quotes removed) when comparing arguments: `if "%~1"=="/v"` works whether or not the user quoted the argument.

## Comparison operators

```bat
if %count% GTR 10 echo many
if /i "%name%" LSS "m" echo first half of the alphabet
```

| Operator | Meaning |
|---|---|
| `EQU` | equal |
| `NEQ` | not equal |
| `LSS` | less than |
| `LEQ` | less than or equal |
| `GTR` | greater than |
| `GEQ` | greater than or equal |

**Numeric or string?** If **both** operands are valid integers (decimal, `0x` hex, or `0` octal, optionally signed), the comparison is numeric; otherwise it is a string comparison. Verified examples:

| Test | Result | Why |
|---|---|---|
| `if 10 GTR 9` | true | numeric |
| `if "10" GTR "9"` | **false** | quotes make them strings; `"1…"` < `"9…"` |
| `if 1 EQU 01` | true | numeric (`01` is octal 1) |
| `if 08 EQU 8` | **false** | `08` is not a valid octal number → string comparison |
| `if 0x10 EQU 16` | true | hex |
| `if 10a LSS 9` | true | `10a` is not a number → string comparison |
| `if 2147483648 GTR 2147483647` | **false** | out-of-range values saturate to 2147483647 |

Consequences:

- **Do not quote numbers** you want compared numerically.
- **Strip leading zeros** from date/time parts before comparing.
- **Values over 2 GB don't compare correctly** (file sizes via `%~z1`!). Compare lengths first, or pad both to equal length and compare as strings:

```bat
rem Compare two non-negative integers of up to 20 digits as zero-padded strings
set "pa=00000000000000000000%a%" & set "pb=00000000000000000000%b%"
if "%pa:~-20%" GTR "%pb:~-20%" echo a is larger
```

- **String ordering is collation-based, not ASCII.** `if a LSS B` and `if A LSS b` are both true; `if Z LSS a` is false (verified). Case matters only as a tie-breaker; `/I` ignores it. Don't rely on string `LSS/GTR` for exact byte ordering.

## EXIST

```bat
if exist "C:\path\file.txt" echo file or directory exists
if exist "C:\path\*.log" echo at least one .log file
if exist "C:\path\dir\" echo dir is a directory
if exist "C:\path\dir\*" echo dir is a directory (also true when it's empty)
```

- Matches files **and** directories, including hidden and system ones (verified).
- Wildcards are allowed; true if anything matches. On volumes that still generate 8.3 short names, wildcards also match those — `*.htm` matches `x.html` (short name `X~1.HTM`).
- **Directory test:** append `\` — `if exist "%p%\"` is true only for directories (verified false for a file). Both `"dir\"` and `"dir\*"` are true for empty directories (verified).
- **File-not-directory test:** use the `~a` attribute modifier:

```bat
for %%A in ("%p%") do set "attr=%%~aA"
if not defined attr                 echo does not exist
if defined attr if "%attr:~0,1%"=="d" echo directory
if defined attr if not "%attr:~0,1%"=="d" echo file
```

  (The `if defined attr if "%attr:~0,1%"…` form is safe only because `attr` is guaranteed set or unset by the line before — see the undefined-substring trap in [Parsing](02-parsing-escaping.md#percent-expansion). The library's [`EnsureDir`](../lib/files/README.md#ensuredir) shows the robust `goto` form.)
- `IF EXIST` on a path to an unavailable network share can stall for tens of seconds.
- Cannot test for **devices** reliably (`if exist nul` is true everywhere, in every folder).

## DEFINED

```bat
if defined JAVA_HOME echo Java configured
if not defined OUT set "OUT=%CD%\out"
```

- Takes a variable **name**, not `%value%`. Never expands the value, so it is immune to special characters and is current inside blocks.
- True if the variable has any value. There is no defined-but-empty state.
- Dynamic variables (`CD`, `DATE`, `ERRORLEVEL`, …) count as defined. `if defined %name%` tests the variable whose name is in `name`.

## ERRORLEVEL

```bat
if errorlevel 1 echo failed                 & rem means ERRORLEVEL >= 1
if not errorlevel 1 echo succeeded          & rem means ERRORLEVEL < 1
if %errorlevel% neq 0 echo failed           & rem exact test (parse-time value!)
if %errorlevel% equ 3 echo exactly three
```

| Form | Semantics | Current inside blocks? |
|---|---|---|
| `if errorlevel N` | `ERRORLEVEL >= N` | **Yes** |
| `if %errorlevel% …` | exact, any comparison | No — expanded at parse time |
| `if !errorlevel! …` | exact, any comparison | Yes (needs delayed expansion) |

- `if errorlevel 1` misses **negative** exit codes (e.g. `-1`, or `0xC0000005` crashes = -1073741819). Prefer `if %errorlevel% neq 0` / `if !errorlevel! neq 0` when the program may return negatives.
- Test exact values from highest to lowest with the classic form:

```bat
robocopy ... 
if errorlevel 16 (echo fatal) else if errorlevel 8 (echo failures) else (echo ok)
```

- If someone did `set ERRORLEVEL=...`, `%ERRORLEVEL%` returns that variable instead of the real value — but `if errorlevel N` still reads the real one.

More on what sets and resets `ERRORLEVEL`: [Redirection & errors](12-redirection-errors.md#errorlevel-semantics).

## CMDEXTVERSION

```bat
if cmdextversion 2 echo extensions version 2 or later
```

True when command extensions are enabled and their version is ≥ N. Always 2 since Windows 2000, so this is only a test for "extensions are enabled".

## Tests IF can't do directly

| Need | Technique |
|---|---|
| Is a number | `for /f "delims=0123456789" %%A in ("%v%") do echo not a number` |
| Contains substring | `if not "!s:%sub%=!"=="!s!"` (delayed) or `echo(%s%\|find "%sub%" >nul` |
| Starts with | `if "%s:~0,3%"=="abc"` (s must be defined) |
| Regex match | `echo(%s%\|findstr /r /x "[0-9][0-9]*" >nul && echo digits` |
| File is empty | `for %%A in ("%f%") do if %%~zA equ 0 echo empty` |
| File is newer | `xcopy /d /l /y "%a%" "%b%"` output, or `forfiles /d`, or `robocopy /l` (no direct date compare) |
| Process running | `tasklist /fi "imagename eq app.exe" \| find /i "app.exe" >nul` |
| Service running | `sc query "Name" \| find "RUNNING" >nul` |
| Command available | `where /q tool` (Vista+) or [`FindInPath`](../lib/system/README.md#findinpath) |
| Running elevated | [`IsAdmin`](../lib/system/README.md#isadmin) |
| 64-bit OS | `if defined ProgramFiles(x86)` (careful: name contains parentheses — fine in `if defined`) |

See [Strings](13-strings.md) for substring tests in detail.

## Quick reference

| Test | True when | Notes |
|---|---|---|
| `"a"=="b"` | exact string match | `/I` to ignore case |
| `a EQU b` … `GEQ` | numeric if both integers, else collation-order string compare | don't quote numbers; 32-bit saturation |
| `EXIST p` | file or dir exists | `p\` = directory only; wildcards OK |
| `DEFINED v` | variable has a value | name, not value |
| `ERRORLEVEL n` | errorlevel ≥ n | current inside blocks |
| `CMDEXTVERSION n` | extensions ≥ n | always 2 |

---

See also: [Conditional statements](06-conditionals.md) · [Strings](13-strings.md) · [Redirection & errors](12-redirection-errors.md)
