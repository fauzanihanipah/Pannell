#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#   ALL PRO - BBR Congestion Control Manager
# ═══════════════════════════════════════════════════════════════
source /etc/allpro/lib-common.sh

bbr_status() {
    show_header
    _top; _btn "  ${IT}${AL}🚀  STATUS BBR${NC}"; _bot
    local cc;        cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    local qdisc;     qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null)
    local kernel;    kernel=$(uname -r)
    local available; available=$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null)
    local mod_loaded=0
    lsmod 2>/dev/null | grep -q '^tcp_bbr' && mod_loaded=1

    echo ""
    _btn "  ${DIM}Kernel${NC}              : ${W}$kernel${NC}"
    _btn "  ${DIM}CC tersedia${NC}         : ${DIM}$available${NC}"

    if [[ $mod_loaded -eq 1 ]]; then
        _btn "  ${DIM}Module tcp_bbr${NC}      : ${LG}✔  Loaded${NC}"
    elif echo "$available" | grep -q bbr; then
        _btn "  ${DIM}Module tcp_bbr${NC}      : ${A3}✔  Built-in${NC}"
    else
        _btn "  ${DIM}Module tcp_bbr${NC}      : ${LR}✘  Tidak tersedia${NC}"
    fi

    if [[ "$cc" == "bbr" ]]; then
        _btn "  ${DIM}TCP Congestion${NC}      : ${LG}✔  BBR aktif${NC}"
    else
        _btn "  ${DIM}TCP Congestion${NC}      : ${LR}✘  $cc${NC}"
    fi

    if [[ "$qdisc" == "fq" || "$qdisc" == "fq_codel" ]]; then
        _btn "  ${DIM}Default Qdisc${NC}       : ${LG}✔  $qdisc${NC}"
    else
        _btn "  ${DIM}Default Qdisc${NC}       : ${A4}⚠  $qdisc${NC}  ${DIM}(disarankan: fq)${NC}"
    fi

    _sep
    _btn "  ${DIM}rmem_max${NC}            : $(sysctl -n net.core.rmem_max 2>/dev/null)"
    _btn "  ${DIM}wmem_max${NC}            : $(sysctl -n net.core.wmem_max 2>/dev/null)"
    _btn "  ${DIM}udp_rmem_min${NC}        : $(sysctl -n net.ipv4.udp_rmem_min 2>/dev/null)"
    _btn "  ${DIM}udp_wmem_min${NC}        : $(sysctl -n net.ipv4.udp_wmem_min 2>/dev/null)"
    _btn "  ${DIM}netdev_max_backlog${NC}  : $(sysctl -n net.core.netdev_max_backlog 2>/dev/null)"
    _btn "  ${DIM}ip_forward${NC}          : $(sysctl -n net.ipv4.ip_forward 2>/dev/null)"
    _bot

    if [[ "$cc" == "bbr" && ( "$qdisc" == "fq" || "$qdisc" == "fq_codel" ) ]]; then
        ok "BBR + Fair Queue aktif & optimal"
    elif [[ "$cc" == "bbr" ]]; then
        warn "BBR aktif tapi qdisc belum optimal"
    else
        err "BBR belum aktif!"
    fi
    pause
}

bbr_enable() {
    show_header
    _top; _btn "  ${IT}${AL}✦  AKTIFKAN BBR${NC}"; _bot
    inf "Memuat module tcp_bbr..."
    modprobe tcp_bbr 2>/dev/null

    grep -q 'tcp_bbr' /etc/modules-load.d/modules.conf 2>/dev/null || \
        echo "tcp_bbr" >> /etc/modules-load.d/modules.conf

    inf "Menulis sysctl tuning ke /etc/sysctl.conf..."
    # Bersihkan entry lama yang dikelola panel
    sed -i '/# ALL PRO BBR/,/# END ALL PRO BBR/d' /etc/sysctl.conf
    cat >> /etc/sysctl.conf <<'EOF'

# ALL PRO BBR
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192
net.core.netdev_max_backlog=16384
net.ipv4.ip_forward=1
# END ALL PRO BBR
EOF

    sysctl -p &>/dev/null
    sleep 1

    local cc; cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    if [[ "$cc" == "bbr" ]]; then
        ok "BBR berhasil diaktifkan ✨"
    else
        err "Gagal mengaktifkan BBR. Kernel mungkin belum mendukung."
        warn "Reboot kemudian cek lagi: sysctl net.ipv4.tcp_congestion_control"
    fi
    pause
}

bbr_disable() {
    show_header
    _top; _btn "  ${IT}${AL}⚠  NONAKTIFKAN BBR${NC}"; _bot
    echo -ne "  ${A3}Yakin nonaktifkan BBR?${NC} [y/N]: "; read -r yn
    [[ "$yn" != [yY] ]] && { inf "Dibatalkan"; pause; return; }

    sed -i '/# ALL PRO BBR/,/# END ALL PRO BBR/d' /etc/sysctl.conf
    sysctl -w net.ipv4.tcp_congestion_control=cubic &>/dev/null
    sysctl -w net.core.default_qdisc=pfifo_fast    &>/dev/null
    sysctl -p &>/dev/null
    ok "BBR dinonaktifkan, kembali ke cubic + pfifo_fast"
    pause
}

bbr_test_speed() {
    show_header
    _top; _btn "  ${IT}${AL}📊  QUICK SPEED TEST${NC}"; _bot
    inf "Download test 100MB dari Cloudflare..."
    curl -o /dev/null -s -w "  ${DIM}Speed${NC} : ${LG}%{speed_download}${NC} bytes/s\n  ${DIM}Time${NC}  : ${A3}%{time_total}${NC} s\n" \
        --max-time 30 https://speed.cloudflare.com/__down?bytes=104857600
    echo ""
    pause
}

while true; do
    show_header
    _top; _btn "  ${IT}${AL}🚀  BBR CONGESTION CONTROL${NC}"; _bot
    local cur_cc; cur_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    if [[ "$cur_cc" == "bbr" ]]; then
        _btn "  ${DIM}Status${NC} : ${LG}● BBR AKTIF${NC}"
    else
        _btn "  ${DIM}Status${NC} : ${LR}○ BBR NONAKTIF${NC} (${cur_cc})"
    fi
    _sep
    _btn "  ${A2}[1]${NC}  📊  Cek Status Lengkap"
    _btn "  ${A2}[2]${NC}  ✦   Aktifkan BBR + Tuning UDP"
    _btn "  ${A2}[3]${NC}  ⚠   Nonaktifkan BBR"
    _btn "  ${A2}[4]${NC}  🚀  Quick Speed Test"
    _btn "  ${LR}[0]${NC}  ◀   Kembali"
    _bot
    echo -ne "  ${A1}›${NC} "; read -r ch
    case "$ch" in
        1) bbr_status ;;
        2) bbr_enable ;;
        3) bbr_disable ;;
        4) bbr_test_speed ;;
        0) break ;;
        *) warn "Invalid"; sleep 1 ;;
    esac
done
