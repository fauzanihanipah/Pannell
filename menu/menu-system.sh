#!/bin/bash
# ALL PRO - System Tools
source /etc/allpro/lib-common.sh

while true; do
    show_header
    _top; _btn "  ${IT}${AL}⚙  SYSTEM TOOLS${NC}"; _bot
    _btn "  ${A2}[1]${NC}  📊  Status Semua Service"
    _btn "  ${A2}[2]${NC}  🔁  Restart Semua Service"
    _btn "  ${A2}[3]${NC}  🚀  BBR Congestion Control (menu)"
    _btn "  ${A2}[4]${NC}  🌐  IPv6 Manager (disable/enable)"
    _btn "  ${A2}[5]${NC}  🔥  Status Firewall (iptables)"
    _btn "  ${A2}[6]${NC}  📡  Bandwidth / Koneksi Aktif"
    _btn "  ${A2}[7]${NC}  📄  Lihat Log SSH"
    _btn "  ${A2}[8]${NC}  📄  Lihat Log Xray"
    _btn "  ${A2}[9]${NC}  📄  Lihat Log Hysteria 2"
    _btn "  ${A2}[10]${NC} 🛡  Status Fail2ban"
    _btn "  ${A2}[11]${NC} 🧹  Clear semua expired user (auto)"
    _btn "  ${LR}[0]${NC}  ◀   Kembali"
    _bot
    echo -ne "  ${A1}›${NC} "; read -r ch
    case "$ch" in
        1)  for s in ssh dropbear stunnel4 nginx xray trojan-go hysteria-server slowdns ws ohp badvpn fail2ban; do
                printf "  %-22s : " "$s"
                systemctl is-active "$s" 2>/dev/null
            done; pause ;;
        2)  for s in ssh dropbear stunnel4 nginx xray trojan-go hysteria-server slowdns ws ohp badvpn; do
                systemctl restart "$s" 2>/dev/null && ok "$s restarted"
            done; pause ;;
        3)  menu-bbr  ;;
        4)  menu-ipv6 ;;
        5)  iptables -L INPUT -n --line-numbers | head -50; pause ;;
        6)  ss -tunap | head -40; pause ;;
        7)  tail -40 /var/log/auth.log 2>/dev/null; pause ;;
        8)  journalctl -u xray -n 40 --no-pager; pause ;;
        9)  journalctl -u hysteria-server -n 40 --no-pager; pause ;;
        10) fail2ban-client status sshd 2>/dev/null; pause ;;
        11) /etc/allpro/clean-expired.sh 2>/dev/null || warn "Belum tersedia"; pause ;;
        0)  break ;;
        *)  warn "Invalid"; sleep 1 ;;
    esac
done
