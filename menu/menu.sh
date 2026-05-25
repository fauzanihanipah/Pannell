#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#   ALL PRO - Main Menu
# ═══════════════════════════════════════════════════════════════
source /etc/allpro/lib-common.sh

REPO_BASE="${REPO_BASE:-https://raw.githubusercontent.com/fauzanihanipah/Pannell/main}"

main_menu() {
    while true; do
        show_header
        echo ""
        _btn "          +-------------- ${AL}ALL PRO MAIN MENU${NC} --------------+"
        echo ""
        _sep
        _btn "  ${A2}[1]${NC}  🛡  SSH / OpenSSH        ${A1}│${NC}  ${A2}[2]${NC}  🔐  OpenVPN"
        _sep
        _btn "  ${A2}[3]${NC}  🟣  Xray (VMess/VL/TR)   ${A1}│${NC}  ${A2}[4]${NC}  ⚡  Trojan-Go"
        _sep
        _btn "  ${A2}[5]${NC}  🌐  WireGuard            ${A1}│${NC}  ${A2}[6]${NC}  🚀  Hysteria 2"
        _sep
        _btn "  ${A2}[7]${NC}  🌎  SlowDNS              ${A1}│${NC}  ${A2}[8]${NC}  ⚙  System Tools"
        _sep
        _btn "  ${A2}[9]${NC}  💾  Backup & Restore     ${A1}│${NC}  ${A2}[10]${NC} 🎨  Tema"
        _sep
        _btn "  ${A2}[11]${NC} ⚙   Pengaturan           ${A1}│${NC}  ${A2}[12]${NC} 🔄  Update Script"
        _sep
        _btn "  ${A2}[13]${NC} 📋  About                ${A1}│${NC}  ${A2}[14]${NC} 🔧  Install Ulang"
        _sep
        _btn "  ${LR}[E]${NC}  🗑  Uninstall            ${LR}[X]${NC}  ✖  Keluar"
        _sep
        echo ""
        _btn "          ${A4}✦  ALL PRO PANEL v1.0  ✦${NC}"
        echo ""
        echo -ne "  ${A1}›${NC} Pilih menu: "
        read -r ch
        case "$ch" in
            1)  menu-ssh        ;;
            2)  warn "OpenVPN module belum diinstall"; sleep 1 ;;
            3)  menu-xray       ;;
            4)  menu-trojango   ;;
            5)  warn "WireGuard module belum diinstall"; sleep 1 ;;
            6)  menu-hy2        ;;
            7)  menu-slowdns    ;;
            8)  menu-system     ;;
            9)  menu-backup     ;;
            10) menu-tema       ;;
            11) menu-pengaturan ;;
            12) bash <(curl -s "${REPO_BASE}/setup.sh") ;;
            13) menu-about      ;;
            14) bash <(curl -s "${REPO_BASE}/setup.sh") ;;
            E|e) bash /etc/allpro/uninstall.sh 2>/dev/null || warn "uninstall.sh tidak ditemukan" ;;
            X|x|0) clear; exit 0 ;;
            *)  warn "Pilihan tidak valid"; sleep 1 ;;
        esac
    done
}

main_menu
