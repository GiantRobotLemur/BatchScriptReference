@echo off
:: ===========================================================================
:: IsAdmin
::   Tests whether the script is running elevated (UAC "Run as administrator")
::   or as SYSTEM.  Typical use:  call "%BATLIB%\system\IsAdmin.cmd" || goto :NeedAdmin
::   ERRORLEVEL: 0 elevated | 2 not elevated
::   Requires:   Windows Vista+ (WHOAMI); NET SESSION fallback for XP
::   Docs:       lib/system/README.md#isadmin
:: ===========================================================================
setlocal EnableExtensions DisableDelayedExpansion
rem Mandatory integrity level SIDs: S-1-16-12288 = High (elevated admin),
rem S-1-16-16384 = System. Present in the token from Vista onwards.
whoami /groups 2>nul | findstr /c:"S-1-16-12288" /c:"S-1-16-16384" >nul && exit /b 0
rem Fallback (XP has no integrity levels): NET SESSION needs admin rights.
rem It also fails if the Server (LanmanServer) service is stopped.
net session >nul 2>&1 && exit /b 0
exit /b 2
