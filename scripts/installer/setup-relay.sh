#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-/etc/netbird-relay}"
ENV_FILE="${ENV_FILE:-${CONFIG_DIR}/relay.env}"
CERT_DIR="${CERT_DIR:-${CONFIG_DIR}/certs}"
BIN_PATH="${BIN_PATH:-/usr/local/bin/netbird-relay}"
CERT_RELOAD_HOOK="${CERT_RELOAD_HOOK:-/usr/local/libexec/netbird-relay/reload-relay-certificate.sh}"
ACME_HOME="${ACME_HOME:-/root/.acme.sh}"
SERVICE_USER="${SERVICE_USER:-netbird-relay}"
SERVICE_GROUP="${SERVICE_GROUP:-netbird-relay}"
RELS_LANG="${RELS_LANG:-en}"

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

is_zh() {
  [[ "${RELS_LANG:-en}" == "zh" ]]
}

msg() {
  local key="$1"
  shift || true
  if is_zh; then
    case "$key" in
      root_required) printf '%s' "运行此配置需要 root 权限，请使用 root 或 sudo。" ;;
      unable_read_terminal) printf '%s' "无法从终端读取输入，请在交互式终端中运行。" ;;
      wizard_title) printf '%s' "NetBird Relay 配置向导" ;;
      deployment_mode) printf '%s' "部署模式：二进制" ;;
      shared_secret_note) printf '%s' "同一 Relay 节点组中的所有节点必须使用相同的密钥。" ;;
      cloudflare_note) printf '%s' "Cloudflare 模式使用 acme.sh DNS 验证，并通过 reloadcmd 同步续期证书。" ;;
      relay_group_mode_title) printf '%s' "Relay 节点组模式：" ;;
      relay_group_create) printf '%s' "创建新的 Relay 节点组" ;;
      relay_group_join) printf '%s' "加入已有的 Relay 节点组" ;;
      select_group_mode) printf '%s' "选择节点组模式 [1]：" ;;
      invalid_group_mode) printf '%s' "请输入 1 或 2。" ;;
      existing_secret) printf '%s' "已有节点组密钥（必填）：" ;;
      new_secret) printf '%s' "Relay 身份验证密钥（留空则自动生成；多节点组请保存并复用）：" ;;
      openssl_required) printf '%s' "生成 Relay 身份验证密钥需要 openssl 或 python3。" ;;
      tls_mode_title) printf '%s' "TLS 证书模式：" ;;
      tls_cloudflare) printf '%s' "Cloudflare DNS + acme.sh 自动签发（推荐）" ;;
      tls_existing) printf '%s' "使用已有证书路径" ;;
      tls_selfsigned) printf '%s' "生成本地自签名证书" ;;
      select_cert_mode) printf '%s' "请选择证书模式 [1]：" ;;
      invalid_cert_mode) printf '%s' "请输入 1、2 或 3。" ;;
      relay_domain) printf '%s' "Relay 域名，例如 rels.example.com：" ;;
      relay_port) printf '%s' "Relay TCP 端口 [8443]：" ;;
      stun_port) printf '%s' "STUN UDP 端口 [3478]：" ;;
      cert_path) printf 'TLS 证书路径 [%s]：' "$1" ;;
      key_path) printf 'TLS 私钥路径 [%s]：' "$1" ;;
      acme_email) printf '%s' "ACME 邮箱：" ;;
      cf_api_token) printf '%s' "Cloudflare API Token：" ;;
      acme_installing) printf '%s' "正在安装 acme.sh..." ;;
      acme_failed) printf '%s' "acme.sh 安装失败。" ;;
      acme_email_empty) printf '%s' "ACME 邮箱不能为空。" ;;
      cf_token_empty) printf '%s' "Cloudflare API Token 不能为空。" ;;
      invalid_existing_cert) printf '已有证书路径无效：%s / %s' "$1" "$2" ;;
      generating_selfsigned) printf '正在生成本地自签名证书：%s' "$1" ;;
      service_required) printf '%s' "启动 netbird-relay 需要 systemd 或 OpenRC。" ;;
      missing_binary) printf '未找到 netbird-relay 二进制文件：%s' "$1" ;;
      missing_hook) printf '未找到证书重新加载脚本：%s' "$1" ;;
      invalid_port) printf 'Relay 端口无效：%s' "$1" ;;
      invalid_stun_port) printf 'STUN 端口无效：%s' "$1" ;;
      relay_port_min) printf '%s' "Relay 端口必须不小于 1024，因为服务不以 root 身份运行。" ;;
      same_udp_port) printf '%s' "Relay 和 STUN 不能使用相同的 UDP 端口。" ;;
      reserved_port) printf '%s' "Relay 端口 9000 和 9090 已被本地健康检查和指标端点占用。" ;;
      join_secret_required) printf '%s' "加入已有 Relay 节点组必须提供已有密钥。" ;;
      secret_generated) printf '%s' "Relay 身份验证密钥已自动生成。请保存它；所有节点和 Management 必须使用相同的值。" ;;
      summary_title) printf '%s' "配置完成" ;;
      group_create_label) printf '%s' "创建新的 Relay 节点组" ;;
      group_join_label) printf '%s' "加入已有的 Relay 节点组" ;;
      summary_deployment) printf '%s' "部署模式：二进制" ;;
      summary_group) printf 'Relay 节点组模式：%s' "$1" ;;
      summary_binary) printf 'Relay 二进制文件：%s' "$1" ;;
      summary_env) printf 'Relay 环境文件：%s' "$1" ;;
      summary_relay_address) printf 'Relay 地址：rels://%s:%s' "$1" "$2" ;;
      summary_stun_address) printf 'STUN 地址：stun:%s:%s' "$1" "$2" ;;
      summary_secret) printf 'Relay 身份验证密钥：%s（完整值已写入 %s）' "$1" "$2" ;;
      summary_cert) printf 'TLS 证书：%s' "$1" ;;
      summary_key) printf 'TLS 私钥：%s' "$1" ;;
      summary_cert_mode) printf '证书模式：%s' "$1" ;;
      summary_renewal) printf '%s' "证书续期：Cloudflare 模式使用 acme.sh cron 和 reloadcmd。" ;;
      management_config) printf '%s' "合并到 NetBird Management 的 config.yaml：" ;;
      additional_node) printf '%s' "如果这是附加节点，请追加：" ;;
      common_commands) printf '%s' "常用命令：" ;;
      mode_create_summary) printf '%s' "创建新的 Relay 节点组" ;;
      mode_join_summary) printf '%s' "加入已有的 Relay 节点组" ;;
      cert_mode_cloudflare_summary) printf '%s' "Cloudflare DNS + acme.sh 自动签发" ;;
      cert_mode_existing_summary) printf '%s' "使用已有证书路径" ;;
      cert_mode_selfsigned_summary) printf '%s' "本地自签名证书" ;;
    esac
    return 0
  fi

  case "$key" in
    root_required) printf '%s' "Root privileges are required to run this setup. Run as root or use sudo." ;;
    unable_read_terminal) printf '%s' "Unable to read input. Please run in an interactive terminal." ;;
    wizard_title) printf '%s' "NetBird Relay Setup Wizard" ;;
    deployment_mode) printf '%s' "Deployment mode: binary" ;;
    shared_secret_note) printf '%s' "All nodes in the same Relay node group must use the same secret." ;;
    cloudflare_note) printf '%s' "Cloudflare mode uses acme.sh DNS validation and reloadcmd for renewal sync." ;;
    relay_group_mode_title) printf '%s' "Relay node group mode:" ;;
    relay_group_create) printf '%s' "Create a new Relay node group" ;;
    relay_group_join) printf '%s' "Join an existing Relay node group" ;;
    select_group_mode) printf '%s' "Select node group mode [1]:" ;;
    invalid_group_mode) printf '%s' "Please enter 1 or 2." ;;
    existing_secret) printf '%s' "Existing node group secret (required):" ;;
    new_secret) printf '%s' "Relay auth secret (leave empty to generate; save and reuse for multi-node groups):" ;;
    openssl_required) printf '%s' "openssl or python3 is required to generate the Relay auth secret." ;;
    tls_mode_title) printf '%s' "TLS certificate mode:" ;;
    tls_cloudflare) printf '%s' "Cloudflare DNS + acme.sh automatic issuance (recommended)" ;;
    tls_existing) printf '%s' "Use existing certificate paths" ;;
    tls_selfsigned) printf '%s' "Generate a local self-signed certificate" ;;
    select_cert_mode) printf '%s' "Select certificate mode [1]:" ;;
    invalid_cert_mode) printf '%s' "Please enter 1, 2, or 3." ;;
    relay_domain) printf '%s' "Relay domain, for example rels.example.com:" ;;
    relay_port) printf '%s' "Relay TCP port [8443]:" ;;
    stun_port) printf '%s' "STUN UDP port [3478]:" ;;
    cert_path) printf 'TLS certificate path [%s]:' "$1" ;;
    key_path) printf 'TLS private key path [%s]:' "$1" ;;
    acme_email) printf '%s' "ACME email:" ;;
    cf_api_token) printf '%s' "Cloudflare API Token:" ;;
    acme_installing) printf '%s' "Installing acme.sh..." ;;
    acme_failed) printf '%s' "acme.sh installation failed." ;;
    acme_email_empty) printf '%s' "ACME email must not be empty." ;;
    cf_token_empty) printf '%s' "Cloudflare API Token must not be empty." ;;
    invalid_existing_cert) printf 'Existing certificate paths are invalid: %s / %s' "$1" "$2" ;;
    generating_selfsigned) printf 'Generating local self-signed certificate: %s' "$1" ;;
    service_required) printf '%s' "systemd or OpenRC is required to start netbird-relay." ;;
    missing_binary) printf 'netbird-relay binary was not found: %s' "$1" ;;
    missing_hook) printf 'certificate reload hook was not found: %s' "$1" ;;
    invalid_port) printf 'Invalid Relay port: %s' "$1" ;;
    invalid_stun_port) printf 'Invalid STUN port: %s' "$1" ;;
    relay_port_min) printf '%s' "Relay port must be 1024 or higher because the service runs without root privileges." ;;
    same_udp_port) printf '%s' "Relay and STUN cannot share the same UDP port." ;;
    reserved_port) printf '%s' "Relay port 9000 and 9090 are reserved for local health and metrics endpoints." ;;
    join_secret_required) printf '%s' "Joining an existing Relay node group requires an existing secret." ;;
    secret_generated) printf '%s' "Relay auth secret was generated automatically. Save it; all nodes and Management must use the same value." ;;
    summary_title) printf '%s' "Setup completed" ;;
    group_create_label) printf '%s' "create a new relay node group" ;;
    group_join_label) printf '%s' "join an existing relay node group" ;;
    summary_deployment) printf '%s' "Deployment mode: binary" ;;
    summary_group) printf 'Relay node group mode: %s' "$1" ;;
    summary_binary) printf 'Relay binary: %s' "$1" ;;
    summary_env) printf 'Relay environment file: %s' "$1" ;;
    summary_relay_address) printf 'Relay address: rels://%s:%s' "$1" "$2" ;;
    summary_stun_address) printf 'STUN address: stun:%s:%s' "$1" "$2" ;;
    summary_secret) printf 'Relay auth secret: %s (full value was written to %s)' "$1" "$2" ;;
    summary_cert) printf 'TLS certificate: %s' "$1" ;;
    summary_key) printf 'TLS private key: %s' "$1" ;;
    summary_cert_mode) printf 'Certificate mode: %s' "$1" ;;
    summary_renewal) printf '%s' "Certificate renewal: Cloudflare mode uses acme.sh cron and reloadcmd." ;;
    management_config) printf '%s' "Merge into NetBird Management config.yaml:" ;;
    additional_node) printf '%s' "If this is an additional node, append:" ;;
    common_commands) printf '%s' "Common commands:" ;;
    mode_create_summary) printf '%s' "create a new relay node group" ;;
    mode_join_summary) printf '%s' "join an existing relay node group" ;;
    cert_mode_cloudflare_summary) printf '%s' "Cloudflare DNS + acme.sh automatic issuance" ;;
    cert_mode_existing_summary) printf '%s' "use existing certificate paths" ;;
    cert_mode_selfsigned_summary) printf '%s' "local self-signed certificate" ;;
  esac
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
    IFS= read -r value </dev/tty || fail "$(msg unable_read_terminal)"
  else
    IFS= read -r value || fail "$(msg unable_read_terminal)"
  fi
  trim "$value"
}

read_secret() {
  local prompt="$1"
  local value=""
  printf '%s' "$prompt" >&2
  if [[ -r /dev/tty ]]; then
    IFS= read -r -s value </dev/tty || fail "$(msg unable_read_terminal)"
  else
    IFS= read -r -s value || fail "$(msg unable_read_terminal)"
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
    {
      printf '%s\n' "$(msg relay_group_mode_title)"
      printf '  1. %s\n' "$(msg relay_group_create)"
      printf '  2. %s\n' "$(msg relay_group_join)"
    } >&2
    value="$(read_input "$(msg select_group_mode) ")"
    if [[ -z "$value" || "$value" == "1" ]]; then
      printf 'create'
      return 0
    fi
    if [[ "$value" == "2" ]]; then
      printf 'join'
      return 0
    fi
    warn "$(msg invalid_group_mode)"
  done
}

read_relay_auth_secret() {
  if [[ "$RELAY_GROUP_MODE" == "join" ]]; then
    read_secret "$(msg existing_secret) "
  else
    read_secret "$(msg new_secret) "
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
    fail "$(msg openssl_required)"
  fi
}

mask_secret() {
  local secret="$1"
  if [[ "${#secret}" -le 8 ]]; then
    printf '********'
    return 0
  fi
  printf '%s...%s' "${secret:0:4}" "${secret: -4}"
}

ensure_service_user() {
  if ! getent group "$SERVICE_GROUP" >/dev/null 2>&1; then
    if command -v groupadd >/dev/null 2>&1; then
      run_as_root groupadd --system "$SERVICE_GROUP"
    elif command -v addgroup >/dev/null 2>&1; then
      run_as_root addgroup -S "$SERVICE_GROUP"
    else
      fail "Unable to create service group: ${SERVICE_GROUP}"
    fi
  fi

  if ! id "$SERVICE_USER" >/dev/null 2>&1; then
    if command -v useradd >/dev/null 2>&1; then
      run_as_root useradd --system --no-create-home --home-dir /nonexistent --shell /usr/sbin/nologin --gid "$SERVICE_GROUP" "$SERVICE_USER"
    elif command -v adduser >/dev/null 2>&1; then
      run_as_root adduser -S -D -H -h /nonexistent -s /sbin/nologin -G "$SERVICE_GROUP" "$SERVICE_USER"
    else
      fail "Unable to create service user: ${SERVICE_USER}"
    fi
  fi
}

protect_binary_runtime_files() {
  run_as_root chown -R "${SERVICE_USER}:${SERVICE_GROUP}" "$CONFIG_DIR"
  run_as_root chmod 0750 "$CONFIG_DIR"
  if [[ -d "$CERT_DIR" ]]; then
    run_as_root chmod 0750 "$CERT_DIR"
    [[ -f "$TLS_CERT_FILE" ]] && run_as_root chown "${SERVICE_USER}:${SERVICE_GROUP}" "$TLS_CERT_FILE"
    [[ -f "$TLS_KEY_FILE" ]] && run_as_root chown "${SERVICE_USER}:${SERVICE_GROUP}" "$TLS_KEY_FILE"
    [[ -f "$TLS_CERT_FILE" ]] && run_as_root chmod 0640 "$TLS_CERT_FILE"
    [[ -f "$TLS_KEY_FILE" ]] && run_as_root chmod 0640 "$TLS_KEY_FILE"
  fi
  [[ -f "$ENV_FILE" ]] && run_as_root chmod 0640 "$ENV_FILE"
}

ensure_cron_service() {
  if command -v systemctl >/dev/null 2>&1; then
    run_as_root systemctl enable --now cron >/dev/null 2>&1 || \
      run_as_root systemctl enable --now crond >/dev/null 2>&1 || true
  elif command -v rc-update >/dev/null 2>&1; then
    run_as_root rc-update add crond default >/dev/null 2>&1 || true
    run_as_root service crond start >/dev/null 2>&1 || true
  fi
}

service_reload_command() {
  printf '%q' "$CERT_RELOAD_HOOK"
}

ensure_acme_sh() {
  local installer
  if command -v acme.sh >/dev/null 2>&1; then
    command -v acme.sh
    return 0
  fi

  if run_as_root test -x "${ACME_HOME}/acme.sh"; then
    printf '%s' "${ACME_HOME}/acme.sh"
    return 0
  fi

  if command -v apk >/dev/null 2>&1; then
    if run_as_root apk add --no-cache acme.sh >/dev/null 2>&1; then
      command -v acme.sh
      return 0
    fi
  fi

  log "$(msg acme_installing)"
  installer="$(mktemp)"
  trap 'rm -f "$installer"' RETURN
  curl -fsSL --proto '=https' --proto-redir '=https' --tlsv1.2 --connect-timeout 10 --max-time 120 --retry 2 --retry-delay 2 https://get.acme.sh -o "$installer"
  run_as_root env HOME=/root sh "$installer" email="${ACME_EMAIL}"
  run_as_root test -x "${ACME_HOME}/acme.sh" || fail "$(msg acme_failed)"
  printf '%s' "${ACME_HOME}/acme.sh"
}

issue_cloudflare_certificate() {
  local domain="$1"
  local cert_file="$2"
  local key_file="$3"
  local acme
  local reloadcmd

  [[ -n "${ACME_EMAIL:-}" ]] || fail "$(msg acme_email_empty)"
  [[ -n "${CF_API_TOKEN:-}" ]] || fail "$(msg cf_token_empty)"

  run_as_root mkdir -p "$(dirname "$cert_file")"
  ensure_cron_service
  acme="$(ensure_acme_sh)"
  reloadcmd="$(service_reload_command)"

  run_as_root env HOME=/root "$acme" --set-default-ca --server letsencrypt
  run_as_root env HOME=/root CF_Token="$CF_API_TOKEN" "$acme" --issue --dns dns_cf -d "$domain" --keylength ec-256
  run_as_root env HOME=/root "$acme" --install-cert -d "$domain" --ecc \
    --fullchain-file "$cert_file" \
    --key-file "$key_file" \
    --reloadcmd "$reloadcmd"
}

select_certificate_mode() {
  local value=""
  while true; do
    {
      printf '%s\n' "$(msg tls_mode_title)"
      printf '  1. %s\n' "$(msg tls_cloudflare)"
      printf '  2. %s\n' "$(msg tls_existing)"
      printf '  3. %s\n' "$(msg tls_selfsigned)"
    } >&2
    value="$(read_input "$(msg select_cert_mode) ")"
    if [[ -z "$value" || "$value" == "1" ]]; then
      printf 'cloudflare'
      return 0
    fi
    if [[ "$value" == "2" ]]; then
      printf 'existing'
      return 0
    fi
    if [[ "$value" == "3" ]]; then
      printf 'selfsigned'
      return 0
    fi
    warn "$(msg invalid_cert_mode)"
  done
}

ensure_certificate() {
  local domain="$1"
  local cert_file="$2"
  local key_file="$3"

  case "$CERT_MODE" in
    cloudflare)
      issue_cloudflare_certificate "$domain" "$cert_file" "$key_file"
      return 0
      ;;
    existing)
      [[ -s "$cert_file" && -s "$key_file" ]] || fail "$(msg invalid_existing_cert "$cert_file" "$key_file")"
      return 0
      ;;
    selfsigned)
      if [[ -s "$cert_file" && -s "$key_file" ]]; then
        return 0
      fi
      ;;
  esac

  warn "$(msg generating_selfsigned "$cert_file")"
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
NB_HEALTH_LISTEN_ADDRESS=127.0.0.1:9000
NB_METRICS_PORT=9090
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
    fail "$(msg service_required)"
  fi
}

print_header() {
  echo -e "${GREEN}=================================================${NC}"
  echo -e "${GREEN}              $(msg wizard_title)              ${NC}"
  echo -e "${GREEN}=================================================${NC}"
  echo "$(msg deployment_mode)"
  echo "$(msg shared_secret_note)"
  echo "$(msg cloudflare_note)"
  echo
}

print_summary() {
  local mode_label
  local cert_label
  local relay_secret_hint
  if [[ "$RELAY_GROUP_MODE" == "join" ]]; then
    mode_label="$(msg group_join_label)"
  else
    mode_label="$(msg group_create_label)"
  fi
  case "$CERT_MODE" in
    cloudflare) cert_label="$(msg cert_mode_cloudflare_summary)" ;;
    existing) cert_label="$(msg cert_mode_existing_summary)" ;;
    selfsigned) cert_label="$(msg cert_mode_selfsigned_summary)" ;;
    *) cert_label="$CERT_MODE" ;;
  esac
  relay_secret_hint="$(mask_secret "$RELAY_AUTH_SECRET")"

  cat <<EOF

==================== $(msg summary_title) ====================
$(msg summary_deployment)
$(msg summary_group "$mode_label")
$(msg summary_binary "$BIN_PATH")
$(msg summary_env "$ENV_FILE")
$(msg summary_relay_address "$RELAY_DOMAIN" "$RELAY_PORT")
$(msg summary_stun_address "$RELAY_DOMAIN" "$STUN_PORT")
$(msg summary_secret "$relay_secret_hint" "$ENV_FILE")
$(msg summary_cert "$TLS_CERT_FILE")
$(msg summary_key "$TLS_KEY_FILE")
$(msg summary_cert_mode "$cert_label")
$(msg summary_renewal)

$(msg management_config)
server:
  relays:
    addresses:
      - "rels://${RELAY_DOMAIN}:${RELAY_PORT}"
    secret: "<read NB_AUTH_SECRET from ${ENV_FILE}>"
  stuns:
    - uri: "stun:${RELAY_DOMAIN}:${STUN_PORT}"
      proto: udp

$(msg additional_node)
relays.addresses:
  - "rels://${RELAY_DOMAIN}:${RELAY_PORT}"

$(msg common_commands)
  systemctl status netbird-relay
  journalctl -u netbird-relay -f
  service netbird-relay status
EOF
}

main() {
  [[ -x "$BIN_PATH" ]] || fail "$(msg missing_binary "$BIN_PATH")"
  [[ -x "$CERT_RELOAD_HOOK" ]] || fail "$(msg missing_hook "$CERT_RELOAD_HOOK")"

  print_header

  RELAY_GROUP_MODE="$(select_relay_group_mode)"
  RELAY_DOMAIN="$(prompt_nonempty "$(msg relay_domain) ")"
  RELAY_PORT="$(prompt_default "$(msg relay_port) " '8443')"
  STUN_PORT="$(prompt_default "$(msg stun_port) " '3478')"
  CERT_MODE="$(select_certificate_mode)"
  TLS_CERT_FILE="$(prompt_default "$(msg cert_path "${CERT_DIR}/fullchain.pem") " "${CERT_DIR}/fullchain.pem")"
  TLS_KEY_FILE="$(prompt_default "$(msg key_path "${CERT_DIR}/privkey.pem") " "${CERT_DIR}/privkey.pem")"
  if [[ "$CERT_MODE" == "cloudflare" ]]; then
    ACME_EMAIL="$(prompt_nonempty "$(msg acme_email) ")"
    CF_API_TOKEN="$(read_secret "$(msg cf_api_token) ")"
  fi
  RELAY_AUTH_SECRET="$(read_relay_auth_secret)"

  validate_port "$RELAY_PORT" || fail "$(msg invalid_port "$RELAY_PORT")"
  validate_port "$STUN_PORT" || fail "$(msg invalid_stun_port "$STUN_PORT")"
  (( RELAY_PORT >= 1024 )) || fail "$(msg relay_port_min)"
  [[ "$RELAY_PORT" != "$STUN_PORT" ]] || fail "$(msg same_udp_port)"
  [[ "$RELAY_PORT" != "9000" && "$RELAY_PORT" != "9090" ]] || fail "$(msg reserved_port)"

  if [[ "$RELAY_GROUP_MODE" == "join" && -z "$RELAY_AUTH_SECRET" ]]; then
    fail "$(msg join_secret_required)"
  fi

  if [[ -z "$RELAY_AUTH_SECRET" ]]; then
    RELAY_AUTH_SECRET="$(generate_secret)"
    log "$(msg secret_generated)"
  fi

  ensure_service_user
  write_env_file
  ensure_certificate "$RELAY_DOMAIN" "$TLS_CERT_FILE" "$TLS_KEY_FILE"
  protect_binary_runtime_files
  restart_service
  print_summary
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
