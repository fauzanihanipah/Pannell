#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#   ALL PRO - Common Library (sourced by every menu)
# ═══════════════════════════════════════════════════════════════

# ── COLORS / THEME ─────────────────────────────────────────
ALLPRO_DIR="/etc/allpro"
THEMEF="$ALLPRO_DIR/theme"
mkdir -p "$ALLPRO_DIR"
[[ ! -f "$THEMEF" ]] && echo "1" > "$THEMEF"

load_theme() {
    local t; t=$(cat "$THEMEF" 2>/dev/null || echo 1)
    case "$t" in
        2)  A1='\033[38;5;51m';  A2='\033[1;36m';     A3='\033[0;36m';
            A4='\033[38;5;123m'; AL='\033[38;5;87m';  THEME_NAME="ARCTIC CYAN" ;;
        3)  A1='\033[38;5;46m';  A2='\033[1;32m';     A3='\033[38;5;40m';
            A4='\033[38;5;118m'; AL='\033[38;5;82m';  THEME_NAME="MATRIX GREEN" ;;
        4)  A1='\033[38;5;220m'; A2='\033[38;5;226m'; A3='\033[38;5;214m';
            A4='\033[38;5;208m'; AL='\033[38;5;228m'; THEME_NAME="ROYAL GOLD" ;;
        5)  A1='\033[38;5;196m'; A2='\033[1;31m';     A3='\033[38;5;203m';
            A4='\033[38;5;197m'; AL='\033[38;5;204m'; THEME_NAME="CRIMSON RED" ;;
        6)  A1='\033[38;5;213m'; A2='\033[38;5;218m'; A3='\033[38;5;219m';
            A4='\033[38;5;211m'; AL='\033[38;5;225m'; THEME_NAME="SAKURA PINK" ;;
        7)  A1='\033[38;5;27m';  A2='\033[38;5;33m';  A3='\033[38;5;39m';
            A4='\033[38;5;45m';  AL='\033[38;5;81m';  THEME_NAME="OCEAN BLUE" ;;
        *)  A1='\033[38;5;135m'; A2='\033[1;35m';     A3='\033[38;5;141m';
            A4='\033[1;33m';     AL='\033[38;5;141m'; THEME_NAME="VIOLET" ;;
    esac
    NC='\033[0m'; BLD='\033[1m'; DIM='\033[2m'; IT='\033[3m'
    W='\033[1;37m'; LG='\033[1;32m'; LR='\033[1;31m'; LC='\033[1;36m'; Y='\033[1;33m'
}


# ── HELPERS ────────────────────────────────────────────────
_DASH="─────────────────────────────────────────────────────────"
_top()  { echo -e "  ${A1}${_DASH}${NC}"; }
_bot()  { echo -e "  ${A1}${_DASH}${NC}"; }
_sep()  { echo -e "  ${A1}${_DASH}${NC}"; }
_btn()  { printf "  %b\n" "$1"; }
ok()    { echo -e "  ${LG}✔${NC}  $*"; }
inf()   { echo -e "  ${A3}➜${NC}  $*"; }
warn()  { echo -e "  ${A4}⚠${NC}  $*"; }
err()   { echo -e "  ${LR}✘${NC}  $*"; }
pause() { echo ""; echo -ne "  ${DIM}╰─ [ Enter ] kembali ke menu...${NC}"; read -r; }

# ── SYSTEM INFO ────────────────────────────────────────────
get_ip()      { cat "$ALLPRO_DIR/ipvps" 2>/dev/null || curl -s4 --max-time 5 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}'; }
get_domain()  { cat "$ALLPRO_DIR/domain" 2>/dev/null || get_ip; }
get_brand()   { grep ^BRAND= "$ALLPRO_DIR/store.conf" 2>/dev/null | cut -d= -f2- || echo "ALL PRO"; }
rand_pass()   { tr -dc 'A-Za-z0-9' </dev/urandom | head -c 12; }
rand_uuid()   { cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen; }

# ── SERVICE CHECKERS ───────────────────────────────────────
sv_ssh()    { systemctl is-active --quiet ssh    && echo "●" || echo "○"; }
sv_dropb()  { systemctl is-active --quiet dropbear && echo "●" || echo "○"; }
sv_stunn()  { systemctl is-active --quiet stunnel4 && echo "●" || echo "○"; }
sv_xray()   { systemctl is-active --quiet xray   && echo "●" || echo "○"; }
sv_trojan() { systemctl is-active --quiet trojan-go && echo "●" || echo "○"; }
sv_hy2()    { systemctl is-active --quiet hysteria-server && echo "●" || echo "○"; }
sv_ws()     { systemctl is-active --quiet ws     && echo "●" || echo "○"; }
sv_nginx()  { systemctl is-active --quiet nginx  && echo "●" || echo "○"; }
sv_slowdns(){ systemctl is-active --quiet slowdns && echo "●" || echo "○"; }


# ── LOGO ───────────────────────────────────────────────────
draw_logo() {
    echo ""
    _top
    echo -e "  ${AL}${BLD}    █████╗ ██╗     ██╗         ██████╗ ██████╗  ██████╗ ${NC}"
    echo -e "  ${AL}${BLD}   ██╔══██╗██║     ██║         ██╔══██╗██╔══██╗██╔═══██╗${NC}"
    echo -e "  ${AL}${BLD}   ███████║██║     ██║         ██████╔╝██████╔╝██║   ██║${NC}"
    echo -e "  ${AL}${BLD}   ██╔══██║██║     ██║         ██╔═══╝ ██╔══██╗██║   ██║${NC}"
    echo -e "  ${AL}${BLD}   ██║  ██║███████╗███████╗    ██║     ██║  ██║╚██████╔╝${NC}"
    echo -e "  ${DIM}    ╚═╝  ╚═╝╚══════╝╚══════╝    ╚═╝     ╚═╝  ╚═╝ ╚═════╝ ${NC}"
    _top
    echo -e "  ${A4}      ✦  * ALL PRO TUNNELING PANEL *  ✦${NC}"
    echo -e "  ${DIM}      +---------------- ${A2}[ ALL-IN-ONE ]${DIM} ----------------+${NC}"
    _top
}

# ── INFO BOX ───────────────────────────────────────────────
draw_info() {
    local ip; ip=$(get_ip)
    local domain; domain=$(get_domain)
    local brand; brand=$(get_brand)
    local hn; hn=$(hostname)
    local os; os=$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || echo "Linux")
    local ram_u; ram_u=$(free -m | awk '/^Mem/{print $3}')
    local ram_t; ram_t=$(free -m | awk '/^Mem/{print $2}')
    local cpu;   cpu=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{printf "%.1f",$2}')
    local du;    du=$(df -h / | awk 'NR==2{print $3}')
    local dt;    dt=$(df -h / | awk 'NR==2{print $2}')
    local now_t; now_t=$(TZ="Asia/Jakarta" date "+%H:%M")
    local now_d; now_d=$(TZ="Asia/Jakarta" date "+%d/%m/%Y")
    local total_user; total_user=$(cat "$ALLPRO_DIR"/{ssh,vmess,vless,trojan,trojango,hy2}.db 2>/dev/null | wc -l)
    echo ""
    _top
    echo -e "  ${A4}◈${NC} ${BLD}INFO VPS${NC}  ${DIM}${now_t}  │  ${now_d}${NC}"
    _top
    _btn "  ${DIM}HOST    ${NC}${A1}│${NC} ${A3}$(printf '%-20s' "$hn")${NC}  ${DIM}OS${NC}    ${A1}│${NC} ${W}${os}${NC}"
    _sep
    _btn "  ${DIM}IP ADDR ${NC}${A1}│${NC} ${A3}$(printf '%-20s' "$ip")${NC}  ${DIM}DOMAIN${NC}${A1}│${NC} ${W}${domain}${NC}"
    _sep
    _btn "  ${DIM}USER    ${NC}${A1}│${NC} ${Y}$(printf '%-20s' "$total_user")${NC}  ${DIM}BRAND${NC} ${A1}│${NC} ${A4}${brand}${NC}"
    _sep
    _btn "  ${DIM}CPU${NC} ${LG}${cpu}%${NC}  ${A1}│${NC}  ${DIM}RAM${NC} ${LG}${ram_u}/${ram_t}MB${NC}  ${A1}│${NC}  ${DIM}DISK${NC} ${Y}${du}/${dt}${NC}"
    _sep
    _btn "  ${DIM}SSH${NC}$(sv_ssh) ${DIM}DRB${NC}$(sv_dropb) ${DIM}STN${NC}$(sv_stunn) ${DIM}XRY${NC}$(sv_xray) ${DIM}TGO${NC}$(sv_trojan) ${DIM}HY2${NC}$(sv_hy2) ${DIM}WS${NC}$(sv_ws) ${DIM}NGX${NC}$(sv_nginx) ${DIM}SDNS${NC}$(sv_slowdns)"
    _top
}

show_header() { clear; load_theme; draw_logo; draw_info; }
