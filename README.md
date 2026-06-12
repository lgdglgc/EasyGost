# ⚡ EasyGost - GOST Web 管理面板

基于 [Multi-EasyGost](https://github.com/KANIKIG/Multi-EasyGost) 的一键 Web 管理面板，**纯 Bash 实现，零 Python 依赖**。

[![GitHub](https://img.shields.io/badge/GitHub-lgdglgc/EasyGost-blue?logo=github)](https://github.com/lgdglgc/EasyGost)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Bash](https://img.shields.io/badge/Bash-5.0+-brightgreen?logo=gnubash)](https://www.gnu.org/software/bash/)

---

## 📖 简介

**EasyGost** 是专为原版 **Multi-EasyGost** 脚本打造的轻量化 Web 管理面板，具有以下亮点：

- ✨ **一键安装/卸载** - 交互式菜单，自动配置环境和系统依赖
- 🌐 **可视化 Web 界面** - 响应式设计，适配手机/电脑，随时随地管理转发规则
- 🐍 **零 Python 依赖** - 纯 Bash + `socat` 实现轻量 HTTP 服务，内存占用极低
- 📊 **实时状态监测** - 直观显示 GOST 的运行状态及规则总数
- 🔐 **登录身份鉴权** - 带密码保护的安全登录机制，防止未经授权的访问
- ⚡ **规则批量导入** - 支持一键粘贴多条规则，校验通过后自动重载生效
- 🔗 **新增 SOCKS5 落地中转** - 支持将流量经由中转机，通过 SOCKS5（支持账号/密码认证）中继至海外落地机

---

## 🏗️ 系统架构

```
浏览器 :8888
    └──▶ socat (TCP 监听，fork 处理并发)
              └──▶ gost-web.sh (Bash HTTP 处理器)
                        ├── GET  /                  → 返回 index.html
                        ├── POST /api/login         → 验证账密 → 返回 Token
                        ├── GET  /api/rules         → 读取 rawconf → JSON
                        ├── POST /api/rules         → 写入 rawconf → 重建配置 → 重启 gost
                        ├── POST /api/rules/batch   → 批量写入 rawconf → 重建配置 → 重启 gost
                        ├── DELETE /api/rules/N     → 删除第 N 行 → 重建配置 → 重启 gost
                        └── GET  /api/status        → systemctl is-active gost
```

### 技术栈说明

| 层级 | 技术 | 说明 |
| :--- | :--- | :--- |
| **前端** | HTML5 + CSS3 + Vanilla JS | 单文件实现，响应式排版，无任何外部 CDN 依赖 |
| **后端** | Bash + socat | 纯 Shell 实现的极简 HTTP 服务器，无常驻臃肿后台进程 |
| **服务管理** | systemd | 开机自启，进程挂掉自动拉起 |
| **持久化** | 纯文本数据 | 规则保存在 `/etc/gost/rawconf`，按行存储，易于备份 |

---

## 🚀 快速开始

### 一键安装

使用 curl 安装：
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/lgdglgc/EasyGost/main/install.sh)
```
或使用 wget：
```bash
bash <(wget -qO- https://raw.githubusercontent.com/lgdglgc/EasyGost/main/install.sh)
```

在弹出的交互菜单中，输入 `1` 即可自动完成 GOST 与 Web 管理面板的部署。
安装完成后，您可以通过浏览器访问：
```
http://您的服务器IP:8888
```

> [!WARNING]
> 如果您使用了代理软件，访问面板前请务必将服务器 IP 加入直连绕过规则，或者暂时关闭代理。

---

## 🔐 账户与安全

### 默认凭据

| 项目 | 默认值 |
| :--- | :--- |
| **管理账号** | `admin` |
| **管理密码** | `admin123456` |

### 修改默认账密

编辑 `/opt/gost-web/gost-web.sh` 文件顶部的账户定义：
```bash
ADMIN_USER="您的新账号"
ADMIN_PASS="您的新密码"
```
保存后，重启 Web 面板服务即可生效：
```bash
systemctl restart gost-web
```

> [!NOTE]
> 登录成功的身份 Token 暂存于 `/tmp/gost-web-token`，中转机重启或面板服务重载后会自动刷新，届时需要重新登录。

---

## 📋 支持的规则类型

| 类型值 | 界面显示名称 | 说明 / 使用场景 |
| :--- | :--- | :--- |
| `nonencrypt` | 不加密中转 | TCP+UDP 直接转发，适合普通国内中转 |
| `encrypttls` | 加密TLS | 中转端：将流量加密后送入落地机 |
| `encryptws` | 加密WS | 中转端：WebSocket 加密转发 |
| `encryptwss` | 加密WSS | 中转端：支持 TLS 的 WebSocket 加密转发 |
| `decrypttls` | 解密TLS | 落地端：接收并解密来自中转机的 TLS 流量 |
| `decryptws` | 解密WS | 落地端：接收并解密来自中转机的 WS 流量 |
| `decryptwss` | 解密WSS | 落地端：接收并解密来自中转机的 WSS 流量 |
| `ss` | Shadowsocks | 创建本地 Shadowsocks 代理服务 |
| `socks` | SOCKS5 | 创建本地 SOCKS5 代理服务（带认证） |
| `transitsocks` | SOCKS5落地中转 | **链式代理**：中转机监听并经由落地 SOCKS5 中继流量（支持账密） |
| `ocservsocks` | ocserv VPN 劫持中转 | **透明代理**：通过 iptables 自动劫持 AnyConnect (ocserv) 流量并由 SOCKS5 转发 |
| `http` | HTTP | 创建本地 HTTP 代理服务 |
| `peerno` | 均衡-无加密 | 轮询转发流量至多个落地机节点 |
| `peertls` | 均衡-TLS | 轮询加密转发至多个落地机节点 |
| `peerws` | 均衡-WS | 轮询以 WS 协议转发至多个落地机 |
| `peerwss` | 均衡-WSS | 轮询以 WSS 协议转发至多个落地机 |
| `cdnno` | CDN-无加密 | 利用 CDN 进行转发（无加密） |
| `cdnws` | CDN-WS | 经过 CDN 进行 Websocket 隧道中转 |
| `cdnwss` | CDN-WSS | 经过 CDN 进行 Websocket Secure 隧道中转 |

---

## ⚡ 批量导入规则

批量添加适合快速导入服务商提供的节点列表。

### 格式要求
每行代表一条规则，各个字段之间使用 **空格** 或 **Tab** 分隔：
```
本地端口 落地IP/域名 落地端口
```

**正确范例：**
```
10000 1.2.3.4 443
10001 1.2.3.4 444
10002 example.com 8080
# 如果是 SOCKS5 落地中转 (transitsocks)，且落地需要账密，可采用如下格式：
10003 myuser:mypassword@5.6.7.8 1080
```

---

## 🔧 维护命令

```bash
# 查看 Web 管理面板状态
systemctl status gost-web

# 重启 Web 管理面板
systemctl restart gost-web

# 实时查看面板访问/操作日志
journalctl -u gost-web -f

# 查看 GOST 运行状态与出错日志
systemctl status gost
journalctl -u gost -n 50 --no-pager

# 重启 GOST 转发核心
systemctl restart gost
```

### 修改 Web 面板端口

默认监听 `8888` 端口。如果需要更换，请编辑 `/etc/systemd/system/gost-web.service` 文件，将 `TCP-LISTEN:8888` 中的端口修改为您需要的端口，然后运行：
```bash
systemctl daemon-reload && systemctl restart gost-web
```

---

## 🐛 常见排查与故障解决

### Web 页面打不开
1. 检查面板服务是否在运行：`systemctl status gost-web`
2. 检查 8888 端口是否处于监听状态：`ss -tulnp | grep 8888`
3. 若端口被占用，请更换端口。
4. 本地使用 curl 测试能否连通：`curl -I http://127.0.0.1:8888/`

### 规则设置后不生效
1. 检查 GOST 服务的状态：`systemctl status gost`
2. 查看 GOST 报错日志：`journalctl -u gost -n 30`
3. 检查解析后的配置文件格式是否正确：`cat /etc/gost/config.json`
4. 检查最原始的配置文件记录：`cat /etc/gost/rawconf`

---

## 🤝 参与贡献与致谢

- 感谢 [@ginuerzh](https://github.com/ginuerzh) 带来的优秀工具 [GOST](https://github.com/ginuerzh/gost)。
- 感谢 [@KANIKIG](https://github.com/KANIKIG) 的 [Multi-EasyGost](https://github.com/KANIKIG/Multi-EasyGost) 核心转发脚本逻辑。

---

**祝您使用愉快！** 🚀
