#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/kos991/net_relay.git}"
ARCHIVE_URL="${ARCHIVE_URL:-https://github.com/kos991/net_relay/archive/refs/heads/main.tar.gz}"
INSTALL_DIR="${INSTALL_DIR:-/opt/netbird-relay-installer}"
BRANCH="${BRANCH:-main}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
  echo -e "${GREEN}$*${NC}"
}

warn() {
  echo -e "${YELLOW}$*${NC}"
}

fail() {
  echo -e "${RED}$*${NC}" >&2
  exit 1
}

download_file() {
  local url="$1"
  local output="$2"

  log "正在下载安装器：${url}"
  if command -v curl >/dev/null 2>&1; then
    curl -fL --connect-timeout 10 --max-time 180 --retry 2 --retry-delay 2 "$url" -o "$output"
  elif command -v wget >/dev/null 2>&1; then
    wget --timeout=10 --tries=3 -O "$output" "$url"
  else
    fail "需要安装 git、curl 或 wget 之一，用于下载安装器。"
  fi
}

need_root_for_install_dir() {
  if [[ "${EUID}" -ne 0 && "$INSTALL_DIR" == /opt/* ]]; then
    fail "请使用 root 执行，或通过 INSTALL_DIR 指定当前用户可写目录。"
  fi
}

download_with_tarball() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"

  if command -v curl >/dev/null 2>&1; then
    download_file "$ARCHIVE_URL" "$tmp_dir/repo.tar.gz"
  elif command -v wget >/dev/null 2>&1; then
    download_file "$ARCHIVE_URL" "$tmp_dir/repo.tar.gz"
  else
    fail "需要安装 git、curl 或 wget 之一，用于下载安装器。"
  fi

  rm -rf "$INSTALL_DIR"
  mkdir -p "$INSTALL_DIR"
  tar -xzf "$tmp_dir/repo.tar.gz" -C "$tmp_dir"
  shopt -s dotglob nullglob
  mv "$tmp_dir"/net_relay-*/* "$INSTALL_DIR"/
  rm -rf "$tmp_dir"
}

sync_repo() {
  mkdir -p "$(dirname "$INSTALL_DIR")"

  if command -v git >/dev/null 2>&1; then
    if [[ -d "$INSTALL_DIR/.git" ]]; then
      log "正在更新安装器：${INSTALL_DIR}"
      git -C "$INSTALL_DIR" fetch --depth 1 origin "$BRANCH" || fail "更新安装器失败，请检查服务器到 GitHub 的网络。"
      git -C "$INSTALL_DIR" reset --hard "origin/${BRANCH}"
    else
      rm -rf "$INSTALL_DIR"
      log "正在下载安装到：${INSTALL_DIR}"
      git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$INSTALL_DIR" || fail "下载安装器失败，请检查服务器到 GitHub 的网络。"
    fi
  else
    warn "未检测到 git，改用压缩包下载安装器。"
    download_with_tarball
  fi
}

need_root_for_install_dir
sync_repo
chmod +x "$INSTALL_DIR/setup-relay.sh"

log "正在启动安装器：${INSTALL_DIR}"
cd "$INSTALL_DIR"
exec ./setup-relay.sh
