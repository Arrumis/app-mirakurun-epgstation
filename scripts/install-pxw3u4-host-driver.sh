#!/usr/bin/env bash
set -euo pipefail

WORK_DIR="${PXW3U4_DRIVER_WORK_DIR:-${HOME}/src/px4_drv}"
PX4_REPO="${PXW3U4_DRIVER_REPO:-https://github.com/nns779/px4_drv.git}"
FIRMWARE_PATH="/lib/firmware/it930x-firmware.bin"

run_sudo() {
  if [[ -n "${SUDO_PASSWORD:-}" ]]; then
    printf '%s\n' "${SUDO_PASSWORD}" | sudo -S "$@"
  else
    sudo "$@"
  fi
}

patch_px4_driver_source() {
  local source_dir="$1"
  local chrdev_file="${source_dir}/driver/ptx_chrdev.c"

  if [[ ! -f "${chrdev_file}" ]]; then
    echo "WARNING: px4_drv の ptx_chrdev.c が見つかりません: ${chrdev_file}"
    return 0
  fi

  # Linux 6.4 以降では strlcpy が使えず、class_create() も引数が 1 つに変わっている。
  # Ubuntu 24.04 / 26.04 系で DKMS ビルドが止まるため、ビルド前に互換パッチを当てる。
  if grep -q 'strlcpy(' "${chrdev_file}"; then
    sed -i 's/strlcpy(/strscpy(/g' "${chrdev_file}"
  fi

  if ! grep -q '#include <linux/version.h>' "${chrdev_file}"; then
    sed -i '/#include <linux\/fs.h>/a #include <linux/version.h>' "${chrdev_file}"
  fi

  if grep -q 'ctx->class = class_create(THIS_MODULE, name);' "${chrdev_file}"; then
    perl -0pi -e 's|ctx->class = class_create\(THIS_MODULE, name\);|#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 4, 0)\n\tctx->class = class_create(THIS_MODULE, name);\n#else\n\tctx->class = class_create(name);\n#endif|' "${chrdev_file}"
  fi
}

echo "PX-W3U4 用ホストドライバ px4_drv を確認します。"

run_sudo apt-get update
run_sudo apt-get install -y \
  build-essential \
  ca-certificates \
  curl \
  dkms \
  git \
  linux-headers-"$(uname -r)" \
  make \
  unzip \
  wget

mkdir -p "$(dirname "${WORK_DIR}")"
if [[ -d "${WORK_DIR}/.git" ]]; then
  echo "px4_drv ソースを更新します: ${WORK_DIR}"
  git -C "${WORK_DIR}" pull --ff-only
else
  echo "px4_drv ソースを取得します: ${WORK_DIR}"
  git clone --depth=1 "${PX4_REPO}" "${WORK_DIR}"
fi

patch_px4_driver_source "${WORK_DIR}"

if [[ ! -f "${FIRMWARE_PATH}" ]]; then
  echo "PX-W3U4 ファームウェアを作成します。"
  (
    cd "${WORK_DIR}/fwtool"
    make
    wget http://plex-net.co.jp/plex/pxw3u4/pxw3u4_BDA_ver1x64.zip -O pxw3u4_BDA_ver1x64.zip
    unzip -oj pxw3u4_BDA_ver1x64.zip pxw3u4_BDA_ver1x64/PXW3U4.sys
    ./fwtool PXW3U4.sys it930x-firmware.bin
  )
  run_sudo install -D -m 0644 "${WORK_DIR}/fwtool/it930x-firmware.bin" "${FIRMWARE_PATH}"
else
  echo "PX-W3U4 ファームウェアは既にあります: ${FIRMWARE_PATH}"
fi

driver_version="$(
  awk -F= '/PACKAGE_VERSION/ {
    gsub(/"/, "", $2)
    print $2
    exit
  }' "${WORK_DIR}/dkms.conf"
)"
driver_version="${driver_version:-0.2.1}"
dkms_name="px4_drv/${driver_version}"

if dkms status "${dkms_name}" 2>/dev/null | grep -q 'installed'; then
  echo "DKMS ビルド済みです: ${dkms_name}"
else
  echo "DKMS ソースを更新します: ${dkms_name}"
  run_sudo dkms remove "${dkms_name}" --all 2>/dev/null || true
  echo "DKMS へ px4_drv を登録します: ${dkms_name}"
  run_sudo rm -rf "/usr/src/px4_drv-${driver_version}"
  run_sudo cp -a "${WORK_DIR}" "/usr/src/px4_drv-${driver_version}"
  run_sudo dkms add "${dkms_name}"

  echo "DKMS で px4_drv をビルド・インストールします。"
  run_sudo dkms install "${dkms_name}"
fi

run_sudo modprobe -r px4_drv 2>/dev/null || true
run_sudo modprobe px4_drv

if compgen -G "/dev/px4video*" >/dev/null 2>&1; then
  echo "PX-W3U4 デバイスを検出しました。"
  ls -l /dev/px4video*
else
  echo "WARNING: px4_drv は導入しましたが /dev/px4video* が見えません。"
  echo "USBを抜き差しするか、再起動後に再確認してください。"
fi
