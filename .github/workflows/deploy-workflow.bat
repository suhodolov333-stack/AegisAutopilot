@echo off
setlocal

REM Переход в папку проекта
cd /d "C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\Aegis"

REM Убедимся, что нужный файл шаблона существует
if not exist "%~dp0aegis-min.yml" (
    echo ❌ Файл aegis-min.yml не найден рядом с .bat. Операция отменена.
    pause
    exit /b
)

REM Убедимся, что папка существует
if not exist ".github\workflows" (
    mkdir .github\workflows
)

REM Удаляем все YML/YAML кроме aegis-min.yml
for %%f in (.github\workflows\*.yml) do (
    if /I not "%%~nxf"=="aegis-min.yml" del "%%f"
)
for %%f in (.github\workflows\*.yaml) do (
    if /I not "%%~nxf"=="aegis-min.yml" del "%%f"
)

REM Копируем файл (перезапись, если надо)
copy /Y "%~dp0aegis-min.yml" ".github\workflows\aegis-min.yml" > nul

REM Git push
git add -A
git commit -m "ci: безопасное обновление workflow (не трогаем aegis-min.yml)"
git push origin main

echo.
echo ✅ Готово! Проверяй GitHub → вкладка Actions.
pause
