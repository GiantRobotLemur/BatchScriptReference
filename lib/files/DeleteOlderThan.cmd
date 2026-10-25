@echo off
:: ===========================================================================
:: DeleteOlderThan  dir mask days [/S]
::   Deletes files in dir matching mask whose last-modified DATE is at least
::   days days before today (FORFILES /D -days, so whole days, not hours).
::   /S also searches sub-directories. Directories themselves are never deleted.
::   ERRORLEVEL: 0 ok (including "nothing to delete") | 1 usage
::               | 2 dir is not a directory
::   Requires:   Windows Vista+ (FORFILES)
::   Limits:     FORFILES does not accept UNC paths - map a drive or PUSHD first.
::   Docs:       lib/files/README.md#deleteolderthan
:: ===========================================================================
setlocal EnableExtensions DisableDelayedExpansion
if "%~3"=="" exit /b 1
rem Any character that is not a digit leaves a token behind -> not a number.
for /f "delims=0123456789" %%A in ("%~3") do exit /b 1
set "_attr=%~a1"
if not defined _attr exit /b 2
if /i not "%_attr:~0,1%"=="d" exit /b 2

set "_dir=%~f1"
if "%_dir:~-1%"=="\" set "_dir=%_dir%."
set "_recurse="
if /i "%~4"=="/S" set "_recurse=/s"

rem FORFILES returns 1 and prints an error when nothing matches: ignore both.
rem It also writes a blank line to stdout before running the commands.
forfiles /p "%_dir%" /m "%~2" %_recurse% /d -%~3 /c "cmd /c if @isdir==FALSE del /f /q @path" >nul 2>&1
exit /b 0
