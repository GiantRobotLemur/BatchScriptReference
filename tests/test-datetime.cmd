@echo off
setlocal EnableExtensions DisableDelayedExpansion
set ASSERT=call "%~dp0_assert.cmd"
set "BATLIB=%~dp0..\lib"
set "WORK=%TEMP%\bsr-test-datetime-%RANDOM%"
md "%WORK%"
%ASSERT% :Begin "datetime"

rem --- GetTimestamp -----------------------------------------------------------
call "%BATLIB%\datetime\GetTimestamp.cmd" ts
%ASSERT% :AssertEqual "GetTimestamp succeeds" "0" "%errorlevel%"
echo(%ts%|findstr /r /x "[0-9][0-9][0-9][0-9][01][0-9][0-3][0-9]_[0-2][0-9][0-5][0-9][0-5][0-9]" >nul
%ASSERT% :AssertEqual "GetTimestamp default format YYYYMMDD_hhnnss [%ts%]" "0" "%errorlevel%"

call "%BATLIB%\datetime\GetTimestamp.cmd" ts "YYYY-MM-DD hh:nn:ss"
echo(%ts%|findstr /r /x /c:"[0-9][0-9][0-9][0-9]-[01][0-9]-[0-3][0-9] [0-2][0-9]:[0-5][0-9]:[0-5][0-9]" >nul
%ASSERT% :AssertEqual "GetTimestamp custom format [%ts%]" "0" "%errorlevel%"

call "%BATLIB%\datetime\GetTimestamp.cmd" year "YYYY"
if %year% geq 2000 (set "ok=1") else set "ok=0"
%ASSERT% :AssertEqual "GetTimestamp year is plausible [%year%]" "1" "%ok%"

call "%BATLIB%\datetime\GetTimestamp.cmd"
%ASSERT% :AssertEqual "GetTimestamp usage error" "1" "%errorlevel%"

rem --- TimestampName ----------------------------------------------------------
call "%BATLIB%\datetime\TimestampName.cmd" f "%WORK%" backup zip
%ASSERT% :AssertEqual "TimestampName succeeds" "0" "%errorlevel%"
echo(%f%|findstr /r /i /c:"\\backup_[0-9]*_[0-9]*\.zip$" >nul
%ASSERT% :AssertEqual "TimestampName shape [%f%]" "0" "%errorlevel%"
for %%A in ("%f%") do set "fdir=%%~dpA"
%ASSERT% :AssertEqual "TimestampName in requested dir" "%WORK%\" "%fdir%"

rem Taking the name forces the _2 suffix. Retry in case the second ticked over.
set /a tries=0
:retry
set /a tries+=1
call "%BATLIB%\datetime\TimestampName.cmd" f1 "%WORK%" log .txt
type nul >"%f1%"
call "%BATLIB%\datetime\TimestampName.cmd" f2 "%WORK%" log .txt
if not "%f2%"=="%f1:~0,-4%_2.txt" if %tries% lss 3 goto :retry
%ASSERT% :AssertEqual "TimestampName appends _2 when taken" "%f1:~0,-4%_2.txt" "%f2%"

call "%BATLIB%\datetime\TimestampName.cmd" f "%WORK%"
echo(%f%|findstr /r /x /c:".*\\[0-9]*_[0-9]*" >nul
%ASSERT% :AssertEqual "TimestampName without prefix or ext [%f%]" "0" "%errorlevel%"

call "%BATLIB%\datetime\TimestampName.cmd" f
%ASSERT% :AssertEqual "TimestampName usage error" "1" "%errorlevel%"

rd /s /q "%WORK%"
%ASSERT% :End
exit /b %errorlevel%
