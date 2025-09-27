@echo off
setlocal EnableExtensions

title Aegis Runner Cleaner

rem Require admin
>nul 2>&1 net session
if %errorlevel% NEQ 0 (
  echo ERROR: Run as Administrator (right click -> Run as administrator).
  pause
  exit /b 1
)

set "RDIR=%~1"
if "%RDIR%"=="" set "RDIR=C:\aegis-runner"

echo Cleaning runner folder: %RDIR%

rem Stop and uninstall service if present
if exist "%RDIR%\svc.cmd" (
  call "%RDIR%\svc.cmd" stop  >nul 2>&1
  call "%RDIR%\svc.cmd" uninstall >nul 2>&1
)

rem Kill possible running processes
taskkill /IM Runner.Listener.exe /F >nul 2>&1
taskkill /IM Runner.Worker.exe   /F >nul 2>&1

rem Try to remove any services named actions.runner*
for /f "tokens=1" %%S in ('sc query type^= service state^= all ^| find /I "actions.runner"') do (
  sc stop %%S >nul 2>&1
  sc delete %%S >nul 2>&1
)

rem Take ownership and full control, then remove folder
if exist "%RDIR%" (
  takeown /F "%RDIR%" /R /D Y >nul 2>&1
  icacls "%RDIR%" /grant "%USERNAME%":F /T /C >nul 2>&1
  rd /s /q "%RDIR%" 2>nul
)

if exist "%RDIR%" (
  echo WARN: Folder still exists. Reboot and run this cleaner again.
) else (
  echo OK: Runner folder removed.
)

echo Done. You can now run setup-aegis-runner.bat
pause
endlocal