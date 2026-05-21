#!/usr/bin/env bash
set -euo pipefail

: "${RELAY_DOMAIN:?RELAY_DOMAIN is required}"
: "${RELAY_CONTAINER_NAME:=netbird-relay}"
: "${SYNC_INTERVAL:=60}"

TARGET_CERT="/relay-certs/fullchain.pem"
TARGET_KEY="/relay-certs/privkey.pem"

log() {
  printf '[sync] %s\n' "$*"
}

find_source_file() {
  local extension="$1"
  find /caddy-data -type f -path "*/${RELAY_DOMAIN}/*.${extension}" | sort | head -n 1
}

hash_file() {
  local path="$1"
  if [[ -f "$path" ]]; then
    sha256sum "$path" | awk '{print $1}'
  else
    echo ""
  fi
}

copy_atomic() {
  local src="$1"
  local dst="$2"
  local mode="$3"
  local tmp="${dst}.tmp"

  cp "$src" "$tmp"
  chmod "$mode" "$tmp"
  mv "$tmp" "$dst"
}

restart_relay() {
  curl --silent --show-error --fail \
    --unix-socket /var/run/docker.sock \
    -X POST "http://localhost/containers/${RELAY_CONTAINER_NAME}/restart?t=10" \
    >/dev/null
}

log "正在监听 Caddy 证书目录：${RELAY_DOMAIN}"

while true; do
  src_cert="$(find_source_file crt || true)"
  src_key="$(find_source_file key || true)"

  if [[ -n "$src_cert" && -n "$src_key" ]]; then
    src_cert_hash="$(hash_file "$src_cert")"
    src_key_hash="$(hash_file "$src_key")"
    dst_cert_hash="$(hash_file "$TARGET_CERT")"
    dst_key_hash="$(hash_file "$TARGET_KEY")"

    if [[ "$src_cert_hash" != "$dst_cert_hash" || "$src_key_hash" != "$dst_key_hash" ]]; then
      log "检测到证书更新"
      mkdir -p /relay-certs
      copy_atomic "$src_cert" "$TARGET_CERT" 0644
      copy_atomic "$src_key" "$TARGET_KEY" 0600
      log "证书已同步到 Relay"

      if curl --silent --show-error --fail \
        --unix-socket /var/run/docker.sock \
        "http://localhost/containers/${RELAY_CONTAINER_NAME}/json" \
        >/dev/null 2>&1; then
        log "正在重启 ${RELAY_CONTAINER_NAME}"
        restart_relay
      else
        log "Relay 容器尚未创建，跳过重启"
      fi
    fi
  else
    log "证书尚未就绪"
  fi

  sleep "$SYNC_INTERVAL"
done
