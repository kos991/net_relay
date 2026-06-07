#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${DIST_DIR:-${ROOT_DIR}/dist}"
PACKAGE_DIR="${PACKAGE_DIR:-${ROOT_DIR}/release}"
TARGET_OS="${TARGET_OS:-linux}"
TARGET_ARCH="${TARGET_ARCH:-amd64}"
NETBIRD_RELAY_REF="${NETBIRD_RELAY_REF:-main}"
PACKAGE_PREFIX="netbird-relay-linux"

binary="${DIST_DIR}/netbird-relay-${TARGET_OS}-${TARGET_ARCH}"
package_name="${PACKAGE_PREFIX}-${TARGET_ARCH}.tar.gz"
staging_dir="$(mktemp -d)"

cleanup() {
  rm -rf "$staging_dir"
}
trap cleanup EXIT

[[ -x "$binary" ]] || {
  printf 'missing relay binary: %s\n' "$binary" >&2
  exit 1
}

mkdir -p \
  "${staging_dir}/netbird-relay/bin" \
  "${staging_dir}/netbird-relay/services" \
  "$PACKAGE_DIR"

cp "$binary" "${staging_dir}/netbird-relay/bin/netbird-relay"
cp "${ROOT_DIR}/relay/netbird-relay.service" "${staging_dir}/netbird-relay/services/netbird-relay.service"
cp "${ROOT_DIR}/relay/netbird-relay.openrc" "${staging_dir}/netbird-relay/services/netbird-relay.openrc"

cat > "${staging_dir}/netbird-relay/VERSION" <<EOF
NETBIRD_RELAY_REF=${NETBIRD_RELAY_REF}
TARGET_OS=${TARGET_OS}
TARGET_ARCH=${TARGET_ARCH}
EOF

tar -C "$staging_dir" -czf "${PACKAGE_DIR}/${package_name}" netbird-relay
printf 'Packaged: %s\n' "${PACKAGE_DIR}/${package_name}" >&2
