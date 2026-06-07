#!/usr/bin/env bash
set -euo pipefail

RELEASE_BASE="${RELEASE_BASE:-https://github.com/kos991/net_relay/releases/latest/download}"
INSTALL_DIR="${INSTALL_DIR:-/opt/netbird-relay-installer}"
BIN_PATH="${BIN_PATH:-/usr/local/bin/netbird-relay}"
CONFIG_DIR="${CONFIG_DIR:-/etc/netbird-relay}"
INSTALL_MODE="${INSTALL_MODE:-binary}"

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
    fail "Root permission is required. Run as root or install/configure sudo first."
  fi
}

detect_install_mode() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --binary)
        INSTALL_MODE="binary"
        ;;
      --compose|--docker-compose)
        INSTALL_MODE="compose"
        ;;
      *)
        fail "Unknown option: $1"
        ;;
    esac
    shift
  done

  case "$INSTALL_MODE" in
    binary|compose) ;;
    *) fail "INSTALL_MODE must be binary or compose." ;;
  esac
}

detect_os() {
  [[ -r /etc/os-release ]] || fail "Cannot detect OS: missing /etc/os-release. Supported: Debian/Ubuntu/Rocky/Alma/Alpine."

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
      fail "Unsupported OS: ${PRETTY_NAME:-${OS_ID}}. Supported: Debian/Ubuntu/Rocky/Alma/Alpine."
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
      fail "Unsupported CPU architecture: ${machine}. Supported: amd64/arm64."
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

install_compose_dependencies() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    return 0
  fi

  case "$OS_FAMILY" in
    debian)
      run_as_root apt-get update
      run_as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y \
        docker.io \
        docker-compose-plugin
      ;;
    rhel)
      local pkg_manager="dnf"
      command -v dnf >/dev/null 2>&1 || pkg_manager="yum"
      run_as_root "$pkg_manager" install -y \
        docker \
        docker-compose-plugin
      ;;
    alpine)
      run_as_root apk add --no-cache \
        docker \
        docker-cli-compose
      ;;
  esac

  if command -v systemctl >/dev/null 2>&1; then
    run_as_root systemctl enable --now docker
  elif command -v rc-update >/dev/null 2>&1; then
    run_as_root rc-update add docker default
    run_as_root service docker start
  fi

  docker compose version >/dev/null 2>&1 || fail "Docker Compose is unavailable after installation."
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

  log "Downloading: ${url}"
  if command -v curl >/dev/null 2>&1; then
    curl -fL --connect-timeout 10 --max-time 180 --retry 2 --retry-delay 2 "$url" -o "$output"
  elif command -v wget >/dev/null 2>&1; then
    wget --timeout=10 --tries=3 -O "$output" "$url"
  else
    fail "curl or wget is required."
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
    warn "sha256sum/shasum not found; skipping SHA256 verification."
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
  [[ -x "${tmp_dir}/netbird-relay/bin/netbird-relay" ]] || fail "Package is missing netbird-relay binary."

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
  detect_install_mode "$@"
  detect_os
  install_base_dependencies
  ensure_scheduler
  install_installer_files

  if [[ "$INSTALL_MODE" == "compose" ]]; then
    install_compose_dependencies
    log "Starting Docker Compose configuration wizard."
    DEPLOY_MODE=compose exec bash "$INSTALL_DIR/setup-relay.sh"
  fi

  local arch package_file tmp_dir
  arch="$(detect_arch)"
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT

  package_file="$(download_relay_package "$arch" "$tmp_dir")"
  install_relay_binary "$package_file"

  log "netbird-relay binary installed: ${BIN_PATH}"
  log "Starting binary configuration wizard."
  DEPLOY_MODE=binary exec bash "$INSTALL_DIR/setup-relay.sh"
}

main "$@"
