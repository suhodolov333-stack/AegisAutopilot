@echo off
setlocal enabledelayedexpansion
REM Локальная компиляция + commit статуса
set META="C:\Path\To\MetaTrader 5\metaeditor64.exe"
set EA=experts\Aegis_S_Base.mq5
set OUT=build.log

echo [BUILD] compile %EA%
%META% /compile:%EA% /log:%OUT%

if not exist %OUT% (
  echo [BUILD][FAIL] no build.log
  goto END
)

findstr /C:" 0 error" %OUT% >nul & if %errorlevel%==0 (set STATUS=SUCCESS) else (set STATUS=FAIL)
for /f "tokens=1" %%A in ('find /c "warning" ^< %OUT%') do set WARN=%%A

git add %OUT%
git commit -m "[BUILD] %STATUS% warnings=%WARN%" 2>nul
git push 2>nul

echo [BUILD] %STATUS% warnings=%WARN%

:END
endlocal