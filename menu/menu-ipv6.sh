#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#   ALL PRO - IPv6 Disable / Enable Manager
# ═══════════════════════════════════════════════════════════════
source /etc/allpro/lib-common.sh

ipv6_status() {
    show_header
    _top; _btn "  ${IT}${AL}🌐  STATUS IPv6${NC}"; _bot
    local all def lo
    all=$(sysctl -n net.ipv6.conf.all.disable_ipv6     2>/dev/null)
    def=$(sysctl -n net.ipv6.conf.default.disable_ipv6 2>/dev/null)
    lo=$(sysctl  -n net.ipv6.conf.lo.disable_ipv6      2>/dev/null)

    if [[ "$all" == "1" && "$def" == "1" && "$lo" == "1" ]]; then
        _btn "  ${DIM}Status${NC}       : ${LR}● IPv6 NONAKTIF${NC}"
    else
        _btn "  ${DIM}Status${NC}       : ${LG}● IPv6 AKTIF${NC}"
    fi

    _sep
    _btn "  ${DIM}all.disable_ipv6${NC}     : ${W}${all:-?}${NC}"
    _btn "  ${DIM}default.disable_ipv6${NC} : ${W}${def:-?}${NC}"
    _btn "  ${DIM}lo.disable_ipv6${NC}      : ${W}${lo:-?}${NC}"
    _sep
    _btn "  ${DIM}IPv6 addresses aktif:${NC}"
    local v6count; v6count=$(ip -6 addr show 2>/dev/null | grep -c 'inet6' || echo 0)
    if [[ "$v6count" -gt 0 ]]; then
        ip -6 addr show 2>/dev/null | grep 'inet6' | awk '{printf "  - %s (%s)\n",$2,$NF}'
    else
        _btn "  ${DIM}  (tidak ada)${NC}"
    fi
    _bot
    pause
}

ipv6_disable() {
    show_header
    _top; _btn "  ${IT}${AL}🚫  NONAKTIFKAN IPv6${NC}"; _bot
    inf "Menulis sysctl untuk disable IPv6 (permanen)..."

    # Hapus entry lama yang dikelola panel
    sed -i '/# ALL PRO IPv6/,/# END ALL PRO IPv6/d' /etc/sysctl.conf
    cat >> /etc/sysctl.conf <<'EOF'

# ALL PRO IPv6
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1
# END ALL PRO IPv6
EOF

    sysctl -w net.ipv6.conf.all.disable_ipv6=1     &>/dev/null
    sysctl -w net.ipv6.conf.default.disable_ipv6=1 &>/dev/null
    sysctl -w net.ipv6.conf.lo.disable_ipv6=1      &>/dev/null
    sysctl -p &>/dev/null

    # GRUB ipv6.disable=1 untuk persistent saat boot (opsional)
    if [[ -f /etc/default/grub ]]; then
        if ! grep -q 'ipv6.disable=1' /etc/default/grub; then
            inf "Menambahkan ipv6.disable=1 ke GRUB (efektif setelah reboot)..."
            sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 ipv6.disable=1"/' /etc/default/grub
            update-grub &>/dev/null
        fi
    fi

    ok "IPv6 berhasil dinonaktifkan"
    inf "Reboot disarankan untuk efek maksimal"
    pause
}

ipv6_enable() {
    show_header
    _top; _btn "  ${IT}${AL}✦  AKTIFKAN KEMBALI IPv6${NC}"; _bot
    echo -ne "  ${A3}Yakin aktifkan kembali IPv6?${NC} [y/N]: "; read -r yn
    [[ "$yn" != [yY] ]] && { inf "Dibatalkan"; pause; return; }

    sed -i '/# ALL PRO IPv6/,/# END ALL PRO IPv6/d' /etc/sysctl.conf
    sysctl -w net.ipv6.conf.all.disable_ipv6=0     &>/dev/null
    sysctl -w net.ipv6.conf.default.disable_ipv6=0 &>/dev/null
    sysctl -w net.ipv6.conf.lo.disable_ipv6=0      &>/dev/null
    sysctl -p &>/dev/null

    if [[ -f /etc/default/grub ]] && grep -q 'ipv6.disable=1' /etc/default/grub; then
        inf "Hapus ipv6.disable=1 dari GRUB..."
        sed -i 's/ ipv6.disable=1//' /etc/default/grub
        update-grub &>/dev/null
    fi

    ok "IPv6 diaktifkan kembali"
    pause
}

while true; do
    show_header
    _top; _btn "  ${IT}${AL}🌐  IPv6 MANAGER${NC}"; _bot
    local cur; cur=$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null)
    if [[ "$cur" == "1" ]]; then
        _btn "  ${DIM}Status${NC} : ${LR}● IPv6 NONAKTIF${NC}"
    else
        _btn "  ${DIM}Status${NC} : ${LG}● IPv6 AKTIF${NC}"
    fi
    _sep
    _btn "  ${A2}[1]${NC}  📊  Cek Status IPv6"
    _btn "  ${A2}[2]${NC}  🚫  Nonaktifkan IPv6 (anti-leak)"
    _btn "  ${A2}[3]${NC}  ✦   Aktifkan kembali IPv6"
    _btn "  ${LR}[0]${NC}  ◀   Kembali"
    _bot
    echo -ne "  ${A1}›${NC} "; read -r ch
    case "$ch" in
        1) ipv6_status ;;
        2) ipv6_disable ;;
        3) ipv6_enable ;;
        0) break ;;
        *) warn "Invalid"; sleep 1 ;;
    esac
done
