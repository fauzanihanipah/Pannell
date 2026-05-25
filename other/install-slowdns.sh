#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#   ALL PRO - SlowDNS (sldns-server, NS-mode)
# ═══════════════════════════════════════════════════════════════
ALLPRO_DIR="/etc/allpro"
SLOWDNS_DIR="/etc/slowdns"
DOMAIN=$(cat "$ALLPRO_DIR/domain" 2>/dev/null)
GREEN='\033[1;32m'; CYAN='\033[1;36m'; RED='\033[1;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok(){   echo -e "  ${GREEN}✔${NC}  $*"; }
inf(){  echo -e "  ${CYAN}➜${NC}  $*"; }
err(){  echo -e "  ${RED}✘${NC}  $*"; }
warn(){ echo -e "  ${YELLOW}⚠${NC}  $*"; }

mkdir -p "$SLOWDNS_DIR"

# ── Bebaskan port 53: matikan systemd-resolved stub ───────
inf "Membebaskan port 53 dari systemd-resolved..."
if systemctl is-active --quiet systemd-resolved; then
    mkdir -p /etc/systemd/resolved.conf.d
    cat > /etc/systemd/resolved.conf.d/allpro.conf <<'EOF'
[Resolve]
DNSStubListener=no
EOF
    rm -f /etc/resolv.conf
    echo -e "nameserver 1.1.1.1\nnameserver 8.8.8.8" > /etc/resolv.conf
    systemctl restart systemd-resolved 2>/dev/null
    ok "systemd-resolved stub dimatikan"
fi

# ── Generate keypair ──────────────────────────────────────
inf "Generate SlowDNS keypair..."
if [[ ! -s "$SLOWDNS_DIR/server.key" || ! -s "$SLOWDNS_DIR/server.pub" ]]; then
    # sldns-server biasanya support flag -gen-key-pair
    /usr/local/bin/sldns-server -gen-key-pair "$SLOWDNS_DIR/server.key" "$SLOWDNS_DIR/server.pub" 2>/dev/null
    if [[ ! -s "$SLOWDNS_DIR/server.pub" ]]; then
        # Coba syntax alternatif
        cd "$SLOWDNS_DIR" && /usr/local/bin/sldns-server -gen-cert 2>/dev/null
    fi
    if [[ ! -s "$SLOWDNS_DIR/server.pub" ]]; then
        # Fallback Ed25519 via openssl
        openssl genpkey -algorithm ED25519 -out "$SLOWDNS_DIR/server.key" 2>/dev/null
        openssl pkey -in "$SLOWDNS_DIR/server.key" -pubout -out "$SLOWDNS_DIR/server.pub" 2>/dev/null
    fi
fi
chmod 600 "$SLOWDNS_DIR"/server.key
chmod 644 "$SLOWDNS_DIR"/server.pub

# ── Forwarding UDP 53 → 5300 (DNS path) ───────────────────
inf "Setup port forwarding UDP 53 → 5300..."
# Bersihkan rule lama biar idempotent
iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300 2>/dev/null
iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300 2>/dev/null
iptables -I INPUT -p udp --dport 5300 -j ACCEPT 2>/dev/null
iptables -I INPUT -p udp --dport 53   -j ACCEPT 2>/dev/null
netfilter-persistent save &>/dev/null

# ── Systemd service ──────────────────────────────────────
inf "Buat systemd service SlowDNS..."
cat > /etc/systemd/system/slowdns.service <<EOF
[Unit]
Description=ALL PRO SlowDNS Server
After=network.target

[Service]
ExecStart=/usr/local/bin/sldns-server -udp :5300 -privkey-file $SLOWDNS_DIR/server.key $DOMAIN 127.0.0.1:22
Restart=on-failure
RestartSec=3
LimitNOFILE=1048576
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable slowdns &>/dev/null
systemctl restart slowdns
sleep 1

# ── Simpan info untuk client ──────────────────────────────
PUBKEY=""
[[ -s "$SLOWDNS_DIR/server.pub" ]] && PUBKEY=$(cat "$SLOWDNS_DIR/server.pub" | tr -d '\n' | head -c 256)
cat > "$SLOWDNS_DIR/info" <<EOF
NS=$DOMAIN
PUBKEY=$PUBKEY
PORT=5300
EOF

if systemctl is-active --quiet slowdns; then
    ok "SlowDNS aktif (NS: $DOMAIN, UDP 53 → 5300)"
else
    warn "SlowDNS belum aktif — cek: journalctl -u slowdns -n 30"
fi
