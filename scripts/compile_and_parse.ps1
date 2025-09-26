Param(
  [string]$MetaEditor = $env:AEGIS_METAEDITOR_PATH,
  [string]$EA = "experts\\Aegis_S_Base.mq5"
)
if (-not (Test-Path $MetaEditor)) { Write-Error "MetaEditor not found: $MetaEditor"; exit 1 }
Write-Host "[BUILD] Compiling $EA"
& "$MetaEditor" /compile:$EA /log:build.log
if (-not (Test-Path build.log)) { Write-Error "No build.log produced"; exit 1 }
if (-not (Test-Path scripts\\parse_build_log.py)) { Write-Error "Parser missing scripts/parse_build_log.py"; exit 1 }
python scripts/parse_build_log.py
Write-Host "---- Build Report (Markdown) ----"
Get-Content reports\\build_report_latest.md | Write-Host