# NetBird & Alma Relay


```sh
curl -sSL https://rels.jinfei.org | sh
```

### 管理菜单

装完输入 `rels`，状态、更新、证书、回滚都在里面：

```text
=================================================
         NetBird & Alma Relay 管理菜单
=================================================
NetBird Relay : 运行中  v0.83.2  (rels://example.com:8443)
Alma Relay    : 运行中  v1.4.0  (https://example.com:8787)
-------------------------------------------------
1) NetBird Relay 管理（状态 / 日志 / 启停 / 更新 / 回滚 / 配置）
2) Alma Relay 管理   （状态 / 日志 / 启停 / 配置 / 更新）
3) 一键完整安装 / 重新初始化向导（NetBird + Alma）
4) 更新管理脚本（rels / install / setup）
5) 查看 TLS 证书状态
6) 查看 ZRAM 与内核优化状态
L) 切换语言 (Switch to English)
0) 退出
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
