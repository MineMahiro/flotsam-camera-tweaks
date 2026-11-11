@echo off
chcp 65001 >nul
title Flotsam Camera Tweaks - Restore
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\restore.ps1"
if errorlevel 1 (
  echo.
  echo Failed. See the error message above.
)
echo.
pause
