# NetBird Relay 一键部署

```bash
curl -sSL https://rels.jinfei.org | sh
```

## 支持系统

- Debian / Ubuntu
- Rocky Linux / AlmaLinux
- Alpine Linux

## 安装模式

一键安装脚本会先进入中文交互菜单：

```text
请选择安装模式：
  1. 官方二进制安装（推荐，不安装 Docker）
  2. Docker Compose
请选择安装模式 [1]:
```

- 选择 `1` 或直接回车：安装 GitHub Release 中由 NetBird 官方源码编译出的 `netbird-relay` 二进制，并注册 systemd/OpenRC 服务。
- 选择 `2`：安装 Docker/Compose，并生成 `docker-compose.yml` 运行 `netbirdio/relay`。
- 自动化安装可使用 `INSTALL_MODE=binary`、`INSTALL_MODE=compose`、`--binary` 或 `--compose` 跳过安装模式选择。

## 发布产物

当前最新 Release 只保留一个版本，旧 release 和旧 tag 会在新版本发布成功后自动清理。

每个 Release 包含：

- `install.sh`
- `netbird-relay-linux-amd64.tar.gz`
- `netbird-relay-linux-arm64.tar.gz`
- `net-relay-alpine-x86_64.ova`
- `net-relay-alpine-x86_64.qcow2.gz`
- `net-relay-alpine-x86_64.raw.img.gz`
- `net_relay-main.tar.gz`
- `SHA256SUMS`

## 官方源码跟随

仓库通过 GitHub Actions 定时跟随 `netbirdio/netbird` 官方最新 release tag。

- 检测到新的官方 `v*` tag 后，自动触发 `build-ova`。
- Relay 二进制从官方源码编译，不使用 Docker 构建运行时。
- 发布说明会记录本次构建使用的 NetBird upstream ref。

## OVA / QCOW2 / RAW

镜像内置的是官方源码编译的 `netbird-relay` 二进制，不内置 Docker/Compose。

镜像特性：

- 首次登录强制修改 root 密码。
- Release notes 会显示本次 OVA 的 SSH 端口和登录命令。
- 首启会执行根分区自动扩容。
- 首启会进行 DHCP 网络自检。
- 预加载常见虚拟化网卡模块：VirtIO、E1000/E1000E、VMXNET3、Xen、ENA、Hyper-V、GCP gVNIC。
- 内置 ZRAM 与保守内核参数优化。

暂不计划支持 LXC/OpenVZ 容器环境。

## TLS 证书

配置向导支持三种证书模式：

- Cloudflare DNS + `acme.sh` 自动签发和续期。
- 使用已有 TLS 证书路径。
- 生成本地自签证书。

Cloudflare 模式会通过 `reloadcmd` 在证书续期后自动重启 Relay 服务，完成证书同步。
