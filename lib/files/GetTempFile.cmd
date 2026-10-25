@echo off
:: ===========================================================================
:: GetTempFile  outVar [prefix] [ext]
::   Sets outVar to the path of a new, empty file in %TEMP% named
::   prefix_<random>.ext. The file is created to reserve the name; delete it
::   when finished. prefix defaults to "tmp", ext to ".tmp".
::   ERRORLEVEL: 0 ok | 1 usage | 2 could not create a file (100 attempts)
::   Requires:   Windows 2000+
::   Docs:       lib/files/README.md#gettempfile
:: ===========================================================================
setlocal EnableExtensions DisableDelayedExpansion
if "%~1"=="" exit /b 1
set "_pre=%~2"
if not defined _pre set "_pre=tmp"
set "_ext=%~3"
if not defined _ext set "_ext=.tmp"
if not "%_ext:~0,1%"=="." set "_ext=.%_ext%"

set /a _tries=0
:GetTempFile_next
set /a _tries+=1
if %_tries% gtr 100 exit /b 2
set "_r=%TEMP%\%_pre%_%RANDOM%%RANDOM%%_ext%"
if exist "%_r%" goto :GetTempFile_next
rem Not atomic: another process could take the same name between the test
rem and the create, but 30-bit randomness makes that very unlikely.
2>nul (type nul >"%_r%") || goto :GetTempFile_next

endlocal & set "%~1=%_r%"
exit /b 0
