#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${ENV_FILE:-.env.local}"
MIRAKURUN_URL="${MIRAKURUN_URL:-http://127.0.0.1:${MIRAKURUN_PORT:-40772}}"

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
  MIRAKURUN_URL="${MIRAKURUN_URL:-http://127.0.0.1:${MIRAKURUN_PORT:-40772}}"
fi

scan_type() {
  local channel_type="$1"
  echo "Scanning ${channel_type} channels via ${MIRAKURUN_URL}"
  curl -fsS -X PUT \
    "${MIRAKURUN_URL}/api/config/channels/scan?type=${channel_type}&setDisabledOnAdd=false&refresh=true"
  echo
}

scan_type GR || true
scan_type BS || true
scan_type CS || true

echo "Channel scan requests completed."
