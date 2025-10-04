@echo off
setlocal

REM Переход в папку проекта
cd /d "C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\Aegis"

REM Проверяем, существует ли файл шаблона
if not exist "%~dp0aegis-min.yml" (
    echo ❌ Файл aegis-min.yml не найден рядом с батником. Отмена операций.
    pause
    exit /b
)

REM Удаляем старые workflow-файлы
if exist ".github\workflows" (
    del /q .github\workflows\*.yml
    del /q .github\workflows\*.yaml
) else (
    mkdir .github\workflows
)

REM Копируем новый workflow
copy "%~dp0aegis-min.yml" ".github\workflows\aegis-min.yml" > nul

REM Добавляем в git, коммитим и пушим
git add -A
git commit -m "ci: обновлён workflow (исправленный .bat)"
git push origin main

echo.
echo ✅ Готово! Workflow отправлен. Проверь вкладку Actions на GitHub.
pause
