#!/bin/bash
# ALL PRO - Trojan-Go User Manager
source /etc/allpro/lib-common.sh
DB="$ALLPRO_DIR/trojango.db"
CFG="/etc/trojan-go/config.json"

tg_add() {
    show_header; _top; _btn "  ${IT}${AL}➕  TAMBAH AKUN TROJAN-GO${NC}"; _bot
    echo -ne "  ${A3}Username${NC}: "; read -r un
    grep -q "^${un}|" "$DB" 2>/dev/null && { err "Ada"; pause; return; }
    echo -ne "  ${A3}Hari${NC} [30]: "; read -r d; [[ -z "$d" ]] && d=30
    local exp; exp=$(date -d "+${d} days" +"%Y-%m-%d")
    local pwd; pwd=$(rand_uuid)
    echo "${un}|${pwd}|${exp}" >> "$DB"
    python3 <<PY
import json
with open("$CFG") as f: c=json.load(f)
c["password"].append("$pwd")
with open("$CFG","w") as f: json.dump(c,f,indent=2)
PY
    systemctl restart trojan-go
    local domain; domain=$(get_domain)
    local link="trojan-go://${pwd}@${domain}:2087/?sni=${domain}&type=ws&path=%2Ftrojango-ws&host=${domain}#${un}"
    show_header
    _top; _btn "  ${LG}✔  Trojan-Go user dibuat${NC}"; _bot
    _btn "  ${DIM}User${NC}     : ${W}$un${NC}"
    _btn "  ${DIM}Password${NC} : ${A3}$pwd${NC}"
    _btn "  ${DIM}Domain${NC}   : ${W}$domain${NC}"
    _btn "  ${DIM}Port${NC}     : 2087"
    _btn "  ${DIM}Path WS${NC}  : /trojango-ws"
    _btn "  ${DIM}Expired${NC}  : ${Y}$exp${NC}"
    _sep
    echo "  $link"
    _bot; pause
}

tg_list() { show_header; _top; _btn "  ${IT}${AL}📋  LIST TROJAN-GO${NC}"; _bot
    [[ ! -s "$DB" ]] && { warn "Kosong"; pause; return; }
    awk -F'|' '{printf "  - %s | %s | %s\n",$1,$2,$3}' "$DB"; pause; }

tg_del() { show_header; _top; _btn "  ${IT}${AL}🗑  HAPUS${NC}"; _bot
    awk -F'|' '{printf "  - %s\n",$1}' "$DB"
    echo -ne "  ${A3}Username${NC}: "; read -r du
    local pwd; pwd=$(grep "^${du}|" "$DB" | cut -d'|' -f2)
    [[ -z "$pwd" ]] && { err "Tidak ada"; pause; return; }
    sed -i "/^${du}|/d" "$DB"
    python3 <<PY
import json
with open("$CFG") as f: c=json.load(f)
c["password"]=[p for p in c["password"] if p!="$pwd"]
with open("$CFG","w") as f: json.dump(c,f,indent=2)
PY
    systemctl restart trojan-go; ok "Dihapus"; pause; }

while true; do
    show_header
    _top; _btn "  ${IT}${AL}⚡  TROJAN-GO MENU${NC}"; _bot
    _btn "  ${A2}[1]${NC}  ➕  Tambah     ${A2}[2]${NC}  📋  List"
    _btn "  ${A2}[3]${NC}  🗑  Hapus       ${LR}[0]${NC}  ◀   Kembali"
    _bot
    echo -ne "  ${A1}›${NC} "; read -r ch
    case "$ch" in
        1) tg_add;; 2) tg_list;; 3) tg_del;;
        0) break;; *) warn "Invalid"; sleep 1;;
    esac
done
