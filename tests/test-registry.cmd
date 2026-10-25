@echo off
setlocal EnableExtensions DisableDelayedExpansion
set ASSERT=call "%~dp0_assert.cmd"
set "BATLIB=%~dp0..\lib"
%ASSERT% :Begin "registry"

rem Fixtures live under HKCU (no admin rights needed) and are removed at the end.
set "TK=HKCU\Software\BatchScriptReferenceTest"
set "AP=HKCU\Software\Microsoft\Windows\CurrentVersion\App Paths\bsrtest-app.exe"
set "UN=HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall"
call :Cleanup
reg add "%TK%" /ve /d "default data" /f >nul
rem REG.EXE reads \" as an escaped quote: a trailing backslash must be doubled.
reg add "%TK%" /v "Plain" /d "C:\Program Files (x86)\Some App\\" /f >nul
reg add "%TK%" /v "Name With Spaces" /d "a & b" /f >nul
reg add "%TK%" /v "Number" /t REG_DWORD /d 42 /f >nul
reg add "%TK%" /v "Expand" /t REG_EXPAND_SZ /d "%%SystemRoot%%\x" /f >nul
reg add "%AP%" /ve /t REG_EXPAND_SZ /d "\"%%SystemRoot%%\System32\cmd.exe\"" /f >nul
reg add "%UN%\BsrTestProductA" /v DisplayName /d "BSR Test Product Alpha 1.0" /f >nul
reg add "%UN%\BsrTestProductA" /v InstallLocation /d "C:\Program Files\BSR Alpha\\" /f >nul
reg add "%UN%\BsrTestProductB" /v DisplayName /d "BSR Test Product Beta" /f >nul
reg add "%UN%\BsrTestProductB" /v DisplayIcon /d "\"C:\Program Files\BSR Beta\beta.exe\",0" /f >nul
reg add "%UN%\BsrTestProductC" /v DisplayName /d "BSR Test Product Gamma" /f >nul

rem --- RegQueryValue ----------------------------------------------------------
call "%BATLIB%\registry\RegQueryValue.cmd" v "%TK%" Plain
%ASSERT% :AssertEqual "RegQueryValue succeeds" "0" "%errorlevel%"
%ASSERT% :AssertVar "RegQueryValue REG_SZ data" v "C:\Program Files (x86)\Some App\"
%ASSERT% :AssertVar "RegQueryValue sets _TYPE" v_TYPE "REG_SZ"
call "%BATLIB%\registry\RegQueryValue.cmd" v "%TK%" "Name With Spaces"
%ASSERT% :AssertVar "RegQueryValue value name with spaces" v "a & b"
call "%BATLIB%\registry\RegQueryValue.cmd" v "%TK%"
%ASSERT% :AssertVar "RegQueryValue default value" v "default data"
call "%BATLIB%\registry\RegQueryValue.cmd" v "%TK%" Number
%ASSERT% :AssertVar "RegQueryValue REG_DWORD is hex" v "0x2a"
set /a n=v
%ASSERT% :AssertEqual "RegQueryValue REG_DWORD via SET /A" "42" "%n%"
call "%BATLIB%\registry\RegQueryValue.cmd" v "%TK%" Expand
%ASSERT% :AssertVar "RegQueryValue REG_EXPAND_SZ unexpanded type" v_TYPE "REG_EXPAND_SZ"
call set "v=%v%"
%ASSERT% :AssertVar "RegQueryValue REG_EXPAND_SZ expanded with CALL SET" v "%SystemRoot%\x"
call "%BATLIB%\registry\RegQueryValue.cmd" v "%TK%" Missing
%ASSERT% :AssertEqual "RegQueryValue missing value returns 2" "2" "%errorlevel%"
call "%BATLIB%\registry\RegQueryValue.cmd" v "%TK%\NoSuchKey" Plain
%ASSERT% :AssertEqual "RegQueryValue missing key returns 2" "2" "%errorlevel%"
call "%BATLIB%\registry\RegQueryValue.cmd" v "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" CurrentBuild 64
%ASSERT% :AssertEqual "RegQueryValue with 64-bit view" "0" "%errorlevel%"
call "%BATLIB%\registry\RegQueryValue.cmd" v
%ASSERT% :AssertEqual "RegQueryValue usage error" "1" "%errorlevel%"

rem --- FindAppPath ------------------------------------------------------------
call "%BATLIB%\registry\FindAppPath.cmd" p bsrtest-app
%ASSERT% :AssertEqual "FindAppPath succeeds" "0" "%errorlevel%"
%ASSERT% :AssertVar "FindAppPath unquoted and expanded" p "%SystemRoot%\System32\cmd.exe"
call "%BATLIB%\registry\FindAppPath.cmd" p no-such-app-bsr.exe
%ASSERT% :AssertEqual "FindAppPath not registered returns 2" "2" "%errorlevel%"

rem --- FindInstallPath --------------------------------------------------------
call "%BATLIB%\registry\FindInstallPath.cmd" d "test product alpha"
%ASSERT% :AssertEqual "FindInstallPath succeeds" "0" "%errorlevel%"
%ASSERT% :AssertVar "FindInstallPath from InstallLocation" d "C:\Program Files\BSR Alpha"
%ASSERT% :AssertVar "FindInstallPath sets _KEY" d_KEY "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Uninstall\BsrTestProductA"
call "%BATLIB%\registry\FindInstallPath.cmd" d "BSR Test Product Beta"
%ASSERT% :AssertVar "FindInstallPath from DisplayIcon" d "C:\Program Files\BSR Beta"
call "%BATLIB%\registry\FindInstallPath.cmd" d "BSR Test Product Gamma"
%ASSERT% :AssertEqual "FindInstallPath no location returns 3" "3" "%errorlevel%"
call "%BATLIB%\registry\FindInstallPath.cmd" d "No Such Product BSR 9z"
%ASSERT% :AssertEqual "FindInstallPath no match returns 2" "2" "%errorlevel%"

call :Cleanup
%ASSERT% :End
exit /b %errorlevel%

:Cleanup
reg delete "%TK%" /f >nul 2>&1
reg delete "%AP%" /f >nul 2>&1
for %%P in (A B C) do reg delete "%UN%\BsrTestProduct%%P" /f >nul 2>&1
exit /b 0
