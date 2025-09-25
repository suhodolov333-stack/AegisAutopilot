@echo off
set SCRIPT_DIR=%~dp0
set CONFIG=%SCRIPT_DIR%..\config\build-config_Version2.json

powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%pull_build_report_Version2.ps1" -ConfigPath "%CONFIG%"