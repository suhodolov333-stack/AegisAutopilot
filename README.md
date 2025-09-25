# AegisAutopilot - Автоматизация MQL5

Система автоматической сборки и компиляции MQL5 Expert Advisors с интеграцией GitHub.

## 🚀 Быстрый старт

### Что уже готово:
- ✅ Структура папок настроена (`scripts/`, `config/`)
- ✅ Скрипты автоматизации готовы
- ✅ Конфигурация подготовлена
- ✅ Документация создана

### Что нужно сделать:

#### 1. Настроить пути в конфигурации
Отредактируйте файл `config/build-config.json`:
```json
{
  "RepoPath": "ПУТЬ_К_ПАПКЕ_В_MT5_DATA_FOLDER",
  "MetaEditorPath": "C:\\Program Files\\MetaTrader 5\\metaeditor64.exe",
  "EAPath": "ПОЛНЫЙ_ПУТЬ_К_ФАЙЛУ_MQ5",
  "BackupDir": "ПУТЬ_ДЛЯ_РЕЗЕРВНЫХ_КОПИЙ"
}
```

#### 2. Настроить планировщик Windows (3 способа):

**🎯 Способ 1 - Автоматический (рекомендуется):**
```powershell
# Запустите PowerShell от имени администратора
.\setup-scheduler.ps1
```

**📋 Способ 2 - Подробное руководство:**
Читайте `SCHEDULER_SETUP_GUIDE.md` - полная пошаговая инструкция

**⚡ Способ 3 - Быстрый:**
```cmd
# Замените ПОЛНЫЙ_ПУТЬ на путь к репозиторию
schtasks /create /tn "AegisAutopilot" /tr "cmd /c \"ПОЛНЫЙ_ПУТЬ\scripts\run_pull_build_report.bat\"" /sc minute /mo 10 /ru SYSTEM /rl HIGHEST /f
```

#### 3. Протестировать
```cmd
# Ручной запуск для проверки
scripts\run_pull_build_report.bat
```

## 📁 Структура проекта

```
AegisAutopilot/
├── scripts/
│   ├── run_pull_build_report.bat      # Основной скрипт запуска
│   └── pull_build_report.ps1          # PowerShell логика
├── config/
│   └── build-config.json              # Конфигурация путей
├── Experts/                           # MQL5 файлы
├── setup-scheduler.ps1                # Автонастройка планировщика
├── SCHEDULER_SETUP_GUIDE.md           # Подробное руководство
├── BUILD_AUTOMATION_Version2.md       # Техническая документация
└── AutoBuildAegis_Version2.xml        # XML шаблон для планировщика
```

## 🔧 Что делает система

1. **Каждые 10 минут:**
   - Выполняет `git pull` для обновления кода
   - Создает backup старых `.ex5` файлов
   - Компилирует MQL5 код через MetaEditor
   - Создает отчеты в папке `reports/`
   - При ошибках создает Issues в GitHub

2. **Файлы результатов:**
   - `build.log` - лог компиляции
   - `reports/last_build.md` - последний отчет
   - `reports/build_YYYYMMDD_HHMMSS.md` - архивные отчеты
   - `backup/` - резервные копии

## 🆘 Помощь и устранение проблем

### Частые проблемы:

**❌ "Система не может найти указанный файл"**
- Проверьте все пути в `config/build-config.json`
- Убедитесь, что MetaTrader 5 установлен

**❌ "Access denied"**
- Запускайте скрипты от имени администратора
- Проверьте права на папки MT5

**❌ Git ошибки**
- Настройте Git для работы с GitHub
- Проверьте SSH ключи или HTTPS аутентификацию

### Где получить помощь:
- `SCHEDULER_SETUP_GUIDE.md` - подробное руководство
- Issues в GitHub репозитории
- Логи в файлах `build.log` и `reports/`

## 🔑 GitHub Token (опционально)

Для автоматического создания Issues:
1. GitHub → Settings → Developer settings → Personal access tokens
2. Создайте token с правами `repo`
3. Установите переменную среды:
   ```cmd
   setx GITHUB_TOKEN "your_token_here" /M
   ```

## ✅ Проверка работы

После настройки проверьте:
- [ ] Задача создана в планировщике Windows
- [ ] Ручной запуск `scripts\run_pull_build_report.bat` работает
- [ ] Создаются файлы в папке `reports/`
- [ ] Backup файлы сохраняются
- [ ] Компиляция проходит без ошибок

---

**🎯 Система готова к работе! Теперь ваши MQL5 Expert Advisors будут компилироваться автоматически каждые 10 минут.**