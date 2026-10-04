@echo off
setlocal
title SchoolHub GOVERNANCE TEST

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Claude-App-Updater\Update-From-Claude-GOVERNANCE-TEST.ps1"
if errorlevel 1 (
  echo.
  echo Update stopped safely. Read the error above and the newest update log.
  pause
  exit /b 1
)

echo.
echo SchoolHub is updated and running.
pause
exit /b 0
