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
Relay 镜像：默认 `crpi-9kn2o1el6okkk1mu.cn-shanghai.personal.cr.aliyuncs.com/netrels/netrels:relay`
证书同步间隔：默认 60 秒
共享密钥：可留空自动生成
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

## 默认镜像

VPS 一键安装默认使用阿里云 ACR 公网镜像，不修改 Docker registry mirror：

```text
crpi-9kn2o1el6okkk1mu.cn-shanghai.personal.cr.aliyuncs.com/netrels/netrels:relay
crpi-9kn2o1el6okkk1mu.cn-shanghai.personal.cr.aliyuncs.com/netrels/netrels:caddy
crpi-9kn2o1el6okkk1mu.cn-shanghai.personal.cr.aliyuncs.com/netrels/netrels:sync
```

如需覆盖，可在执行脚本前设置 `RELAY_IMAGE`、`CADDY_IMAGE`、`SYNC_IMAGE`。

### 阿里云 ACR 构建规则

在仓库 `netrels/netrels` 中添加 3 条构建规则：

```text
类型：Branch
Branch/Tag：main
构建上下文目录：/caddy/
Dockerfile文件名：Dockerfile
镜像版本：caddy
```

```text
类型：Branch
Branch/Tag：main
构建上下文目录：/sync/
Dockerfile文件名：Dockerfile
镜像版本：sync
```

```text
类型：Branch
Branch/Tag：main
构建上下文目录：/relay/
Dockerfile文件名：Dockerfile
镜像版本：relay
```

## 镜像

GitHub Releases 会提供 OVA、QCOW2、VHD 镜像。镜像内置 Relay、Caddy、证书同步服务所需 Docker 镜像，首次启动会自动导入。每次 Release 说明都会写入 root 密码、SSH 端口、内置 Relay 镜像和本次更新内容。
