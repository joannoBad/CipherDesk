@echo off
setlocal

set "ROOT_DIR=%~dp0.."
set "DIST_DIR=%ROOT_DIR%\dist"
set "CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"
for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss"') do set "STAMP=%%I"
set "OUTPUT_EXE=%DIST_DIR%\CipherDeskSetup-%STAMP%.exe"

if not exist "%DIST_DIR%" mkdir "%DIST_DIR%"

echo Building installer...
"%CSC%" /nologo /target:winexe /out:"%OUTPUT_EXE%" /reference:System.Windows.Forms.dll /reference:Microsoft.CSharp.dll /resource:"%ROOT_DIR%\CipherDesk.ps1",CipherDesk.ps1 /resource:"%ROOT_DIR%\CipherDeskLauncher.exe",CipherDeskLauncher.exe /resource:"%ROOT_DIR%\Launch-CipherDesk.cmd",Launch-CipherDesk.cmd /resource:"%ROOT_DIR%\README.md",README.md "%~dp0CipherDeskSetup.cs"

if errorlevel 1 goto :fail
if not exist "%OUTPUT_EXE%" goto :fail

echo Installer created: %OUTPUT_EXE%
exit /b 0

:fail
echo Installer build failed.
exit /b 1
