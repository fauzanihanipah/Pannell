#!/bin/bash
# ALL PRO - Hysteria 2 User Manager
source /etc/allpro/lib-common.sh
DB="$ALLPRO_DIR/hy2.db"
CFG="/etc/hysteria/config.yaml"

hy2_add() {
    show_header; _top; _btn "  ${IT}${AL}➕  TAMBAH AKUN HYSTERIA 2${NC}"; _bot
    echo -ne "  ${A3}Username${NC}: "; read -r un
    grep -q "^${un}|" "$DB" 2>/dev/null && { err "Ada"; pause; return; }
    echo -ne "  ${A3}Hari${NC} [30]: "; read -r d; [[ -z "$d" ]] && d=30
    local exp; exp=$(date -d "+${d} days" +"%Y-%m-%d")
    local pwd; pwd=$(rand_uuid)
    echo "${un}|${pwd}|${exp}" >> "$DB"
    # Update config.yaml: gunakan multi-password mode
    python3 <<PY
import sys, re
with open("$CFG") as f: c=f.read()
# convert single password ke userpass jika belum
if "userpass" not in c:
    # build userpass dari DB
    pass
PY
    # Simple approach: pakai mode userpass
    local userpass=""
    while IFS='|' read -r u p e; do
        userpass+="    $u: $p"$'\n'
    done < "$DB"
    cat > "$CFG" <<EOF
listen: :8443
tls:
  cert: /etc/hysteria/server.crt
  key:  /etc/hysteria/server.key
auth:
  type: userpass
  userpass:
$userpass
masquerade:
  type: proxy
  proxy:
    url: https://www.bing.com
    rewriteHost: true
EOF
    systemctl restart hysteria-server
    local domain; domain=$(get_domain)
    local link="hysteria2://${un}:${pwd}@${domain}:8443?insecure=1&sni=${domain}#${un}"
    show_header
    _top; _btn "  ${LG}✔  Hysteria 2 user dibuat${NC}"; _bot
    _btn "  ${DIM}User${NC}     : ${W}$un${NC}"
    _btn "  ${DIM}Password${NC} : ${A3}$pwd${NC}"
    _btn "  ${DIM}Domain${NC}   : ${W}$domain${NC}"
    _btn "  ${DIM}Port UDP${NC} : 8443  (range 20000-50000)"
    _btn "  ${DIM}Expired${NC}  : ${Y}$exp${NC}"
    _sep
    echo "  $link"
    _bot; pause
}


hy2_list() {
    show_header; _top; _btn "  ${IT}${AL}📋  LIST HYSTERIA 2${NC}"; _bot
    [[ ! -s "$DB" ]] && { warn "Kosong"; pause; return; }
    awk -F'|' '{printf "  - %s | %s | %s\n",$1,$2,$3}' "$DB"; pause
}

hy2_del() {
    show_header; _top; _btn "  ${IT}${AL}🗑  HAPUS HYSTERIA 2${NC}"; _bot
    awk -F'|' '{printf "  - %s\n",$1}' "$DB"
    echo -ne "  ${A3}Username${NC}: "; read -r du
    grep -q "^${du}|" "$DB" || { err "Tidak ada"; pause; return; }
    sed -i "/^${du}|/d" "$DB"
    # rebuild yaml
    local userpass=""
    while IFS='|' read -r u p e; do
        userpass+="    $u: $p"$'\n'
    done < "$DB"
    cat > "$CFG" <<EOF
listen: :8443
tls:
  cert: /etc/hysteria/server.crt
  key:  /etc/hysteria/server.key
auth:
  type: userpass
  userpass:
$userpass
masquerade:
  type: proxy
  proxy:
    url: https://www.bing.com
    rewriteHost: true
EOF
    systemctl restart hysteria-server
    ok "Dihapus"; pause
}

hy2_renew() {
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
    _top; _btn "  ${IT}${AL}🚀  HYSTERIA 2 MENU${NC}"; _bot
    _btn "  ${A2}[1]${NC}  ➕  Tambah     ${A2}[2]${NC}  📋  List"
    _btn "  ${A2}[3]${NC}  🗑  Hapus       ${A2}[4]${NC}  🔁  Perpanjang"
    _btn "  ${LR}[0]${NC}  ◀   Kembali"
    _bot
    echo -ne "  ${A1}›${NC} "; read -r ch
    case "$ch" in
        1) hy2_add;; 2) hy2_list;; 3) hy2_del;; 4) hy2_renew;;
        0) break;; *) warn "Invalid"; sleep 1;;
    esac
done
