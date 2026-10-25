# CLAUDE.md — maintenance notes

Notes for future AI-assisted changes to this repository. Read before editing.

## What this repo is

A personal reference for Windows Batch (`cmd.exe`) scripting, written for an experienced engineer who works in locked-down Windows environments. It has three parts:

- `docs/01–15` — dense language reference. Assume the reader knows programming; don't explain basics.
- `lib/` — tested, reusable functions, one `.cmd` per function, grouped in folders with one `README.md` per group.
- `templates/script-template.cmd` — the model script; `tests/` — pure-batch test suite.

The original brief is in `Task.md` (untracked). Hard constraints from the owner:

- **Pure batch plus built-in Windows executables only.** No PowerShell, VBScript, or third-party tools in `lib/` or templates. WMIC only as a fallback (it was removed from Windows 11 in 2026).
- Anything up to Windows 10 can be used freely; mark features introduced **after XP** with a `> **Since:** …` note.
- Library: one file per function, arg 1 = output variable name, ERRORLEVEL 0 ok / 1 usage / 2+ specific, tests for everything.
- Argument parser supports `/x`, `/name:value`, `-x`, `--name value`, `--name=value`, positional.

## Layout and cross-links

```
README.md                  index: docs table, library table, template, tests, cheat sheet
docs/NN-topic.md           each starts with nav links: [← Index](../README.md) · [← Prev] · Next →
docs/15-pitfalls.md        checklist of every trap; add new traps here too
lib/README.md              library overview, contents table (with Since + Depends), conventions, how to inline
lib/<group>/README.md      one entry per function (fixed layout, see below)
lib/<group>/<Name>.cmd     the functions
tests/run-tests.cmd        runs tests/test-*.cmd; optional filter arg
tests/_assert.cmd          :Begin :AssertEqual :AssertVar :AssertVarI :AssertUndefined :AssertExists :AssertNotExists :End
tests/test-<group>.cmd     one suite per lib group
templates/script-template.cmd
```

When adding or renaming anything, update **all** of: the group README entry, the `lib/README.md` contents table, the `README.md` library table, and any `docs/` links. GitHub anchors: `### ToUpper / ToLower` → `#toupper--tolower`, `### 3. Many results…` → `#3-many-results…`.

## Writing .cmd files — mandatory checks

1. **Line endings must be CRLF.** The Write/Edit tools emit LF, and an LF or mixed file makes `GOTO`/`CALL` fail randomly ("cannot find the batch label"). This happened during development. After writing or editing any `.cmd`, normalise:

   ```powershell
   Get-ChildItem Q:\dev\git\BatchScriptReference -Recurse -Include *.cmd,*.bat |
     ? { $_.FullName -notmatch '\\\.git\\' } |
     % { $t=[IO.File]::ReadAllText($_.FullName); [IO.File]::WriteAllText($_.FullName, ($t -replace "`r?`n","`r`n")) }
   ```

   `.gitattributes` enforces CRLF on checkout/commit.
2. **Run the tests** (from PowerShell; Git Bash's `cmd //c` doesn't work reliably here):

   ```powershell
   cmd /c "Q:\dev\git\BatchScriptReference\tests\run-tests.cmd"     # expect "0 failed", exit 0
   ```

3. For the template, run it with `cmd /c` — **not** `call … /?` from a wrapper (CALL eats `/?`).

## Library function conventions (copy an existing file as the model)

- Header: `@echo off` then a `::` block: `Name  args`, description, `ERRORLEVEL:`, `Requires:` (min Windows), `Depends:`, `Docs: lib/<group>/README.md#anchor`.
- Body starts `setlocal EnableExtensions DisableDelayedExpansion` (or `EnableDelayedExpansion` if the algorithm needs it).
- Usage checks first: `if "%~1"=="" exit /b 1`.
- Internal variables `_name`; internal labels `FuncName_label`. That keeps inlining (paste under `:FuncName`) collision-free. `tests/test-args.cmd` checks this for ParseArgs.
- Return: `endlocal & set "%~1=%_r%"` then `exit /b 0` on its own line. Extra outputs: `%~1_SUFFIX`.
- String inputs are passed **by variable name** (read with `!%~2!`), not by value.
- Sibling calls via `call "%~dp0X.cmd"` / `"%~dp0..\group\X.cmd"`; list them under `Depends:`.
- Library root variable is **`BATLIB`**, never `LIB` (MSVC uses `LIB`).

## Group README entry layout

`### Name` → one-line synopsis → `**Source:**` link (+ `**Depends on:**`) → **Usage** code block → arguments table → ERRORLEVEL table → `**Since:**` → **Examples** → **How it works.** → **Limitations.**

## Batch traps found while building this repo (all verified on Windows 11)

These caught real bugs here. Check new code and examples against them:

- `%~` (or any bad `%~x` modifier) inside `REM` or `::` comments **aborts the script**. Write "the ~a modifier" instead.
- `REM /? …` at the start of a comment, `ECHO /?`, and any unquoted `/?` in `CALL` arguments print help.
- `%var:~…%` / `%var:x=y%` on an **undefined** variable eats text up to the next `%`. Guard with `if not defined var goto :skip` on a **previous** line (an `if defined` on the same line doesn't help).
- `%var%` is expanded when the line/block is read: `call :X && echo %OUT%`, `call :X || set "RC=%errorlevel%"`, `set "a=1" & echo %a%` all use stale values. Use separate lines.
- `::` comments inside `( )` blocks break them; use `rem`.
- `REG`, `ROBOCOPY`, most EXEs treat `\"` as an escaped quote: write `"C:\dir\\"` or `"C:\dir\."`.
- `FINDSTR "a b"` means a OR b; use `/c:"a b"` for a phrase.
- cmd splits unquoted args at `= , ;` too: `--x=y` arrives as two arguments.
- `FOR /F skip=0` is a syntax error. `FOR /R` root can't be a FOR variable.
- `if "10" GTR "9"` is a string compare (false); out-of-range numbers saturate.
- A `.cmd` `SET` resets ERRORLEVEL to 0; `RD`/redirection failures don't set ERRORLEVEL (only `||`).
- `cmd /c script` exits 0 after a failure unless the script ends with `exit /b N`.
- After `SHIFT`, `%~1` (and `%0`/`%~dp0`) have moved: save values first.
- `call :label` inside `FOR /F ('…')` fails — child cmd isn't in batch context.
- Changing user/machine persistence settings (e.g. `Command Processor\AutoRun`) is off-limits for experiments.

## Documentation style

- Dense and table-heavy. Every code block uses ` ```bat ` and should be copy-pasteable. `& rem …` inline comments are fine: REM ignores `< > |` (verified).
- Mark surprising behaviour as *(verified)* only after reproducing it. Do that in a probe script in the scratchpad: write it with CRLF and run it with `cmd /c "probe.cmd"`. Don't state undocumented behaviour from memory.
- Version notes: `> **Since:** Windows Vista` (only for post-XP features). Use Microsoft docs to confirm when unsure; say "present on Windows 7+" rather than guessing an earlier version.
- New traps go both in the relevant page's **Pitfalls** section and in `docs/15-pitfalls.md`.

## Not yet covered / ideas

Possible additions the owner might want: INI-file read/write helpers, a CSV parser that keeps empty fields, service start/stop-and-wait helpers, a `Sleep` function, file hashing via CERTUTIL, and a lock-file/mutex helper (`mkdir` is atomic).
