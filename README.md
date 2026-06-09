# NetBird Relay 一键部署

```bash
curl -sSL https://github.com/kos991/net_relay/releases/latest/download/main.sh | sh
```

支持 Debian / Ubuntu / Rocky / Alma / Alpine。

## OVA 镜像

- 镜像不内置 Docker/Compose。
- 首次登录强制修改 root 密码。
- SSH 端口写在 Release notes。
- 首启执行根分区扩容、DHCP 自检、ZRAM 和内核参数优化。
- 阿里云导入使用 RAW 镜像，暂不发布 QCOW2。
- 暂不支持 LXC/OpenVZ。

## 许可证

GPL-3.0，详见 [LICENSE](LICENSE)。
