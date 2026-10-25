@echo off
:: ===========================================================================
:: StrLen  outVar inVar
::   Sets outVar to the length of the string held in variable inVar
::   (inVar is a variable NAME, not a value). Undefined/empty -> 0.
::   ERRORLEVEL: 0 ok | 1 usage
::   Requires:   Windows 2000+
::   Docs:       lib/strings/README.md#strlen
:: ===========================================================================
setlocal EnableExtensions EnableDelayedExpansion
if "%~1"=="" exit /b 1
if "%~2"=="" exit /b 1
rem Binary search on the string length; the trailing # means the string is
rem never empty. 4096+2048+...+1 covers the 8191 character cmd.exe limit.
set "_s=!%~2!#"
set "_len=0"
for %%P in (4096 2048 1024 512 256 128 64 32 16 8 4 2 1) do (
    if not "!_s:~%%P,1!"=="" (
        set /a "_len+=%%P"
        set "_s=!_s:~%%P!"
    )
)
endlocal & set "%~1=%_len%"
exit /b 0
