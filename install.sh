#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/kos991/net_relay.git}"
ARCHIVE_URL="${ARCHIVE_URL:-https://github.com/kos991/net_relay/archive/refs/heads/main.tar.gz}"
INSTALL_DIR="${INSTALL_DIR:-/opt/netbird-relay-installer}"
BRANCH="${BRANCH:-main}"

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

need_root_for_install_dir() {
  if [[ "${EUID}" -ne 0 && "$INSTALL_DIR" == /opt/* ]]; then
    fail "Run as root, or set INSTALL_DIR to a writable path."
  fi
}

download_with_tarball() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$ARCHIVE_URL" -o "$tmp_dir/repo.tar.gz"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$tmp_dir/repo.tar.gz" "$ARCHIVE_URL"
  else
    fail "Need git, curl, or wget to download the installer."
  fi

  rm -rf "$INSTALL_DIR"
  mkdir -p "$INSTALL_DIR"
  tar -xzf "$tmp_dir/repo.tar.gz" -C "$tmp_dir"
  shopt -s dotglob nullglob
  mv "$tmp_dir"/net_relay-*/* "$INSTALL_DIR"/
  rm -rf "$tmp_dir"
}

sync_repo() {
  mkdir -p "$(dirname "$INSTALL_DIR")"

  if command -v git >/dev/null 2>&1; then
    if [[ -d "$INSTALL_DIR/.git" ]]; then
      log "Updating installer in ${INSTALL_DIR} ..."
      git -C "$INSTALL_DIR" fetch --depth 1 origin "$BRANCH"
      git -C "$INSTALL_DIR" reset --hard "origin/${BRANCH}"
    else
      rm -rf "$INSTALL_DIR"
      log "Cloning installer to ${INSTALL_DIR} ..."
      git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$INSTALL_DIR"
    fi
  else
    warn "git not found, downloading source archive instead ..."
    download_with_tarball
  fi
}

need_root_for_install_dir
sync_repo
chmod +x "$INSTALL_DIR/setup-relay.sh"

log "Running installer from ${INSTALL_DIR} ..."
cd "$INSTALL_DIR"
exec ./setup-relay.sh

