@echo off
:: ===========================================================================
:: MirrorDir  source dest [robocopy options...]
::   Makes dest an exact copy of source with ROBOCOPY /MIR.
::   WARNING: files in dest that are not in source are DELETED.
::   Defaults: /MIR /R:2 /W:5 /NP. Extra options are appended, e.g.
::     /XD .git /XF *.tmp     exclusions
::     /NFL /NDL /NJH /NJS    silence the per-file listing and summary
::   ERRORLEVEL: 0 ok (robocopy 0-7) | 1 usage | 2 source is not a directory
::               | 8-16 the robocopy failure code, unchanged
::   Requires:   Windows Vista+ (ROBOCOPY)
::   Docs:       lib/files/README.md#mirrordir
:: ===========================================================================
setlocal EnableExtensions DisableDelayedExpansion
if "%~1"=="" exit /b 1
if "%~2"=="" exit /b 1
set "_attr=%~a1"
if not defined _attr exit /b 2
if /i not "%_attr:~0,1%"=="d" exit /b 2

rem A trailing backslash before the closing quote ("D:\") is read by
rem robocopy as an escaped quote; "D:\." avoids that.
set "_src=%~f1"
set "_dst=%~f2"
if "%_src:~-1%"=="\" set "_src=%_src%."
if "%_dst:~-1%"=="\" set "_dst=%_dst%."

set "_opts="
:MirrorDir_opts
if [%3]==[] goto :MirrorDir_run
set _opts=%_opts% %3
shift /3
goto :MirrorDir_opts

:MirrorDir_run
robocopy "%_src%" "%_dst%" /MIR /R:2 /W:5 /NP %_opts%
rem Robocopy exit codes are a bitmask; 8 and above means something failed.
if errorlevel 8 exit /b %errorlevel%
exit /b 0
