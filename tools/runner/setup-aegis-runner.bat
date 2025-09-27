@echo off
setlocal EnableExtensions

title Aegis GitHub Actions Runner - Setup (asks token at the end)

rem Require admin
>nul 2>&1 net session
if %errorlevel% NEQ 0 (
  echo ERROR: Run as Administrator (right click -> Run as administrator).
  pause
  exit /b 1
)

set "RDIR=C:\aegis-runner"
set "REPO_URL=https://github.com/suhodolov333-stack/AegisAutopilot"
set "RUNNER_NAME=aegis-vps"
set "LABELS=self-hosted,Windows,X64,aegis"
set "VER1=2.328.0"
set "VER2=2.319.1"
set "URL1=https://github.com/actions/runner/releases/download/v%VER1%/actions-runner-win-x64-%VER1%.zip"
set "URL2=https://github.com/actions/runner/releases/download/v%VER2%/actions-runner-win-x64-%VER2%.zip"

echo Target folder: %RDIR%
echo Repo: %REPO_URL%

echo [1/5] Cleanup old install (if any)...
if exist "%RDIR%\svc.cmd" (
  call "%RDIR%\svc.cmd" stop  >nul 2>&1
  call "%RDIR%\svc.cmd" uninstall >nul 2>&1
)

taskkill /IM Runner.Listener.exe /F >nul 2>&1
taskkill /IM Runner.Worker.exe   /F >nul 2>&1

if exist "%RDIR%" rd /s /q "%RDIR%"
mkdir "%RDIR%" || ( echo ERROR: cannot create %RDIR% & pause & exit /b 1 )
cd /d "%RDIR%"

echo [2/5] Download runner (curl first, then PowerShell fallback)...
where curl >nul 2>&1
if %errorlevel% EQU 0 (
  curl -L -f -o runner.zip "%URL1%" || curl -L -f -o runner.zip "%URL2%"
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;try{(New-Object Net.WebClient).DownloadFile('%URL1%','runner.zip')}catch{(New-Object Net.WebClient).DownloadFile('%URL2%','runner.zip')}"
)

if not exist "runner.zip" (
  echo ERROR: download failed.
  pause
  exit /b 1
)

echo [3/5] Extract runner...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath 'runner.zip' -DestinationPath '.' -Force" || (
  echo ERROR: extract failed.
  pause
  exit /b 1
)

del /q runner.zip >nul 2>&1

if not exist ".\config.cmd" (
  echo ERROR: config.cmd not found after extract.
  pause
  exit /b 1
)

echo [4/5] Enter TOKEN (paste only the token string, not the whole command):
set "TOKEN="
set /p "TOKEN=TOKEN= "
if "%TOKEN%"=="" (
  echo ERROR: empty token.
  pause
  exit /b 1
)

echo [5/5] Register, install service, start...
call ".\config.cmd" --url "%REPO_URL%" --token %TOKEN% --name "%RUNNER_NAME%" --labels "%LABELS%" --unattended --replace
if errorlevel 1 (
  echo ERROR: registration failed (token may be expired or wrong repo). Re-run this script with a fresh token.
  pause
  exit /b 1
)

call ".\svc.cmd" install
call ".\svc.cmd" start
call ".\svc.cmd" status

echo Done.
echo Check: Repo -> Settings -> Actions -> Runners (Online: %RUNNER_NAME%)
echo Test build: Actions -> "Aegis build (self-hosted)" -> Run workflow
pause
endlocal