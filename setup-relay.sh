#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'
COMPOSE_CMD=()
DEFAULT_IMAGE_REPOSITORY="${DEFAULT_IMAGE_REPOSITORY:-crpi-9kn2o1el6okkk1mu.cn-shanghai.personal.cr.aliyuncs.com/netrels/netrels}"
RELAY_IMAGE_DEFAULT="${RELAY_IMAGE_DEFAULT:-${DEFAULT_IMAGE_REPOSITORY}:relay}"
CADDY_IMAGE_DEFAULT="${CADDY_IMAGE_DEFAULT:-${DEFAULT_IMAGE_REPOSITORY}:caddy}"
SYNC_IMAGE_DEFAULT="${SYNC_IMAGE_DEFAULT:-${DEFAULT_IMAGE_REPOSITORY}:sync}"

print_header() {
  echo -e "${GREEN}=================================================${NC}"
  echo -e "${GREEN}              NetBird Relay 安装向导             ${NC}"
  echo -e "${GREEN}          Cloudflare DNS + Relay + STUN          ${NC}"
  echo -e "${GREEN}=================================================${NC}"
  echo "说明：如需多 Relay 节点，请在每台节点输入同一个认证密钥。"
  echo "认证密钥可留空自动生成，但多节点场景不要留空。"
  echo
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

wait_for_docker() {
  local attempts=60
  while (( attempts > 0 )); do
    if [[ -S /var/run/docker.sock ]] && docker info >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
    attempts=$((attempts - 1))
  done
  return 1
}

force_start_docker() {
  if command -v systemctl >/dev/null 2>&1; then
    systemctl restart docker || systemctl start docker || true
  elif command -v service >/dev/null 2>&1; then
    service docker restart || service docker start || true
  fi
}

show_docker_diagnostics() {
  warn "Docker 诊断信息："
  command -v docker >/dev/null 2>&1 && docker version || true
  if command -v systemctl >/dev/null 2>&1; then
    systemctl status docker --no-pager -l || true
    journalctl -u docker --no-pager -n 50 || true
  elif command -v service >/dev/null 2>&1; then
    service docker status || true
  fi
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
  local value=""
  value="$(read_input "$prompt")"
  if [[ -z "$value" ]]; then
    value="$default"
  fi
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
    python3 -c 'import secrets; print(secrets.token_urlsafe(32))'
  else
    fail "需要 openssl 或 python3 才能自动生成认证密钥。"
  fi
}

normalize_relay_image() {
  local image="$1"
  if [[ "$image" != */* && "$image" != *:* ]]; then
    image="netbirdio/relay:${image}"
  fi
  printf '%s' "$image"
}

ensure_permissions() {
  if [[ "${EUID}" -eq 0 ]]; then
    return 0
  fi

  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    return 0
  fi

  fail "请使用 root 运行，或使用具备 Docker 访问权限的用户运行。"
}

ensure_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    fail "未找到 Docker。OVA 内应已内置 Docker；请先确认 Docker 是否可用。"
  fi

  if ! docker info >/dev/null 2>&1; then
    warn "Docker 未运行，正在尝试启动。"
    force_start_docker
    wait_for_docker || true
  fi

  if ! docker info >/dev/null 2>&1; then
    show_docker_diagnostics
    fail "Docker 不可用，请启动 Docker 后重试。"
  fi

  if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD=(docker compose)
  elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD=(docker-compose)
  else
    fail "未找到 Docker Compose。"
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
RELAY_IMAGE=${RELAY_IMAGE}
CADDY_IMAGE=${CADDY_IMAGE}
SYNC_IMAGE=${SYNC_IMAGE}
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
    write_compose_service_source "${CADDY_IMAGE}" "./caddy"
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
    write_compose_service_source "${SYNC_IMAGE}" "./sync"
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
    image: \${RELAY_IMAGE}
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

  fail "等待证书超时。请查看日志：${COMPOSE_CMD[*]} logs caddy sync-relay-certs"
}

start_relay() {
  log "正在启动 NetBird Relay。"
  "${COMPOSE_CMD[@]}" -f "${SCRIPT_DIR}/docker-compose.yml" up -d relay
}

print_summary() {
  cat <<EOF

==================== 安装完成 ====================
Relay 地址：rels://${RELAY_DOMAIN}:${RELAY_PORT}
STUN 地址： stun:${RELAY_DOMAIN}:${STUN_PORT}
认证密钥：  ${RELAY_AUTH_SECRET}

把下面配置合并到 NetBird Management 的 config.yaml：
server:
  relays:
    addresses:
      - "rels://${RELAY_DOMAIN}:${RELAY_PORT}"
    secret: "${RELAY_AUTH_SECRET}"
  stuns:
    - uri: "stun:${RELAY_DOMAIN}:${STUN_PORT}"
      proto: udp

如果有多个 Relay 节点，所有节点和 Management 必须使用同一个 secret。

常用命令：
  cd ${SCRIPT_DIR}
  ${COMPOSE_CMD[*]} logs -f caddy sync-relay-certs relay
  ${COMPOSE_CMD[*]} restart relay
EOF
}

print_header
ensure_permissions
ensure_docker

RELAY_DOMAIN="$(prompt_nonempty 'Relay 域名，例如 rels.jinfei.org：')"
ACME_EMAIL="$(prompt_nonempty '证书申请邮箱 ACME Email：')"
CF_API_TOKEN="$(read_secret 'Cloudflare API Token（输入不显示）：')"
RELAY_PORT="$(prompt_default 'Relay TCP 端口 [8443]：' '8443')"
STUN_PORT="$(prompt_default 'STUN UDP 端口 [3478]：' '3478')"
CADDY_IMAGE="${CADDY_IMAGE:-${CADDY_IMAGE_DEFAULT}}"
SYNC_IMAGE="${SYNC_IMAGE:-${SYNC_IMAGE_DEFAULT}}"
RELAY_IMAGE_DEFAULT="${RELAY_IMAGE:-${RELAY_IMAGE_DEFAULT}}"
RELAY_IMAGE="$(prompt_default "Relay 镜像 [${RELAY_IMAGE_DEFAULT}]：" "${RELAY_IMAGE_DEFAULT}")"
RELAY_IMAGE="$(normalize_relay_image "$RELAY_IMAGE")"
SYNC_INTERVAL="$(prompt_default '证书同步间隔秒数 [60]：' '60')"
RELAY_AUTH_SECRET="$(read_secret '认证密钥 secret（多节点请填同一个；留空自动生成）：')"

CADDY_HTTP_PORT=18080
CADDY_HTTPS_PORT=18443

validate_port "$RELAY_PORT" || fail "Relay 端口无效：${RELAY_PORT}"
validate_port "$STUN_PORT" || fail "STUN 端口无效：${STUN_PORT}"
validate_port "$SYNC_INTERVAL" || fail "证书同步间隔无效：${SYNC_INTERVAL}"

if [[ -z "$RELAY_AUTH_SECRET" ]]; then
  RELAY_AUTH_SECRET="$(generate_secret)"
  log "已自动生成认证密钥。多 Relay 节点请把这个密钥复制到其它节点。"
fi

ensure_directories
write_env_files
write_compose_file
write_caddyfile
start_bootstrap_stack
wait_for_cert
start_relay
print_summary
