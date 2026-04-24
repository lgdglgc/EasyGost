#!/bin/bash
# ╔══════════════════════════════════════╗
# ║  EasyGost — 一键安装/卸载脚本       ║
# ║  Web管理面板 + GOST转发服务          ║
# ╚══════════════════════════════════════╝

set -e

G="\033[32m" R="\033[31m" Y="\033[33m" B="\033[34m" E="\033[0m"
OK="${G}[✓]${E}" ERR="${R}[✗]${E}" WARN="${Y}[!]${E}" INFO="${B}[→]${E}"

GOST_VER="2.11.2"
APP_DIR="/opt/gost-web"
GOST_CONF="/etc/gost/config.json"
RAW_CONF="/etc/gost/rawconf"
GITHUB_RAW="https://raw.githubusercontent.com/lgdglgc/EasyGost/main"

# ── 检查root ────────────────────────────────────────────────────────────────
check_root() {
    [[ $EUID -eq 0 ]] || { echo -e "${ERR} 请使用 root 权限运行"; exit 1; }
}

# ── 检测系统 ────────────────────────────────────────────────────────────────
detect_sys() {
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64) GOST_ARCH="amd64" ;;
        aarch64|arm64) GOST_ARCH="arm64" ;;
        armv7l) GOST_ARCH="armv7" ;;
        i686)   GOST_ARCH="386" ;;
        *) echo -e "${WARN} 未知架构 $ARCH，请手动输入（386/amd64/arm64/armv7）:"
           read -r GOST_ARCH ;;
    esac
    if   [[ -f /etc/debian_version ]]; then PKG="apt"
    elif [[ -f /etc/redhat-release ]]; then PKG="yum"
    elif [[ -f /etc/alpine-release ]]; then PKG="apk"
    else PKG="apt"; fi
}

# ── 安装依赖 ────────────────────────────────────────────────────────────────
install_deps() {
    echo -e "${INFO} 安装依赖（socat / wget）..."
    case "$PKG" in
        apt) apt-get update -qq && apt-get install -y socat wget curl >/dev/null 2>&1 ;;
        yum) yum install -y socat wget curl >/dev/null 2>&1 ;;
        apk) apk add --no-cache socat wget curl >/dev/null 2>&1 ;;
    esac
    command -v socat >/dev/null || { echo -e "${ERR} socat 安装失败"; exit 1; }
    echo -e "${OK} 依赖安装完成"
}

# ── 安装 GOST 二进制 ─────────────────────────────────────────────────────────
install_gost_bin() {
    if command -v gost >/dev/null 2>&1; then
        echo -e "${OK} GOST 已安装: $(gost -V 2>&1 | head -1)"
        return
    fi

    echo -e "${INFO} 下载 GOST v${GOST_VER} (${GOST_ARCH})..."

    read -e -p "$(echo -e "${WARN}") 是否使用国内镜像加速下载? [y/N]: " use_cn
    local URL
    if [[ "$use_cn" =~ ^[Yy]$ ]]; then
        URL="https://gotunnel.oss-cn-shenzhen.aliyuncs.com/gost-linux-${GOST_ARCH}-${GOST_VER}.gz"
    else
        URL="https://github.com/ginuerzh/gost/releases/download/v${GOST_VER}/gost-linux-${GOST_ARCH}-${GOST_VER}.gz"
    fi

    local TMP; TMP=$(mktemp -d)
    wget -q --no-check-certificate "$URL" -O "$TMP/gost.gz" || {
        echo -e "${ERR} 下载失败，请检查网络"; rm -rf "$TMP"; exit 1
    }
    gunzip "$TMP/gost.gz"
    install -m755 "$TMP/gost" /usr/bin/gost
    rm -rf "$TMP"
    echo -e "${OK} GOST 安装成功"
}

# ── 安装 GOST Systemd 服务 ───────────────────────────────────────────────────
install_gost_service() {
    mkdir -p /etc/gost /usr/lib/systemd/system

    # 初始 config.json（空规则）
    if [[ ! -f "$GOST_CONF" ]]; then
        cat > "$GOST_CONF" << 'CONF'
{
    "Debug": true,
    "Retries": 0,
    "ServeNodes": [
        "tcp://127.0.0.1:65532"
    ]
}
CONF
    fi
    touch "$RAW_CONF"
    chmod 644 "$RAW_CONF" "$GOST_CONF"

    cat > /usr/lib/systemd/system/gost.service << 'SVC'
[Unit]
Description=GOST Proxy/Relay Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Restart=always
RestartSec=5
ExecStart=/usr/bin/gost -C /etc/gost/config.json

[Install]
WantedBy=multi-user.target
SVC

    systemctl daemon-reload
    systemctl enable gost >/dev/null 2>&1
    systemctl restart gost
    echo -e "${OK} GOST 服务已启动"
}

# ── 安装 Web 管理面板 ────────────────────────────────────────────────────────
install_web_panel() {
    echo -e "${INFO} 安装 Web 管理面板到 ${APP_DIR}..."
    mkdir -p "$APP_DIR"

    # 优先使用脚本同级目录的文件，否则从 GitHub 下载
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    if [[ -f "$SCRIPT_DIR/gost-web.sh" ]]; then
        cp "$SCRIPT_DIR/gost-web.sh" "$APP_DIR/gost-web.sh"
        echo -e "${OK} gost-web.sh 使用本地文件"
    else
        wget -q "$GITHUB_RAW/gost-web.sh" -O "$APP_DIR/gost-web.sh" || {
            echo -e "${ERR} 下载 gost-web.sh 失败"; exit 1
        }
    fi

    if [[ -f "$SCRIPT_DIR/web/index.html" ]]; then
        cp "$SCRIPT_DIR/web/index.html" "$APP_DIR/index.html"
        echo -e "${OK} index.html 使用本地文件"
    else
        wget -q "$GITHUB_RAW/web/index.html" -O "$APP_DIR/index.html" || {
            echo -e "${ERR} 下载 index.html 失败"; exit 1
        }
    fi

    chmod +x "$APP_DIR/gost-web.sh"

    # Systemd 服务
    cat > /etc/systemd/system/gost-web.service << 'SVC'
[Unit]
Description=GOST Web Management Panel
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/socat TCP-LISTEN:8888,fork,reuseaddr EXEC:/opt/gost-web/gost-web.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
SVC

    systemctl daemon-reload
    systemctl enable gost-web >/dev/null 2>&1
    systemctl restart gost-web
    sleep 1
    echo -e "${OK} Web 管理面板已启动"
}

# ── 卸载 ────────────────────────────────────────────────────────────────────
uninstall_all() {
    echo -e "${WARN} 即将卸载 GOST 和 Web 管理面板，配置将被删除！"
    read -e -p "确认卸载? [y/N]: " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { echo "已取消"; exit 0; }

    for svc in gost-web gost; do
        systemctl stop "$svc"    2>/dev/null || true
        systemctl disable "$svc" 2>/dev/null || true
    done

    rm -f /etc/systemd/system/gost-web.service
    rm -f /usr/lib/systemd/system/gost.service
    rm -f /usr/bin/gost
    rm -rf /etc/gost
    rm -rf "$APP_DIR"
    systemctl daemon-reload

    echo -e "${OK} 卸载完成"
}

# ── 显示状态 ─────────────────────────────────────────────────────────────────
show_status() {
    echo ""
    local ip; ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    [[ -z "$ip" ]] && ip="<VPS_IP>"

    echo -e "${G}╔════════════════════════════════════════╗${E}"
    echo -e "${G}║        安装完成！                      ║${E}"
    echo -e "${G}╚════════════════════════════════════════╝${E}"
    echo ""
    echo -e " ${OK} GOST 服务:    $(systemctl is-active gost 2>/dev/null)"
    echo -e " ${OK} Web 面板:     $(systemctl is-active gost-web 2>/dev/null)"
    echo ""
    echo -e " 🌐 访问地址: ${G}http://${ip}:8888${E}"
    echo ""
    echo -e " 🔧 常用命令:"
    echo    "    systemctl status  gost-web   # 面板状态"
    echo    "    systemctl restart gost-web   # 重启面板"
    echo    "    systemctl restart gost       # 重启 GOST"
    echo    "    journalctl -u gost-web -f    # 查看面板日志"
    echo ""
    echo -e " 📁 配置文件: ${Y}/etc/gost/rawconf${E}"
    echo ""
}

# ══════════════════════════ 主菜单 ═══════════════════════════════════════════

check_root
detect_sys

echo ""
echo -e "${G}╔════════════════════════════════════════╗${E}"
echo -e "${G}║   EasyGost — GOST Web 管理面板         ║${E}"
echo -e "${G}║   纯 Bash 实现，无 Python 依赖          ║${E}"
echo -e "${G}╚════════════════════════════════════════╝${E}"
echo ""
echo -e " ${G}1.${E} 安装 GOST + Web 管理面板"
echo -e " ${G}2.${E} 卸载 GOST + Web 管理面板"
echo -e " ${R}0.${E} 退出"
echo ""
read -e -p " 请选择 [0-2]: " num

case "$num" in
    1)
        echo ""
        install_deps
        install_gost_bin
        install_gost_service
        install_web_panel
        show_status
        ;;
    2)
        echo ""
        uninstall_all
        ;;
    0|*)
        echo "已退出"
        exit 0
        ;;
esac
