@echo off
setlocal

set "APP_NAME=Cipher Desk"
set "TARGET_DIR=%LocalAppData%\Programs\CipherDesk"
set "START_MENU_DIR=%AppData%\Microsoft\Windows\Start Menu\Programs\Cipher Desk"
set "DESKTOP_SHORTCUT=%UserProfile%\Desktop\Cipher Desk.lnk"

if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"
if not exist "%START_MENU_DIR%" mkdir "%START_MENU_DIR%"

copy /Y "CipherDesk.ps1" "%TARGET_DIR%\CipherDesk.ps1" >nul
copy /Y "CipherDeskLauncher.exe" "%TARGET_DIR%\CipherDeskLauncher.exe" >nul
copy /Y "Launch-CipherDesk.cmd" "%TARGET_DIR%\Launch-CipherDesk.cmd" >nul
copy /Y "README.md" "%TARGET_DIR%\README.md" >nul

(
echo @echo off
echo setlocal
echo set "TARGET_DIR=%%LocalAppData%%\Programs\CipherDesk"
echo set "START_MENU_DIR=%%AppData%%\Microsoft\Windows\Start Menu\Programs\Cipher Desk"
echo del /Q "%%UserProfile%%\Desktop\Cipher Desk.lnk" ^>nul 2^>^&1
echo del /Q "%%START_MENU_DIR%%\Cipher Desk.lnk" ^>nul 2^>^&1
echo rmdir "%%START_MENU_DIR%%" ^>nul 2^>^&1
echo del /Q "%%TARGET_DIR%%\*" ^>nul 2^>^&1
echo rmdir "%%TARGET_DIR%%" ^>nul 2^>^&1
) > "%TARGET_DIR%\Uninstall-CipherDesk.cmd"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ws = New-Object -ComObject WScript.Shell; " ^
  "$desktop = $ws.CreateShortcut('%DESKTOP_SHORTCUT%'); " ^
  "$desktop.TargetPath = '%TARGET_DIR%\CipherDeskLauncher.exe'; " ^
  "$desktop.WorkingDirectory = '%TARGET_DIR%'; " ^
  "$desktop.Description = 'Cipher Desk'; " ^
  "$desktop.Save(); " ^
  "$startMenu = $ws.CreateShortcut('%START_MENU_DIR%\Cipher Desk.lnk'); " ^
  "$startMenu.TargetPath = '%TARGET_DIR%\CipherDeskLauncher.exe'; " ^
  "$startMenu.WorkingDirectory = '%TARGET_DIR%'; " ^
  "$startMenu.Description = 'Cipher Desk'; " ^
  "$startMenu.Save();"

start "" "%TARGET_DIR%\CipherDeskLauncher.exe"
exit /b 0
