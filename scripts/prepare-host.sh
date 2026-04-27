#!/usr/bin/env bash
set -euo pipefail

if ! command -v apt-get >/dev/null 2>&1; then
  echo "This script currently supports Debian/Ubuntu hosts only."
  exit 1
fi

run_sudo() {
  if [[ -n "${SUDO_PASSWORD:-}" ]]; then
    printf '%s\n' "${SUDO_PASSWORD}" | sudo -S "$@"
  else
    sudo "$@"
  fi
}

PACKAGES=(
  dkms
  git
  usbutils
  pciutils
  dvb-tools
  curl
  libpcsclite-dev
  pcscd
  pcsc-tools
  libccid
)

missing_packages=()
for package in "${PACKAGES[@]}"; do
  if ! dpkg -s "${package}" >/dev/null 2>&1; then
    missing_packages+=("${package}")
  fi
done

if [[ "${#missing_packages[@]}" -gt 0 ]]; then
  echo "Installing host packages: ${missing_packages[*]}"
  run_sudo apt-get update
  run_sudo apt-get install -y "${missing_packages[@]}"
else
  echo "Required host packages are already installed."
fi

hardware_profile="${TUNER_HARDWARE_PROFILE:-auto}"
if [[ "${hardware_profile}" == "auto" && -x "./scripts/detect-tuner-hardware.sh" ]]; then
  hardware_profile="$(./scripts/detect-tuner-hardware.sh)"
fi

echo "Detected tuner hardware profile: ${hardware_profile}"

case "${hardware_profile}" in
  pxw3u4)
    ./scripts/install-pxw3u4-host-driver.sh
    ;;
  dvb|pt3)
    if [[ -e /dev/dvb ]]; then
      echo "Detected /dev/dvb"
    else
      echo "WARNING: /dev/dvb was not found. PT3/DVB devices are not currently visible on this host."
    fi
    ;;
  unknown)
    echo "WARNING: tuner hardware was not detected. Connect PT3/DVB or PX-W3U4 and rerun this script."
    ;;
  *)
    echo "WARNING: unknown TUNER_HARDWARE_PROFILE=${hardware_profile}"
    ;;
esac

for unit in pcscd.socket pcscd.service; do
  if systemctl list-unit-files "${unit}" >/dev/null 2>&1; then
    run_sudo systemctl stop "${unit}" || true
    run_sudo systemctl disable "${unit}" || true
    echo "Stopped and disabled ${unit}"
  fi
done

if [[ -e /dev/dri ]]; then
  echo "Detected /dev/dri"
else
  echo "WARNING: /dev/dri was not found. Hardware transcoding may be unavailable."
fi

echo "Recording host preparation finished."
