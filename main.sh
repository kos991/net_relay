#!/usr/bin/env bash
set -euo pipefail

INSTALL_URL="${INSTALL_URL:-https://raw.githubusercontent.com/kos991/net_relay/main/install.sh}"

tmp_file="$(mktemp)"
cleanup() {
  rm -f "$tmp_file"
}
trap cleanup EXIT

if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$INSTALL_URL" -o "$tmp_file"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "$tmp_file" "$INSTALL_URL"
else
  echo "需要安装 curl 或 wget 后再执行。" >&2
  exit 1
fi

bash "$tmp_file"
