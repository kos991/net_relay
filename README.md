# NetBird & Alma Relay

为 NetBird 与 Alma 提供独立中继服务，支持 Debian、Ubuntu、Rocky、AlmaLinux 和 Alpine。

- **NetBird Relay**：支持 TCP/UDP/QUIC 自定义端口（默认 `8443`）及独立 UDP STUN（默认 `3478`）。
- **Alma Relay**：为桌面端与手机端 Alma 提供远程访问中继（默认 `8787`），支持自定义端口与访问密钥。
- **证书管理**：Cloudflare DNS-01 自动签发/续期，双中继共用 TLS 证书。

## 快速安装

不安装 Docker、Compose 或 Caddy。以 root 执行，按向导完成安装：

```sh
curl -sSL https://rels.jinfei.org | sh
```

- **OVA 首次开机**：请在虚拟机控制台 (VNC / Proxmox / KVM) 登录 `root`（默认初始密码 `relay`）完成初始化及密码修改；SSH 固定监听 `63000` 端口。
- **日常运维**：随时在终端输入 `rels` 打开管理菜单，查看状态、更新程序或调整配置。
