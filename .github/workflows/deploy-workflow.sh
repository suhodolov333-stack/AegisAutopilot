#!/bin/bash

cd /mnt/c/Users/Administrator/AppData/Roaming/MetaQuotes/Terminal/D0E8209F77C8CF37AD8BF550E51FF075/MQL5/Experts/Aegis || { echo "⛔ Путь не найден"; exit 1; }

mkdir -p .github/workflows
rm -f .github/workflows/*.yml .github/workflows/*.yaml

cp aegis-min.yml .github/workflows/aegis-min.yml

git add -A
git commit -m "ci: добавлен минимальный workflow"
git push origin main

echo "✅ Готово: workflow установлен и запушен. Проверь вкладку Actions на GitHub."
