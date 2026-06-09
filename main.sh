#!/bin/sh
set -eu

DEFAULT_INSTALL_URL="https://rels.jinfei.org/install.sh"
INSTALL_URL="${INSTALL_URL:-$DEFAULT_INSTALL_URL}"
ALLOW_CUSTOM_INSTALL_URL="${ALLOW_CUSTOM_INSTALL_URL:-0}"
RELS_LANG="${RELS_LANG:-}"

log() {
  printf '%s\n' "$*" >&2
}

fail() {
  log "$*"
  exit 1
}

msg() {
  key="$1"
  case "${RELS_LANG:-en}:$key" in
    zh:root_required) printf '%s\n' "需要 root 权限安装 bash/curl。请使用 root 运行，或先安装 sudo 并授权当前用户。" ;;
    zh:unsupported_os) printf '%s\n' "无法自动安装 bash/curl。支持 Debian/Ubuntu/Rocky/Alma/Alpine。" ;;
    zh:downloading) printf '正在下载安装入口：%s\n' "$2" ;;
    zh:need_downloader) printf '%s\n' "需要安装 curl 或 wget 后再执行。" ;;
    zh:custom_url_warning) printf '警告：正在使用自定义 INSTALL_URL，请确认来源可信：%s\n' "$2" ;;
    zh:bad_url) printf '%s\n' "INSTALL_URL 必须是受信任的 HTTPS 地址。如确需自定义来源，请设置 ALLOW_CUSTOM_INSTALL_URL=1。" ;;
    zh:download_failed) printf '下载失败：%s\n' "$2" ;;
    zh:download_hint) printf '%s\n' "请检查安装入口是否可访问，或临时设置 INSTALL_URL 为可访问的 install.sh 地址。" ;;
    zh:hash_tool_required) printf '%s\n' "需要 sha256sum 或 shasum 来校验 install.sh。" ;;
    zh:hash_failed) printf '%s\n' "install.sh SHA256 校验失败。" ;;
    *) case "$key" in
      root_required) printf '%s\n' "Root privileges are required to install bash/curl. Run as root, or install sudo and grant access to the current user first." ;;
      unsupported_os) printf '%s\n' "Unable to install bash/curl automatically. Supported systems: Debian/Ubuntu/Rocky/Alma/Alpine." ;;
      downloading) printf 'Downloading installer entrypoint: %s\n' "$2" ;;
      need_downloader) printf '%s\n' "curl or wget must be installed before continuing." ;;
      custom_url_warning) printf 'Warning: using custom INSTALL_URL. Make sure the source is trusted: %s\n' "$2" ;;
      bad_url) printf '%s\n' "INSTALL_URL must be a trusted HTTPS URL. Set ALLOW_CUSTOM_INSTALL_URL=1 only if you really need a custom source." ;;
      download_failed) printf 'Download failed: %s\n' "$2" ;;
      download_hint) printf '%s\n' "Check whether the installer entrypoint is reachable, or temporarily set INSTALL_URL to a reachable install.sh URL." ;;
      hash_tool_required) printf '%s\n' "sha256sum or shasum is required to verify install.sh." ;;
      hash_failed) printf '%s\n' "install.sh SHA256 verification failed." ;;
    esac ;;
  esac
}

select_language() {
  value=""
  case "$RELS_LANG" in
    zh|en) return 0 ;;
    "") ;;
    *) RELS_LANG="" ;;
  esac

  cat >&2 <<'EOF'
Select language / 选择语言:
  1. 中文
  2. English
EOF
  printf '%s' '请选择语言 / Select language [1]: ' >&2
  if [ -r /dev/tty ]; then
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
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    fail "$(msg root_required)"
  fi
}

ensure_bootstrap_tools() {
  if command -v bash >/dev/null 2>&1 && { command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; }; then
    return 0
  fi

  if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
  fi

  case " ${ID:-} ${ID_LIKE:-} " in
    *" alpine "*)
      run_as_root apk add --no-cache bash curl ca-certificates
      ;;
    *" debian "*|*" ubuntu "*)
      run_as_root apt-get update
      run_as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y bash curl ca-certificates
      ;;
    *" rhel "*|*" fedora "*|*" rocky "*|*" almalinux "*|*" centos "*)
      if command -v dnf >/dev/null 2>&1; then
        run_as_root dnf install -y bash curl ca-certificates
      else
        run_as_root yum install -y bash curl ca-certificates
      fi
      ;;
    *)
      fail "$(msg unsupported_os)"
      ;;
  esac
}

download_file() {
  url="$1"
  output="$2"

  log "$(msg downloading "$url")"
  if command -v curl >/dev/null 2>&1; then
    curl -fL --proto '=https' --proto-redir '=https' --tlsv1.2 --connect-timeout 10 --max-time 120 --retry 2 --retry-delay 2 "$url" -o "$output"
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

validate_install_url() {
  case "$INSTALL_URL" in
    https://rels.jinfei.org/install.sh|https://github.com/kos991/net_relay/releases/latest/download/install.sh|https://github.com/kos991/net_relay/releases/download/*/install.sh)
      return 0
      ;;
    https://*)
      if [ "$ALLOW_CUSTOM_INSTALL_URL" = "1" ]; then
        log "$(msg custom_url_warning "$INSTALL_URL")"
        return 0
      fi
      ;;
  esac

  fail "$(msg bad_url)"
}

verify_install_sha256() {
  script_file="$1"
  sums_file="$2"
  expected_hash=""
  actual_hash=""

  if command -v sha256sum >/dev/null 2>&1; then
    expected_hash="$(awk '$2=="install.sh"{print $1; found=1} END{exit !found}' "$sums_file")"
    actual_hash="$(sha256sum "$script_file" | awk '{print $1}')"
  elif command -v shasum >/dev/null 2>&1; then
    expected_hash="$(awk '$2=="install.sh"{print $1; found=1} END{exit !found}' "$sums_file")"
    actual_hash="$(shasum -a 256 "$script_file" | awk '{print $1}')"
  else
    fail "$(msg hash_tool_required)"
  fi

  [ "$actual_hash" = "$expected_hash" ] || fail "$(msg hash_failed)"
}

select_language
ensure_bootstrap_tools
validate_install_url

tmp_file="$(mktemp)"
tmp_sums="$(mktemp)"
trap 'rm -f "$tmp_file" "$tmp_sums"' 0 HUP INT TERM

download_file "$INSTALL_URL" "$tmp_file" || {
  log "$(msg download_failed "$INSTALL_URL")"
  log "$(msg download_hint)"
  exit 1
}
download_file "$(dirname "$INSTALL_URL")/SHA256SUMS" "$tmp_sums"
verify_install_sha256 "$tmp_file" "$tmp_sums"

bash "$tmp_file"
