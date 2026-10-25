@echo off
:: ===========================================================================
:: Trim  outVar inVar
::   Sets outVar to the value of variable inVar with leading and trailing
::   spaces removed. outVar may be the same as inVar.
::   ERRORLEVEL: 0 ok | 1 usage
::   Requires:   Windows 2000+
::   Docs:       lib/strings/README.md#trim
:: ===========================================================================
setlocal EnableExtensions EnableDelayedExpansion
if "%~1"=="" exit /b 1
if "%~2"=="" exit /b 1
set "_s=!%~2!"

:Trim_lead
if not defined _s goto :Trim_done
if "!_s:~0,1!"==" " (set "_s=!_s:~1!" & goto :Trim_lead)

:Trim_trail
if "!_s:~-1!"==" " (set "_s=!_s:~0,-1!" & goto :Trim_trail)

:Trim_done
endlocal & set "%~1=%_s%"
exit /b 0
