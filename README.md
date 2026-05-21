# NetBird Relay 一键安装

用于部署一个独立的 NetBird 外部 Relay：

- Caddy 通过 Cloudflare DNS challenge 自动申请证书
- Relay TCP 端口可自定义，不占用 `80/443`
- STUN UDP 端口可自定义
- 自动同步 Caddy 证书到 Relay，并在证书更新后重启 Relay

## 一键命令

```bash
bash <(curl -sSL https://rels.jinfei.org/main.sh)
```

也可以直接使用 GitHub 源：

```bash
curl -fsSL https://raw.githubusercontent.com/kos991/net_relay/main/install.sh | bash
```

## 前置条件

- 域名托管在 Cloudflare
- 准备 Cloudflare API Token，权限为 `Zone.Zone:Read` 和 `Zone.DNS:Edit`
- Relay 域名使用 Cloudflare DNS only，建议不要开启橙云代理
- 服务器能访问 Cloudflare API 和 GitHub
- 公网防火墙放行 Relay TCP 端口和 STUN UDP 端口

## 安装时会询问

```text
Relay domain: Relay 域名，例如 rels.jinfei.org
ACME email: 证书申请邮箱
Cloudflare API token: Cloudflare API Token
Relay TCP port: Relay 端口，默认 8443
STUN UDP port: STUN 端口，默认 3478
Relay image tag: 默认 latest
Cert sync interval: 证书同步检查间隔，默认 60 秒
Auth secret: 留空自动生成
```

## 安装顺序

1. 生成 `.env`、`relay.env`、`docker-compose.yml`、`caddy/Caddyfile`
2. 启动 `caddy` 和 `sync-relay-certs`
3. 等待证书同步到 `data/relay-certs`
4. 启动 `netbird-relay`
5. 输出 NetBird Management 的 `config.yaml` 片段

## 安装完成后

脚本会输出类似下面的主服务器配置：

```yaml
server:
  relays:
    addresses:
      - "rels://rels.jinfei.org:8443"
    secret: "自动生成或手动输入的 secret"
  stuns:
    - uri: "stun:rels.jinfei.org:3478"
      proto: udp
```

将它合并到 NetBird Management 的 `config.yaml` 后，重启 Management 服务。

## 自定义短域名入口

当前短入口：

```text
https://rels.jinfei.org/main.sh
```

Cloudflare Worker 返回仓库里的 `main.sh` 内容。验证示例见：

```text
docs/screenshots/curl-main-sh.txt
```

## 常用命令

```bash
cd /opt/netbird-relay-installer
docker compose ps
docker compose logs -f caddy sync-relay-certs relay
docker compose restart relay
```

## CI

GitHub Actions 会检查：

- shell 语法
- ShellCheck
- 安装脚本生成的 `.env`、`relay.env`、`docker-compose.yml`、`caddy/Caddyfile`
- 启动顺序是否为先 `caddy + sync`，再 `relay`

