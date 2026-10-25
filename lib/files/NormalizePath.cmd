@echo off
:: ===========================================================================
:: NormalizePath  outVar path
::   Sets outVar to the absolute form of path: resolved against the current
::   directory, "." and ".." collapsed, "/" turned into "\", and any trailing
::   backslash removed (except for a drive root such as C:\).
::   The path does not need to exist. Wildcards are not expanded.
::   ERRORLEVEL: 0 ok | 1 usage
::   Requires:   Windows 2000+
::   Docs:       lib/files/README.md#normalizepath
:: ===========================================================================
setlocal EnableExtensions DisableDelayedExpansion
if "%~1"=="" exit /b 1
if "%~2"=="" exit /b 1
set "_r=%~f2"
if not "%_r:~-1%"=="\" goto :NormalizePath_done
if "%_r:~-2%"==":\" goto :NormalizePath_done
set "_r=%_r:~0,-1%"

:NormalizePath_done
endlocal & set "%~1=%_r%"
exit /b 0
