# app-mirakurun-epgstation

Mirakurun と EPGStation を独立リポジトリとして扱うための新しい正本候補です。upstream `docker-mirakurun-epgstation` をベースにしつつ、実データとホスト依存設定を repo 外へ出しやすい形にしています。

## 日本語メモ

GitHub のコミット一覧が英語で分かりにくい場合は、[コミット履歴の日本語メモ](docs/COMMIT_HISTORY_JA.md) を見てください。

## サンプル値の置き換え

`.env.example` は公開用の見本です。実際に使う値は `.env.local` に書きます。

- `HOST_DATA_DIR` は Mirakurun / EPGStation / DB 設定を置く場所へ変更します
- `RECORDED_DIR` は録画ファイルを置く大容量ディスクへ変更します
- `EPG_DB_PASSWORD` / `EPG_DB_ROOT_PASSWORD` は自分で決めた強い値へ変更します
- `LEGACY_MIRAKURUN_CONF_DIR` は旧環境の `server.yml` `channels.yml` `tuners.yml` を引き継ぐときだけ指定します
- 親 repo からまとめて使う場合は、`stack.service.env.local` の `GLOBAL__HOST_DATA_ROOT` / `GLOBAL__RECORDED_ROOT` / `APP_MIRAKURUN_EPGSTATION__...` を使います

## 方針

- ベースの `compose.yaml` は portable に保つ
- `/dev/dvb` や `/dev/dri` などのハードウェア依存は `compose.hardware.example.yaml` に分離する
- 実データは `HOST_DATA_DIR` と `RECORDED_DIR` に保存する

## 起動

```bash
cp .env.example .env.local
./scripts/prepare-host.sh
./scripts/init-data-dirs.sh
docker compose --env-file .env.local -f compose.yaml -f compose.hardware.example.yaml up -d
```

チューナーや GPU を使う環境では、必要に応じて hardware override を使います。

```bash
docker compose --env-file .env.local -f compose.yaml -f compose.hardware.example.yaml up -d
```

## ポート

- Mirakurun: `40772`
- Mirakurun debug: `9229`
- EPGStation: `8888`
- EPGStation preview: `8889`

## データ配置

- `data/mirakurun/conf`
- `data/mirakurun/data`
- `data/mariadb`
- `data/epgstation/config`
- `data/epgstation/data`
- `data/epgstation/logs`
- `data/epgstation/thumbnail`
- `recorded/`

## 初期化

```bash
./scripts/prepare-host.sh
./scripts/init-data-dirs.sh
```

初回実行時は config テンプレートを data 側へコピーします。`prepare-host.sh` は旧 `mirakurun.sh` に入っていたホスト前提の `apt` 導入と `pcscd` 停止を、今の構成向けに切り出したものです。

既存の Mirakurun 設定を引き継ぎたい場合は、`.env.local` に `LEGACY_MIRAKURUN_CONF_DIR=/path/to/mirakurun/conf` を入れてから実行します。`server.yml` `channels.yml` `tuners.yml` が自動で取り込まれます。

アンテナ接続後に Mirakurun へチャンネルスキャンを投げたい場合:

```bash
./scripts/scan-channels.sh
```

## 注意

- ホスト側の `pcscd` 停止やチューナードライバ導入は必要です
- hardware override を使わないベース compose では、ハードウェア依存の機能は有効になりません
- 旧構成の external network / 固定 IP はベース compose から外しています
- `channels.yml` と `tuners.yml` は地域とデバイスに依存します。repo の example は空のプレースホルダなので、本格運用では自分の環境に合わせて置き換えてください
