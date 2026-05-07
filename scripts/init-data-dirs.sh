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
MIRAKURUN_CONF_DIR="${MIRAKURUN_CONFIG_DIR:-${DATA_DIR}/mirakurun/conf}"
MIRAKURUN_APP_DATA_DIR="${MIRAKURUN_DATA_DIR:-${DATA_DIR}/mirakurun/data}"
EPG_SQL_DATA_DIR="${EPG_DB_DIR:-${DATA_DIR}/mirakurun/mira_sql}"
EPGSTATION_CONF_DIR="${EPGSTATION_CONFIG_DIR:-${DATA_DIR}/epgstation/config}"
EPGSTATION_APP_DATA_DIR="${EPGSTATION_DATA_DIR:-${DATA_DIR}/epgstation/data}"
EPGSTATION_LOG_DIR="${EPGSTATION_LOGS_DIR:-${DATA_DIR}/epgstation/logs}"
EPGSTATION_THUMBNAIL_DATA_DIR="${EPGSTATION_THUMBNAIL_DIR:-${DATA_DIR}/epgstation/thumbnail}"

ensure_dir() {
  local dir_path="$1"

  if mkdir -p "${dir_path}" 2>/dev/null; then
    return 0
  fi

  echo "通常ユーザーで作成できないため sudo で作成します: ${dir_path}"
  sudo install -d -o "${INSTALL_UID}" -g "${INSTALL_GID}" -m 0755 "${dir_path}"
}

for dir_path in \
  "${MIRAKURUN_CONF_DIR}" \
  "${MIRAKURUN_APP_DATA_DIR}" \
  "${EPG_SQL_DATA_DIR}" \
  "${EPGSTATION_CONF_DIR}" \
  "${EPGSTATION_APP_DATA_DIR}" \
  "${EPGSTATION_LOG_DIR}" \
  "${EPGSTATION_THUMBNAIL_DATA_DIR}" \
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

yaml_list_items() {
  local values="$1"
  local value

  for value in ${values}; do
    [[ -n "${value}" ]] || continue
    printf '  - %s\n' "${value}"
  done
}

replace_yaml_list_block() {
  local file_path="$1"
  local key="$2"
  local values="$3"
  local tmp_file

  tmp_file="$(mktemp)"
  awk -v key="${key}" -v values="${values}" '
    BEGIN {
      list_count = split(values, list_values, /[[:space:]]+/)
    }
    $0 == key ":" {
      print key ":"
      for (i = 1; i <= list_count; i++) {
        if (list_values[i] != "") {
          print "  - " list_values[i]
        }
      }
      skipping = 1
      next
    }
    skipping && $0 ~ /^  - / {
      next
    }
    {
      skipping = 0
      print
    }
  ' "${file_path}" >"${tmp_file}"
  mv "${tmp_file}" "${file_path}"

  if ! grep -q "^${key}:" "${file_path}"; then
    {
      printf '\n%s:\n' "${key}"
      yaml_list_items "${values}"
    } >>"${file_path}"
  fi
}

copy_from_legacy_or_sample() {
  local filename="$1"
  local sample="$2"
  local destination="${MIRAKURUN_CONF_DIR}/${filename}"

  if [[ -f "${destination}" ]]; then
    return 0
  fi

  if [[ -n "${LEGACY_CONF_DIR}" && -f "${LEGACY_CONF_DIR}/${filename}" ]]; then
    cp "${LEGACY_CONF_DIR}/${filename}" "${destination}"
    return 0
  fi

  copy_if_missing "${sample}" "${destination}"
}

detect_tuner_hardware_profile() {
  local profile="${TUNER_HARDWARE_PROFILE:-auto}"

  if [[ "${profile}" != "auto" ]]; then
    printf '%s\n' "${profile}"
    return 0
  fi

  if [[ -x "./scripts/detect-tuner-hardware.sh" ]]; then
    ./scripts/detect-tuner-hardware.sh
  else
    printf 'unknown\n'
  fi
}

apply_tuner_profile_config() {
  local profile
  local tuners_file="${MIRAKURUN_CONF_DIR}/tuners.yml"
  local tuners_body

  profile="$(detect_tuner_hardware_profile)"
  echo "Detected tuner hardware profile: ${profile}"

  case "${profile}" in
    pxw3u4)
      tuners_body=""
      if [[ -f "${tuners_file}" ]]; then
        tuners_body="$(
          awk '
            /^[[:space:]]*#/ { next }
            /^[[:space:]]*$/ { next }
            { gsub(/[[:space:]]/, "", $0); printf "%s", $0 }
          ' "${tuners_file}"
        )"
      fi

      if [[ ! -f "${tuners_file}" || "${tuners_body}" == "[]" || "${FORCE_TUNERS:-0}" == "1" ]] \
        || grep -Eq '(/dev/dvb|dvbv5-zap)' "${tuners_file}" 2>/dev/null; then
        cp "./mirakurun/conf/tuners.pxw3u4.yml.example" "${tuners_file}"
        echo "Applied PX-W3U4 tuners.yml: ${tuners_file}"
      else
        echo "KEEP tuners.yml already exists: ${tuners_file}"
      fi
      ;;
    dvb|pt3|unknown)
      ;;
    *)
      echo "WARNING: unknown TUNER_HARDWARE_PROFILE=${profile}"
      ;;
  esac
}

render_mirakurun_server_config() {
  local dst="${MIRAKURUN_CONF_DIR}/server.yml"
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

apply_mirakurun_server_overrides() {
  local dst="${MIRAKURUN_CONF_DIR}/server.yml"
  local hostname="${MIRAKURUN_HOSTNAME:-}"
  local port="${MIRAKURUN_PORT:-}"
  local allow_ipv4_ranges="${MIRAKURUN_ALLOW_IPV4_CIDR_RANGES:-10.0.0.0/8 127.0.0.0/8 172.16.0.0/12 192.168.0.0/16}"

  [[ -f "${dst}" ]] || return 0

  # 既存データを引き継いだ場合でも、親 installer から明示された公開名は反映する。
  # ここが localhost のままだと、ブラウザUIや外部連携で localhost 前提に見えるため混乱しやすい。
  if [[ -n "${hostname}" ]]; then
    hostname="$(escape_sed_replacement "${hostname}")"
    if grep -q '^hostname:' "${dst}"; then
      sed -i -e "s|^hostname:.*|hostname: ${hostname}|" "${dst}"
    else
      printf '\nhostname: %s\n' "${hostname}" >>"${dst}"
    fi
  fi

  if [[ -n "${port}" ]]; then
    port="$(escape_sed_replacement "${port}")"
    if grep -q '^port:' "${dst}"; then
      sed -i -e "s|^port:.*|port: ${port}|" "${dst}"
    else
      printf 'port: %s\n' "${port}" >>"${dst}"
    fi
  fi

  # 旧 server.yml を使った場合でも、Docker 内部と家庭内LANからのアクセスを許可する。
  # 現在の検証PCは 192.168.2.x なので、既定値の 192.168.0.0/16 に含めている。
  replace_yaml_list_block "${dst}" "allowIPv4CidrRanges" "${allow_ipv4_ranges}"
}

render_epgstation_config() {
  local dst="${EPGSTATION_CONF_DIR}/config.yml"
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

copy_if_missing "./epgstation/config/enc.js.template" "${EPGSTATION_CONF_DIR}/enc.js"
copy_if_missing "./epgstation/config/operatorLogConfig.sample.yml" "${EPGSTATION_CONF_DIR}/operatorLogConfig.yml"
copy_if_missing "./epgstation/config/epgUpdaterLogConfig.sample.yml" "${EPGSTATION_CONF_DIR}/epgUpdaterLogConfig.yml"
copy_if_missing "./epgstation/config/serviceLogConfig.sample.yml" "${EPGSTATION_CONF_DIR}/serviceLogConfig.yml"
render_epgstation_config
render_mirakurun_server_config
apply_mirakurun_server_overrides
copy_from_legacy_or_sample "channels.yml" "./mirakurun/conf/channels.yml.example"
copy_from_legacy_or_sample "tuners.yml" "./mirakurun/conf/tuners.yml.example"
apply_tuner_profile_config

echo "Initialized Mirakurun/EPGStation directories under: ${DATA_DIR}"
echo "Recorded directory: ${REC_DIR}"
