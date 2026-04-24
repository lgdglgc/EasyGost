# 🚀 EasyGost - GOST Web 管理面板

基于 [Multi-EasyGost](https://github.com/KANIKIG/Multi-EasyGost) 的一键Web管理面板，提供图形界面轻松管理GOST规则。

[![GitHub](https://img.shields.io/badge/GitHub-lgdglgc/EasyGost-blue?logo=github)](https://github.com/lgdglgc/EasyGost)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Python](https://img.shields.io/badge/Python-3.7+-blue)](https://www.python.org/)
[![Flask](https://img.shields.io/badge/Flask-3.0+-blue)](https://flask.palletsprojects.com/)

## 📖 简介

**EasyGost** 是为原版 **Multi-EasyGost** 脚本配套的Web管理面板，提供以下特性：

- ✨ **一键安装** - 自动启动，无需手动配置
- 🌐 **Web界面** - 图形化管理GOST规则，支持移动设备
- ⚡ **快速操作** - 一行命令启动/停止/重启服务
- 📊 **实时监控** - 显示GOST服务状态和规则配置
- 🎨 **现代设计** - 响应式布局，深色主题支持
- 📱 **完全兼容** - 支持17种规则类型（TCP、UDP、TLS、Shadowsocks等）

## �️ 系统架构

### 系统框架图

```
┌─────────────────────────────────────────────────────────┐
│                   用户浏览器 (客户端)                    │
│              http://IP:8888                             │
└────────────────┬────────────────────────────────────────┘
                 │  REST API (JSON/HTTP)
                 ▼
┌─────────────────────────────────────────────────────────┐
│           EasyGost Web 管理面板服务                      │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │   Flask Web 应用 (gost-web-manager.py)           │  │
│  │  - REST API 端点                                 │  │
│  │  - 规则管理 (增删改查)                            │  │
│  │  - 配置文件处理                                   │  │
│  │  - GOST 服务控制                                 │  │
│  └──────────────────────────────────────────────────┘  │
│           │                │                │           │
│    ▼      ▼                ▼                ▼           │
│  ┌─────┐ ┌────────────┐ ┌──────────┐ ┌──────────┐   │
│  │HTML │ │Static File │ │RuleManager│ │Configuration││
│  │Files│ │(CSS/JS)    │ │           │ │Generator   │   │
│  └─────┘ └────────────┘ └──────────┘ └──────────┘   │
└──────────┬──────────────────────────────┬─────────────┘
           │                               │
      ▼    ▼                               ▼
  ┌──────────────────┐         ┌────────────────────┐
  │  配置文件系统    │         │  systemctl/GOST    │
  │ /etc/gost/rawconf│         │   服务控制         │
  └──────────────────┘         └────────────────────┘
           │                               │
           ▼                               ▼
  ┌──────────────────┐         ┌────────────────────┐
  │  GOST 规则配置   │         │  GOST 进程         │
  │  (转发规则)      │         │  (实际转发)        │
  └──────────────────┘         └────────────────────┘
```

### 技术栈

| 层级 | 技术 | 说明 |
|------|------|------|
| **前端** | HTML5 + CSS3 + JavaScript | 响应式Web界面 |
| **后端** | Python 3.7+ + Flask 3.0+ | REST API服务器 |
| **通信** | HTTP/JSON | 前后端数据交互 |
| **部署** | systemd + Bash | 服务管理和启动 |
| **配置** | 文本文件 | /etc/gost/rawconf |
| **通知** | journalctl | 日志和事件 |

### 核心组件

#### 1. 前端组件 (`web/`)
- **index.html** - 响应式HTML界面
  - 仪表板：显示GOST服务状态
  - 规则管理：添加/编辑/删除规则
  - 配置预览：查看生成的配置
  - 帮助文档：使用说明

- **static/app.js** - 前端逻辑 (500+ 行)
  - API通信（加载、保存、删除规则）
  - 实时状态刷新
  - 用户交互处理
  - 欢迎层管理

- **static/style.css** - 样式表 (600+ 行)
  - 响应式布局
  - 深色主题
  - 动画效果
  - 移动设备适配

#### 2. 后端组件 (`gost-web-manager.py`)
```python
Flask 应用
├── API 端点
│   ├── GET /api/rules           - 获取所有规则
│   ├── POST /api/rules          - 添加新规则
│   ├── PUT /api/rules/<id>      - 修改规则
│   ├── DELETE /api/rules/<id>   - 删除规则
│   ├── GET /api/gost/status     - 获取GOST状态
│   ├── POST /api/rules/apply    - 应用配置
│   ├── GET /api/protocol-types  - 获取规则类型
│   └── GET /api/health          - 健康检查
│
├── 规则管理器 (RuleManager)
│   ├── 解析配置文件
│   ├── 生成配置文件
│   ├── 验证规则格式
│   └── 管理规则增删改查
│
└── 配置生成器 (ConfigGenerator)
    ├── 根据规则生成GOST配置
    └── 实时预览配置
```

#### 3. 服务组件
- **install.sh** - 自动安装脚本
  - 检查依赖
  - 创建目录
  - 部署文件
  - 配置服务

- **gost-web** - 快速控制脚本
  - start/stop/restart/status/logs 5个命令
  - 自动IP检测
  - 彩色输出反馈

- **gost-web-manager.service** - systemd 服务定义
  - 自动启动配置
  - 重启策略
  - 权限和隔离

#### 4. 配置组件
- **requirements.txt** - Python依赖
  ```
  Flask==3.0.0
  Flask-CORS==4.0.0
  ```

- **/etc/gost/rawconf** - GOST规则配置 (自动生成)
  ```
  规则类型/本地端口#目标IP#目标端口
  tcpno/8080#192.168.1.100#80
  relayws/8081#relay.example.com#8001
  ```

## 🔄 工作流程

### 用户操作流程

```
用户打开Web页面 (http://IP:8888)
    ↓
加载欢迎界面，显示加载动画
    ↓
前端 JavaScript 发起 API 请求
    ↓
后端加载规则并返回 JSON
    ↓
前端渲染规则列表到页面
    ↓
用户点击"添加规则"
    ↓
打开表单，用户填写规则信息
    ↓
用户点击"保存"
    ↓
前端发送 POST /api/rules 请求
    ↓
后端验证规则格式
    ↓
后端追加规则到 /etc/gost/rawconf
    ↓
返回成功响应到前端
    ↓
前端刷新规则列表显示新规则
    ↓
用户点击"应用配置"
    ↓
前端发送 POST /api/rules/apply 请求
    ↓
后端调用 systemctl restart gost
    ↓
GOST服务重启，新规则生效
```

### 数据流

```
用户操作
    ↓
Web 界面 (HTML/CSS/JS)
    ↓
REST API 请求 (HTTP/JSON)
    ↓
Flask 路由处理
    ↓
RuleManager 类处理
    ↓
读/写 /etc/gost/rawconf 文件
    ↓
systemctl 控制 GOST 服务
    ↓
GOST 执行转发规则
```

### API 端点详解

| 方法 | 端点 | 功能 | 请求体 | 响应 |
|------|------|------|--------|------|
| GET | `/api/rules` | 获取所有规则 | - | {rules: [...]} |
| POST | `/api/rules` | 添加新规则 | {type, local_port, dest_ip, dest_port} | {success: true} |
| PUT | `/api/rules/<id>` | 修改规则 | {type, local_port, dest_ip, dest_port} | {success: true} |
| DELETE | `/api/rules/<id>` | 删除规则 | - | {success: true} |
| GET | `/api/gost/status` | 获取GOST状态 | - | {status: "active"} |
| POST | `/api/rules/apply` | 应用配置 | - | {success: true} |
| GET | `/api/protocol-types` | 获取规则类型列表 | - | {data: {...}} |
| GET | `/api/health` | 健康检查 | - | {status: "ok"} |

## �🎯 快速开始

### 一键安装

```bash
# 下载并运行安装脚本
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/lgdglgc/EasyGost/main/install.sh)"
```

或使用wget：

```bash
sudo bash -c "$(wget -O- https://raw.githubusercontent.com/lgdglgc/EasyGost/main/install.sh)"
```

### 安装完成后

脚本会自动启动Web服务，打开浏览器访问：

```
http://你的服务器IP:8888
```

## 🛠️ 常用命令

```bash
# 启动Web管理面板
sudo gost-web start

# 停止Web管理面板
sudo gost-web stop

# 重启Web管理面板
sudo gost-web restart

# 查看服务状态
sudo gost-web status

# 查看实时日志
sudo gost-web logs
```

或使用systemctl：

```bash
sudo systemctl start gost-web-manager
sudo systemctl restart gost-web-manager
sudo systemctl status gost-web-manager
```

## 📋 功能特性

### 支持的规则类型

- **基础隧道**: TCP、UDP、TLS隧道转发
- **代理服务**: Socks5、HTTP、HTTPS代理
- **加密转发**: Shadowsocks、Relay+WS、Relay+WSS
- **负载均衡**: 支持多个后端的负载均衡转发
- **CDN转发**: 自定义CDN节点IP转发

### Web管理面板

- 📊 **仪表板** - 显示GOST服务状态
- 📝 **规则管理** - 添加、编辑、删除转发规则
- 👁️ **配置预览** - 实时预览GOST配置文件
- 📚 **帮助文档** - 完整的功能说明和示例

## 💻 系统要求

- **操作系统**: Linux (CentOS 7+, Ubuntu 18.04+, Debian 9+)
- **Python**: 3.7 或更高版本
- **权限**: 需要root权限（sudo）
- **GOST**: 需要先安装 [GOST](https://github.com/ginuerzh/gost)

### 安装GOST

如果未安装GOST，可使用以下命令：

```bash
# CentOS/RHEL
sudo yum install gost

# Ubuntu/Debian
sudo apt install gost

# 或从源码编译
wget https://github.com/ginuerzh/gost/releases/download/v2.11.2/gost-linux-amd64-2.11.2.gz
gunzip gost-linux-amd64-2.11.2.gz
sudo mv gost-linux-amd64-2.11.2 /usr/local/bin/gost
sudo chmod +x /usr/local/bin/gost
```

## 🚀 使用示例

### 添加一个TCP转发规则

1. 打开Web管理面板 `http://你的IP:8888`
2. 点击"规则管理"标签
3. 点击"添加规则"按钮
4. 选择规则类型为"tcpno"
5. 填写信息：
   - 本地端口: 8080
   - 目标IP: 192.168.1.100
   - 目标端口: 80
6. 点击"保存"按钮
7. 点击"应用配置"应用设置

## 🔧 高级配置

### 修改Web访问端口

编辑 `/opt/gost-web-manager/gost-web-manager.py`，找到最后一行：

```python
app.run(host='0.0.0.0', port=8888, debug=False)
```

修改 `port=8888` 为需要的端口号，然后重启：

```bash
sudo gost-web restart
```

### 查看详细日志

```bash
# 使用快速脚本查看
sudo gost-web logs

# 或使用journalctl
sudo journalctl -u gost-web-manager -f
```

## 🐛 故障排除

### Web无法访问

```bash
# 检查服务状态
sudo gost-web status

# 查看日志找出原因
sudo gost-web logs

# 重启服务
sudo gost-web restart
```

### 规则不生效

1. 检查规则格式是否正确
2. 查看"配置预览"确认配置文件
3. 在Web面板中点击"应用配置"
4. 查看日志 `sudo gost-web logs`

### 服务无法启动

```bash
# 检查GOST是否安装
which gost
gost -v

# 检查权限
sudo ls -l /etc/gost/

# 查看错误日志
sudo journalctl -u gost-web-manager -n 50
```

## 📚 相关资源

- [GOST官方文档](https://docs.ginuerzh.xyz/gost/)
- [Multi-EasyGost原始项目](https://github.com/KANIKIG/Multi-EasyGost)
- [GOST GitHub仓库](https://github.com/ginuerzh/gost)

## 🤝 贡献

欢迎提交Issue和Pull Request！

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

## 💬 反馈和支持

- 提交Issue: [GitHub Issues](https://github.com/lgdglgc/EasyGost/issues)
- 讨论: [GitHub Discussions](https://github.com/lgdglgc/EasyGost/discussions)

## 🙏 致谢

- 感谢 [@ginuerzh](https://github.com/ginuerzh) 开发的 [GOST](https://github.com/ginuerzh/gost)
- 感谢 [@KANIKIG](https://github.com/KANIKIG) 的 [Multi-EasyGost](https://github.com/KANIKIG/Multi-EasyGost) 脚本

---

**祝您使用愉快！** 🎉
