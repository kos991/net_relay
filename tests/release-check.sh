#!/usr/bin/env bash
set -euo pipefail
[[ "${TRACE_CHECKS:-0}" == "1" ]] && set -x

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIRSTBOOT="${ROOT_DIR}/packaging/ova/files/net-relay-firstboot"
RELS="${ROOT_DIR}/packaging/ova/files/rels"
SETUP="${ROOT_DIR}/scripts/installer/setup-relay.sh"
INSTALL="${ROOT_DIR}/scripts/installer/install.sh"
ROOT_SETUP="${ROOT_DIR}/setup-relay.sh"
ROOT_INSTALL="${ROOT_DIR}/install.sh"
CERT_RELOAD="${ROOT_DIR}/scripts/certificate/reload-relay-certificate.sh"
MAIN="${ROOT_DIR}/main.sh"
ROOT_PROFILE="${ROOT_DIR}/packaging/ova/files/root-profile"
LOCALE_PROFILE="${ROOT_DIR}/packaging/ova/files/00-net-relay-locale.sh"
WORKER="${ROOT_DIR}/worker/rels-worker.js"
ZRAM_SETUP="${ROOT_DIR}/packaging/ova/files/setup-zram"
KERNEL_TUNING="${ROOT_DIR}/packaging/ova/files/setup-kernel-tuning"
ROOT_RESIZE="${ROOT_DIR}/packaging/ova/files/setup-root-resize"
NETWORK_CHECK="${ROOT_DIR}/packaging/ova/files/setup-network-check"
VIRTIO_MODULES="${ROOT_DIR}/packaging/ova/files/virtio-modules.conf"
BUILD_RELAY="${ROOT_DIR}/packaging/relay/build-relay.sh"
PACKAGE_RELAY="${ROOT_DIR}/packaging/relay/package-relay.sh"
SYSTEMD_SERVICE="${ROOT_DIR}/packaging/relay/netbird-relay.service"
OPENRC_SERVICE="${ROOT_DIR}/packaging/relay/netbird-relay.openrc"
LOGIN_CFG="${ROOT_DIR}/packaging/ova/files/99-net-relay-login.cfg"
CLOUD_DATASOURCES="${ROOT_DIR}/packaging/ova/files/98-net-relay-datasources.cfg"
BUILD_OVA="${ROOT_DIR}/.github/workflows/build-ova.yml"
DEPLOY_WORKER="${ROOT_DIR}/.github/workflows/deploy-worker.yml"
VALIDATE_WORKFLOW="${ROOT_DIR}/.github/workflows/validate.yml"
SYNC_OFFICIAL="${ROOT_DIR}/.github/workflows/sync-official-relay.yml"
TRIVY_IGNORE="${ROOT_DIR}/.trivyignore.yaml"
SYSCTL_CONF="${ROOT_DIR}/packaging/ova/files/99-net-relay-sysctl.conf"
SSHD_CONFIG="${ROOT_DIR}/packaging/ova/files/sshd_config"

bash -n "$FIRSTBOOT"
bash -n "$RELS"
bash -n "$SETUP"
bash -n "$INSTALL"
bash -n "$ROOT_SETUP"
bash -n "$ROOT_INSTALL"
bash -n "$CERT_RELOAD"
bash -n "$BUILD_RELAY"
bash -n "$PACKAGE_RELAY"
bash -n "$ZRAM_SETUP"
bash -n "$KERNEL_TUNING"
bash -n "$ROOT_RESIZE"
bash -n "$NETWORK_CHECK"
sh -n "$MAIN"
bash -n "$ROOT_PROFILE"
sh -n "$LOCALE_PROFILE"
node "$ROOT_DIR/tests/worker-check.mjs"

zh_header="$(RELS_LANG=zh bash -c 'source "$1"; print_header' _ "$SETUP" 2>&1)"
grep -Fq "NetBird Relay 配置向导" <<<"$zh_header"
grep -Fq "同一 Relay 节点组中的所有节点必须使用相同的密钥。" <<<"$zh_header"
zh_summary="$(RELS_LANG=zh bash -c '
  source "$1"
  RELAY_GROUP_MODE=create
  RELAY_DOMAIN=rels.example.com
  RELAY_PORT=9527
  STUN_PORT=3478
  RELAY_AUTH_SECRET=abcdefghijklmnop
  CERT_MODE=cloudflare
  TLS_CERT_FILE=/etc/netbird-relay/certs/fullchain.pem
  TLS_KEY_FILE=/etc/netbird-relay/certs/privkey.pem
  print_summary
' _ "$SETUP" 2>&1)"
grep -Fq "配置完成" <<<"$zh_summary"
grep -Fq "Relay 节点组模式：创建新的 Relay 节点组" <<<"$zh_summary"
en_prompt="$(RELS_LANG=en bash -c 'source "$1"; msg relay_domain' _ "$SETUP")"
zh_prompt="$(RELS_LANG=zh bash -c 'source "$1"; msg relay_domain' _ "$SETUP")"
grep -Fq "Relay domain" <<<"$en_prompt"
grep -Fq "Relay 域名" <<<"$zh_prompt"

grep -q "NetBird Relay OVA 首次启动向导" "$FIRSTBOOT"
grep -q "首次启动步骤" "$FIRSTBOOT"
grep -q "\\[1/5\\] 环境预检" "$FIRSTBOOT"
grep -q "\\[2/5\\] 根分区扩容" "$FIRSTBOOT"
grep -q "\\[3/5\\] 网络自检" "$FIRSTBOOT"
grep -q "\\[4/5\\] ZRAM 和内核调优" "$FIRSTBOOT"
grep -q "\\[5/5\\] Relay 配置向导" "$FIRSTBOOT"
grep -q "再次运行 rels" "$FIRSTBOOT"
grep -q "正在执行 OVA 启动预检" "$FIRSTBOOT"
grep -q "预检完成" "$FIRSTBOOT"
grep -q "多节点 Relay 组" "$FIRSTBOOT"
grep -q "未找到 netbird-relay 二进制文件" "$FIRSTBOOT"
grep -q "setup-root-resize" "$FIRSTBOOT"
grep -q "setup-network-check" "$FIRSTBOOT"
grep -q "setup-zram" "$FIRSTBOOT"
grep -q "setup-kernel-tuning" "$FIRSTBOOT"
grep -q "根分区扩容：" "$ROOT_RESIZE"
grep -q "网络自检：" "$NETWORK_CHECK"
grep -q "ZRAM：" "$ZRAM_SETUP"
grep -q "内核调优：" "$KERNEL_TUNING"

grep -q "NetBird Relay" "$RELS"
grep -q "show_certificate_status" "$RELS"
grep -q "show_system_optimization_status" "$RELS"
grep -q "zramctl" "$RELS"
grep -q "tcp_congestion_control" "$RELS"
grep -q "openssl x509" "$RELS"

grep -q "acme.sh" "$BUILD_OVA"
grep -q "acme.sh" "$SETUP"
grep -q "command -v acme.sh" "$SETUP"
grep -q "apk add --no-cache acme.sh" "$SETUP"
grep -q "NetBird Relay Setup Wizard" "$SETUP"
grep -Fq 'RELS_LANG="${RELS_LANG:-en}"' "$SETUP"
grep -q "is_zh()" "$SETUP"
grep -q "NetBird Relay 配置向导" "$SETUP"
grep -q "Relay 节点组模式" "$SETUP"
grep -q "请选择证书模式" "$SETUP"
grep -q "配置完成" "$SETUP"
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
grep -q "NB_HEALTH_LISTEN_ADDRESS=127.0.0.1:9000" "$SETUP"
grep -q "NB_METRICS_PORT=9090" "$SETUP"
grep -q "Relay and STUN cannot share the same UDP port" "$SETUP"
grep -q "Relay port must be 1024 or higher" "$SETUP"
grep -q "CERT_RELOAD_HOOK" "$SETUP"
grep -q "certificate and private key do not match" "$CERT_RELOAD"
grep -q "systemctl restart netbird-relay" "$CERT_RELOAD"
grep -q "rc-service netbird-relay restart" "$CERT_RELOAD"
grep -q 'scripts/installer/install.sh' "$ROOT_INSTALL"
grep -q 'scripts/installer/setup-relay.sh' "$ROOT_SETUP"

grep -q "root-password-confirmed" "$ROOT_PROFILE"
grep -q "ROOT_PASSWORD_CONFIRM_FLAG" "$ROOT_PROFILE"
grep -q "passwd root" "$ROOT_PROFILE"
grep -q "首次登录必须修改 root 密码" "$ROOT_PROFILE"
grep -q "expire: true" "$LOGIN_CFG"
grep -Fq "datasource_list: [ AliYun, NoCloud, ConfigDrive, None ]" "$CLOUD_DATASOURCES"
grep -q "LANG=C.UTF-8" "$LOCALE_PROFILE"
grep -q "LC_ALL=C.UTF-8" "$LOCALE_PROFILE"
grep -q "TZ=Asia/Shanghai" "$LOCALE_PROFILE"

grep -q "chage -d 0 root" "$BUILD_OVA"
grep -q "release_channel" "$BUILD_OVA"
grep -q "publish_release" "$BUILD_OVA"
grep -q "github.event.inputs.publish_release != 'false'" "$BUILD_OVA"
grep -q "v1.0" "$BUILD_OVA"
grep -q "tag_prefix" "$BUILD_OVA"
grep -q 'tags:' "$BUILD_OVA"
grep -q '"v1.\*"' "$BUILD_OVA"
grep -q "release/setup-relay.sh" "$BUILD_OVA"
grep -q "release/reload-relay-certificate.sh" "$BUILD_OVA"
grep -q "Resolve NetBird relay ref" "$BUILD_OVA"
grep -q ".github/netbird-relay-upstream.sha" "$BUILD_OVA"
if grep -Eq 'gh release delete|--cleanup-tag' "$BUILD_OVA"; then
  echo "Stable release history must not be deleted by the build workflow." >&2
  exit 1
fi
if grep -Eq 'v0\.|--prerelease|release_channel.*test' "$BUILD_OVA"; then
  echo "Release workflow must publish stable v1.0.N releases only." >&2
  exit 1
fi
grep -q "Build official NetBird relay binaries" "$BUILD_OVA"
grep -q "https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/cloud/" "$BUILD_OVA"
if grep -q "dev.alpinelinux.org/~tomalok" "$BUILD_OVA"; then
  echo "OVA builds must use Alpine's official release CDN, not the retired developer image path." >&2
  exit 1
fi
grep -q "OVA_NAME" "$BUILD_OVA"
grep -q "OVA_MINIMAL_NAME" "$BUILD_OVA"
grep -q "RAW_NAME" "$BUILD_OVA"
grep -q "VHD_NAME" "$BUILD_OVA"
grep -q "QCOW2_NAME" "$BUILD_OVA"
grep -q "net-relay-alpine-x86_64.ova" "$BUILD_OVA"
grep -q "net-relay-alpine-x86_64-minimal.ova" "$BUILD_OVA"
grep -q "net-relay-alpine-x86_64.raw.img.gz" "$BUILD_OVA"
grep -q "net-relay-alpine-x86_64.vhd.gz" "$BUILD_OVA"
grep -q "net-relay-alpine-x86_64.qcow2.gz" "$BUILD_OVA"
grep -q "SSH port:" "$BUILD_OVA"
grep -q "ssh -p" "$BUILD_OVA"
grep -q "OVA_APK_PACKAGES" "$BUILD_OVA"
grep -q "apk fetch --recursive" "$BUILD_OVA"
grep -q "BASE_APK_PACKAGES" "$BUILD_OVA"
grep -q 'virt-cat -a ova-build/alpine.qcow2 /lib/apk/db/installed' "$BUILD_OVA"
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
grep -q "procps-ng" "$BUILD_OVA"
grep -q "parted" "$BUILD_OVA"
grep -q "xfsprogs" "$BUILD_OVA"
grep -q "btrfs-progs" "$BUILD_OVA"
grep -q "gnutls" "$BUILD_OVA"
grep -q "tzdata" "$BUILD_OVA"
grep -q "Asia/Shanghai" "$BUILD_OVA"
grep -q "00-net-relay-locale.sh" "$BUILD_OVA"
grep -q "virtio-modules.conf" "$BUILD_OVA"
grep -q "98-net-relay-datasources.cfg" "$BUILD_OVA"
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
grep -q "write_ovf release/net-relay-alpine-x86_64-minimal.ovf ''" "$BUILD_OVA"
grep -q "setup-root-resize" "$BUILD_OVA"
grep -q "setup-network-check" "$BUILD_OVA"
grep -q "setup-zram" "$BUILD_OVA"
grep -q "setup-kernel-tuning" "$BUILD_OVA"
grep -q "qemu-img convert -p -O raw" "$BUILD_OVA"
grep -q "name: Verify OVA SSH port" "$BUILD_OVA"
grep -q "virt-cat -a ova-build/alpine.qcow2 /etc/ssh/sshd_config" "$BUILD_OVA"
grep -q 'echo "SSH_PORT=\${actual_ssh_port}" >> "\$GITHUB_ENV"' "$BUILD_OVA"
grep -q 'SSH port: \${SSH_PORT}' "$BUILD_OVA"
grep -q 'ssh -p \${SSH_PORT}' "$BUILD_OVA"
grep -q '"release/${RAW_NAME}"' "$BUILD_OVA"
grep -q '"$RAW_NAME"' "$BUILD_OVA"
grep -q "qemu-img convert -p -O vpc ova-build/alpine.qcow2" "$BUILD_OVA"
grep -q "qemu-img convert -p -O qcow2 -o compat=1.1" "$BUILD_OVA"
grep -q 'qemu-img info --output=json release/net-relay-alpine-x86_64.vhd' "$BUILD_OVA"
grep -Fq '.format == "vpc"' "$BUILD_OVA"
grep -q '"release/${VHD_NAME}"' "$BUILD_OVA"
grep -q '"release/${QCOW2_NAME}"' "$BUILD_OVA"
grep -q '"$VHD_NAME"' "$BUILD_OVA"
grep -q '"$QCOW2_NAME"' "$BUILD_OVA"
grep -q "TRIVY_VERSION" "$BUILD_OVA"
grep -q "TRIVY_CHECKSUM" "$BUILD_OVA"
grep -q 'go-version: "1.25.13"' "$BUILD_OVA"
grep -q "Install Trivy" "$BUILD_OVA"
grep -q "sha256sum -c" "$BUILD_OVA"
grep -q "Scan relay source with govulncheck" "$BUILD_OVA"
grep -q "go install golang.org/x/vuln/cmd/govulncheck" "$BUILD_OVA"
grep -q "Scan release workspace with Trivy" "$BUILD_OVA"
grep -q "Scan Alpine rootfs with Trivy" "$BUILD_OVA"
grep -q "Generate release SBOM" "$BUILD_OVA"
grep -q "trivy rootfs" "$BUILD_OVA"
grep -q -- "--pkg-types os" "$BUILD_OVA"
grep -q "trivy fs" "$BUILD_OVA"
grep -q -- "--ignorefile .trivyignore.yaml" "$BUILD_OVA"
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
grep -q "cp main.sh release/main.sh" "$BUILD_OVA"
grep -q '"release/main.sh"' "$BUILD_OVA"
grep -q "netbird-relay-linux-amd64.tar.gz" "$BUILD_OVA"
grep -q "netbird-relay-linux-arm64.tar.gz" "$BUILD_OVA"

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
grep -q "validate_args" "$INSTALL"
grep -q "download_relay_package" "$INSTALL"
grep -q "verify_sha256" "$INSTALL"
grep -q "install_relay_binary" "$INSTALL"
grep -q "install_installer_asset" "$INSTALL"
grep -Fq 'if [[ "$source_file" == "$destination" ]]' "$INSTALL"
grep -q "reload-relay-certificate.sh" "$INSTALL"
if grep -Eq 'install_compose_dependencies|docker\.io|docker-cli-compose|docker-compose-plugin|docker compose version' "$INSTALL"; then
  echo "Installer must not install or run Docker/Compose." >&2
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
grep -q "golang.org/x/net@v0.58.0" "$BUILD_RELAY"
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
grep -q "curl -sSL https://rels.jinfei.org | sh" "${ROOT_DIR}/README.md"
grep -q "镜像不内置 Docker、Compose 或 Caddy" "${ROOT_DIR}/README.md"
grep -q "GPL-3.0" "${ROOT_DIR}/README.md"
grep -q "GNU GENERAL PUBLIC LICENSE" "${ROOT_DIR}/LICENSE"
grep -q 'proxyAsset("main.sh", false)' "$WORKER"
grep -q 'return proxyInstallScript()' "$WORKER"
if grep -q "MAIN_SH =" "$WORKER"; then
  echo "Worker must proxy release/main.sh instead of embedding a stale bootstrap script." >&2
  exit 1
fi

grep -q "PubkeyAuthentication yes" "$SSHD_CONFIG"
grep -q "UsePAM yes" "$SSHD_CONFIG"
grep -q "MaxAuthTries 3" "$SSHD_CONFIG"

grep -q "validate_release_base" "$INSTALL"
grep -q "verify_tar_paths" "$INSTALL"
grep -q 'echo -e "\${GREEN}\$\*\${NC}" >&2' "$INSTALL"
grep -q 'echo -e "\${YELLOW}\$\*\${NC}" >&2' "$INSTALL"
grep -q 'local source_file="\${BASH_SOURCE\[0\]}"' "$INSTALL"
grep -q 'install_installer_asset "\$source_file" install.sh' "$INSTALL"
grep -q 'trap "rm -rf -- '\''\$binary_tmp_dir'\''" RETURN' "$INSTALL"
grep -q 'trap '\''rm -rf -- "\${tmp_dir:-}"'\'' EXIT' "$INSTALL"
grep -q -- "--proto '=https'" "$INSTALL"
grep -q -- "--https-only" "$INSTALL"
grep -q 'DEFAULT_RELEASE_BASE="https://rels.jinfei.org/download"' "$INSTALL"
grep -q 'https://rels.jinfei.org/download' "$INSTALL"
grep -q 'const RELEASE_ASSETS = new Set' "$WORKER"
grep -q 'const SOURCE_INSTALL_URL' "$WORKER"
grep -q 'const SOURCE_SETUP_URL' "$WORKER"
grep -q 'url.pathname.startsWith("/download/")' "$WORKER"
grep -q 'proxyInstallScript()' "$WORKER"
grep -q 'proxySetupScript()' "$WORKER"
grep -Fq 'assetName === "setup-relay.sh"' "$WORKER"
grep -q 'crypto.subtle.digest' "$WORKER"
grep -q 'return proxyAsset(assetName' "$WORKER"
grep -q 'return proxyChecksums()' "$WORKER"
grep -q 'branches:' "$DEPLOY_WORKER"
grep -q 'worker/rels-worker.js' "$DEPLOY_WORKER"
grep -q 'cloudflare/wrangler-action@v3' "$DEPLOY_WORKER"
grep -q "github.event.inputs.worker_name || 'rels-worker'" "$DEPLOY_WORKER"
grep -q "github.event.inputs.route || 'rels.jinfei.org/\*'" "$DEPLOY_WORKER"
grep -q "awk -v n=" "$INSTALL"

if grep -q "Relay auth secret: \${RELAY_AUTH_SECRET}" "$SETUP"; then
  echo "setup summary must not print relay auth secret in plaintext." >&2
  exit 1
fi

if LC_ALL=C.UTF-8 grep -R -n "[一-龥]" \
  "$RELS" "$LOCALE_PROFILE"; then
  echo "OVA utility scripts must remain ASCII/English only." >&2
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
if grep -Fq '\\.' "$SYNC_OFFICIAL" || grep -Fq '\\^{}' "$SYNC_OFFICIAL"; then
  echo "Official tag detection must not double-escape regex characters inside shell single quotes." >&2
  exit 1
fi

grep -q "TRIVY_VERSION" "$VALIDATE_WORKFLOW"
grep -q "TRIVY_CHECKSUM" "$VALIDATE_WORKFLOW"
grep -q 'go-version: "1.25.13"' "$VALIDATE_WORKFLOW"
grep -q "Install Trivy" "$VALIDATE_WORKFLOW"
grep -q "sha256sum -c" "$VALIDATE_WORKFLOW"
grep -q "Scan repository with Trivy" "$VALIDATE_WORKFLOW"
grep -q "trivy fs" "$VALIDATE_WORKFLOW"
grep -q -- "--ignorefile .trivyignore.yaml" "$VALIDATE_WORKFLOW"
grep -q "Scan relay source with govulncheck" "$VALIDATE_WORKFLOW"
grep -q "go install golang.org/x/vuln/cmd/govulncheck" "$VALIDATE_WORKFLOW"
grep -q "CRITICAL,HIGH" "$VALIDATE_WORKFLOW"
grep -q "misconfigurations: \[\]" "$TRIVY_IGNORE"

if find "$ROOT_DIR" -path "$ROOT_DIR/.git" -prune -o -path "$ROOT_DIR/.build" -prune -o -path "$ROOT_DIR/.worktrees" -prune -o -path "$ROOT_DIR/.tmp-release" -prune -o -path "$ROOT_DIR/.cospec" -prune -o -path "$ROOT_DIR/netbird" -prune -o -name Dockerfile -print | grep -q .; then
  echo "Repository must not contain Docker image definitions." >&2
  exit 1
fi

if grep -Eq "install_docker|docker-compose-plugin|docker-cli-compose|docker compose|docker-compose|netbirdio/relay" "$FIRSTBOOT" "$RELS" "$ZRAM_SETUP" "$KERNEL_TUNING" "$ROOT_RESIZE" "$NETWORK_CHECK"; then
  echo "OVA image scripts must not install or require Docker." >&2
  exit 1
fi

if grep -Eqi "caddy|sync-relay-certs|netbirdio/relay|docker compose" "$SETUP" "$CERT_RELOAD" "$BUILD_OVA"; then
  echo "Binary deployment and release workflow must not contain Caddy or container runtime paths." >&2
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
