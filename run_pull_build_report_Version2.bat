@echo off
set SCRIPT_DIR=%~dp0
set CONFIG=%SCRIPT_DIR%..\config\build-config.json

powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%pull_build_report.ps1" -ConfigPath "%CONFIG%"