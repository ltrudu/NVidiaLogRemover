@echo off
rem Lance l'outil de reparation NVIDIA en francais (scripts\NettoyageNvidia.ps1) avec les droits administrateur.
setlocal
set "SCRIPT=%~dp0scripts\NettoyageNvidia.ps1"

net session >nul 2>&1
if %errorlevel% neq 0 goto :elevate

start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%SCRIPT%" -Language fr
exit /b 0

:elevate
echo Demande des droits administrateur... Clique sur "Oui" dans la fenetre qui s'ouvre.
set "BAT_PATH=%~f0"
powershell.exe -NoProfile -Command "try { Start-Process -FilePath $env:BAT_PATH -Verb RunAs -ErrorAction Stop } catch { exit 1 }"
if %errorlevel% neq 0 (
    echo.
    echo Il faut cliquer sur "Oui" pour que la reparation fonctionne.
    echo Relance le fichier et clique sur "Oui".
    pause
)
exit /b
