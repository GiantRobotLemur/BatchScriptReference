@echo off
:: ===========================================================================
:: FindInstallPath  outVar displayName
::   Finds the first installed product whose DisplayName in the Windows
::   "Uninstall" registry keys contains displayName (case-insensitive) and
::   sets outVar to its install directory (no trailing backslash) and
::   outVar_KEY to the product's registry key.
::   Directory = InstallLocation, else the folder of DisplayIcon.
::   Search order: HKLM (64-bit view), HKLM\WOW6432Node (32-bit apps), HKCU.
::   ERRORLEVEL: 0 ok | 1 usage | 2 no matching product
::               | 3 product found but no location recorded
::   Requires:   Windows Vista+ (REG QUERY /F)
::   Depends:    lib\registry\RegQueryValue.cmd
::   Docs:       lib/registry/README.md#findinstallpath
:: ===========================================================================
setlocal EnableExtensions DisableDelayedExpansion
if "%~1"=="" exit /b 1
if "%~2"=="" exit /b 1
set "_name=%~2"
set "_key="
for %%R in (
    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall"
) do if not defined _key call :FindInstallPath_search %%R
if not defined _key exit /b 2

set "_loc="
call "%~dp0RegQueryValue.cmd" _loc "%_key%" InstallLocation
if defined _loc goto :FindInstallPath_done

rem DisplayIcon is usually "C:\path\app.exe",0 - keep the folder part.
set "_icon="
call "%~dp0RegQueryValue.cmd" _icon "%_key%" DisplayIcon
if not defined _icon exit /b 3
set "_icon=%_icon:"=%"
for /f "delims=," %%I in ("%_icon%") do set "_icon=%%I"
for %%I in ("%_icon%") do set "_loc=%%~dpI"

:FindInstallPath_done
set "_loc=%_loc:"=%"
if "%_loc:~-1%"=="\" set "_loc=%_loc:~0,-1%"
endlocal & set "%~1=%_loc%" & set "%~1_KEY=%_key%"
exit /b 0

:FindInstallPath_search  root
rem REG /F /D matches the text anywhere in any value's data, so remember the
rem current key and accept only matches on the DisplayName value.
set "_cur="
for /f "delims=" %%L in ('reg query "%~1" /s /f "%_name%" /d 2^>nul') do (
    set "_line=%%L"
    call :FindInstallPath_line
    if defined _key exit /b 0
)
exit /b 0

:FindInstallPath_line
if "%_line:~0,5%"=="HKEY_" (set "_cur=%_line%" & exit /b 0)
for /f "tokens=1,2,*" %%A in ("%_line%") do (
    if /i "%%A"=="DisplayName" if /i "%%B"=="REG_SZ" set "_key=%_cur%"
)
exit /b 0
