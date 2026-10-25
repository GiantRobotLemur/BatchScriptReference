@echo off
setlocal EnableExtensions DisableDelayedExpansion
set ASSERT=call "%~dp0_assert.cmd"
set "BATLIB=%~dp0..\lib"
%ASSERT% :Begin "strings"

rem --- StrLen -----------------------------------------------------------------
set "s=hello world"
call "%BATLIB%\strings\StrLen.cmd" n s
%ASSERT% :AssertEqual "StrLen simple" "11" "%n%"

set "s="
call "%BATLIB%\strings\StrLen.cmd" n s
%ASSERT% :AssertEqual "StrLen undefined is 0" "0" "%n%"

set "s=a&b|c<d>e^f(g)h"
call "%BATLIB%\strings\StrLen.cmd" n s
%ASSERT% :AssertEqual "StrLen special characters" "15" "%n%"

set "s=x!y"
call "%BATLIB%\strings\StrLen.cmd" n s
%ASSERT% :AssertEqual "StrLen with exclamation mark" "3" "%n%"

setlocal EnableDelayedExpansion
set "s="
for /l %%i in (1,1,100) do set "s=!s!0123456789"
endlocal & set "s=%s%"
call "%BATLIB%\strings\StrLen.cmd" n s
%ASSERT% :AssertEqual "StrLen 1000 chars" "1000" "%n%"

call "%BATLIB%\strings\StrLen.cmd" n
%ASSERT% :AssertEqual "StrLen usage error" "1" "%errorlevel%"

rem --- ToUpper / ToLower ------------------------------------------------------
set "s=Hello, World 123 & more"
call "%BATLIB%\strings\ToUpper.cmd" u s
%ASSERT% :AssertVar "ToUpper" u "HELLO, WORLD 123 & MORE"
call "%BATLIB%\strings\ToLower.cmd" l s
%ASSERT% :AssertVar "ToLower" l "hello, world 123 & more"

set "s=MiXeD"
call "%BATLIB%\strings\ToLower.cmd" s s
%ASSERT% :AssertVar "ToLower in place" s "mixed"

set "s="
call "%BATLIB%\strings\ToUpper.cmd" u s
%ASSERT% :AssertUndefined "ToUpper of undefined stays undefined" u

rem --- Trim -------------------------------------------------------------------
set "s=   padded text   "
call "%BATLIB%\strings\Trim.cmd" t s
%ASSERT% :AssertVar "Trim both ends" t "padded text"

set "s=no-padding"
call "%BATLIB%\strings\Trim.cmd" t s
%ASSERT% :AssertVar "Trim no-op" t "no-padding"

set "s=     "
call "%BATLIB%\strings\Trim.cmd" t s
%ASSERT% :AssertUndefined "Trim all spaces gives undefined" t

set "s=  a & b  "
call "%BATLIB%\strings\Trim.cmd" s s
%ASSERT% :AssertVar "Trim in place with ampersand" s "a & b"

%ASSERT% :End
exit /b %errorlevel%
