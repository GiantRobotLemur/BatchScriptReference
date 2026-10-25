@echo off
:: ===========================================================================
:: FindInPath  outVar program
::   Sets outVar to the full path of the first program found the way cmd.exe
::   would find it: current directory first, then each PATH directory, trying
::   the name as given and then with each %PATHEXT% extension appended.
::   Does not see built-in commands (DIR, COPY ...) or App Paths entries.
::   ERRORLEVEL: 0 found | 1 usage | 2 not found
::   Requires:   Windows 2000+ (no WHERE.EXE needed)
::   Docs:       lib/system/README.md#findinpath
:: ===========================================================================
setlocal EnableExtensions DisableDelayedExpansion
if "%~1"=="" exit /b 1
if "%~2"=="" exit /b 1
set "_r="
rem The ~$PATH: modifier searches the current directory, then PATH.
for %%A in ("%~2") do set "_r=%%~$PATH:A"
if defined _r goto :FindInPath_done
set "_pathext=%PATHEXT%"
if not defined _pathext set "_pathext=.COM;.EXE;.BAT;.CMD"
for %%E in (%_pathext%) do if not defined _r for %%A in ("%~2%%E") do set "_r=%%~$PATH:A"
if not defined _r exit /b 2

:FindInPath_done
endlocal & set "%~1=%_r%"
exit /b 0
