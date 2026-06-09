#!/usr/bin/env bash
set -euo pipefail

DEFAULT_RELEASE_BASE="https://github.com/kos991/net_relay/releases/latest/download"
RELEASE_BASE="${RELEASE_BASE:-$DEFAULT_RELEASE_BASE}"
ALLOW_CUSTOM_RELEASE_BASE="${ALLOW_CUSTOM_RELEASE_BASE:-0}"
INSTALL_DIR="${INSTALL_DIR:-/opt/netbird-relay-installer}"
BIN_PATH="${BIN_PATH:-/usr/local/bin/netbird-relay}"
CONFIG_DIR="${CONFIG_DIR:-/etc/netbird-relay}"
INSTALL_MODE="${INSTALL_MODE:-}"
RELS_LANG="${RELS_LANG:-}"

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

is_zh() {
  [[ "${RELS_LANG:-en}" == "zh" ]]
}

msg() {
  local key="$1"
  shift || true
  if is_zh; then
    case "$key" in
      root_required) printf '%s' "需要 root 权限。请使用 root 运行，或先安装并配置 sudo。" ;;
      unknown_arg) printf '未知参数：%s' "$1" ;;
      bad_install_mode) printf '%s' "INSTALL_MODE 必须是 binary 或 compose。" ;;
      custom_release_base) printf '正在使用自定义 RELEASE_BASE，请确认来源可信：%s' "$1" ;;
      bad_release_base) printf '%s' "RELEASE_BASE 必须是受信任的 HTTPS 地址。如确需自定义来源，请设置 ALLOW_CUSTOM_RELEASE_BASE=1。" ;;
      select_install_mode) printf '%s\n' "选择安装模式："; printf '%s\n' "  1. 官方二进制安装（推荐，无 Docker）"; printf '%s' "  2. Docker Compose" ;;
      select_install_prompt) printf '%s' "选择安装模式 [1]: " ;;
      read_install_mode_failed) printf '%s' "无法读取安装模式。" ;;
      read_install_mode_noninteractive) printf '%s' "无法读取安装模式。非交互安装请设置 INSTALL_MODE=binary 或 INSTALL_MODE=compose。" ;;
      enter_1_or_2) printf '%s' "请输入 1 或 2。" ;;
      os_missing) printf '%s' "无法检测系统：缺少 /etc/os-release。支持 Debian/Ubuntu/Rocky/Alma/Alpine。" ;;
      unsupported_os) printf '不支持的系统：%s。支持 Debian/Ubuntu/Rocky/Alma/Alpine。' "$1" ;;
      unsupported_arch) printf '不支持的 CPU 架构：%s。支持 amd64/arm64。' "$1" ;;
      compose_unavailable) printf '%s' "安装后仍无法使用 Docker Compose。" ;;
      alpine_binary_only) printf '%s' "Alpine 使用官方二进制安装模式，不安装 Docker/Compose。" ;;
      alpine_compose_disabled) printf '%s' "Alpine 不支持 Docker Compose 模式；请使用官方二进制安装模式。" ;;
      downloading) printf '正在下载：%s' "$1" ;;
      need_downloader) printf '%s' "需要 curl 或 wget。" ;;
      hash_missing_warn) printf '%s' "未找到 sha256sum/shasum，跳过 SHA256 校验。" ;;
      unsafe_path) printf '安装包包含不安全路径：%s' "$1" ;;
      missing_binary) printf '%s' "安装包缺少 netbird-relay 二进制文件。" ;;
      compose_wizard) printf '%s' "启动 Docker Compose 配置向导。" ;;
      binary_installed) printf 'netbird-relay 二进制已安装：%s' "$1" ;;
      binary_wizard) printf '%s' "启动二进制配置向导。" ;;
    esac
    return 0
  fi

  case "$key" in
    root_required) printf '%s' "Root privileges are required. Run as root, or install and configure sudo first." ;;
    unknown_arg) printf 'Unknown argument: %s' "$1" ;;
    bad_install_mode) printf '%s' "INSTALL_MODE must be binary or compose." ;;
    custom_release_base) printf 'Using custom RELEASE_BASE. Make sure the source is trusted: %s' "$1" ;;
    bad_release_base) printf '%s' "RELEASE_BASE must be a trusted HTTPS URL. Set ALLOW_CUSTOM_RELEASE_BASE=1 only if you really need a custom source." ;;
    select_install_mode) printf '%s\n' "Select install mode:"; printf '%s\n' "  1. Official binary install (recommended, no Docker)"; printf '%s' "  2. Docker Compose" ;;
    select_install_prompt) printf '%s' "Select install mode [1]: " ;;
    read_install_mode_failed) printf '%s' "Unable to read install mode." ;;
    read_install_mode_noninteractive) printf '%s' "Unable to read install mode. For non-interactive installs, set INSTALL_MODE=binary or INSTALL_MODE=compose." ;;
    enter_1_or_2) printf '%s' "Please enter 1 or 2." ;;
    os_missing) printf '%s' "Unable to detect OS: /etc/os-release is missing. Supported systems: Debian/Ubuntu/Rocky/Alma/Alpine." ;;
    unsupported_os) printf 'Unsupported OS: %s. Supported systems: Debian/Ubuntu/Rocky/Alma/Alpine.' "$1" ;;
    unsupported_arch) printf 'Unsupported CPU architecture: %s. Supported architectures: amd64/arm64.' "$1" ;;
    compose_unavailable) printf '%s' "Docker Compose is still unavailable after installation." ;;
    alpine_binary_only) printf '%s' "Alpine uses official binary mode; Docker/Compose is not installed." ;;
    alpine_compose_disabled) printf '%s' "Alpine does not support Docker Compose mode; use official binary mode instead." ;;
    downloading) printf 'Downloading: %s' "$1" ;;
    need_downloader) printf '%s' "curl or wget is required." ;;
    hash_missing_warn) printf '%s' "sha256sum/shasum was not found; skipping SHA256 verification." ;;
    unsafe_path) printf 'Package contains an unsafe path: %s' "$1" ;;
    missing_binary) printf '%s' "Package is missing the netbird-relay binary." ;;
    compose_wizard) printf '%s' "Starting Docker Compose setup wizard." ;;
    binary_installed) printf 'netbird-relay binary installed: %s' "$1" ;;
    binary_wizard) printf '%s' "Starting binary setup wizard." ;;
  esac
}

select_language() {
  local value=""
  case "$RELS_LANG" in
    zh|en) export RELS_LANG; return 0 ;;
    "") ;;
    *) RELS_LANG="" ;;
  esac

  cat >&2 <<'EOF'
Select language / 选择语言:
  1. 中文
  2. English
EOF
  printf '%s' '请选择语言 / Select language [1]: ' >&2
  if [[ -r /dev/tty ]]; then
    IFS= read -r value </dev/tty || value=""
  else
    IFS= read -r value || value=""
  fi

  case "$value" in
    2|en|EN|english|English) RELS_LANG="en" ;;
    *) RELS_LANG="zh" ;;
  esac
  export RELS_LANG
}

run_as_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    fail "$(msg root_required)"
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
        fail "$(msg unknown_arg "$1")"
        ;;
    esac
    shift
  done

  case "$INSTALL_MODE" in
    ""|binary|compose) ;;
    *) fail "$(msg bad_install_mode)" ;;
  esac
}

validate_release_base() {
  case "$RELEASE_BASE" in
    https://github.com/kos991/net_relay/releases/latest/download|https://github.com/kos991/net_relay/releases/download/*)
      return 0
      ;;
    https://*)
      if [[ "$ALLOW_CUSTOM_RELEASE_BASE" == "1" ]]; then
        warn "$(msg custom_release_base "$RELEASE_BASE")"
        return 0
      fi
      ;;
  esac

  fail "$(msg bad_release_base)"
}

select_install_mode() {
  local value=""

  if [[ -n "$INSTALL_MODE" ]]; then
    return 0
  fi

  while true; do
    msg select_install_mode >&2
    printf '\n' >&2
    msg select_install_prompt >&2
    if [[ -r /dev/tty ]]; then
      IFS= read -r value </dev/tty || fail "$(msg read_install_mode_failed)"
    else
      IFS= read -r value || fail "$(msg read_install_mode_noninteractive)"
    fi

    case "$value" in
      ""|1)
        INSTALL_MODE="binary"
        return 0
        ;;
      2)
        INSTALL_MODE="compose"
        return 0
        ;;
      *)
        warn "$(msg enter_1_or_2)"
        ;;
    esac
  done
}

detect_os() {
  [[ -r /etc/os-release ]] || fail "$(msg os_missing)"

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
      fail "$(msg unsupported_os "${PRETTY_NAME:-${OS_ID}}")"
      ;;
  esac
}

enforce_install_mode_policy() {
  if [[ "$OS_FAMILY" != "alpine" ]]; then
    return 0
  fi

  if [[ "$INSTALL_MODE" == "compose" ]]; then
    fail "$(msg alpine_compose_disabled)"
  fi

  if [[ -z "$INSTALL_MODE" ]]; then
    INSTALL_MODE="binary"
    warn "$(msg alpine_binary_only)"
  fi
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
      fail "$(msg unsupported_arch "$machine")"
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
  esac

  if command -v systemctl >/dev/null 2>&1; then
    run_as_root systemctl enable --now docker
  elif command -v rc-update >/dev/null 2>&1; then
    run_as_root rc-update add docker default
    run_as_root service docker start
  fi

  docker compose version >/dev/null 2>&1 || fail "$(msg compose_unavailable)"
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

  log "$(msg downloading "$url")"
  if command -v curl >/dev/null 2>&1; then
    curl -fL --proto '=https' --proto-redir '=https' --tlsv1.2 --connect-timeout 10 --max-time 180 --retry 2 --retry-delay 2 "$url" -o "$output"
  elif command -v wget >/dev/null 2>&1; then
    if wget --help 2>&1 | grep -q -- '--https-only'; then
      wget --https-only --timeout=10 --tries=3 -O "$output" "$url"
    else
      wget --timeout=10 --tries=3 -O "$output" "$url"
    fi
  else
    fail "$(msg need_downloader)"
  fi
}

verify_sha256() {
  local package_file="$1"
  local sums_file="$2"
  local package_name
  package_name="$(basename "$package_file")"

  if command -v sha256sum >/dev/null 2>&1; then
    (cd "$(dirname "$package_file")" && awk -v n="$package_name" '$2==n{print; found=1} END{exit !found}' "$sums_file" | sha256sum -c -)
  elif command -v shasum >/dev/null 2>&1; then
    (cd "$(dirname "$package_file")" && awk -v n="$package_name" '$2==n{print; found=1} END{exit !found}' "$sums_file" | shasum -a 256 -c -)
  else
    warn "$(msg hash_missing_warn)"
  fi
}

verify_tar_paths() {
  local package_file="$1"
  local entry

  while IFS= read -r entry; do
    case "$entry" in
      ""|/*|../*|*/../*|*"/.."|*"/../"*|*":"*)
        fail "$(msg unsafe_path "$entry")"
        ;;
    esac
  done < <(tar -tzf "$package_file")
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

  verify_tar_paths "$package_file"
  tar -xzf "$package_file" -C "$tmp_dir"
  [[ -x "${tmp_dir}/netbird-relay/bin/netbird-relay" ]] || fail "$(msg missing_binary)"

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
  select_language
  detect_install_mode "$@"
  validate_release_base
  detect_os
  enforce_install_mode_policy
  install_base_dependencies
  ensure_scheduler
  install_installer_files
  select_install_mode

  if [[ "$INSTALL_MODE" == "compose" ]]; then
    install_compose_dependencies
    log "$(msg compose_wizard)"
    RELS_LANG="$RELS_LANG" DEPLOY_MODE=compose exec bash "$INSTALL_DIR/setup-relay.sh"
  fi

  local arch package_file tmp_dir
  arch="$(detect_arch)"
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT

  package_file="$(download_relay_package "$arch" "$tmp_dir")"
  install_relay_binary "$package_file"

  log "$(msg binary_installed "$BIN_PATH")"
  log "$(msg binary_wizard)"
  RELS_LANG="$RELS_LANG" DEPLOY_MODE=binary exec bash "$INSTALL_DIR/setup-relay.sh"
}

main "$@"
