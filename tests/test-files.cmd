@echo off
setlocal EnableExtensions DisableDelayedExpansion
set ASSERT=call "%~dp0_assert.cmd"
set "BATLIB=%~dp0..\lib"
set "WORK=%TEMP%\bsr-test-files-%RANDOM%"
md "%WORK%"
%ASSERT% :Begin "files"

rem --- EnsureDir --------------------------------------------------------------
call "%BATLIB%\files\EnsureDir.cmd" "%WORK%\a\b c\d"
%ASSERT% :AssertEqual "EnsureDir creates nested dirs" "0" "%errorlevel%"
%ASSERT% :AssertExists "EnsureDir nested dir exists" "%WORK%\a\b c\d\"
call "%BATLIB%\files\EnsureDir.cmd" "%WORK%\a\b c\d"
%ASSERT% :AssertEqual "EnsureDir existing dir is ok" "0" "%errorlevel%"
call "%BATLIB%\files\EnsureDir.cmd" "%WORK%\a\b c\d\"
%ASSERT% :AssertEqual "EnsureDir trailing backslash is ok" "0" "%errorlevel%"
type nul >"%WORK%\afile"
call "%BATLIB%\files\EnsureDir.cmd" "%WORK%\afile"
%ASSERT% :AssertEqual "EnsureDir on a file returns 2" "2" "%errorlevel%"
call "%BATLIB%\files\EnsureDir.cmd"
%ASSERT% :AssertEqual "EnsureDir usage error" "1" "%errorlevel%"

rem --- NormalizePath ----------------------------------------------------------
pushd "%WORK%"
call "%BATLIB%\files\NormalizePath.cmd" p "x\..\y\.\z\"
%ASSERT% :AssertVar "NormalizePath relative" p "%WORK%\y\z"
call "%BATLIB%\files\NormalizePath.cmd" p "C:/Windows/System32"
%ASSERT% :AssertVar "NormalizePath forward slashes" p "C:\Windows\System32"
call "%BATLIB%\files\NormalizePath.cmd" p "C:\"
%ASSERT% :AssertVar "NormalizePath keeps drive root" p "C:\"
call "%BATLIB%\files\NormalizePath.cmd" p "*.txt"
%ASSERT% :AssertVar "NormalizePath does not expand wildcards" p "%WORK%\*.txt"
popd

rem --- GetTempFile ------------------------------------------------------------
call "%BATLIB%\files\GetTempFile.cmd" t bsrtest .dat
%ASSERT% :AssertEqual "GetTempFile succeeds" "0" "%errorlevel%"
%ASSERT% :AssertExists "GetTempFile reserves the file" "%t%"
for %%A in ("%t%") do set "tx=%%~xA" & set "tdir=%%~dpA"
%ASSERT% :AssertVar "GetTempFile extension" tx ".dat"
for %%A in ("%TEMP%\.") do set "tempdir=%%~fA\"
%ASSERT% :AssertVar "GetTempFile is in TEMP" tdir "%tempdir%"
del "%t%"
call "%BATLIB%\files\GetTempFile.cmd" t
for %%A in ("%t%") do set "tx=%%~xA"
%ASSERT% :AssertVar "GetTempFile default extension" tx ".tmp"
del "%t%"

rem --- BackupFile -------------------------------------------------------------
>"%WORK%\config.ini" echo key=value
call "%BATLIB%\files\BackupFile.cmd" b "%WORK%\config.ini"
%ASSERT% :AssertEqual "BackupFile succeeds" "0" "%errorlevel%"
%ASSERT% :AssertExists "BackupFile copy exists" "%b%"
echo(%b%|findstr /r /i /c:"\\config_[0-9]*_[0-9]*\.ini$" >nul
%ASSERT% :AssertEqual "BackupFile name shape [%b%]" "0" "%errorlevel%"
set "line="
set /p line=<"%b%"
%ASSERT% :AssertVar "BackupFile content copied" line "key=value"
call "%BATLIB%\files\BackupFile.cmd" b "%WORK%\config.ini" "%WORK%\backups"
%ASSERT% :AssertExists "BackupFile into new destDir" "%b%"
call "%BATLIB%\files\BackupFile.cmd" b "%WORK%\missing.ini"
%ASSERT% :AssertEqual "BackupFile missing source returns 2" "2" "%errorlevel%"
call "%BATLIB%\files\BackupFile.cmd" b "%WORK%\a"
%ASSERT% :AssertEqual "BackupFile directory source returns 2" "2" "%errorlevel%"

rem --- MirrorDir --------------------------------------------------------------
md "%WORK%\src\sub"
>"%WORK%\src\one.txt" echo 1
>"%WORK%\src\sub\two.txt" echo 2
>"%WORK%\src\skip.tmp" echo x
call "%BATLIB%\files\MirrorDir.cmd" "%WORK%\src" "%WORK%\dst" /XF *.tmp /NFL /NDL /NJH /NJS >nul
%ASSERT% :AssertEqual "MirrorDir succeeds" "0" "%errorlevel%"
%ASSERT% :AssertExists "MirrorDir copied file" "%WORK%\dst\one.txt"
%ASSERT% :AssertExists "MirrorDir copied sub-dir file" "%WORK%\dst\sub\two.txt"
%ASSERT% :AssertNotExists "MirrorDir honoured /XF" "%WORK%\dst\skip.tmp"
del "%WORK%\src\one.txt"
call "%BATLIB%\files\MirrorDir.cmd" "%WORK%\src" "%WORK%\dst" /NFL /NDL /NJH /NJS >nul
%ASSERT% :AssertNotExists "MirrorDir removes extra files" "%WORK%\dst\one.txt"
call "%BATLIB%\files\MirrorDir.cmd" "%WORK%\nope" "%WORK%\dst" >nul
%ASSERT% :AssertEqual "MirrorDir missing source returns 2" "2" "%errorlevel%"

rem --- RotateFiles ------------------------------------------------------------
md "%WORK%\logs"
for %%N in (1 2 3 4) do (
    >"%WORK%\logs\app%%N.log" echo %%N
    ping -n 2 127.0.0.1 >nul
)
>"%WORK%\logs\keep.txt" echo not a log
call "%BATLIB%\files\RotateFiles.cmd" "%WORK%\logs" "*.log" 2
%ASSERT% :AssertEqual "RotateFiles succeeds" "0" "%errorlevel%"
%ASSERT% :AssertNotExists "RotateFiles deleted oldest" "%WORK%\logs\app1.log"
%ASSERT% :AssertNotExists "RotateFiles deleted second oldest" "%WORK%\logs\app2.log"
%ASSERT% :AssertExists "RotateFiles kept newest" "%WORK%\logs\app4.log"
%ASSERT% :AssertExists "RotateFiles kept second newest" "%WORK%\logs\app3.log"
%ASSERT% :AssertExists "RotateFiles ignored non-matching" "%WORK%\logs\keep.txt"
call "%BATLIB%\files\RotateFiles.cmd" "%WORK%\logs" "*.log" 0
%ASSERT% :AssertNotExists "RotateFiles keep=0 deletes all" "%WORK%\logs\app4.log"
call "%BATLIB%\files\RotateFiles.cmd" "%WORK%\logs" "*.log" x
%ASSERT% :AssertEqual "RotateFiles non-numeric keep is usage error" "1" "%errorlevel%"

rem --- DeleteOlderThan --------------------------------------------------------
rem COPY preserves the last-modified time, so a copy of an old system file is
rem an "old" file. Only assert the deletion if win.ini really is > 30 days old.
md "%WORK%\old"
copy /y "%SystemRoot%\win.ini" "%WORK%\old\ancient.txt" >nul
>"%WORK%\old\fresh.txt" echo new
set "isOld=0"
forfiles /p "%SystemRoot%" /m win.ini /d -30 >nul 2>&1 && set "isOld=1"
call "%BATLIB%\files\DeleteOlderThan.cmd" "%WORK%\old" "*.txt" 30
%ASSERT% :AssertEqual "DeleteOlderThan succeeds" "0" "%errorlevel%"
%ASSERT% :AssertExists "DeleteOlderThan keeps recent file" "%WORK%\old\fresh.txt"
if "%isOld%"=="1" %ASSERT% :AssertNotExists "DeleteOlderThan removed old file" "%WORK%\old\ancient.txt"
call "%BATLIB%\files\DeleteOlderThan.cmd" "%WORK%\old" "*.none" 30
%ASSERT% :AssertEqual "DeleteOlderThan nothing to delete is ok" "0" "%errorlevel%"
call "%BATLIB%\files\DeleteOlderThan.cmd" "%WORK%\nope" "*.txt" 30
%ASSERT% :AssertEqual "DeleteOlderThan missing dir returns 2" "2" "%errorlevel%"
call "%BATLIB%\files\DeleteOlderThan.cmd" "%WORK%\old" "*.txt" 3x
%ASSERT% :AssertEqual "DeleteOlderThan non-numeric days is usage error" "1" "%errorlevel%"

rd /s /q "%WORK%"
%ASSERT% :End
exit /b %errorlevel%
