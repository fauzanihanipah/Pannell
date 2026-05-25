#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#   ALL PRO - SlowDNS (NS / sldns-server)
# ═══════════════════════════════════════════════════════════════
ALLPRO_DIR="/etc/allpro"
SLOWDNS_DIR="/etc/slowdns"
DOMAIN=$(cat "$ALLPRO_DIR/domain" 2>/dev/null)
GREEN='\033[1;32m'; CYAN='\033[1;36m'; NC='\033[0m'
ok(){  echo -e "  ${GREEN}✔${NC}  $*"; }
inf(){ echo -e "  ${CYAN}➜${NC}  $*"; }

mkdir -p "$SLOWDNS_DIR"

# Cek apakah sldns-keygen ada (dibundel di binary atau separate)
inf "Generate SlowDNS keys..."
if [[ ! -f "$SLOWDNS_DIR/server.pub" || ! -f "$SLOWDNS_DIR/server.key" ]]; then
    # sldns-server biasanya bisa generate via flag -gen
    /usr/local/bin/sldns-server -gen-key-pair "$SLOWDNS_DIR/server.key" "$SLOWDNS_DIR/server.pub" 2>/dev/null || {
        # Fallback: openssl ed25519
        openssl genpkey -algorithm ED25519 -out "$SLOWDNS_DIR/server.key" 2>/dev/null
        openssl pkey -in "$SLOWDNS_DIR/server.key" -pubout -out "$SLOWDNS_DIR/server.pub" 2>/dev/null
    }
fi

inf "Buat systemd service SlowDNS..."
cat > /etc/systemd/system/slowdns.service <<EOF
[Unit]
Description=ALL PRO SlowDNS Server
After=network.target

[Service]
ExecStart=/usr/local/bin/sldns-server -udp :5300 -privkey-file $SLOWDNS_DIR/server.key ${DOMAIN} 127.0.0.1:22
Restart=always
LimitNOFILE=1048576
User=root

[Install]
WantedBy=multi-user.target
EOF

# Forward UDP 53 → 5300 (DNS path)
iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300 2>/dev/null
iptables -I INPUT -p udp --dport 5300 -j ACCEPT 2>/dev/null
netfilter-persistent save &>/dev/null

systemctl daemon-reload
systemctl enable slowdns &>/dev/null
systemctl restart slowdns

# Tampilkan public key (untuk client)
PUBKEY=$(cat "$SLOWDNS_DIR/server.pub" 2>/dev/null | base64 -w0)
echo "PUBKEY=$PUBKEY" > "$SLOWDNS_DIR/info"
echo "NS=$DOMAIN"     >> "$SLOWDNS_DIR/info"

ok "SlowDNS aktif (UDP 53 → 5300, NS: $DOMAIN)"
