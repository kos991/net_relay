#!/bin/sh
set -eu

DEFAULT_INSTALL_URL="https://rels.jinfei.org/install.sh"
INSTALL_URL="${INSTALL_URL:-$DEFAULT_INSTALL_URL}"
ALLOW_CUSTOM_INSTALL_URL="${ALLOW_CUSTOM_INSTALL_URL:-0}"

log() {
  printf '%s\n' "$*" >&2
}

fail() {
  log "$*"
  exit 1
}

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    fail "需要 root 权限安装 bash/curl。请使用 root 运行，或先安装 sudo 并授权当前用户。"
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
      fail "无法自动安装 bash/curl。支持 Debian/Ubuntu/Rocky/Alma/Alpine。"
      ;;
  esac
}

download_file() {
  url="$1"
  output="$2"

  log "正在下载安装入口：${url}"
  if command -v curl >/dev/null 2>&1; then
    curl -fL --proto '=https' --proto-redir '=https' --tlsv1.2 --connect-timeout 10 --max-time 120 --retry 2 --retry-delay 2 "$url" -o "$output"
  elif command -v wget >/dev/null 2>&1; then
    if wget --help 2>&1 | grep -q -- '--https-only'; then
      wget --https-only --timeout=10 --tries=3 -O "$output" "$url"
    else
      wget --timeout=10 --tries=3 -O "$output" "$url"
    fi
  else
    fail "需要安装 curl 或 wget 后再执行。"
  fi
}

validate_install_url() {
  case "$INSTALL_URL" in
    https://rels.jinfei.org/install.sh|https://github.com/kos991/net_relay/releases/latest/download/install.sh|https://github.com/kos991/net_relay/releases/download/*/install.sh)
      return 0
      ;;
    https://*)
      if [ "$ALLOW_CUSTOM_INSTALL_URL" = "1" ]; then
        log "警告：正在使用自定义 INSTALL_URL，请确认来源可信：$INSTALL_URL"
        return 0
      fi
      ;;
  esac

  fail "INSTALL_URL 必须是受信任的 HTTPS 地址。如确需自定义，请设置 ALLOW_CUSTOM_INSTALL_URL=1。"
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
    fail "需要 sha256sum 或 shasum 校验 install.sh。"
  fi

  [ "$actual_hash" = "$expected_hash" ] || fail "install.sh SHA256 校验失败。"
}

ensure_bootstrap_tools
validate_install_url

tmp_file="$(mktemp)"
tmp_sums="$(mktemp)"
trap 'rm -f "$tmp_file" "$tmp_sums"' 0 HUP INT TERM

download_file "$INSTALL_URL" "$tmp_file" || {
  log "下载失败：${INSTALL_URL}"
  log "请检查安装入口是否可访问，或临时设置 INSTALL_URL 为可访问的 install.sh 地址。"
  exit 1
}
download_file "$(dirname "$INSTALL_URL")/SHA256SUMS" "$tmp_sums"
verify_install_sha256 "$tmp_file" "$tmp_sums"

bash "$tmp_file"
