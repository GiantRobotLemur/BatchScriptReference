@echo off
:: ===========================================================================
:: RotateFiles  dir mask keep
::   Keeps the newest keep files in dir matching mask (by last-modified time)
::   and deletes the rest. Sub-directories are not touched.
::   ERRORLEVEL: 0 ok | 1 usage | 2 dir is not a directory
::   Requires:   Windows 2000+
::   Limits:     DIR also matches 8.3 short names, so *.log can match x.logx.
::   Docs:       lib/files/README.md#rotatefiles
:: ===========================================================================
setlocal EnableExtensions DisableDelayedExpansion
if "%~3"=="" exit /b 1
for /f "delims=0123456789" %%A in ("%~3") do exit /b 1
set "_attr=%~a1"
if not defined _attr exit /b 2
if /i not "%_attr:~0,1%"=="d" exit /b 2

set "_dir=%~f1"
if "%_dir:~-1%"=="\" set "_dir=%_dir:~0,-1%"

rem Strip leading zeros (SET /A and SKIP= would treat 08 as bad octal).
set "_keep="
for /f "tokens=* delims=0" %%A in ("%~3") do set "_keep=%%A"
rem FOR /F rejects skip=0, so only add the option when keep > 0.
set "_skip="
if defined _keep set "_skip=skip=%_keep% "

rem eol=: because ':' cannot appear in a file name (default eol ';' can).
for /f "%_skip%eol=: delims=" %%F in ('dir /b /a-d /o-d "%_dir%\%~2" 2^>nul') do (
    del /f /q "%_dir%\%%F"
)
exit /b 0
