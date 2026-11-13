# NetBird Relay 二进制发行版

```bash
curl -sSL https://rels.jinfei.org | sh
```

支持 Debian / Ubuntu / Rocky / Alma / Alpine，使用官方源码构建的 `netbird-relay`，不安装 Docker、Compose 或 Caddy。

## 功能与镜像

- Relay TCP/WebSocket 与 UDP/QUIC 共用自定义端口，STUN 使用独立 UDP 端口。
- Cloudflare DNS-01 自动签发和续期 TLS 证书；校验证书、私钥及匹配关系后重启 Relay。
- 每 6 小时跟踪上游正式版，变化后构建发布 `v1.0.N`。
- 发布 Linux amd64/arm64 包，以及 OVA、RAW、VHD、QCOW2 镜像；云平台按导入要求选用，暂不支持 LXC/OpenVZ。
- OVA 首次登录强制修改 root 密码，SSH 端口见 Release notes；首启执行扩容、DHCP 自检、ZRAM 和内核优化。

## 在线更新

- OVA 输入 `rels`：`1) Install or reconfigure Relay` 配置；`2) Update binary and run setup wizard` 更新二进制并进入向导。
- `3) Update installer scripts` 只更新安装器、配置向导、证书钩子和 `rels` 自身；`7)` 查看证书，`8)` 查看 ZRAM 与内核状态。
- 已迁移的 OVA 或独立 Linux：以 root 执行 `bash /opt/netbird-relay-installer/install.sh --scripts-only`。
- 脚本更新先下载并校验全部 SHA256，再用同目录临时文件 rename 替换；下载或校验失败保留旧文件。不会更新二进制、启动向导、重启服务或修改配置、证书和系统参数。
- 二进制更新可重跑一键入口或执行 `bash /opt/netbird-relay-installer/install.sh`；会进入配置向导，按需确认配置。

## 旧 OVA 首次迁移

旧安装器不识别 scripts-only 参数；不要直接选择旧菜单的更新项，也不要用普通安装命令代替。先以 root 下载并验证新安装器，在临时目录运行一次：

```bash
bash <<'EOF'
set -euo pipefail
base=https://rels.jinfei.org/download
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
cd "$tmp"
curl -fL --proto '=https' --proto-redir '=https' "$base/install.sh" -o install.sh
curl -fL --proto '=https' --proto-redir '=https' "$base/SHA256SUMS" -o SHA256SUMS
awk '$2=="install.sh" {print; n++} END {exit n!=1}' SHA256SUMS > installer.sha256
sha256sum -c installer.sha256
bash ./install.sh --scripts-only
EOF
```

迁移成功后重新运行 `rels`，使用菜单 `3)`；命令需要 Bash、curl、SHA256 工具，下载源变化导致校验失败时重试即可。Worker 和新脚本须先发布；纯 GitHub Release 下载源需包含 `rels` 资产及校验条目。

## 仓库与维护

`scripts/installer/` 安装与向导；`scripts/certificate/` 证书钩子；`packaging/` 二进制与镜像；`worker/` 下载入口；`tests/` 发布及行为检查。根目录脚本为兼容入口。

CI 失败自动修复的配置与试运行说明见 `.github/workflows/repair-build.yml` 注释。

GPL-3.0，详见 [LICENSE](LICENSE)。
