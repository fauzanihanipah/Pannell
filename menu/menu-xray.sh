#!/bin/bash
# ALL PRO - Xray Submenu (VMess / VLess / Trojan)
source /etc/allpro/lib-common.sh

while true; do
    show_header
    _top; _btn "  ${IT}${AL}🟣  XRAY (VMess / VLess / Trojan)${NC}"; _bot
    _btn "  ${A2}[1]${NC}  📨  VMess  (WS TLS / NTLS)"
    _btn "  ${A2}[2]${NC}  ✉   VLess  (WS TLS / NTLS)"
    _btn "  ${A2}[3]${NC}  🛡  Trojan (WS TLS + gRPC)"
    _btn "  ${LR}[0]${NC}  ◀   Kembali"
    _bot
    echo -ne "  ${A1}›${NC} "; read -r ch
    case "$ch" in
        1) menu-vmess ;;
        2) menu-vless ;;
        3) menu-trojan ;;
        0) break ;;
        *) warn "Invalid"; sleep 1 ;;
    esac
done
