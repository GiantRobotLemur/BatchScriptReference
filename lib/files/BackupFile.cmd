@echo off
:: ===========================================================================
:: BackupFile  outVar file [destDir]
::   Copies file to destDir (default: the file's own directory) as
::   name_YYYYMMDD_hhnnss.ext and sets outVar to the new path.
::   destDir is created if missing.
::   ERRORLEVEL: 0 ok | 1 usage | 2 source missing or is a directory
::               | 3 destination unusable / no free name | 4 copy failed
::   Requires:   Windows Vista+ (via GetTimestamp)
::   Depends:    lib\files\EnsureDir.cmd, lib\datetime\TimestampName.cmd
::   Docs:       lib/files/README.md#backupfile
:: ===========================================================================
setlocal EnableExtensions DisableDelayedExpansion
if "%~1"=="" exit /b 1
if "%~2"=="" exit /b 1
set "_attr=%~a2"
if not defined _attr exit /b 2
if /i "%_attr:~0,1%"=="d" exit /b 2

set "_dest=%~3"
if not defined _dest set "_dest=%~dp2"
call "%~dp0EnsureDir.cmd" "%_dest%"
if errorlevel 1 exit /b 3

call "%~dp0..\datetime\TimestampName.cmd" _r "%_dest%" "%~n2" "%~x2"
if errorlevel 1 exit /b 3

copy /y /b "%~f2" "%_r%" >nul 2>&1
if errorlevel 1 exit /b 4

endlocal & set "%~1=%_r%"
exit /b 0
