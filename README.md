# NetBird Relay 一键部署

```bash
curl -sSL https://rels.jinfei.org | sh
```

支持系统：

- Debian / Ubuntu
- Rocky Linux / AlmaLinux
- Alpine Linux

说明：
- Release 会自动从 NetBird 官方源码编译 `netbird-relay` 二进制。
- 一键脚本会自动识别系统和架构，下载二进制安装包，注册 systemd/OpenRC 服务并启动。
- 配置向导默认使用 `acme.sh` + Cloudflare DNS 自动签发 TLS 证书，并配置续期后自动重启 Relay 完成证书同步。
- 也支持填写已有 TLS 证书路径，或生成本地自签证书。
- 建议使用 root 执行；非 root 用户需要已有 sudo 权限。

## 镜像支持计划

当前发布产物以 OVA、QCOW2 和一键安装包为主。

RAW/DD 镜像计划支持，但暂未发布。后续会优先确认以下适配项：

- 根分区自动扩容
- 常见虚拟化网卡支持：VirtIO、E1000/E1000E、VMXNET3、Xen、ENA、Hyper-V、GCP gVNIC
- DHCP 网络自检
- 与 reinstall/DD 场景的启动兼容性

暂不计划支持 LXC/OpenVZ 容器环境。
