#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#   ALL PRO - Trojan-Go (port 2087, WS TLS)
# ═══════════════════════════════════════════════════════════════
ALLPRO_DIR="/etc/allpro"
TROJAN_DIR="/etc/trojan-go"
DOMAIN=$(cat "$ALLPRO_DIR/domain" 2>/dev/null)
GREEN='\033[1;32m'; CYAN='\033[1;36m'; RED='\033[1;31m'; NC='\033[0m'
ok(){  echo -e "  ${GREEN}✔${NC}  $*"; }
inf(){ echo -e "  ${CYAN}➜${NC}  $*"; }
err(){ echo -e "  ${RED}✘${NC}  $*"; }

mkdir -p "$TROJAN_DIR"

# ── Generate cert sendiri (gak depend cert lain) ──────────
inf "Generate cert Trojan-Go..."
if [[ -f /etc/letsencrypt/live/$DOMAIN/fullchain.pem ]]; then
    cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem "$TROJAN_DIR/trojan.crt"
    cp /etc/letsencrypt/live/$DOMAIN/privkey.pem   "$TROJAN_DIR/trojan.key"
elif [[ -f /etc/xray/xray.crt ]]; then
    cp /etc/xray/xray.crt "$TROJAN_DIR/trojan.crt"
    cp /etc/xray/xray.key "$TROJAN_DIR/trojan.key"
else
    openssl req -new -newkey rsa:2048 -days 1095 -nodes -x509 \
      -subj "/CN=$DOMAIN" \
      -keyout "$TROJAN_DIR/trojan.key" \
      -out    "$TROJAN_DIR/trojan.crt" &>/dev/null
fi
chmod 644 "$TROJAN_DIR"/trojan.{crt,key}

# ── Config Trojan-Go ───────────────────────────────────────
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
    "path":    "/trojango-ws",
    "host":    "$DOMAIN"
  }
}
EOF

cat > /etc/systemd/system/trojan-go.service <<'EOF'
[Unit]
Description=ALL PRO Trojan-Go
After=network.target nss-lookup.target

[Service]
ExecStart=/usr/local/bin/trojan-go -config /etc/trojan-go/config.json
Restart=on-failure
RestartSec=3
LimitNOFILE=1048576
User=root

[Install]
WantedBy=multi-user.target
EOF

# Firewall
iptables -I INPUT -p tcp --dport 2087 -j ACCEPT 2>/dev/null
netfilter-persistent save &>/dev/null

systemctl daemon-reload
systemctl enable trojan-go &>/dev/null
systemctl restart trojan-go
sleep 1
if systemctl is-active --quiet trojan-go; then
    touch "$ALLPRO_DIR/trojango.db"
    echo "default|$DEFAULT_PWD|$(date -d '+30 days' +%Y-%m-%d)" > "$ALLPRO_DIR/trojango.db"
    ok "Trojan-Go aktif (port 2087, WS path /trojango-ws)"
else
    err "Trojan-Go gagal start — cek: journalctl -u trojan-go -n 20"
fi
