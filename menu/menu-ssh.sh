#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#   ALL PRO - SSH / OpenSSH User Manager
# ═══════════════════════════════════════════════════════════════
source /etc/allpro/lib-common.sh
SDB="$ALLPRO_DIR/ssh.db"

ssh_add() {
    show_header
    _top; _btn "  ${IT}${AL}➕  TAMBAH AKUN SSH${NC}"; _bot; echo ""
    echo -ne "  ${A3}Username${NC}            : "; read -r un
    [[ -z "$un" ]] && { err "Username kosong!"; pause; return; }
    id -u "$un" &>/dev/null && { err "User '$un' sudah ada!"; pause; return; }
    echo -ne "  ${A3}Password${NC} [auto]      : "; read -r pw
    [[ -z "$pw" ]] && pw=$(rand_pass)
    echo -ne "  ${A3}Masa aktif (hari)${NC} [30]: "; read -r dur
    [[ -z "$dur" ]] && dur=30
    local exp; exp=$(date -d "+${dur} days" +"%Y-%m-%d")
    useradd -e "$exp" -s /bin/false -M "$un"
    echo -e "$pw\n$pw" | passwd "$un" &>/dev/null
    echo "${un}|${pw}|${exp}" >> "$SDB"

    local domain; domain=$(get_domain)
    local ip;     ip=$(get_ip)
    show_header
    _top; _btn "  ${LG}✔  Akun SSH berhasil dibuat${NC}"; _bot
    _btn "  ${DIM}Username${NC}        : ${W}$un${NC}"
    _btn "  ${DIM}Password${NC}        : ${A3}$pw${NC}"
    _btn "  ${DIM}IP / Domain${NC}     : ${W}$domain${NC}"
    _btn "  ${DIM}OpenSSH${NC}         : 22, 442"
    _btn "  ${DIM}Dropbear${NC}        : 109, 143"
    _btn "  ${DIM}SSL/TLS${NC}         : 443, 777"
    _btn "  ${DIM}SSH WS NTLS${NC}     : 80   (CDN /ssh-ws)"
    _btn "  ${DIM}SSH WS TLS${NC}      : 443  (CDN /ssh-ws)"
    _btn "  ${DIM}OHP HTTP/SSL${NC}    : 8080 / 8443"
    _btn "  ${DIM}BadVPN UDPGW${NC}    : 7100, 7200, 7300"
    _btn "  ${DIM}Expired${NC}         : ${Y}$exp${NC}"
    _bot; pause
}


ssh_list() {
    show_header
    _top; _btn "  ${IT}${AL}📋  LIST AKUN SSH${NC}"; _bot; echo ""
    [[ ! -s "$SDB" ]] && { warn "Belum ada akun SSH"; pause; return; }
    local n=1
    printf  "  ${BLD} %-3s  %-16s  %-12s  %-12s${NC}\n" "#" "Username" "Password" "Expired"
    _sep
    while IFS='|' read -r u p e; do
        printf "  ${DIM}%3s${NC}  ${W}%-16s${NC}  ${A3}%-12s${NC}  ${Y}%-12s${NC}\n" "$n" "$u" "$p" "$e"
        ((n++))
    done < "$SDB"
    _sep
    pause
}

ssh_del() {
    show_header
    _top; _btn "  ${IT}${AL}🗑   HAPUS AKUN SSH${NC}"; _bot; echo ""
    [[ ! -s "$SDB" ]] && { warn "Tidak ada akun"; pause; return; }
    awk -F'|' '{printf "  - %s (exp: %s)\n",$1,$3}' "$SDB"
    echo ""
    echo -ne "  ${A3}Username yang dihapus${NC}: "; read -r du
    grep -q "^${du}|" "$SDB" || { err "User tidak ditemukan!"; pause; return; }
    userdel -f "$du" &>/dev/null
    sed -i "/^${du}|/d" "$SDB"
    ok "User '$du' dihapus"
    pause
}

ssh_renew() {
    show_header
    _top; _btn "  ${IT}${AL}🔁  PERPANJANG AKUN SSH${NC}"; _bot; echo ""
    echo -ne "  ${A3}Username${NC}    : "; read -r ru
    grep -q "^${ru}|" "$SDB" || { err "User tidak ditemukan!"; pause; return; }
    echo -ne "  ${A3}Tambah hari${NC} : "; read -r days; [[ -z "$days" ]] && days=30
    local ce; ce=$(grep "^${ru}|" "$SDB" | cut -d'|' -f3)
    local today; today=$(date +%Y-%m-%d)
    [[ "$ce" < "$today" ]] && ce="$today"
    local ne; ne=$(date -d "${ce} +${days} days" +"%Y-%m-%d")
    sed -i "s/^\(${ru}|[^|]*|\)[^|]*/\1${ne}/" "$SDB"
    chage -E "$ne" "$ru" 2>/dev/null
    ok "User '$ru' diperpanjang sampai $ne"
    pause
}


ssh_trial() {
    show_header
    _top; _btn "  ${IT}${AL}🎁  AKUN TRIAL SSH${NC}"; _bot; echo ""
    local un="trial$(tr -dc 'a-z0-9' </dev/urandom | head -c 4)"
    local pw; pw=$(rand_pass)
    local exp; exp=$(date -d "+1 day" +"%Y-%m-%d")
    useradd -e "$exp" -s /bin/false -M "$un"
    echo -e "$pw\n$pw" | passwd "$un" &>/dev/null
    echo "${un}|${pw}|${exp}" >> "$SDB"
    local domain; domain=$(get_domain)
    _btn "  ${DIM}Username${NC}    : ${W}$un${NC}"
    _btn "  ${DIM}Password${NC}    : ${A3}$pw${NC}"
    _btn "  ${DIM}Domain/IP${NC}   : ${W}$domain${NC}"
    _btn "  ${DIM}Expired${NC}     : ${Y}$exp${NC} (1 hari)"
    pause
}

ssh_clean() {
    show_header
    _top; _btn "  ${IT}${AL}🧹  HAPUS AKUN EXPIRED${NC}"; _bot; echo ""
    local today; today=$(date +%Y-%m-%d); local cnt=0
    while IFS='|' read -r u p e; do
        if [[ "$e" < "$today" ]]; then
            userdel -f "$u" &>/dev/null
            sed -i "/^${u}|/d" "$SDB"
            ok "Dihapus: $u (exp: $e)"; ((cnt++))
        fi
    done < <(cat "$SDB" 2>/dev/null)
    [[ $cnt -eq 0 ]] && inf "Tidak ada akun expired"
    pause
}

while true; do
    show_header
    _top; _btn "  ${IT}${AL}🛡   SSH / OPENSSH MENU${NC}"; _bot
    _btn "  ${A2}[1]${NC}  ➕  Tambah Akun"
    _btn "  ${A2}[2]${NC}  📋  List Akun"
    _btn "  ${A2}[3]${NC}  🗑  Hapus Akun"
    _btn "  ${A2}[4]${NC}  🔁  Perpanjang Akun"
    _btn "  ${A2}[5]${NC}  🎁  Akun Trial"
    _btn "  ${A2}[6]${NC}  🧹  Hapus Expired"
    _btn "  ${LR}[0]${NC}  ◀   Kembali"
    _bot
    echo -ne "  ${A1}›${NC} "; read -r ch
    case "$ch" in
        1) ssh_add ;;
        2) ssh_list ;;
        3) ssh_del ;;
        4) ssh_renew ;;
        5) ssh_trial ;;
        6) ssh_clean ;;
        0) break ;;
        *) warn "Pilihan tidak valid"; sleep 1 ;;
    esac
done
