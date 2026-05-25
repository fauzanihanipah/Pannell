#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#   ALL PRO - Xray (VMess / VLess / Trojan) + WS TLS / NTLS
# ═══════════════════════════════════════════════════════════════
ALLPRO_DIR="/etc/allpro"
XRAY_DIR="/etc/xray"
DOMAIN=$(cat "$ALLPRO_DIR/domain" 2>/dev/null)
GREEN='\033[1;32m'; CYAN='\033[1;36m'; RED='\033[1;31m'; NC='\033[0m'
ok(){ echo -e "  ${GREEN}✔${NC}  $*"; }
inf(){ echo -e "  ${CYAN}➜${NC}  $*"; }
err(){ echo -e "  ${RED}✘${NC}  $*"; }

mkdir -p "$XRAY_DIR" /var/log/xray
touch "$XRAY_DIR"/users.db

# ── SSL Cert (acme via certbot if domain valid) ────────────
inf "Generate self-signed cert (fallback)..."
openssl req -new -newkey rsa:2048 -days 1095 -nodes -x509 \
  -subj "/C=ID/ST=ALL/L=PRO/O=ALL/OU=PRO/CN=$DOMAIN" \
  -keyout "$XRAY_DIR/xray.key" -out "$XRAY_DIR/xray.crt" &>/dev/null
chmod 644 "$XRAY_DIR"/xray.{key,crt}

# Try acme if domain looks valid (not IP)
if [[ "$DOMAIN" =~ [a-zA-Z] ]]; then
    inf "Mencoba issue cert dari Let's Encrypt untuk $DOMAIN..."
    systemctl stop nginx 2>/dev/null
    certbot certonly --standalone --non-interactive --agree-tos \
      --email admin@$DOMAIN -d "$DOMAIN" &>/dev/null
    if [[ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
        cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$XRAY_DIR/xray.crt"
        cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem"   "$XRAY_DIR/xray.key"
        ok "Cert Let's Encrypt aktif untuk $DOMAIN"
    else
        inf "Gunakan self-signed cert (skip LE)"
    fi
    systemctl start nginx 2>/dev/null
fi


# ── Xray config (multi-protocol) ───────────────────────────
# Ports plan:
#   VMess WS TLS    : 443  (path /vmess)
#   VMess WS NTLS   : 80   (path /vmess-ntls)  CDN-friendly
#   VLess WS TLS    : 443  (path /vless)
#   VLess WS NTLS   : 80   (path /vless-ntls)
#   Trojan WS TLS   : 443  (path /trojan-ws)
#   Trojan gRPC TLS : 443  (serviceName=trojan-grpc)
inf "Generate Xray config..."
DEFAULT_UUID=$(cat /proc/sys/kernel/random/uuid)
cat > "$XRAY_DIR/config.json" <<EOF
{
  "log": {"loglevel": "warning"},
  "inbounds": [
    {
      "port": 10000,
      "protocol": "vmess",
      "settings": {"clients": [{"id": "$DEFAULT_UUID", "alterId": 0}]},
      "streamSettings": {"network": "ws", "wsSettings": {"path": "/vmess"}}
    },
    {
      "port": 10001,
      "protocol": "vmess",
      "settings": {"clients": [{"id": "$DEFAULT_UUID", "alterId": 0}]},
      "streamSettings": {"network": "ws", "wsSettings": {"path": "/vmess-ntls"}}
    },
    {
      "port": 10002,
      "protocol": "vless",
      "settings": {"clients": [{"id": "$DEFAULT_UUID"}], "decryption": "none"},
      "streamSettings": {"network": "ws", "wsSettings": {"path": "/vless"}}
    },
    {
      "port": 10003,
      "protocol": "vless",
      "settings": {"clients": [{"id": "$DEFAULT_UUID"}], "decryption": "none"},
      "streamSettings": {"network": "ws", "wsSettings": {"path": "/vless-ntls"}}
    },
    {
      "port": 10004,
      "protocol": "trojan",
      "settings": {"clients": [{"password": "$DEFAULT_UUID"}]},
      "streamSettings": {"network": "ws", "wsSettings": {"path": "/trojan-ws"}}
    },
    {
      "port": 10005,
      "protocol": "trojan",
      "settings": {"clients": [{"password": "$DEFAULT_UUID"}]},
      "streamSettings": {"network": "grpc", "grpcSettings": {"serviceName": "trojan-grpc"}}
    }
  ],
  "outbounds": [{"protocol": "freedom"}]
}
EOF
ok "config.json siap"


# ── Nginx reverse proxy: 443 TLS / 80 NTLS ─────────────────
inf "Konfigurasi Nginx reverse proxy untuk Xray..."
cat > /etc/nginx/conf.d/allpro-xray.conf <<EOF
# ── 443 TLS (TLS path) ─────────────────────────
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN;
    ssl_certificate $XRAY_DIR/xray.crt;
    ssl_certificate_key $XRAY_DIR/xray.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    location = /vmess        { proxy_redirect off; proxy_pass http://127.0.0.1:10000;
                               proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade;
                               proxy_set_header Connection "upgrade"; proxy_set_header Host \$host; }
    location = /vless        { proxy_redirect off; proxy_pass http://127.0.0.1:10002;
                               proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade;
                               proxy_set_header Connection "upgrade"; proxy_set_header Host \$host; }
    location = /trojan-ws    { proxy_redirect off; proxy_pass http://127.0.0.1:10004;
                               proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade;
                               proxy_set_header Connection "upgrade"; proxy_set_header Host \$host; }
    location ^~ /trojan-grpc { grpc_pass grpc://127.0.0.1:10005; }
}
# ── 80 NTLS (CDN-friendly, no TLS at origin) ───
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    location = /vmess-ntls   { proxy_redirect off; proxy_pass http://127.0.0.1:10001;
                               proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade;
                               proxy_set_header Connection "upgrade"; proxy_set_header Host \$host; }
    location = /vless-ntls   { proxy_redirect off; proxy_pass http://127.0.0.1:10003;
                               proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade;
                               proxy_set_header Connection "upgrade"; proxy_set_header Host \$host; }
}
EOF
nginx -t &>/dev/null && systemctl restart nginx
ok "Nginx routing TLS/NTLS aktif"

# ── Systemd service ────────────────────────────────────────
cat > /etc/systemd/system/xray.service <<'EOF'
[Unit]
Description=ALL PRO Xray Service
After=network.target

[Service]
ExecStart=/usr/local/bin/xray run -c /etc/xray/config.json
Restart=always
User=root
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable xray &>/dev/null
systemctl restart xray
ok "Xray service aktif (VMess/VLess/Trojan + WS TLS/NTLS + gRPC)"
