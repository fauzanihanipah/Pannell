#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#   ALL PRO - Trojan-Go (port 2087 WS TLS)
# ═══════════════════════════════════════════════════════════════
ALLPRO_DIR="/etc/allpro"
TROJAN_DIR="/etc/trojan-go"
DOMAIN=$(cat "$ALLPRO_DIR/domain" 2>/dev/null)
GREEN='\033[1;32m'; CYAN='\033[1;36m'; NC='\033[0m'
ok(){  echo -e "  ${GREEN}✔${NC}  $*"; }
inf(){ echo -e "  ${CYAN}➜${NC}  $*"; }

mkdir -p "$TROJAN_DIR"

# Reuse cert dari xray jika ada
if [[ -f /etc/xray/xray.crt ]]; then
    cp /etc/xray/xray.crt "$TROJAN_DIR/trojan.crt"
    cp /etc/xray/xray.key "$TROJAN_DIR/trojan.key"
else
    openssl req -new -newkey rsa:2048 -days 1095 -nodes -x509 \
      -subj "/CN=$DOMAIN" -keyout "$TROJAN_DIR/trojan.key" \
      -out "$TROJAN_DIR/trojan.crt" &>/dev/null
fi

inf "Generate Trojan-Go config..."
DEFAULT_PWD=$(cat /proc/sys/kernel/random/uuid)
cat > "$TROJAN_DIR/config.json" <<EOF
{
  "run_type": "server",
  "local_addr": "0.0.0.0",
  "local_port": 2087,
  "remote_addr": "127.0.0.1",
  "remote_port": 89,
  "password": ["$DEFAULT_PWD"],
  "ssl": {
    "cert": "$TROJAN_DIR/trojan.crt",
    "key":  "$TROJAN_DIR/trojan.key",
    "sni":  "$DOMAIN",
    "alpn": ["http/1.1"]
  },
  "websocket": {
    "enabled": true,
    "path": "/trojango-ws",
    "host": "$DOMAIN"
  }
}
EOF

cat > /etc/systemd/system/trojan-go.service <<'EOF'
[Unit]
Description=ALL PRO Trojan-Go
After=network.target

[Service]
ExecStart=/usr/local/bin/trojan-go -config /etc/trojan-go/config.json
Restart=always
LimitNOFILE=1048576
User=root

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable trojan-go &>/dev/null
systemctl restart trojan-go
touch "$ALLPRO_DIR/trojango.db"
echo "default|$DEFAULT_PWD|$(date -d "+30 days" +%Y-%m-%d)" > "$ALLPRO_DIR/trojango.db"
ok "Trojan-Go aktif (port 2087, WS path /trojango-ws)"
