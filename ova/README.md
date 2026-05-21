# OVA 发布镜像

OVA 镜像由 GitHub Actions 构建并上传到 Releases。

## 构建内容

- Alpine Linux cloud image
- Docker 与 Docker Compose
- 已内置 `netbirdio/relay:latest`
- 已内置 `net-relay-caddy:ova`
- 已内置 `net-relay-sync:ova`
- **open-vm-tools** - VMware 虚拟机集成（时间同步、剪贴板、文件拖放）
- **qemu-guest-agent** - KVM/Proxmox 虚拟机集成（快照、状态查询）
- SSH 默认开启，端口随机生成并写入 Release 说明
- 首次登录 root 后自动进入中文配置向导

## 虚拟机集成功能

### VMware 平台（open-vm-tools）
- ✅ 自动时间同步
- ✅ 剪贴板共享
- ✅ 文件拖放
- ✅ 自动调整分辨率
- ✅ 虚拟机状态报告

### KVM/Proxmox 平台（qemu-guest-agent）
- ✅ 虚拟机快照支持
- ✅ 文件系统冻结/解冻
- ✅ 虚拟机状态查询
- ✅ IP 地址自动获取

## root 密码

每次发布 OVA 时都会随机生成 root 密码和 SSH 端口，并写入对应 Release 说明。

首次登录后建议立刻修改密码：

```bash
passwd
```

## OVF 兼容性

- OVF 版本：1.0 标准
- 虚拟硬件版本：vmx-14（兼容 ESXi 6.7+）
- 网络适配器：E1000
- 磁盘格式：streamOptimized VMDK
