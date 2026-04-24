# ⚡ EasyGost - GOST Web 管理面板

基于 [Multi-EasyGost](https://github.com/KANIKIG/Multi-EasyGost) 的一键 Web 管理面板，**纯 Bash 实现，零 Python 依赖**。

[![GitHub](https://img.shields.io/badge/GitHub-lgdglgc/EasyGost-blue?logo=github)](https://github.com/lgdglgc/EasyGost)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Bash](https://img.shields.io/badge/Bash-5.0+-brightgreen?logo=gnubash)](https://www.gnu.org/software/bash/)

## 📖 简介

**EasyGost** 是为原版 **Multi-EasyGost** 脚本配套的 Web 管理面板，提供以下特性：

- ✨ **一键安装/卸载** - 交互式菜单，自动安装依赖
- 🌐 **Web 界面** - 图形化管理 GOST 规则，支持移动设备
- 🐍 **零 Python 依赖** - 纯 Bash + socat 实现，运行更稳定
- 📊 **实时状态** - 显示 GOST 服务状态和规则列表
- 🎨 **现代设计** - 深色主题，响应式布局
- 📱 **17 种规则类型** - 涵盖 TCP/UDP、TLS、WS、SS、SOCKS5 等
- 🔐 **登录鉴权** - Web 面板带密码保护，防止未授权访问
- ⚡ **批量添加规则** - 一次粘贴多条转发规则，瞬间生效

## 🏗️ 系统架构

```
浏览器 :8888
    └──▶ socat（TCP 监听，fork 处理并发）
              └──▶ gost-web.sh（Bash HTTP 处理器）
                        ├── GET  /                  → 返回 index.html
                        ├── POST /api/login         → 验证账密 → 返回 Token
                        ├── GET  /api/rules         → 读取 rawconf → JSON
                        ├── POST /api/rules         → 写入 rawconf → 重建配置 → 重启 gost
                        ├── POST /api/rules/batch   → 批量写入 rawconf → 重建配置 → 重启 gost
                        ├── DELETE /api/rules/N     → 删除第 N 行 → 重建配置 → 重启 gost
                        └── GET  /api/status        → systemctl is-active gost
```

### 技术栈

| 层级 | 技术 | 说明 |
|------|------|------|
| **前端** | HTML5 + CSS3 + JavaScript | 单文件，无外部 CDN 依赖 |
| **后端** | Bash + socat | 纯 Shell HTTP 服务器 |
| **服务管理** | systemd | 开机自启，自动重启 |
| **配置** | 文本文件 | `/etc/gost/rawconf` |

### 文件结构

```
EasyGost/
├── install.sh        # 一键安装/卸载脚本（含交互菜单）
├── gost-web.sh       # Bash HTTP 请求处理器
├── gost-web.service  # Web 面板 systemd 服务定义
├── config.json       # GOST 初始配置模板
└── web/
    └── index.html    # Web 管理界面（单文件，CSS+JS 全内联）
```

## 🚀 快速开始

### 一键安装

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/lgdglgc/EasyGost/main/install.sh)
```

或使用 wget：

```bash
bash <(wget -qO- https://raw.githubusercontent.com/lgdglgc/EasyGost/main/install.sh)
```

安装脚本会弹出菜单，选择 `1` 安装：

```
╔════════════════════════════════════════╗
║   EasyGost — GOST Web 管理面板         ║
║   纯 Bash 实现，无 Python 依赖          ║
╚════════════════════════════════════════╝

 1. 安装 GOST + Web 管理面板
 2. 卸载 GOST + Web 管理面板
 0. 退出
```

安装完成后，打开浏览器访问：

```
http://你的服务器IP:8888
```

> ⚠️ **注意**：如果你使用了 Clash/V2ray 等代理软件，请将服务器 IP 加入直连规则，或关闭代理后再访问。

## 🔐 登录账号

首次访问 Web 面板时需要登录，默认账号密码如下：

| 项目 | 默认值 |
|------|--------|
| **账号** | `admin` |
| **密码** | `admin123456` |

### 修改账号密码

编辑 `/opt/gost-web/gost-web.sh`，修改文件顶部的以下两行：

```bash
ADMIN_USER="admin"        # 修改为你的账号
ADMIN_PASS="admin123456"  # 修改为你的密码
```

保存后重启 Web 面板服务生效：

```bash
systemctl restart gost-web
```

> 💡 **说明**：登录 Token 存储于 `/tmp/gost-web-token`，重启服务器或面板后会自动刷新，需要重新登录。

---

## ⚡ 批量添加规则

批量添加是本面板的核心特色功能，特别适合需要**一次性导入大量转发规则**的场景，例如从服务商获取到一批节点列表后快速配置。

### 打开批量添加窗口

登录面板后，点击规则列表右上角的 **「⚡ 批量添加」** 按钮即可打开批量添加弹窗。

### 填写格式

每行填写一条规则，格式如下：

```
本地端口  目标IP/域名  目标端口
```

字段之间使用**空格**或 **Tab** 分隔，三个字段缺一不可。

**示例：**

```
10000 1.2.3.4 443
10001 1.2.3.4 444
10002 5.6.7.8 8080
10003 example.com 443
10004 node1.example.com 8388
```

### 选择规则类型

在弹窗顶部的下拉菜单中选择转发类型，**该类型将统一应用到本次批量添加的所有规则**。

> 💡 如需添加不同类型的规则，请分多次使用批量添加功能，每次选择对应类型。

### 实时预览

粘贴或输入内容后，弹窗会**实时解析**并展示预览区域：

- ✅ **绿色 ✓**：该行格式正确，将被添加
- ❌ **红色 ✗**：该行格式有误，附带错误原因（如端口超出范围、字段缺失等），**不会**被提交

预览区显示格式：`本地端口 → 目标IP:目标端口`，同时统计有效/无效条数。

### 提交与生效

确认预览无误后，点击 **「✓ 批量保存并应用」** 按钮：

1. 仅提交解析成功的有效规则
2. 有效规则逐条追加到 `/etc/gost/rawconf`
3. 后端重新生成 `config.json`
4. 自动重启 `gost` 服务，规则立即生效
5. 弹窗关闭，规则列表自动刷新

### 常见错误与解决

| 错误提示 | 原因 | 解决方法 |
|----------|------|----------|
| `格式错误，需 3 个字段` | 该行字段不足 3 个 | 补全「本地端口 目标IP 目标端口」三个字段 |
| `本地端口无效: XXXX` | 端口非数字或超出 1-65535 范围 | 检查本地端口填写是否正确 |
| `目标端口无效: XXXX` | 端口非数字或超出 1-65535 范围 | 检查目标端口填写是否正确 |
| `没有有效规则` | 所有行均解析失败 | 检查整体格式，确保使用空格/Tab 分隔 |
| `解析规则失败，无有效记录` | 后端解析异常 | 检查输入是否含特殊字符，重试 |

### 批量添加 API（进阶）

批量添加功能通过以下 API 实现，也可直接调用：

```
POST /api/rules/batch
Header: X-Auth-Token: <你的Token>
Content-Type: application/json
```

请求体格式：

```json
{
  "type": "nonencrypt",
  "rules": [
    { "local_port": "10000", "dest_ip": "1.2.3.4", "dest_port": "443" },
    { "local_port": "10001", "dest_ip": "1.2.3.4", "dest_port": "444" },
    { "local_port": "10002", "dest_ip": "5.6.7.8", "dest_port": "8080" }
  ]
}
```

成功响应：

```json
{
  "success": true,
  "added": 3,
  "message": "3 条规则已添加并重启"
}
```

---

## 🛠️ 常用命令

```bash
# 查看 Web 面板状态
systemctl status gost-web

# 重启 Web 面板
systemctl restart gost-web

# 查看面板日志
journalctl -u gost-web -f

# 查看 GOST 状态
systemctl status gost

# 重启 GOST（规则改动后）
systemctl restart gost
```

## 📋 支持的规则类型

| 类型值 | 说明 | 使用场景 |
|--------|------|----------|
| `nonencrypt` | TCP+UDP 不加密转发 | 国内中转机 |
| `encrypttls` | 加密隧道（TLS） | 中转机加密转发 |
| `encryptws` | 加密隧道（WS） | 中转机加密转发 |
| `encryptwss` | 加密隧道（WSS） | 中转机加密转发 |
| `decrypttls` | 解密（TLS） | 落地机对接 |
| `decryptws` | 解密（WS） | 落地机对接 |
| `decryptwss` | 解密（WSS） | 落地机对接 |
| `ss` | Shadowsocks 代理 | 轻量代理 |
| `socks` | SOCKS5 代理 | 通用代理 |
| `http` | HTTP 代理 | 通用代理 |
| `peerno` | 均衡负载（无加密） | 多落地轮询 |
| `peertls` | 均衡负载（TLS） | 多落地轮询 |
| `peerws` | 均衡负载（WS） | 多落地轮询 |
| `peerwss` | 均衡负载（WSS） | 多落地轮询 |
| `cdnno` | CDN 转发（无加密） | CDN 自选节点 |
| `cdnws` | CDN 转发（WS） | CDN 隧道 |
| `cdnwss` | CDN 转发（WSS） | CDN 隧道 |

## 💻 系统要求

- **操作系统**: Linux（CentOS 7+、Ubuntu 18.04+、Debian 9+）
- **依赖**: `socat`、`wget`（安装脚本自动安装）
- **权限**: 需要 root 权限
- **GOST**: 脚本会自动下载安装 GOST v2.11.2

## 🐛 故障排除

### Web 无法访问

```bash
# 1. 检查面板服务是否运行
systemctl status gost-web

# 2. 检查端口是否在监听
ss -tulnp | grep 8888

# 3. 本地测试是否正常响应
curl -I http://127.0.0.1:8888/

# 4. 查看错误日志
journalctl -u gost-web -n 50 --no-pager
```

### 规则不生效

```bash
# 查看 GOST 状态和日志
systemctl status gost
journalctl -u gost -n 30

# 检查配置文件是否正确生成
cat /etc/gost/config.json
```

### 批量添加后规则未出现

```bash
# 检查 rawconf 是否已写入
cat /etc/gost/rawconf

# 检查 GOST 是否成功重启
systemctl status gost
journalctl -u gost -n 20 --no-pager
```

### 修改 Web 端口

编辑 `/etc/systemd/system/gost-web.service`，将 `8888` 改为目标端口，然后：

```bash
systemctl daemon-reload && systemctl restart gost-web
```

## 📚 相关资源

- [GOST 官方文档](https://docs.ginuerzh.xyz/gost/)
- [Multi-EasyGost 原始项目](https://github.com/KANIKIG/Multi-EasyGost)
- [GOST GitHub 仓库](https://github.com/ginuerzh/gost)

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

## 🙏 致谢

- 感谢 [@ginuerzh](https://github.com/ginuerzh) 开发的 [GOST](https://github.com/ginuerzh/gost)
- 感谢 [@KANIKIG](https://github.com/KANIKIG) 的 [Multi-EasyGost](https://github.com/KANIKIG/Multi-EasyGost) 脚本

---

**祝您使用愉快！** 🎉
