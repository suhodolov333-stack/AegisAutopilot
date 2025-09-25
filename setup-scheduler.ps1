# Автоматическая настройка планировщика Windows для AegisAutopilot
# Запускать от имени администратора

param(
    [string]$RepoPath = "",
    [switch]$Help
)

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err($msg) { Write-Host "[ERR ] $msg" -ForegroundColor Red }
function Write-Success($msg) { Write-Host "[OK] $msg" -ForegroundColor Green }

if ($Help) {
    Write-Host @"
Автоматическая настройка планировщика Windows для AegisAutopilot

Использование:
  .\setup-scheduler.ps1 -RepoPath "C:\путь\к\репозиторию"

Параметры:
  -RepoPath    Полный путь к папке репозитория AegisAutopilot
  -Help        Показать эту справку

Примеры:
  .\setup-scheduler.ps1 -RepoPath "C:\Users\Admin\Documents\AegisAutopilot"
  
Требования:
  - Запуск от имени администратора
  - Установленный Git
  - Установленный MetaTrader 5
"@
    exit 0
}

# Проверка прав администратора
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Err "Этот скрипт должен быть запущен от имени администратора!"
    Write-Info "Щелкните правой кнопкой по PowerShell и выберите 'Запуск от имени администратора'"
    exit 1
}

# Определение пути к репозиторию
if ([string]::IsNullOrWhiteSpace($RepoPath)) {
    $RepoPath = Split-Path -Parent $PSScriptRoot
    Write-Info "Автоопределение пути к репозиторию: $RepoPath"
}

# Проверки
$scriptPath = Join-Path $RepoPath "scripts\run_pull_build_report.bat"
$configPath = Join-Path $RepoPath "config\build-config.json"

if (!(Test-Path $RepoPath)) {
    Write-Err "Путь к репозиторию не найден: $RepoPath"
    exit 1
}

if (!(Test-Path $scriptPath)) {
    Write-Err "Скрипт не найден: $scriptPath"
    Write-Info "Убедитесь, что файлы находятся в правильных папках (scripts/ и config/)"
    exit 1
}

if (!(Test-Path $configPath)) {
    Write-Err "Конфигурация не найдена: $configPath"
    exit 1
}

Write-Info "Проверка конфигурации..."
$config = Get-Content $configPath -Raw | ConvertFrom-Json

# Проверка путей в конфигурации
if (!(Test-Path $config.MetaEditorPath)) {
    Write-Warn "MetaEditor не найден: $($config.MetaEditorPath)"
    Write-Info "Проверьте путь в config/build-config.json"
}

if (!(Test-Path $config.RepoPath)) {
    Write-Warn "Путь репозитория в MT5 не найден: $($config.RepoPath)"
    Write-Info "Убедитесь, что репозиторий склонирован в Data Folder MT5"
}

# Создание XML для задачи
$xmlContent = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Author>AegisAutopilot</Author>
    <Description>Автоматическая сборка и компиляция MQL5 Aegis</Description>
  </RegistrationInfo>
  <Triggers>
    <CalendarTrigger>
      <Repetition>
        <Interval>PT10M</Interval>
        <StopAtDurationEnd>false</StopAtDurationEnd>
      </Repetition>
      <StartBoundary>$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')</StartBoundary>
      <Enabled>true</Enabled>
    </CalendarTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <RunLevel>HighestAvailable</RunLevel>
      <UserId>S-1-5-18</UserId>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT10M</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>cmd</Command>
      <Arguments>/c "$scriptPath"</Arguments>
      <WorkingDirectory>$(Split-Path $scriptPath)</WorkingDirectory>
    </Exec>
  </Actions>
</Task>
"@

$tempXmlPath = Join-Path $env:TEMP "AegisAutopilot.xml"
$xmlContent | Out-File -FilePath $tempXmlPath -Encoding Unicode

try {
    Write-Info "Удаление существующей задачи (если есть)..."
    schtasks /delete /tn "AegisAutopilot" /f 2>$null | Out-Null

    Write-Info "Создание новой задачи планировщика..."
    $result = schtasks /create /tn "AegisAutopilot" /xml $tempXmlPath

    if ($LASTEXITCODE -eq 0) {
        Write-Success "Задача 'AegisAutopilot' успешно создана!"
        Write-Info "Задача будет выполняться каждые 10 минут"
        
        Write-Info "Тестирование задачи..."
        schtasks /run /tn "AegisAutopilot"
        
        Write-Success "Настройка завершена!"
        Write-Info "Проверить статус задачи можно командой:"
        Write-Host "  schtasks /query /tn AegisAutopilot" -ForegroundColor Gray
        Write-Info "Или через интерфейс: Win+R → taskschd.msc"
        
    } else {
        Write-Err "Ошибка создания задачи планировщика"
        Write-Info "Попробуйте создать задачу вручную через GUI (taskschd.msc)"
    }
    
} catch {
    Write-Err "Ошибка: $($_.Exception.Message)"
} finally {
    if (Test-Path $tempXmlPath) {
        Remove-Item $tempXmlPath -Force
    }
}