# OVA 发布镜像

OVA 镜像由 GitHub Actions 构建并上传到 Releases。

## 构建内容

- Alpine Linux cloud image
- Docker 与 Docker Compose
- 已内置 `netbirdio/relay:latest`
- 已内置 `net-relay-caddy:ova`
- 已内置 `net-relay-sync:ova`
- SSH 默认开启，端口随机生成并写入 Release 说明
- 首次登录 root 后自动进入中文配置向导

## root 密码

每次发布 OVA 时都会随机生成 root 密码和 SSH 端口，并写入对应 Release 说明。

首次登录后建议立刻修改密码：

```bash
passwd
```
