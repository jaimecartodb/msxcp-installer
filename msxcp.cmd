@echo off
REM MSXCP launcher (cmd shim — invoked by msxcp.exe inside the winget portable zip).
REM Delegates to msxcp.ps1 in the same directory, forwarding all arguments.
setlocal
set "_HERE=%~dp0"
powershell.exe -NoLogo -ExecutionPolicy Bypass -File "%_HERE%msxcp.ps1" %*
exit /b %ERRORLEVEL%
