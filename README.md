# NetBird Relay 一键部署

```bash
bash <(curl -sSL https://rels.jinfei.org)
```

脚本会创建 NetBird Relay、Caddy 证书容器和证书同步容器，默认从阿里云 ACR 公网拉取镜像，不需要配置 Docker registry mirror。

## 支持系统

- Debian / Ubuntu
- CentOS / Rocky Linux / AlmaLinux

一键脚本不安装 Docker。运行前需要 root，或当前用户已具备 Docker socket 访问权限；Docker 和 Docker Compose 必须已安装并可用。

## 安装前准备

- 域名托管在 Cloudflare。
- Cloudflare API Token 需要 `Zone.Zone:Read` 和 `Zone.DNS:Edit` 权限。
- Relay 域名建议使用 DNS only，不开启 Cloudflare 代理。
- 放行 Relay TCP 端口，例如 `8443/tcp`。
- 放行 STUN UDP 端口，例如 `3478/udp`。

## 安装时填写

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

再次执行一键脚本会更新安装器文件，但会保留 `.env`、`relay.env`、`docker-compose.yml`、`data/`、证书目录和 `caddy/Caddyfile`。
