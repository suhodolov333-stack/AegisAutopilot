@echo off
setlocal

REM Переход в папку проекта
cd /d "C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\Aegis"

REM Удаляем старые workflow-файлы
if exist ".github\workflows" (
    del /q .github\workflows\*.yml
    del /q .github\workflows\*.yaml
) else (
    mkdir .github\workflows
)

REM Копируем новый workflow из текущей папки (где лежит батник)
copy "%~dp0aegis-min.yml" ".github\workflows\aegis-min.yml" > nul

REM Добавляем в git, коммитим и пушим
git add -A
git commit -m "ci: добавлен минимальный workflow через .bat"
git push origin main

echo.
echo ✅ Готово! Workflow установлен и отправлен в GitHub.
echo Проверь вкладку Actions в репозитории.
pause
