#!/usr/bin/env python3
"""新規導入用の認証情報を生成する。既存DBの認証情報は変更しない。"""
import os
from pathlib import Path
import re
import secrets
import shlex
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
KEYS = ['EPG_DB_PASSWORD', 'EPG_DB_ROOT_PASSWORD']
DATA_KEY = 'EPG_DB_DIR'
DATA_SUFFIX = 'mirakurun/mira_sql'
BAD = {"", "change-me", "change-me-root", "password", "epgstation", "wordpress", "wikijs", "wp-db-pw", "mysql-root-pw"}
p = ROOT / ".env.local"
text = p.read_text() if p.exists() else (ROOT / ".env.example").read_text()
values = {}
for line in text.splitlines():
    if line.strip() and not line.lstrip().startswith("#") and "=" in line:
        key, value = line.split("=", 1)
        words = shlex.split(value, comments=True)
        values[key.strip()] = words[0] if words else ""
missing = [key for key in KEYS if values.get(key, "") in BAD]
if "--check" in sys.argv:
    if missing:
        sys.exit("認証情報が未設定、または既知の初期値です。")
    print("認証情報の設定を確認しました。")
    sys.exit(0)
base = values.get("HOST_DATA_DIR", "./data")
data = values.get(DATA_KEY) or str(Path(base) / DATA_SUFFIX)
if "$" in data:
    sys.exit("保存先の変数を具体的なパスに解決してから実行してください。")
data = Path(data)
if not data.is_absolute():
    data = ROOT / data
if missing and data.exists() and any(data.iterdir()):
    sys.exit("既存データがあるため生成を中止しました。DB側と接続設定を整合させて変更してください。")
for key in missing:
    value = secrets.token_hex(32)
    if re.search(r"^" + re.escape(key) + "=", text, re.M):
        text = re.sub(r"^" + re.escape(key) + r"=.*$", lambda m: key + "=" + value, text, flags=re.M)
    else:
        text += "\n" + key + "=" + value + "\n"
os.umask(0o077)
with tempfile.NamedTemporaryFile(mode="w", dir=ROOT, delete=False) as f:
    f.write(text)
    tmp = Path(f.name)
tmp.replace(p)
p.chmod(0o600)
print("認証情報を .env.local に保存しました。値は表示しません。")
