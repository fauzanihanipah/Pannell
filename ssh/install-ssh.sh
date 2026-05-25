#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#   ALL PRO - SSH / OpenSSH + Dropbear + Stunnel + WS + OHP + UDPGW
# ═══════════════════════════════════════════════════════════════
ALLPRO_DIR="/etc/allpro"
DOMAIN=$(cat "$ALLPRO_DIR/domain" 2>/dev/null)
GREEN='\033[1;32m'; CYAN='\033[1;36m'; RED='\033[1;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()  { echo -e "  ${GREEN}✔${NC}  $*"; }
inf() { echo -e "  ${CYAN}➜${NC}  $*"; }
err() { echo -e "  ${RED}✘${NC}  $*"; }
warn(){ echo -e "  ${YELLOW}⚠${NC}  $*"; }

# ── SSHD: 22 + 442 ─────────────────────────────────────────
inf "Konfigurasi SSHD..."
sed -i 's/^#\?Port .*/Port 22/' /etc/ssh/sshd_config
grep -q "^Port 442" /etc/ssh/sshd_config || echo "Port 442" >> /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
systemctl restart ssh
ok "SSH (22, 442) aktif"

# ── Dropbear: 109, 143 ─────────────────────────────────────
inf "Konfigurasi Dropbear..."
sed -i 's/^NO_START=.*/NO_START=0/' /etc/default/dropbear 2>/dev/null
sed -i 's/^DROPBEAR_PORT=.*/DROPBEAR_PORT=109/' /etc/default/dropbear 2>/dev/null
sed -i 's/^DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS="-p 143"/' /etc/default/dropbear 2>/dev/null
systemctl enable dropbear &>/dev/null
systemctl restart dropbear
ok "Dropbear (109, 143) aktif"

# ── Stunnel SSL: HANYA 777 (untuk Dropbear) ───────────────
# port 443 di-handle Nginx agar gak bentrok
inf "Konfigurasi Stunnel SSL (port 777)..."
mkdir -p /etc/stunnel
openssl req -new -newkey rsa:2048 -days 1095 -nodes -x509 \
  -subj "/C=ID/ST=ALL/L=PRO/O=ALL/OU=PRO/CN=$DOMAIN" \
  -keyout /etc/stunnel/stunnel.pem -out /etc/stunnel/stunnel.pem &>/dev/null
chmod 600 /etc/stunnel/stunnel.pem

cat > /etc/stunnel/stunnel.conf <<EOF
cert = /etc/stunnel/stunnel.pem
client = no
socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1

[dropbear]
accept = 777
connect = 127.0.0.1:109
EOF
sed -i 's/ENABLED=.*/ENABLED=1/' /etc/default/stunnel4 2>/dev/null
systemctl enable stunnel4 &>/dev/null
systemctl restart stunnel4
ok "Stunnel SSL (777) aktif"

# ── BadVPN UDPGW: 7100 7200 7300 ───────────────────────────
inf "Setup BadVPN UDPGW..."
cat > /etc/systemd/system/badvpn.service <<'EOF'
[Unit]
Description=BadVPN UDPGW (multi-port)
After=network.target

[Service]
Type=forking
ExecStart=/bin/sh -c 'screen -dmS udp7100 /usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:7100 --max-clients 1500; screen -dmS udp7200 /usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:7200 --max-clients 1500; screen -dmS udp7300 /usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 1500'
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable badvpn &>/dev/null
systemctl restart badvpn
ok "BadVPN UDPGW (7100/7200/7300) aktif"

# ── OHP Server: 8080 HTTP / 8443 SSL ───────────────────────
inf "Setup OHP Server..."
cat > /etc/systemd/system/ohp.service <<EOF
[Unit]
Description=OHP HTTP Proxy (HTTP injector)
After=network.target

[Service]
ExecStart=/usr/local/bin/ohpserver -port 8080 -proxy 127.0.0.1:22 -tls-port 8443 -tls-key /etc/stunnel/stunnel.pem -tls-cert /etc/stunnel/stunnel.pem
Restart=always
RestartSec=3
User=root

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable ohp &>/dev/null
systemctl restart ohp
ok "OHP Server (8080 HTTP / 8443 SSL) aktif"

# ── WS Proxy (SSH WS CDN TLS / NTLS) ───────────────────────
# Tulis service file sendiri (override) supaya pasti jalan
inf "Setup WS Proxy (SSH WS port 8880)..."
cat > /etc/systemd/system/ws.service <<'EOF'
[Unit]
Description=ALL PRO WebSocket Proxy (SSH-over-WS)
After=network.target

[Service]
ExecStart=/usr/local/bin/ws
Restart=always
RestartSec=3
User=root
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable ws &>/dev/null
systemctl restart ws
sleep 1
if systemctl is-active --quiet ws; then
    ok "WS service aktif"
else
    warn "WS service belum aktif — cek: journalctl -u ws -n 30"
fi

# ── Nginx: 80 (NTLS) + 443 (TLS) untuk SSH WS ─────────────
inf "Setup Nginx routing SSH WS..."
mkdir -p /etc/nginx/conf.d
# Generate cert kalau belum ada
if [[ ! -f /etc/xray/xray.crt ]]; then
    mkdir -p /etc/xray
    openssl req -new -newkey rsa:2048 -days 1095 -nodes -x509 \
      -subj "/CN=$DOMAIN" \
      -keyout /etc/xray/xray.key -out /etc/xray/xray.crt &>/dev/null
fi

cat > /etc/nginx/conf.d/allpro-ssh-ws.conf <<EOF
# SSH WS NTLS (80) — Cloudflare CDN compatible
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    root /var/www/html;
    location / { return 200 "ALL PRO"; }
    location /ssh-ws {
        proxy_pass http://127.0.0.1:8880;
        proxy_redirect off;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_read_timeout 86400;
    }
}
EOF
# Disable default nginx vhost agar gak bentrok
rm -f /etc/nginx/sites-enabled/default 2>/dev/null
nginx -t &>/dev/null && systemctl restart nginx
systemctl enable nginx &>/dev/null
ok "Nginx routing SSH WS (80/ssh-ws) aktif"

# ── Firewall ───────────────────────────────────────────────
for p in 22 442 109 143 443 777 80 8080 8443 8880; do
    iptables -I INPUT -p tcp --dport $p -j ACCEPT 2>/dev/null
done
netfilter-persistent save &>/dev/null
ok "SSH stack lengkap terpasang!"
