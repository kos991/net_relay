#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/kos991/net_relay.git}"
ARCHIVE_URL="${ARCHIVE_URL:-https://rels.jinfei.org/net_relay-main.tar.gz}"
ARCHIVE_FALLBACK_URL="${ARCHIVE_FALLBACK_URL:-https://github.com/kos991/net_relay/archive/refs/heads/main.tar.gz}"
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
  local fallback_url="${3:-}"

  log "正在下载安装器：${url}"
  if command -v curl >/dev/null 2>&1; then
    if curl -fL --connect-timeout 10 --max-time 180 --retry 2 --retry-delay 2 "$url" -o "$output"; then
      return 0
    fi
  elif command -v wget >/dev/null 2>&1; then
    if wget --timeout=10 --tries=3 -O "$output" "$url"; then
      return 0
    fi
  else
    fail "需要安装 git、curl 或 wget 之一，用于下载安装器。"
  fi

  if [[ -n "$fallback_url" ]]; then
    warn "主下载地址失败，尝试 GitHub 备用：${fallback_url}"
    if command -v curl >/dev/null 2>&1; then
      curl -fL --connect-timeout 10 --max-time 180 --retry 1 --retry-delay 2 "$fallback_url" -o "$output"
    else
      wget --timeout=10 --tries=2 -O "$output" "$fallback_url"
    fi
  else
    return 1
  fi
}

sync_installer_files() {
  local source_dir="$1"

  mkdir -p "$INSTALL_DIR"
  log "正在同步安装器文件到：${INSTALL_DIR}"
  warn "保留现有配置和数据：.env、relay.env、docker-compose.yml、data/、证书和 Caddyfile。"

  tar -C "$source_dir" \
    --exclude=.env \
    --exclude=relay.env \
    --exclude=docker-compose.yml \
    --exclude=data \
    --exclude=certs \
    --exclude=caddy/Caddyfile \
    --exclude=.git \
    -cf - . | tar -C "$INSTALL_DIR" -xf -
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
    download_file "$ARCHIVE_URL" "$tmp_dir/repo.tar.gz" "$ARCHIVE_FALLBACK_URL"
  elif command -v wget >/dev/null 2>&1; then
    download_file "$ARCHIVE_URL" "$tmp_dir/repo.tar.gz" "$ARCHIVE_FALLBACK_URL"
  else
    fail "需要安装 git、curl 或 wget 之一，用于下载安装器。"
  fi

  tar -xzf "$tmp_dir/repo.tar.gz" -C "$tmp_dir"
  shopt -s nullglob
  local extracted_dirs=("$tmp_dir"/net_relay-*)
  (( ${#extracted_dirs[@]} > 0 )) || fail "安装包解压失败，未找到 net_relay-* 目录。"
  sync_installer_files "${extracted_dirs[0]}"
  rm -rf "$tmp_dir"
}

sync_repo() {
  mkdir -p "$(dirname "$INSTALL_DIR")"

  if command -v git >/dev/null 2>&1; then
    warn "检测到 git，但默认使用 rels.jinfei.org 安装包以避免 GitHub 网络不稳定。"
  else
    warn "未检测到 git，使用压缩包下载安装器。"
  fi
  download_with_tarball
}

need_root_for_install_dir
sync_repo
chmod +x "$INSTALL_DIR/setup-relay.sh"

log "正在启动安装器：${INSTALL_DIR}"
cd "$INSTALL_DIR"
exec ./setup-relay.sh
