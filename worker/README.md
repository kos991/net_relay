# Cloudflare Worker for rels.jinfei.org

`rels.jinfei.org` 使用 Cloudflare Worker 时，直接部署 `worker/rels-worker.js`。

## 路由

- `/` 和 `/main.sh`：一键安装入口。
- `/install.sh`：安装器入口。
- `/net_relay-main.tar.gz`：代理当前 Release 的安装包。
- `/SHA256SUMS`：代理当前 Release 的校验文件。

## 部署后检查

```bash
curl -I https://rels.jinfei.org
curl -I https://rels.jinfei.org/install.sh
curl -I https://rels.jinfei.org/net_relay-main.tar.gz
```

三个地址都应返回 `200`。

## 更新版本

发布新版本后，修改 `rels-worker.js` 顶部的 `RELEASE_TAG`，例如：

```js
const RELEASE_TAG = "v1.0.2";
```
