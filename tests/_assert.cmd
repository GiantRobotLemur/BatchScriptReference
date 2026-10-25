@echo off
:: ===========================================================================
:: Assertion helpers for the test scripts (not part of the library).
::
::   set ASSERT=call "%~dp0_assert.cmd"
::   %ASSERT% :Begin "suite name"
::   %ASSERT% :AssertEqual     "description" "expected" "actual"
::   %ASSERT% :AssertVar       "description" VARNAME "expected"
::   %ASSERT% :AssertVarI      "description" VARNAME "expected"   (ignores case)
::   %ASSERT% :AssertUndefined "description" VARNAME
::   %ASSERT% :AssertExists    "description" "path"
::   %ASSERT% :AssertNotExists "description" "path"
::   %ASSERT% :End                 (ERRORLEVEL 1 if any assertion failed)
::
:: Counters T_PASS / T_FAIL live in the calling test script's environment, so
:: these helpers deliberately do not SETLOCAL around them. Descriptions are
:: echoed unquoted: keep them free of & | < > ^ characters.
:: If T_RESULTS names a file, :End appends "<pass> <fail>" to it (run-tests.cmd).
:: ===========================================================================
set "_a_fn=%~1"
shift
goto %_a_fn%

:Begin
set /a T_PASS=0, T_FAIL=0
echo.
echo === %~1
exit /b 0

:End
echo --- %T_PASS% passed, %T_FAIL% failed
if defined T_RESULTS >>"%T_RESULTS%" echo %T_PASS% %T_FAIL%
if %T_FAIL% gtr 0 exit /b 1
exit /b 0

:AssertEqual
set "_a_ci="
set "_a_exp=%~2"
set "_a_act=%~3"
goto :_Compare

:AssertVar
set "_a_ci="
:_AssertVar
set "_a_exp=%~3"
set "_a_act="
if not "%~2"=="" call set "_a_act=%%%~2%%"
goto :_Compare

:AssertVarI
set "_a_ci=/i"
goto :_AssertVar

:AssertUndefined
if not defined %~2 goto :_Pass
setlocal EnableDelayedExpansion
echo   FAIL  %~1
echo         expected %~2 to be undefined, but it is [!%~2!]
endlocal
goto :_Fail

:AssertExists
if exist "%~2" goto :_Pass
echo   FAIL  %~1
echo         path does not exist: %2
goto :_Fail

:AssertNotExists
if not exist "%~2" goto :_Pass
echo   FAIL  %~1
echo         path should not exist: %2
goto :_Fail

:_Compare
setlocal EnableDelayedExpansion
if %_a_ci% "!_a_exp!"=="!_a_act!" (endlocal & goto :_Pass)
echo   FAIL  %~1
echo         expected: [!_a_exp!]
echo         actual:   [!_a_act!]
endlocal
goto :_Fail

:_Pass
set /a T_PASS+=1
echo   PASS  %~1
exit /b 0

:_Fail
set /a T_FAIL+=1
exit /b 0
