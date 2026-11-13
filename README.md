# NetBird Relay 二进制发行版

```bash
curl -sSL https://rels.jinfei.org | sh
```

支持 Debian / Ubuntu / Rocky / Alma / Alpine，仅安装官方源码构建的 `netbird-relay` 二进制，不安装 Docker、Compose 或 Caddy。

## 功能

- Relay TCP/WebSocket 与 UDP/QUIC 使用同一个自定义端口。
- 内置 STUN 使用独立自定义 UDP 端口。
- Cloudflare DNS-01 自动签发和续期 TLS 证书。
- 续期时校验证书、私钥和匹配关系，再自动重启 Relay。
- 每 6 小时自动跟踪上游正式版，变化后自动构建发布 `v1.0.N`。
- 发布 Linux amd64/arm64 二进制包、OVA 虚拟机镜像及 RAW/VHD/QCOW2 云镜像。

## OVA 镜像

- 镜像不内置 Docker、Compose 或 Caddy。
- 首次登录强制修改 root 密码，SSH 端口写在 Release notes。
- 首启执行根分区扩容、DHCP 自检、ZRAM 和内核参数优化。
- 登录后输入 `rels` 打开管理菜单：更新 Relay 和脚本、查看服务状态、证书有效期等。
- 阿里云导入可按控制台要求选择 RAW、VHD 或 QCOW2 镜像。
- 暂不支持 LXC/OpenVZ。

## 二进制更新

OVA 虚拟机或独立安装的 Linux 服务器均可在线更新：
- **OVA 虚拟机**：终端输入 `rels`，选择 `2) Update binary and restart service` 或 `3) Update installer scripts`。
- **独立 Linux 服务器**：重跑一键安装脚本 `curl -sSL https://rels.jinfei.org | sh`，或进入 `/opt/netbird-relay-installer` 执行 `./install.sh`。
- 更新脚本：`cd /opt/netbird-relay-installer && FORCE_UPDATE_SCRIPTS=1 ./install.sh`。

配置和 TLS 证书在更新时原样保留。

## 仓库结构

```text
scripts/installer/       二进制安装与配置向导
scripts/certificate/     证书续期重载钩子
packaging/relay/         Relay 构建、打包和服务文件
packaging/ova/           OVA 虚拟机运行时文件
tests/                   发布与安装脚本检查
worker/                  下载入口 Worker
```

根目录的 `main.sh`、`install.sh`、`setup-relay.sh` 为兼容入口。

## CI 构建失败自动修复

`.github/workflows/repair-build.yml` 监听主分支构建失败，自动创建 Issue 并分配给 Copilot 提交修复 PR。详见工作流注释。

## 许可证

GPL-3.0，详见 [LICENSE](LICENSE)。
