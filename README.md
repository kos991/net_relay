# NetBird Relay
为 NetBird 提供独立 Relay/STUN 中继服务，支持 Debian、Ubuntu、Rocky、AlmaLinux 和 Alpine。

## 快速安装
镜像不内置 Docker、Compose 或 Caddy。
以 root 执行，按向导完成安装：
```sh
curl -sSL https://rels.jinfei.org | sh
```

## 安装后配置
- 准备指向服务器公网 IP 的域名；使用 Cloudflare DNS-01 自动签发证书时，准备邮箱和具有该域名 DNS 编辑权限的 API Token，也可使用已有证书。
- 按向导设置域名、Relay 端口（默认 8443）、STUN 端口（默认 3478）和认证密钥；同组 Relay 节点及 Management 必须使用相同密钥。
- 将向导输出的配置合并到 NetBird Management 的 `config.yaml`；完整密钥保存在 `/etc/netbird-relay/relay.env`，请妥善保管。

## OVA 与管理菜单
导入 OVA 后首次登录须修改 root 密码，SSH 端口见镜像下载说明；以 root 输入 `rels` 打开菜单。
- `1` 安装或重新配置；`2` 更新二进制并进入配置向导；`3` 仅更新安装器、配置向导、证书钩子和菜单。
- `4` 查看服务状态；`5` 查看日志；`6` 重启服务；`7` 查看证书；`8` 查看 ZRAM 和内核状态；`0` 退出。
- 使用 `3` 的前提：本机安装器已支持 `--scripts-only`，下载源已提供新版脚本（含 `rels`）及对应 SHA256 校验条目；旧 OVA 须先按下方迁移。
- 仅更新脚本不会更新二进制、启动配置向导、重启服务或修改配置与证书；下载或校验失败时保留旧脚本，成功后重新运行 `rels`。

<details>
<summary>旧 OVA 首次迁移（仅限安装器不支持 --scripts-only）</summary>

不要直接使用旧菜单更新项。以 root 执行以下命令，需 Bash、curl 和 sha256sum；校验失败时停止，稍后重试。
```bash
bash <<'EOF'
set -euo pipefail
base=https://rels.jinfei.org/download
tmp=$(mktemp -d); trap 'rm -rf -- "$tmp"' EXIT; cd "$tmp"
curl -fL --proto '=https' --proto-redir '=https' "$base/install.sh" -o install.sh
curl -fL --proto '=https' --proto-redir '=https' "$base/SHA256SUMS" -o SHA256SUMS
awk '$2=="install.sh" {print; n++} END {exit n!=1}' SHA256SUMS > installer.sha256
sha256sum -c installer.sha256 && bash ./install.sh --scripts-only
EOF
```
</details>

## 普通 Linux 更新
以 root 重跑快速安装命令，或执行 `bash /opt/netbird-relay-installer/install.sh` 更新二进制，并在向导中确认配置。
仅更新脚本：`bash /opt/netbird-relay-installer/install.sh --scripts-only`，前提与菜单 `3` 相同。

## 服务、日志与注意事项
- systemd：`systemctl status netbird-relay --no-pager` 查看状态，`journalctl -u netbird-relay -f -n 120` 查看日志，`systemctl restart netbird-relay` 重启。
- Alpine/OpenRC：`service netbird-relay status` 查看状态，`tail -f /var/log/netbird-relay.log /var/log/netbird-relay.err` 查看日志，`service netbird-relay restart` 重启。
- 放行防火墙与安全组中的 Relay TCP/UDP 端口和 STUN UDP 端口；Cloudflare 中继域名使用“仅 DNS”。更新前备份配置与证书，不要公开认证密钥或 API Token。

## 许可证
[GPL-3.0](LICENSE)。
