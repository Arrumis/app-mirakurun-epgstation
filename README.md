# app-mirakurun-epgstation

Mirakurun と EPGStation を独立リポジトリとして扱うための新しい正本候補です。upstream `docker-mirakurun-epgstation` をベースにしつつ、実データとホスト依存設定を repo 外へ出しやすい形にしています。

## 方針

- ベースの `compose.yaml` は portable に保つ
- `/dev/dvb` や `/dev/dri` などのハードウェア依存は `compose.hardware.example.yaml` に分離する
- 実データは `HOST_DATA_DIR` と `RECORDED_DIR` に保存する

## 起動

```bash
cp .env.example .env.local
./scripts/init-data-dirs.sh
docker compose --env-file .env.local up -d
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
./scripts/init-data-dirs.sh
```

初回実行時は config テンプレートを data 側へコピーします。

## 注意

- ホスト側の `pcscd` 停止やチューナードライバ導入は必要です
- hardware override を使わないベース compose では、ハードウェア依存の機能は有効になりません
- 旧構成の external network / 固定 IP はベース compose から外しています

