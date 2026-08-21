#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_DIR="${BUILD_DIR:-${ROOT_DIR}/.build/netbird}"
OUTPUT_DIR="${OUTPUT_DIR:-${ROOT_DIR}/dist}"
NETBIRD_RELAY_REF="${NETBIRD_RELAY_REF:-main}"
NETBIRD_RELAY_REPO="${NETBIRD_RELAY_REPO:-https://github.com/netbirdio/netbird.git}"
GO_SECURITY_PATCH_MODULES="${GO_SECURITY_PATCH_MODULES:-golang.org/x/net@v0.58.0}"

TARGET_OS="${TARGET_OS:-linux}"
TARGET_ARCH="${TARGET_ARCH:-amd64}"

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
require_cmd go

mkdir -p "$(dirname "$BUILD_DIR")" "$OUTPUT_DIR"

if [[ -d "${BUILD_DIR}/.git" ]]; then
  log "Updating NetBird source: ${NETBIRD_RELAY_REPO}"
  git -C "$BUILD_DIR" fetch --tags --force origin
else
  rm -rf "$BUILD_DIR"
  log "Cloning NetBird source: ${NETBIRD_RELAY_REPO}"
  git clone --depth 1 "$NETBIRD_RELAY_REPO" "$BUILD_DIR"
  git -C "$BUILD_DIR" fetch --tags --force origin
fi

git -C "$BUILD_DIR" checkout "$NETBIRD_RELAY_REF"

commit="$(git -C "$BUILD_DIR" rev-parse --short=12 HEAD)"
binary="${OUTPUT_DIR}/netbird-relay-${TARGET_OS}-${TARGET_ARCH}"

log "Building netbird-relay ${NETBIRD_RELAY_REF} (${commit}) for ${TARGET_OS}/${TARGET_ARCH}"
(
  cd "$BUILD_DIR"
  if [[ -n "$GO_SECURITY_PATCH_MODULES" ]]; then
    read -r -a security_patch_modules <<< "$GO_SECURITY_PATCH_MODULES"
    log "Applying Go security module overrides: ${GO_SECURITY_PATCH_MODULES}"
    go get "${security_patch_modules[@]}"
    go mod tidy
  fi
  CGO_ENABLED=0 GOOS="$TARGET_OS" GOARCH="$TARGET_ARCH" go build \
    -trimpath \
    -ldflags "-s -w -X github.com/netbirdio/netbird/version.version=${NETBIRD_RELAY_REF} -X github.com/netbirdio/netbird/version.commit=${commit}" \
    -o "$binary" \
    ./relay
)

chmod +x "$binary"
log "Built: ${binary}"
