@echo off
setlocal EnableExtensions EnableDelayedExpansion
title [Aegis Codex] Smart Runner v2.1
color 0A

echo.
echo [Aegis] Starting environment discovery...
echo.

rem === Locate codex root automatically ===
set "CURR=%~dp0"
set "BASE_DIR=%CURR%"
:find_root
if exist "%BASE_DIR%config\build-config_Version2.env" goto root_found
cd ..
set "BASE_DIR=%cd%\"
if "%BASE_DIR%"=="C:\" (
    echo [ERROR] Codex root not found.
    pause
    exit /b 10
)
goto find_root

:root_found
cd /d "%BASE_DIR%"
echo [Aegis] Codex root found: "%BASE_DIR%"
set "ENVFILE=%BASE_DIR%config\build-config_Version2.env"
echo [Aegis] Using .env: "%ENVFILE%"
echo.

rem === Load environment variables safely ===
for /f "usebackq tokens=1,* delims==" %%A in ("%ENVFILE%") do (
  set "k=%%A"
  set "v=%%B"
  if not "!k!"=="" if not "!k:~0,1!"=="#" if not "!k:~0,1!"==";" (
    set "!k!=!v!"
  )
)

rem === Ensure directories ===
for %%X in ("%OUT_DIR%" "%BUILD_DIR%" "%LOG%" "%ERR_LOG%" "%STAGE_FILE%") do (
  set "fpath=%%~dpX"
  if not exist "!fpath!" mkdir "!fpath!" >nul 2>&1
)

echo [Aegis] Environment ready.
echo.

if not exist "%METAEDITOR%" (
  echo [ERROR] MetaEditor not found: "%METAEDITOR%"
  pause
  exit /b 20
)

if not exist "%EA_TERM%" (
  echo [WARNING] EA_TERM missing — fallback to EA_REPO
  set "EA_TERM=%EA_REPO%"
)

echo [Aegis] Running compiler...
cscript //nologo "%BASE_DIR%engine\CodexLoop.js" 1>"%LOG%" 2>&1

echo [Aegis] Compilation finished. Log saved to "%LOG%"
echo.

rem === Safe backup ===
if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"
echo [Aegis] Backing up .ex5 files to "%OUT_DIR%"...

for /r "%MQL5_DIR%\Experts\Aegis\SuhabFiboTrade" %%F in (*.ex5) do (
  copy "%%F" "%OUT_DIR%" >nul 2>&1
)

echo [Aegis] Backup complete.
echo.

echo [Aegis] Showing last 10 log lines...
for /f "usebackq delims=" %%L in ('powershell -NoLogo -Command "Get-Content -Tail 10 \"%LOG%\""') do (
  echo %%L
)

echo.
echo [Aegis] Finished successfully.
pause
exit /b 0
