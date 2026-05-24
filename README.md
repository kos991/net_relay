# NetBird Relay 一键部署

一键脚本会创建 NetBird Relay、Caddy 证书容器和证书同步容器，默认从阿里云 ACR 公网拉取镜像，不需要配置 Docker registry mirror。

```bash
bash <(curl -sSL https://rels.jinfei.org)
```

## 支持系统

脚本要求使用 `bash` 运行，支持以下 Linux 发行版：

- Debian / Ubuntu：支持 `systemctl` 或 `service` 启停 Docker。
- CentOS / Rocky Linux / AlmaLinux：支持 `systemctl` 或 `service` 启停 Docker。

一键脚本不安装 Docker。运行前需要 root，或当前用户已具备 Docker socket 访问权限；Docker 和 Docker Compose 必须已安装并可用。若 Docker 或 Docker Compose 不存在，脚本会停止并提示。

## 安装前准备

- 域名托管在 Cloudflare。
- Cloudflare API Token 需要 `Zone.Zone:Read` 和 `Zone.DNS:Edit` 权限。
- Relay 域名建议使用 DNS only，不开启 Cloudflare 代理。
- 放行 Relay TCP 端口，例如 `8443/tcp`。
- 放行 STUN UDP 端口，例如 `3478/udp`。

## 交互参数

```text
Relay domain: Relay 域名，例如 rels.example.com
ACME email: 证书申请邮箱
Cloudflare API Token: DNS-01 证书签发 Token
Relay TCP port: 默认 8443
STUN UDP port: 默认 3478
Relay image: 默认阿里云 ACR relay 镜像
Certificate sync interval: 默认 60 秒
Auth secret: 可留空自动生成
```

默认镜像：

```text
crpi-9kn2o1el6okkk1mu.cn-shanghai.personal.cr.aliyuncs.com/netrels/netrels:relay
crpi-9kn2o1el6okkk1mu.cn-shanghai.personal.cr.aliyuncs.com/netrels/netrels:caddy
crpi-9kn2o1el6okkk1mu.cn-shanghai.personal.cr.aliyuncs.com/netrels/netrels:sync
```

如需覆盖镜像，可在运行脚本前设置 `RELAY_IMAGE`、`CADDY_IMAGE`、`SYNC_IMAGE`。

## 脚本升级

再次执行一键脚本会升级安装器文件，但不会删除 `.env`、`relay.env`、`docker-compose.yml`、`data/`、证书目录和 `caddy/Caddyfile`。

## 运行边界

- 一键脚本不安装 Docker，只在 Docker 未启动时尝试通过 `systemctl` 或 `service` 启动 Docker。
- OVA 内置 Docker、Docker Compose 和必要基础工具；Docker socket 残留导致 Alpine OVA 内 Docker 启动异常时，OVA firstboot 会清理 stale pid/socket 后重启 Docker。
- Docker Compose 缺失、Docker 仍不可用、镜像无法拉取、磁盘空间不足时会停止安装并给出错误原因。
- `docker-compose.yml` 内的 `caddy`、`sync-relay-certs`、`relay` 都配置 `restart: unless-stopped`，容器异常退出后由 Docker 自动拉起。
- 证书同步容器会按 `SYNC_INTERVAL` 周期同步 Caddy 证书到 Relay 挂载目录。

## OVA 镜像

GitHub Release 从 `v1.0.0` 起使用语义化版本号。发布文件只保留：

- `net-relay-alpine-x86_64.ova`：VMware / ESXi。
- `net-relay-alpine-x86_64.qcow2.gz`：KVM / Proxmox / 阿里云。
- `SHA256SUMS`：校验文件。

OVA 内置 Docker、Docker Compose、cloud-init、qemu-guest-agent、BBR 配置和基础工具。首次登录会在交互安装前自检 Docker、Compose、磁盘空间和 ACR 镜像拉取，不需要用户单独执行检查命令。

## NetBird Management 配置

安装完成后，把脚本输出的配置写入 NetBird Management 的 `config.yaml`：

```yaml
server:
  relays:
    addresses:
      - "rels://你的Relay域名:8443"
    secret: "脚本输出的secret"
  stuns:
    - uri: "stun:你的Relay域名:3478"
      proto: udp
```

然后重启 NetBird Management。

## 常用命令

```bash
cd /opt/netbird-relay-installer
docker compose ps
docker compose logs -f caddy sync-relay-certs relay
docker compose restart relay
```
