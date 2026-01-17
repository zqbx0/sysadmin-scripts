#!/bin/bash
# 版本: v1.0.1

# =========================
# zqbx0 sing-box four-in-one installation script (VPS specific)
# vless-version-reality|vmess-ws-tls(tunnel)|hysteria2|tuic5
# Last update: 2025.10.17
# GitHub: https://github.com/zqbx0/sysadmin-scripts
# =========================

export LANG=en_US.UTF-8
# Define colors
re="\033[0m"
red="\033[1;91m"
green="\e[1;32m"
yellow="\e[1;33m"
purple="\e[1;35m"
skyblue="\e[1;36m"
red() { echo -e "\e[1;91m$1\033[0m"; }
green() { echo -e "\e[1;32m$1\033[0m"; }
yellow() { echo -e "\e[1;33m$1\033{0m"; }
purple() { echo -e "\e[1;35m$1\033[0m"; }
skyblue() { echo -e "\e[1;36m$1\033[0m"; }
reading() { read -p "$(red "$1")" "$2"; }

# Define constants
server_name="sing-box"
work_dir="/etc/sing-box"
config_dir="${work_dir}/config.json"
client_dir="${work_dir}/url.txt"
export vless_port=${PORT:-$(shuf -i 1000-65000 -n 1)}
export CFIP=${CFIP:-'cf.090227.xyz'} 
export CFPORT=${CFPORT:-'443'} 
# 自定义域名变量 - 用户可修改此处
export CUSTOM_DOMAIN="os.gcrs6.qzz.io"  # Your custom domain

# Check if running as root
[[ $EUID -ne 0 ]] && red "Please run this script as root user" && exit 1
# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Generic service status check function
check_service() {
    local service_name=$1
    local service_file=$2
    
    [[ ! -f "${service_file}" ]] && { red "not installed"; return 2; }
        
    if command_exists apk; then
        rc-service "${service_name}" status | grep -q "started" && green "running" || yellow "not running"
    else
        systemctl is-active "${service_name}" | grep -q "^active$" && green "running" || yellow "not running"
    fi
    return $?
}

# Check sing-box status
check_singbox() {
    check_service "sing-box" "${work_dir}/${server_name}"
}

# Check argo status
check_argo() {
    check_service "argo" "${work_dir}/argo"
}

# Check nginx status
check_nginx() {
    command_exists nginx || { red "not installed"; return 2; }
    check_service "nginx" "$(command -v nginx)"
}

# Install/Uninstall packages based on system type
manage_packages() {
    if [ $# -lt 2 ]; then
        red "Unspecified package name or action" 
        return 1
    fi

    action=$1
    shift

    for package in "$@"; do
        if [ "$action" == "install" ]; then
            if command_exists "$package"; then
                green "${package} already installed"
                continue
            fi
            yellow "Installing ${package}..."
            if command_exists apt; then
                DEBIAN_FRONTEND=noninteractive apt install -y "$package"
            elif command_exists dnf; then
                dnf install -y "$package"
            elif command_exists yum; then
                yum install -y "$package"
            elif command_exists apk; then
                apk update
                apk add "$package"
            else
                red "Unknown system!"
                return 1
            fi
        elif [ "$action" == "uninstall" ]; then
            if ! command_exists "$package"; then
                yellow "${package} is not installed"
                continue
            fi
            yellow "Uninstalling ${package}..."
            if command_exists apt; then
                apt remove -y "$package" && apt autoremove -y
            elif command_exists dnf; then
                dnf remove -y "$package" && dnf autoremove -y
            elif command_exists yum; then
                yum remove -y "$package" && yum autoremove -y
            elif command_exists apk; then
                apk del "$package"
            else
                red "Unknown system!"
                return 1
            fi
        else
            red "Unknown action: $action"
            return 1
        fi
    done

    return 0
}
# Get real IP
get_realip() {
    ip=$(curl -4 -sm 2 ip.sb)
    ipv6() { curl -6 -sm 2 ip.sb; }
    if [ -z "$ip" ]; then
        echo "[$(ipv6)]"
    elif curl -4 -sm 2 http://ipinfo.io/org | grep -qE 'Cloudflare|UnReal|AEZA|Andrei'; then
        echo "[$(ipv6)]"
    else
        resp=$(curl -sm 8 "https://status.eooce.com/api/$ip" | jq -r '.status')
        if [ "$resp" = "Available" ]; then
            echo "$ip"
        else
            v6=$(ipv6)
            [ -n "$v6" ] && echo "[$v6]" || echo "$ip"
        fi
    fi
}

# Configure firewall
allow_port() {
    has_ufw=0
    has_firewalld=0
    has_iptables=0
    has_ip6tables=0

    command_exists ufw && has_ufw=1
    command_exists firewall-cmd && systemctl is-active firewalld >/dev/null 2>&1 && has_firewalld=1
    command_exists iptables && has_iptables=1
    command_exists ip6tables && has_ip6tables=1

    # Outbound and basic rules
    [ "$has_ufw" -eq 1 ] && ufw --force default allow outgoing >/dev/null 2>&1
    [ "$has_firewalld" -eq 1 ] && firewall-cmd --permanent --zone=public --set-target=ACCEPT >/dev/null 2>&1
    [ "$has_iptables" -eq 1 ] && {
        iptables -C INPUT -i lo -j ACCEPT 2>/dev/null || iptables -I INPUT 3 -i lo -j ACCEPT
        iptables -C INPUT -p icmp -j ACCEPT 2>/dev/null || iptables -I INPUT 4 -p icmp -j ACCEPT
        iptables -P FORWARD DROP 2>/dev/null || true
        iptables -P OUTPUT ACCEPT 2>/dev/null || true
    }
    [ "$has_ip6tables" -eq 1 ] && {
        ip6tables -C INPUT -i lo -j ACCEPT 2>/dev/null || ip6tables -I INPUT 3 -i lo -j ACCEPT
        ip6tables -C INPUT -p icmp -j ACCEPT 2>/dev/null || ip6tables -I INPUT 4 -p icmp -j ACCEPT
        ip6tables -P FORWARD DROP 2>/dev/null || true
        ip6tables -P OUTPUT ACCEPT 2>/dev/null || true
    }

    # Inbound
    for rule in "$@"; do
        port=${rule%/*}
        proto=${rule#*/}
        [ "$has_ufw" -eq 1 ] && ufw allow in ${port}/${proto} >/dev/null 2>&1
        [ "$has_firewalld" -eq 1 ] && firewall-cmd --permanent --add-port=${port}/${proto} >/dev/null 2>&1
        [ "$has_iptables" -eq 1 ] && (iptables -C INPUT -p ${proto} --dport ${port} -j ACCEPT 2>/dev/null || iptables -I INPUT 4 -p ${proto} --dport ${port} -j ACCEPT)
        [ "$has_ip6tables" -eq 1 ] && (ip6tables -C INPUT -p ${proto} --dport ${port} -j ACCEPT 2>/dev/null || ip6tables -I INPUT 4 -p ${proto} --dport ${port} -j ACCEPT)
    done

    [ "$has_firewalld" -eq 1 ] && firewall-cmd --reload >/dev/null 2>&1

    # Rules persistence
    if command_exists rc-service 2>/dev/null; then
        [ "$has_iptables" -eq 1 ] && iptables-save > /etc/iptables/rules.v4 2>/dev/null
        [ "$has_ip6tables" -eq 1 ] && ip6tables-save > /etc/iptables/rules.v6 2>/dev/null
    else
        if ! command_exists netfilter-persistent; then
            manage_packages install iptables-persistent || yellow "Please manually install netfilter-persistent or save iptables rules" 
            netfilter-persistent save >/dev/null 2>&1
        elif command_exists service; then
            service iptables save 2>/dev/null
            service ip6tables save 2>/dev/null
        fi
    fi
}
# Download sing-box, cloudflared
install_singbox() {
    clear
    purple "Installing sing-box, please wait..."
    # Detect system architecture
    ARCH_RAW=$(uname -m)
    case "${ARCH_RAW}" in
        'x86_64') ARCH='amd64' ;;
        'x86' | 'i686' | 'i386') ARCH='386' ;;
        'aarch64' | 'arm64') ARCH='arm64' ;;
        'armv7l') ARCH='armv7' ;;
        's390x') ARCH='s390x' ;;
        *) red "Unsupported architecture: ${ARCH_RAW}"; exit 1 ;;
    esac

    # Download sing-box, cloudflared
    [ ! -d "${work_dir}" ] && mkdir -p "${work_dir}" && chmod 777 "${work_dir}"
    
    yellow "Downloading sing-box..."
    latest_version=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
    curl -sLo "${work_dir}/sing-box.tar.gz" "https://github.com/SagerNet/sing-box/releases/download/v${latest_version}/sing-box-${latest_version}-linux-${ARCH}.tar.gz"
    tar -xzf "${work_dir}/sing-box.tar.gz" -C "${work_dir}/"
    mv "${work_dir}/sing-box-${latest_version}-linux-${ARCH}/sing-box" "${work_dir}/"
    rm -rf "${work_dir}/sing-box.tar.gz" "${work_dir}/sing-box-${latest_version}-linux-${ARCH}"
    
    yellow "Downloading cloudflared..."
    curl -sLo "${work_dir}/argo" "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}"
    
    yellow "Configuring qrencode..."
    if ! command -v qrencode &> /dev/null; then
        if command_exists apt; then
            apt install -y qrencode 2>/dev/null || true
        elif command_exists yum; then
            yum install -y qrencode 2>/dev/null || true
        elif command_exists apk; then
            apk add qrencode 2>/dev/null || true
        fi
    fi
    
    if command -v qrencode &> /dev/null; then
        ln -sf $(command -v qrencode) "${work_dir}/qrencode" 2>/dev/null || true
    else
        yellow "qrencode installation failed, QR code function will be unavailable"
        touch "${work_dir}/qrencode"
    fi
    
    chown root:root ${work_dir} && chmod +x ${work_dir}/${server_name} ${work_dir}/argo
    [ -f "${work_dir}/qrencode" ] && chmod +x "${work_dir}/qrencode"
    
    green "Components downloaded successfully"
    
   # Generate random ports and passwords
    nginx_port=$(($vless_port + 1)) 
    tuic_port=$(($vless_port + 2))
    hy2_port=$(($vless_port + 3)) 
    uuid=$(cat /proc/sys/kernel/random/uuid)
    password=$(< /dev/urandom tr -dc 'A-Za-z0-9' | head -c 24)
    output=$(/etc/sing-box/sing-box generate reality-keypair)
    private_key=$(echo "${output}" | awk '/PrivateKey:/ {print $2}')
    public_key=$(echo "${output}" | awk '/PublicKey:/ {print $2}')

    # Allow ports
    allow_port $vless_port/tcp $nginx_port/tcp $tuic_port/udp $hy2_port/udp > /dev/null 2>&1

    # Generate self-signed certificate
    openssl ecparam -genkey -name prime256v1 -out "${work_dir}/private.key"
    openssl req -new -x509 -days 3650 -key "${work_dir}/private.key" -out "${work_dir}/cert.pem" -subj "/CN=bing.com"
    
    # Detect network type and set DNS strategy
    dns_strategy=$(ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1 && echo "prefer_ipv4" || (ping -c 1 -W 3 2001:4860:4860::8888 >/dev/null 2>&1 && echo "prefer_ipv6" || echo "prefer_ipv4"))

   # Generate configuration file
cat > "${config_dir}" << EOF
{
  "log": {
    "disabled": false,
    "level": "error",
    "output": "$work_dir/sb.log",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "local",
        "address": "local",
        "strategy": "$dns_strategy"
      }
    ]
  },
  "ntp": {
    "enabled": true,
    "server": "time.apple.com",
    "server_port": 123,
    "interval": "30m"
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-reality",
      "listen": "::",
      "listen_port": $vless_port,
      "users": [
        {
          "uuid": "$uuid",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "www.iij.ad.jp",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "www.iij.ad.jp",
            "server_port": 443
          },
          "private_key": "$private_key",
          "short_id": [""]
        }
      }
    },
    {
      "type": "vmess",
      "tag": "vmess-ws",
      "listen": "::",
      "listen_port": 8001,
      "users": [
        {
          "uuid": "$uuid"
        }
      ],
      "transport": {
        "type": "ws",
        "path": "/vmess-argo",
        "early_data_header_name": "Sec-WebSocket-Protocol"
      }
    },
    {
      "type": "hysteria2",
      "tag": "hysteria2",
      "listen": "::",
      "listen_port": $hy2_port,
      "users": [
        {
          "password": "$uuid"
        }
      ],
      "ignore_client_bandwidth": false,
      "masquerade": "https://bing.com",
      "tls": {
        "enabled": true,
        "alpn": ["h3"],
        "min_version": "1.3",
        "max_version": "1.3",
        "certificate_path": "$work_dir/cert.pem",
        "key_path": "$work_dir/private.key"
      }
    },
    {
      "type": "tuic",
      "tag": "tuic",
      "listen": "::",
      "listen_port": $tuic_port,
      "users": [
        {
          "uuid": "$uuid",
          "password": "$password"
        }
      ],
      "congestion_control": "bbr",
      "tls": {
        "enabled": true,
        "alpn": ["h3"],
        "certificate_path": "$work_dir/cert.pem",
        "key_path": "$work_dir/private.key"
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    },
    {
      "type": "wireguard",
      "tag": "wireguard-out",
      "server": "engage.cloudflareclient.com",
      "server_port": 2408,
      "local_address": [
        "172.16.0.2/32",
        "2606:4700:110:851f:4da3:4e2c:cdbf:2ecf/128"
      ],
      "private_key": "eAx8o6MJrH4KE7ivPFFCa4qvYw5nJsYHCBQXPApQX1A=",
      "peer_public_key": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
      "reserved": [82, 90, 51],
      "mtu": 1420
    }
  ],
  "route": {
    "rule_set": [
      {
        "tag": "openai",
        "type": "remote",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo-lite/geosite/openai.srs",
        "download_detour": "direct"
      },
      {
        "tag": "netflix",
        "type": "remote",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo-lite/geosite/netflix.srs",
        "download_detour": "direct"
      }
    ],
    "rules": [
      {
        "rule_set": ["openai", "netflix"],
        "outbound": "wireguard-out"
      }
    ],
    "final": "direct"
  }
}
EOF
}
# Debian/Ubuntu/CentOS systemd services
main_systemd_services() {
    cat > /etc/systemd/system/sing-box.service << EOF
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
User=root
WorkingDirectory=/etc/sing-box
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
ExecStart=/etc/sing-box/sing-box run -c /etc/sing-box/config.json
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

    cat > /etc/systemd/system/argo.service << EOF
[Unit]
Description=Cloudflare Tunnel
After=network.target

[Service]
Type=simple
NoNewPrivileges=yes
TimeoutStartSec=0
ExecStart=/bin/sh -c "/etc/sing-box/argo tunnel --url http://localhost:8001 --no-autoupdate --edge-ip-version auto --protocol http2 > /etc/sing-box/argo.log 2>&1"
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    if [ -f /etc/centos-release ]; then
        yum install -y chrony
        systemctl start chronyd
        systemctl enable chronyd
        chronyc -a makestep
        yum update -y ca-certificates
        bash -c 'echo "0 0" > /proc/sys/net/ipv4/ping_group_range'
    fi
    systemctl daemon-reload 
    systemctl enable sing-box
    systemctl start sing-box
    systemctl enable argo
    systemctl start argo
}

# Alpine OpenRC services
alpine_openrc_services() {
    cat > /etc/init.d/sing-box << 'EOF'
#!/sbin/openrc-run

description="sing-box service"
command="/etc/sing-box/sing-box"
command_args="run -c /etc/sing-box/config.json"
command_background=true
pidfile="/var/run/sing-box.pid"
EOF

    cat > /etc/init.d/argo << 'EOF'
#!/sbin/openrc-run

description="Cloudflare Tunnel"
command="/bin/sh"
command_args="-c '/etc/sing-box/argo tunnel --url http://localhost:8001 --no-autoupdate --edge-ip-version auto --protocol http2 > /etc/sing-box/argo.log 2>&1'"
command_background=true
pidfile="/var/run/argo.pid"
EOF

    chmod +x /etc/init.d/sing-box
    chmod +x /etc/init.d/argo

    rc-update add sing-box default > /dev/null 2>&1
    rc-update add argo default > /dev/null 2>&1

}
# Generate nodes and subscription links
get_info() {  
  yellow "\nDetecting IP, please wait...\n"
  server_ip=$(get_realip)
  clear
  isp=$(curl -s --max-time 2 https://ipapi.co/json | tr -d '\n[:space:]' | sed 's/.*"country_code":"\([^"]*\)".*"org":"\([^"]*\)".*/\1-\2/' | sed 's/ /_/g' 2>/dev/null || echo "$hostname")

  if [ -f "${work_dir}/argo.log" ]; then
      for i in {1..5}; do
          purple "Attempt $i to get ArgoDomain..."
          argodomain=$(sed -n 's|.*https://\([^/]*trycloudflare\.com\).*|\1|p' "${work_dir}/argo.log")
          [ -n "$argodomain" ] && break
          sleep 2
      done
  else
      restart_argo
      sleep 6
      argodomain=$(sed -n 's|.*https://\([^/]*trycloudflare\.com\).*|\1|p' "${work_dir}/argo.log")
  fi

  green "\nArgoDomain：${purple}$argodomain${re}\n"

  VMESS="{ \"v\": \"2\", \"ps\": \"${isp}\", \"add\": \"${CFIP}\", \"port\": \"${CFPORT}\", \"id\": \"${uuid}\", \"aid\": \"0\", \"scy\": \"none\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"${argodomain}\", \"path\": \"/vmess-argo?ed=2560\", \"tls\": \"tls\", \"sni\": \"${argodomain}\", \"alpn\": \"\", \"fp\": \"firefox\", \"allowlnsecure\": \"flase\"}"

  cat > ${work_dir}/url.txt <<EOF
vless://${uuid}@${server_ip}:${vless_port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.iij.ad.jp&fp=firefox&pbk=${public_key}&type=tcp&headerType=none#${isp}

vmess://$(echo "$VMESS" | base64 -w0)

hysteria2://${uuid}@${server_ip}:${hy2_port}/?sni=www.bing.com&insecure=1&alpn=h3&obfs=none#${isp}

tuic://${uuid}:${password}@${server_ip}:${tuic_port}?sni=www.bing.com&congestion_control=bbr&udp_relay_mode=native&alpn=h3&allow_insecure=1#${isp}
EOF
  
  echo ""
  while IFS= read -r line; do echo -e "${purple}$line"; done < ${work_dir}/url.txt
  base64 -w0 ${work_dir}/url.txt > ${work_dir}/sub.txt
  chmod 644 ${work_dir}/sub.txt

  yellow "\nReminder: Need to enable 'Skip certificate verification' in V2rayN or other software, or set Insecure/TLS to 'true' in node settings\n"

  # Raw subscription links - 使用自定义域名
  RAW_SUB_IP_URL="http://${server_ip}:${nginx_port}/${password}"
  RAW_SUB_DOMAIN_URL="http://${CUSTOM_DOMAIN}:${nginx_port}/${password}"
  
  green "Raw subscription links:\n"
  green "IP address: ${RAW_SUB_IP_URL}\n"
  green "Domain address: ${RAW_SUB_DOMAIN_URL}\n"
  
  if [ -x "${work_dir}/qrencode" ]; then
      green "Domain subscription QR code:"
      ${work_dir}/qrencode "${RAW_SUB_DOMAIN_URL}"
  fi

  yellow "\n=========================================================================================="

  # Self-hosted conversion service
  if [ -f "/var/www/html/converter/api.php" ] && systemctl is-active nginx >/dev/null 2>&1; then
      CONVERTER_IP_URL="http://${server_ip}/converter"
      CONVERTER_DOMAIN_URL="http://${CUSTOM_DOMAIN}/converter"
      
      green "\nSelf-hosted conversion service links (Domain version):\n"
      
      # Clash/Mihomo
      CLASH_DOMAIN_URL="${CONVERTER_DOMAIN_URL}/api.php?target=clash&url=${RAW_SUB_DOMAIN_URL}"
      green "Clash/Mihomo subscription: ${CLASH_DOMAIN_URL}\n"
      ${work_dir}/qrencode "${CLASH_DOMAIN_URL}"
      
      yellow "\n=========================================================================================="
      
      # Sing-box
      SINGBOX_DOMAIN_URL="${CONVERTER_DOMAIN_URL}/api.php?target=singbox&url=${RAW_SUB_DOMAIN_URL}"
      green "Sing-box subscription: ${SINGBOX_DOMAIN_URL}\n"
      ${work_dir}/qrencode "${SINGBOX_DOMAIN_URL}"
      
      yellow "\n=========================================================================================="
      
      # Surge
      SURGE_DOMAIN_URL="${CONVERTER_DOMAIN_URL}/api.php?target=surge&url=${RAW_SUB_DOMAIN_URL}"
      green "Surge subscription: ${SURGE_DOMAIN_URL}\n"
      ${work_dir}/qrencode "${SURGE_DOMAIN_URL}"
      
      yellow "\n=========================================================================================="
      
      # Quantumult X
      QX_DOMAIN_URL="${CONVERTER_DOMAIN_URL}/api.php?target=qx&url=${RAW_SUB_DOMAIN_URL}"
      green "Quantumult X subscription: ${QX_DOMAIN_URL}\n"
      
  else
      green "\nConversion service:\n"
      echo "To deploy self-hosted conversion service, run the following command:"
      echo "bash <(curl -s https://raw.githubusercontent.com/zqbx0/sysadmin-scripts/main/scripts/sing-box/deploy-converter.sh)"
      echo ""
      echo "After deployment, you can use self-hosted conversion service"
      yellow "\n=========================================================================================="
  fi

  green "\nClient support:\n"
  echo "✅ V2rayN/Shadowrocket/Nekobox/Loon/Karing/Sterisand: Use raw subscription link"
  echo "✅ Clash/Mihomo/Sing-box/Surge: Use conversion links above"
  echo ""
}
# Nginx subscription configuration
add_nginx_conf() {
    if ! command_exists nginx; then
        red "nginx not installed, cannot configure subscription service"
        return 1
    else
        manage_service "nginx" "stop" > /dev/null 2>&1
        pkill nginx  > /dev/null 2>&1
    fi

    mkdir -p /etc/nginx/conf.d

    [[ -f "/etc/nginx/conf.d/sing-box.conf" ]] && cp /etc/nginx/conf.d/sing-box.conf /etc/nginx/conf.d/sing-box.conf.bak.sb

    cat > /etc/nginx/conf.d/sing-box.conf << EOF
# sing-box subscription configuration
server {
    listen $nginx_port;
    listen [::]:$nginx_port;
    server_name _;

    # Security settings
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";

    location = /$password {
        alias /etc/sing-box/sub.txt;
        default_type 'text/plain; charset=utf-8';
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
    }

    location / {
        return 404;
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}
EOF

    # Check if main config file exists
    if [ -f "/etc/nginx/nginx.conf" ]; then
        cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak.sb > /dev/null 2>&1
        sed -i -e '15{/include \/etc\/nginx\/modules\/\*\.conf/d;}' -e '18{/include \/etc\/nginx\/conf\.d\/\*\.conf/d;}' /etc/nginx/nginx.conf > /dev/null 2>&1
        # Check if config directory is included
        if ! grep -q "include.*conf.d" /etc/nginx/nginx.conf; then
            http_end_line=$(grep -n "^}" /etc/nginx/nginx.conf | tail -1 | cut -d: -f1)
            if [ -n "$http_end_line" ]; then
                sed -i "${http_end_line}i \    include /etc/nginx/conf.d/*.conf;" /etc/nginx/nginx.conf > /dev/null 2>&1
            fi
        fi
    else 
        cat > /etc/nginx/nginx.conf << EOF
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
    
    access_log  /var/log/nginx/access.log  main;
    sendfile        on;
    keepalive_timeout  65;
    
    include /etc/nginx/conf.d/*.conf;
}
EOF
    fi

    # Check nginx configuration syntax
    if nginx -t > /dev/null 2>&1; then
    
        if nginx -s reload > /dev/null 2>&1; then
            green "nginx subscription configuration loaded"
        else
            start_nginx  > /dev/null 2>&1
        fi
    else
        yellow "nginx configuration failed, subscription unavailable but nodes still work, issues: https://github.com/eooce/Sing-box/issues"
        restart_nginx  > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            green "nginx subscription configuration active"
        else
            [[ -f "/etc/nginx/nginx.conf.bak.sb" ]] && cp "/etc/nginx/nginx.conf.bak.sb" /etc/nginx/nginx.conf > /dev/null 2>&1
            restart_nginx  > /dev/null 2>&1
        fi
    fi
}
# Generic service management function
manage_service() {
    local service_name="$1"
    local action="$2"

    if [ -z "$service_name" ] || [ -z "$action" ]; then
        red "Missing service name or action parameter\n"
        return 1
    fi
    
    local status=$(check_service "$service_name" 2>/dev/null)

    case "$action" in
        "start")
            if [ "$status" == "running" ]; then 
                yellow "${service_name} is running\n"
                return 0
            elif [ "$status" == "not installed" ]; then 
                yellow "${service_name} is not installed!\n"
                return 1
            else 
                yellow "Starting ${service_name} service\n"
                if command_exists rc-service; then
                    rc-service "$service_name" start
                elif command_exists systemctl; then
                    systemctl daemon-reload
                    systemctl start "$service_name"
                fi
                
                if [ $? -eq 0 ]; then
                    green "${service_name} service started successfully\n"
                    return 0
                else
                    red "${service_name} service failed to start\n"
                    return 1
                fi
            fi
            ;;
            
        "stop")
            if [ "$status" == "not installed" ]; then 
                yellow "${service_name} is not installed!\n"
                return 2
            elif [ "$status" == "not running" ]; then
                yellow "${service_name} is not running\n"
                return 1
            else
                yellow "Stopping ${service_name} service\n"
                if command_exists rc-service; then
                    rc-service "$service_name" stop
                elif command_exists systemctl; then
                    systemctl stop "$service_name"
                fi
                
                if [ $? -eq 0 ]; then
                    green "${service_name} service stopped successfully\n"
                    return 0
                else
                    red "${service_name} service failed to stop\n"
                    return 1
                fi
            fi
            ;;
            
        "restart")
            if [ "$status" == "not installed" ]; then
                yellow "${service_name} is not installed!\n"
                return 1
            else
                yellow "Restarting ${service_name} service\n"
                if command_exists rc-service; then
                    rc-service "$service_name" restart
                elif command_exists systemctl; then
                    systemctl daemon-reload
                    systemctl restart "$service_name"
                fi
                
                if [ $? -eq 0 ]; then
                    green "${service_name} service restarted successfully\n"
                    return 0
                else
                    red "${service_name} service failed to restart\n"
                    return 1
                fi
            fi
            ;;
			        *)
            red "Invalid action: $action\n"
            red "Available actions: start, stop, restart\n"
            return 1
            ;;
    esac
}

# Start nginx
start_nginx() {
    manage_service "nginx" "start"
}

# Restart nginx
restart_nginx() {
    manage_service "nginx" "restart"
}

# Uninstall sing-box
uninstall_singbox() {
   reading "Are you sure you want to uninstall sing-box? (y/n): " choice
   case "${choice}" in
       y|Y)
           yellow "Uninstalling sing-box"
           if command_exists rc-service; then
                rc-service sing-box stop
                rc-service argo stop
                rm /etc/init.d/sing-box /etc/init.d/argo
                rc-update del sing-box default
                rc-update del argo default
           else
                # Stop sing-box and argo services
                systemctl stop "${server_name}"
                systemctl stop argo
                # Disable sing-box service
                systemctl disable "${server_name}"
                systemctl disable argo

                # Reload systemd
                systemctl daemon-reload || true
            fi
           # Delete configuration files and logs
           rm -rf "${work_dir}" || true
           rm -rf /etc/systemd/system/sing-box.service /etc/systemd/system/argo.service > /dev/null 2>&1
           rm  -rf /etc/nginx/conf.d/sing-box.conf > /dev/null 2>&1
           
           # Uninstall Nginx
           reading "\nUninstall Nginx? ${green}(Enter ${yellow}y${re} ${green}to uninstall, press Enter to skip) (y/n): ${re}" choice
            case "${choice}" in
                y|Y)
                    manage_packages uninstall nginx
                    ;;
                 *) 
                    yellow "Nginx uninstallation cancelled\n\n"
                    ;;
            esac

            green "\nsing-box uninstalled successfully\n\n" && exit 0
           ;;
       *)
           purple "Uninstallation cancelled\n\n"
           ;;
   esac
}

# Create shortcut command
create_shortcut() {
  cat > "$work_dir/sb.sh" << EOF
#!/usr/bin/env bash

bash <(curl -Ls https://raw.githubusercontent.com/zqbx0/sysadmin-scripts/main/scripts/sing-box.sh) \$1
EOF
  chmod +x "$work_dir/sb.sh"
  ln -sf "$work_dir/sb.sh" /usr/bin/sb
  if [ -s /usr/bin/sb ]; then
    green "\nShortcut command 'sb' created successfully\n"
    green "Next time you can run: sb\n"
  else
    red "\nFailed to create shortcut command\n"
  fi
}

# Fix Alpine running argo user group and DNS issues
change_hosts() {
    sh -c 'echo "0 0" > /proc/sys/net/ipv4/ping_group_range'
    sed -i '1s/.*/127.0.0.1   localhost/' /etc/hosts
    sed -i '2s/.*/::1         localhost/' /etc/hosts
}
# View node information and subscription links
check_nodes() {
    while IFS= read -r line; do purple "${purple}$line"; done < ${work_dir}/url.txt
    server_ip=$(get_realip)
    lujing=$(sed -n 's|.*location = /\([^ ]*\).*|\1|p' "/etc/nginx/conf.d/sing-box.conf")
    sub_port=$(sed -n 's/^\s*listen \([0-9]\+\);/\1/p' "/etc/nginx/conf.d/sing-box.conf")
    base64_ip_url="http://${server_ip}:${sub_port}/${lujing}"
    base64_domain_url="http://${CUSTOM_DOMAIN}:${sub_port}/${lujing}"
    
    yellow "\n=========================================================================================="
    green "\nSubscription Links:\n"
    green "IP subscription link: ${purple}${base64_ip_url}${re}"
    green "Domain subscription link: ${purple}${base64_domain_url}${re}\n"
    
    # Check self-hosted conversion service
    if [ -f "/var/www/html/converter/api.php" ] && systemctl is-active nginx >/dev/null 2>&1; then
        CONVERTER_IP_URL="http://${server_ip}/converter"
        CONVERTER_DOMAIN_URL="http://${CUSTOM_DOMAIN}/converter"
        green "\nSelf-hosted conversion service (Domain version):\n"
        green "  Clash: ${CONVERTER_DOMAIN_URL}/api.php?target=clash&url=${base64_domain_url}\n"
        green "  Sing-box: ${CONVERTER_DOMAIN_URL}/api.php?target=singbox&url=${base64_domain_url}\n"
        green "  Surge: ${CONVERTER_DOMAIN_URL}/api.php?target=surge&url=${base64_domain_url}\n"
    else
        green "\nConversion service:\n"
        echo "To deploy self-hosted conversion service, run:"
        echo "bash <(curl -s https://raw.githubusercontent.com/zqbx0/sysadmin-scripts/main/scripts/sing-box/deploy-converter.sh)"
    fi
    
    yellow "\n=========================================================================================="
    green "\nClient support:\n"
    echo "✅ V2rayN/Shadowrocket/Nekobox/Loon/Karing/Sterisand: Use raw subscription link"
    echo "✅ Clash/Mihomo/Sing-box/Surge: Use conversion links above"
    echo ""
    green "Your custom domain: ${CUSTOM_DOMAIN}"
    green "Subscription will work via both IP and domain"
}

# Change configuration
change_config() {
    # Check sing-box status
    local singbox_status=$(check_singbox 2>/dev/null)
    local singbox_installed=$?
    
    if [ $singbox_installed -eq 2 ]; then
        yellow "sing-box is not installed!"
        sleep 1
        menu
        return
    fi
    
    clear
    echo ""
    green "=== Modify Node Configuration ===\n"
    green "sing-box current status: $singbox_status\n"
    green "1. Change ports"
    skyblue "------------"
    green "2. Change UUID"
    skyblue "------------"
    green "3. Change Reality camouflage domain"
    skyblue "------------"
    green "4. Add hysteria2 port hopping"
    skyblue "------------"
    green "5. Remove hysteria2 port hopping"
    skyblue "------------"
    green "6. Change vmess-argo optimized domain"
    skyblue "------------"
    purple "0. Return to main menu"
    skyblue "------------"
    reading "Please enter your choice: " choice
    case "${choice}" in
        1)
            echo ""
            green "1. Change vless-reality port"
            skyblue "------------"
            green "2. Change hysteria2 port"
            skyblue "------------"
            green "3. Change tuic port"
            skyblue "------------"
            green "4. Change vmess-argo port"
            skyblue "------------"
            purple "0. Return to previous menu"
            skyblue "------------"
            reading "Please enter your choice: " choice
            case "${choice}" in
                1)
                    reading "\nEnter vless-reality port (press Enter for random port): " new_port
                    [ -z "$new_port" ] && new_port=$(shuf -i 2000-65000 -n 1)
                    sed -i '/"type": "vless"/,/listen_port/ s/"listen_port": [0-9]\+/"listen_port": '"$new_port"'/' $config_dir
                    restart_singbox
                    allow_port $new_port/tcp > /dev/null 2>&1
                    sed -i 's/\(vless:\/\/[^@]*@[^:]*:\)[0-9]\{1,\}/\1'"$new_port"'/' $client_dir
                    base64 -w0 /etc/sing-box/url.txt > /etc/sing-box/sub.txt
                    while IFS= read -r line; do yellow "$line"; done < ${work_dir}/url.txt
                    green "\nvless-reality port changed to: ${purple}$new_port${re} ${green}Please update subscription or manually change vless-reality port${re}\n"
                    ;;
                2)
                    reading "\nEnter hysteria2 port (press Enter for random port): " new_port
                    [ -z "$new_port" ] && new_port=$(shuf -i 2000-65000 -n 1)
                    sed -i '/"type": "hysteria2"/,/listen_port/ s/"listen_port": [0-9]\+/"listen_port": '"$new_port"'/' $config_dir
                    restart_singbox
                    allow_port $new_port/udp > /dev/null 2>&1
                    sed -i 's/\(hysteria2:\/\/[^@]*@[^:]*:\)[0-9]\{1,\}/\1'"$new_port"'/' $client_dir
                    base64 -w0 $client_dir > /etc/sing-box/sub.txt
                    while IFS= read -r line; do yellow "$line"; done < ${work_dir}/url.txt
                    green "\nhysteria2 port changed to: ${purple}${new_port}${re} ${green}Please update subscription or manually change hysteria2 port${re}\n"
                    ;;
                3)
                    reading "\nEnter tuic port (press Enter for random port): " new_port
                    [ -z "$new_port" ] && new_port=$(shuf -i 2000-65000 -n 1)
                    sed -i '/"type": "tuic"/,/listen_port/ s/"listen_port": [0-9]\+/"listen_port": '"$new_port"'/' $config_dir
                    restart_singbox
                    allow_port $new_port/udp > /dev/null 2>&1
                    sed -i 's/\(tuic:\/\/[^@]*@[^:]*:\)[0-9]\{1,\}/\1'"$new_port"'/' $client_dir
                    base64 -w0 $client_dir > /etc/sing-box/sub.txt
                    while IFS= read -r line; do yellow "$line"; done < ${work_dir}/url.txt
                    green "\ntuic port changed to: ${purple}${new_port}${re} ${green}Please update subscription or manually change tuic port${re}\n"
                    ;;
                4)  
                    reading "\nEnter vmess-argo port (press Enter for random port): " new_port
                    [ -z "$new_port" ] && new_port=$(shuf -i 2000-65000 -n 1)
                    sed -i '/"type": "vmess"/,/listen_port/ s/"listen_port": [0-9]\+/"listen_port": '"$new_port"'/' $config_dir
                    allow_port $new_port/tcp > /dev/null 2>&1
                    if command_exists rc-service; then
                        if grep -q "localhost:" /etc/init.d/argo; then
                            sed -i 's/localhost:[0-9]\{1,\}/localhost:'"$new_port"'/' /etc/init.d/argo
                            get_quick_tunnel
                            change_argo_domain 
                        fi
                    else
                        if grep -q "localhost:" /etc/systemd/system/argo.service; then
                            sed -i 's/localhost:[0-9]\{1,\}/localhost:'"$new_port"'/' /etc/systemd/system/argo.service
                            get_quick_tunnel
                            change_argo_domain 
                        fi
                    fi

                    if [ -f /etc/sing-box/tunnel.yml ]; then
                        sed -i 's/localhost:[0-9]\{1,\}/localhost:'"$new_port"'/' /etc/sing-box/tunnel.yml
                        restart_argo
                    fi

                    if ([ -f /etc/systemd/system/argo.service ] && grep -q -- "--token" /etc/systemd/system/argo.service) || \
                       ([ -f /etc/init.d/argo ] && grep -q -- "--token" /etc/init.d/argo); then
                        yellow "Please also modify port to: ${purple}${new_port}${re} in cloudflared\n"
                    fi

                    restart_singbox
                    green "\nvmess-argo port changed to: ${purple}${new_port}${re}\n"
                    ;;                    
                0)  change_config ;;
                *)  red "Invalid option, please enter 1 to 4" ;;
            esac
            ;;
        2)
            reading "\nEnter new UUID: " new_uuid
            [ -z "$new_uuid" ] && new_uuid=$(cat /proc/sys/kernel/random/uuid)
            sed -i -E '
                s/"uuid": "([a-f0-9-]+)"/"uuid": "'"$new_uuid"'"/g;
                s/"uuid": "([a-f0-9-]+)"$/\"uuid\": \"'$new_uuid'\"/g;
                s/"password": "([a-f0-9-]+)"/"password": "'"$new_uuid"'"/g
            ' $config_dir

            restart_singbox
            sed -i -E 's/(vless:\/\/|hysteria2:\/\/)[^@]*(@.*)/\1'"$new_uuid"'\2/' $client_dir
            sed -i "s/tuic:\/\/[0-9a-f\-]\{36\}/tuic:\/\/$new_uuid/" /etc/sing-box/url.txt
            isp=$(curl -s https://speed.cloudflare.com/meta | awk -F\" '{print $26"-"$18}' | sed -e 's/ /_/g')
            argodomain=$(grep -oE 'https://[[:alnum:]+\.-]+\.trycloudflare\.com' "${work_dir}/argo.log" | sed 's@https://@@')
            VMESS="{ \"v\": \"2\", \"ps\": \"${isp}\", \"add\": \"www.visa.com.tw\", \"port\": \"443\", \"id\": \"${new_uuid}\", \"aid\": \"0\", \"scy\": \"none\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"${argodomain}\", \"path\": \"/vmess-argo?ed=2560\", \"tls\": \"tls\", \"sni\": \"${argodomain}\", \"alpn\": \"\", \"fp\": \"\", \"allowlnsecure\": \"flase\"}"
            encoded_vmess=$(echo "$VMESS" | base64 -w0)
            sed -i -E '/vmess:\/\//{s@vmess://.*@vmess://'"$encoded_vmess"'@}' $client_dir
            base64 -w0 $client_dir > /etc/sing-box/sub.txt
            while IFS= read -r line; do yellow "$line"; done < ${work_dir}/url.txt
            green "\nUUID changed to: ${purple}${new_uuid}${re} ${green}Please update subscription or manually change all node UUIDs${re}\n"
            ;;
        3)  
            clear
            green "\n1. www.joom.com\n\n2. www.stengg.com\n\n3. www.wedgehr.com\n\n4. www.cerebrium.ai\n\n5. www.nazhumi.com\n"
            reading "\nEnter new Reality camouflage domain (custom input allowed, press Enter for default 1): " new_sni
                if [ -z "$new_sni" ]; then    
                    new_sni="www.joom.com"
                elif [[ "$new_sni" == "1" ]]; then
                    new_sni="www.joom.com"
                elif [[ "$new_sni" == "2" ]]; then
                    new_sni="www.stengg.com"
                elif [[ "$new_sni" == "3" ]]; then
                    new_sni="www.wedgehr.com"
                elif [[ "$new_sni" == "4" ]]; then
                    new_sni="www.cerebrium.ai"
	            elif [[ "$new_sni" == "5" ]]; then
                    new_sni="www.nazhumi.com"
                else
                    new_sni="$new_sni"
                fi
                jq --arg new_sni "$new_sni" '
                (.inbounds[] | select(.type == "vless") | .tls.server_name) = $new_sni |
                (.inbounds[] | select(.type == "vless") | .tls.reality.handshake.server) = $new_sni
                ' "$config_dir" > "$config_file.tmp" && mv "$config_file.tmp" "$config_dir"
                restart_singbox
                sed -i "s/\(vless:\/\/[^\?]*\?\([^\&]*\&\)*sni=\)[^&]*/\1$new_sni/" $client_dir
                base64 -w0 $client_dir > /etc/sing-box/sub.txt
                while IFS= read -r line; do yellow "$line"; done < ${work_dir}/url.txt
                echo ""
                green "\nReality sni changed to: ${purple}${new_sni}${re} ${green}Please update subscription or manually change reality node sni domain${re}\n"
            ;; 
        4)  
            purple "Port hopping requires ensuring port range is not occupied, NAT VPS pay attention to available port range, otherwise nodes may not work\n"
            reading "Enter hopping start port (press Enter for random port): " min_port
            [ -z "$min_port" ] && min_port=$(shuf -i 50000-65000 -n 1)
            yellow "Your start port: $min_port"
            reading "\nEnter hopping end port (must be greater than start port): " max_port
            [ -z "$max_port" ] && max_port=$(($min_port + 100)) 
            yellow "Your end port: $max_port\n"
            purple "Installing dependencies and setting port hopping rules, please wait...\n"
            listen_port=$(sed -n '/"tag": "hysteria2"/,/}/s/.*"listen_port": \([0-9]*\).*/\1/p' $config_dir)
            iptables -t nat -A PREROUTING -p udp --dport $min_port:$max_port -j DNAT --to-destination :$listen_port > /dev/null
            command -v ip6tables &> /dev/null && ip6tables -t nat -A PREROUTING -p udp --dport $min_port:$max_port -j DNAT --to-destination :$listen_port > /dev/null
            if command_exists rc-service 2>/dev/null; then
                iptables-save > /etc/iptables/rules.v4
                command -v ip6tables &> /dev/null && ip6tables-save > /etc/iptables/rules.v6

                cat << 'EOF' > /etc/init.d/iptables
#!/sbin/openrc-run

depend() {
    need net
}

start() {
    [ -f /etc/iptables/rules.v4 ] && iptables-restore < /etc/iptables/rules.v4
    command -v ip6tables &> /dev/null && [ -f /etc/iptables/rules.v6 ] && ip6tables-restore < /etc/iptables/rules.v6
}
EOF

                chmod +x /etc/init.d/iptables && rc-update add iptables default && /etc/init.d/iptables start
            elif [ -f /etc/debian_version ]; then
                DEBIAN_FRONTEND=noninteractive apt install -y iptables-persistent > /dev/null 2>&1 && netfilter-persistent save > /dev/null 2>&1 
                systemctl enable netfilter-persistent > /dev/null 2>&1 && systemctl start netfilter-persistent > /dev/null 2>&1
            elif [ -f /etc/redhat-release ]; then
                manage_packages install iptables-services > /dev/null 2>&1 && service iptables save > /dev/null 2>&1
                systemctl enable iptables > /dev/null 2>&1 && systemctl start iptables > /dev/null 2>&1
                command -v ip6tables &> /dev/null && service ip6tables save > /dev/null 2>&1
                systemctl enable ip6tables > /dev/null 2>&1 && systemctl start ip6tables > /dev/null 2>&1
            else
                red "Unknown system, please manually forward hopping ports to main port" && exit 1
            fi            
            restart_singbox
            ip=$(get_realip)
            uuid=$(sed -n 's/.*hysteria2:\/\/\([^@]*\)@.*/\1/p' $client_dir)
            line_number=$(grep -n 'hysteria2://' $client_dir | cut -d':' -f1)
            isp=$(curl -s --max-time 2 https://speed.cloudflare.com/meta | awk -F\" '{print $26"-"$18}' | sed -e 's/ /_/g' || echo "vps")
            sed -i.bak "/hysteria2:/d" $client_dir
            sed -i "${line_number}i hysteria2://$uuid@$ip:$listen_port?peer=www.bing.com&insecure=1&alpn=h3&obfs=none&mport=$listen_port,$min_port-$max_port#$isp" $client_dir
            base64 -w0 $client_dir > /etc/sing-box/sub.txt
            while IFS= read -r line; do yellow "$line"; done < ${work_dir}/url.txt
            green "\nhysteria2 port hopping enabled, hopping ports: ${purple}$min_port-$max_port${re} ${green}Please update subscription or manually copy above hysteria2 node${re}\n"
            ;;
        5)  
            iptables -t nat -F PREROUTING  > /dev/null 2>&1
            command -v ip6tables &> /dev/null && ip6tables -t nat -F PREROUTING  > /dev/null 2>&1
            if command_exists rc-service 2>/dev/null; then
                rc-update del iptables default && rm -rf /etc/init.d/iptables 
            elif [ -f /etc/redhat-release ]; then
                netfilter-persistent save > /dev/null 2>&1
            elif [ -f /etc/redhat-release ]; then
                service iptables save > /dev/null 2>&1
                command -v ip6tables &> /dev/null && service ip6tables save > /dev/null 2>&1
            else
                manage_packages uninstall iptables ip6tables iptables-persistent iptables-service > /dev/null 2>&1
            fi
            sed -i '/hysteria2/s/&mport=[^#&]*//g' /etc/sing-box/url.txt
            base64 -w0 $client_dir > /etc/sing-box/sub.txt
            green "\nPort hopping removed\n"
            ;;
        6)  change_cfip ;;
        0)  menu ;;
        *)  read "Invalid option!" ;; 
    esac
}
# Manage node subscription
disable_open_sub() {
    local singbox_status=$(check_singbox 2>/dev/null)
    local singbox_installed=$?
    
    if [ $singbox_installed -eq 2 ]; then
        yellow "sing-box is not installed!"
        sleep 1
        menu
        return
    fi
    
    clear
    echo ""
    green "=== Manage Node Subscription ===\n"
    skyblue "------------"
    green "1. Disable node subscription"
    skyblue "------------"
    green "2. Enable node subscription"
    skyblue "------------"
    green "3. Change subscription port"
    skyblue "------------"
    purple "0. Return to main menu"
    skyblue "------------"
    reading "Please enter choice: " choice
    case "${choice}" in
        1)
            if command -v nginx &>/dev/null; then
                if command_exists rc-service 2>/dev/null; then
                    rc-service nginx status | grep -q "started" && rc-service nginx stop || red "nginx not running"
                else 
                    [ "$(systemctl is-active nginx)" = "active" ] && systemctl stop nginx || red "nginx not running"
                fi
            else
                yellow "Nginx is not installed"
            fi

            green "\nNode subscription disabled\n"     
            ;; 
        2)
            green "\nNode subscription enabled\n"
            server_ip=$(get_realip)
            password=$(tr -dc A-Za-z < /dev/urandom | head -c 32) 
            sed -i "s|\(location = /\)[^ ]*|\1$password|" /etc/nginx/conf.d/sing-box.conf
	    sub_port=$(port=$(grep -E 'listen [0-9]+;' "/etc/nginx/conf.d/sing-box.conf" | awk '{print $2}' | sed 's/;//'); if [ "$port" -eq 80 ]; then echo ""; else echo "$port"; fi)
            start_nginx
            (port=$(grep -E 'listen [0-9]+;' "/etc/nginx/conf.d/sing-box.conf" | awk '{print $2}' | sed 's/;//'); if [ "$port" -eq 80 ]; then echo ""; else green "Subscription port: $port"; fi); 
            ip_link=$(if [ -z "$sub_port" ]; then echo "http://$server_ip/$password"; else echo "http://$server_ip:$sub_port/$password"; fi)
            domain_link=$(if [ -z "$sub_port" ]; then echo "http://${CUSTOM_DOMAIN}/$password"; else echo "http://${CUSTOM_DOMAIN}:$sub_port/$password"; fi)
            green "\nNew node subscription links:\n"
            green "IP link: $ip_link"
            green "Domain link: $domain_link\n"
            ;; 

        3)
            reading "Enter new subscription port (1-65535):" sub_port
            [ -z "$sub_port" ] && sub_port=$(shuf -i 2000-65000 -n 1)
            
            # Check if port is in use
            until [[ -z $(lsof -iTCP:"$sub_port" -sTCP:LISTEN -t) ]]; do
                if [[ -n $(lsof -iTCP:"$sub_port" -sTCP:LISTEN -t) ]]; then
                    echo -e "${red}Port $sub_port is already in use, please try another port${re}"
                    reading "Enter new subscription port (1-65535):" sub_port
                    [[ -z $sub_port ]] && sub_port=$(shuf -i 2000-65000 -n 1)
                fi
            done

            # Backup current config
            if [ -f "/etc/nginx/conf.d/sing-box.conf" ]; then
                cp "/etc/nginx/conf.d/sing-box.conf" "/etc/nginx/conf.d/sing-box.conf.bak.$(date +%Y%m%d)"
            fi
            
            # Update port configuration
            sed -i 's/listen [0-9]\+;/listen '$sub_port';/g' "/etc/nginx/conf.d/sing-box.conf"
            sed -i 's/listen \[::\]:[0-9]\+;/listen [::]:'$sub_port';/g' "/etc/nginx/conf.d/sing-box.conf"
            path=$(sed -n 's|.*location = /\([^ ]*\).*|\1|p' "/etc/nginx/conf.d/sing-box.conf")
            server_ip=$(get_realip)
            
            # Allow new port
            allow_port $sub_port/tcp > /dev/null 2>&1
            
            # Test nginx configuration
            if nginx -t > /dev/null 2>&1; then
                # Try to reload configuration
                if nginx -s reload > /dev/null 2>&1; then
                    green "nginx configuration reloaded, port changed successfully"
                else
                    yellow "Configuration reload failed, trying to restart nginx service..."
                    restart_nginx
                fi
                green "\nSubscription port changed successfully\n"
                green "New subscription links:\n"
                green "IP: http://$server_ip:$sub_port/$path"
                green "Domain: http://${CUSTOM_DOMAIN}:$sub_port/$path\n"
            else
                red "nginx configuration test failed, restoring original configuration..."
                if [ -f "/etc/nginx/conf.d/sing-box.conf.bak."* ]; then
                    latest_backup=$(ls -t /etc/nginx/conf.d/sing-box.conf.bak.* | head -1)
                    cp "$latest_backup" "/etc/nginx/conf.d/sing-box.conf"
                    yellow "Original nginx configuration restored"
                fi
                return 1
            fi
            ;; 
        0)  menu ;; 
        *)  red "Invalid option!" ;;
    esac
}

# singbox management
manage_singbox() {
    # Check sing-box status
    local singbox_status=$(check_singbox 2>/dev/null)
    local singbox_installed=$?
    
    clear
    echo ""
    green "=== sing-box Management ===\n"
    green "sing-box current status: $singbox_status\n"
    green "1. Start sing-box service"
    skyblue "-------------------"
    green "2. Stop sing-box service"
    skyblue "-------------------"
    green "3. Restart sing-box service"
    skyblue "-------------------"
    purple "0. Return to main menu"
    skyblue "------------"
    reading "\nPlease enter choice: " choice
    case "${choice}" in
        1) start_singbox ;;  
        2) stop_singbox ;;
        3) restart_singbox ;;
        0) menu ;;
        *) red "Invalid option!" && sleep 1 && manage_singbox;;
    esac
}
# Argo tunnel management
manage_argo() {
    # Check Argo status
    local argo_status=$(check_argo 2>/dev/null)
    local argo_installed=$?

    clear
    echo ""
    green "=== Argo Tunnel Management ===\n"
    green "Argo current status: $argo_status\n"
    green "1. Start Argo service"
    skyblue "------------"
    green "2. Stop Argo service"
    skyblue "------------"
    green "3. Restart Argo service"
    skyblue "------------"
    green "4. Add Argo fixed tunnel"
    skyblue "----------------"
    green "5. Switch back to Argo temporary tunnel"
    skyblue "------------------"
    green "6. Get new Argo temporary domain"
    skyblue "-------------------"
    purple "0. Return to main menu"
    skyblue "-----------"
    reading "\nPlease enter choice: " choice
    case "${choice}" in
        1)  start_argo ;;
        2)  stop_argo ;; 
        3)  clear
            if command_exists rc-service 2>/dev/null; then
                grep -Fq -- '--url http://localhost' /etc/init.d/argo && get_quick_tunnel && change_argo_domain || { green "\nCurrently using fixed tunnel, no need to get temporary domain"; sleep 2; menu; }
            else
                grep -q 'ExecStart=.*--url http://localhost' /etc/systemd/system/argo.service && get_quick_tunnel && change_argo_domain || { green "\nCurrently using fixed tunnel, no need to get temporary domain"; sleep 2; menu; }
            fi
         ;; 
        4)
            clear
            yellow "\nFixed tunnel can be json or token, fixed tunnel port is 8001, configure in Cloudflare dashboard\n\nGet json from fscarmen's site: ${purple}https://fscarmen.cloudflare.now.cc${re}\n"
            reading "\nEnter your argo domain: " argo_domain
            ArgoDomain=$argo_domain
            reading "\nEnter your argo key (token or json): " argo_auth
            if [[ $argo_auth =~ TunnelSecret ]]; then
                echo $argo_auth > ${work_dir}/tunnel.json
                cat > ${work_dir}/tunnel.yml << EOF
tunnel: $(cut -d\" -f12 <<< "$argo_auth")
credentials-file: ${work_dir}/tunnel.json
protocol: http2
                                           
ingress:
  - hostname: $ArgoDomain
    service: http://localhost:8001
    originRequest:
      noTLSVerify: true
  - service: http_status:404
EOF

                if command_exists rc-service 2>/dev/null; then
                    sed -i '/^command_args=/c\command_args="-c '\''/etc/sing-box/argo tunnel --edge-ip-version auto --config /etc/sing-box/tunnel.yml run 2>&1'\''"' /etc/init.d/argo
                else
                    sed -i '/^ExecStart=/c ExecStart=/bin/sh -c "/etc/sing-box/argo tunnel --edge-ip-version auto --config /etc/sing-box/tunnel.yml run 2>&1"' /etc/systemd/system/argo.service
                fi
                restart_argo
                sleep 1 
                change_argo_domain

            elif [[ $argo_auth =~ ^[A-Z0-9a-z=]{120,250}$ ]]; then
                if command_exists rc-service 2>/dev/null; then
                    sed -i "/^command_args=/c\command_args=\"-c '/etc/sing-box/argo tunnel --edge-ip-version auto --no-autoupdate --protocol http2 run --token $argo_auth 2>&1'\"" /etc/init.d/argo
                else

                    sed -i '/^ExecStart=/c ExecStart=/bin/sh -c "/etc/sing-box/argo tunnel --edge-ip-version auto --no-autoupdate --protocol http2 run --token '$argo_auth' 2>&1"' /etc/systemd/system/argo.service
                fi
                restart_argo
                sleep 1 
                change_argo_domain
            else
                yellow "Your argo domain or token doesn't match, please re-enter"
                manage_argo            
            fi
            ;; 
        5)
            clear
            if command_exists rc-service 2>/dev/null; then
                alpine_openrc_services
            else
                main_systemd_services
            fi
            get_quick_tunnel
            change_argo_domain 
            ;; 

        6)  
            if command_exists rc-service 2>/dev/null; then
                if grep -Fq -- '--url http://localhost' "/etc/init.d/argo"; then
                    get_quick_tunnel
                    change_argo_domain 
                else
                    yellow "Currently using fixed tunnel, cannot get temporary tunnel"
                    sleep 2
                    menu
                fi
            else
                if grep -q 'ExecStart=.*--url http://localhost' "/etc/systemd/system/argo.service"; then
                    get_quick_tunnel
                    change_argo_domain 
                else
                    yellow "Currently using fixed tunnel, cannot get temporary tunnel"
                    sleep 2
                    menu
                fi
            fi 
            ;; 
        0)  menu ;; 
        *)  red "Invalid option!" ;;
    esac
}
# Get argo temporary tunnel
get_quick_tunnel() {
restart_argo
yellow "Getting temporary argo domain, please wait...\n"
sleep 3
if [ -f /etc/sing-box/argo.log ]; then
  for i in {1..5}; do
        purple "Attempt $i to get ArgoDomain..."
      get_argodomain=$(sed -n 's|.*https://\([^/]*trycloudflare\.com\).*|\1|p' "/etc/sing-box/argo.log")
      [ -n "$get_argodomain" ] && break
      sleep 2
  done
else
  restart_argo
  sleep 6
  get_argodomain=$(sed -n 's|.*https://\([^/]*trycloudflare\.com\).*|\1|p' "/etc/sing-box/argo.log")
fi
green "ArgoDomain：${purple}$get_argodomain${re}\n"
ArgoDomain=$get_argodomain
}

# Update Argo domain to subscription
change_argo_domain() {
content=$(cat "$client_dir")
vmess_url=$(grep -o 'vmess://[^ ]*' "$client_dir")
vmess_prefix="vmess://"
encoded_vmess="${vmess_url#"$vmess_prefix"}"
decoded_vmess=$(echo "$encoded_vmess" | base64 --decode)
updated_vmess=$(echo "$decoded_vmess" | jq --arg new_domain "$ArgoDomain" '.host = $new_domain | .sni = $new_domain')
encoded_updated_vmess=$(echo "$updated_vmess" | base64 | tr -d '\n')
new_vmess_url="${vmess_prefix}${encoded_updated_vmess}"
new_content=$(echo "$content" | sed "s|$vmess_url|$new_vmess_url|")
echo "$new_content" > "$client_dir"
base64 -w0 ${work_dir}/url.txt > ${work_dir}/sub.txt
green "vmess node updated, update subscription or manually copy below vmess-argo node\n"
purple "$new_vmess_url\n" 
}

# Change CF optimized domain
change_cfip() {
    clear
    yellow "Change vmess-argo optimized domain\n"
    green "1: cf.090227.xyz  2: cf.877774.xyz  3: cf.877771.xyz  4: cdns.doon.eu.org  5: cf.zhetengsha.eu.org  6: time.is\n"
    reading "Enter your optimized domain or IP\n(Enter 1-6, or domain:port or IP:port, press Enter for default 1): " cfip_input

    if [ -z "$cfip_input" ]; then
        cfip="cf.090227.xyz"
        cfport="443"
    else
        case "$cfip_input" in
            "1")
                cfip="cf.090227.xyz"
                cfport="443"
                ;;
            "2")
                cfip="cf.877774.xyz"
                cfport="443"
                ;;
            "3")
                cfip="cf.877771.xyz"
                cfport="443"
                ;;
            "4")
                cfip="cdns.doon.eu.org"
                cfport="443"
                ;;
            "5")
                cfip="cf.zhetengsha.eu.org"
                cfport="443"
                ;;
            "6")
                cfip="time.is"
                cfport="443"
                ;;
            *)
                if [[ "$cfip_input" =~ : ]]; then
                    cfip=$(echo "$cfip_input" | cut -d':' -f1)
                    cfport=$(echo "$cfip_input" | cut -d':' -f2)
                else
                    cfip="$cfip_input"
                    cfport="443"
                fi
                ;;
        esac
    fi

content=$(cat "$client_dir")
vmess_url=$(grep -o 'vmess://[^ ]*' "$client_dir")
encoded_part="${vmess_url#vmess://}"
decoded_json=$(echo "$encoded_part" | base64 --decode 2>/dev/null)
updated_json=$(echo "$decoded_json" | jq --arg cfip "$cfip" --argjson cfport "$cfport" \
    '.add = $cfip | .port = $cfport')
new_encoded_part=$(echo "$updated_json" | base64 -w0)
new_vmess_url="vmess://$new_encoded_part"
new_content=$(echo "$content" | sed "s|$vmess_url|$new_vmess_url|")
echo "$new_content" > "$client_dir"
base64 -w0 "${work_dir}/url.txt" > "${work_dir}/sub.txt"
green "\nvmess node optimized domain updated to: ${purple}${cfip}:${cfport},${green} update subscription or manually copy below vmess-argo node${re}\n"
purple "$new_vmess_url\n"
}

# Main menu
menu() {
   singbox_status=$(check_singbox 2>/dev/null)
   nginx_status=$(check_nginx 2>/dev/null)
   argo_status=$(check_argo 2>/dev/null)
   
   clear
   echo ""
   green "GitHub Repository: ${purple}https://github.com/zqbx0/sysadmin-scripts${re}"
   green "Script location: ${purple}scripts/sing-box.sh${re}\n"
   purple "=== zqbx0 sing-box Four-in-One Installation Script ===\n"
   purple "---Argo Status: ${argo_status}"   
   purple "--Nginx Status: ${nginx_status}"
   purple "singbox Status: ${singbox_status}"
   purple "Custom Domain: ${CUSTOM_DOMAIN}\n"
   green "1. Install sing-box"
   red "2. Uninstall sing-box"
   echo "==============="
   green "3. sing-box Management"
   green "4. Argo Tunnel Management"
   echo  "==============="
   green  "5. View Node Information"
   green  "6. Modify Node Configuration"
   green  "7. Manage Node Subscription"
   echo  "==============="
   green  "8. Deploy Subscription Conversion Service"
   purple "9. SSH Comprehensive Toolbox"
   echo  "==============="
   red "0. Exit Script"
   echo "==========="
   reading "Please enter choice (0-9): " choice
   echo ""
}

# Capture Ctrl+C exit signal
trap 'red "Operation cancelled"; exit' INT

# Main loop
while true; do
   menu
   case "${choice}" in
        1)  
            check_singbox &>/dev/null; check_singbox=$?
            if [ ${check_singbox} -eq 0 ]; then
                yellow "sing-box is already installed!\n"
            else
                manage_packages install nginx jq tar openssl lsof coreutils
                install_singbox
                if command_exists systemctl; then
                    main_systemd_services
                elif command_exists rc-update; then
                    alpine_openrc_services
                    change_hosts
                    rc-service sing-box restart
                    rc-service argo restart
                else
                    echo "Unsupported init system"
                    exit 1 
                fi

                sleep 5
                get_info
                add_nginx_conf
                create_shortcut
            fi
           ;;
        2) uninstall_singbox ;;
        3) manage_singbox ;;
        4) manage_argo ;;
        5) check_nodes ;;
        6) change_config ;;
        7) disable_open_sub ;;
        8) 
           clear
           echo "Deploy Subscription Conversion Service"
           echo "================="
           echo "1. Deploy PHP Subscription Conversion Service"
           echo "2. View Conversion Service Status"
           echo "3. View Deployment Instructions"
           echo "0. Return to Main Menu"
           reading "Please choose: " converter_choice
           case "${converter_choice}" in
               1)
                   green "Deploying subscription conversion service..."
                   DEPLOY_URL="https://raw.githubusercontent.com/zqbx0/sysadmin-scripts/main/scripts/sing-box/deploy-converter.sh"
                   if bash <(curl -s "$DEPLOY_URL") "converter.local" "/var/www/html/converter"; then
                       green "✅ Subscription conversion service deployed successfully!"
                       green "Access address: http://$(hostname -I | awk '{print $1}')/converter"
                       green "API address: http://$(hostname -I | awk '{print $1}')/converter/api.php"
                       green "Domain address: http://${CUSTOM_DOMAIN}/converter"
                   else
                       red "❌ Deployment failed, please check network or permissions"
                   fi
                   ;;
               2)
                   clear
                   echo "Conversion Service Status Check:"
                   echo "================="
                   if [ -f "/var/www/html/converter/api.php" ]; then
                       green "✅ Conversion service file exists: /var/www/html/converter/api.php"
                   else
                       yellow "⚠️  Conversion service file does not exist"
                   fi
                   
                   if systemctl is-active nginx >/dev/null 2>&1; then
                       green "✅ Nginx service running"
                   else
                       yellow "⚠️  Nginx service not running"
                   fi
                   
                   if [ -f "/var/www/html/converter/api.php" ] && systemctl is-active nginx >/dev/null 2>&1; then
                       SERVER_IP=$(hostname -I | awk '{print $1}')
                       echo ""
                       green "Conversion service ready:"
                       green "Home page: http://${SERVER_IP}/converter"
                       green "Domain home: http://${CUSTOM_DOMAIN}/converter"
                       green "API: http://${SERVER_IP}/converter/api.php"
                       green "Domain API: http://${CUSTOM_DOMAIN}/converter/api.php"
                   else
                       echo ""
                       yellow "Conversion service not fully deployed"
                   fi
                   ;;
               3)
                   clear
                   green "Deployment Instructions:"
                   echo "=============="
                   echo "Run the following command to deploy subscription conversion service:"
                   echo "bash <(curl -s https://raw.githubusercontent.com/zqbx0/sysadmin-scripts/main/scripts/sing-box/deploy-converter.sh)"
                   echo ""
                   echo "Deployment parameters:"
                   echo "  First parameter: domain (default: converter.local)"
                   echo "  Second parameter: installation directory (default: /var/www/html/converter)"
                   echo ""
                   echo "Example:"
                   echo "  bash <(curl -s ...) sub.example.com /var/www/converter"
                   echo ""
                   echo "After deployment, you can use self-hosted conversion service to generate Clash/Sing-box/Surge subscriptions"
                   ;;
               0) continue ;;
               *) red "Invalid choice" ;;
           esac
           ;;
        9) 
           clear
           bash <(curl -Ls ssh_tool.eooce.com)
           ;;           
        0) exit 0 ;;
        *) red "Invalid option, please enter 0 to 9" ;;
   esac
   read -n 1 -s -r -p $'\033[1;91mPress any key to continue...\033[0m'
done
