#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#   ALL PRO - Hysteria 2 (UDP)
# ═══════════════════════════════════════════════════════════════
ALLPRO_DIR="/etc/allpro"
HYSTERIA_DIR="/etc/hysteria"
DOMAIN=$(cat "$ALLPRO_DIR/domain" 2>/dev/null)
GREEN='\033[1;32m'; CYAN='\033[1;36m'; NC='\033[0m'
ok(){  echo -e "  ${GREEN}✔${NC}  $*"; }
inf(){ echo -e "  ${CYAN}➜${NC}  $*"; }

mkdir -p "$HYSTERIA_DIR"

# Cert (reuse xray's cert if exists)
if [[ -f /etc/xray/xray.crt ]]; then
    cp /etc/xray/xray.crt "$HYSTERIA_DIR/server.crt"
    cp /etc/xray/xray.key "$HYSTERIA_DIR/server.key"
else
    openssl req -new -newkey rsa:2048 -days 1095 -nodes -x509 \
      -subj "/CN=$DOMAIN" -keyout "$HYSTERIA_DIR/server.key" \
      -out "$HYSTERIA_DIR/server.crt" &>/dev/null
fi

inf "Generate Hysteria 2 config..."
DEFAULT_PWD=$(cat /proc/sys/kernel/random/uuid)
cat > "$HYSTERIA_DIR/config.yaml" <<EOF
listen: :8443
tls:
  cert: $HYSTERIA_DIR/server.crt
  key:  $HYSTERIA_DIR/server.key
auth:
  type: password
  password: $DEFAULT_PWD
masquerade:
  type: proxy
  proxy:
    url: https://www.bing.com
    rewriteHost: true
EOF

cat > /etc/systemd/system/hysteria-server.service <<'EOF'
[Unit]
Description=ALL PRO Hysteria 2 Server
After=network.target

[Service]
ExecStart=/usr/local/bin/hysteria server -c /etc/hysteria/config.yaml
Restart=always
LimitNOFILE=1048576
User=root

[Install]
WantedBy=multi-user.target
EOF

# UDP firewall
iptables -I INPUT -p udp --dport 8443 -j ACCEPT 2>/dev/null
iptables -t nat -A PREROUTING -p udp --dport 20000:50000 -j DNAT --to-destination :8443 2>/dev/null
netfilter-persistent save &>/dev/null

systemctl daemon-reload
systemctl enable hysteria-server &>/dev/null
systemctl restart hysteria-server

touch "$ALLPRO_DIR/hy2.db"
echo "default|$DEFAULT_PWD|$(date -d "+30 days" +%Y-%m-%d)" > "$ALLPRO_DIR/hy2.db"
ok "Hysteria 2 aktif (UDP port 8443, range 20000-50000)"
