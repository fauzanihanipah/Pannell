#!/bin/bash
# ALL PRO - VMess (Xray) User Manager
source /etc/allpro/lib-common.sh
DB="$ALLPRO_DIR/vmess.db"
CFG="/etc/xray/config.json"

vmess_add() {
    show_header
    _top; _btn "  ${IT}${AL}➕  TAMBAH AKUN VMESS${NC}"; _bot; echo ""
    echo -ne "  ${A3}Username${NC}            : "; read -r un
    [[ -z "$un" ]] && { err "Username kosong!"; pause; return; }
    grep -q "^${un}|" "$DB" 2>/dev/null && { err "User sudah ada!"; pause; return; }
    echo -ne "  ${A3}Masa aktif (hari)${NC} [30]: "; read -r dur; [[ -z "$dur" ]] && dur=30
    local exp; exp=$(date -d "+${dur} days" +"%Y-%m-%d")
    local uuid; uuid=$(rand_uuid)
    echo "${un}|${uuid}|${exp}" >> "$DB"

    # Inject ke Xray (TLS dan NTLS inbound)
    python3 <<PY
import json
with open("$CFG") as f: c=json.load(f)
for ib in c["inbounds"]:
    if ib["protocol"]=="vmess":
        ib["settings"]["clients"].append({"id":"$uuid","alterId":0,"email":"$un"})
with open("$CFG","w") as f: json.dump(c,f,indent=2)
PY
    systemctl restart xray
    local domain; domain=$(get_domain); local ip; ip=$(get_ip)
    local link_tls="vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"${un}-TLS\",\"add\":\"${domain}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${domain}\",\"path\":\"/vmess\",\"tls\":\"tls\"}" | base64 -w0)"
    local link_ntls="vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"${un}-NTLS\",\"add\":\"${domain}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${domain}\",\"path\":\"/vmess-ntls\",\"tls\":\"\"}" | base64 -w0)"
    show_header
    _top; _btn "  ${LG}✔  Akun VMess berhasil dibuat${NC}"; _bot
    _btn "  ${DIM}User${NC}      : ${W}$un${NC}"
    _btn "  ${DIM}UUID${NC}      : ${A3}$uuid${NC}"
    _btn "  ${DIM}Domain${NC}    : ${W}$domain${NC}"
    _btn "  ${DIM}TLS Port${NC}  : 443 (path /vmess)"
    _btn "  ${DIM}NTLS Port${NC} : 80  (path /vmess-ntls)"
    _btn "  ${DIM}Expired${NC}   : ${Y}$exp${NC}"
    _sep
    _btn "  ${DIM}Link TLS:${NC}"
    echo "  $link_tls"
    _btn "  ${DIM}Link NTLS (CDN):${NC}"
    echo "  $link_ntls"
    _bot; pause
}


vmess_list() {
    show_header
    _top; _btn "  ${IT}${AL}📋  LIST VMESS${NC}"; _bot; echo ""
    [[ ! -s "$DB" ]] && { warn "Belum ada akun"; pause; return; }
    printf  "  ${BLD}%-3s  %-16s  %-36s  %-12s${NC}\n" "#" "User" "UUID" "Expired"
    _sep
    local n=1
    while IFS='|' read -r u uuid e; do
        printf "  ${DIM}%-3s${NC}  ${W}%-16s${NC}  ${A3}%-36s${NC}  ${Y}%-12s${NC}\n" "$n" "$u" "$uuid" "$e"
        ((n++))
    done < "$DB"
    pause
}

vmess_del() {
    show_header
    _top; _btn "  ${IT}${AL}🗑  HAPUS VMESS${NC}"; _bot; echo ""
    [[ ! -s "$DB" ]] && { warn "Tidak ada akun"; pause; return; }
    awk -F'|' '{printf "  - %s (uuid: %s, exp: %s)\n",$1,$2,$3}' "$DB"
    echo ""
    echo -ne "  ${A3}Username${NC}: "; read -r du
    local uuid; uuid=$(grep "^${du}|" "$DB" | cut -d'|' -f2)
    [[ -z "$uuid" ]] && { err "User tidak ditemukan!"; pause; return; }
    sed -i "/^${du}|/d" "$DB"
    python3 <<PY
import json
with open("$CFG") as f: c=json.load(f)
for ib in c["inbounds"]:
    if ib["protocol"]=="vmess":
        ib["settings"]["clients"]=[x for x in ib["settings"]["clients"] if x.get("id")!="$uuid"]
with open("$CFG","w") as f: json.dump(c,f,indent=2)
PY
    systemctl restart xray
    ok "User '$du' dihapus"; pause
}

vmess_renew() {
    show_header
    _top; _btn "  ${IT}${AL}🔁  PERPANJANG VMESS${NC}"; _bot; echo ""
    echo -ne "  ${A3}Username${NC}: "; read -r ru
    grep -q "^${ru}|" "$DB" || { err "User tidak ditemukan!"; pause; return; }
    echo -ne "  ${A3}Tambah hari${NC}: "; read -r d; [[ -z "$d" ]] && d=30
    local ce; ce=$(grep "^${ru}|" "$DB" | cut -d'|' -f3)
    local today; today=$(date +%Y-%m-%d)
    [[ "$ce" < "$today" ]] && ce="$today"
    local ne; ne=$(date -d "${ce} +${d} days" +"%Y-%m-%d")
    sed -i "s/^\(${ru}|[^|]*|\)[^|]*/\1${ne}/" "$DB"
    ok "Diperpanjang sampai $ne"
    pause
}

while true; do
    show_header
    _top; _btn "  ${IT}${AL}🟣  VMESS MENU (Xray WS TLS/NTLS)${NC}"; _bot
    _btn "  ${A2}[1]${NC}  ➕  Tambah"
    _btn "  ${A2}[2]${NC}  📋  List"
    _btn "  ${A2}[3]${NC}  🗑  Hapus"
    _btn "  ${A2}[4]${NC}  🔁  Perpanjang"
    _btn "  ${LR}[0]${NC}  ◀   Kembali"
    _bot
    echo -ne "  ${A1}›${NC} "; read -r ch
    case "$ch" in
        1) vmess_add ;; 2) vmess_list ;; 3) vmess_del ;; 4) vmess_renew ;;
        0) break ;; *) warn "Invalid"; sleep 1 ;;
    esac
done
