#!/bin/bash
# ALL PRO - System Tools
source /etc/allpro/lib-common.sh

ALL_SVC=(ssh dropbear stunnel4 nginx xray trojan-go hysteria-server slowdns ws ohp badvpn fail2ban)

svc_status_all() {
    show_header
    _top; _btn "  ${IT}${AL}📊  STATUS SEMUA SERVICE${NC}"; _bot
    for s in "${ALL_SVC[@]}"; do
        if systemctl is-active --quiet "$s" 2>/dev/null; then
            printf "  ${LG}●${NC}  %-22s ${LG}aktif${NC}\n" "$s"
        elif systemctl list-unit-files 2>/dev/null | grep -q "^${s}\\.service"; then
            printf "  ${LR}●${NC}  %-22s ${LR}MATI${NC}  ${DIM}(coba: systemctl restart $s)${NC}\n" "$s"
        else
            printf "  ${DIM}○${NC}  %-22s ${DIM}belum terinstall${NC}\n" "$s"
        fi
    done
    pause
}

svc_restart_all() {
    show_header
    _top; _btn "  ${IT}${AL}🔁  RESTART SEMUA SERVICE${NC}"; _bot
    for s in "${ALL_SVC[@]}"; do
        if systemctl list-unit-files 2>/dev/null | grep -q "^${s}\\.service"; then
            if systemctl restart "$s" 2>/dev/null; then
                ok "$s restarted"
            else
                err "$s gagal restart"
            fi
        fi
    done
    pause
}

svc_diagnose() {
    show_header
    _top; _btn "  ${IT}${AL}🩺  DIAGNOSTIK SERVICE GAGAL${NC}"; _bot; echo ""
    local fail=0
    for s in "${ALL_SVC[@]}"; do
        systemctl list-unit-files 2>/dev/null | grep -q "^${s}\\.service" || continue
        if ! systemctl is-active --quiet "$s"; then
            ((fail++))
            _btn "  ${LR}● $s${NC}"
            _sep
            journalctl -u "$s" -n 15 --no-pager 2>/dev/null | sed 's/^/    /'
            _sep
            echo ""
        fi
    done
    [[ $fail -eq 0 ]] && ok "Semua service yang terinstall dalam keadaan aktif ✨"
    pause
}

while true; do
    show_header
    _top; _btn "  ${IT}${AL}⚙  SYSTEM TOOLS${NC}"; _bot
    _btn "  ${A2}[1]${NC}  📊  Status Semua Service"
    _btn "  ${A2}[2]${NC}  🔁  Restart Semua Service"
    _btn "  ${A2}[3]${NC}  🩺  Diagnosa Service Gagal (auto-debug)"
    _btn "  ${A2}[4]${NC}  🚀  BBR Congestion Control"
    _btn "  ${A2}[5]${NC}  🌐  IPv6 Manager"
    _btn "  ${A2}[6]${NC}  🔥  Status Firewall (iptables)"
    _btn "  ${A2}[7]${NC}  📡  Bandwidth / Koneksi Aktif"
    _btn "  ${A2}[8]${NC}  📄  Lihat Log SSH"
    _btn "  ${A2}[9]${NC}  📄  Lihat Log Xray"
    _btn "  ${A2}[10]${NC} 📄  Lihat Log Hysteria 2"
    _btn "  ${A2}[11]${NC} 📄  Lihat Log Nginx"
    _btn "  ${A2}[12]${NC} 🛡  Status Fail2ban"
    _btn "  ${A2}[13]${NC} 🧹  Clear semua expired user (auto)"
    _btn "  ${LR}[0]${NC}  ◀   Kembali"
    _bot
    echo -ne "  ${A1}›${NC} "; read -r ch
    case "$ch" in
        1)  svc_status_all ;;
        2)  svc_restart_all ;;
        3)  svc_diagnose ;;
        4)  menu-bbr  ;;
        5)  menu-ipv6 ;;
        6)  iptables -L INPUT -n --line-numbers | head -50; pause ;;
        7)  ss -tunap | head -40; pause ;;
        8)  tail -40 /var/log/auth.log 2>/dev/null; pause ;;
        9)  journalctl -u xray -n 40 --no-pager; pause ;;
        10) journalctl -u hysteria-server -n 40 --no-pager; pause ;;
        11) tail -40 /var/log/nginx/error.log 2>/dev/null; pause ;;
        12) fail2ban-client status sshd 2>/dev/null; pause ;;
        13) /etc/allpro/clean-expired.sh 2>/dev/null || warn "Belum tersedia"; pause ;;
        0)  break ;;
        *)  warn "Invalid"; sleep 1 ;;
    esac
done
