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
