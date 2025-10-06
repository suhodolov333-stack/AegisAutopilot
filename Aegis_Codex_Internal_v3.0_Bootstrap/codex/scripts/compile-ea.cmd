@echo off
setlocal EnableExtensions EnableDelayedExpansion
set ENVFILE=config\build-config_Version3.env
if not exist "%ENVFILE%" (
  echo [ERROR] .env not found: "%ENVFILE%"
  exit /b 10
)
for /f "usebackq tokens=1,* delims==" %%A in ("%ENVFILE%") do (
  set "k=%%A"
  set "v=%%B"
  if not "!k!"=="" if not "!k:~0,1!"=="#" if not "!k:~0,1!"==";" (
    set "!k!=!v!"
  )
)
if not exist "codex\build" mkdir "codex\build"
cscript //nologo codex\engine\CodexLoop.js
exit /b %ERRORLEVEL%
