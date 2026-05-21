# NetBird Relay 自动化部署项目

## 项目概述

这是一个 NetBird Relay 的自动化部署解决方案，支持：
- 一键脚本部署到 VPS
- OVA/QCOW2/VHD 镜像构建和分发
- Cloudflare DNS 自动证书管理
- 证书自动同步和热重载

## 技术栈

- **Shell Script**: Bash 脚本，遵循 `set -euo pipefail` 严格模式
- **Docker**: 容器化部署，使用 Docker Compose 编排
- **Caddy**: 自动 HTTPS 证书管理，使用 Cloudflare DNS 插件
- **Alpine Linux**: 轻量级基础镜像
- **GitHub Actions**: CI/CD 自动构建 OVA 镜像

## 代码规范

### Shell 脚本
- 使用 `#!/usr/bin/env bash` shebang
- 启用严格模式：`set -euo pipefail`
- 函数命名使用 snake_case
- 变量使用大写（环境变量）或小写（局部变量）
- 使用 `[[ ]]` 而不是 `[ ]` 进行条件判断
- 字符串操作优先使用 Bash 内置功能
- 错误处理使用 `fail()` 函数统一输出

### Docker
- 多阶段构建优化镜像大小
- 使用 Alpine 作为基础镜像
- 明确指定镜像版本标签
- 使用 `.dockerignore` 排除不必要文件

### 文档
- 使用中文编写用户文档
- 代码注释使用中文
- README 包含快速开始、配置说明、常见问题

## 项目结构

```
.
├── setup-relay.sh              # 主安装脚本（交互式）
├── install.sh                  # 下载仓库并启动安装
├── main.sh                     # 远程快速安装入口
├── caddy/
│   ├── Dockerfile             # Caddy 证书管理容器
│   └── Caddyfile              # 动态生成
├── sync/
│   ├── Dockerfile             # 证书同步服务
│   └── sync-relay-certs.sh    # 证书同步守护进程
├── ova/
│   ├── files/
│   │   ├── net-relay-firstboot # OVA 首次启动向导
│   │   └── root-profile        # root 用户配置
│   └── README.md
├── .github/
│   └── workflows/
│       └── build-ova.yml       # OVA 镜像构建流程
└── docker-compose.yml          # 动态生成
```

## 关键组件

### 1. setup-relay.sh
- 交互式收集配置参数（域名、端口、API Token 等）
- 生成 `.env`、`relay.env`、`docker-compose.yml`、`Caddyfile`
- 启动 Caddy 和证书同步服务
- 等待证书签发完成
- 启动 NetBird Relay 服务

### 2. sync-relay-certs.sh
- 监控 Caddy 证书目录变化
- 使用 SHA256 哈希检测证书更新
- 原子性复制证书到 Relay 挂载目录
- 通过 Docker Socket API 重启 Relay 容器

### 3. build-ova.yml
- 基于 Alpine Linux cloud image 构建
- 预装 Docker 和相关镜像
- 使用 virt-customize 定制系统
- 生成 OVA/QCOW2/VHD 三种格式
- 随机生成 root 密码和 SSH 端口
- 自动发布到 GitHub Releases

## 环境变量

### 必需变量
- `RELAY_DOMAIN`: Relay 域名
- `ACME_EMAIL`: 证书申请邮箱
- `CF_API_TOKEN`: Cloudflare API Token
- `RELAY_AUTH_SECRET`: Relay 共享密钥

### 可选变量
- `RELAY_PORT`: Relay TCP 端口（默认 8443）
- `STUN_PORT`: STUN UDP 端口（默认 3478）
- `RELAY_IMAGE_TAG`: Relay 镜像标签（默认 latest）
- `SYNC_INTERVAL`: 证书同步间隔秒数（默认 60）
- `INSTALL_DIR`: 安装目录（默认 /opt/netbird-relay-installer）

## 常见任务

### 添加新的配置参数
1. 在 `setup-relay.sh` 中使用 `prompt_*` 函数收集参数
2. 在 `write_env_files()` 中写入 `.env` 或 `relay.env`
3. 在 `write_compose_file()` 或 `write_caddyfile()` 中使用变量
4. 更新 README.md 文档

### 修改 OVA 构建流程
1. 编辑 `.github/workflows/build-ova.yml`
2. 修改 `virt-customize` 命令添加定制步骤
3. 更新 Release Notes 模板

### 调试证书同步问题
```bash
docker compose logs -f sync-relay-certs
ls -la data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/
ls -la data/relay-certs/
```

## 安全注意事项

- 不要在代码中硬编码密钥或密码
- 使用 `prompt_secret()` 收集敏感信息（不回显）
- 生成的 `.env` 文件包含敏感信息，不应提交到 Git
- OVA 镜像的 root 密码每次构建随机生成
- SSH 端口随机化以减少暴力破解风险

## 测试建议

### 本地测试
```bash
# 在干净的 Docker 环境测试
./setup-relay.sh

# 检查服务状态
docker compose ps
docker compose logs

# 验证证书
openssl x509 -in data/relay-certs/fullchain.pem -text -noout
```

### OVA 测试
1. 触发 GitHub Actions 构建
2. 下载生成的 OVA 文件
3. 导入到 VMware/VirtualBox
4. 验证首次启动向导
5. 完成配置并测试 Relay 连接

## 贡献指南

- 保持脚本的幂等性（可重复执行）
- 添加详细的错误提示信息
- 使用中文编写用户可见的消息
- 更新相关文档
- 测试多种部署场景（VPS、OVA、不同虚拟化平台）
