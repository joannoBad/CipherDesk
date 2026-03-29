@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
powershell -ExecutionPolicy Bypass -STA -File "%SCRIPT_DIR%CipherDesk.ps1"
