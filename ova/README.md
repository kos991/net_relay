# OVA 发布镜像

OVA 镜像由 GitHub Actions 构建并上传到 Releases。

## 构建内容

- Alpine Linux cloud image
- Docker 与 Docker Compose
- 已内置构建时指定的 Relay 镜像，默认 `netbirdio/relay:latest`
- 已内置 `net-relay-caddy:ova`
- 已内置 `net-relay-sync:ova`
- 首次启动会自动 `docker load` 导入内置镜像
- cloud-init 与 AliYun datasource
- 常用工具：wget、curl、git、vim、nano、unzip、zip、rsync
- 网络排障工具：net-tools、iproute2、ping、arping、tracepath、traceroute、mtr、dig、telnet、nmap、iperf3、tcpdump、lsof、socat、whois
- BBR TCP 拥塞控制配置
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

该命令会检查 cloud-init、qemu-guest-agent、virtio/NVMe 模块、BBR 和常用网络工具状态。阿里云导入前仍建议使用阿里云镜像规范检测工具做最终检查。
