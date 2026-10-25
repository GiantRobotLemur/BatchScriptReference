@echo off
:: ===========================================================================
:: run-tests.cmd [filter]
::   Runs every tests\test-*.cmd (or tests\test-<filter>*.cmd) and prints a
::   summary. ERRORLEVEL 0 if every assertion passed, 1 otherwise.
::
::   tests\run-tests.cmd            run all suites
::   tests\run-tests.cmd strings    run tests\test-strings*.cmd only
:: ===========================================================================
setlocal EnableExtensions DisableDelayedExpansion

set "T_RESULTS=%TEMP%\bsr-test-results-%RANDOM%%RANDOM%.txt"
type nul >"%T_RESULTS%"

set /a _suites=0, _failedSuites=0, _pass=0, _fail=0
for %%F in ("%~dp0test-%~1*.cmd") do (
    set /a _suites+=1
    call "%%~fF"
    if errorlevel 1 set /a _failedSuites+=1
)

for /f "usebackq tokens=1,2" %%A in ("%T_RESULTS%") do set /a _pass+=%%A, _fail+=%%B
del "%T_RESULTS%" 2>nul

echo.
echo ===========================================================================
echo  Suites: %_suites%   Failed suites: %_failedSuites%
echo  Assertions: %_pass% passed, %_fail% failed
echo ===========================================================================

if %_suites% equ 0 exit /b 1
if %_failedSuites% gtr 0 exit /b 1
exit /b 0
