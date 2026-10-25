@echo off
setlocal EnableExtensions DisableDelayedExpansion
set ASSERT=call "%~dp0_assert.cmd"
set "BATLIB=%~dp0..\lib"
set "SPEC=o|out: v|verbose n|dry-run level: color"
%ASSERT% :Begin "args"

rem --- Each switch style ------------------------------------------------------
call "%BATLIB%\args\ParseArgs.cmd" OPT "%SPEC%" /v /out:C:\x.txt -n --level 3 first
%ASSERT% :AssertEqual "ParseArgs succeeds" "0" "%errorlevel%"
%ASSERT% :AssertVar "slash flag /v" OPT_verbose "1"
%ASSERT% :AssertVar "slash value /out:x keeps later colons" OPT_out "C:\x.txt"
%ASSERT% :AssertVar "dash flag -n maps to long name" OPT_dry-run "1"
%ASSERT% :AssertVar "double-dash value --level 3" OPT_level "3"
%ASSERT% :AssertVar "positional" OPT_ARG1 "first"
%ASSERT% :AssertVar "ARGC" OPT_ARGC "1"
%ASSERT% :AssertUndefined "unused option undefined" OPT_color
%ASSERT% :AssertUndefined "no ERROR on success" OPT_ERROR

call "%BATLIB%\args\ParseArgs.cmd" OPT "%SPEC%" --out=first.txt -o "c d.txt" /LEVEL 7 "--color=never"
%ASSERT% :AssertVar "--out=value then -o value: last wins" OPT_out "c d.txt"
%ASSERT% :AssertVar "option names are case-insensitive" OPT_level "7"
%ASSERT% :AssertVar "quoted flag with inline value" OPT_color "never"
%ASSERT% :AssertVar "no positionals gives ARGC 0" OPT_ARGC "0"

rem cmd.exe splits UNQUOTED arguments at = , ; so --out=x arrives as two
rem arguments (--out x), which still works for options that take a value.
call "%BATLIB%\args\ParseArgs.cmd" OPT "%SPEC%" --out=x.txt
%ASSERT% :AssertVar "unquoted --name=value" OPT_out "x.txt"
call "%BATLIB%\args\ParseArgs.cmd" OPT "%SPEC%" "--out=a=b.txt"
%ASSERT% :AssertVar "quoted --name=value splits at first =" OPT_out "a=b.txt"
call "%BATLIB%\args\ParseArgs.cmd" OPT "%SPEC%" --out=a=b.txt
%ASSERT% :AssertVar "unquoted value containing = is split by cmd.exe" OPT_ARG1 "b.txt"
call "%BATLIB%\args\ParseArgs.cmd" OPT "%SPEC%" /out x /level:
%ASSERT% :AssertVar "/name value (space separated)" OPT_out "x"
%ASSERT% :AssertUndefined "/name: with empty inline value" OPT_level

rem --- Positionals ------------------------------------------------------------
call "%BATLIB%\args\ParseArgs.cmd" OPT "%SPEC%" "with space" "" - "a & b" "(paren)" -v last
%ASSERT% :AssertVar "quoted positional" OPT_ARG1 "with space"
%ASSERT% :AssertUndefined "empty positional" OPT_ARG2
%ASSERT% :AssertVar "lone dash is positional" OPT_ARG3 "-"
%ASSERT% :AssertVar "ampersand in quoted arg" OPT_ARG4 "a & b"
%ASSERT% :AssertVar "parentheses in arg" OPT_ARG5 "(paren)"
%ASSERT% :AssertVar "positional after option" OPT_ARG6 "last"
%ASSERT% :AssertVar "ARGC counts empty args" OPT_ARGC "6"

call "%BATLIB%\args\ParseArgs.cmd" OPT "%SPEC%" -v -- -n /x
%ASSERT% :AssertUndefined "-- stops option parsing" OPT_dry-run
%ASSERT% :AssertVar "after -- dash arg is positional" OPT_ARG1 "-n"
%ASSERT% :AssertVar "after -- slash arg is positional" OPT_ARG2 "/x"

rem --- Errors -----------------------------------------------------------------
call "%BATLIB%\args\ParseArgs.cmd" OPT "%SPEC%" -v --bogus x
%ASSERT% :AssertEqual "unknown option returns 2" "2" "%errorlevel%"
%ASSERT% :AssertVar "unknown option message" OPT_ERROR "Unknown option: --bogus"
%ASSERT% :AssertVar "options before the error are kept" OPT_verbose "1"

call "%BATLIB%\args\ParseArgs.cmd" OPT "%SPEC%" --out
%ASSERT% :AssertEqual "missing value returns 2" "2" "%errorlevel%"
%ASSERT% :AssertVar "missing value message" OPT_ERROR "Option --out requires a value"

call "%BATLIB%\args\ParseArgs.cmd" OPT "%SPEC%" "--bad name"
%ASSERT% :AssertEqual "option name with space is rejected" "2" "%errorlevel%"

call "%BATLIB%\args\ParseArgs.cmd"
%ASSERT% :AssertEqual "usage error" "1" "%errorlevel%"

rem --- Housekeeping -----------------------------------------------------------
set "OPT_stale=old"
call "%BATLIB%\args\ParseArgs.cmd" OPT "%SPEC%" -v
%ASSERT% :AssertUndefined "previous prefix_ variables are cleared" OPT_stale
%ASSERT% :AssertUndefined "internal variables do not leak" _pa_p
%ASSERT% :AssertUndefined "internal lookup tables do not leak" _pa_opt_verbose

call "%BATLIB%\args\ParseArgs.cmd" OPT ""  one
%ASSERT% :AssertVar "empty spec still collects positionals" OPT_ARG1 "one"

rem --- Inlined as a :label subroutine -----------------------------------------
rem The library promise: a label followed by the file's contents works unchanged.
set "INL=%TEMP%\bsr-test-inline-%RANDOM%.cmd"
>"%INL%" (
    echo @echo off
    echo setlocal
    echo call :ParseArgs X "v|verbose o|out:" %%*
    echo echo %%X_verbose%%^^^|%%X_out%%^^^|%%X_ARG1%%
    echo exit /b
    echo :ParseArgs
)
type "%BATLIB%\args\ParseArgs.cmd" >>"%INL%"
set "out="
for /f "delims=" %%L in ('call "%INL%" -v pos --out "f.txt"') do set "out=%%L"
del "%INL%"
%ASSERT% :AssertVar "inlined ParseArgs works" out "1|f.txt|pos"

%ASSERT% :End
exit /b %errorlevel%
