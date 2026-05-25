#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#   ALL PRO - Premium Tunneling Panel Installer
#   Support : SSH, V2Ray, Trojan-Go, Hysteria 2, SlowDNS
#   OS      : Debian & Ubuntu (all version)
# ═══════════════════════════════════════════════════════════════

# ── COLORS ─────────────────────────────────────────────────
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
PURPLE='\033[38;5;135m'
WHITE='\033[1;37m'
NC='\033[0m'
DIM='\033[2m'

# ── BINARY URLs (user provided) ────────────────────────────
XRAY_URL="https://github.com/chanelog/max/releases/download/bin/Xray-linux-64.zip"
HYSTERIA_URL="https://github.com/chanelog/max/releases/download/bin/hysteria-linux-amd64"
TROJAN_GO_URL="https://github.com/chanelog/max/releases/download/bin/trojan-go-linux-amd64.zip"
UDPGW_URL="https://raw.githubusercontent.com/chanelog/max/main/udpgw"
SLOWDNS_URL="https://github.com/chanelog/max/raw/main/sldns-server"
OHP_URL="https://github.com/chanelog/max/raw/main/ohpserver"
WS_URL="https://raw.githubusercontent.com/chanelog/max/main/ws"
WS_SERVICE_URL="https://raw.githubusercontent.com/chanelog/max/main/ws.service"

# ── REPO BASE (menus & installers) ─────────────────────────
REPO_BASE="${REPO_BASE:-https://raw.githubusercontent.com/fauzanihanipah/Pannell/main}"

# ── DIRECTORIES ────────────────────────────────────────────
ALLPRO_DIR="/etc/allpro"
XRAY_DIR="/etc/xray"
TROJAN_DIR="/etc/trojan-go"
HYSTERIA_DIR="/etc/hysteria"
SLOWDNS_DIR="/etc/slowdns"
MENU_DIR="/usr/local/sbin"

# ── HELPERS ────────────────────────────────────────────────
ok()   { echo -e "  ${GREEN}✔${NC}  $*"; }
inf()  { echo -e "  ${CYAN}➜${NC}  $*"; }
err()  { echo -e "  ${RED}✘${NC}  $*"; }
warn() { echo -e "  ${YELLOW}⚠${NC}  $*"; }
hr()   { echo -e "  ${PURPLE}─────────────────────────────────────────────────────────${NC}"; }


check_root() {
    [[ $EUID -ne 0 ]] && { err "Script harus dijalankan sebagai root!"; exit 1; }
}

check_os() {
    [[ ! -f /etc/os-release ]] && { err "OS tidak dikenali!"; exit 1; }
    source /etc/os-release
    local os_id=$(echo "${ID}" | tr '[:upper:]' '[:lower:]')
    if [[ "$os_id" != "debian" && "$os_id" != "ubuntu" ]]; then
        err "OS tidak didukung! Hanya Debian & Ubuntu."
        exit 1
    fi
    ok "OS: ${PRETTY_NAME}"
}

show_logo() {
    clear
    echo ""
    hr
    echo -e "  ${PURPLE}    █████╗ ██╗     ██╗         ██████╗ ██████╗  ██████╗ ${NC}"
    echo -e "  ${PURPLE}   ██╔══██╗██║     ██║         ██╔══██╗██╔══██╗██╔═══██╗${NC}"
    echo -e "  ${PURPLE}   ███████║██║     ██║         ██████╔╝██████╔╝██║   ██║${NC}"
    echo -e "  ${PURPLE}   ██╔══██║██║     ██║         ██╔═══╝ ██╔══██╗██║   ██║${NC}"
    echo -e "  ${PURPLE}   ██║  ██║███████╗███████╗    ██║     ██║  ██║╚██████╔╝${NC}"
    echo -e "  ${DIM}    ╚═╝  ╚═╝╚══════╝╚══════╝    ╚═╝     ╚═╝  ╚═╝ ╚═════╝ ${NC}"
    hr
    echo -e "  ${YELLOW}    ✦  PREMIUM TUNNELING PANEL  •  ALL-IN-ONE  ✦${NC}"
    hr
    echo ""
}

install_dependencies() {
    inf "Mengupdate package list & install dependencies..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq &>/dev/null
    apt-get install -y -qq \
        curl wget unzip zip tar git nano vim jq bc \
        net-tools dnsutils iptables iptables-persistent netfilter-persistent \
        openssl ca-certificates lsof cron rsyslog \
        socat netcat-openbsd uuid-runtime \
        python3 python3-pip \
        nginx certbot python3-certbot-nginx \
        dropbear stunnel4 fail2ban squid \
        screen tmux htop neofetch \
        sudo at &>/dev/null
    ok "Dependencies terpasang"
}


prep_dirs() {
    inf "Membuat direktori panel..."
    mkdir -p "$ALLPRO_DIR" "$XRAY_DIR" "$TROJAN_DIR" "$HYSTERIA_DIR" "$SLOWDNS_DIR"
    mkdir -p /var/log/allpro /usr/local/sbin
    touch "$ALLPRO_DIR"/{ssh,vmess,vless,trojan,trojango,hy2,slowdns}.db
    : > /etc/xray/users.db 2>/dev/null
    ok "Direktori dibuat: ${ALLPRO_DIR}"
}

input_config() {
    hr
    echo -e "  ${YELLOW}● KONFIGURASI AWAL${NC}"
    hr
    local sip
    sip=$(curl -s4 --max-time 8 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    echo -ne "  ${CYAN}Domain / Sub-domain${NC}     : "; read -r DOMAIN
    [[ -z "$DOMAIN" ]] && DOMAIN="$sip"
    echo -ne "  ${CYAN}Nama Brand / Toko${NC}       : "; read -r BRAND
    [[ -z "$BRAND" ]] && BRAND="ALL PRO"
    echo -ne "  ${CYAN}Username Telegram Admin${NC} : "; read -r ADMIN_TG
    [[ -z "$ADMIN_TG" ]] && ADMIN_TG="-"
    echo "$DOMAIN"   > "$ALLPRO_DIR/domain"
    echo "$sip"      > "$ALLPRO_DIR/ipvps"
    cat > "$ALLPRO_DIR/store.conf" <<EOF
BRAND=$BRAND
ADMIN_TG=$ADMIN_TG
DOMAIN=$DOMAIN
IP=$sip
EOF
    ok "Config tersimpan di ${ALLPRO_DIR}/store.conf"
}

install_bbr() {
    inf "Mengaktifkan BBR + UDP optimization..."
    modprobe tcp_bbr 2>/dev/null
    grep -q 'tcp_bbr' /etc/modules-load.d/modules.conf 2>/dev/null || \
        echo "tcp_bbr" >> /etc/modules-load.d/modules.conf

    # Bersihkan marker lama biar idempotent
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
    local cc; cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    if [[ "$cc" == "bbr" ]]; then
        ok "BBR aktif (Fair Queue + UDP buffer optimasi)"
    else
        warn "BBR belum aktif sepenuhnya — kernel mungkin perlu reboot"
    fi
}

install_ipv6_disable() {
    inf "Menonaktifkan IPv6 (anti-leak)..."

    # Bersihkan marker lama biar idempotent
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

    # Persistent via GRUB (efektif setelah reboot)
    if [[ -f /etc/default/grub ]] && ! grep -q 'ipv6.disable=1' /etc/default/grub; then
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 ipv6.disable=1"/' /etc/default/grub
        update-grub &>/dev/null
        inf "GRUB di-update (ipv6.disable=1) — efektif penuh setelah reboot"
    fi
    ok "IPv6 dinonaktifkan"
}


download_binaries() {
    hr
    echo -e "  ${YELLOW}● DOWNLOAD BINARIES${NC}"
    hr
    # Xray
    inf "Download Xray..."
    wget -qO /tmp/xray.zip "$XRAY_URL" || { err "Gagal download Xray"; return 1; }
    mkdir -p "$XRAY_DIR"
    unzip -qo /tmp/xray.zip -d /tmp/xray
    install -m 755 /tmp/xray/xray /usr/local/bin/xray
    rm -rf /tmp/xray /tmp/xray.zip
    ok "Xray: $(/usr/local/bin/xray version 2>/dev/null | head -1)"

    # Hysteria 2
    inf "Download Hysteria 2..."
    wget -qO /usr/local/bin/hysteria "$HYSTERIA_URL"
    chmod +x /usr/local/bin/hysteria
    ok "Hysteria 2 terpasang"

    # Trojan-Go
    inf "Download Trojan-Go..."
    wget -qO /tmp/trojan-go.zip "$TROJAN_GO_URL"
    unzip -qo /tmp/trojan-go.zip -d /tmp/trojan-go
    install -m 755 /tmp/trojan-go/trojan-go /usr/local/bin/trojan-go
    rm -rf /tmp/trojan-go /tmp/trojan-go.zip
    ok "Trojan-Go terpasang"

    # BadVPN UDPGW
    inf "Download BadVPN UDPGW..."
    wget -qO /usr/local/bin/badvpn-udpgw "$UDPGW_URL"
    chmod +x /usr/local/bin/badvpn-udpgw
    ok "BadVPN UDPGW terpasang"

    # SlowDNS server
    inf "Download SlowDNS..."
    wget -qO /usr/local/bin/sldns-server "$SLOWDNS_URL"
    chmod +x /usr/local/bin/sldns-server
    ok "SlowDNS terpasang"

    # OHP
    inf "Download OHP server..."
    wget -qO /usr/local/bin/ohpserver "$OHP_URL"
    chmod +x /usr/local/bin/ohpserver
    ok "OHP terpasang"

    # WS proxy
    inf "Download WebSocket proxy..."
    wget -qO /usr/local/bin/ws "$WS_URL"
    chmod +x /usr/local/bin/ws
    wget -qO /etc/systemd/system/ws.service "$WS_SERVICE_URL"
    ok "WS proxy terpasang"
}


fetch_modules() {
    hr
    echo -e "  ${YELLOW}● FETCH MODULES (menu & installers)${NC}"
    hr
    local files=(
        "menu/menu.sh:${MENU_DIR}/menu"
        "menu/menu-ssh.sh:${MENU_DIR}/menu-ssh"
        "menu/menu-xray.sh:${MENU_DIR}/menu-xray"
        "menu/menu-vmess.sh:${MENU_DIR}/menu-vmess"
        "menu/menu-vless.sh:${MENU_DIR}/menu-vless"
        "menu/menu-trojan.sh:${MENU_DIR}/menu-trojan"
        "menu/menu-trojango.sh:${MENU_DIR}/menu-trojango"
        "menu/menu-hy2.sh:${MENU_DIR}/menu-hy2"
        "menu/menu-slowdns.sh:${MENU_DIR}/menu-slowdns"
        "menu/menu-system.sh:${MENU_DIR}/menu-system"
        "menu/menu-bbr.sh:${MENU_DIR}/menu-bbr"
        "menu/menu-ipv6.sh:${MENU_DIR}/menu-ipv6"
        "menu/menu-backup.sh:${MENU_DIR}/menu-backup"
        "menu/menu-tema.sh:${MENU_DIR}/menu-tema"
        "menu/menu-about.sh:${MENU_DIR}/menu-about"
        "menu/menu-pengaturan.sh:${MENU_DIR}/menu-pengaturan"
        "menu/lib-common.sh:${ALLPRO_DIR}/lib-common.sh"
        "ssh/install-ssh.sh:/tmp/install-ssh.sh"
        "xray/install-xray.sh:/tmp/install-xray.sh"
        "trojan-go/install-trojango.sh:/tmp/install-trojango.sh"
        "hysteria2/install-hy2.sh:/tmp/install-hy2.sh"
        "other/install-slowdns.sh:/tmp/install-slowdns.sh"
        "other/install-fail2ban.sh:/tmp/install-fail2ban.sh"
        "other/uninstall.sh:${ALLPRO_DIR}/uninstall.sh"
        "other/clean-expired.sh:${ALLPRO_DIR}/clean-expired.sh"
    )
    for entry in "${files[@]}"; do
        local src="${entry%%:*}"
        local dst="${entry##*:}"
        inf "  fetch ${src} → ${dst}"
        wget -qO "$dst" "${REPO_BASE}/${src}" || warn "Gagal fetch ${src}"
    done
    chmod +x "${MENU_DIR}"/menu* /tmp/install-*.sh 2>/dev/null
    ok "Modules siap"
}

run_protocol_installers() {
    hr
    echo -e "  ${YELLOW}● INSTALL PROTOCOLS${NC}"
    hr
    [[ -x /tmp/install-ssh.sh       ]] && bash /tmp/install-ssh.sh
    [[ -x /tmp/install-xray.sh      ]] && bash /tmp/install-xray.sh
    [[ -x /tmp/install-trojango.sh  ]] && bash /tmp/install-trojango.sh
    [[ -x /tmp/install-hy2.sh       ]] && bash /tmp/install-hy2.sh
    [[ -x /tmp/install-slowdns.sh   ]] && bash /tmp/install-slowdns.sh
    [[ -x /tmp/install-fail2ban.sh  ]] && bash /tmp/install-fail2ban.sh
    chmod +x "${ALLPRO_DIR}/clean-expired.sh" "${ALLPRO_DIR}/uninstall.sh" 2>/dev/null
    # Daily cron - cleanup expired users
    (crontab -l 2>/dev/null | grep -v 'allpro/clean-expired' ; echo "5 0 * * * ${ALLPRO_DIR}/clean-expired.sh") | crontab -
    ok "Cron auto-cleanup expired terdaftar"
    ok "Semua protocol selesai diinstall"
}


finish() {
    hr
    echo -e "  ${GREEN}✦ ALL PRO PANEL BERHASIL DIINSTALL!${NC}"
    hr
    local ip; ip=$(cat "$ALLPRO_DIR/ipvps" 2>/dev/null)
    local domain; domain=$(cat "$ALLPRO_DIR/domain" 2>/dev/null)
    printf  "  ${DIM}IP VPS    :${NC}  ${WHITE}%s${NC}\n" "$ip"
    printf  "  ${DIM}Domain    :${NC}  ${WHITE}%s${NC}\n" "$domain"
    printf  "  ${DIM}Brand     :${NC}  ${YELLOW}%s${NC}\n" "$(grep ^BRAND= "$ALLPRO_DIR/store.conf" | cut -d= -f2-)"
    hr
    echo -e "  ${CYAN}Ketik ${YELLOW}menu${CYAN} untuk membuka panel ALL PRO${NC}"
    hr
    echo ""
    rm -f /tmp/install-*.sh
}

main() {
    check_root
    show_logo
    check_os
    install_dependencies
    prep_dirs
    input_config
    install_bbr
    install_ipv6_disable
    download_binaries
    fetch_modules
    run_protocol_installers
    finish
}

main "$@"
