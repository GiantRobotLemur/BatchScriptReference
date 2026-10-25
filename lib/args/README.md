[← Library](../README.md) · [← Index](../../README.md)

# Arguments

| Function | Purpose |
|---|---|
| [ParseArgs](#parseargs) | Parse switches, options with values, and positional arguments |

Tests: [`tests/test-args.cmd`](../../tests/test-args.cmd) · Background: [docs/11-arguments.md](../../docs/11-arguments.md)

---

### ParseArgs

Parses a script's command line into variables, accepting both Windows-style and Unix-style options.

**Source:** [`ParseArgs.cmd`](ParseArgs.cmd)

**Usage**

```bat
call "%BATLIB%\args\ParseArgs.cmd" prefix "spec" %*
```

| Argument | Required | Meaning |
|---|---|---|
| `prefix` | yes | Prefix for the result variables, e.g. `OPT` |
| `spec` | yes (may be `""`) | Space-separated option list (see below) |
| `%*` | — | The arguments to parse |

**Spec syntax**

| Entry | Meaning |
|---|---|
| `verbose` | Flag `--verbose` / `/verbose` / `-verbose` |
| `v\|verbose` | Flag with a short alias: `-v`, `/v`, `--verbose`, … all set `OPT_verbose` |
| `out:` | Option taking a value |
| `o\|out:` | Option taking a value, with alias |

**Results** (in the caller's environment; every existing `prefix_*` variable is cleared first)

| Variable | Value |
|---|---|
| `prefix_<long>` | The option's value, or `1` for a flag. Undefined if not given |
| `prefix_ARG1` … `prefix_ARGn` | Positional arguments, quotes removed |
| `prefix_ARGC` | Number of positional arguments (always set) |
| `prefix_ERROR` | Error message (only with ERRORLEVEL 2) |

**Accepted forms**

| Form | Example | Notes |
|---|---|---|
| `/name` `-name` `--name` | `/v` `-v` `--verbose` | Flags, any prefix, any alias |
| `/name:value` | `/out:C:\x.txt` | Splits at the first `:` — later colons are kept |
| `/name value` `-n value` `--name value` | `--out x.txt` | Value is the next argument |
| `--name=value` | `--out=x.txt` | cmd.exe itself splits unquoted `=` into two arguments, which gives the same result. Values containing `=` need quotes: `"--opt=a=b"` |
| `"--flag=value"` | `"--color=never"` | A flag given a value stores the value instead of `1` (quotes required) |
| `--` | `-- -file-starting-with-dash` | Everything after is positional |
| `-` alone | `-` | Positional (conventional "stdin") |

Option names are case-insensitive (`/OUT` = `/out`).

| ERRORLEVEL | Meaning |
|---|---|
| 0 | OK |
| 1 | Usage error (no prefix) |
| 2 | Unknown option, or option missing its value — `prefix_ERROR` explains; options parsed before the error are still set |

**Since:** Windows 2000.

**Examples**

```bat
@echo off
setlocal EnableExtensions DisableDelayedExpansion
if not defined BATLIB set "BATLIB=%~dp0lib"

rem /? must be checked before CALL - see Limitations
if "%~1"=="/?" goto :Usage

call "%BATLIB%\args\ParseArgs.cmd" OPT "h|help o|out: v|verbose n|dry-run level:" %*
if errorlevel 2 (
    >&2 echo %~n0: %OPT_ERROR%
    exit /b 1
)
if defined OPT_help goto :Usage
if %OPT_ARGC% lss 1 (>&2 echo %~n0: missing input file & exit /b 1)
if not defined OPT_level set "OPT_level=1"

echo input:   %OPT_ARG1%
echo output:  %OPT_out%
if defined OPT_verbose echo verbose on
if defined OPT_dry-run echo dry run
```

```
myscript.cmd -v --out result.txt data.csv            -> OPT_verbose=1 OPT_out=result.txt OPT_ARG1=data.csv
myscript.cmd /out:C:\out\r.txt /n "my data.csv"       -> OPT_out=C:\out\r.txt OPT_dry-run=1 OPT_ARG1=my data.csv
myscript.cmd --bogus                                  -> ERRORLEVEL 2, OPT_ERROR=Unknown option: --bogus
myscript.cmd --out                                    -> ERRORLEVEL 2, OPT_ERROR=Option --out requires a value
```

Iterating positional arguments:

```bat
for /l %%i in (1,1,%OPT_ARGC%) do call :Process "%%OPT_ARG%%i%%"
rem or, without CALL's re-parsing of the value:
set /a I=0
:Next
set /a I+=1
if %I% gtr %OPT_ARGC% goto :Done
call set "ITEM=%%OPT_ARG%I%%%"
...
goto :Next
```

The first form passes the literal text `%OPT_ARG1%` to `:Process`, which `CALL` expands — fine for ordinary values. See [`templates/script-template.cmd`](../../templates/script-template.cmd) for a complete script built around ParseArgs.

**How it works.**

1. Clears `prefix_*` in the caller's scope, then `SETLOCAL`.
2. Turns the spec into lookup variables: `_pa_opt_<alias>=<long>` for every alias and `_pa_val_<long>=1` for options taking values (`|` is converted to `/` first so it can't act as a pipe).
3. Walks the arguments with `SHIFT`: classifies each as `--`, positional, or option (`--x`, `/x`, `-x`); splits `name:value` / `name=value` with `FOR /F "delims=:="`; rejects names with unsafe characters; looks the name up with `IF DEFINED _pa_opt_<name>`; reads the value inline or from the next argument.
4. Returns every `prefix_*` variable across `ENDLOCAL` with the *replay* idiom: `for /f "delims=" %%V in ('set prefix_') do (endlocal & set "%%V")` inside a parenthesised block that also holds `exit /b %rc%` ([explained](../../docs/10-functions.md#3-many-results-with-a-prefix)).

**Limitations.**

- **`/?` cannot pass through `CALL`**: an unquoted `/?` anywhere in a CALL's arguments makes CALL show its own help. Check `if "%~1"=="/?"` before calling ParseArgs (or use `-h`/`--help`).
- `CALL` re-parses arguments: values containing `%`, `^`, `!`, `"`, or unquoted `& | < >` are not supported.
- Unquoted `=`, `,` and `;` split arguments (cmd.exe behaviour, before ParseArgs sees them).
- Arguments beginning with `-` or `/` are treated as options — put positional values like `-5` or `/path` after `--`.
- No short-flag bundling (`-abc` is the option `abc`, not `-a -b -c`).
