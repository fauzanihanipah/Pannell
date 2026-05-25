#!/bin/bash
# ALL PRO - Trojan (Xray) User Manager - WS TLS + gRPC
source /etc/allpro/lib-common.sh
DB="$ALLPRO_DIR/trojan.db"
CFG="/etc/xray/config.json"

trojan_add() {
    show_header
    _top; _btn "  ${IT}${AL}➕  TAMBAH AKUN TROJAN${NC}"; _bot; echo ""
    echo -ne "  ${A3}Username${NC}: "; read -r un
    [[ -z "$un" ]] && { err "Kosong!"; pause; return; }
    grep -q "^${un}|" "$DB" 2>/dev/null && { err "Ada"; pause; return; }
    echo -ne "  ${A3}Hari${NC} [30]: "; read -r dur; [[ -z "$dur" ]] && dur=30
    local exp; exp=$(date -d "+${dur} days" +"%Y-%m-%d")
    local pwd; pwd=$(rand_uuid)
    echo "${un}|${pwd}|${exp}" >> "$DB"
    python3 <<PY
import json
with open("$CFG") as f: c=json.load(f)
for ib in c["inbounds"]:
    if ib["protocol"]=="trojan":
        ib["settings"]["clients"].append({"password":"$pwd","email":"$un"})
with open("$CFG","w") as f: json.dump(c,f,indent=2)
PY
    systemctl restart xray
    local domain; domain=$(get_domain)
    local lws="trojan://${pwd}@${domain}:443?path=/trojan-ws&security=tls&host=${domain}&type=ws&sni=${domain}#${un}-WS"
    local lgrpc="trojan://${pwd}@${domain}:443?mode=gun&security=tls&type=grpc&serviceName=trojan-grpc&sni=${domain}#${un}-gRPC"
    show_header
    _top; _btn "  ${LG}✔  Akun Trojan berhasil dibuat${NC}"; _bot
    _btn "  ${DIM}User${NC}     : ${W}$un${NC}"
    _btn "  ${DIM}Password${NC} : ${A3}$pwd${NC}"
    _btn "  ${DIM}Domain${NC}   : ${W}$domain${NC}"
    _btn "  ${DIM}WS Path${NC}  : 443  /trojan-ws"
    _btn "  ${DIM}gRPC SVC${NC} : 443  trojan-grpc"
    _btn "  ${DIM}Expired${NC}  : ${Y}$exp${NC}"
    _sep
    _btn "  ${DIM}WS:${NC}";   echo "  $lws"
    _btn "  ${DIM}gRPC:${NC}"; echo "  $lgrpc"
    _bot; pause
}


trojan_list() {
    show_header; _top; _btn "  ${IT}${AL}📋  LIST TROJAN${NC}"; _bot
    [[ ! -s "$DB" ]] && { warn "Kosong"; pause; return; }
    awk -F'|' '{printf "  - %s | %s | exp:%s\n",$1,$2,$3}' "$DB"
    pause
}

trojan_del() {
    show_header; _top; _btn "  ${IT}${AL}🗑  HAPUS TROJAN${NC}"; _bot
    awk -F'|' '{printf "  - %s\n",$1}' "$DB"
    echo -ne "  ${A3}Username${NC}: "; read -r du
    local pwd; pwd=$(grep "^${du}|" "$DB" | cut -d'|' -f2)
    [[ -z "$pwd" ]] && { err "Tidak ada"; pause; return; }
    sed -i "/^${du}|/d" "$DB"
    python3 <<PY
import json
with open("$CFG") as f: c=json.load(f)
for ib in c["inbounds"]:
    if ib["protocol"]=="trojan":
        ib["settings"]["clients"]=[x for x in ib["settings"]["clients"] if x.get("password")!="$pwd"]
with open("$CFG","w") as f: json.dump(c,f,indent=2)
PY
    systemctl restart xray
    ok "Dihapus"; pause
}

trojan_renew() {
    show_header; _top; _btn "  ${IT}${AL}🔁  PERPANJANG${NC}"; _bot
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
    _top; _btn "  ${IT}${AL}🟣  TROJAN MENU${NC}"; _bot
    _btn "  ${A2}[1]${NC}  ➕  Tambah     ${A2}[2]${NC}  📋  List"
    _btn "  ${A2}[3]${NC}  🗑  Hapus       ${A2}[4]${NC}  🔁  Perpanjang"
    _btn "  ${LR}[0]${NC}  ◀   Kembali"
    _bot
    echo -ne "  ${A1}›${NC} "; read -r ch
    case "$ch" in
        1) trojan_add;; 2) trojan_list;; 3) trojan_del;; 4) trojan_renew;;
        0) break;; *) warn "Invalid"; sleep 1;;
    esac
done
