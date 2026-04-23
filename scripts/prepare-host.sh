#!/usr/bin/env bash
set -euo pipefail

if ! command -v apt-get >/dev/null 2>&1; then
  echo "This script currently supports Debian/Ubuntu hosts only."
  exit 1
fi

PACKAGES=(
  dkms
  git
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
  sudo apt-get update
  sudo apt-get install -y "${missing_packages[@]}"
else
  echo "Required host packages are already installed."
fi

for unit in pcscd.socket pcscd.service; do
  if systemctl list-unit-files "${unit}" >/dev/null 2>&1; then
    sudo systemctl stop "${unit}" || true
    sudo systemctl disable "${unit}" || true
    echo "Stopped and disabled ${unit}"
  fi
done

if [[ -e /dev/dvb ]]; then
  echo "Detected /dev/dvb"
else
  echo "WARNING: /dev/dvb was not found. Tuner devices are not currently visible on this host."
fi

if [[ -e /dev/dri ]]; then
  echo "Detected /dev/dri"
else
  echo "WARNING: /dev/dri was not found. Hardware transcoding may be unavailable."
fi

echo "Recording host preparation finished."
