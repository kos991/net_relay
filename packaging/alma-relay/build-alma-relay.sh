#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_DIR="${BUILD_DIR:-${ROOT_DIR}/.build/alma-relay}"
OUTPUT_FILE="${OUTPUT_FILE:-${ROOT_DIR}/packaging/alma-relay/alma-relay.cjs}"
ALMA_RELAY_REF="${ALMA_RELAY_REF:-}"
ALMA_RELAY_REPO="${ALMA_RELAY_REPO:-https://github.com/yetone/alma-relay.git}"

log() {
  printf '%s\n' "$*" >&2
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'missing command: %s\n' "$1" >&2
    exit 1
  }
}

require_cmd git
require_cmd node
require_cmd npm

if [[ -z "${ALMA_RELAY_REF}" ]]; then
  if [[ -f "${ROOT_DIR}/.github/alma-relay-upstream.sha" ]]; then
    ALMA_RELAY_REF="$(cat "${ROOT_DIR}/.github/alma-relay-upstream.sha")"
  else
    ALMA_RELAY_REF="v1.4.0"
  fi
fi

mkdir -p "$(dirname "$BUILD_DIR")" "$(dirname "$OUTPUT_FILE")"

if [[ -d "${BUILD_DIR}/.git" ]]; then
  log "Updating Alma Relay source: ${ALMA_RELAY_REPO}"
  git -C "$BUILD_DIR" fetch --tags --force origin
else
  rm -rf "$BUILD_DIR"
  log "Cloning Alma Relay source: ${ALMA_RELAY_REPO}"
  git clone --depth 1 "$ALMA_RELAY_REPO" "$BUILD_DIR"
  git -C "$BUILD_DIR" fetch --tags --force origin
fi

git -C "$BUILD_DIR" checkout "$ALMA_RELAY_REF"
commit="$(git -C "$BUILD_DIR" rev-parse --short=12 HEAD)"

log "Building Alma Relay ${ALMA_RELAY_REF} (${commit})"
(
  cd "$BUILD_DIR"
  node -e "
    const fs = require('fs');
    let code = fs.readFileSync('index.mjs', 'utf8');
    if (!code.includes('createHttpsServer')) {
      code = code.replace(
        \"import { createServer } from 'node:http';\",
        \"import { createServer as createHttpServer } from 'node:http';\\nimport { createServer as createHttpsServer } from 'node:https';\"
      ).replace(
        \"import { readFileSync } from 'node:fs';\",
        \"import { readFileSync, existsSync } from 'node:fs';\"
      ).replace(
        \"const server = createServer((req, res) => {\",
        \"const TLS_CERT = env.TLS_CERT_FILE || env.SSL_CERT;\\nconst TLS_KEY = env.TLS_KEY_FILE || env.SSL_KEY;\\nfunction initServer(handler) {\\n    if (TLS_CERT && TLS_KEY && existsSync(TLS_CERT) && existsSync(TLS_KEY)) {\\n        return createHttpsServer({ cert: readFileSync(TLS_CERT), key: readFileSync(TLS_KEY) }, handler);\\n    }\\n    return createHttpServer(handler);\\n}\\nconst server = initServer((req, res) => {\"
      );
      fs.writeFileSync('index.mjs', code);
    }
  "

  npm install --no-audit --no-fund ws@8.18.3
  npx --yes esbuild index.mjs --bundle --platform=node --target=node20 --format=cjs --outfile="$OUTPUT_FILE"
  node --check "$OUTPUT_FILE"
)

log "Successfully built ${OUTPUT_FILE}"
