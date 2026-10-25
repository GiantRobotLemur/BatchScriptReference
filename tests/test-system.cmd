@echo off
setlocal EnableExtensions DisableDelayedExpansion
set ASSERT=call "%~dp0_assert.cmd"
set "BATLIB=%~dp0..\lib"
set "WORK=%TEMP%\bsr-test-system-%RANDOM%"
md "%WORK%"
%ASSERT% :Begin "system"

rem --- IsAdmin ----------------------------------------------------------------
rem Cross-check against a different technique: FLTMC needs admin rights.
call "%BATLIB%\system\IsAdmin.cmd"
set "rc=%errorlevel%"
fltmc >nul 2>&1 && (set "expect=0") || set "expect=2"
%ASSERT% :AssertEqual "IsAdmin agrees with FLTMC [rc=%rc%]" "%expect%" "%rc%"

rem --- FindInPath -------------------------------------------------------------
call "%BATLIB%\system\FindInPath.cmd" p cmd
%ASSERT% :AssertEqual "FindInPath succeeds" "0" "%errorlevel%"
%ASSERT% :AssertVarI "FindInPath applies PATHEXT" p "%SystemRoot%\System32\cmd.exe"
call "%BATLIB%\system\FindInPath.cmd" p "cmd.exe"
%ASSERT% :AssertVarI "FindInPath with extension" p "%SystemRoot%\System32\cmd.exe"
call "%BATLIB%\system\FindInPath.cmd" p no-such-program-bsr
%ASSERT% :AssertEqual "FindInPath not found returns 2" "2" "%errorlevel%"

>"%WORK%\bsr-local-tool.cmd" echo @echo off
pushd "%WORK%"
call "%BATLIB%\system\FindInPath.cmd" p bsr-local-tool
%ASSERT% :AssertVarI "FindInPath searches current dir first" p "%WORK%\bsr-local-tool.cmd"
popd

rd /s /q "%WORK%"
%ASSERT% :End
exit /b %errorlevel%
