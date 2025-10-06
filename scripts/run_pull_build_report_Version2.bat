@echo off
set SCRIPT_DIR=%~dp0
<<<<<<< Updated upstream
set CONFIG=%SCRIPT_DIR%..\config\build-config_Version2.json

powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%pull_build_report_Version2.ps1" -ConfigPath "%CONFIG%"
=======
set CONFIG=%SCRIPT_DIR%..\config\build-config.json

powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%pull_build_report.ps1" -ConfigPath "%CONFIG%"
>>>>>>> Stashed changes
