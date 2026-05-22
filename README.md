# NetBird Relay 一键安装

```bash
bash <(curl -sSL https://rels.jinfei.org/main.sh)
```

## 准备

- 域名托管在 Cloudflare。
- Cloudflare API Token 需要 `Zone.Zone:Read` 和 `Zone.DNS:Edit` 权限。
- Relay 域名建议使用 DNS only，不开启橙云代理。
- 放行 Relay TCP 端口，例如 `8443/tcp`。
- 放行 STUN UDP 端口，例如 `3478/udp`。

## 安装时填写

```text
Relay 域名：例如 rels.jinfei.org
证书邮箱：用于申请证书
Cloudflare API Token：用于 DNS-01 证书签发
Relay TCP 端口：默认 8443
STUN UDP 端口：默认 3478
Relay 镜像标签：默认 latest
证书同步间隔：默认 60 秒
共享密钥：可留空自动生成
Docker registry mirror：可选，国内拉取失败时填写
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

## 镜像

GitHub Releases 会提供 OVA、QCOW2、VHD 镜像。每次 Release 说明都会写入随机 root 密码、SSH 端口和本次更新内容。
如果 Docker Hub 拉取慢或失败，可以在安装时填写 Docker registry mirror。
