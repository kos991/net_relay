# NetBird & Alma Relay

一行命令装好。不安装 Docker、Compose 或 Caddy。

```sh
curl -sSL https://rels.jinfei.org | sh
```

### 管理菜单

装完输入 `rels`，状态、更新、证书、回滚都在里面：

```text
=================================================
              NetBird Relay Management Menu
=================================================
1) Install or reconfigure Relay
2) Update Relay binary (keeps config)
3) Update management scripts (rels/install/setup)
4) Show service status
5) Show service logs (real-time)
6) Restart Relay service
7) Show certificate status
8) Show ZRAM and kernel tuning status
9) Rollback Relay binary to previous backup
0) Exit
=================================================
```

### 端口

| 用途 | 端口 |
|---|---|
| NetBird Relay (TCP/UDP/QUIC) | `8443` |
| STUN (UDP) | `3478` |
| Alma Relay | `8787` |
| OVA SSH | `63000` |

OVA 首次开机在控制台用 `root` / `relay` 登录，会强制改密。