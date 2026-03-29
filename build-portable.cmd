@echo off
setlocal

set "ROOT_DIR=%~dp0"
set "RELEASE_DIR=%ROOT_DIR%release\CipherDesk-Portable"

if exist "%RELEASE_DIR%" rmdir /S /Q "%RELEASE_DIR%"

mkdir "%RELEASE_DIR%"

copy /Y "%ROOT_DIR%CipherDesk.ps1" "%RELEASE_DIR%\CipherDesk.ps1" >nul
copy /Y "%ROOT_DIR%CipherDeskLauncher.exe" "%RELEASE_DIR%\CipherDeskLauncher.exe" >nul
copy /Y "%ROOT_DIR%Launch-CipherDesk.cmd" "%RELEASE_DIR%\Launch-CipherDesk.cmd" >nul

(
echo Cipher Desk Portable
echo.
echo Start the app with:
echo - CipherDeskLauncher.exe
echo - or Launch-CipherDesk.cmd
echo.
echo Notes:
echo - Works offline
echo - Does not need installation
echo - Keep CipherDesk.ps1 next to the launcher files
) > "%RELEASE_DIR%\README-PORTABLE.txt"

echo Portable package created:
echo %RELEASE_DIR%
exit /b 0
