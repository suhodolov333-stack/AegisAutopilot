set -euo pipefail

# ── 1) Находим репозиторий
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  REPO_DIR="$(git rev-parse --show-toplevel)"
else
  CANDIDATE=$(ls -d /c/Users/*/AppData/Roaming/MetaQuotes/Terminal/*/MQL5/Experts/Aegis 2>/dev/null | head -n 1 || true)
  if [ -z "${CANDIDATE:-}" ]; then
    echo "❌ Не нашёл репозиторий. Зайди в папку проекта Aegis и повтори запуск."
    exit 1
  fi
  REPO_DIR="$CANDIDATE"
fi
cd "$REPO_DIR"

# ── 2) Находим файл workflow
WF=""
for f in .github/workflows/*.yml .github/workflows/*.yaml; do
  [ -f "$f" ] && { WF="$f"; break; }
done
[ -z "$WF" ] && { echo "❌ Не нашёл .github/workflows/*.yml"; exit 1; }

# ── 3) Если блок уже есть — пропускаем, иначе вставляем после первого 'steps:'
if grep -q 'AEGIS_AUTO_PUSH_MARKER' "$WF"; then
  echo "ℹ️ Блок автопуша уже присутствует — пропускаю."
else
  TS=$(date +%Y%m%d_%H%M%S)
  cp "$WF" "${WF}.bak.$TS"

  # корректный фрагмент с отступами (6 пробелов перед - name)
  cat > __autopush_block.yml <<'YAML'
      - name: Push changes back to repo  # AEGIS_AUTO_PUSH_MARKER
        if: always()
        env:
          GH_TOKEN: ${{ secrets.GH_TOKEN }}
        run: |
          git config user.name "aegis-bot"
          git config user.email "aegis-bot@users.noreply.github.com"
          git remote set-url origin https://${GH_TOKEN}@github.com/suhodolov333-stack/AegisAutopilot.git
          git fetch --all
          git add -A
          if git diff --cached --quiet; then
            echo "No changes to push"
          else
            git commit -m "ci: auto-push from runner"
            git push origin HEAD:${GITHUB_REF#refs/heads/}
          fi
YAML

  awk -v frag="__autopush_block.yml" '
    { print }
    ins==0 && /^[[:space:]]*steps:[[:space:]]*$/ {
      while ((getline l < frag) > 0) print l
      close(frag); ins=1
    }' "$WF" > "$WF.new"

  mv "$WF.new" "$WF"
  rm -f __autopush_block.yml
  echo "✅ Вставил блок автопуша в $WF"
fi

# ── 4) Коммитим и пушим
git add "$WF"
git commit -m "ci: add safe auto-push step (marker)" || echo "ℹ️ Нечего коммитить"
git push origin main
echo "🎯 Готово. Проверь прогон в GitHub Actions."
