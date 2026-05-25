#!/bin/bash
# ALL PRO - SlowDNS info menu
source /etc/allpro/lib-common.sh
INFO="/etc/slowdns/info"

while true; do
    show_header
    _top; _btn "  ${IT}${AL}🌎  SLOWDNS${NC}"; _bot
    if [[ -f "$INFO" ]]; then
        source "$INFO"
        _btn "  ${DIM}NS Domain${NC}  : ${W}${NS}${NC}"
        _btn "  ${DIM}Public Key${NC} : ${A3}${PUBKEY}${NC}"
        _btn "  ${DIM}Port${NC}       : UDP 53 → 5300"
        _btn "  ${DIM}Backend${NC}    : SSH (127.0.0.1:22)"
        _btn "  ${DIM}Status${NC}     : $(sv_slowdns)"
    else
        warn "SlowDNS belum terinstall"
    fi
    _sep
    _btn "  ${A2}[1]${NC}  Restart Service"
    _btn "  ${A2}[2]${NC}  Tampilkan Log"
    _btn "  ${LR}[0]${NC}  ◀   Kembali"
    _bot
    echo -ne "  ${A1}›${NC} "; read -r ch
    case "$ch" in
        1) systemctl restart slowdns; ok "Restart"; sleep 1 ;;
        2) journalctl -u slowdns -n 30 --no-pager; pause ;;
        0) break ;;
        *) warn "Invalid"; sleep 1 ;;
    esac
done
