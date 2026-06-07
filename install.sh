#!/usr/bin/env bash
set -euo pipefail

RELEASE_BASE="${RELEASE_BASE:-https://github.com/kos991/net_relay/releases/latest/download}"
INSTALL_DIR="${INSTALL_DIR:-/opt/netbird-relay-installer}"
BIN_PATH="${BIN_PATH:-/usr/local/bin/netbird-relay}"
CONFIG_DIR="${CONFIG_DIR:-/etc/netbird-relay}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

OS_ID=""
OS_ID_LIKE=""
OS_VERSION_CODENAME=""
OS_FAMILY=""

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

run_as_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    fail "需要 root 权限执行：$*。请使用 root 运行，或先安装 sudo 并授权当前用户。"
  fi
}

detect_os() {
  [[ -r /etc/os-release ]] || fail "无法识别系统：缺少 /etc/os-release。支持 Debian/Ubuntu/Rocky/Alma/Alpine。"

  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID="${ID:-}"
  OS_ID_LIKE="${ID_LIKE:-}"
  OS_VERSION_CODENAME="${VERSION_CODENAME:-}"

  case " ${OS_ID} ${OS_ID_LIKE} " in
    *" debian "*|*" ubuntu "*)
      OS_FAMILY="debian"
      ;;
    *" rhel "*|*" fedora "*|*" rocky "*|*" almalinux "*|*" centos "*)
      OS_FAMILY="rhel"
      ;;
    *" alpine "*)
      OS_FAMILY="alpine"
      ;;
    *)
      fail "不支持的系统：${PRETTY_NAME:-${OS_ID}}。当前支持 Debian/Ubuntu/Rocky/Alma/Alpine。"
      ;;
  esac
}

detect_arch() {
  local machine
  machine="$(uname -m)"
  case "$machine" in
    x86_64|amd64)
      printf 'amd64'
      ;;
    aarch64|arm64)
      printf 'arm64'
      ;;
    *)
      fail "不支持的 CPU 架构：${machine}。当前支持 amd64/arm64。"
      ;;
  esac
}

install_base_dependencies() {
  case "$OS_FAMILY" in
    debian)
      run_as_root apt-get update
      run_as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y \
        bash \
        ca-certificates \
        cron \
        curl \
        openssl \
        tar
      ;;
    rhel)
      local pkg_manager="dnf"
      command -v dnf >/dev/null 2>&1 || pkg_manager="yum"
      run_as_root "$pkg_manager" install -y \
        bash \
        ca-certificates \
        cronie \
        curl \
        openssl \
        tar
      ;;
    alpine)
      run_as_root apk add --no-cache \
        bash \
        ca-certificates \
        cronie \
        curl \
        openssl \
        tar
      ;;
  esac
}

ensure_scheduler() {
  if command -v systemctl >/dev/null 2>&1; then
    run_as_root systemctl enable --now cron >/dev/null 2>&1 || \
      run_as_root systemctl enable --now crond >/dev/null 2>&1 || true
  elif command -v rc-update >/dev/null 2>&1; then
    run_as_root rc-update add crond default >/dev/null 2>&1 || true
    run_as_root service crond start >/dev/null 2>&1 || true
  fi
}

download_file() {
  local url="$1"
  local output="$2"

  log "下载：${url}"
  if command -v curl >/dev/null 2>&1; then
    curl -fL --connect-timeout 10 --max-time 180 --retry 2 --retry-delay 2 "$url" -o "$output"
  elif command -v wget >/dev/null 2>&1; then
    wget --timeout=10 --tries=3 -O "$output" "$url"
  else
    fail "需要 curl 或 wget。"
  fi
}

verify_sha256() {
  local package_file="$1"
  local sums_file="$2"
  local package_name
  package_name="$(basename "$package_file")"

  if command -v sha256sum >/dev/null 2>&1; then
    (cd "$(dirname "$package_file")" && grep " ${package_name}$" "$sums_file" | sha256sum -c -)
  elif command -v shasum >/dev/null 2>&1; then
    (cd "$(dirname "$package_file")" && grep " ${package_name}$" "$sums_file" | shasum -a 256 -c -)
  else
    warn "未找到 sha256sum/shasum，跳过 SHA256 校验。"
  fi
}

download_relay_package() {
  local arch="$1"
  local output_dir="$2"
  local package_name="netbird-relay-linux-${arch}.tar.gz"

  mkdir -p "$output_dir"
  download_file "${RELEASE_BASE}/${package_name}" "${output_dir}/${package_name}"
  download_file "${RELEASE_BASE}/SHA256SUMS" "${output_dir}/SHA256SUMS"
  verify_sha256 "${output_dir}/${package_name}" "${output_dir}/SHA256SUMS"
  printf '%s' "${output_dir}/${package_name}"
}

install_relay_binary() {
  local package_file="$1"
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' RETURN

  tar -xzf "$package_file" -C "$tmp_dir"
  [[ -x "${tmp_dir}/netbird-relay/bin/netbird-relay" ]] || fail "安装包缺少 netbird-relay 二进制。"

  run_as_root install -m 0755 -D "${tmp_dir}/netbird-relay/bin/netbird-relay" "$BIN_PATH"
  run_as_root install -m 0644 -D "${tmp_dir}/netbird-relay/services/netbird-relay.service" /etc/systemd/system/netbird-relay.service
  run_as_root install -m 0755 -D "${tmp_dir}/netbird-relay/services/netbird-relay.openrc" /etc/init.d/netbird-relay
}

install_installer_files() {
  local source_dir
  source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  run_as_root mkdir -p "$INSTALL_DIR" "$CONFIG_DIR"
  run_as_root cp "$source_dir/setup-relay.sh" "$INSTALL_DIR/setup-relay.sh"
  run_as_root chmod +x "$INSTALL_DIR/setup-relay.sh"
}

main() {
  detect_os
  install_base_dependencies
  ensure_scheduler

  local arch package_file tmp_dir
  arch="$(detect_arch)"
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT

  package_file="$(download_relay_package "$arch" "$tmp_dir")"
  install_relay_binary "$package_file"
  install_installer_files

  log "netbird-relay 二进制已安装：${BIN_PATH}"
  log "正在启动配置向导。"
  exec bash "$INSTALL_DIR/setup-relay.sh"
}

main "$@"
