#!/usr/bin/env bash
set -euo pipefail

if [[ -f ".env.local" ]]; then
  set -a
  # shellcheck disable=SC1091
  source ".env.local"
  set +a
fi

DATA_DIR="${1:-${HOST_DATA_DIR:-./data}}"
CONFIG_DIR="${MIRAKURUN_CONFIG_DIR:-${DATA_DIR}/mirakurun/conf}"
TUNERS_FILE="${CONFIG_DIR}/tuners.yml"
PXW3U4_SAMPLE="./mirakurun/conf/tuners.pxw3u4.yml.example"

mkdir -p "${CONFIG_DIR}"

if [[ ! -f "${PXW3U4_SAMPLE}" ]]; then
  echo "PX-W3U4 用 tuners.yml 見本がありません: ${PXW3U4_SAMPLE}"
  exit 1
fi

if [[ -f "${TUNERS_FILE}" ]] && ! grep -q '^\[\]$' "${TUNERS_FILE}" && [[ "${FORCE:-0}" != "1" ]]; then
  cat <<EOF
既存の tuners.yml があるため上書きしません。
  ${TUNERS_FILE}

PX-W3U4 用の見本で上書きする場合:
  FORCE=1 ./scripts/apply-pxw3u4-config.sh
EOF
  exit 0
fi

cp "${PXW3U4_SAMPLE}" "${TUNERS_FILE}"

cat <<EOF
PX-W3U4 用 tuners.yml を配置しました。
  ${TUNERS_FILE}

次に必要な確認:
  - ホスト側に /dev/px4video0 から /dev/px4video3 があること
  - 外部B-CASカードリーダーが pcsc_scan で見えること
  - Mirakurun コンテナを再ビルドして recpt1 が入っていること
EOF
