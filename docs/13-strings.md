[← Index](../README.md) · [← Redirection & errors](12-redirection-errors.md) · Next: [Built-in tools →](14-tools.md)

# 13. String manipulation

All string operations work on **variables** (not literals or FOR variables) through expansion syntax. Every example below was run on Windows 11 with `s=Hello World, hello Batch`.

- [Substrings](#substrings)
- [Search and replace](#search-and-replace)
- [Dynamic positions and lengths](#dynamic-positions-and-lengths)
- [Length](#length)
- [Tests: contains, starts with, ends with](#tests-contains-starts-with-ends-with)
- [Trim, case, padding](#trim-case-padding)
- [Split and join](#split-and-join)
- [Find position, count occurrences](#find-position-count-occurrences)
- [Special characters: quotes, newline, tab](#special-characters-quotes-newline-tab)
- [Pitfalls](#pitfalls)

---

## Substrings

```
%var:~start%            from start (0-based) to the end
%var:~start,length%     length characters from start
%var:~-n%               last n characters
%var:~start,-n%         from start, dropping the last n
```

| Expression | Result |
|---|---|
| `%s:~6,5%` | `World` |
| `%s:~-5%` | `Batch` |
| `%s:~0,-1%` | `Hello World, hello Batc` |
| `%s:~-11,5%` | `hello` |
| `%s:~100%` | (empty) |

The same syntax works with delayed expansion: `!s:~6,5!`.

## Search and replace

```
%var:old=new%     replace every occurrence of old with new (search is CASE-INSENSITIVE)
%var:old=%        remove every occurrence
%var:*old=new%    replace everything up to and including the FIRST old
```

| Expression | Result |
|---|---|
| `%s:hello=Bye%` | `Bye World, Bye Batch` (both cases matched) |
| `%s:l=%` | `Heo Word, heo Batch` |
| `%s:*World=%` | `, hello Batch` |
| `%q:"=%` with `q="quoted" value` | `quoted value` |

Limits:

- The search string can't contain `=` and can't start with `*` (except as the prefix operator) or `~`.
- Replacement text is literal; there are no regexes or capture groups.
- Case-insensitivity is also how [`ToUpper`/`ToLower`](../lib/strings/README.md#toupper--tolower) work: replacing `a` with `A` upper-cases every `a`/`A`.

## Dynamic positions and lengths

Positions must be literal numbers when the expression is parsed. To use variables:

```bat
rem Delayed expansion: %i% is substituted first, then !...! evaluated
setlocal EnableDelayedExpansion
set "ch=!s:~%i%,1!"
for /l %%i in (0,1,4) do echo char %%i = !s:~%%i,1!
endlocal

rem Without delayed expansion: CALL's second pass
call set "ch=%%s:~%i%,1%%"
call set "out=%%s:%find%=%repl%%%"
```

## Length

No built-in. Use [`StrLen`](../lib/strings/README.md#strlen) (binary search, ~13 steps for any length up to 8191):

```bat
call "%BATLIB%\strings\StrLen.cmd" LEN s
```

## Tests: contains, starts with, ends with

```bat
rem Contains (case-insensitive) - delayed expansion handles any content
setlocal EnableDelayedExpansion
if not "!s:World=!"=="!s!" echo contains World
endlocal

rem Contains, with FIND/FINDSTR (slower: starts a process)
echo(%s%| find /i "world" >nul && echo contains world

rem Starts with / ends with (s must be defined!)
if "%s:~0,5%"=="Hello" echo starts with Hello
if /i "%f:~-4%"==".txt" echo ends with .txt

rem Matches a pattern
echo(%ver%| findstr /r /x "[0-9]*\.[0-9]*\.[0-9]*" >nul && echo looks like x.y.z
```

`if not "!s:%sub%=!"=="!s!"` fails if `sub` is empty, contains `=`, or starts with `*`/`~`.

## Trim, case, padding

```bat
rem Leading spaces: FOR /F with tokens=* skips leading delimiters
for /f "tokens=* delims= " %%A in ("%s%") do set "s=%%A"

rem Both ends, robustly (spaces)
call "%BATLIB%\strings\Trim.cmd" s s

rem Case
call "%BATLIB%\strings\ToUpper.cmd" up s
call "%BATLIB%\strings\ToLower.cmd" low s

rem Pad right to 10 / left to 6 / zero-pad to 6
set "p=%name%          " & rem then on the next line:
set "p=%p:~0,10%"
set "p=      %n%"
set "p=%p:~-6%"
set "z=000000%n%"
set "z=%z:~-6%"
```

(Each `set` that uses the result of the previous one must be on its own line — `%p%` is expanded when the line is read.)

Results: `[abc       ]`, `[    42]`, `[000042]`.

## Split and join

```bat
rem Split on a character, keeping empty fields: turn "a,b,,c d" into "a" "b" "" "c d"
set "csv=a,b,,c d"
for %%T in ("%csv:,=" "%") do echo [%%~T]

rem Split with FOR /F tokens (empty fields collapse!)
for /f "tokens=1-3 delims=," %%a in ("%csv%") do echo %%a / %%b / %%c

rem Split on the first separator only
for /f "tokens=1,* delims==" %%k in ("%pair%") do set "key=%%k" & set "value=%%l"

rem Join
set "joined="
for %%W in (alpha beta gamma) do call set "joined=%%joined%%;%%W"
set "joined=%joined:~1%"                     & rem alpha;beta;gamma
```

The `"%csv:,=" "%"` trick breaks if the data contains `*`, `?` (wildcards in `FOR`) or quotes.

## Find position, count occurrences

```bat
rem 0-based index of the first occurrence of needle in hay
setlocal EnableDelayedExpansion
set "rest=!hay:*%needle%=!"
call "%BATLIB%\strings\StrLen.cmd" Lh hay
call "%BATLIB%\strings\StrLen.cmd" Lr rest
call "%BATLIB%\strings\StrLen.cmd" Ln needle
set /a "idx=Lh - Lr - Ln"                     & rem "find the needle here" -> 9
endlocal & set "idx=%idx%"

rem Count occurrences of a substring: length difference after removing it
set "t=%s:l=%"
call "%BATLIB%\strings\StrLen.cmd" L1 s
call "%BATLIB%\strings\StrLen.cmd" L2 t
set /a "count=L1-L2"                          & rem 5 for "l"; divide by the substring's length if longer
```

If the needle is not found, `!hay:*%needle%=!` returns `hay` unchanged and the index comes out negative — test for "contains" first.

## Special characters: quotes, newline, tab

```bat
rem Remove all quotes
set "v=%v:"=%"

rem A linefeed in a variable (the two lines after ^ are required, the second empty)
(set LF=^
%=empty=%
)
setlocal EnableDelayedExpansion
echo line1!LF!line2                         & rem prints two lines
endlocal

rem A TAB character, generated without typing one into the script
for /f "delims=" %%T in ('forfiles /p "%~dp0." /m "%~nx0" /c "cmd /c echo(0x09"') do set "TAB=%%T"
echo [a%TAB%b]
```

`FORFILES /C` interprets `0xHH` codes, which makes it a portable source of control characters (**Since:** Vista). Both recipes verified.

## Pitfalls

- `:~` and `:=` on an **undefined** variable corrupt the line — check `if defined` on a previous line ([details](02-parsing-escaping.md#percent-expansion)).
- Replacement search is case-insensitive; no way to make it case-sensitive.
- `%s%` with `& | < > ^` breaks when echoed or compared unquoted — use `!s!`.
- `FOR /F` collapses consecutive delimiters (empty CSV fields vanish).
- Lines are limited to 8191 characters after expansion.

---

See also: [String library](../lib/strings/README.md) · [Variables](04-variables.md) · [Parsing & escaping](02-parsing-escaping.md)
