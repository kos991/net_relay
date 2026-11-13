#!/usr/bin/env bash
set -euo pipefail

DEFAULT_RELEASE_BASE="https://rels.jinfei.org/download"
RELEASE_BASE="${RELEASE_BASE:-$DEFAULT_RELEASE_BASE}"
ALLOW_CUSTOM_RELEASE_BASE="${ALLOW_CUSTOM_RELEASE_BASE:-0}"
INSTALL_DIR="${INSTALL_DIR:-/opt/netbird-relay-installer}"
BIN_PATH="${BIN_PATH:-/usr/local/bin/netbird-relay}"
CONFIG_DIR="${CONFIG_DIR:-/etc/netbird-relay}"
RELS_LANG="${RELS_LANG:-}"
FORCE_UPDATE_SCRIPTS="${FORCE_UPDATE_SCRIPTS:-0}"
CERT_RELOAD_PATH="${CERT_RELOAD_PATH:-/usr/local/libexec/netbird-relay/reload-relay-certificate.sh}"
RELS_PATH="${RELS_PATH:-/usr/local/sbin/rels}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

OS_ID=""
OS_ID_LIKE=""
OS_VERSION_CODENAME=""
OS_FAMILY=""

log() {
  echo -e "${GREEN}$*${NC}" >&2
}

warn() {
  echo -e "${YELLOW}$*${NC}" >&2
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
      compose_removed) printf '%s' "Docker/Compose 安装模式已移除，请使用二进制安装。" ;;
      custom_release_base) printf '正在使用自定义 RELEASE_BASE，请确认来源可信：%s' "$1" ;;
      bad_release_base) printf '%s' "RELEASE_BASE 必须是受信任的 HTTPS 地址。如确需自定义来源，请设置 ALLOW_CUSTOM_RELEASE_BASE=1。" ;;
      os_missing) printf '%s' "无法检测系统：缺少 /etc/os-release。支持 Debian/Ubuntu/Rocky/Alma/Alpine。" ;;
      unsupported_os) printf '不支持的系统：%s。支持 Debian/Ubuntu/Rocky/Alma/Alpine。' "$1" ;;
      unsupported_arch) printf '不支持的 CPU 架构：%s。支持 amd64/arm64。' "$1" ;;
      downloading) printf '正在下载：%s' "$1" ;;
      need_downloader) printf '%s' "需要 curl 或 wget。" ;;
      hash_missing_warn) printf '%s' "未找到 sha256sum/shasum，跳过 SHA256 校验。" ;;
      unsafe_path) printf '安装包包含不安全路径：%s' "$1" ;;
      missing_binary) printf '%s' "安装包缺少 netbird-relay 二进制文件。" ;;
      binary_installed) printf 'netbird-relay 二进制已安装：%s' "$1" ;;
      binary_wizard) printf '%s' "启动二进制配置向导。" ;;
    esac
    return 0
  fi

  case "$key" in
    root_required) printf '%s' "Root privileges are required. Run as root, or install and configure sudo first." ;;
    unknown_arg) printf 'Unknown argument: %s' "$1" ;;
    compose_removed) printf '%s' "Docker/Compose install mode has been removed; use the binary installer." ;;
    custom_release_base) printf 'Using custom RELEASE_BASE. Make sure the source is trusted: %s' "$1" ;;
    bad_release_base) printf '%s' "RELEASE_BASE must be a trusted HTTPS URL. Set ALLOW_CUSTOM_RELEASE_BASE=1 only if you really need a custom source." ;;
    os_missing) printf '%s' "Unable to detect OS: /etc/os-release is missing. Supported systems: Debian/Ubuntu/Rocky/Alma/Alpine." ;;
    unsupported_os) printf 'Unsupported OS: %s. Supported systems: Debian/Ubuntu/Rocky/Alma/Alpine.' "$1" ;;
    unsupported_arch) printf 'Unsupported CPU architecture: %s. Supported architectures: amd64/arm64.' "$1" ;;
    downloading) printf 'Downloading: %s' "$1" ;;
    need_downloader) printf '%s' "curl or wget is required." ;;
    hash_missing_warn) printf '%s' "sha256sum/shasum was not found; skipping SHA256 verification." ;;
    unsafe_path) printf 'Package contains an unsafe path: %s' "$1" ;;
    missing_binary) printf '%s' "Package is missing the netbird-relay binary." ;;
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



validate_release_base() {
  case "$RELEASE_BASE" in
    https://rels.jinfei.org/download|https://github.com/kos991/net_relay/releases/latest/download|https://github.com/kos991/net_relay/releases/download/*)
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
  local package_name="${3:-$(basename "$package_file")}"
  local expected_hash=""
  local actual_hash=""

  expected_hash="$(awk -v n="$package_name" '$2==n{print $1; found=1} END{exit !found}' "$sums_file")" || \
    fail "SHA256 entry was not found for ${package_name}."

  if command -v sha256sum >/dev/null 2>&1; then
    actual_hash="$(sha256sum "$package_file" | awk '{print $1}')"
  elif command -v shasum >/dev/null 2>&1; then
    actual_hash="$(shasum -a 256 "$package_file" | awk '{print $1}')"
  else
    fail "SHA256 verification requires sha256sum or shasum."
  fi

  [[ "$actual_hash" == "$expected_hash" ]] || fail "SHA256 verification failed for ${package_name}."
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
  local binary_tmp_dir
  binary_tmp_dir="$(mktemp -d)"
  trap "rm -rf -- '$binary_tmp_dir'" RETURN

  verify_tar_paths "$package_file"
  tar -xzf "$package_file" -C "$binary_tmp_dir"
  [[ -x "${binary_tmp_dir}/netbird-relay/bin/netbird-relay" ]] || fail "$(msg missing_binary)"

  run_as_root install -m 0755 -D "${binary_tmp_dir}/netbird-relay/bin/netbird-relay" "$BIN_PATH"
  run_as_root install -m 0644 -D "${binary_tmp_dir}/netbird-relay/services/netbird-relay.service" /etc/systemd/system/netbird-relay.service
  run_as_root install -m 0755 -D "${binary_tmp_dir}/netbird-relay/services/netbird-relay.openrc" /etc/init.d/netbird-relay
}

install_installer_asset() (
  local source_file="$1"
  local release_name="$2"
  local destination="$3"
  local sums_file="$4"
  local mode="$5"
  local stage=""
  local downloaded_file=""
  trap 'rm -f -- "${downloaded_file:-}"; [[ -z "$stage" ]] || run_as_root rm -rf -- "$stage"' EXIT

  if [[ -f "$source_file" && "$FORCE_UPDATE_SCRIPTS" != "1" ]]; then
    if [[ "$source_file" == "$destination" ]]; then
      return 0
    fi
  else
    downloaded_file="$(mktemp)"
    download_file "${RELEASE_BASE}/${release_name}" "$downloaded_file"
    verify_sha256 "$downloaded_file" "$sums_file" "$release_name"
    source_file="$downloaded_file"
  fi
  run_as_root mkdir -p -- "$(dirname "$destination")"
  stage="$(run_as_root mktemp -d "$(dirname "$destination")/.rels-install.XXXXXX")"
  run_as_root install -m "$mode" "$source_file" "$stage/new"
  run_as_root mv -f -- "$stage/new" "$destination"
)

install_installer_files() {
  local sums_file="$1"
  local source_file="${BASH_SOURCE[0]}"
  local source_dir
  source_dir="$(cd "$(dirname "$source_file")" && pwd)"

  run_as_root mkdir -p "$INSTALL_DIR" "$CONFIG_DIR"
  install_installer_asset "$source_dir/setup-relay.sh" setup-relay.sh "$INSTALL_DIR/setup-relay.sh" "$sums_file" 0755
  install_installer_asset "$source_dir/reload-relay-certificate.sh" reload-relay-certificate.sh /usr/local/libexec/netbird-relay/reload-relay-certificate.sh "$sums_file" 0755
  install_installer_asset "$source_file" install.sh "$INSTALL_DIR/install.sh" "$sums_file" 0755
}

update_scripts_only() (
  # Subshell keeps cleanup traps and temporary paths alive through every failure.
  set -e
  tmp_dir="$(mktemp -d)"
  local -a names=(install.sh setup-relay.sh reload-relay-certificate.sh rels)
  local -a destinations=("$INSTALL_DIR/install.sh" "$INSTALL_DIR/setup-relay.sh" "$CERT_RELOAD_PATH" "$RELS_PATH")
  local -a stages=() existed=()
  local i committed=0 complete=0
  cleanup_update() {
    local status=$? j
    trap - EXIT
    if [[ "$complete" != 1 ]]; then
      for ((j=committed-1; j>=0; j--)); do
        if [[ "${existed[j]}" == 1 ]]; then
          if ! run_as_root mv -f -- "${stages[j]}/old" "${destinations[j]}"; then
            warn "Rollback failed; original retained at ${stages[j]}/old"
            stages[j]=""
            status=1
          fi
        else
          run_as_root rm -f -- "${destinations[j]}" || status=1
        fi
      done
    fi
    for j in "${stages[@]}"; do
      [[ -z "$j" ]] || run_as_root rm -rf -- "$j"
    done
    rm -rf -- "$tmp_dir"
    exit "$status"
  }
  trap cleanup_update EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  download_file "${RELEASE_BASE}/SHA256SUMS" "$tmp_dir/SHA256SUMS"
  for i in "${!names[@]}"; do
    download_file "${RELEASE_BASE}/${names[i]}" "$tmp_dir/${names[i]}"
    verify_sha256 "$tmp_dir/${names[i]}" "$tmp_dir/SHA256SUMS" "${names[i]}"
    bash -n "$tmp_dir/${names[i]}"
  done
  # Stage every replacement beside its destination before touching any live file.
  for i in "${!names[@]}"; do
    run_as_root mkdir -p -- "$(dirname "${destinations[i]}")"
    stages[i]="$(run_as_root mktemp -d "$(dirname "${destinations[i]}")/.rels-update.XXXXXX")"
    existed[i]=0
    if [[ -e "${destinations[i]}" || -L "${destinations[i]}" ]]; then
      [[ ! -d "${destinations[i]}" ]] || fail "Script destination is a directory: ${destinations[i]}"
      run_as_root cp -pP -- "${destinations[i]}" "${stages[i]}/old"
      existed[i]=1
    fi
    run_as_root install -m 0755 "$tmp_dir/${names[i]}" "${stages[i]}/new"
  done
  for i in "${!names[@]}"; do
    committed=$((i+1))
    run_as_root mv -f -- "${stages[i]}/new" "${destinations[i]}"
  done
  complete=1
  log "Scripts updated successfully (including rels); no configuration wizard was started."
)

main() {
  local scripts_only=0
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --scripts-only|--update-scripts-only)
        scripts_only=1
        shift
        ;;
      --binary)
        shift
        ;;
      --compose|--docker-compose)
        fail "$(msg compose_removed)"
        ;;
      *)
        fail "$(msg unknown_arg "$1")"
        ;;
    esac
  done

  if [[ "$scripts_only" == "1" ]]; then
    RELS_LANG="${RELS_LANG:-en}"
  else
    select_language
  fi
  validate_release_base

  if [[ "$scripts_only" == "1" ]]; then
    update_scripts_only
    return 0
  fi

  detect_os
  install_base_dependencies
  ensure_scheduler

  local arch package_file tmp_dir
  arch="$(detect_arch)"
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf -- "${tmp_dir:-}"' EXIT

  package_file="$(download_relay_package "$arch" "$tmp_dir")"
  install_relay_binary "$package_file"
  install_installer_files "$tmp_dir/SHA256SUMS"

  log "$(msg binary_installed "$BIN_PATH")"
  log "$(msg binary_wizard)"
  RELS_LANG="$RELS_LANG" exec bash "$INSTALL_DIR/setup-relay.sh"
}

main "$@"
