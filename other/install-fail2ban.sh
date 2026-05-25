#!/bin/bash
# ALL PRO - Fail2ban (anti-bruteforce SSH)
GREEN='\033[1;32m'; NC='\033[0m'
echo -e "  ${GREEN}✔${NC}  Konfigurasi Fail2ban..."
cat > /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5
banaction = iptables-multiport

[sshd]
enabled = true
port    = 22,442
logpath = %(sshd_log)s
backend = systemd

[dropbear]
enabled = true
port    = 109,143
logpath = /var/log/auth.log
backend = auto
EOF
systemctl enable fail2ban &>/dev/null
systemctl restart fail2ban
echo -e "  ${GREEN}✔${NC}  Fail2ban aktif (SSH/Dropbear)"
