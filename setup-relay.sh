#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-/etc/netbird-relay}"
ENV_FILE="${ENV_FILE:-${CONFIG_DIR}/relay.env}"
CERT_DIR="${CERT_DIR:-${CONFIG_DIR}/certs}"
BIN_PATH="${BIN_PATH:-/usr/local/bin/netbird-relay}"

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

run_as_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    fail "需要 root 权限执行：$*。"
  fi
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

read_input() {
  local prompt="$1"
  local value=""

  printf '%s' "$prompt" >&2
  if [[ -r /dev/tty ]]; then
    IFS= read -r value </dev/tty || fail "无法从终端读取输入。"
  else
    IFS= read -r value || fail "无法读取输入，请在交互式终端中运行。"
  fi

  trim "$value"
}

read_secret() {
  local prompt="$1"
  local value=""

  printf '%s' "$prompt" >&2
  if [[ -r /dev/tty ]]; then
    IFS= read -r -s value </dev/tty || fail "无法从终端读取输入。"
  else
    IFS= read -r -s value || fail "无法读取输入，请在交互式终端中运行。"
  fi
  printf '\n' >&2

  trim "$value"
}

prompt_nonempty() {
  local prompt="$1"
  local value=""
  while [[ -z "$value" ]]; do
    value="$(read_input "$prompt")"
  done
  printf '%s' "$value"
}

prompt_default() {
  local prompt="$1"
  local default="$2"
  local value
  value="$(read_input "$prompt")"
  if [[ -z "$value" ]]; then
    value="$default"
  fi
  printf '%s' "$value"
}

select_relay_group_mode() {
  local value=""

  while true; do
    cat >&2 <<'EOF'
部署模式：
  1. 创建新的 Relay 节点组
  2. 加入已有 Relay 节点组
EOF
    value="$(read_input '请选择部署模式 [1]: ')"
    if [[ -z "$value" || "$value" == "1" ]]; then
      printf 'create'
      return 0
    fi
    if [[ "$value" == "2" ]]; then
      printf 'join'
      return 0
    fi
    warn "请输入 1 或 2。"
  done
}

read_relay_auth_secret() {
  if [[ "$RELAY_GROUP_MODE" == "join" ]]; then
    read_secret '已有节点组 secret（必填）：'
  else
    read_secret '认证密钥 secret（可留空自动生成；多节点请保存并复用）：'
  fi
}

validate_port() {
  local port="$1"
  [[ "$port" =~ ^[0-9]+$ ]] || return 1
  (( port >= 1 && port <= 65535 ))
}

generate_secret() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 32 | tr -d '\n'
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import secrets; print(secrets.token_urlsafe(32))'
  else
    fail "需要 openssl 或 python3 才能自动生成认证密钥。"
  fi
}

ensure_certificate() {
  local domain="$1"
  local cert_file="$2"
  local key_file="$3"

  if [[ -s "$cert_file" && -s "$key_file" ]]; then
    return 0
  fi

  warn "未找到 TLS 证书，自动生成本地自签证书：${cert_file}"
  run_as_root mkdir -p "$(dirname "$cert_file")"
  run_as_root openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
    -keyout "$key_file" \
    -out "$cert_file" \
    -subj "/CN=${domain}" \
    -addext "subjectAltName=DNS:${domain}"
}

write_env_file() {
  local tmp_file
  tmp_file="$(mktemp)"

  cat > "$tmp_file" <<EOF
NB_LOG_LEVEL=info
NB_LOG_FILE=console
NB_LISTEN_ADDRESS=:${RELAY_PORT}
NB_EXPOSED_ADDRESS=rels://${RELAY_DOMAIN}:${RELAY_PORT}
NB_AUTH_SECRET=${RELAY_AUTH_SECRET}
NB_ENABLE_STUN=true
NB_STUN_PORTS=${STUN_PORT}
NB_TLS_CERT_FILE=${TLS_CERT_FILE}
NB_TLS_KEY_FILE=${TLS_KEY_FILE}
EOF

  run_as_root mkdir -p "$CONFIG_DIR"
  run_as_root install -m 0600 "$tmp_file" "$ENV_FILE"
  rm -f "$tmp_file"
}

restart_service() {
  if command -v systemctl >/dev/null 2>&1; then
    run_as_root systemctl daemon-reload
    run_as_root systemctl enable --now netbird-relay
    run_as_root systemctl restart netbird-relay
  elif command -v rc-update >/dev/null 2>&1; then
    run_as_root rc-update add netbird-relay default
    run_as_root service netbird-relay restart
  else
    fail "未找到 systemd 或 OpenRC，无法启动 netbird-relay 服务。"
  fi
}

print_header() {
  echo -e "${GREEN}=================================================${NC}"
  echo -e "${GREEN}              NetBird Relay 安装向导             ${NC}"
  echo -e "${GREEN}              官方源码编译二进制版               ${NC}"
  echo -e "${GREEN}=================================================${NC}"
  echo "说明：如需多 Relay 节点，请在每台节点输入同一个认证密钥。"
  echo
}

print_summary() {
  local mode_label="创建新的 Relay 节点组"
  if [[ "$RELAY_GROUP_MODE" == "join" ]]; then
    mode_label="加入已有 Relay 节点组"
  fi

  cat <<EOF

==================== 安装完成 ====================
当前节点组模式：${mode_label}
Relay 二进制：${BIN_PATH}
Relay 配置：${ENV_FILE}
Relay 地址：rels://${RELAY_DOMAIN}:${RELAY_PORT}
STUN 地址： stun:${RELAY_DOMAIN}:${STUN_PORT}
认证密钥：  ${RELAY_AUTH_SECRET}
TLS 证书：  ${TLS_CERT_FILE}
TLS 私钥：  ${TLS_KEY_FILE}

把下面配置合并到 NetBird Management 的 config.yaml：
server:
  relays:
    addresses:
      - "rels://${RELAY_DOMAIN}:${RELAY_PORT}"
    secret: "${RELAY_AUTH_SECRET}"
  stuns:
    - uri: "stun:${RELAY_DOMAIN}:${STUN_PORT}"
      proto: udp

如果这是追加节点，请把下面地址追加到现有 NetBird Management config.yaml：
relays.addresses:
  - "rels://${RELAY_DOMAIN}:${RELAY_PORT}"

常用命令：
  systemctl status netbird-relay
  journalctl -u netbird-relay -f
  service netbird-relay status
EOF
}

[[ -x "$BIN_PATH" ]] || fail "未找到 netbird-relay 二进制：${BIN_PATH}"

print_header

RELAY_GROUP_MODE="$(select_relay_group_mode)"
RELAY_DOMAIN="$(prompt_nonempty 'Relay 域名，例如 rels.example.com：')"
RELAY_PORT="$(prompt_default 'Relay TCP 端口 [8443]：' '8443')"
STUN_PORT="$(prompt_default 'STUN UDP 端口 [3478]：' '3478')"
TLS_CERT_FILE="$(prompt_default "TLS 证书路径 [${CERT_DIR}/fullchain.pem]：" "${CERT_DIR}/fullchain.pem")"
TLS_KEY_FILE="$(prompt_default "TLS 私钥路径 [${CERT_DIR}/privkey.pem]：" "${CERT_DIR}/privkey.pem")"
RELAY_AUTH_SECRET="$(read_relay_auth_secret)"

validate_port "$RELAY_PORT" || fail "Relay 端口无效：${RELAY_PORT}"
validate_port "$STUN_PORT" || fail "STUN 端口无效：${STUN_PORT}"

if [[ "$RELAY_GROUP_MODE" == "join" && -z "$RELAY_AUTH_SECRET" ]]; then
  fail "must provide an existing relay auth secret when joining a relay node group."
fi

if [[ -z "$RELAY_AUTH_SECRET" ]]; then
  RELAY_AUTH_SECRET="$(generate_secret)"
  log "已自动生成认证密钥。请保存这个 secret，后续 Relay 节点和 Management 必须使用同一个值。"
fi

ensure_certificate "$RELAY_DOMAIN" "$TLS_CERT_FILE" "$TLS_KEY_FILE"
write_env_file
restart_service
print_summary
