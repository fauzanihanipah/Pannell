#!/bin/bash
# ALL PRO - VLess (Xray) User Manager
source /etc/allpro/lib-common.sh
DB="$ALLPRO_DIR/vless.db"
CFG="/etc/xray/config.json"

vless_add() {
    show_header
    _top; _btn "  ${IT}${AL}➕  TAMBAH AKUN VLESS${NC}"; _bot; echo ""
    echo -ne "  ${A3}Username${NC}: "; read -r un
    [[ -z "$un" ]] && { err "Kosong!"; pause; return; }
    grep -q "^${un}|" "$DB" 2>/dev/null && { err "User sudah ada!"; pause; return; }
    echo -ne "  ${A3}Hari${NC} [30]: "; read -r dur; [[ -z "$dur" ]] && dur=30
    local exp; exp=$(date -d "+${dur} days" +"%Y-%m-%d")
    local uuid; uuid=$(rand_uuid)
    echo "${un}|${uuid}|${exp}" >> "$DB"
    python3 <<PY
import json
with open("$CFG") as f: c=json.load(f)
for ib in c["inbounds"]:
    if ib["protocol"]=="vless":
        ib["settings"]["clients"].append({"id":"$uuid","email":"$un"})
with open("$CFG","w") as f: json.dump(c,f,indent=2)
PY
    systemctl restart xray
    local domain; domain=$(get_domain)
    local lt="vless://${uuid}@${domain}:443?path=/vless&security=tls&encryption=none&host=${domain}&type=ws&sni=${domain}#${un}-TLS"
    local ln="vless://${uuid}@${domain}:80?path=/vless-ntls&encryption=none&host=${domain}&type=ws#${un}-NTLS"
    show_header
    _top; _btn "  ${LG}✔  Akun VLess berhasil dibuat${NC}"; _bot
    _btn "  ${DIM}User${NC}      : ${W}$un${NC}"
    _btn "  ${DIM}UUID${NC}      : ${A3}$uuid${NC}"
    _btn "  ${DIM}Domain${NC}    : ${W}$domain${NC}"
    _btn "  ${DIM}TLS  443${NC}  : path /vless"
    _btn "  ${DIM}NTLS 80 ${NC}  : path /vless-ntls (CDN)"
    _btn "  ${DIM}Expired${NC}   : ${Y}$exp${NC}"
    _sep
    _btn "  ${DIM}Link TLS:${NC}";  echo "  $lt"
    _btn "  ${DIM}Link NTLS:${NC}"; echo "  $ln"
    _bot; pause
}


vless_list() {
    show_header
    _top; _btn "  ${IT}${AL}📋  LIST VLESS${NC}"; _bot
    [[ ! -s "$DB" ]] && { warn "Kosong"; pause; return; }
    awk -F'|' '{printf "  - %s | %s | exp:%s\n",$1,$2,$3}' "$DB"
    pause
}

vless_del() {
    show_header
    _top; _btn "  ${IT}${AL}🗑  HAPUS VLESS${NC}"; _bot
    [[ ! -s "$DB" ]] && { warn "Kosong"; pause; return; }
    awk -F'|' '{printf "  - %s\n",$1}' "$DB"
    echo -ne "  ${A3}Username${NC}: "; read -r du
    local uuid; uuid=$(grep "^${du}|" "$DB" | cut -d'|' -f2)
    [[ -z "$uuid" ]] && { err "Tidak ada"; pause; return; }
    sed -i "/^${du}|/d" "$DB"
    python3 <<PY
import json
with open("$CFG") as f: c=json.load(f)
for ib in c["inbounds"]:
    if ib["protocol"]=="vless":
        ib["settings"]["clients"]=[x for x in ib["settings"]["clients"] if x.get("id")!="$uuid"]
with open("$CFG","w") as f: json.dump(c,f,indent=2)
PY
    systemctl restart xray
    ok "Dihapus"; pause
}

vless_renew() {
    show_header
    _top; _btn "  ${IT}${AL}🔁  PERPANJANG VLESS${NC}"; _bot
    echo -ne "  ${A3}Username${NC}: "; read -r ru
    grep -q "^${ru}|" "$DB" || { err "Tidak ada"; pause; return; }
    echo -ne "  ${A3}Hari${NC}: "; read -r d; [[ -z "$d" ]] && d=30
    local ce; ce=$(grep "^${ru}|" "$DB" | cut -d'|' -f3)
    local today; today=$(date +%Y-%m-%d)
    [[ "$ce" < "$today" ]] && ce="$today"
    local ne; ne=$(date -d "${ce} +${d} days" +"%Y-%m-%d")
    sed -i "s/^\(${ru}|[^|]*|\)[^|]*/\1${ne}/" "$DB"
    ok "Sampai $ne"; pause
}

while true; do
    show_header
    _top; _btn "  ${IT}${AL}🟣  VLESS MENU${NC}"; _bot
    _btn "  ${A2}[1]${NC}  ➕  Tambah     ${A2}[2]${NC}  📋  List"
    _btn "  ${A2}[3]${NC}  🗑  Hapus       ${A2}[4]${NC}  🔁  Perpanjang"
    _btn "  ${LR}[0]${NC}  ◀   Kembali"
    _bot
    echo -ne "  ${A1}›${NC} "; read -r ch
    case "$ch" in
        1) vless_add;; 2) vless_list;; 3) vless_del;; 4) vless_renew;;
        0) break;; *) warn "Invalid"; sleep 1;;
    esac
done
