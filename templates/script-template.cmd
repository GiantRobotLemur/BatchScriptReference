@echo off
:: ===========================================================================
:: script-template.cmd - model script to copy and adapt.
::
:: Usage: script-template [options] <input> [<input> ...]
:: Copies each input file into an output directory, logging as it goes.
:: Replace the "Main" section with real work; keep the rest.
::
:: Exit codes: 0 ok | 1 bad arguments | 2 input missing | 3 operation failed
:: ===========================================================================
setlocal EnableExtensions DisableDelayedExpansion

set "SCRIPT=%~n0"
rem BATLIB points at the library's lib folder. Set it in the environment, or
rem adjust this default (here: the repo layout, templates\..\lib).
if not defined BATLIB set "BATLIB=%~dp0..\lib"
if not exist "%BATLIB%\args\ParseArgs.cmd" (
    >&2 echo %SCRIPT%: cannot find the batch library. Set BATLIB.
    exit /b 1
)

rem --- Arguments ------------------------------------------------------------
rem Handle the help switch before any CALL: an unquoted /? in CALL's
rem arguments makes CALL print its own help instead of running the target.
if "%~1"=="/?" goto :Usage
if "%~1"=="-?" goto :Usage

call "%BATLIB%\args\ParseArgs.cmd" OPT "h|help o|out: v|verbose n|dry-run" %*
if errorlevel 2 (
    >&2 echo %SCRIPT%: %OPT_ERROR%
    >&2 echo Try "%SCRIPT% --help".
    exit /b 1
)
if defined OPT_help goto :Usage
if %OPT_ARGC% lss 1 (
    >&2 echo %SCRIPT%: no input files given. Try "%SCRIPT% --help".
    exit /b 1
)

set "OUTDIR=%OPT_out%"
if not defined OUTDIR set "OUTDIR=%CD%\out"

rem --- Logging --------------------------------------------------------------
rem One log file per run: %TEMP%\script-template_YYYYMMDD_hhnnss.log
call "%BATLIB%\datetime\TimestampName.cmd" LOGFILE "%TEMP%" "%SCRIPT%" log
call :Log INFO "Started %SCRIPT% with %OPT_ARGC% input(s), output to %OUTDIR%"
call :Log DEBUG "Log file: %LOGFILE%"

rem --- Main -----------------------------------------------------------------
set "RC=0"
if not defined OPT_dry-run call "%BATLIB%\files\EnsureDir.cmd" "%OUTDIR%"
if errorlevel 1 (
    call :Log ERROR "Cannot create output directory: %OUTDIR%"
    set "RC=3"
    goto :Cleanup
)

rem Positional arguments are OPT_ARG1..OPT_ARG<n>; loop with a counter.
set /a I=0
:NextInput
set /a I+=1
if %I% gtr %OPT_ARGC% goto :Cleanup
call set "INPUT=%%OPT_ARG%I%%%"
call :ProcessFile "%INPUT%"
if errorlevel 1 if %RC% equ 0 set "RC=%errorlevel%"
goto :NextInput

:Cleanup
rem Release resources here (temp files, PUSHD, services stopped, ...).
call :Log INFO "Finished with exit code %RC%"
exit /b %RC%


:: ===========================================================================
:: Subroutines
:: ===========================================================================

:ProcessFile  file
rem Returns ERRORLEVEL 2 if the input is missing, 3 if the copy fails.
if not exist "%~1" (
    call :Log ERROR "Input not found: %~1"
    exit /b 2
)
if defined OPT_dry-run (
    call :Log INFO "Would copy %~nx1 to %OUTDIR%"
    exit /b 0
)
call :Log DEBUG "Copying %~f1"
copy /y "%~f1" "%OUTDIR%\" >nul 2>&1 || (
    call :Log ERROR "Copy failed: %~nx1"
    exit /b 3
)
call :Log INFO "Copied %~nx1"
exit /b 0

:Log  level message
rem Writes "[hh:mm:ss] LEVEL message" to the console and the log file.
rem DEBUG lines appear only with --verbose. ERROR lines go to stderr.
setlocal
set "_lvl=%~1"
set "_msg=%~2"
if /i "%_lvl%"=="DEBUG" if not defined OPT_verbose exit /b 0
set "_t=%TIME: =0%"
setlocal EnableDelayedExpansion
if /i "!_lvl!"=="ERROR" (
    >&2 echo [!_t:~0,8!] !_lvl! !_msg!
) else (
    echo [!_t:~0,8!] !_lvl! !_msg!
)
if defined LOGFILE >>"!LOGFILE!" echo [!_t:~0,8!] !_lvl! !_msg!
endlocal
exit /b 0

:Usage
echo Usage: %SCRIPT% [options] ^<input^> [^<input^> ...]
echo.
echo Copies each input file into an output directory.
echo.
echo   -o, --out ^<dir^>    Output directory (default: .\out)
echo   -n, --dry-run      Show what would be done without doing it
echo   -v, --verbose      Show debug messages
echo   -h, --help, /?     Show this help
echo.
echo Exit codes: 0 ok, 1 bad arguments, 2 input missing, 3 operation failed
exit /b 0
