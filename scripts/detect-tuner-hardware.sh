#!/usr/bin/env bash
set -euo pipefail

# 録画チューナーの種類を、実機に見えているデバイスから判定する。
# 出力は install 側でも使いやすいように 1 行だけにする。

if compgen -G "/dev/px4video*" >/dev/null 2>&1; then
  echo "pxw3u4"
  exit 0
fi

if command -v lsusb >/dev/null 2>&1 && lsusb | grep -Eqi '0511:083f|PXW3U4|PX-W3U4'; then
  echo "pxw3u4"
  exit 0
fi

if [[ -e /dev/dvb ]]; then
  echo "dvb"
  exit 0
fi

if command -v lspci >/dev/null 2>&1 && lspci | grep -Eqi 'Earthsoft|PT3|Altera.*4c15'; then
  echo "dvb"
  exit 0
fi

echo "unknown"
