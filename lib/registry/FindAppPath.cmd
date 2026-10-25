@echo off
:: ===========================================================================
:: FindAppPath  outVar exeName
::   Sets outVar to the full path of a program registered under
::   ...\CurrentVersion\App Paths\<exeName> (the key Explorer, START and the
::   Run box use). HKCU is checked before HKLM. ".exe" is added when exeName
::   has no extension. Environment variables in the value are expanded.
::   ERRORLEVEL: 0 ok | 1 usage | 2 not registered | 3 registered file missing
::   Requires:   Windows XP+
::   Depends:    lib\registry\RegQueryValue.cmd
::   Docs:       lib/registry/README.md#findapppath
:: ===========================================================================
setlocal EnableExtensions DisableDelayedExpansion
if "%~1"=="" exit /b 1
if "%~2"=="" exit /b 1
set "_exe=%~2"
if "%~x2"=="" set "_exe=%_exe%.exe"
set "_key=Software\Microsoft\Windows\CurrentVersion\App Paths\%_exe%"

set "_r="
for %%H in (HKCU HKLM) do if not defined _r call "%~dp0RegQueryValue.cmd" _r "%%H\%_key%"
if not defined _r exit /b 2

rem The value may be quoted and may contain %VARS% (REG_EXPAND_SZ).
set "_r=%_r:"=%"
call set "_r=%_r%"
if not exist "%_r%" exit /b 3

endlocal & set "%~1=%_r%"
exit /b 0
