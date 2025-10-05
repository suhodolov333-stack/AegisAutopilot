#!/bin/bash
set -e

MSG=$1
if [ -z "$MSG" ]; then
  MSG="update from Codex"
fi

git config --global user.name "suhodolov333-stack"
git config --global user.email "suhodolov333@gmail.com"

git remote remove origin 2>/dev/null || true
git remote add origin https://$GH_TOKEN@github.com/suhodolov333-stack/AegisAutopilot.git

git add .

if git commit -m "$MSG"; then
  echo "$(date) ✅ Commit successful: $MSG" >> codex_push.log
else
  echo "$(date) ⚠️ Nothing to commit: $MSG" >> codex_push.log
fi

if git push -u origin main; then
  echo "$(date) 🚀 Push successful" >> codex_push.log
else
  echo "$(date) ❌ Push failed" >> codex_push.log
fi
