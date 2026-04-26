#!/usr/bin/env bash
set -euo pipefail

if [[ -f ".env.local" ]]; then
  set -a
  # shellcheck disable=SC1091
  source ".env.local"
  set +a
fi

DATA_DIR="${1:-${HOST_DATA_DIR:-./data}}"
REC_DIR="${2:-${RECORDED_DIR:-./recorded}}"
LEGACY_CONF_DIR="${LEGACY_MIRAKURUN_CONF_DIR:-}"
INSTALL_UID="${EPGSTATION_UID:-$(id -u)}"
INSTALL_GID="${EPGSTATION_GID:-$(id -g)}"

ensure_dir() {
  local dir_path="$1"

  if mkdir -p "${dir_path}" 2>/dev/null; then
    return 0
  fi

  echo "通常ユーザーで作成できないため sudo で作成します: ${dir_path}"
  sudo install -d -o "${INSTALL_UID}" -g "${INSTALL_GID}" -m 0755 "${dir_path}"
}

for dir_path in \
  "${DATA_DIR}/mirakurun/conf" \
  "${DATA_DIR}/mirakurun/data" \
  "${DATA_DIR}/mariadb" \
  "${DATA_DIR}/epgstation/config" \
  "${DATA_DIR}/epgstation/data" \
  "${DATA_DIR}/epgstation/logs" \
  "${DATA_DIR}/epgstation/thumbnail" \
  "${REC_DIR}"
do
  ensure_dir "${dir_path}"
done

copy_if_missing() {
  local src="$1"
  local dst="$2"
  if [[ ! -f "${dst}" && -f "${src}" ]]; then
    cp "${src}" "${dst}"
  fi
}

escape_sed_replacement() {
  printf '%s' "$1" | sed -e 's/[\\/&]/\\&/g'
}

copy_from_legacy_or_sample() {
  local filename="$1"
  local sample="$2"
  local destination="${DATA_DIR}/mirakurun/conf/${filename}"

  if [[ -f "${destination}" ]]; then
    return 0
  fi

  if [[ -n "${LEGACY_CONF_DIR}" && -f "${LEGACY_CONF_DIR}/${filename}" ]]; then
    cp "${LEGACY_CONF_DIR}/${filename}" "${destination}"
    return 0
  fi

  copy_if_missing "${sample}" "${destination}"
}

render_mirakurun_server_config() {
  local dst="${DATA_DIR}/mirakurun/conf/server.yml"
  local hostname
  local port

  hostname="$(escape_sed_replacement "${MIRAKURUN_HOSTNAME:-localhost}")"
  port="$(escape_sed_replacement "${MIRAKURUN_PORT:-40772}")"

  if [[ -f "${dst}" ]]; then
    return 0
  fi

  if [[ -n "${LEGACY_CONF_DIR}" && -f "${LEGACY_CONF_DIR}/server.yml" ]]; then
    cp "${LEGACY_CONF_DIR}/server.yml" "${dst}"
    return 0
  fi

  copy_if_missing "./mirakurun/conf/server.yml.template" "${dst}"
  sed -i \
    -e "s|__MIRAKURUN_PORT__|${port}|g" \
    -e "s|__MIRAKURUN_HOSTNAME__|${hostname}|g" \
    "${dst}"
}

render_epgstation_config() {
  local dst="${DATA_DIR}/epgstation/config/config.yml"
  local db_host
  local db_port
  local db_user
  local db_password
  local db_name
  local mirakurun_url

  db_host="$(escape_sed_replacement "${EPG_DB_HOST:-epg-sql}")"
  db_port="$(escape_sed_replacement "${EPG_DB_PORT:-3306}")"
  db_user="$(escape_sed_replacement "${EPG_DB_USER:-epgstation}")"
  db_password="$(escape_sed_replacement "${EPG_DB_PASSWORD:-change-me}")"
  db_name="$(escape_sed_replacement "${EPG_DB_NAME:-epgstation}")"
  mirakurun_url="$(escape_sed_replacement "${EPG_MIRAKURUN_URL:-http://mirakurun:40772/}")"

  if [[ -f "${dst}" ]]; then
    return 0
  fi

  copy_if_missing "./epgstation/config/config.yml.template" "${dst}"
  sed -i \
    -e "s|^mirakurunPath: .*|mirakurunPath: ${mirakurun_url}|" \
    -e "0,/^    host: /s|^    host: .*|    host: ${db_host}|" \
    -e "0,/^    port: /s|^    port: .*|    port: ${db_port}|" \
    -e "0,/^    user: /s|^    user: .*|    user: ${db_user}|" \
    -e "0,/^    password: /s|^    password: .*|    password: ${db_password}|" \
    -e "0,/^    database: /s|^    database: .*|    database: ${db_name}|" \
    "${dst}"
}

copy_if_missing "./epgstation/config/enc.js.template" "${DATA_DIR}/epgstation/config/enc.js"
copy_if_missing "./epgstation/config/operatorLogConfig.sample.yml" "${DATA_DIR}/epgstation/config/operatorLogConfig.yml"
copy_if_missing "./epgstation/config/epgUpdaterLogConfig.sample.yml" "${DATA_DIR}/epgstation/config/epgUpdaterLogConfig.yml"
copy_if_missing "./epgstation/config/serviceLogConfig.sample.yml" "${DATA_DIR}/epgstation/config/serviceLogConfig.yml"
render_epgstation_config
render_mirakurun_server_config
copy_from_legacy_or_sample "channels.yml" "./mirakurun/conf/channels.yml.example"
copy_from_legacy_or_sample "tuners.yml" "./mirakurun/conf/tuners.yml.example"

echo "Initialized Mirakurun/EPGStation directories under: ${DATA_DIR}"
echo "Recorded directory: ${REC_DIR}"
