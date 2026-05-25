#!/bin/bash
# ALL PRO - Backup & Restore
source /etc/allpro/lib-common.sh
BAKDIR="/root/allpro-backups"
mkdir -p "$BAKDIR"

bk_create() {
    show_header
    _top; _btn "  ${IT}${AL}📦  BUAT BACKUP${NC}"; _bot
    local f="$BAKDIR/allpro-$(date +%Y%m%d-%H%M%S).tar.gz"
    tar -czPf "$f" \
        /etc/allpro \
        /etc/xray \
        /etc/trojan-go \
        /etc/hysteria \
        /etc/slowdns \
        /etc/stunnel \
        /etc/nginx/conf.d 2>/dev/null
    local sz; sz=$(du -sh "$f" | cut -f1)
    ok "Backup: $f ($sz)"
    pause
}

bk_list() {
    show_header
    _top; _btn "  ${IT}${AL}📋  DAFTAR BACKUP${NC}"; _bot
    ls -lhS "$BAKDIR"/*.tar.gz 2>/dev/null | awk '{print "  "$NF" ("$5")"}' || warn "Kosong"
    pause
}

bk_restore() {
    show_header
    _top; _btn "  ${IT}${AL}♻  RESTORE BACKUP${NC}"; _bot
    ls -1 "$BAKDIR"/*.tar.gz 2>/dev/null | nl
    echo -ne "  ${A3}Path file backup${NC}: "; read -r f
    [[ ! -f "$f" ]] && { err "File tidak ada"; pause; return; }
    tar -xzPf "$f"
    systemctl restart ssh dropbear stunnel4 nginx xray trojan-go hysteria-server slowdns ws 2>/dev/null
    ok "Restore selesai"; pause
}

bk_del() {
    show_header
    _top; _btn "  ${IT}${AL}🗑  HAPUS BACKUP${NC}"; _bot
    ls -1 "$BAKDIR"/*.tar.gz 2>/dev/null
    echo -ne "  ${A3}Nama file (atau 'all')${NC}: "; read -r f
    if [[ "$f" == "all" ]]; then
        rm -f "$BAKDIR"/*.tar.gz; ok "Semua dihapus"
    else
        rm -f "$BAKDIR/$f" && ok "Dihapus" || err "Gagal"
    fi
    pause
}

while true; do
    show_header
    _top; _btn "  ${IT}${AL}💾  BACKUP & RESTORE${NC}"; _bot
    _btn "  ${A2}[1]${NC}  📦  Buat Backup"
    _btn "  ${A2}[2]${NC}  📋  List Backup"
    _btn "  ${A2}[3]${NC}  ♻  Restore"
    _btn "  ${A2}[4]${NC}  🗑  Hapus"
    _btn "  ${LR}[0]${NC}  ◀   Kembali"
    _bot
    echo -ne "  ${A1}›${NC} "; read -r ch
    case "$ch" in
        1) bk_create;; 2) bk_list;; 3) bk_restore;; 4) bk_del;;
        0) break;; *) warn "Invalid"; sleep 1;;
    esac
done
