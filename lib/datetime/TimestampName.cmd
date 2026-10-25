@echo off
:: ===========================================================================
:: TimestampName  outVar dir [prefix] [ext]
::   Sets outVar to a full path  dir\prefix_YYYYMMDD_hhnnss.ext  that does not
::   yet exist, appending _2, _3 ... when the name is already taken.
::   The file is NOT created and dir is NOT created (see EnsureDir).
::   prefix and ext are optional; ext may be given with or without the dot.
::   ERRORLEVEL: 0 ok | 1 usage | 2 timestamp failed | 3 no free name (999 tries)
::   Requires:   Windows Vista+ (via GetTimestamp)
::   Depends:    lib\datetime\GetTimestamp.cmd
::   Docs:       lib/datetime/README.md#timestampname
:: ===========================================================================
setlocal EnableExtensions DisableDelayedExpansion
if "%~1"=="" exit /b 1
if "%~2"=="" exit /b 1
set "_dir=%~f2"
if "%_dir:~-1%"=="\" set "_dir=%_dir:~0,-1%"
set "_pre=%~3"
if defined _pre set "_pre=%_pre%_"
set "_ext=%~4"
rem Never apply :~ or := to an undefined variable - jump past instead.
if not defined _ext goto :TimestampName_ts
if not "%_ext:~0,1%"=="." set "_ext=.%_ext%"

:TimestampName_ts
call "%~dp0GetTimestamp.cmd" _ts
if errorlevel 1 exit /b 2

set "_base=%_dir%\%_pre%%_ts%"
set "_r=%_base%%_ext%"
set /a _i=1
:TimestampName_next
if not exist "%_r%" goto :TimestampName_done
set /a _i+=1
if %_i% gtr 999 exit /b 3
set "_r=%_base%_%_i%%_ext%"
goto :TimestampName_next

:TimestampName_done
endlocal & set "%~1=%_r%"
exit /b 0
