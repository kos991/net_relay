# OVA 发布镜像

OVA 镜像由 GitHub Actions 构建并上传到 Releases。镜像不再内置 Docker 业务镜像，以减小体积；首次配置时会从阿里云 ACR 公网拉取运行所需镜像。

## 构建内容

- Alpine Linux cloud image
- Docker 与 Docker Compose
- 默认从阿里云 ACR 公网拉取 Relay、Caddy 和证书同步服务镜像
- cloud-init 与 AliYun datasource
- 常用工具：wget、curl、git、vim、nano、unzip、zip、rsync
- 基础网络工具：net-tools、iproute2、ping、arping、tracepath、dig、telnet、lsof
- BBR TCP 拥塞控制配置
- **qemu-guest-agent** - KVM/Proxmox 虚拟机集成（快照、状态查询）
- SSH 默认开启，端口随机生成并写入 Release 说明
- 首次登录 root 后自动进入中文配置向导

## 虚拟机集成功能

### KVM/Proxmox 平台（qemu-guest-agent）
- ✅ 虚拟机快照支持
- ✅ 文件系统冻结/解冻
- ✅ 虚拟机状态查询
- ✅ IP 地址自动获取

## root 密码

root 密码固定为 `Net@rels2026`，SSH 端口每次发布随机生成并写入对应 Release 说明。

首次登录后建议立刻修改密码：

```bash
passwd
```

## OVF 兼容性

- OVF 版本：1.0 标准
- 虚拟硬件版本：vmx-14（兼容 ESXi 6.7+）
- 网络适配器：E1000
- 磁盘格式：streamOptimized VMDK

## 镜像检测

镜像内置检测命令：

```bash
net-relay-hw-check
```

该命令会检查 cloud-init、qemu-guest-agent、virtio/NVMe 模块、BBR 和基础网络工具状态。阿里云导入前仍建议使用阿里云镜像规范检测工具做最终检查。
