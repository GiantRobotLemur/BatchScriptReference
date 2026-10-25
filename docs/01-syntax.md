[← Index](../README.md) · Next: [Parsing & escaping →](02-parsing-escaping.md)

# 1. Syntax

The basic structure of a batch file: lines, commands, comments, blocks and labels.

- [File types: .bat vs .cmd](#file-types-bat-vs-cmd)
- [Line endings and encoding](#line-endings-and-encoding)
- [Echo control and the `@` prefix](#echo-control-and-the--prefix)
- [Comments](#comments)
- [Command separators and conditional execution](#command-separators-and-conditional-execution)
- [Blocks (parentheses)](#blocks-parentheses)
- [Line continuation](#line-continuation)
- [Labels](#labels)
- [Case sensitivity and whitespace](#case-sensitivity-and-whitespace)
- [Skeleton of a well-behaved script](#skeleton-of-a-well-behaved-script)
- [Pitfalls](#pitfalls)

---

## File types: .bat vs .cmd

Both are run by `cmd.exe`, but they differ in one way that matters:

| Behaviour | `.bat` | `.cmd` |
|---|---|---|
| `SET`, `PATH`, `ASSOC`, `FTYPE`, `PROMPT`, `DPATH`, `APPEND` on **success** | leave `ERRORLEVEL` unchanged | reset `ERRORLEVEL` to 0 |
| Runs on MS-DOS / Windows 9x `COMMAND.COM` | yes | no |

```bat
rem In a .cmd file:
cmd /c exit 3
set "x=1"
echo %errorlevel%     & rem 0 in .cmd, 3 in .bat
```

**Use `.cmd`** for anything new: the behaviour is more predictable and nobody runs `COMMAND.COM` any more. This repository uses `.cmd` throughout.

## Line endings and encoding

- **Line endings must be CRLF.** `cmd.exe` locates `GOTO`/`CALL` targets by seeking in the file; with LF-only line endings label lookups randomly fail with *"The system cannot find the batch label specified"*. This repo enforces CRLF with [`.gitattributes`](../.gitattributes).
- **Encoding:** save as ANSI/OEM or UTF-8 **without BOM**. A BOM becomes garbage on line 1 (`'ï»¿@echo' is not recognized…`). For non-ASCII text in UTF-8 files, switch the console code page first: `chcp 65001 >nul` (see [Environment → code pages](03-environment.md#code-pages)).
- `cmd.exe` re-reads the file from disk as it runs. **Editing a running batch file** changes what executes next — never edit a script while it runs.

## Echo control and the `@` prefix

```bat
@echo off          & rem stop echoing commands; @ hides this line itself
echo on            & rem resume echoing (useful for debugging a section)
@somecommand       & rem hide just this one command, when echo is on
echo.              & rem blank line (see below for the safer form)
echo(              & rem blank line - safest form
echo(%var%         & rem prints var even if empty or "on"/"off"/"/?"
```

`echo %var%` misbehaves when `var` is empty (prints *ECHO is off.*), is `on`/`off`, or starts with `/?` (prints help). **`echo(` is the robust form** — the `(` is not printed.

To print text without a trailing newline:

```bat
<nul set /p "=Working... "
rem ...
echo done
```

> On Vista+ `SET /P` strips leading spaces/tabs from the prompt text.

## Comments

| Form | Notes |
|---|---|
| `rem text` | A real command. Safe everywhere, including inside blocks. Slightly slower. |
| `:: text` | Actually an invalid label, skipped by the parser. Fast and common, **but breaks inside `( )` blocks**. |
| `& rem text` | End-of-line comment after a command. |
| `%= text =%` | Inline comment trick: expands an (undefined) variable to nothing. Rarely worth it. |

Gotchas, all verified:

```bat
rem %~a in a comment aborts the script: percent expansion runs on comment
rem lines too (both REM and ::). Write "the ~a modifier" instead.

rem /? at the start of REM arguments is parsed as REM's help switch and
rem the rest of the line becomes a syntax error.

(
    echo inside a block
    :: one :: comment line here is tolerated...
    rem ...but two consecutive :: lines, or :: just before ")", break the block.
)
```

**Rule:** use `rem` inside blocks; `::` only at top level. Never put `%` or `/?` in comments carelessly.

## Command separators and conditional execution

| Syntax | Meaning |
|---|---|
| `a & b` | Run `a`, then `b` |
| `a && b` | Run `b` only if `a` succeeded |
| `a \|\| b` | Run `b` only if `a` failed |
| `a \| b` | Pipe stdout of `a` into `b` (both run in **child** `cmd.exe` instances for internal commands — see [Redirection](12-redirection-errors.md#pipes)) |
| `(a & b) > f` | Group, e.g. to redirect several commands at once |

"Succeeded" for `&&`/`||` means the command reported success. For external programs that is exit code 0; for internal commands it is the command's own success flag, which does not always match `ERRORLEVEL` (see [Redirection & errors](12-redirection-errors.md#errorlevel-semantics)).

```bat
mkdir "%OUT%" 2>nul || (echo Cannot create %OUT% & exit /b 1)
findstr /i "error" log.txt >nul && echo Errors found || echo Clean
```

> `a && b || c` is **not** a ternary: `c` also runs if `b` fails. Make `b` something that cannot fail (or wrap it) when you rely on this.

## Blocks (parentheses)

Parentheses group commands for `IF`, `ELSE`, `FOR` and redirection.

```bat
if exist "%FILE%" (
    echo Found %FILE%
    type "%FILE%"
) else (
    echo Missing %FILE%
)
```

Rules:

- The opening `(` must be on the same line as the `if`/`for`/`do`/`else`. `) else (` must be on one line.
- **The whole block is parsed — and `%var%` is expanded — once, before any of it runs.** Variables changed inside the block keep their old `%value%` until the block ends. This is the single most common batch bug; the fix is delayed expansion (`!var!`) — see [Parsing & escaping](02-parsing-escaping.md#delayed-expansion).
- An unescaped `)` inside a block ends it early: `echo (x)` inside a block breaks. Escape it: `echo ^(x^)`, or quote it.
- Labels and `::` comments inside blocks are unreliable (see above). `GOTO` inside a block abandons the block **and any enclosing `FOR` loop**.

## Line continuation

A caret `^` as the **very last character** of a line joins the next line:

```bat
robocopy "%SRC%" "%DST%" ^
    /MIR /R:2 /W:5 ^
    /XD .git node_modules ^
    /LOG:"%LOG%"
```

A space after the `^` breaks it silently (the space is escaped instead). Inside quotes, `^` is literal and does not continue the line. Inside a parenthesised block, a newline is already a command separator, so continuation is only needed within one command.

## Labels

```bat
:Main
:ProcessFile
:Loop_Next
```

- A label is `:` followed by a name at the start of a line (leading whitespace allowed). Only the first token counts; text after it is ignored, which makes `:Func  arg1 arg2` a handy self-documenting signature.
- Names are case-insensitive. Stick to letters, digits, `_` and `-`; avoid spaces and special characters.
- If a label is duplicated, `GOTO`/`CALL` find the **first one after the current position**, wrapping around to the top of the file.
- `:EOF` is a built-in pseudo-label meaning end of file — do not define it. `goto :eof` returns from a subroutine or ends the script.

See [Branching](09-branching.md) and [Functions](10-functions.md).

## Case sensitivity and whitespace

- Commands, variable names, labels and `IF /I` comparisons are **case-insensitive**. `IF "a"=="A"` (without `/I`) is case-**sensitive**.
- Delimiters between arguments: space, tab, `,`, `;`, `=` (unquoted). So `copy a,b` is `copy a b`. This also affects [command-line arguments](11-arguments.md#argument-splitting).
- `set x = 1` creates a variable named `"x "` with value `" 1"`. Always write `set "x=1"`.
- Trailing spaces on a line become part of an unquoted `set` value. The `set "name=value"` form protects against this.

## Skeleton of a well-behaved script

```bat
@echo off
setlocal EnableExtensions DisableDelayedExpansion

rem --- arguments / configuration
set "SCRIPT_DIR=%~dp0"

rem --- main logic
call :DoWork "%~1" || exit /b 1
exit /b 0

:DoWork  input
setlocal
rem ...
exit /b 0
```

See [`templates/script-template.cmd`](../templates/script-template.cmd) for a complete model with argument parsing, logging and error handling.

## Pitfalls

- CRLF line endings, no BOM.
- `rem`/`::` comments still go through `%` expansion.
- `::` inside blocks; unescaped `)` inside blocks.
- `%var%` inside a block is expanded once, before the block runs.
- Trailing whitespace after `^` or in unquoted `set` values.
- `echo %var%` with an empty var — use `echo(%var%`.

---

See also: [Parsing & escaping](02-parsing-escaping.md) · [Pitfalls checklist](15-pitfalls.md)
