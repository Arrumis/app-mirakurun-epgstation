# app-mirakurun-epgstation

Mirakurun と EPGStation を Docker で動かすためのリポジトリです。
チューナー機器の設定、番組表データ、録画ファイルを指定した保存先へ置けます。

## 使い方

通常の DVB 系チューナーを使う場合:

```bash
cp .env.example .env.local
./scripts/prepare-host.sh
./scripts/init-data-dirs.sh
docker compose --env-file .env.local -f compose.yaml -f compose.hardware.example.yaml up -d
```

PX-W3U4 を使う場合:

```bash
cp .env.example .env.local
./scripts/prepare-host.sh
./scripts/init-data-dirs.sh
docker compose --env-file .env.local -f compose.yaml -f compose.hardware.pxw3u4.example.yaml up -d --build
```

## 変更する値

`.env.example` は公開用の見本です。実際の値は `.env.local` に書きます。

- `HOST_DATA_DIR`: Mirakurun、EPGStation、データベース設定を置く場所です。
- `RECORDED_DIR`: 録画ファイルを置く場所です。大容量ディスクを指定します。
- `EPG_DB_PASSWORD` と `EPG_DB_ROOT_PASSWORD`: データベースのパスワードです。必ず変更します。
- `LEGACY_MIRAKURUN_CONF_DIR`: 旧環境の `server.yml`、`channels.yml`、`tuners.yml` を引き継ぐときだけ指定します。
- `APP_MIRAKURUN_EPGSTATION__...`: 親リポジトリからまとめて設定するときに使います。

## データ

標準の保存先:

- `mirakurun/conf`
- `mirakurun/data`
- `mirakurun/mira_sql`
- `epgstation/config`
- `epgstation/data`
- `epgstation/logs`
- `epgstation/thumbnail`
- `recorded`

既存環境から移す場合は、旧 `/var/docker` 相当のディレクトリを `HOST_DATA_DIR` に指定します。

## チャンネルスキャン

アンテナとチューナーの準備後に実行します。

```bash
./scripts/scan-channels.sh
```

## 補足

- ホスト側の `pcscd` 停止やチューナードライバ導入が必要です。
- PX-W3U4 は `/dev/dvb` ではなく `/dev/px4video0..3` を使います。
- PX-W3U4 の内蔵カードリーダーは使わない前提です。B-CAS または ACAS は外部 USB カードリーダーを使います。
- `channels.yml` と `tuners.yml` は地域と機器に依存します。実運用では自分の環境に合わせて置き換えます。

## 認証情報の安全な初期設定

新規導入では `python3 scripts/init-secrets.py` を実行すると、固有のパスワードを `.env.local` に生成します。値は表示せず、ファイル権限を所有者の読み書きに限定します。`python3 scripts/init-secrets.py --check` で空欄・既知の初期値を検査できます。Compose は `docker compose --env-file .env.local up -d` で起動してください。

既存DBがある場合、初期値の自動変更は拒否します。バックアップ後、DB内の認証情報とアプリの接続設定を整合させて変更してください。環境変数の変更だけでは既存DBのパスワードは変わりません。認証情報をGitやログへ保存しないでください。

## 安全な運用への変更

既定のDBイメージをMariaDB 11.4系に変更しました。既存の10.5系環境は、バックアップから別の保存先へ復元し、アプリの互換性を確認してから切り替えてください。旧DBの保存先へ予告なく新イメージを接続しないでください。管理ポートは他のPCからアクセスできる公開に戻しました。デバッグポートの公開廃止は維持しています。

既存の `.env.local` に `EPG_DB_IMAGE` がなければ起動を拒否します。移行前の既存環境では `mariadb:10.5` を明示して維持し、復元テスト後に `mariadb:11.4` と検証済みの新しい保存先を指定してください。
