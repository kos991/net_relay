# NetBird Relay 二进制发行版

```bash
curl -sSL https://rels.jinfei.org | sh
```

支持 Debian / Ubuntu / Rocky / Alma / Alpine，仅安装官方源码构建的
`netbird-relay` 二进制，不安装 Docker、Compose 或 Caddy。

## 功能

- Relay TCP/WebSocket 与 UDP/QUIC 使用同一个自定义端口。
- 内置 STUN 使用独立自定义 UDP 端口。
- Cloudflare DNS-01 自动签发和续期 TLS 证书。
- 续期时校验证书、私钥和匹配关系，再自动重启 Relay。
- 每 6 小时检测 NetBird 官方最新 tag，变化后自动构建 `v1.0.N` 正式版。
- 发布 Linux amd64/arm64 二进制包、OVA 和 RAW 镜像。

## 目录

```text
scripts/installer/       二进制安装与配置向导
scripts/certificate/     单机证书续期重载钩子
packaging/relay/         Relay 构建、打包和服务文件
packaging/ova/           OVA 运行时文件
tests/                   发布与安装脚本检查
worker/                  下载入口 Worker
```

根目录的 `main.sh`、`install.sh`、`setup-relay.sh` 保留为兼容入口。

## OVA 镜像

- 镜像不内置 Docker、Compose 或 Caddy。
- 首次登录强制修改 root 密码。
- SSH 端口写在 Release notes。
- 首启执行根分区扩容、DHCP 自检、ZRAM 和内核参数优化。
- 阿里云导入使用 RAW 镜像，暂不发布 QCOW2。
- 暂不支持 LXC/OpenVZ。

## 许可证

GPL-3.0，详见 [LICENSE](LICENSE)。
