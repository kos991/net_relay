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
1) 安装或重新配置 Relay（NetBird + Alma）
2) 更新 Relay 程序（保留现有配置）
3) 更新管理脚本（rels / install / setup）
4) 查看服务状态（NetBird + Alma）
5) 查看实时日志（NetBird / Alma）
6) 重启服务（NetBird + Alma）
7) Alma Relay 管理（配置 / 启停 / 访问地址）
8) 查看 TLS 证书状态
9) 查看 ZRAM 与内核优化状态
10) 回滚 NetBird Relay 到上一版本
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
