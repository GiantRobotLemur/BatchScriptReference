@echo off
:: ===========================================================================
:: EnsureDir  path
::   Creates directory path (and any missing parents) unless it already exists.
::   ERRORLEVEL: 0 ok (exists or created) | 1 usage | 2 path exists as a file
::               | 3 could not create
::   Requires:   Windows 2000+ (MKDIR creates parents with extensions enabled)
::   Docs:       lib/files/README.md#ensuredir
:: ===========================================================================
setlocal EnableExtensions DisableDelayedExpansion
if "%~1"=="" exit /b 1
rem The ~a modifier gives the attribute string ("d----------" for a
rem directory) and is empty when the path does not exist.
set "_attr=%~a1"
if not defined _attr goto :EnsureDir_create
if /i "%_attr:~0,1%"=="d" exit /b 0
exit /b 2

:EnsureDir_create
mkdir "%~f1" 2>nul
if not exist "%~f1\" exit /b 3
exit /b 0
