#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOST Web管理面板 - 后端API服务
支持规则的可视化管理、添加、编辑、删除和配置生成
"""

import os
import json
import subprocess
import re
from pathlib import Path
from flask import Flask, render_template, request, jsonify
from flask_cors import CORS

app = Flask(__name__, template_folder='web', static_folder='web/static')
CORS(app)

# 配置文件路径
GOST_CONF_PATH = "/etc/gost/config.json"
RAW_CONF_PATH = "/etc/gost/rawconf"

# 规则类型映射
PROTOCOL_TYPES = {
    "1": {"name": "tcp+udp转发", "value": "nonencrypt", "desc": "不加密转发"},
    "2": {"name": "加密隧道(TLS)", "value": "encrypttls", "desc": "relay+tls加密"},
    "3": {"name": "加密隧道(WS)", "value": "encryptws", "desc": "relay+ws加密"},
    "4": {"name": "加密隧道(WSS)", "value": "encryptwss", "desc": "relay+wss加密"},
    "5": {"name": "解密(TLS)", "value": "decrypttls", "desc": "relay+tls解密"},
    "6": {"name": "解密(WS)", "value": "decryptws", "desc": "relay+ws解密"},
    "7": {"name": "解密(WSS)", "value": "decryptwss", "desc": "relay+wss解密"},
    "8": {"name": "Shadowsocks", "value": "ss", "desc": "shadowsocks代理"},
    "9": {"name": "SOCKS5", "value": "socks", "desc": "socks5代理"},
    "10": {"name": "HTTP", "value": "http", "desc": "http代理"},
    "11": {"name": "均衡负载(无加密)", "value": "peerno", "desc": "多落地轮询"},
    "12": {"name": "均衡负载(TLS)", "value": "peertls", "desc": "多落地TLS轮询"},
    "13": {"name": "均衡负载(WS)", "value": "peerws", "desc": "多落地WS轮询"},
    "14": {"name": "均衡负载(WSS)", "value": "peerwss", "desc": "多落地WSS轮询"},
    "15": {"name": "CDN转发(无加密)", "value": "cdnno", "desc": "CDN自选节点"},
    "16": {"name": "CDN转发(WS)", "value": "cdnws", "desc": "CDN WS隧道"},
    "17": {"name": "CDN转发(WSS)", "value": "cdnwss", "desc": "CDN WSS隧道"},
}

BALANCE_STRATEGY = {
    "1": {"name": "轮询", "value": "round"},
    "2": {"name": "随机", "value": "random"},
    "3": {"name": "自上而下", "value": "fifo"},
}

SS_ENCRYPT = {
    "1": "aes-256-gcm",
    "2": "aes-256-cfb",
    "3": "chacha20-ietf-poly1305",
    "4": "chacha20",
    "5": "rc4-md5",
    "6": "AEAD_CHACHA20_POLY1305",
}


class RuleManager:
    """规则管理器"""
    
    @staticmethod
    def parse_raw_conf():
        """解析原始配置文件"""
        rules = []
        if not os.path.exists(RAW_CONF_PATH):
            return rules
        
        try:
            with open(RAW_CONF_PATH, 'r', encoding='utf-8') as f:
                for i, line in enumerate(f, 1):
                    line = line.strip()
                    if not line:
                        continue
                    
                    # 格式: type/port#dest_ip#dest_port
                    parts = line.split('/')
                    if len(parts) < 2:
                        continue
                    
                    rule_type = parts[0]
                    rest = '/'.join(parts[1:])
                    
                    # 处理链式规则
                    if '#' in rest:
                        conf_parts = rest.split('#')
                        local_port = conf_parts[0] if conf_parts else ""
                        dest_ip = conf_parts[1] if len(conf_parts) > 1 else ""
                        dest_port = conf_parts[2] if len(conf_parts) > 2 else ""
                    else:
                        local_port = rest
                        dest_ip = ""
                        dest_port = ""
                    
                    rules.append({
                        "id": i,
                        "type": rule_type,
                        "local_port": local_port,
                        "dest_ip": dest_ip,
                        "dest_port": dest_port,
                        "raw": line
                    })
        except Exception as e:
            print(f"Error reading raw conf: {e}")
        
        return rules
    
    @staticmethod
    def write_raw_conf(rules):
        """写入原始配置文件"""
        try:
            os.makedirs(os.path.dirname(RAW_CONF_PATH), exist_ok=True)
            with open(RAW_CONF_PATH, 'w', encoding='utf-8') as f:
                for rule in rules:
                    if rule['type'] in ['peerno', 'peertls', 'peerws', 'peerwss']:
                        # 均衡负载格式
                        line = f"{rule['type']}/{rule['local_port']}#{rule['dest_ip']}#{rule['dest_port']}\n"
                    elif rule['type'] in ['cdnno', 'cdnws', 'cdnwss']:
                        # CDN转发格式
                        line = f"{rule['type']}/{rule['local_port']}#{rule['dest_ip']}#{rule['dest_port']}\n"
                    else:
                        # 普通格式
                        line = f"{rule['type']}/{rule['local_port']}#{rule['dest_ip']}#{rule['dest_port']}\n"
                    f.write(line)
            return True
        except Exception as e:
            print(f"Error writing raw conf: {e}")
            return False
    
    @staticmethod
    def add_rule(rule_data):
        """添加规则"""
        rules = RuleManager.parse_raw_conf()
        rules.append(rule_data)
        return RuleManager.write_raw_conf(rules)
    
    @staticmethod
    def delete_rule(rule_id):
        """删除规则"""
        rules = RuleManager.parse_raw_conf()
        rules = [r for r in rules if r['id'] != rule_id]
        # 重新编号
        for i, r in enumerate(rules, 1):
            r['id'] = i
        return RuleManager.write_raw_conf(rules)
    
    @staticmethod
    def update_rule(rule_id, rule_data):
        """更新规则"""
        rules = RuleManager.parse_raw_conf()
        for i, rule in enumerate(rules):
            if rule['id'] == rule_id:
                rules[i] = {**rule, **rule_data}
                break
        return RuleManager.write_raw_conf(rules)


class ConfigGenerator:
    """配置文件生成器"""
    
    @staticmethod
    def generate_config(rules):
        """生成GOST配置文件"""
        if not rules:
            return {
                "Debug": True,
                "Retries": 0,
                "ServeNodes": []
            }
        
        config = {
            "Debug": True,
            "Retries": 0,
            "ServeNodes": [],
            "Routes": []
        }
        
        # TODO: 根据规则类型生成对应的ServeNodes和Routes配置
        # 这是一个复杂的过程，需要根据不同的加密类型生成不同的配置
        
        return config
    
    @staticmethod
    def apply_config():
        """应用配置到GOST"""
        try:
            # 重新生成config.json
            result = subprocess.run(
                ["bash", "-c", "cd /etc/gost && /path/to/gost.sh restart"],
                capture_output=True,
                timeout=10
            )
            return result.returncode == 0
        except Exception as e:
            print(f"Error applying config: {e}")
            return False


# ==================== API端点 ====================

@app.route('/')
def index():
    """主页"""
    return render_template('index.html')


@app.route('/api/rules', methods=['GET'])
def get_rules():
    """获取所有规则"""
    try:
        rules = RuleManager.parse_raw_conf()
        return jsonify({
            "success": True,
            "data": rules,
            "total": len(rules)
        })
    except Exception as e:
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500


@app.route('/api/rules', methods=['POST'])
def create_rule():
    """创建新规则"""
    try:
        data = request.get_json()
        
        # 验证必要字段
        required_fields = ['type', 'local_port', 'dest_ip', 'dest_port']
        if not all(field in data for field in required_fields):
            return jsonify({
                "success": False,
                "error": "缺少必要字段"
            }), 400
        
        rule_data = {
            "type": data['type'],
            "local_port": data['local_port'],
            "dest_ip": data['dest_ip'],
            "dest_port": data['dest_port']
        }
        
        if RuleManager.add_rule(rule_data):
            return jsonify({
                "success": True,
                "message": "规则已添加"
            })
        else:
            return jsonify({
                "success": False,
                "error": "添加规则失败"
            }), 500
    except Exception as e:
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500


@app.route('/api/rules/<int:rule_id>', methods=['PUT'])
def update_rule(rule_id):
    """更新规则"""
    try:
        data = request.get_json()
        
        if RuleManager.update_rule(rule_id, data):
            return jsonify({
                "success": True,
                "message": "规则已更新"
            })
        else:
            return jsonify({
                "success": False,
                "error": "更新规则失败"
            }), 500
    except Exception as e:
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500


@app.route('/api/rules/<int:rule_id>', methods=['DELETE'])
def delete_rule(rule_id):
    """删除规则"""
    try:
        if RuleManager.delete_rule(rule_id):
            return jsonify({
                "success": True,
                "message": "规则已删除"
            })
        else:
            return jsonify({
                "success": False,
                "error": "删除规则失败"
            }), 500
    except Exception as e:
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500


@app.route('/api/rules/apply', methods=['POST'])
def apply_rules():
    """应用配置并重启GOST"""
    try:
        # 调用systemctl重启gost
        result = subprocess.run(
            ["systemctl", "restart", "gost"],
            capture_output=True,
            timeout=10
        )
        
        if result.returncode == 0:
            return jsonify({
                "success": True,
                "message": "配置已应用，GOST已重启"
            })
        else:
            return jsonify({
                "success": False,
                "error": "重启GOST失败: " + result.stderr.decode()
            }), 500
    except Exception as e:
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500


@app.route('/api/gost/status', methods=['GET'])
def get_gost_status():
    """获取GOST服务状态"""
    try:
        result = subprocess.run(
            ["systemctl", "is-active", "gost"],
            capture_output=True,
            timeout=5
        )
        
        status = result.stdout.decode().strip()
        return jsonify({
            "success": True,
            "status": status,
            "is_running": status == "active"
        })
    except Exception as e:
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500


@app.route('/api/gost/start', methods=['POST'])
def start_gost():
    """启动GOST"""
    try:
        result = subprocess.run(
            ["systemctl", "start", "gost"],
            capture_output=True,
            timeout=10
        )
        
        if result.returncode == 0:
            return jsonify({
                "success": True,
                "message": "GOST已启动"
            })
        else:
            return jsonify({
                "success": False,
                "error": "启动GOST失败"
            }), 500
    except Exception as e:
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500


@app.route('/api/gost/stop', methods=['POST'])
def stop_gost():
    """停止GOST"""
    try:
        result = subprocess.run(
            ["systemctl", "stop", "gost"],
            capture_output=True,
            timeout=10
        )
        
        if result.returncode == 0:
            return jsonify({
                "success": True,
                "message": "GOST已停止"
            })
        else:
            return jsonify({
                "success": False,
                "error": "停止GOST失败"
            }), 500
    except Exception as e:
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500


@app.route('/api/protocol-types', methods=['GET'])
def get_protocol_types():
    """获取协议类型列表"""
    return jsonify({
        "success": True,
        "data": PROTOCOL_TYPES
    })


@app.route('/api/balance-strategies', methods=['GET'])
def get_balance_strategies():
    """获取负载均衡策略列表"""
    return jsonify({
        "success": True,
        "data": BALANCE_STRATEGY
    })


@app.route('/api/ss-encrypts', methods=['GET'])
def get_ss_encrypts():
    """获取Shadowsocks加密方式"""
    return jsonify({
        "success": True,
        "data": SS_ENCRYPT
    })


@app.route('/api/health', methods=['GET'])
def health_check():
    """健康检查"""
    return jsonify({
        "success": True,
        "status": "ok"
    })


if __name__ == '__main__':
    # 初始化 - 确保配置目录存在
    try:
        os.makedirs('/etc/gost', exist_ok=True)
        
        # 如果rawconf文件不存在，创建空文件
        if not os.path.exists(RAW_CONF_PATH):
            Path(RAW_CONF_PATH).touch(exist_ok=True)
            
        # 设置正确的权限
        os.chmod('/etc/gost', 0o755)
        
        print("[✓] GOST配置目录已初始化")
    except Exception as e:
        print(f"[!] 初始化失败: {e}")
    
    # 需要root权限运行以访问/etc/gost目录
    print("[*] GOST Web 管理面板启动中...")
    print("[*] 访问地址: http://0.0.0.0:8888")
    print("[*] 按 Ctrl+C 停止服务")
    
    app.run(host='0.0.0.0', port=8888, debug=False)
