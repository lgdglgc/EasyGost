#!/bin/bash
# GOST Web Manager - Pure Bash HTTP Handler
# Called by socat for each HTTP connection

RAW_CONF="/etc/gost/rawconf"
GOST_CONF="/etc/gost/config.json"
HTML_FILE="/opt/gost-web/index.html"
TOKEN_FILE="/tmp/gost-web-token"

# Default credentials (change here if needed)
ADMIN_USER="admin"
ADMIN_PASS="admin123456"

# Ensure standard tools are found regardless of environment PATH
export PATH=/usr/sbin:/usr/bin:/sbin:/bin:$PATH

# ─── HTTP helpers ───────────────────────────────────────────────────────────

send_response() {
    local status="$1" ctype="$2" body="$3"
    # Use byte length (LC_ALL=C ensures ${#} counts bytes not chars)
    local len; len=$(LC_ALL=C printf '%s' "$body" | wc -c | tr -d ' ')
    # HTTP/1.0 + Connection: close ensures socat child exits cleanly
    printf 'HTTP/1.0 %s\r\nContent-Type: %s\r\nContent-Length: %s\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n%s' \
        "$status" "$ctype" "$len" "$body"
    # Flush stdout so socat sends all data before script exits
    sync 2>/dev/null || true
}

json_ok()   { send_response "200 OK"    "application/json" "$1"; }
json_err()  { send_response "500 Error" "application/json" "{\"success\":false,\"error\":\"$1\"}"; }
json_401()  { send_response "401 Unauthorized" "application/json" '{"success":false,"error":"未授权"}'; }

# ─── Auth Helpers ────────────────────────────────────────────────────────────

generate_token() {
    # Generate a random 32-char hex token
    cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-' || \
    dd if=/dev/urandom bs=16 count=1 2>/dev/null | xxd -p | tr -d '\n'
}

api_login() {
    local body="$1"
    local user pass
    user=$(printf '%s' "$body" | grep -o '"username":"[^"]*"' | head -1 | cut -d'"' -f4)
    pass=$(printf '%s' "$body" | grep -o '"password":"[^"]*"' | head -1 | cut -d'"' -f4)
    if [[ "$user" == "$ADMIN_USER" && "$pass" == "$ADMIN_PASS" ]]; then
        local token; token=$(generate_token)
        printf '%s' "$token" > "$TOKEN_FILE"
        json_ok "{\"success\":true,\"token\":\"$token\"}"
    else
        send_response "401 Unauthorized" "application/json" '{"success":false,"error":"账号或密码错误"}'
    fi
}

check_auth() {
    # Returns 0 if token is valid, 1 otherwise
    local token="$1"
    [[ -z "$token" ]] && return 1
    [[ -f "$TOKEN_FILE" ]] || return 1
    local stored; stored=$(cat "$TOKEN_FILE" 2>/dev/null)
    [[ "$token" == "$stored" ]] && return 0 || return 1
}

# ─── Config Generator (ported from original gost.sh) ────────────────────────

generate_config() {
    rm -f "$GOST_CONF"
    local count_line
    count_line=$(grep -c . "$RAW_CONF" 2>/dev/null || echo 0)

    if [[ $count_line -eq 0 ]]; then
        printf '{\n    "Debug": true,\n    "Retries": 0,\n    "ServeNodes": [\n        "tcp://127.0.0.1:65532"\n    ]\n}\n' > "$GOST_CONF"
        return
    fi

    local i=1
    while IFS= read -r line; do
        [[ -z "$line" ]] && { ((i++)); continue; }

        local is_encrypt="${line%%/*}"
        local rest="${line#*/}"
        local s_port="${rest%%#*}"
        local d_server="${rest#*#}"
        local d_ip="${d_server%%#*}"
        local d_port="${d_server##*#}"

        if [[ $i -eq 1 ]]; then
            printf '{\n    "Debug": true,\n    "Retries": 0,\n    "ServeNodes": [\n' >> "$GOST_CONF"
            write_node "$is_encrypt" "$s_port" "$d_ip" "$d_port" "first" >> "$GOST_CONF"
        else
            [[ $i -eq 2 ]] && printf '    ],\n    "Routes": [\n' >> "$GOST_CONF"
            printf '        {\n            "Retries": 0,\n            "ServeNodes": [\n' >> "$GOST_CONF"
            write_node "$is_encrypt" "$s_port" "$d_ip" "$d_port" "route" >> "$GOST_CONF"
            if [[ $i -eq $count_line ]]; then
                printf '            ]\n        }\n' >> "$GOST_CONF"
            else
                printf '            ]\n        },\n' >> "$GOST_CONF"
            fi
        fi
        ((i++))
    done < "$RAW_CONF"

    printf '    ]\n}\n' >> "$GOST_CONF"
}

write_node() {
    local enc="$1" sp="$2" dip="$3" dp="$4" mode="$5"
    local pad="        "; [[ "$mode" == "route" ]] && pad="                "

    case "$enc" in
        nonencrypt)
            printf '%s"tcp://:%s/%s:%s",\n%s"udp://:%s/%s:%s"\n' \
                "$pad" "$sp" "$dip" "$dp" "$pad" "$sp" "$dip" "$dp" ;;
        encrypttls)
            printf '%s"tcp://:%s",\n%s"udp://:%s"\n    ],\n    "ChainNodes": [\n        "relay+tls://%s:%s"\n' \
                "$pad" "$sp" "$pad" "$sp" "$dip" "$dp" ;;
        encryptws)
            printf '%s"tcp://:%s",\n%s"udp://:%s"\n    ],\n    "ChainNodes": [\n        "relay+ws://%s:%s"\n' \
                "$pad" "$sp" "$pad" "$sp" "$dip" "$dp" ;;
        encryptwss)
            printf '%s"tcp://:%s",\n%s"udp://:%s"\n    ],\n    "ChainNodes": [\n        "relay+wss://%s:%s"\n' \
                "$pad" "$sp" "$pad" "$sp" "$dip" "$dp" ;;
        decrypttls)
            if [[ -d "$HOME/gost_cert" ]]; then
                printf '%s"relay+tls://:%s/%s:%s?cert=/root/gost_cert/cert.pem&key=/root/gost_cert/key.pem"\n' "$pad" "$sp" "$dip" "$dp"
            else
                printf '%s"relay+tls://:%s/%s:%s"\n' "$pad" "$sp" "$dip" "$dp"
            fi ;;
        decryptws)  printf '%s"relay+ws://:%s/%s:%s"\n'  "$pad" "$sp" "$dip" "$dp" ;;
        decryptwss)
            if [[ -d "$HOME/gost_cert" ]]; then
                printf '%s"relay+wss://:%s/%s:%s?cert=/root/gost_cert/cert.pem&key=/root/gost_cert/key.pem"\n' "$pad" "$sp" "$dip" "$dp"
            else
                printf '%s"relay+wss://:%s/%s:%s"\n' "$pad" "$sp" "$dip" "$dp"
            fi ;;
        ss)    printf '%s"ss://%s:%s@:%s"\n'     "$pad" "$dip" "$sp" "$dp" ;;
        socks) printf '%s"socks5://%s:%s@:%s"\n' "$pad" "$dip" "$sp" "$dp" ;;
        http)  printf '%s"http://%s:%s@:%s"\n'   "$pad" "$dip" "$sp" "$dp" ;;
        peerno)
            printf '%s"tcp://:%s?ip=/root/%s.txt&strategy=%s",\n%s"udp://:%s?ip=/root/%s.txt&strategy=%s"\n' \
                "$pad" "$sp" "$dip" "$dp" "$pad" "$sp" "$dip" "$dp" ;;
        peertls)
            printf '%s"tcp://:%s",\n%s"udp://:%s"\n    ],\n    "ChainNodes": [\n        "relay+tls://:?ip=/root/%s.txt&strategy=%s"\n' \
                "$pad" "$sp" "$pad" "$sp" "$dip" "$dp" ;;
        peerws)
            printf '%s"tcp://:%s",\n%s"udp://:%s"\n    ],\n    "ChainNodes": [\n        "relay+ws://:?ip=/root/%s.txt&strategy=%s"\n' \
                "$pad" "$sp" "$pad" "$sp" "$dip" "$dp" ;;
        peerwss)
            printf '%s"tcp://:%s",\n%s"udp://:%s"\n    ],\n    "ChainNodes": [\n        "relay+wss://:?ip=/root/%s.txt&strategy=%s"\n' \
                "$pad" "$sp" "$pad" "$sp" "$dip" "$dp" ;;
        cdnno)
            printf '%s"tcp://:%s/%s?host=%s",\n%s"udp://:%s/%s?host=%s"\n' \
                "$pad" "$sp" "$dip" "$dp" "$pad" "$sp" "$dip" "$dp" ;;
        cdnws)
            printf '%s"tcp://:%s",\n%s"udp://:%s"\n    ],\n    "ChainNodes": [\n        "relay+ws://%s?host=%s"\n' \
                "$pad" "$sp" "$pad" "$sp" "$dip" "$dp" ;;
        cdnwss)
            printf '%s"tcp://:%s",\n%s"udp://:%s"\n    ],\n    "ChainNodes": [\n        "relay+wss://%s?host=%s"\n' \
                "$pad" "$sp" "$pad" "$sp" "$dip" "$dp" ;;
        *) printf '%s"tcp://:%s/%s:%s"\n' "$pad" "$sp" "$dip" "$dp" ;;
    esac
}

# ─── API Handlers ────────────────────────────────────────────────────────────

api_get_rules() {
    touch "$RAW_CONF"
    local json="[" first=true i=1
    while IFS= read -r line; do
        [[ -z "$line" ]] && { ((i++)); continue; }
        local type="${line%%/*}" rest="${line#*/}"
        local lp="${rest%%#*}" ds="${rest#*#}"
        local dip="${ds%%#*}" dp="${ds##*#}"
        $first || json+=","
        first=false
        # escape for JSON
        json+="{\"id\":$i,\"type\":\"$type\",\"local_port\":\"$lp\",\"dest_ip\":\"$dip\",\"dest_port\":\"$dp\"}"
        ((i++))
    done < "$RAW_CONF"
    json+="]"
    json_ok "{\"success\":true,\"data\":$json}"
}

api_add_rule() {
    local body="$1"
    local type lp dip dp
    type=$(printf '%s' "$body" | grep -o '"type":"[^"]*"' | head -1 | cut -d'"' -f4)
    lp=$(printf '%s' "$body"   | grep -o '"local_port":"[^"]*"' | head -1 | cut -d'"' -f4)
    dip=$(printf '%s' "$body"  | grep -o '"dest_ip":"[^"]*"' | head -1 | cut -d'"' -f4)
    dp=$(printf '%s' "$body"   | grep -o '"dest_port":"[^"]*"' | head -1 | cut -d'"' -f4)

    if [[ -z "$type" || -z "$lp" || -z "$dp" ]]; then
        json_err "缺少必要字段"; return
    fi

    printf '%s/%s#%s#%s\n' "$type" "$lp" "$dip" "$dp" >> "$RAW_CONF"
    generate_config
    systemctl restart gost 2>/dev/null
    json_ok '{"success":true,"message":"规则已添加并已重启"}'
}

api_delete_rule() {
    local id="$1"
    if ! [[ "$id" =~ ^[0-9]+$ ]]; then json_err "无效ID"; return; fi
    sed -i "${id}d" "$RAW_CONF"
    generate_config
    systemctl restart gost 2>/dev/null
    json_ok '{"success":true,"message":"规则已删除并已重启"}'
}

api_get_status() {
    local st
    st=$(systemctl is-active gost 2>/dev/null)
    local running=false
    [[ "$st" == "active" ]] && running=true
    json_ok "{\"success\":true,\"status\":\"$st\",\"is_running\":$running}"
}

api_restart() {
    generate_config
    systemctl restart gost 2>/dev/null
    json_ok '{"success":true,"message":"GOST已重启"}'
}

# ─── Serve HTML ──────────────────────────────────────────────────────────────

serve_html() {
    if [[ -f "$HTML_FILE" ]]; then
        local body; body=$(cat "$HTML_FILE")
        send_response "200 OK" "text/html; charset=utf-8" "$body"
    else
        send_response "404 Not Found" "text/plain" "index.html not found"
    fi
}

# ─── Main Request Dispatcher ─────────────────────────────────────────────────

# Read request line
IFS= read -r req_line
req_line="${req_line%$'\r'}"
method=$(awk '{print $1}' <<< "$req_line")
path=$(awk '{print $2}' <<< "$req_line")

# Read headers
content_length=0
auth_token=""
while IFS= read -r hdr; do
    hdr="${hdr%$'\r'}"
    [[ -z "$hdr" ]] && break
    if [[ "$hdr" =~ ^[Cc]ontent-[Ll]ength:[[:space:]]*([0-9]+) ]]; then
        content_length="${BASH_REMATCH[1]}"
    fi
    if [[ "$hdr" =~ ^[Xx]-[Aa]uth-[Tt]oken:[[:space:]]*(.+) ]]; then
        auth_token="${BASH_REMATCH[1]}"
    fi
done

# Read body
body=""
if [[ $content_length -gt 0 ]]; then
    body=$(dd bs=1 count="$content_length" 2>/dev/null)
fi

# OPTIONS preflight
if [[ "$method" == "OPTIONS" ]]; then
    printf "HTTP/1.0 204 No Content\r\nAccess-Control-Allow-Origin: *\r\nAccess-Control-Allow-Methods: GET,POST,DELETE,OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type\r\n\r\n"
    exit 0
fi

# Route
case "$method:$path" in
    GET:/)               serve_html ;;
    POST:/api/login)     api_login "$body" ;;
    GET:/api/rules)
        check_auth "$auth_token" && api_get_rules || json_401 ;;
    POST:/api/rules)
        check_auth "$auth_token" && api_add_rule "$body" || json_401 ;;
    DELETE:/api/rules/*)
        check_auth "$auth_token" && api_delete_rule "${path##*/}" || json_401 ;;
    GET:/api/status)
        check_auth "$auth_token" && api_get_status || json_401 ;;
    POST:/api/restart)
        check_auth "$auth_token" && api_restart || json_401 ;;
    *)   send_response "404 Not Found" "text/plain" "Not Found" ;;
esac
