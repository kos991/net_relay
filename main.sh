#!/usr/bin/env bash
set -euo pipefail

INSTALL_URL="${INSTALL_URL:-https://rels.jinfei.org/install.sh}"

tmp_file="$(mktemp)"
cleanup() {
  rm -f "$tmp_file"
}
trap cleanup EXIT

download_file() {
  local url="$1"
  local output="$2"

  echo "正在下载安装入口：${url}" >&2
  if command -v curl >/dev/null 2>&1; then
    curl -fL --connect-timeout 10 --max-time 120 --retry 2 --retry-delay 2 "$url" -o "$output"
  elif command -v wget >/dev/null 2>&1; then
    wget --timeout=10 --tries=3 -O "$output" "$url"
  else
    echo "需要安装 curl 或 wget 后再执行。" >&2
    exit 1
  fi
}

download_file "$INSTALL_URL" "$tmp_file" || {
  echo "下载失败：${INSTALL_URL}" >&2
  echo "请检查服务器能否访问 GitHub raw，或临时设置 INSTALL_URL 为可访问的 install.sh 地址。" >&2
  exit 1
}

bash "$tmp_file"
