@echo off
setlocal

set "ROOT_DIR=%~dp0"
powershell -ExecutionPolicy Bypass -File "%ROOT_DIR%make-portable-release.ps1" %*
exit /b %ERRORLEVEL%
