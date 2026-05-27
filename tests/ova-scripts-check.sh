#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIRSTBOOT="${ROOT_DIR}/ova/files/net-relay-firstboot"
RELS="${ROOT_DIR}/ova/files/rels"
SETUP="${ROOT_DIR}/setup-relay.sh"
ROOT_PROFILE="${ROOT_DIR}/ova/files/root-profile"
LOGIN_CFG="${ROOT_DIR}/ova/files/99-net-relay-login.cfg"
BUILD_OVA="${ROOT_DIR}/.github/workflows/build-ova.yml"
SYSCTL_CONF="${ROOT_DIR}/ova/files/99-net-relay-sysctl.conf"

bash -n "$FIRSTBOOT"
bash -n "$RELS"
bash -n "$SETUP"
bash -n "$ROOT_PROFILE"

grep -q "NetBird Relay OVA 初始化引导" "$FIRSTBOOT"
grep -q "正在执行 OVA 启动自检" "$FIRSTBOOT"
grep -q "自检完成" "$FIRSTBOOT"
grep -q "multi-node relay group" "$FIRSTBOOT"
grep -q "NetBird Relay 管理菜单" "$RELS"
grep -q "安装或重新配置 Relay" "$RELS"
grep -q "更新镜像并重启服务" "$RELS"
grep -q "查看证书状态" "$RELS"
grep -q "show_certificate_status" "$RELS"
grep -q "证书有效期结束" "$RELS"
grep -q "剩余天数" "$RELS"
grep -q "同步状态" "$RELS"
grep -q "openssl x509" "$RELS"
grep -q "NetBird Relay 安装向导" "$SETUP"
grep -q "Relay 域名" "$SETUP"
grep -q "认证密钥" "$SETUP"
grep -q "select_relay_group_mode" "$SETUP"
grep -q "RELAY_GROUP_MODE" "$SETUP"
grep -q "create" "$SETUP"
grep -q "join" "$SETUP"
grep -q "read_relay_auth_secret" "$SETUP"
grep -Fq 'if [[ "$RELAY_GROUP_MODE" == "join" && -z "$RELAY_AUTH_SECRET" ]]' "$SETUP"
grep -q "must provide an existing relay auth secret" "$SETUP"
grep -q "RELAY_NODE_NAME=" "$SETUP"
grep -q "RELAY_NODE_NAME=\${RELAY_NODE_NAME}" "$SETUP"
grep -q "安装完成" "$SETUP"
grep -q "如果有多个 Relay 节点" "$SETUP"
grep -q "mode_label" "$SETUP"
grep -q "relays.addresses" "$SETUP"
grep -q "same secret" "$SETUP"
grep -q "RELAY_NODE_NAME" "$SETUP"
grep -q "root-password-confirmed" "$ROOT_PROFILE"
grep -q "ROOT_PASSWORD_CONFIRM_FLAG" "$ROOT_PROFILE"
grep -q "yes" "$ROOT_PROFILE"
grep -q "expire: true" "$LOGIN_CFG"
grep -q "chage -d 0 root" "$BUILD_OVA"
grep -q "net.core.default_qdisc = fq" "$SYSCTL_CONF"
grep -q "net.ipv4.tcp_congestion_control = bbr" "$SYSCTL_CONF"
grep -q "net.core.rmem_max = 8388608" "$SYSCTL_CONF"
grep -q "net.ipv4.tcp_keepalive_time = 120" "$SYSCTL_CONF"
grep -q "net.ipv4.ip_local_port_range = 10000 65535" "$SYSCTL_CONF"

if grep -Eq "default_qdisc = cake|tc qdisc|tcp_retries2|nf_conntrack_udp_timeout|wg-quick|systemctl restart xray" "$SYSCTL_CONF" "$FIRSTBOOT" "$RELS" "$SETUP"; then
  echo "OVA scripts must not contain high-risk network tuning commands." >&2
  exit 1
fi

if grep -qi "VMware" "$FIRSTBOOT" "$RELS" "$SETUP"; then
  echo "OVA scripts must not contain VMware-specific text." >&2
  exit 1
fi

prefix_file="$(mktemp)"
trap 'rm -f "$prefix_file"' EXIT
awk '/^if \[\[ -f "\$FLAG" \]\]/{exit} {print}' "$FIRSTBOOT" > "$prefix_file"
cat >> "$prefix_file" <<'EOF'
printf '%s\n%s\n%s\n' "$RELAY_IMAGE" "$CADDY_IMAGE" "$SYNC_IMAGE"
EOF

output="$(env -u RELAY_IMAGE -u CADDY_IMAGE -u SYNC_IMAGE bash "$prefix_file")"
grep -q "netrels/netrels:relay" <<<"$output"
grep -q "netrels/netrels:caddy" <<<"$output"
grep -q "netrels/netrels:sync" <<<"$output"
