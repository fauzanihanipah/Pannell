#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#   ALL PRO - Xray (VMess / VLess / Trojan) + WS TLS / NTLS
# ═══════════════════════════════════════════════════════════════
ALLPRO_DIR="/etc/allpro"
XRAY_DIR="/etc/xray"
DOMAIN=$(cat "$ALLPRO_DIR/domain" 2>/dev/null)
GREEN='\033[1;32m'; CYAN='\033[1;36m'; RED='\033[1;31m'; NC='\033[0m'
ok(){  echo -e "  ${GREEN}✔${NC}  $*"; }
inf(){ echo -e "  ${CYAN}➜${NC}  $*"; }
err(){ echo -e "  ${RED}✘${NC}  $*"; }

mkdir -p "$XRAY_DIR" /var/log/xray
touch "$XRAY_DIR"/users.db

# ── SSL Cert (selalu siapkan self-signed dulu sebagai fallback) ──
if [[ ! -f "$XRAY_DIR/xray.crt" ]]; then
    inf "Generate self-signed cert..."
    openssl req -new -newkey rsa:2048 -days 1095 -nodes -x509 \
      -subj "/C=ID/ST=ALL/L=PRO/O=ALL/OU=PRO/CN=$DOMAIN" \
      -keyout "$XRAY_DIR/xray.key" -out "$XRAY_DIR/xray.crt" &>/dev/null
fi
chmod 644 "$XRAY_DIR"/xray.{key,crt}

# ── Coba issue cert dari Let's Encrypt kalau domain valid ──
if [[ "$DOMAIN" =~ [a-zA-Z] ]]; then
    inf "Mencoba issue cert Let's Encrypt untuk $DOMAIN..."
    systemctl stop nginx 2>/dev/null
    certbot certonly --standalone --non-interactive --agree-tos \
      --email "admin@$DOMAIN" -d "$DOMAIN" &>/dev/null
    if [[ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
        cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$XRAY_DIR/xray.crt"
        cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem"   "$XRAY_DIR/xray.key"
        ok "Let's Encrypt cert aktif"
    else
        inf "Gunakan self-signed cert"
    fi
fi

# ── Xray config (multi-protocol, multi-inbound) ────────────
inf "Generate Xray config..."
DEFAULT_UUID=$(cat /proc/sys/kernel/random/uuid)
cat > "$XRAY_DIR/config.json" <<EOF
{
  "log": {"loglevel": "warning", "access": "/var/log/xray/access.log"},
  "inbounds": [
    {
      "port": 10000, "listen": "127.0.0.1", "protocol": "vmess",
      "settings": {"clients": [{"id": "$DEFAULT_UUID", "alterId": 0}]},
      "streamSettings": {"network": "ws", "wsSettings": {"path": "/vmess"}}
    },
    {
      "port": 10001, "listen": "127.0.0.1", "protocol": "vmess",
      "settings": {"clients": [{"id": "$DEFAULT_UUID", "alterId": 0}]},
      "streamSettings": {"network": "ws", "wsSettings": {"path": "/vmess-ntls"}}
    },
    {
      "port": 10002, "listen": "127.0.0.1", "protocol": "vless",
      "settings": {"clients": [{"id": "$DEFAULT_UUID"}], "decryption": "none"},
      "streamSettings": {"network": "ws", "wsSettings": {"path": "/vless"}}
    },
    {
      "port": 10003, "listen": "127.0.0.1", "protocol": "vless",
      "settings": {"clients": [{"id": "$DEFAULT_UUID"}], "decryption": "none"},
      "streamSettings": {"network": "ws", "wsSettings": {"path": "/vless-ntls"}}
    },
    {
      "port": 10004, "listen": "127.0.0.1", "protocol": "trojan",
      "settings": {"clients": [{"password": "$DEFAULT_UUID"}]},
      "streamSettings": {"network": "ws", "wsSettings": {"path": "/trojan-ws"}}
    },
    {
      "port": 10005, "listen": "127.0.0.1", "protocol": "trojan",
      "settings": {"clients": [{"password": "$DEFAULT_UUID"}]},
      "streamSettings": {"network": "grpc", "grpcSettings": {"serviceName": "trojan-grpc"}}
    }
  ],
  "outbounds": [{"protocol": "freedom"}, {"protocol": "blackhole", "tag": "blocked"}]
}
EOF
ok "config.json siap"

# ── Nginx vhost: 443 TLS (multi-path) ──────────────────────
inf "Konfigurasi Nginx vhost Xray..."
cat > /etc/nginx/conf.d/allpro-xray.conf <<EOF
# 443 TLS — Xray WS TLS + gRPC
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN;
    ssl_certificate     $XRAY_DIR/xray.crt;
    ssl_certificate_key $XRAY_DIR/xray.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location = /vmess {
        proxy_redirect off; proxy_pass http://127.0.0.1:10000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_read_timeout 86400;
    }
    location = /vless {
        proxy_redirect off; proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_read_timeout 86400;
    }
    location = /trojan-ws {
        proxy_redirect off; proxy_pass http://127.0.0.1:10004;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_read_timeout 86400;
    }
    location ^~ /trojan-grpc { grpc_pass grpc://127.0.0.1:10005; }
    location = /ssh-ws {
        proxy_pass http://127.0.0.1:8880;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_read_timeout 86400;
    }

    location / { return 200 "ALL PRO"; }
}

# 80 NTLS — append ke vhost SSH WS NTLS yang sudah ada
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    location = /vmess-ntls {
        proxy_redirect off; proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_read_timeout 86400;
    }
    location = /vless-ntls {
        proxy_redirect off; proxy_pass http://127.0.0.1:10003;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_read_timeout 86400;
    }
}
EOF

# Hapus vhost SSH WS yang lama supaya gak duplikat server_name
rm -f /etc/nginx/conf.d/allpro-ssh-ws.conf 2>/dev/null

if nginx -t &>/dev/null; then
    systemctl restart nginx
    ok "Nginx aktif (443 TLS + 80 NTLS, multi-path)"
else
    err "Nginx config error! Detail:"
    nginx -t 2>&1 | sed 's/^/    /'
fi
systemctl enable nginx &>/dev/null

# ── Systemd service ────────────────────────────────────────
cat > /etc/systemd/system/xray.service <<'EOF'
[Unit]
Description=ALL PRO Xray Service
After=network.target nss-lookup.target

[Service]
ExecStart=/usr/local/bin/xray run -c /etc/xray/config.json
Restart=on-failure
RestartSec=3
LimitNOFILE=1048576
User=root

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable xray &>/dev/null
systemctl restart xray
sleep 1
if systemctl is-active --quiet xray; then
    ok "Xray service aktif"
else
    err "Xray gagal start — cek: journalctl -u xray -n 20"
fi
