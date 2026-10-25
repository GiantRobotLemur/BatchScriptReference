@echo off
:: ===========================================================================
:: ToUpper  outVar inVar
::   Sets outVar to the value of variable inVar converted to upper case
::   (ASCII letters only). outVar may be the same as inVar.
::   ERRORLEVEL: 0 ok | 1 usage
::   Requires:   Windows 2000+
::   Docs:       lib/strings/README.md#toupper--tolower
:: ===========================================================================
setlocal EnableExtensions EnableDelayedExpansion
if "%~1"=="" exit /b 1
if "%~2"=="" exit /b 1
set "_s=!%~2!"
rem !var:x=X! search is case-insensitive, so replacing each letter with
rem itself in upper case upper-cases every occurrence.
if defined _s for %%C in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do set "_s=!_s:%%C=%%C!"
endlocal & set "%~1=%_s%"
exit /b 0
