[← Library](../README.md) · [← Index](../../README.md)

# Strings

String helpers that operate on variables **by name**, so values containing `& | < > ^ ( ) %` and `!` pass through intact (they never travel through `CALL` arguments).

| Function | Purpose |
|---|---|
| [StrLen](#strlen) | Length of a string |
| [ToUpper / ToLower](#toupper--tolower) | Change case (ASCII letters) |
| [Trim](#trim) | Remove leading and trailing spaces |

Tests: [`tests/test-strings.cmd`](../../tests/test-strings.cmd) · Background: [docs/13-strings.md](../../docs/13-strings.md)

---

### StrLen

Sets a variable to the length of the string held in another variable.

**Source:** [`StrLen.cmd`](StrLen.cmd)

**Usage**

```bat
call "%BATLIB%\strings\StrLen.cmd" outVar inVar
call :StrLen outVar inVar                       & rem when inlined
```

| Argument | Required | Meaning |
|---|---|---|
| `outVar` | yes | Variable to receive the length |
| `inVar` | yes | **Name** of the variable holding the string. Undefined counts as length 0 |

| ERRORLEVEL | Meaning |
|---|---|
| 0 | OK |
| 1 | Usage error (missing argument) |

**Since:** Windows 2000.

**Examples**

```bat
set "name=Hello World"
call "%BATLIB%\strings\StrLen.cmd" LEN name
echo %LEN%                                       & rem 11

rem Right-align a value in a 12-character column
call "%BATLIB%\strings\StrLen.cmd" LEN value
set /a "PAD=12-LEN"
set "spaces=            "
call set "line=%%spaces:~0,%PAD%%%%value%"
```

**How it works.** Appends a sentinel `#`, then performs a binary search with `!s:~N,1!` for N = 4096, 2048, … 1: each time a character exists at offset N, adds N to the length and drops the first N characters. 13 steps cover the 8191-character maximum.

**Limitations.** Uses delayed expansion internally (no effect on the caller).

---

### ToUpper / ToLower

Set a variable to the upper-/lower-case form of another variable's value.

**Source:** [`ToUpper.cmd`](ToUpper.cmd), [`ToLower.cmd`](ToLower.cmd)

**Usage**

```bat
call "%BATLIB%\strings\ToUpper.cmd" outVar inVar
call "%BATLIB%\strings\ToLower.cmd" outVar inVar
```

| Argument | Required | Meaning |
|---|---|---|
| `outVar` | yes | Variable to receive the result; may be the same as `inVar` |
| `inVar` | yes | **Name** of the source variable. If undefined, `outVar` becomes undefined |

| ERRORLEVEL | Meaning |
|---|---|
| 0 | OK |
| 1 | Usage error |

**Since:** Windows 2000.

**Examples**

```bat
set "ext=%~x1"
call "%BATLIB%\strings\ToLower.cmd" ext ext
if "%ext%"==".jpg" echo JPEG

call "%BATLIB%\strings\ToUpper.cmd" HOST COMPUTERNAME
```

**How it works.** Delayed-expansion replacement `!s:a=A!` is case-insensitive in its search, so replacing each letter with itself in the target case converts every occurrence. 26 replacements, no loop over characters.

**Limitations.** ASCII `A–Z` only; accented letters are unchanged. Values with `"` break the [return tunnel](../../docs/10-functions.md#returning-values); `!` is lost if the caller has delayed expansion enabled.

---

### Trim

Removes leading and trailing spaces.

**Source:** [`Trim.cmd`](Trim.cmd)

**Usage**

```bat
call "%BATLIB%\strings\Trim.cmd" outVar inVar
```

| Argument | Required | Meaning |
|---|---|---|
| `outVar` | yes | Variable to receive the result; may be the same as `inVar` |
| `inVar` | yes | **Name** of the source variable. A value of only spaces gives an undefined result |

| ERRORLEVEL | Meaning |
|---|---|
| 0 | OK |
| 1 | Usage error |

**Since:** Windows 2000.

**Examples**

```bat
set /p "answer=Name: "
call "%BATLIB%\strings\Trim.cmd" answer answer
if not defined answer echo Name is required

rem Clean up values parsed from "key = value" lines
for /f "usebackq tokens=1,* delims==" %%K in ("%CONF%") do (
    set "k=%%K" & set "v=%%L"
    call "%BATLIB%\strings\Trim.cmd" k k
    call "%BATLIB%\strings\Trim.cmd" v v
    call set "CFG_%%k%%=%%v%%"
)
```

**How it works.** Two `GOTO` loops strip one space at a time from the front (`!s:~1!`) and back (`!s:~0,-1!`).

**Limitations.** Spaces only — tabs are not trimmed (see [docs/13-strings.md](../../docs/13-strings.md#special-characters-quotes-newline-tab) for generating a TAB if you need it). Same tunnel limits as above.
