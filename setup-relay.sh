#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-/etc/netbird-relay}"
ENV_FILE="${ENV_FILE:-${CONFIG_DIR}/relay.env}"
CERT_DIR="${CERT_DIR:-${CONFIG_DIR}/certs}"
BIN_PATH="${BIN_PATH:-/usr/local/bin/netbird-relay}"
DEPLOY_MODE="${DEPLOY_MODE:-binary}"
COMPOSE_FILE="${COMPOSE_FILE:-${CONFIG_DIR}/docker-compose.yml}"
COMPOSE_ENV_FILE="${COMPOSE_ENV_FILE:-${CONFIG_DIR}/compose.env}"

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
    fail "Root permission is required for: $*"
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
    IFS= read -r value </dev/tty || fail "Unable to read from terminal."
  else
    IFS= read -r value || fail "Unable to read input. Run in an interactive terminal."
  fi
  trim "$value"
}

read_secret() {
  local prompt="$1"
  local value=""
  printf '%s' "$prompt" >&2
  if [[ -r /dev/tty ]]; then
    IFS= read -r -s value </dev/tty || fail "Unable to read from terminal."
  else
    IFS= read -r -s value || fail "Unable to read input. Run in an interactive terminal."
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
Deploy mode:
  1. Create a new relay node group
  2. Join an existing relay node group
EOF
    value="$(read_input 'Choose relay group mode [1]: ')"
    if [[ -z "$value" || "$value" == "1" ]]; then
      printf 'create'
      return 0
    fi
    if [[ "$value" == "2" ]]; then
      printf 'join'
      return 0
    fi
    warn "Please enter 1 or 2."
  done
}

read_relay_auth_secret() {
  if [[ "$RELAY_GROUP_MODE" == "join" ]]; then
    read_secret 'Existing relay group secret (required): '
  else
    read_secret 'Relay auth secret (empty means auto-generate; save it for multi-node reuse): '
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
    fail "openssl or python3 is required to generate a relay auth secret."
  fi
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
  if [[ "$DEPLOY_MODE" == "compose" ]]; then
    printf 'docker compose -f %s --env-file %s restart' "$COMPOSE_FILE" "$COMPOSE_ENV_FILE"
  elif command -v systemctl >/dev/null 2>&1; then
    printf 'systemctl restart netbird-relay'
  else
    printf 'service netbird-relay restart'
  fi
}

ensure_acme_sh() {
  if [[ -x "${HOME}/.acme.sh/acme.sh" ]]; then
    printf '%s' "${HOME}/.acme.sh/acme.sh"
    return 0
  fi

  log "Installing acme.sh..."
  curl https://get.acme.sh | sh -s email="${ACME_EMAIL}"
  [[ -x "${HOME}/.acme.sh/acme.sh" ]] || fail "acme.sh installation failed."
  printf '%s' "${HOME}/.acme.sh/acme.sh"
}

issue_cloudflare_certificate() {
  local domain="$1"
  local cert_file="$2"
  local key_file="$3"
  local acme
  local reloadcmd

  [[ -n "${ACME_EMAIL:-}" ]] || fail "ACME email cannot be empty."
  [[ -n "${CF_API_TOKEN:-}" ]] || fail "Cloudflare API token cannot be empty."

  run_as_root mkdir -p "$(dirname "$cert_file")"
  ensure_cron_service
  acme="$(ensure_acme_sh)"
  reloadcmd="$(service_reload_command)"

  export CF_Token="$CF_API_TOKEN"
  "$acme" --set-default-ca --server letsencrypt
  "$acme" --issue --dns dns_cf -d "$domain" --keylength ec-256
  "$acme" --install-cert -d "$domain" --ecc \
    --fullchain-file "$cert_file" \
    --key-file "$key_file" \
    --reloadcmd "$reloadcmd"
}

select_certificate_mode() {
  local value=""
  while true; do
    cat >&2 <<'EOF'
TLS certificate mode:
  1. Cloudflare DNS via acme.sh (recommended)
  2. Use existing certificate paths
  3. Generate local self-signed certificate
EOF
    value="$(read_input 'Choose certificate mode [1]: ')"
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
    warn "Please enter 1, 2, or 3."
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
      [[ -s "$cert_file" && -s "$key_file" ]] || fail "Existing certificate paths are invalid: ${cert_file} / ${key_file}"
      return 0
      ;;
    selfsigned)
      if [[ -s "$cert_file" && -s "$key_file" ]]; then
        return 0
      fi
      ;;
  esac

  warn "Generating local self-signed certificate: ${cert_file}"
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

write_compose_file() {
  local env_tmp compose_tmp
  env_tmp="$(mktemp)"
  compose_tmp="$(mktemp)"

  cat > "$env_tmp" <<EOF
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

  cat > "$compose_tmp" <<EOF
services:
  netbird-relay:
    image: netbirdio/relay:latest
    container_name: netbird-relay
    restart: unless-stopped
    env_file:
      - ${COMPOSE_ENV_FILE}
    ports:
      - "${RELAY_PORT}:${RELAY_PORT}/tcp"
      - "${STUN_PORT}:${STUN_PORT}/udp"
    volumes:
      - ${CONFIG_DIR}:${CONFIG_DIR}:ro
EOF

  run_as_root mkdir -p "$CONFIG_DIR"
  run_as_root install -m 0600 "$env_tmp" "$COMPOSE_ENV_FILE"
  run_as_root install -m 0644 "$compose_tmp" "$COMPOSE_FILE"
  rm -f "$env_tmp" "$compose_tmp"
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
    fail "systemd or OpenRC is required to start netbird-relay."
  fi
}

restart_compose_service() {
  run_as_root docker compose -f "$COMPOSE_FILE" --env-file "$COMPOSE_ENV_FILE" up -d
}

print_header() {
  echo -e "${GREEN}=================================================${NC}"
  echo -e "${GREEN}              NetBird Relay installer             ${NC}"
  echo -e "${GREEN}=================================================${NC}"
  echo "Deploy mode: ${DEPLOY_MODE}"
  echo "Use the same auth secret on all nodes in one relay group."
  echo "Cloudflare mode uses acme.sh DNS validation and reloadcmd renewal sync."
  echo
}

print_summary() {
  local mode_label="create a new relay node group"
  if [[ "$RELAY_GROUP_MODE" == "join" ]]; then
    mode_label="join an existing relay node group"
  fi

  cat <<EOF

==================== Install complete ====================
Deploy mode: ${DEPLOY_MODE}
Relay group mode: ${mode_label}
Relay binary: ${BIN_PATH}
Relay env: ${ENV_FILE}
Compose file: ${COMPOSE_FILE}
Relay address: rels://${RELAY_DOMAIN}:${RELAY_PORT}
STUN address: stun:${RELAY_DOMAIN}:${STUN_PORT}
Relay auth secret: ${RELAY_AUTH_SECRET}
TLS certificate: ${TLS_CERT_FILE}
TLS key: ${TLS_KEY_FILE}
Certificate mode: ${CERT_MODE}
Certificate auto-renewal: Cloudflare mode uses acme.sh cron and reloadcmd.

Merge into NetBird Management config.yaml:
server:
  relays:
    addresses:
      - "rels://${RELAY_DOMAIN}:${RELAY_PORT}"
    secret: "${RELAY_AUTH_SECRET}"
  stuns:
    - uri: "stun:${RELAY_DOMAIN}:${STUN_PORT}"
      proto: udp

If this is an added node, append:
relays.addresses:
  - "rels://${RELAY_DOMAIN}:${RELAY_PORT}"

Common commands:
  systemctl status netbird-relay
  journalctl -u netbird-relay -f
  service netbird-relay status
  docker compose -f ${COMPOSE_FILE} --env-file ${COMPOSE_ENV_FILE} ps
EOF
}

if [[ "$DEPLOY_MODE" == "binary" ]]; then
  [[ -x "$BIN_PATH" ]] || fail "netbird-relay binary not found: ${BIN_PATH}"
elif [[ "$DEPLOY_MODE" == "compose" ]]; then
  command -v docker >/dev/null 2>&1 || fail "Docker is required for compose deployment."
  docker compose version >/dev/null 2>&1 || fail "Docker Compose is required for compose deployment."
else
  fail "DEPLOY_MODE must be binary or compose."
fi

print_header

RELAY_GROUP_MODE="$(select_relay_group_mode)"
RELAY_DOMAIN="$(prompt_nonempty 'Relay domain, for example rels.example.com: ')"
RELAY_PORT="$(prompt_default 'Relay TCP port [8443]: ' '8443')"
STUN_PORT="$(prompt_default 'STUN UDP port [3478]: ' '3478')"
CERT_MODE="$(select_certificate_mode)"
TLS_CERT_FILE="$(prompt_default "TLS certificate path [${CERT_DIR}/fullchain.pem]: " "${CERT_DIR}/fullchain.pem")"
TLS_KEY_FILE="$(prompt_default "TLS private key path [${CERT_DIR}/privkey.pem]: " "${CERT_DIR}/privkey.pem")"
if [[ "$CERT_MODE" == "cloudflare" ]]; then
  ACME_EMAIL="$(prompt_nonempty 'ACME email: ')"
  CF_API_TOKEN="$(read_secret 'Cloudflare API token: ')"
fi
RELAY_AUTH_SECRET="$(read_relay_auth_secret)"

validate_port "$RELAY_PORT" || fail "Invalid Relay port: ${RELAY_PORT}"
validate_port "$STUN_PORT" || fail "Invalid STUN port: ${STUN_PORT}"

if [[ "$RELAY_GROUP_MODE" == "join" && -z "$RELAY_AUTH_SECRET" ]]; then
  fail "must provide an existing relay auth secret when joining a relay node group."
fi

if [[ -z "$RELAY_AUTH_SECRET" ]]; then
  RELAY_AUTH_SECRET="$(generate_secret)"
  log "Generated relay auth secret. Save it; all nodes and Management must use the same value."
fi

ensure_certificate "$RELAY_DOMAIN" "$TLS_CERT_FILE" "$TLS_KEY_FILE"
if [[ "$DEPLOY_MODE" == "compose" ]]; then
  write_compose_file
  restart_compose_service
else
  write_env_file
  restart_service
fi
print_summary
