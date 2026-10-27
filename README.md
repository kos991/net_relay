# NetBird Relay 二进制发行版

```bash
curl -sSL https://rels.jinfei.org | sh
```

支持 Debian / Ubuntu / Rocky / Alma / Alpine，仅安装官方源码构建的
`netbird-relay` 二进制，不安装 Docker、Compose 或 Caddy。

## 功能

- Relay TCP/WebSocket 与 UDP/QUIC 使用同一个自定义端口。
- 内置 STUN 使用独立自定义 UDP 端口。
- Cloudflare DNS-01 自动签发和续期 TLS 证书。
- 续期时校验证书、私钥和匹配关系，再自动重启 Relay。
- 每 6 小时检测 NetBird 官方最新 tag，变化后自动构建 `v1.0.N` 正式版。
- 发布 Linux amd64/arm64 二进制包、OVA 和 RAW 镜像。

上游版本由 `.github/netbird-relay-upstream.sha` 跟踪，构建时校验 `vX.Y.Z` 正式版本格式；发布检查不固定具体上游版本，自动更新 tag 后无需同步修改检查脚本。

## 目录

```text
scripts/installer/       二进制安装与配置向导
scripts/certificate/     单机证书续期重载钩子
packaging/relay/         Relay 构建、打包和服务文件
packaging/ova/           OVA 运行时文件
tests/                   发布与安装脚本检查
worker/                  下载入口 Worker
```

根目录的 `main.sh`、`install.sh`、`setup-relay.sh` 保留为兼容入口。

## 构建失败自动修复

`repair-build` 监听主分支的 `build-ova`、`validate` 和 `sync-official-relay`。失败后创建包含运行链接、提交和失败步骤的 Issue，并分配给 Copilot cloud agent 分析和提交修复 PR。相同工作流和提交不会重复建单；PR 仍由维护者审核合并，Agent 不自动发布。

启用前需要：

1. 使用支持 Copilot cloud agent 的订阅，并在账号和仓库设置中启用它。
2. 创建仅授权本仓库的 fine-grained personal access token：Metadata 读取，Actions、Contents、Issues、Pull requests 读写。令牌所属账号必须能使用 cloud agent。
3. 在仓库 Settings → Secrets and variables → Actions 中添加 `COPILOT_AGENT_TOKEN`。不要使用工作流的 `GITHUB_TOKEN`，也不要提交或公开令牌。

缺少令牌、权限或 Copilot 服务未启用时，工作流会明确失败；仅添加工作流并不代表自动修复已启用。委派失败后可以重跑任务，它会复用已创建的 Issue。

手动运行 `repair-build` 时填写失败运行的 `run_id`。默认 `dry_run=true` 只验证失败路由并生成任务摘要，不创建 Issue 或启动 Agent；关闭 dry run 才实际委派。可以使用历史失败运行验证配置，Agent 会先检查主分支是否已经修复。

配置依据：[GitHub 官方 Copilot API 文档](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/use-cloud-agent-via-the-api)。此流程通过 Issue 分配启动 Agent，可能消耗 Copilot 配额和 Actions 分钟数。

## OVA 镜像

- 镜像不内置 Docker、Compose 或 Caddy。
- 首次登录强制修改 root 密码。
- SSH 端口写在 Release notes。
- 首启执行根分区扩容、DHCP 自检、ZRAM 和内核参数优化。
- 阿里云导入可按控制台要求选择 RAW、VHD 或 QCOW2 镜像。
- 暂不支持 LXC/OpenVZ。

## 许可证

GPL-3.0，详见 [LICENSE](LICENSE)。
