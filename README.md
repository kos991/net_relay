# NetBird Relay 一键安装

```bash
bash <(curl -sSL https://rels.jinfei.org/main.sh)
```

## 准备

- 域名托管在 Cloudflare
- Cloudflare API Token 权限：`Zone.Zone:Read`、`Zone.DNS:Edit`
- Relay 域名使用 DNS only，关闭橙云代理
- 放行 Relay TCP 端口，例如 `8443/tcp`
- 放行 STUN UDP 端口，例如 `3478/udp`

## 安装时填写

```text
Relay domain: Relay 域名
ACME email: 证书邮箱
Cloudflare API token: Cloudflare API Token
Relay TCP port: Relay 端口，默认 8443
STUN UDP port: STUN 端口，默认 3478
Relay image tag: 默认 latest
Cert sync interval: 默认 60
Auth secret: 留空自动生成
```

## 主服务器配置

安装完成后，把脚本输出的配置写入 NetBird Management 的 `config.yaml`：

```yaml
server:
  relays:
    addresses:
      - "rels://你的Relay域名:8443"
    secret: "脚本输出的 secret"
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
