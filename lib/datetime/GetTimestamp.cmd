@echo off
:: ===========================================================================
:: GetTimestamp  outVar [format]
::   Sets outVar to the current local date/time, independent of the regional
::   settings that change %DATE% and %TIME%.
::   format placeholders (case-insensitive): YYYY MM DD hh nn ss
::   Default format: YYYYMMDD_hhnnss  ->  20261024_193931
::   ERRORLEVEL: 0 ok | 1 usage | 2 no method available
::   Requires:   Windows Vista+ (ROBOCOPY); falls back to WMIC on XP
::   Docs:       lib/datetime/README.md#gettimestamp
:: ===========================================================================
setlocal EnableExtensions DisableDelayedExpansion
if "%~1"=="" exit /b 1
set "_fmt=%~2"
if not defined _fmt set "_fmt=YYYYMMDD_hhnnss"

rem ROBOCOPY logs errors with a fixed "yyyy/MM/dd HH:mm:ss" local timestamp.
rem An invalid source ("|") makes it print that line without copying anything.
set "_Y="
for /f "tokens=1-6 delims=/: " %%a in ('robocopy "|" . /njh /njs 2^>nul') do (
    if not defined _Y set "_Y=%%a" & set "_M=%%b" & set "_D=%%c" & set "_h=%%d" & set "_n=%%e" & set "_s=%%f"
)
call :GetTimestamp_valid && goto :GetTimestamp_format

rem Fallback for XP: WMIC (removed from current Windows 11 builds).
set "_ldt="
for /f "tokens=2 delims==" %%a in ('wmic os get localdatetime /value 2^>nul ^| find "="') do set "_ldt=%%a"
if not defined _ldt exit /b 2
set "_Y=%_ldt:~0,4%" & set "_M=%_ldt:~4,2%" & set "_D=%_ldt:~6,2%"
set "_h=%_ldt:~8,2%" & set "_n=%_ldt:~10,2%" & set "_s=%_ldt:~12,2%"
call :GetTimestamp_valid || exit /b 2

:GetTimestamp_format
set "_r=%_fmt%"
call set "_r=%%_r:YYYY=%_Y%%%"
call set "_r=%%_r:MM=%_M%%%"
call set "_r=%%_r:DD=%_D%%%"
call set "_r=%%_r:hh=%_h%%%"
call set "_r=%%_r:nn=%_n%%%"
call set "_r=%%_r:ss=%_s%%%"
endlocal & set "%~1=%_r%"
exit /b 0

:GetTimestamp_valid
rem ERRORLEVEL 0 if the six parts form exactly 14 digits.
echo(%_Y%%_M%%_D%%_h%%_n%%_s%|findstr /r /x "[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]" >nul
exit /b
