#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIRSTBOOT="${ROOT_DIR}/ova/files/net-relay-firstboot"
RELS="${ROOT_DIR}/ova/files/rels"

bash -n "$FIRSTBOOT"
bash -n "$RELS"

grep -q "NetBird Relay OVA 初始化引导" "$FIRSTBOOT"
grep -q "正在执行 OVA 启动自检" "$FIRSTBOOT"
grep -q "自检完成" "$FIRSTBOOT"
grep -q "NetBird Relay 管理菜单" "$RELS"
grep -q "安装或重新配置 Relay" "$RELS"
grep -q "更新镜像并重启服务" "$RELS"

if grep -qi "VMware" "$FIRSTBOOT" "$RELS"; then
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
