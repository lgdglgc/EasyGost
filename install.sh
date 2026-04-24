#!/bin/bash
#
# EasyGost - GOST Web 管理面板 一键安装脚本
# https://github.com/lgdglgc/EasyGost
#

set -e

# 颜色定义
Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Yellow_font_prefix="\033[33m"
Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[✓]${Font_color_suffix}"
Error="${Red_font_prefix}[✗]${Font_color_suffix}"
Warn="${Yellow_font_prefix}[!]${Font_color_suffix}"

# 显示欢迎信息
echo -e "${Green_font_prefix}"
echo "╔════════════════════════════════════════════╗"
echo "║   EasyGost - GOST Web 管理面板            ║"
echo "║   一键安装脚本                            ║"
echo "╚════════════════════════════════════════════╝"
echo -e "${Font_color_suffix}"

# 检查root权限
if [[ $EUID != 0 ]]; then
    echo -e "${Error} 此脚本需要root权限"
    echo "请使用: sudo bash install.sh"
    exit 1
fi

# ============ GOST 检测和安装 ============
echo -e "\n${Warn} 检查GOST是否已安装..."

# 检测GOST
if ! command -v gost &> /dev/null; then
    echo -e "${Error} 未检测到GOST\n"
    
    # 询问用户是否安装GOST
    read -p "$(echo -e ${Yellow_font_prefix})[?]$(echo -e ${Font_color_suffix}) 是否现在安装GOST? (y/n): " install_gost
    
    if [[ "$install_gost" != "y" && "$install_gost" != "Y" ]]; then
        echo -e "${Error} 请先手动安装GOST后再运行此脚本"
        exit 1
    fi
    
    echo -e "${Info} 开始安装GOST (v2.11.2)..."
    
    # 检测架构
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)
            GOST_ARCH="amd64"
            ;;
        aarch64|arm64)
            GOST_ARCH="arm64"
            ;;
        armv7l)
            GOST_ARCH="armv7"
            ;;
        i686)
            GOST_ARCH="386"
            ;;
        *)
            echo -e "${Error} 不支持的架构: $ARCH"
            echo "请输入架构: 386/amd64/arm64/armv7/armv5"
            read GOST_ARCH
            ;;
    esac
    
    echo -e "${Info} 检测架构: $GOST_ARCH"
    
    # 创建临时目录
    TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR" || exit 1
    
    # 从GitHub下载GOST 2.11.2
    GOST_VERSION="2.11.2"
    DOWNLOAD_URL="https://github.com/ginuerzh/gost/releases/download/v${GOST_VERSION}/gost-linux-${GOST_ARCH}-${GOST_VERSION}.gz"
    
    echo -e "${Info} 下载GOST二进制文件..."
    if ! curl -fsSL "$DOWNLOAD_URL" -o "gost-linux-${GOST_ARCH}-${GOST_VERSION}.gz"; then
        echo -e "${Error} 下载失败，请检查网络连接"
        cd /
        rm -rf "$TMP_DIR"
        exit 1
    fi
    
    echo -e "${Info} 解压GOST..."
    gunzip "gost-linux-${GOST_ARCH}-${GOST_VERSION}.gz" || {
        echo -e "${Error} 解压失败"
        cd /
        rm -rf "$TMP_DIR"
        exit 1
    }
    
    echo -e "${Info} 安装GOST..."
    mv "gost-linux-${GOST_ARCH}-${GOST_VERSION}" gost
    install -m755 gost /usr/bin/gost || {
        echo -e "${Error} 安装失败"
        cd /
        rm -rf "$TMP_DIR"
        exit 1
    }
    
    # 清理临时目录
    cd /
    rm -rf "$TMP_DIR"
    
    # 验证安装
    if command -v gost &> /dev/null; then
        echo -e "${Info} GOST安装成功"
    else
        echo -e "${Error} GOST安装失败"
        exit 1
    fi
else
    echo -e "${Info} 已检测到GOST"
fi

# 显示GOST版本
echo -e "${Info} GOST版本: $(gost -V 2>&1 || echo 'v2.11.2')"

# ============ 检查Python环境 ============
echo -e "\n${Warn} 检查Python环境..."

# 检查Python
if ! command -v python3 &> /dev/null; then
    echo -e "${Error} 未检测到Python3"
    exit 1
fi

echo -e "${Info} Python版本: $(python3 --version)"

# ============ 安装EasyGost Web管理面板 ============
echo -e "\n${Warn} 安装EasyGost Web管理面板..."

# 检测系统类型
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
fi

# 直接使用系统包管理器安装Flask
echo -e "${Info} 安装Python依赖 (Flask, Flask-CORS)..."

case "$OS" in
    ubuntu|debian)
        echo -e "${Info} 使用apt安装Flask..."
        apt update > /dev/null 2>&1 || true
        apt install -y python3-flask python3-flask-cors > /dev/null 2>&1
        ;;
    centos|rhel|fedora)
        echo -e "${Info} 使用yum安装Flask..."
        yum install -y python3-flask python3-flask-cors > /dev/null 2>&1 || {
            echo -e "${Warn} yum安装失败，尝试epel..."
            yum install -y epel-release > /dev/null 2>&1 || true
            yum install -y python3-flask python3-flask-cors > /dev/null 2>&1
        }
        ;;
    alpine)
        echo -e "${Info} 使用apk安装Flask..."
        apk add --no-cache py3-flask py3-flask-cors > /dev/null 2>&1
        ;;
    *)
        echo -e "${Warn} 无法识别系统类型，尝试使用apt..."
        apt update > /dev/null 2>&1 || true
        apt install -y python3-flask python3-flask-cors > /dev/null 2>&1 || true
        ;;
esac

# 验证Flask是否安装
if python3 -c "import flask; import flask_cors" 2>/dev/null; then
    echo -e "${Info} Flask依赖安装成功"
else
    echo -e "${Error} Flask依赖安装失败"
    echo "请手动执行以下命令:"
    echo ""
    echo "  Debian/Ubuntu:"
    echo "    sudo apt update"
    echo "    sudo apt install -y python3-flask python3-flask-cors"
    echo ""
    echo "  CentOS/RHEL:"
    echo "    sudo yum install -y python3-flask python3-flask-cors"
    echo ""
    exit 1
fi

# 创建应用目录
APP_DIR="/opt/gost-web-manager"
echo -e "${Info} 创建应用目录: $APP_DIR"
mkdir -p "$APP_DIR/web/static"

# 下载文件
GITHUB_URL="https://raw.githubusercontent.com/lgdglgc/EasyGost/main"

echo -e "${Info} 下载应用文件..."
curl -fsSL "${GITHUB_URL}/gost-web-manager.py" -o "$APP_DIR/gost-web-manager.py"
curl -fsSL "${GITHUB_URL}/web/index.html" -o "$APP_DIR/web/index.html"
curl -fsSL "${GITHUB_URL}/web/static/app.js" -o "$APP_DIR/web/static/app.js"
curl -fsSL "${GITHUB_URL}/web/static/style.css" -o "$APP_DIR/web/static/style.css"

# 修改Flask绑定地址为0.0.0.0以支持远程访问
echo -e "${Info} 配置Flask绑定地址..."
sed -i "s/host='127.0.0.1'/host='0.0.0.0'/g" "$APP_DIR/gost-web-manager.py"
sed -i "s/host=\"127.0.0.1\"/host=\"0.0.0.0\"/g" "$APP_DIR/gost-web-manager.py"

# 设置权限
chmod 755 "$APP_DIR"
chmod 644 "$APP_DIR"/*.py
chmod -R 755 "$APP_DIR/web"

# 安装systemd服务
echo -e "${Info} 安装systemd服务..."
cat > /etc/systemd/system/gost-web-manager.service << 'EOF'
[Unit]
Description=GOST Web Management Panel
After=network.target gost.service
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/gost-web-manager
ExecStart=/usr/bin/python3 /opt/gost-web-manager/gost-web-manager.py
Restart=on-failure
RestartSec=5

StandardOutput=journal
StandardError=journal
SyslogIdentifier=gost-web-manager

NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/etc/gost

ExecStartPre=/bin/sleep 2

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

# 安装快速控制脚本
echo -e "${Info} 安装快速控制脚本..."
curl -fsSL "${GITHUB_URL}/gost-web" -o /usr/local/bin/gost-web
chmod +x /usr/local/bin/gost-web

# 创建配置目录
echo -e "${Info} 初始化配置目录..."
mkdir -p /etc/gost
chmod 755 /etc/gost
touch /etc/gost/rawconf
chmod 644 /etc/gost/rawconf

# 启动服务
echo -e "${Info} 启动GOST Web管理面板..."
systemctl start gost-web-manager
systemctl enable gost-web-manager
sleep 2

# 检查服务状态
if systemctl is-active --quiet gost-web-manager; then
    echo -e "${Green_font_prefix}"
    echo "╔════════════════════════════════════════════╗"
    echo "║   安装完成！                              ║"
    echo "╚════════════════════════════════════════════╝"
    echo -e "${Font_color_suffix}"
    
    local_ip=$(hostname -I | awk '{print $1}')
    if [ -z "$local_ip" ]; then
        local_ip="127.0.0.1"
    fi
    
    echo ""
    echo -e "${Green_font_prefix}✓${Font_color_suffix} GOST转发服务正在运行"
    echo -e "${Green_font_prefix}✓${Font_color_suffix} EasyGost Web管理面板已启动"
    echo ""
    echo "════════════════════════════════════════════"
    echo "📊 工作流程说明:"
    echo "════════════════════════════════════════════"
    echo ""
    echo "1️⃣  打开Web面板"
    echo "   http://${local_ip}:8888"
    echo ""
    echo "2️⃣  在Web面板中:"
    echo "   • 点击 [添加规则] 创建转发规则"
    echo "   • 选择规则类型、配置端口和目标"
    echo "   • 点击 [保存] 保存规则"
    echo ""
    echo "3️⃣  应用配置"
    echo "   • Web面板会自动将规则写入 /etc/gost/rawconf"
    echo "   • 点击 [应用配置] 重启GOST服务"
    echo "   • GOST立即执行新的转发规则"
    echo ""
    echo "════════════════════════════════════════════"
    echo "🔧 快速命令:"
    echo "════════════════════════════════════════════"
    echo ""
    echo "  sudo gost-web start     - 启动Web面板"
    echo "  sudo gost-web stop      - 停止Web面板"
    echo "  sudo gost-web restart   - 重启Web面板"
    echo "  sudo gost-web status    - 查看状态"
    echo "  sudo gost-web logs      - 查看日志"
    echo ""
    echo "════════════════════════════════════════════"
    echo "📚 相关资源:"
    echo "════════════════════════════════════════════"
    echo ""
    echo "  项目地址: https://github.com/lgdglgc/EasyGost"
    echo "  GOST官方: https://docs.ginuerzh.xyz/gost/"
    echo "  配置文件: /etc/gost/rawconf"
    echo ""
else
    echo -e "${Error} 服务启动失败"
    systemctl status gost-web-manager
    exit 1
fi
