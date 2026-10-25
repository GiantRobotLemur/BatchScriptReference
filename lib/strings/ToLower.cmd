@echo off
:: ===========================================================================
:: ToLower  outVar inVar
::   Sets outVar to the value of variable inVar converted to lower case
::   (ASCII letters only). outVar may be the same as inVar.
::   ERRORLEVEL: 0 ok | 1 usage
::   Requires:   Windows 2000+
::   Docs:       lib/strings/README.md#toupper--tolower
:: ===========================================================================
setlocal EnableExtensions EnableDelayedExpansion
if "%~1"=="" exit /b 1
if "%~2"=="" exit /b 1
set "_s=!%~2!"
rem !var:X=x! search is case-insensitive, so replacing each letter with
rem itself in lower case lower-cases every occurrence.
if defined _s for %%C in (a b c d e f g h i j k l m n o p q r s t u v w x y z) do set "_s=!_s:%%C=%%C!"
endlocal & set "%~1=%_s%"
exit /b 0
