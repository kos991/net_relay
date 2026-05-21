#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cp -R "$ROOT_DIR"/. "$TMP_DIR"/
cd "$TMP_DIR"

cat > docker <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "info" ]]; then
  exit 0
fi

if [[ "${1:-}" == "compose" && "${2:-}" == "version" ]]; then
  exit 0
fi

if [[ "${1:-}" == "compose" ]]; then
  shift
  echo "docker compose $*" >> docker-calls.log
  if [[ "$*" == *"up -d --build caddy sync-relay-certs"* ]]; then
    mkdir -p data/relay-certs
    printf 'fake cert\n' > data/relay-certs/fullchain.pem
    printf 'fake key\n' > data/relay-certs/privkey.pem
  fi
  exit 0
fi

echo "unexpected docker call: $*" >&2
exit 1
EOF
chmod +x docker
export PATH="$TMP_DIR:$PATH"

printf 'relay.example.com\nadmin@example.com\ncf-token\n9443\n53478\nlatest\n60\n\n' | ./setup-relay.sh

test -f .env
test -f relay.env
test -f docker-compose.yml
test -f caddy/Caddyfile
test -f data/relay-certs/fullchain.pem
test -f data/relay-certs/privkey.pem

grep -q '^RELAY_DOMAIN=relay.example.com$' .env
grep -q '^RELAY_PORT=9443$' .env
grep -q '^STUN_PORT=53478$' .env
grep -q '^NB_EXPOSED_ADDRESS=rels://relay.example.com:9443$' relay.env
grep -q '^NB_STUN_PORTS=53478$' relay.env
grep -q 'dns cloudflare {env.CF_API_TOKEN}' caddy/Caddyfile
grep -q '"${RELAY_PORT}:${RELAY_PORT}/tcp"' docker-compose.yml
grep -q '"${STUN_PORT}:${STUN_PORT}/udp"' docker-compose.yml
grep -q 'docker compose -f .*docker-compose.yml up -d --build caddy sync-relay-certs' docker-calls.log
grep -q 'docker compose -f .*docker-compose.yml up -d relay' docker-calls.log
