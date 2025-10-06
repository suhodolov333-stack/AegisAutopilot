# Конвейер разбора сборки (auto-analysis v1)

## Поток
1. Локально или планировщиком запускается build_and_commit.bat — компиляция эксперта и сохранение build.log.
2. Commit с сообщением "[BUILD] SUCCESS/FAIL warnings=X" пушится.
3. Workflow `Build Log Parse` срабатывает на изменение build.log.
4. `scripts/parse_build_log.py` формирует:
   - reports/build_report_latest.md
   - reports/build_report_latest.json
5. Артефакты доступны во вкладке Actions (Artifacts).

## Зачем
Подготовка к автоматическим:
- Issue при ошибках
- Каталогу типовых правок
- Авто-fix PR (следующие этапы)

## Документы
Связано с:
- Финальное ТЗ v4.0 (прозрачная сборка и анализ)
- "Что делает Эгида сейчас" (поддержка текущей логики)
- Реализация v4.0 (этап автоаналитики)

## Дальше (v2+)
- Self-hosted Windows runner для прямой компиляции в CI
- Авто-Issue и лейблы при error_count>0
- Авто-предложения правок