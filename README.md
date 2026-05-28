# NetBird Relay 一键部署

```bash
bash <(curl -sSL https://rels.jinfei.org)
```

支持系统：

- Debian / Ubuntu
- CentOS / Rocky Linux / AlmaLinux

说明：一键脚本不安装 Docker，运行前需要 Docker 和 Docker Compose 已可用。

## 镜像支持计划

当前发布产物以 OVA、QCOW2 和一键安装包为主。

RAW/DD 镜像计划支持，但暂未发布。后续会优先确认以下适配项：

- 根分区自动扩容
- 常见虚拟化网卡支持：VirtIO、E1000/E1000E、VMXNET3、Xen、ENA、Hyper-V、GCP gVNIC
- DHCP 网络自检
- 与 reinstall/DD 场景的启动兼容性

暂不计划支持 LXC/OpenVZ 容器环境。
