@echo off
setlocal EnableExtensions EnableDelayedExpansion
set ENVFILE=config\build-config_Version2.env
if not "%~1"=="" set ENVFILE=%~1
if not exist "%ENVFILE%" ( echo [ERROR] .env not found: "%ENVFILE%" & exit /b 10 )

for /f "usebackq tokens=1,* delims==" %%A in ("%ENVFILE%") do (
  set "k=%%A"
  set "v=%%B"
  if not "!k!"=="" if not "!k:~0,1!"=="#" if not "!k:~0,1!"==";" (
    set "!k!=!v!"
  )
)

if not exist "codex\build"   mkdir "codex\build"
if not exist "codex\history" mkdir "codex\history"
if not exist "codex\state"   mkdir "codex\state"
if not exist "codex\history\versions" mkdir "codex\history\versions"
if not exist "codex\inbox"   mkdir "codex\inbox"
if not exist "config\backup" mkdir "config\backup"

cscript //nologo codex\engine\CodexLoop.js
exit /b %ERRORLEVEL%
