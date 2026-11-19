@echo off
rem Starts the NVIDIA repair tool in English (scripts\NettoyageNvidia.ps1) with administrator rights.
setlocal
set "SCRIPT=%~dp0scripts\NettoyageNvidia.ps1"

net session >nul 2>&1
if %errorlevel% neq 0 goto :elevate

start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%SCRIPT%" -Language en
exit /b 0

:elevate
echo Asking for administrator rights... Click "Yes" in the window that opens.
set "BAT_PATH=%~f0"
powershell.exe -NoProfile -Command "try { Start-Process -FilePath $env:BAT_PATH -Verb RunAs -ErrorAction Stop } catch { exit 1 }"
if %errorlevel% neq 0 (
    echo.
    echo You must click "Yes" for the repair to work.
    echo Run the file again and click "Yes".
    pause
)
exit /b
