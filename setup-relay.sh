#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_header() {
  echo -e "${GREEN}=================================================${NC}"
  echo -e "${GREEN}          NetBird Relay 一键安装脚本             ${NC}"
  echo -e "${GREEN}        Cloudflare DNS + 自定义 Relay 端口        ${NC}"
  echo -e "${GREEN}=================================================${NC}"
}

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

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "缺少必要命令：$1"
  fi
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

prompt_nonempty() {
  local prompt="$1"
  local value=""
  while [[ -z "$value" ]]; do
    read -r -p "$prompt" value
    value="$(trim "$value")"
  done
  printf '%s' "$value"
}

prompt_default() {
  local prompt="$1"
  local default="$2"
  local value=""
  read -r -p "$prompt" value
  value="$(trim "$value")"
  if [[ -z "$value" ]]; then
    value="$default"
  fi
  printf '%s' "$value"
}

prompt_secret() {
  local prompt="$1"
  local value=""
  read -r -s -p "$prompt" value
  printf '\n' >&2
  value="$(trim "$value")"
  printf '%s' "$value"
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
    python3 - <<'PY'
import secrets
print(secrets.token_urlsafe(32))
PY
  else
    fail "未检测到 openssl 或 python3，无法自动生成共享密钥。"
  fi
}

ensure_permissions() {
  if [[ "${EUID}" -eq 0 ]]; then
    return 0
  fi

  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    return 0
  fi

  fail "请使用 root 执行，或使用已经具备 Docker 权限的用户执行。"
}

ensure_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    warn "未检测到 Docker，正在通过 get.docker.com 安装。"
    require_cmd curl
    curl -fsSL https://get.docker.com | bash
  fi

  if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD=(docker compose)
  elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD=(docker-compose)
  else
    fail "未检测到 docker compose。"
  fi
}

ensure_directories() {
  mkdir -p \
    "${SCRIPT_DIR}/caddy" \
    "${SCRIPT_DIR}/sync" \
    "${SCRIPT_DIR}/data/caddy" \
    "${SCRIPT_DIR}/data/caddy-config" \
    "${SCRIPT_DIR}/data/relay-certs" \
    "${SCRIPT_DIR}/data/relay-data"
}

write_env_files() {
  cat > "${SCRIPT_DIR}/.env" <<EOF
RELAY_DOMAIN=${RELAY_DOMAIN}
RELAY_PORT=${RELAY_PORT}
STUN_PORT=${STUN_PORT}
ACME_EMAIL=${ACME_EMAIL}
CF_API_TOKEN=${CF_API_TOKEN}
RELAY_AUTH_SECRET=${RELAY_AUTH_SECRET}
RELAY_IMAGE_TAG=${RELAY_IMAGE_TAG}
CADDY_HTTP_PORT=${CADDY_HTTP_PORT}
CADDY_HTTPS_PORT=${CADDY_HTTPS_PORT}
SYNC_INTERVAL=${SYNC_INTERVAL}
EOF

  cat > "${SCRIPT_DIR}/relay.env" <<EOF
NB_LOG_LEVEL=info
NB_LISTEN_ADDRESS=:${RELAY_PORT}
NB_EXPOSED_ADDRESS=rels://${RELAY_DOMAIN}:${RELAY_PORT}
NB_AUTH_SECRET=${RELAY_AUTH_SECRET}
NB_ENABLE_STUN=true
NB_STUN_PORTS=${STUN_PORT}
NB_TLS_CERT_FILE=/certs/fullchain.pem
NB_TLS_KEY_FILE=/certs/privkey.pem
EOF
}

write_compose_service_source() {
  local image_value="$1"
  local build_context="$2"

  if [[ -n "$image_value" ]]; then
    cat <<EOF
    image: ${image_value}
EOF
  else
    cat <<EOF
    build:
      context: ${build_context}
EOF
  fi
}

write_compose_file() {
  {
    cat <<EOF
services:
  caddy:
EOF
    write_compose_service_source "${CADDY_IMAGE:-}" "./caddy"
    cat <<EOF
    container_name: netbird-caddy-cert
    restart: unless-stopped
    environment:
      CF_API_TOKEN: \${CF_API_TOKEN}
    volumes:
      - ./caddy/Caddyfile:/etc/caddy/Caddyfile:ro
      - ./data/caddy:/data
      - ./data/caddy-config:/config

  sync-relay-certs:
EOF
    write_compose_service_source "${SYNC_IMAGE:-}" "./sync"
    cat <<EOF
    container_name: netbird-relay-cert-sync
    restart: unless-stopped
    environment:
      RELAY_DOMAIN: \${RELAY_DOMAIN}
      RELAY_CONTAINER_NAME: netbird-relay
      SYNC_INTERVAL: \${SYNC_INTERVAL}
    volumes:
      - ./data/caddy:/caddy-data:ro
      - ./data/relay-certs:/relay-certs
      - /var/run/docker.sock:/var/run/docker.sock
    depends_on:
      - caddy

  relay:
    image: netbirdio/relay:\${RELAY_IMAGE_TAG}
    container_name: netbird-relay
    restart: unless-stopped
    env_file:
      - ./relay.env
    volumes:
      - ./data/relay-certs:/certs:ro
      - ./data/relay-data:/data
    ports:
      - "\${RELAY_PORT}:\${RELAY_PORT}/tcp"
      - "\${STUN_PORT}:\${STUN_PORT}/udp"
    depends_on:
      - caddy
      - sync-relay-certs
EOF
  } > "${SCRIPT_DIR}/docker-compose.yml"
}

write_caddyfile() {
  cat > "${SCRIPT_DIR}/caddy/Caddyfile" <<EOF
{
	email ${ACME_EMAIL}
	http_port ${CADDY_HTTP_PORT}
	https_port ${CADDY_HTTPS_PORT}
}

${RELAY_DOMAIN} {
	tls {
		dns cloudflare {env.CF_API_TOKEN}
	}

	respond "NetBird Relay certificate bootstrap endpoint" 200
}
EOF
}

start_bootstrap_stack() {
  log "正在启动 Caddy 和证书同步服务。"
  "${COMPOSE_CMD[@]}" -f "${SCRIPT_DIR}/docker-compose.yml" up -d --build caddy sync-relay-certs
}

wait_for_cert() {
  local cert_path="${SCRIPT_DIR}/data/relay-certs/fullchain.pem"
  local key_path="${SCRIPT_DIR}/data/relay-certs/privkey.pem"
  local waited=0
  local max_wait=600

  log "正在等待证书签发并同步到 Relay。"
  while (( waited < max_wait )); do
    if [[ -s "$cert_path" && -s "$key_path" ]]; then
      log "证书已就绪。"
      return 0
    fi
    sleep 5
    waited=$((waited + 5))
  done

  fail "等待证书超时，请查看日志：docker compose logs caddy sync-relay-certs"
}

start_relay() {
  log "正在启动 NetBird Relay。"
  "${COMPOSE_CMD[@]}" -f "${SCRIPT_DIR}/docker-compose.yml" up -d relay
}

print_summary() {
  cat <<EOF

==================== 安装完成 ====================
Relay 地址: rels://${RELAY_DOMAIN}:${RELAY_PORT}
STUN 地址:  stun:${RELAY_DOMAIN}:${STUN_PORT}
共享密钥: ${RELAY_AUTH_SECRET}

请将下面配置写入 NetBird Management 的 config.yaml：

server:
  relays:
    addresses:
      - "rels://${RELAY_DOMAIN}:${RELAY_PORT}"
    secret: "${RELAY_AUTH_SECRET}"
  stuns:
    - uri: "stun:${RELAY_DOMAIN}:${STUN_PORT}"
      proto: udp

常用命令：
  cd ${SCRIPT_DIR}
  ${COMPOSE_CMD[*]} logs -f caddy sync-relay-certs relay
  ${COMPOSE_CMD[*]} restart relay
EOF
}

print_header
ensure_permissions
ensure_docker

RELAY_DOMAIN="$(prompt_nonempty '请输入 Relay 域名，例如 rels.jinfei.org: ')"
ACME_EMAIL="$(prompt_nonempty '请输入证书邮箱: ')"
CF_API_TOKEN="$(prompt_secret '请输入 Cloudflare API Token: ')"
RELAY_PORT="$(prompt_default '请输入 Relay TCP 端口 [8443]: ' '8443')"
STUN_PORT="$(prompt_default '请输入 STUN UDP 端口 [3478]: ' '3478')"
RELAY_IMAGE_TAG="$(prompt_default '请输入 Relay 镜像标签 [latest]: ' 'latest')"
SYNC_INTERVAL="$(prompt_default '请输入证书同步间隔秒数 [60]: ' '60')"
RELAY_AUTH_SECRET="$(prompt_secret '请输入共享密钥，留空自动生成: ')"

CADDY_HTTP_PORT=18080
CADDY_HTTPS_PORT=18443

validate_port "$RELAY_PORT" || fail "Relay 端口无效：${RELAY_PORT}"
validate_port "$STUN_PORT" || fail "STUN 端口无效：${STUN_PORT}"

if [[ -z "$RELAY_AUTH_SECRET" ]]; then
  RELAY_AUTH_SECRET="$(generate_secret)"
  log "已自动生成共享密钥。"
fi

ensure_directories
write_env_files
write_compose_file
write_caddyfile
start_bootstrap_stack
wait_for_cert
start_relay
print_summary
