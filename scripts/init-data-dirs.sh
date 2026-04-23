#!/usr/bin/env bash
set -euo pipefail

DATA_DIR="${1:-${HOST_DATA_DIR:-./data}}"
REC_DIR="${2:-${RECORDED_DIR:-./recorded}}"

mkdir -p \
  "${DATA_DIR}/mirakurun/conf" \
  "${DATA_DIR}/mirakurun/data" \
  "${DATA_DIR}/mariadb" \
  "${DATA_DIR}/epgstation/config" \
  "${DATA_DIR}/epgstation/data" \
  "${DATA_DIR}/epgstation/logs" \
  "${DATA_DIR}/epgstation/thumbnail" \
  "${REC_DIR}"

copy_if_missing() {
  local src="$1"
  local dst="$2"
  if [[ ! -f "${dst}" && -f "${src}" ]]; then
    cp "${src}" "${dst}"
  fi
}

copy_if_missing "./epgstation/config/enc.js.template" "${DATA_DIR}/epgstation/config/enc.js"
copy_if_missing "./epgstation/config/config.yml.template" "${DATA_DIR}/epgstation/config/config.yml"
copy_if_missing "./epgstation/config/operatorLogConfig.sample.yml" "${DATA_DIR}/epgstation/config/operatorLogConfig.yml"
copy_if_missing "./epgstation/config/epgUpdaterLogConfig.sample.yml" "${DATA_DIR}/epgstation/config/epgUpdaterLogConfig.yml"
copy_if_missing "./epgstation/config/serviceLogConfig.sample.yml" "${DATA_DIR}/epgstation/config/serviceLogConfig.yml"

echo "Initialized Mirakurun/EPGStation directories under: ${DATA_DIR}"
echo "Recorded directory: ${REC_DIR}"

