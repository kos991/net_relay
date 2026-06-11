#!/usr/bin/env bash
set -euo pipefail
[[ "${TRACE_CHECKS:-0}" == "1" ]] && set -x

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIRSTBOOT="${ROOT_DIR}/ova/files/net-relay-firstboot"
RELS="${ROOT_DIR}/ova/files/rels"
SETUP="${ROOT_DIR}/setup-relay.sh"
INSTALL="${ROOT_DIR}/install.sh"
MAIN="${ROOT_DIR}/main.sh"
ROOT_PROFILE="${ROOT_DIR}/ova/files/root-profile"
LOCALE_PROFILE="${ROOT_DIR}/ova/files/00-net-relay-locale.sh"
WORKER="${ROOT_DIR}/worker/rels-worker.js"
DEPLOY_WORKER="${ROOT_DIR}/.github/workflows/deploy-worker.yml"
ZRAM_SETUP="${ROOT_DIR}/ova/files/setup-zram"
KERNEL_TUNING="${ROOT_DIR}/ova/files/setup-kernel-tuning"
BOOTLOADER_SETUP="${ROOT_DIR}/ova/files/setup-bootloader"
ROOT_RESIZE="${ROOT_DIR}/ova/files/setup-root-resize"
NETWORK_CHECK="${ROOT_DIR}/ova/files/setup-network-check"
VIRTIO_MODULES="${ROOT_DIR}/ova/files/virtio-modules.conf"
BUILD_RELAY="${ROOT_DIR}/relay/build-relay.sh"
PACKAGE_RELAY="${ROOT_DIR}/relay/package-relay.sh"
SYSTEMD_SERVICE="${ROOT_DIR}/relay/netbird-relay.service"
OPENRC_SERVICE="${ROOT_DIR}/relay/netbird-relay.openrc"
LOGIN_CFG="${ROOT_DIR}/ova/files/99-net-relay-login.cfg"
BUILD_OVA="${ROOT_DIR}/.github/workflows/build-ova.yml"
VALIDATE_WORKFLOW="${ROOT_DIR}/.github/workflows/validate.yml"
SYNC_OFFICIAL="${ROOT_DIR}/.github/workflows/sync-official-relay.yml"
SYSCTL_CONF="${ROOT_DIR}/ova/files/99-net-relay-sysctl.conf"
SSHD_CONFIG="${ROOT_DIR}/ova/files/sshd_config"
CADDY_DOCKERFILE="${ROOT_DIR}/caddy/Dockerfile"
SYNC_DOCKERFILE="${ROOT_DIR}/sync/Dockerfile"
SYNC_CERTS_SCRIPT="${ROOT_DIR}/sync/sync-relay-certs.sh"
RELAY_DOCKERFILE="${ROOT_DIR}/relay/Dockerfile"

find_python() {
  local candidate
  for candidate in python3 python; do
    if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c 'import sys; raise SystemExit(0 if sys.version_info[0] == 3 else 1)' >/dev/null 2>&1; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  echo "Python 3 is required to check release asset visibility." >&2
  return 1
}

PYTHON_BIN="$(find_python)"

bash -n "$FIRSTBOOT"
bash -n "$RELS"
bash -n "$SETUP"
bash -n "$INSTALL"
bash -n "$BUILD_RELAY"
bash -n "$PACKAGE_RELAY"
bash -n "$SYNC_CERTS_SCRIPT"
bash -n "$ZRAM_SETUP"
bash -n "$KERNEL_TUNING"
bash -n "$BOOTLOADER_SETUP"
bash -n "$ROOT_RESIZE"
bash -n "$NETWORK_CHECK"
sh -n "$MAIN"
bash -n "$ROOT_PROFILE"
sh -n "$LOCALE_PROFILE"

grep -q "NetBird Relay OVA First Boot Wizard" "$FIRSTBOOT"
grep -q "First boot steps" "$FIRSTBOOT"
grep -q "\\[1/5\\] Environment preflight" "$FIRSTBOOT"
grep -q "\\[2/5\\] Root partition resize" "$FIRSTBOOT"
grep -q "\\[3/5\\] Network self-check" "$FIRSTBOOT"
grep -q "\\[4/5\\] ZRAM and kernel tuning" "$FIRSTBOOT"
grep -q "\\[5/5\\] Relay setup wizard" "$FIRSTBOOT"
grep -q "Run rels to open the management menu again" "$FIRSTBOOT"
grep -q "Running OVA boot preflight checks" "$FIRSTBOOT"
grep -q "Preflight checks completed" "$FIRSTBOOT"
grep -q "Multi-node Relay groups" "$FIRSTBOOT"
grep -q "Run rels to open the management menu again" "$FIRSTBOOT"
grep -q "netbird-relay binary is missing" "$FIRSTBOOT"
grep -q "setup-root-resize" "$FIRSTBOOT"
grep -q "setup-network-check" "$FIRSTBOOT"
grep -q "setup-zram" "$FIRSTBOOT"
grep -q "setup-kernel-tuning" "$FIRSTBOOT"

grep -q "NetBird Relay" "$RELS"
grep -q "show_certificate_status" "$RELS"
grep -q "show_system_optimization_status" "$RELS"
grep -q "zramctl" "$RELS"
grep -q "tcp_congestion_control" "$RELS"
grep -q "openssl x509" "$RELS"

grep -q "acme.sh" "$SETUP"
grep -q "NetBird Relay Setup Wizard" "$SETUP"
grep -q "Relay node group mode" "$SETUP"
grep -q "Select certificate mode" "$SETUP"
grep -q "Setup completed" "$SETUP"
grep -q "dns_cf" "$SETUP"
grep -q "CF_Token" "$SETUP"
grep -q -- "--reloadcmd" "$SETUP"
grep -q "restart_service" "$SETUP"
grep -q "select_relay_group_mode" "$SETUP"
grep -q "RELAY_GROUP_MODE" "$SETUP"
grep -q "create" "$SETUP"
grep -q "join" "$SETUP"
grep -q "read_relay_auth_secret" "$SETUP"
grep -Fq 'if [[ "$RELAY_GROUP_MODE" == "join" && -z "$RELAY_AUTH_SECRET" ]]' "$SETUP"
grep -q "Joining an existing Relay node group requires an existing secret" "$SETUP"
grep -q "mode_label" "$SETUP"
grep -q "relays.addresses" "$SETUP"
grep -q "restart_service" "$SETUP"
grep -q "systemctl enable --now netbird-relay" "$SETUP"
grep -q "rc-update add netbird-relay default" "$SETUP"
grep -q "ensure_service_user" "$SETUP"
grep -q "mask_secret" "$SETUP"
grep -q "DEPLOY_MODE" "$SETUP"
grep -q "write_compose_file" "$SETUP"
grep -q "docker compose -f" "$SETUP"
grep -q "RELAY_IMAGE" "$SETUP"
grep -q "CADDY_IMAGE" "$SETUP"
grep -q "SYNC_IMAGE" "$SETUP"
grep -q "COMPOSE_STACK_ENV_FILE" "$SETUP"
grep -q "crpi-9kn2o1el6okkk1mu.cn-shanghai.personal.cr.aliyuncs.com/netrels/netrels:relay" "$SETUP"
grep -q "crpi-9kn2o1el6okkk1mu.cn-shanghai.personal.cr.aliyuncs.com/netrels/netrels:caddy" "$SETUP"
grep -q "crpi-9kn2o1el6okkk1mu.cn-shanghai.personal.cr.aliyuncs.com/netrels/netrels:sync" "$SETUP"
grep -q "netbird-caddy-cert" "$SETUP"
grep -q "netbird-relay-cert-sync" "$SETUP"
if grep -q "image: netbirdio/relay" "$SETUP"; then
  echo "Compose mode must default to the Aliyun custom relay image, not Docker Hub netbirdio/relay." >&2
  exit 1
fi

grep -q "root-password-confirmed" "$ROOT_PROFILE"
grep -q "ROOT_PASSWORD_CONFIRM_FLAG" "$ROOT_PROFILE"
grep -q "passwd root" "$ROOT_PROFILE"
grep -q "First login requires changing the root password" "$ROOT_PROFILE"
grep -q "expire: true" "$LOGIN_CFG"
grep -q "LANG=C.UTF-8" "$LOCALE_PROFILE"
grep -q "LC_ALL=C.UTF-8" "$LOCALE_PROFILE"
grep -q "TZ=Asia/Shanghai" "$LOCALE_PROFILE"

grep -q "chage -d 0 root" "$BUILD_OVA"
grep -q "Keep only latest release" "$BUILD_OVA"
grep -q "gh release delete" "$BUILD_OVA"
grep -q -- "--cleanup-tag" "$BUILD_OVA"
grep -q "release_channel" "$BUILD_OVA"
grep -q "publish_release" "$BUILD_OVA"
grep -q "github.event.inputs.publish_release != 'false'" "$BUILD_OVA"
grep -q "v0.1" "$BUILD_OVA"
grep -q "v1.0" "$BUILD_OVA"
grep -q -- "--prerelease" "$BUILD_OVA"
grep -q "tag_prefix" "$BUILD_OVA"
grep -q "Build official NetBird relay binaries" "$BUILD_OVA"
grep -q "OVA_NAME" "$BUILD_OVA"
grep -q "RAW_NAME" "$BUILD_OVA"
grep -q "IMAGE_ASSETS" "$BUILD_OVA"
grep -q "IMAGE_SIZE_MIB" "$BUILD_OVA"
grep -q "MIN_ROOT_FREE_MIB" "$BUILD_OVA"
grep -q "net-relay-alpine-x86_64.ova" "$BUILD_OVA"
grep -q "net-relay-alpine-x86_64.raw" "$BUILD_OVA"
if grep -Eqi "VHD_NAME|\\.vhd|fixed VHD|fixed-size VHD|qemu-img convert -p -O vpc" "$BUILD_OVA" "$WORKER"; then
  echo "VHD release assets are not supported; publish OVA and RAW tar.xz only." >&2
  exit 1
fi
if grep -Eq "raw\\.img\\.gz|gzip -9 release/net-relay-alpine-x86_64\\.raw\\.img|gzip -cd" "$BUILD_OVA"; then
  echo "Aliyun RAW assets must be published as uncompressed whole-disk .raw files, not .raw.img.gz." >&2
  exit 1
fi
if grep -Eq "OVA_MINIMAL_NAME|minimal\\.ova|minimal\\.ovf|net-relay-alpine-x86_64-minimal" "$BUILD_OVA"; then
  echo "Do not build or publish minimal OVA variants." >&2
  exit 1
fi
if grep -Eq 'gh release create(.|[[:space:]])*release/[^ ]+\\.ovf' "$BUILD_OVA"; then
  echo "Do not publish standalone OVF files; OVF belongs inside the OVA only." >&2
  exit 1
fi
grep -q "SSH port:" "$BUILD_OVA"
grep -q "ssh -p" "$BUILD_OVA"
grep -q "OVA_APK_PACKAGES" "$BUILD_OVA"
grep -q "apk fetch --recursive" "$BUILD_OVA"
grep -q "apk add --no-network --allow-untrusted" "$BUILD_OVA"
grep -q "apk add --no-network --allow-untrusted --upgrade" "$BUILD_OVA"
grep -q -- "--copy-in ova-build/apks:/tmp" "$BUILD_OVA"
grep -q "apk add --no-cache bash curl ca-certificates" "$MAIN"
grep -q "ca-certificates" "$BUILD_OVA"
grep -q "sudo" "$BUILD_OVA"
grep -q "wget" "$BUILD_OVA"
grep -q "openssh-server" "$BUILD_OVA"
grep -q "cloud-init" "$BUILD_OVA"
grep -q "cloud-init-openrc" "$BUILD_OVA"
grep -q "qemu-guest-agent" "$BUILD_OVA"
grep -q "qemu-guest-agent-openrc" "$BUILD_OVA"
grep -q "syslinux" "$BUILD_OVA"
grep -q "qemu-system-x86" "$BUILD_OVA"
grep -q "procps-ng" "$BUILD_OVA"
grep -q "parted" "$BUILD_OVA"
grep -q "xfsprogs" "$BUILD_OVA"
grep -q "btrfs-progs" "$BUILD_OVA"
grep -q "gnutls" "$BUILD_OVA"
grep -q "tzdata" "$BUILD_OVA"
grep -q "Asia/Shanghai" "$BUILD_OVA"
grep -q "00-net-relay-locale.sh" "$BUILD_OVA"
grep -q "virtio-modules.conf" "$BUILD_OVA"
grep -q "setup-cloud-init" "$BUILD_OVA"
grep -q "rc-update add qemu-guest-agent default" "$BUILD_OVA"
grep -q "/etc/profile.d" "$BUILD_OVA"
if grep -Eq "font-noto-cjk|fontconfig|musl-locales|musl-locales-lang|fc-cache" "$BUILD_OVA"; then
  echo "OVA image must not embed CJK fonts or locale packages that bloat the image." >&2
  exit 1
fi
grep -q "virt-customize --no-network" "$BUILD_OVA"
if grep -q "virt-customize --format qcow2" "$BUILD_OVA"; then
  echo "OVA customization must not require libguestfs guest networking on GitHub runners." >&2
  exit 1
fi
grep -q "ln -sf /usr/local/sbin/rels /usr/local/bin/rels" "$BUILD_OVA"
grep -q "Enables ZRAM swap" "$BUILD_OVA"
grep -q "kernel tuning profile" "$BUILD_OVA"
grep -q "AddressOnParent" "$BUILD_OVA"
grep -q "rasd:Connection" "$BUILD_OVA"
grep -q "setup-root-resize" "$BUILD_OVA"
grep -q "setup-network-check" "$BUILD_OVA"
grep -q "setup-zram" "$BUILD_OVA"
grep -q "setup-kernel-tuning" "$BUILD_OVA"
grep -q "setup-bootloader" "$BUILD_OVA"
grep -q "part-init /dev/sdb mbr" "$BUILD_OVA"
grep -q "part-set-bootable /dev/sdb 1 true" "$BUILD_OVA"
grep -q "copy-device-to-device /dev/sda /dev/sdb1" "$BUILD_OVA"
grep -q "resize2fs /dev/sdb1" "$BUILD_OVA"
grep -q "Verify RAW BIOS bootability" "$BUILD_OVA"
grep -q "virt-df -m" "$BUILD_OVA"
grep -q "RAW root partition must keep at least" "$BUILD_OVA"
grep -q "sfdisk --verify" "$BUILD_OVA"
grep -q "fdisk -l" "$BUILD_OVA"
grep -q "RAW image is missing a bootable MBR partition" "$BUILD_OVA"
grep -q "No bootable device" "$BUILD_OVA"
grep -q "qemu-img convert -p -O raw" "$BUILD_OVA"
grep -q "Package RAW tar.xz image" "$BUILD_OVA"
grep -q "tar -C release -cJf" "$BUILD_OVA"
grep -q 'rm -f "release/${RAW_NAME}"' "$BUILD_OVA"
grep -q '"release/${RAW_NAME}"' "$BUILD_OVA"
grep -q '"$RAW_NAME"' "$BUILD_OVA"
grep -Fq '"${RAW_NAME}.tar.xz"' "$BUILD_OVA"
if grep -Eq 'QCOW2_NAME|net-relay-alpine-x86_64\.qcow2\.gz|qemu-img convert -p -O qcow2|release/\$\{QCOW2_NAME\}|\\"\$QCOW2_NAME\\"' "$BUILD_OVA"; then
  echo "QCOW2 release assets are not supported; publish RAW for cloud import instead." >&2
  exit 1
fi
grep -q "TRIVY_VERSION" "$BUILD_OVA"
grep -q "TRIVY_CHECKSUM" "$BUILD_OVA"
grep -q 'go-version: "1.25.11"' "$BUILD_OVA"
grep -q "Install Trivy" "$BUILD_OVA"
grep -q "sha256sum -c" "$BUILD_OVA"
grep -q "Scan relay source with govulncheck" "$BUILD_OVA"
grep -q "go install golang.org/x/vuln/cmd/govulncheck" "$BUILD_OVA"
grep -q "Scan release workspace with Trivy" "$BUILD_OVA"
grep -q "Upload release workspace Trivy report" "$BUILD_OVA"
grep -q "trivy-fs-failure-report" "$BUILD_OVA"
grep -q "Scan Alpine rootfs with Trivy" "$BUILD_OVA"
grep -q "Generate release SBOM" "$BUILD_OVA"
grep -q "trivy rootfs" "$BUILD_OVA"
grep -q -- "--pkg-types os" "$BUILD_OVA"
grep -q "trivy fs" "$BUILD_OVA"
grep -q "trivy filesystem" "$BUILD_OVA"
grep -q "trivy sbom" "$BUILD_OVA"
grep -q "cyclonedx" "$BUILD_OVA"
grep -q "trivy-rootfs.json" "$BUILD_OVA"
grep -q "trivy-fs.json" "$BUILD_OVA"
grep -q "net-relay-sbom.cdx.json" "$BUILD_OVA"
grep -q "release/trivy-rootfs.json" "$BUILD_OVA"
grep -q "trap cleanup_rootfs EXIT" "$BUILD_OVA"
grep -q "Vulnerabilities" "$BUILD_OVA"
grep -q "release/trivy-fs.json" "$BUILD_OVA"
grep -q "release/net-relay-sbom.cdx.json" "$BUILD_OVA"
grep -q "CRITICAL,HIGH" "$BUILD_OVA"
grep -Fq '"${IMAGE_ASSETS[@]}"' "$BUILD_OVA"
grep -q "mapfile -t IMAGE_ASSETS < release/IMAGE_ASSETS.txt" "$BUILD_OVA"
grep -q "image_release_args" "$BUILD_OVA"
"$PYTHON_BIN" - "$BUILD_OVA" <<'PY'
from pathlib import Path
import sys

workflow = Path(sys.argv[1]).read_text(encoding="utf-8")

publish_block = workflow.split("gh release create", 1)[1].split("\n\n", 1)[0]
hidden_assets = (
    "release/trivy-fs.json",
    "release/net-relay-sbom.cdx.json",
    "release/${INSTALLER_ARCHIVE_NAME}",
    "release/${RAW_NAME}",
)
for asset in hidden_assets:
    if asset in publish_block:
        print(f"{asset} must not be attached as a visible GitHub Release asset.", file=sys.stderr)
        raise SystemExit(1)

notes = workflow.split("cat > release/RELEASE_NOTES.md <<EOF", 1)[1].split("\n          EOF", 1)[0]
for asset in (
    "trivy-fs.json",
    "net-relay-sbom.cdx.json",
    "net_relay-main.tar.gz",
    "${RAW_NAME}: uncompressed",
    "VHD",
    ".vhd",
):
    if asset in notes:
        print(f"{asset} must not be shown in Release notes published assets.", file=sys.stderr)
        raise SystemExit(1)

if '"${image_release_args[@]}"' not in publish_block:
    print("Image assets must be attached to the GitHub Release through image_release_args.", file=sys.stderr)
    raise SystemExit(1)

image_assets_block = workflow.split("IMAGE_ASSETS=(", 1)[1].split(")", 1)[0]
image_assets = [
    line.strip()
    for line in image_assets_block.splitlines()
    if line.strip()
]
expected_image_assets = ['"${RAW_NAME}.tar.xz"']
if image_assets != expected_image_assets:
    print(
        f"Release image assets must be exactly {expected_image_assets}, got {image_assets}.",
        file=sys.stderr,
    )
    raise SystemExit(1)
PY
grep -q "cp main.sh release/main.sh" "$BUILD_OVA"
grep -q '"release/main.sh"' "$BUILD_OVA"
grep -q "netbird-relay-linux-amd64.tar.gz" "$BUILD_OVA"
grep -q "netbird-relay-linux-arm64.tar.gz" "$BUILD_OVA"
grep -q "R2_RELEASE_BASE" "$BUILD_OVA"
grep -q "CLOUDFLARE_R2_BUCKET" "$BUILD_OVA"
grep -q "Verify Cloudflare R2 S3 credentials" "$BUILD_OVA"
grep -q "_permission-test/github-actions-" "$BUILD_OVA"
grep -q "Sync release assets to Cloudflare R2" "$BUILD_OVA"
grep -q 's3://${CLOUDFLARE_R2_BUCKET}/latest' "$BUILD_OVA"
grep -q 's3://${CLOUDFLARE_R2_BUCKET}/releases/' "$BUILD_OVA"

grep -q "growpart" "$ROOT_RESIZE"
grep -q "apt_run" "$ROOT_RESIZE"
grep -q "flock /var/lib/dpkg/lock-frontend" "$ROOT_RESIZE"
grep -q "resize2fs" "$ROOT_RESIZE"
grep -q "xfs_growfs" "$ROOT_RESIZE"

grep -q "virtio_net" "$NETWORK_CHECK"
grep -q "virtio_blk" "$NETWORK_CHECK"
grep -q "virtio_scsi" "$NETWORK_CHECK"
grep -q "virtio_pci" "$NETWORK_CHECK"
grep -q "virtio_balloon" "$NETWORK_CHECK"
grep -q "virtio_console" "$NETWORK_CHECK"
grep -q "e1000" "$NETWORK_CHECK"
grep -q "e1000e" "$NETWORK_CHECK"
grep -q "vmxnet3" "$NETWORK_CHECK"
grep -q "xen_netfront" "$NETWORK_CHECK"
grep -q "ena" "$NETWORK_CHECK"
grep -q "hv_netvsc" "$NETWORK_CHECK"
grep -q "gve" "$NETWORK_CHECK"
grep -q "udhcpc" "$NETWORK_CHECK"
grep -q "ip route" "$NETWORK_CHECK"

grep -q "virtio_net" "$VIRTIO_MODULES"
grep -q "virtio_blk" "$VIRTIO_MODULES"
grep -q "virtio_scsi" "$VIRTIO_MODULES"
grep -q "virtio_pci" "$VIRTIO_MODULES"
grep -q "virtio_balloon" "$VIRTIO_MODULES"
grep -q "virtio_console" "$VIRTIO_MODULES"

grep -q "apt_run" "$ZRAM_SETUP"
grep -q "flock /var/lib/dpkg/lock-frontend" "$ZRAM_SETUP"
grep -q "write_zram_start_script" "$ZRAM_SETUP"
grep -q "wait_for_zram_device" "$ZRAM_SETUP"
grep -q "require_cmd" "$ZRAM_SETUP"
grep -q "verify_zram_swap" "$ZRAM_SETUP"
grep -q "zram-optimize.sh" "$ZRAM_SETUP"
grep -q "vm.swappiness=100" "$ZRAM_SETUP"
grep -q "vm.page-cluster=0" "$ZRAM_SETUP"
grep -q "/etc/init.d/zram" "$ZRAM_SETUP"
grep -q "rc-update add zram default" "$ZRAM_SETUP"
grep -q "rc-service zram restart" "$ZRAM_SETUP"
grep -q "swapon --show=NAME --noheadings" "$ZRAM_SETUP"
grep -q "/dev/zram0" "$ZRAM_SETUP"
grep -q "0 3 \\* \\* \\* /usr/local/bin/zram-optimize.sh" "$ZRAM_SETUP"

if grep -Eq "rc-service[[:space:]]+zram-init|rc-update[[:space:]]+add[[:space:]]+zram-init" "$ZRAM_SETUP"; then
  echo "Alpine zram setup must not rely on a zram-init OpenRC service that is not shipped by the package." >&2
  exit 1
fi

if grep -Eq "apk[[:space:]]+add" "$ZRAM_SETUP"; then
  echo "OVA firstboot zram setup must not run apk add; dependencies are preinstalled offline during image build." >&2
  exit 1
fi

grep -q "sysctl --system" "$KERNEL_TUNING"
grep -q "extlinux --install" "$BOOTLOADER_SETUP"
grep -q "mbr.bin" "$BOOTLOADER_SETUP"
grep -q "root=UUID=" "$BOOTLOADER_SETUP"
grep -q "console=ttyS0" "$BOOTLOADER_SETUP"
grep -q "net.core.somaxconn = 4096" "$SYSCTL_CONF"
grep -q "net.core.netdev_max_backlog = 5000" "$SYSCTL_CONF"
grep -q "net.core.default_qdisc = fq" "$SYSCTL_CONF"
grep -q "net.ipv4.tcp_congestion_control = bbr" "$SYSCTL_CONF"
grep -q "net.core.rmem_max = 16777216" "$SYSCTL_CONF"
grep -q "net.core.wmem_max = 16777216" "$SYSCTL_CONF"
grep -q "net.ipv4.udp_rmem_min = 8192" "$SYSCTL_CONF"
grep -q "net.ipv4.udp_wmem_min = 8192" "$SYSCTL_CONF"
grep -q "net.ipv4.tcp_keepalive_time = 120" "$SYSCTL_CONF"
grep -q "net.ipv4.ip_local_port_range = 10000 65535" "$SYSCTL_CONF"
grep -q "vm.page-cluster = 0" "$SYSCTL_CONF"

grep -q "detect_os" "$INSTALL"
grep -q "detect_arch" "$INSTALL"
grep -q "detect_install_mode" "$INSTALL"
grep -q "select_install_mode" "$INSTALL"
grep -q "Select install mode" "$INSTALL"
grep -q "Official binary install" "$INSTALL"
grep -q "Docker Compose" "$INSTALL"
grep -q "download_relay_package" "$INSTALL"
grep -q "verify_sha256" "$INSTALL"
grep -q "install_relay_binary" "$INSTALL"
grep -q "install_compose_dependencies" "$INSTALL"
grep -q "INSTALL_MODE" "$INSTALL"
grep -q "compose" "$INSTALL"
grep -q "DEFAULT_RELEASE_BASES" "$INSTALL"
grep -q "RELS_R2_RELEASE_BASE" "$INSTALL"
grep -q "R2_RELEASE_BASE" "$INSTALL"
grep -q "download_relay_package_from_base" "$INSTALL"
grep -q "release base failed" "$INSTALL"
if grep -Eq "gh\\.llkk\\.cc|ghproxy\\.net" "$INSTALL" "$MAIN" "$BUILD_OVA"; then
  echo "Default installer download sources must use R2 and GitHub only; do not rely on public GitHub proxy mirrors." >&2
  exit 1
fi
grep -q "enforce_install_mode_policy" "$INSTALL"
grep -q "Alpine uses official binary mode" "$INSTALL"
awk '
  /^main\(\) \{/ { in_main=1 }
  in_main && /enforce_install_mode_policy/ { policy=NR }
  in_main && /select_install_mode/ { menu=NR }
  END {
    if (!policy || !menu || policy > menu) {
      print "Alpine policy must run before the install mode menu is shown." > "/dev/stderr"
      exit 1
    }
  }
' "$INSTALL"
if grep -q "docker-cli-compose" "$INSTALL"; then
  echo "Alpine installer must not install Docker Compose; Alpine uses binary mode only." >&2
  exit 1
fi
grep -q "netbird-relay-linux-\${arch}.tar.gz" "$INSTALL"
grep -q "VERSION_CODENAME" "$INSTALL"
grep -q "ID_LIKE" "$INSTALL"
grep -q "apt-get install" "$INSTALL"
grep -q 'pkg_manager="dnf"' "$INSTALL"
grep -q "apk add" "$INSTALL"
grep -q "cronie" "$INSTALL"
grep -q "cron" "$INSTALL"

grep -q "NETBIRD_RELAY_REF" "$BUILD_RELAY"
grep -q "GO_SECURITY_PATCH_MODULES" "$BUILD_RELAY"
grep -q "golang.org/x/net@v0.55.0" "$BUILD_RELAY"
grep -q "go get \"\${security_patch_modules\\[@\\]}\"" "$BUILD_RELAY"
grep -q "https://github.com/netbirdio/netbird.git" "$BUILD_RELAY"
grep -q "go build" "$BUILD_RELAY"
grep -q "./relay" "$BUILD_RELAY"
grep -q "netbird-relay-linux-" "$PACKAGE_RELAY"
grep -q "netbird-relay" "$SYSTEMD_SERVICE"
grep -q "User=netbird-relay" "$SYSTEMD_SERVICE"
grep -q "Group=netbird-relay" "$SYSTEMD_SERVICE"
grep -q "NoNewPrivileges=true" "$SYSTEMD_SERVICE"
grep -q "ProtectSystem=strict" "$SYSTEMD_SERVICE"
grep -q "command=/usr/local/bin/netbird-relay" "$OPENRC_SERVICE"
grep -q "command_user=\"netbird-relay:netbird-relay\"" "$OPENRC_SERVICE"
grep -q '#!/bin/sh' "$MAIN"
grep -q "ensure_bootstrap_tools" "$MAIN"
grep -q "apk add --no-cache bash curl ca-certificates" "$MAIN"
grep -q "validate_install_url" "$MAIN"
grep -q "verify_install_sha256" "$MAIN"
grep -q "actual_hash" "$MAIN"
grep -q "SHA256SUMS" "$MAIN"
grep -q "curl -sSL https://github.com/kos991/net_relay/releases/latest/download/main.sh | sh" "${ROOT_DIR}/README.md"
grep -q "镜像不内置 Docker/Compose" "${ROOT_DIR}/README.md"
grep -q "GPL-3.0" "${ROOT_DIR}/README.md"
grep -q "GNU GENERAL PUBLIC LICENSE" "${ROOT_DIR}/LICENSE"
grep -q 'proxyAsset("main.sh", env, false)' "$WORKER"
grep -q 'proxyAsset("install.sh", env)' "$WORKER"
grep -q "getReleaseBase" "$WORKER"
grep -q "env.R2_RELEASE_BASE" "$WORKER"
grep -q "signR2Request" "$WORKER"
grep -q "R2_ACCESS_KEY_ID" "$WORKER"
grep -q "R2_SECRET_ACCESS_KEY" "$WORKER"
grep -q "latest/main.sh" "$WORKER"
grep -q "releases/" "$WORKER"
grep -q "R2_RELEASE_BASE" "$DEPLOY_WORKER"
grep -q "wrangler secret put R2_RELEASE_BASE" "$DEPLOY_WORKER"
grep -q "wrangler secret put R2_ACCESS_KEY_ID" "$DEPLOY_WORKER"
grep -q "wrangler secret put R2_SECRET_ACCESS_KEY" "$DEPLOY_WORKER"
grep -q "Ensure Worker DNS record" "$DEPLOY_WORKER"
grep -q "zone_id:" "$DEPLOY_WORKER"
grep -q "CLOUDFLARE_ZONE_ID" "$DEPLOY_WORKER"
grep -q 'zone_id="${ZONE_ID:-}"' "$DEPLOY_WORKER"
grep -q "zones?name=" "$DEPLOY_WORKER"
grep -q "dns_records" "$DEPLOY_WORKER"
grep -q "deploy_command" "$DEPLOY_WORKER"
grep -q 'if \[ -n "${ROUTE}" \]' "$DEPLOY_WORKER"
grep -q "CLOUDFLARE_R2_BUCKET" "$DEPLOY_WORKER"
if grep -q "MAIN_SH =" "$WORKER"; then
  echo "Worker must proxy release/main.sh instead of embedding a stale bootstrap script." >&2
  exit 1
fi

grep -q "PubkeyAuthentication yes" "$SSHD_CONFIG"
grep -q "UsePAM yes" "$SSHD_CONFIG"
grep -q "MaxAuthTries 3" "$SSHD_CONFIG"

grep -q "validate_release_base" "$INSTALL"
grep -q "verify_tar_paths" "$INSTALL"
grep -q -- "--proto '=https'" "$INSTALL"
grep -q -- "--https-only" "$INSTALL"
grep -q "awk -v n=" "$INSTALL"
grep -q "选择语言" "$MAIN"
grep -q "选择安装模式" "$INSTALL"
grep -q "需要 root 权限" "$MAIN"
grep -q "需要 root 权限" "$INSTALL"
if LC_ALL=C.UTF-8 grep -Eq "闇€|閫夋嫨|璇烽|瀹夎|鏃犳硶|姝ｅ湪|涓嬭浇|鎴|锛|銆|€|�" "$MAIN" "$INSTALL"; then
  echo "Installer Chinese text must be valid UTF-8, not mojibake." >&2
  exit 1
fi

if grep -q "Relay auth secret: \${RELAY_AUTH_SECRET}" "$SETUP"; then
  echo "setup summary must not print relay auth secret in plaintext." >&2
  exit 1
fi

if LC_ALL=C.UTF-8 grep -R -n "[一-龥]" \
  "$FIRSTBOOT" "$RELS" "$ROOT_PROFILE" "$ZRAM_SETUP" "$KERNEL_TUNING" "$SETUP" "$LOCALE_PROFILE"; then
  echo "OVA console scripts must remain ASCII/English only." >&2
  exit 1
fi

if grep -Eq "curl[[:space:]]+https://get\\.acme\\.sh[[:space:]]*\\|[[:space:]]*sh|export[[:space:]]+CF_Token=" "$SETUP"; then
  echo "setup must not pipe acme.sh installer into sh or export CF_Token globally." >&2
  exit 1
fi

if grep -Eq 'User=root|Group=root|DynamicUser=no' "$SYSTEMD_SERVICE"; then
  echo "systemd service must not run netbird-relay as root." >&2
  exit 1
fi

if grep -Fq 'export $(grep' "$OPENRC_SERVICE"; then
  echo "OpenRC service must not load env files with export grep/xargs." >&2
  exit 1
fi

grep -q "name: sync-official-relay" "$SYNC_OFFICIAL"
grep -q "schedule:" "$SYNC_OFFICIAL"
grep -q "git ls-remote https://github.com/netbirdio/netbird.git" "$SYNC_OFFICIAL"
grep -q ".github/netbird-relay-upstream.sha" "$SYNC_OFFICIAL"
grep -q "gh workflow run build-ova" "$SYNC_OFFICIAL"
grep -q "netbird_relay_ref" "$SYNC_OFFICIAL"

grep -q "TRIVY_VERSION" "$VALIDATE_WORKFLOW"
grep -q "TRIVY_CHECKSUM" "$VALIDATE_WORKFLOW"
grep -q 'go-version: "1.25.11"' "$VALIDATE_WORKFLOW"
grep -q "Install Trivy" "$VALIDATE_WORKFLOW"
grep -q "sha256sum -c" "$VALIDATE_WORKFLOW"
grep -q "Scan repository with Trivy" "$VALIDATE_WORKFLOW"
grep -q "trivy fs" "$VALIDATE_WORKFLOW"
grep -q "Scan relay source with govulncheck" "$VALIDATE_WORKFLOW"
grep -q "go install golang.org/x/vuln/cmd/govulncheck" "$VALIDATE_WORKFLOW"
grep -q "CRITICAL,HIGH" "$VALIDATE_WORKFLOW"

grep -q "github.com/caddy-dns/cloudflare" "$CADDY_DOCKERFILE"
grep -q "COPY --from=builder /usr/bin/caddy /usr/bin/caddy" "$CADDY_DOCKERFILE"
grep -q "USER 65532:65532" "$CADDY_DOCKERFILE"
grep -q "sync-relay-certs.sh" "$SYNC_DOCKERFILE"
grep -q "curl" "$SYNC_DOCKERFILE"
grep -q "USER 65532:65532" "$SYNC_DOCKERFILE"
grep -q "DOCKER_SOCK_GID" "$SETUP"
grep -q "group_add" "$SETUP"
grep -q "RELAY_DOMAIN" "$SYNC_CERTS_SCRIPT"
grep -q "/var/run/docker.sock" "$SYNC_CERTS_SCRIPT"
grep -q "restart_relay" "$SYNC_CERTS_SCRIPT"
grep -q "FROM netbirdio/relay:latest" "$RELAY_DOCKERFILE"
grep -q "USER 65532:65532" "$RELAY_DOCKERFILE"

if [[ -e "${ROOT_DIR}/.github/workflows/sync-acr-relay-image.yml" ]]; then
  echo "relay image must be built by Aliyun ACR from relay/Dockerfile, not synced by GitHub Actions." >&2
  exit 1
fi

if grep -Eq "install_docker|docker-compose-plugin|docker-cli-compose|docker compose|docker-compose|netbirdio/relay" "$FIRSTBOOT" "$RELS" "$ZRAM_SETUP" "$KERNEL_TUNING" "$ROOT_RESIZE" "$NETWORK_CHECK"; then
  echo "OVA image scripts must not install or require Docker." >&2
  exit 1
fi

if grep -Eqi "docker|compose|sync-relay-certs" "$FIRSTBOOT" "$RELS" "$ZRAM_SETUP" "$KERNEL_TUNING" "$ROOT_RESIZE" "$NETWORK_CHECK"; then
  echo "Binary installer and OVA scripts must not contain Docker/Compose runtime text." >&2
  exit 1
fi

if grep -Eq "default_qdisc = cake|tc qdisc|tcp_retries2|nf_conntrack_udp_timeout|wg-quick|systemctl restart xray" "$SYSCTL_CONF" "$FIRSTBOOT" "$RELS" "$SETUP"; then
  echo "OVA scripts must not contain high-risk network tuning commands." >&2
  exit 1
fi

if grep -qi "VMware" "$FIRSTBOOT" "$RELS" "$SETUP"; then
  echo "OVA scripts must not contain VMware-specific text." >&2
  exit 1
fi

if grep -Eq "OVA_SSH_PORT\\.txt|OVA_ACCESS\\.md|## OVA ports" "$BUILD_OVA"; then
  echo "OVA SSH port must be published in release notes only, without extra access assets." >&2
  exit 1
fi

if grep -Eq "rasd:AutomaticAllocation" "$BUILD_OVA"; then
  echo "OVA OVF network adapter must avoid AutomaticAllocation for broad importer compatibility." >&2
  exit 1
fi
