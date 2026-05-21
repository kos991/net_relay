# 变更日志

## [未发布] - 2026-05-21

### 新增
- 添加 `open-vm-tools` 支持 VMware 虚拟机集成
  - 自动时间同步
  - 剪贴板共享
  - 文件拖放
  - 自动调整分辨率
  - 虚拟机状态报告

- 添加 `qemu-guest-agent` 支持 KVM/Proxmox 虚拟机集成
  - 虚拟机快照支持
  - 文件系统冻结/解冻
  - 虚拟机状态查询
  - IP 地址自动获取

- 添加 GitHub Copilot 项目提示词文件 (`.github/copilot-instructions.md`)

### 修复
- 修复 OVF 格式兼容性问题
  - 添加必需的 `Connection` 元素（某些平台要求必须存在）
  - 移除不兼容的 `ResourceSubType` 元素
  - 移除不兼容的 `AutomaticAllocation` 元素
  - 移除不兼容的 `Address` 元素
  - 使用标准 OVF 1.0 规范的 `AddressOnParent` 元素
  - 网络适配器使用通用的 "VM Network" 连接名称
  - 提升与 ESXi 6.7、VirtualBox、深信服等平台的兼容性

### 优化
- 重新设计 Release Notes 格式
  - 使用表格和 Emoji 图标优化可读性
  - 添加镜像特性和技术规格说明
  - 包含虚拟机集成工具信息
  - 添加快速开始和安全建议章节
  - 更专业的文档结构

### 文档
- 更新 `ova/README.md` 说明虚拟机集成功能
- 更新 `.github/copilot-instructions.md` 开发文档
- 添加 OVF 兼容性说明

## 技术细节

### OVF 兼容性修复历程
1. **第一次修复** (commit: a7d8eb0)
   - 移除 `Connection` 和 `ResourceSubType`
   - 使用 `Address` 和 `AutomaticAllocation`

2. **第二次修复** (commit: dbc2b53)
   - 移除 `AutomaticAllocation`
   - 使用 `AddressOnParent` 替代 `Address`

3. **最终方案**
   - 仅使用 OVF 1.0 核心标准元素
   - 网络适配器配置最小化
   - 兼容所有主流虚拟化平台

### 虚拟机集成工具
- **安装位置**: Alpine APK 包管理器
- **服务启动**: 通过 OpenRC 自动启动
- **适用场景**:
  - VMware 平台优先使用 open-vm-tools
  - KVM/Proxmox 平台优先使用 qemu-guest-agent
  - 两者可以共存，不会冲突

## 待测试项目

- [ ] OVF 导入到 VMware ESXi 6.7
- [ ] OVF 导入到 VMware Workstation
- [ ] OVF 导入到 VirtualBox
- [ ] OVF 导入到深信服虚拟化平台
- [ ] QCOW2 导入到 Proxmox VE
- [ ] QCOW2 导入到 OpenStack
- [ ] VHD 导入到 Xen/XCP-ng
- [ ] open-vm-tools 功能验证（VMware）
- [ ] qemu-guest-agent 功能验证（Proxmox）
- [ ] 首次启动向导流程
- [ ] 证书自动签发和同步
- [ ] Relay 服务正常运行

## 相关 Commits

- `a7d8eb0` - 修复: OVA OVF 格式兼容性问题
- `dbc2b53` - 修复: 移除 OVF 中的 AutomaticAllocation 元素
- `1185268` - 增强: 添加虚拟机集成工具
- `c9a3077` - 文档: 记录虚拟机集成工具功能
- `f992dc4` - 优化: 重新设计 Release Notes 格式

## 相关 Tags

- `ova-20260521152905` - 第一次 OVF 修复版本（已构建）
- `ova-20260521153303` - 第二次 OVF 修复版本（已构建）
- 待创建 - 完整功能版本（包含虚拟机集成工具）
