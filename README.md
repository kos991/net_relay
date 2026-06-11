# NetBird Relay 一键部署

```bash
curl -sSL https://github.com/kos991/net_relay/releases/latest/download/main.sh | sh
```

支持 Debian / Ubuntu / Rocky / Alma / Alpine。

## 镜像

- OVA 镜像不内置 Docker/Compose。
- SSH 端口写在 Release notes。
- 首次登录强制修改 root 密码。
- 首启执行根分区扩容、DHCP 自检、ZRAM 和内核参数优化。
- 云平台导入使用 OVA 和 RAW tar.xz：`net-relay-alpine-x86_64.ova`、`net-relay-alpine-x86_64.raw.tar.xz`。
- 暂不发布 QCOW2，暂不支持 LXC/OpenVZ。

## 许可

GPL-3.0，详见 [LICENSE](LICENSE)。
