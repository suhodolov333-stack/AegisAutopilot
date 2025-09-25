Param(
  [string]$ConfigPath = ""
)

function Write-Info($msg){ Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Warn($msg){ Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err ($msg){ Write-Host "[ERR ] $msg" -ForegroundColor Red }

# 1) Загрузка конфигурации
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
  $ConfigPath = Join-Path $PSScriptRoot "..\config\build-config_Version2.json"
}
if (!(Test-Path $ConfigPath)) {
  Write-Err "Не найден config/build-config_Version2.json. Передай правильный путь параметром или создай файл."
  exit 1
}
$configJson = Get-Content $ConfigPath -Raw | ConvertFrom-Json

$RepoPath        = $configJson.RepoPath
$MetaEditorPath  = $configJson.MetaEditorPath
$EAPath          = $configJson.EAPath
$BackupDir       = $configJson.BackupDir
$CreateIssue     = [bool]$configJson.CreateIssueOnError
$RepoSlug        = $configJson.GitHubRepoSlug
$Branch          = $configJson.Branch

if (-not (Test-Path $RepoPath)) { Write-Err "RepoPath не найден: $RepoPath"; exit 1 }
if (-not (Test-Path $MetaEditorPath)) { Write-Err "MetaEditorPath не найден: $MetaEditorPath"; exit 1 }
if (-not (Test-Path $EAPath)) { Write-Err "EAPath не найден: $EAPath"; exit 1 }

# 2) Git pull
Write-Info "Git fetch/pull..."
git -C "$RepoPath" fetch --quiet
if ($LASTEXITCODE -ne 0) { Write-Err "git fetch завершился с ошибкой"; }
git -C "$RepoPath" pull --ff-only --quiet
if ($LASTEXITCODE -ne 0) { Write-Err "git pull завершился с ошибкой"; }

# 3) Бэкап прошлой сборки (.ex5)
if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null }
$EAOut = [System.IO.Path]::ChangeExtension($EAPath, ".ex5")
if (Test-Path $EAOut) {
  $ts = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
  $backupName = Join-Path $BackupDir ("Aegis_" + $ts + ".ex5")
  Copy-Item -Path $EAOut -Destination $backupName -Force
  Write-Info "Бэкап сделан: $backupName"
}

# 4) Компиляция
$logPath = Join-Path $RepoPath "build.log"
Write-Info "Компиляция через MetaEditor..."
& "$MetaEditorPath" "/compile:$EAPath" "/log:$logPath" | Out-Null
Start-Sleep -Milliseconds 500

if (!(Test-Path $logPath)) {
  Write-Err "build.log не создан. Проверь путь к MetaEditor и EA."
  exit 1
}

# 5) Парсинг лога и формирование отчёта
$log   = Get-Content $logPath
$end   = $log | Select-Object -Last 1
$errs  = 0
$warns = 0
if ($end -match '(\d+)\s+error\(s\).*?(\d+)\s+warning\(s\)') {
  $errs  = [int]$Matches[1]
  $warns = [int]$Matches[2]
} else {
  $errs  = ($log | Select-String -Pattern '(?i)\berror\b').Count
  $warns = ($log | Select-String -Pattern '(?i)\bwarning\b').Count
}

$topErrors = $log | Where-Object { $_ -match '(?i)error|cannot|undeclared|expected' } | Select-Object -First 60

$branchName = ""
try { $branchName = (git -C "$RepoPath" rev-parse --abbrev-ref HEAD).Trim() } catch { $branchName = "unknown" }

# 6) Сохранение отчёта
$reportsDir = Join-Path $RepoPath "reports"
if (-not (Test-Path $reportsDir)) { New-Item -ItemType Directory -Force -Path $reportsDir | Out-Null }

$tsFile = Get-Date -Format "yyyyMMdd_HHmmss"
$reportPath = Join-Path $reportsDir ("build_" + $tsFile + ".md")
$lastPath   = Join-Path $reportsDir "last_build.md"

$eaName = Split-Path $EAPath -Leaf
$repoUrl = "https://github.com/$RepoSlug"
$summary = @"
# Отчёт сборки Aegis

- Время: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
- Репозиторий: $RepoSlug
- Ветка: $branchName
- Советник: $eaName
- Результат: $errs ошибок, $warns предупреждений

## Топ ошибок (фрагменты)