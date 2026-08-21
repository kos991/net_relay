#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${ENV_FILE:-/etc/netbird-relay/relay.env}"
SERVICE_USER="${SERVICE_USER:-netbird-relay}"
SERVICE_GROUP="${SERVICE_GROUP:-netbird-relay}"

fail() {
  echo "Certificate reload failed: $*" >&2
  exit 1
}

read_env_value() {
  local key="$1"
  awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$ENV_FILE"
}

[[ -r "$ENV_FILE" ]] || fail "environment file is missing: ${ENV_FILE}"

cert_file="$(read_env_value NB_TLS_CERT_FILE)"
key_file="$(read_env_value NB_TLS_KEY_FILE)"
[[ -n "$cert_file" && -s "$cert_file" ]] || fail "certificate file is missing"
[[ -n "$key_file" && -s "$key_file" ]] || fail "private key file is missing"

openssl x509 -in "$cert_file" -noout -checkend 0 >/dev/null || fail "certificate is invalid or expired"
openssl pkey -in "$key_file" -noout >/dev/null || fail "private key is invalid"

cert_public_key="$(openssl x509 -in "$cert_file" -pubkey -noout | openssl pkey -pubin -outform DER | openssl dgst -sha256)"
key_public_key="$(openssl pkey -in "$key_file" -pubout -outform DER | openssl dgst -sha256)"
[[ "$cert_public_key" == "$key_public_key" ]] || fail "certificate and private key do not match"

chown "${SERVICE_USER}:${SERVICE_GROUP}" "$cert_file" "$key_file"
chmod 0640 "$cert_file" "$key_file"

if command -v systemctl >/dev/null 2>&1; then
  if systemctl is-active --quiet netbird-relay; then
    systemctl restart netbird-relay
  fi
elif command -v rc-service >/dev/null 2>&1; then
  if rc-service netbird-relay status >/dev/null 2>&1; then
    rc-service netbird-relay restart
  fi
fi

echo "NetBird Relay certificate validated and applied."
