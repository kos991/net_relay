# NetBird Relay OVA

OVA 由 GitHub Actions 构建并发布到 GitHub Releases。镜像不再内置业务 Docker 镜像，首次配置时从阿里云 ACR 公网拉取 `relay`、`caddy`、`sync` 三个镜像，以降低 OVA 体积。

## 内置内容

- Alpine Linux cloud image。
- Docker 和 Docker Compose。
- cloud-init 和 AliYun datasource。
- qemu-guest-agent，用于 KVM/Proxmox 状态查询和快照集成。
- BBR sysctl 配置。
- 基础工具：bash、curl、wget、git、vim、nano、unzip、zip、rsync、net-tools、iproute2、ping、tracepath、dig、telnet、lsof。
- SSH 默认开启，root 密码固定为 `Net@rels2026`，SSH 端口每次 Release 随机生成并写入 Release 说明。

## 首次启动流程

首次 root 登录会自动执行 `/usr/local/sbin/net-relay-firstboot`：

1. 等待 Docker 可用，失败时自动重启 Docker。
2. 检查 `bash`、`curl`、`docker`、`openssl`。
3. 检查 Docker Compose。
4. 检查 Docker 数据目录剩余空间不少于 768 MB。
5. 检查并拉取 ACR 的 `relay`、`caddy`、`sync` 镜像。
6. 进入中文交互安装脚本，生成 `.env`、`relay.env`、`docker-compose.yml` 并启动服务。

自检失败会停止安装并显示原因，避免用户在 OVA 内手工排查基础组件。

## 发布产物

- `net-relay-alpine-x86_64.ova`：VMware / ESXi。
- `net-relay-alpine-x86_64.qcow2.gz`：KVM / Proxmox / 阿里云。
- `SHA256SUMS`：校验文件。

不再发布 VHD。

## 手工检查

正常 OVA 安装不需要手工执行检查。需要排查虚拟硬件或云平台兼容性时，可运行：

```bash
net-relay-hw-check
```
