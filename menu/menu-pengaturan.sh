#!/bin/bash
# ALL PRO - Pengaturan
source /etc/allpro/lib-common.sh

set_brand() {
    show_header; _top; _btn "  ${IT}${AL}⚙  GANTI BRAND${NC}"; _bot
    local cur; cur=$(get_brand)
    echo -ne "  ${A3}Brand baru${NC} [$cur]: "; read -r b
    [[ -z "$b" ]] && b="$cur"
    sed -i "s/^BRAND=.*/BRAND=$b/" "$ALLPRO_DIR/store.conf"
    ok "Brand: $b"; pause
}

set_domain() {
    show_header; _top; _btn "  ${IT}${AL}🌐  GANTI DOMAIN${NC}"; _bot
    local cur; cur=$(get_domain)
    echo -ne "  ${A3}Domain baru${NC} [$cur]: "; read -r d
    [[ -z "$d" ]] && d="$cur"
    echo "$d" > "$ALLPRO_DIR/domain"
    sed -i "s/^DOMAIN=.*/DOMAIN=$d/" "$ALLPRO_DIR/store.conf" 2>/dev/null
    ok "Domain: $d (restart layanan untuk apply)"; pause
}

set_admin() {
    show_header; _top; _btn "  ${IT}${AL}👤  ADMIN TELEGRAM${NC}"; _bot
    local cur; cur=$(grep ^ADMIN_TG= "$ALLPRO_DIR/store.conf" | cut -d= -f2-)
    echo -ne "  ${A3}TG admin${NC} [$cur]: "; read -r t
    [[ -z "$t" ]] && t="$cur"
    sed -i "s/^ADMIN_TG=.*/ADMIN_TG=$t/" "$ALLPRO_DIR/store.conf"
    ok "Admin TG: $t"; pause
}

while true; do
    show_header
    _top; _btn "  ${IT}${AL}⚙  PENGATURAN${NC}"; _bot
    _btn "  ${A2}[1]${NC}  ✏  Ganti Brand"
    _btn "  ${A2}[2]${NC}  🌐  Ganti Domain"
    _btn "  ${A2}[3]${NC}  👤  Set Admin Telegram"
    _btn "  ${A2}[4]${NC}  🔁  Restart Semua Service"
    _btn "  ${LR}[0]${NC}  ◀   Kembali"
    _bot
    echo -ne "  ${A1}›${NC} "; read -r ch
    case "$ch" in
        1) set_brand;; 2) set_domain;; 3) set_admin;;
        4) for s in ssh dropbear stunnel4 nginx xray trojan-go hysteria-server slowdns ws ohp badvpn; do
               systemctl restart "$s" 2>/dev/null
           done; ok "Restart"; sleep 1 ;;
        0) break;; *) warn "Invalid"; sleep 1;;
    esac
done
