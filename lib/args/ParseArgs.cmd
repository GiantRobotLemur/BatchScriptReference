@echo off
:: ===========================================================================
:: ParseArgs  prefix "spec" [arguments...]
::   Parses command-line arguments into variables in the caller's scope:
::     <prefix>_<long>    value of an option, or 1 for a flag
::     <prefix>_ARG1..n   positional arguments (quotes removed)
::     <prefix>_ARGC      number of positional arguments
::     <prefix>_ERROR     message, only when ERRORLEVEL is 2
::   Every existing <prefix>_* variable is cleared first.
::
::   spec: space-separated options. "short|long" gives an alias; a trailing
::   ":" means the option takes a value. Option names are case-insensitive.
::     call "%BATLIB%\args\ParseArgs.cmd" OPT "o|out: v|verbose n|dry-run" %*
::
::   Accepted forms: /v  -v  --verbose  /out:x  /out x  -o x  -o=x
::                   --out x  --out=x   and  --  (everything after is positional)
::   A flag given a value ("--color=never") stores that value instead of 1.
::   cmd.exe splits UNQUOTED arguments at = , ; so --out=x arrives as
::   "--out" "x" (fine), but "--out=a=b" and "--color=never" need quotes.
::
::   ERRORLEVEL: 0 ok | 1 usage | 2 unknown option or missing value
::   Requires:   Windows 2000+
::   Limits:     an unquoted /? anywhere in a CALL shows CALL's help, so test
::               for /? before calling. Arguments containing " % ! ^ or
::               unquoted & | < > are not supported by CALL.
::   Docs:       lib/args/README.md#parseargs
:: ===========================================================================
if "%~1"=="" exit /b 1
for /f "delims==" %%V in ('set %~1_ 2^>nul') do set "%%V="
setlocal EnableExtensions DisableDelayedExpansion
set "_pa_p=%~1"
set "_pa_spec=%~2"
rem '|' would act as a pipe once expanded unquoted; use '/' internally.
if defined _pa_spec set "_pa_spec=%_pa_spec:|=/%"
set "_pa_rc=0"
set "_pa_argc=0"
set "_pa_eoo="

rem --- Build lookup tables from the spec: _pa_opt_<name>=<long>, _pa_val_<long>=1
:ParseArgs_spec
set "_pa_e="
if defined _pa_spec for /f "tokens=1,*" %%A in ("%_pa_spec%") do set "_pa_e=%%A" & set "_pa_spec=%%B"
if not defined _pa_e goto :ParseArgs_args
call :ParseArgs_define
goto :ParseArgs_spec

:ParseArgs_args
shift
shift

rem --- Main loop: one argument per pass ------------------------------------
:ParseArgs_next
if [%1]==[] goto :ParseArgs_done
set "_pa_a=%~1"
shift
if not defined _pa_a goto :ParseArgs_positional
if defined _pa_eoo goto :ParseArgs_positional
if "%_pa_a%"=="--" (set "_pa_eoo=1" & goto :ParseArgs_next)
if "%_pa_a:~1%"=="" goto :ParseArgs_positional
set "_pa_n="
if "%_pa_a:~0,2%"=="--" (set "_pa_n=%_pa_a:~2%" & goto :ParseArgs_option)
if "%_pa_a:~0,1%"=="/" (set "_pa_n=%_pa_a:~1%" & goto :ParseArgs_option)
if "%_pa_a:~0,1%"=="-" (set "_pa_n=%_pa_a:~1%" & goto :ParseArgs_option)
goto :ParseArgs_positional

:ParseArgs_option
rem Split name[:=]value at the first ':' or '='.
set "_pa_k=" & set "_pa_iv=" & set "_pa_has="
if defined _pa_n for /f "tokens=1,* delims=:=" %%A in ("%_pa_n%") do set "_pa_k=%%A" & set "_pa_iv=%%B"
if not defined _pa_k goto :ParseArgs_unknown
if not "%_pa_k%"=="%_pa_n%" set "_pa_has=1"
rem Reject names with characters that would break the IF DEFINED test below.
for /f "delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.?" %%X in ("%_pa_k%") do goto :ParseArgs_unknown
if not defined _pa_opt_%_pa_k% goto :ParseArgs_unknown
call set "_pa_l=%%_pa_opt_%_pa_k%%%"
if defined _pa_val_%_pa_l% goto :ParseArgs_value
if defined _pa_has (set "%_pa_p%_%_pa_l%=%_pa_iv%") else set "%_pa_p%_%_pa_l%=1"
goto :ParseArgs_next

:ParseArgs_value
if defined _pa_has (set "%_pa_p%_%_pa_l%=%_pa_iv%" & goto :ParseArgs_next)
if [%1]==[] (
    set "%_pa_p%_ERROR=Option %_pa_a% requires a value"
    set "_pa_rc=2"
    goto :ParseArgs_done
)
set "%_pa_p%_%_pa_l%=%~1"
shift
goto :ParseArgs_next

:ParseArgs_positional
set /a _pa_argc+=1
set "%_pa_p%_ARG%_pa_argc%=%_pa_a%"
goto :ParseArgs_next

:ParseArgs_unknown
set "%_pa_p%_ERROR=Unknown option: %_pa_a%"
set "_pa_rc=2"

:ParseArgs_done
set "%_pa_p%_ARGC=%_pa_argc%"
rem Copy every <prefix>_* variable out of the SETLOCAL scope. The block is
rem parsed once, so %_pa_rc% is read before ENDLOCAL discards it; the first
rem ENDLOCAL returns to the caller's scope and later ones do nothing.
(
    for /f "delims=" %%V in ('set %_pa_p%_ 2^>nul') do (endlocal & set "%%V")
    exit /b %_pa_rc%
)

:ParseArgs_define
rem _pa_e is one spec entry, e.g. "o/out:" or "verbose".
set "_pa_v="
if "%_pa_e:~-1%"==":" set "_pa_v=1"
if defined _pa_v set "_pa_e=%_pa_e:~0,-1%"
set "_pa_s=" & set "_pa_l="
for /f "tokens=1,2 delims=/" %%A in ("%_pa_e%") do set "_pa_s=%%A" & set "_pa_l=%%B"
if not defined _pa_l set "_pa_l=%_pa_s%"
set "_pa_opt_%_pa_s%=%_pa_l%"
set "_pa_opt_%_pa_l%=%_pa_l%"
if defined _pa_v set "_pa_val_%_pa_l%=1"
exit /b 0
