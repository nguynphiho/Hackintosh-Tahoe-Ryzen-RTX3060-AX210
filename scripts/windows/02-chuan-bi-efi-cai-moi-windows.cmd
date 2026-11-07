@echo off
chcp 65001 >nul
setlocal

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..\..") do set "REPO_DIR=%%~fI"

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%prepare-efi-stage1.ps1" -RepoDir "%REPO_DIR%"
set "RC=%errorlevel%"

echo.
pause
exit /b %RC%
