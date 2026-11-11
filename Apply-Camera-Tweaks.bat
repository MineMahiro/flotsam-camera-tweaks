@echo off
chcp 65001 >nul
title Flotsam Camera Tweaks
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\apply.ps1"
if errorlevel 1 (
  echo.
  echo Failed. See the error message above.
)
echo.
pause
