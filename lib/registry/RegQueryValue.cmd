@echo off
:: ===========================================================================
:: RegQueryValue  outVar key [valueName] [32|64]
::   Sets outVar to the data of a registry value and outVar_TYPE to its type
::   (REG_SZ, REG_DWORD, ...). valueName omitted or "" reads the key's
::   (Default) value. 32 / 64 forces the 32- or 64-bit registry view.
::   Data is returned as REG.EXE prints it: REG_DWORD as 0x..., REG_EXPAND_SZ
::   unexpanded, REG_MULTI_SZ with \0 separators.
::   ERRORLEVEL: 0 ok | 1 usage | 2 key or value not found
::   Requires:   Windows XP+ (32/64 view: Windows 7+)
::   Docs:       lib/registry/README.md#regqueryvalue
:: ===========================================================================
setlocal EnableExtensions DisableDelayedExpansion
if "%~1"=="" exit /b 1
if "%~2"=="" exit /b 1
if "%~3"=="" (set "_sel=/ve") else set _sel=/v "%~3"
set "_view="
if "%~4"=="32" set "_view=/reg:32"
if "%~4"=="64" set "_view=/reg:64"

rem Value lines look like:  <4 spaces>Name<4 spaces>REG_SZ<4 spaces>Data
set "_line="
for /f "delims=" %%L in ('reg query "%~2" %_sel% %_view% 2^>nul ^| findstr /c:"    REG_"') do set "_line=%%L"
if not defined _line exit /b 2

rem Drop everything up to the type, then split "SZ    Data" into type and data.
set "_rest=%_line:*    REG_=%"
set "_type=" & set "_val="
for /f "tokens=1,*" %%T in ("%_rest%") do set "_type=REG_%%T" & set "_val=%%U"

endlocal & set "%~1=%_val%" & set "%~1_TYPE=%_type%"
exit /b 0
