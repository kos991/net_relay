# NetBird Relay 一键部署

```bash
curl -sSL https://rels.jinfei.org | sh
```

支持 Debian / Ubuntu / Rocky / Alma / Alpine。

## 安装模式

脚本会中文交互选择：

- `1` 官方二进制安装：推荐，不安装 Docker。
- `2` Docker Compose：只用于一键安装，不进入 OVA 镜像。

自动化可用：

```bash
INSTALL_MODE=binary curl -sSL https://rels.jinfei.org | sh
INSTALL_MODE=compose curl -sSL https://rels.jinfei.org | sh
```

## 发布产物

Release 只保留最新一个版本，包含：

- `install.sh`
- `netbird-relay-linux-amd64.tar.gz`
- `netbird-relay-linux-arm64.tar.gz`
- `net-relay-alpine-x86_64.ova`
- `net-relay-alpine-x86_64.qcow2.gz`
- `net-relay-alpine-x86_64.raw.img.gz`
- `SHA256SUMS`

## 自动构建

- 自动跟随 `netbirdio/netbird` 官方最新 release tag。
- 发现新官方 tag 后自动编译 relay 二进制并触发 OVA/QCOW2/RAW 发布。
- Relay 二进制从官方源码编译。

## OVA 镜像

- 镜像不内置 Docker/Compose。
- 首次登录强制修改 root 密码。
- SSH 端口写在 Release notes。
- 首启执行根分区扩容、DHCP 自检、ZRAM 和内核参数优化。
- 暂不支持 LXC/OpenVZ。
