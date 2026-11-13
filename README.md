# NetBird & Alma Relay

一行命令装好。不安装 Docker、Compose 或 Caddy。

```sh
curl -sSL https://rels.jinfei.org | sh
```

### 安装向导

```text
=================================================
              NetBird Relay 配置向导
=================================================
部署模式：二进制
同一 Relay 节点组中的所有节点必须使用相同的密钥。
Cloudflare 模式使用 acme.sh DNS 验证，并通过 reloadcmd 同步续期证书。
```

### 管理菜单

装完输入 `rels`：

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

OVA 控制台 `root` / `relay`，SSH `63000`。
NetBird `8443`，STUN `3478`，Alma `8787`。