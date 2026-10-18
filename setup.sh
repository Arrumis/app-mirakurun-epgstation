#!/usr/bin/env bash
set -euo pipefail
umask 077
cd "$(dirname "${BASH_SOURCE[0]}")"
python3 scripts/init-secrets.py
bash scripts/init-data-dirs.sh
echo "初期設定が完了しました。内容を確認後、docker compose --env-file .env.local up -d --build で起動してください。"
