#!/bin/bash
# ============================================================
#   OGH-ZIV Premium Panel
#   Creator : OGH-ZIV Team
#   Ketik   : menu  untuk membuka panel
#   Support : Debian (all version) & Ubuntu (all version)
# ============================================================

# ── CEK OS — HANYA DEBIAN & UBUNTU ──────────────────────────
check_os() {
    if [[ ! -f /etc/os-release ]]; then
        echo -e "
[1;31m✘ OS tidak dikenali! Script ini hanya untuk Debian & Ubuntu.[0m
"
        exit 1
    fi
    source /etc/os-release 2>/dev/null
    local os_name; os_name=$(echo "${ID}" | tr '[:upper:]' '[:lower:]')
    local os_like; os_like=$(echo "${ID_LIKE:-}" | tr '[:upper:]' '[:lower:]')

    if [[ "$os_name" != "debian" && "$os_name" != "ubuntu" ]] \
       && [[ "$os_like" != *"debian"* && "$os_like" != *"ubuntu"* ]]; then
        echo ""
        echo -e "[1;31m  ╔══════════════════════════════════════════════════════╗[0m"
        echo -e "[1;31m  ║   ✘  OS TIDAK DIDUKUNG!                              ║[0m"
        echo -e "[1;31m  ╠══════════════════════════════════════════════════════╣[0m"
        echo -e "[1;31m  ║[0m  OS kamu : [1;33m${PRETTY_NAME:-$ID}[0m"
        echo -e "[1;31m  ╠══════════════════════════════════════════════════════╣[0m"
        echo -e "[1;31m  ║[0m  Script ini hanya mendukung:                        [1;31m║[0m"
        echo -e "[1;31m  ║[0m  [1;32m✔[0m  Debian (semua versi)                          [1;31m║[0m"
        echo -e "[1;31m  ║[0m  [1;32m✔[0m  Ubuntu (semua versi)                          [1;31m║[0m"
        echo -e "[1;31m  ╚══════════════════════════════════════════════════════╝[0m"
        echo ""
        exit 1
    fi

    # Simpan info OS untuk ditampilkan di panel
    OS_NAME="${PRETTY_NAME:-$ID $VERSION_ID}"
    OS_ID="$os_name"
}

# ── KONSTANTA & PATH ────────────────────────────────────────
DIR="/etc/zivpn"
CFG="$DIR/config.json"
BIN="/usr/local/bin/zivpn-bin"
SVC="/etc/systemd/system/zivpn.service"
LOG="$DIR/zivpn.log"
UDB="$DIR/users.db"
DOMF="$DIR/domain.conf"
BOTF="$DIR/bot.conf"
STRF="$DIR/store.conf"
THEMEF="$DIR/theme.conf"
MLDB="$DIR/maxlogin.db"   # format: username|maxdevice
BINARY_URL="https://github.com/fauzanihanipah/ziv-udp/releases/download/udp-zivpn/udp-zivpn-linux-amd64"
CONFIG_URL="https://raw.githubusercontent.com/fauzanihanipah/ziv-udp/main/config.json"

# ── UTILS ───────────────────────────────────────────────────
check_root() { [[ $EUID -ne 0 ]] && { echo -e "\n\033[1;31m✘ Jalankan sebagai root!\033[0m\n"; exit 1; }; }
ok()    { echo -e "  ${A2}✔${NC}  $*"; }
inf()   { echo -e "  ${A3}➜${NC}  $*"; }
warn()  { echo -e "  ${A4}⚠${NC}  $*"; }
err()   { echo -e "  \033[1;31m✘${NC}  $*"; }
pause() { echo ""; echo -ne "  ${DIM}╰─ [ Enter ] kembali ke menu...${NC}"; read -r; }

get_ip()     { curl -s4 --max-time 5 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}'; }
get_port()   { grep -o '"listen":":[0-9]*"\|"listen": *":[0-9]*"' "$CFG" 2>/dev/null | grep -o '[0-9]*' || echo "5667"; }
get_domain() { cat "$DOMF" 2>/dev/null || get_ip; }
is_up()      { systemctl is-active --quiet zivpn 2>/dev/null; }
total_user() { [[ -f "$UDB" ]] && grep -c '' "$UDB" 2>/dev/null || echo 0; }
exp_count()  {
    local t; t=$(date +%Y-%m-%d)
    [[ -f "$UDB" ]] && awk -F'|' -v d="$t" '$3<d{c++}END{print c+0}' "$UDB" || echo 0
}
rand_pass()  { tr -dc 'A-Za-z0-9' </dev/urandom | head -c 12; }

# ── MAXLOGIN HELPERS ────────────────────────────────────────
get_maxlogin() {
    local u="$1"
    grep "^${u}|" "$MLDB" 2>/dev/null | cut -d'|' -f2
}

set_maxlogin() {
    local u="$1" ml="$2"
    sed -i "/^${u}|/d" "$MLDB" 2>/dev/null
    echo "${u}|${ml}" >> "$MLDB"
}

del_maxlogin() {
    local u="$1"
    sed -i "/^${u}|/d" "$MLDB" 2>/dev/null
}

# Hitung koneksi aktif sebuah user (via ss UDP)
count_active_conn() {
    local u="$1"
    local port; port=$(get_port)
    ss -u -n -p 2>/dev/null | grep ":$port" | grep -c "$u" 2>/dev/null || echo 0
}

# Cek & enforce maxlogin – panggil dari cron atau saat buka menu
check_maxlogin_all() {
    [[ ! -f "$MLDB" || ! -f "$UDB" ]] && return
    local port; port=$(get_port)
    local today; today=$(date +%Y-%m-%d)
    while IFS='|' read -r uname maxdev; do
        [[ -z "$uname" || -z "$maxdev" ]] && continue
        # Hitung koneksi aktif berdasarkan auth log zivpn atau ss
        local conn
        conn=$(ss -u -n -p 2>/dev/null | grep -c ":$port" || echo 0)
        # Pakai pendekatan: cek dari log zivpn jika ada
        local active=0
        if [[ -f "$LOG" ]]; then
            active=$(grep -c "user=$uname" "$LOG" 2>/dev/null || echo 0)
        fi
        # Jika koneksi aktif melebihi maxdev, hapus akun
        if [[ "$active" -gt "$maxdev" ]]; then
            sed -i "/^${uname}|/d" "$UDB"
            del_maxlogin "$uname"
            _reload_pw
            _tg_send "🚫 <b>Auto-Delete MaxLogin</b>
👤 User: <code>$uname</code>
⚠️ Melebihi batas ${maxdev} device — akun otomatis dihapus!"
        fi
    done < "$MLDB"
}

# ════════════════════════════════════════════════════════════
#  TEMA WARNA
# ════════════════════════════════════════════════════════════
load_theme() {
    local theme=1
    [[ -f "$THEMEF" ]] && theme=$(cat "$THEMEF" 2>/dev/null)

    case "$theme" in
        2) A1='\033[38;5;51m'; A2='\033[1;36m'; A3='\033[0;36m'; A4='\033[1;33m'
           AL='\033[38;5;87m'; AT='\033[1;37m'; THEME_NAME="CYAN" ;;
        3) A1='\033[38;5;46m'; A2='\033[1;32m'; A3='\033[0;32m'; A4='\033[1;33m'
           AL='\033[38;5;82m'; AT='\033[1;37m'; THEME_NAME="GREEN" ;;
        4) A1='\033[38;5;220m'; A2='\033[1;33m'; A3='\033[38;5;214m'; A4='\033[0;33m'
           AL='\033[38;5;226m'; AT='\033[1;37m'; THEME_NAME="GOLD" ;;
        5) A1='\033[38;5;196m'; A2='\033[1;31m'; A3='\033[0;31m'; A4='\033[1;33m'
           AL='\033[38;5;203m'; AT='\033[1;37m'; THEME_NAME="RED" ;;
        6) A1='\033[38;5;213m'; A2='\033[1;35m'; A3='\033[0;35m'; A4='\033[1;33m'
           AL='\033[38;5;219m'; AT='\033[1;37m'; THEME_NAME="PINK" ;;
        7) A1='\033[1;37m'; A2='\033[1;37m'; A3='\033[38;5;51m'; A4='\033[1;33m'
           AL='\033[38;5;196m'; AT='\033[1;37m'; THEME_NAME="RAINBOW" ;;
        *) A1='\033[38;5;135m'; A2='\033[1;35m'; A3='\033[38;5;141m'; A4='\033[1;33m'
           AL='\033[38;5;141m'; AT='\033[38;5;231m'; THEME_NAME="VIOLET" ;;
    esac

    NC='\033[0m'; BLD='\033[1m'; DIM='\033[2m'; IT='\033[3m'
    W='\033[1;37m'; LG='\033[1;32m'; LR='\033[1;31m'; LC='\033[1;36m'; Y='\033[1;33m'
}

# ════════════════════════════════════════════════════════════
#  MENU TEMA
# ════════════════════════════════════════════════════════════
menu_tema() {
    while true; do
        clear; load_theme
        local cur_theme; cur_theme=$(cat "$THEMEF" 2>/dev/null || echo 1)
        echo ""
        echo -e "  ${A1}╔══════════════════════════════════════════════════════╗${NC}"
        echo -e "  ${A1}║${NC}  ${IT}${AL}  🎨  PILIH TEMA WARNA${NC}                           ${A1}║${NC}"
        echo -e "  ${A1}╠══════════════════════════════════════════════════════╣${NC}"
        echo -e "  ${A1}║${NC}                                                      ${A1}║${NC}"
        local themes=("VIOLET  — Ungu Premium" "CYAN    — Neon Biru" "GREEN   — Matrix Hijau"
                      "GOLD    — Emas Mewah"   "RED     — Merah Elegan" "PINK    — Pink Pastel"
                      "RAINBOW — Pelangi Cantik")
        local icons=("💜" "🩵" "💚" "💛" "❤️" "🩷" "🌈")
        for i in "${!themes[@]}"; do
            local n=$((i+1))
            local mark="   "
            [[ "$cur_theme" == "$n" ]] && mark="${A2}▶${NC} "
            if [[ $n -eq 7 ]]; then
                printf "  ${A1}║${NC}    %b🌈  ${A1}[7]${NC}  \033[38;5;196mR\033[38;5;208mA\033[38;5;226mI\033[38;5;82mN\033[38;5;51mB\033[38;5;171mO\033[38;5;213mW\033[0m  — Pelangi Cantik              ${A1}║${NC}\n" "$mark"
            else
                printf "  ${A1}║${NC}    %b${icons[$i]}  ${A1}[%s]${NC}  %-30s        ${A1}║${NC}\n" "$mark" "$n" "${themes[$i]}"
            fi
        done
        echo -e "  ${A1}║${NC}                                                      ${A1}║${NC}"
        echo -e "  ${A1}╠══════════════════════════════════════════════════════╣${NC}"
        echo -e "  ${A1}║${NC}  ${DIM}Tema aktif sekarang : ${AT}${THEME_NAME}${NC}                        ${A1}║${NC}"
        echo -e "  ${A1}╠══════════════════════════════════════════════════════╣${NC}"
        echo -e "  ${A1}║${NC}  ${LR}[0]${NC}  ◀  Kembali ke menu utama                      ${A1}║${NC}"
        echo -e "  ${A1}╚══════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -ne "  ${A1}›${NC} Pilih tema [0-7]: "; read -r ch
        case $ch in
            [1-7]) echo "$ch" > "$THEMEF"; load_theme; ok "Tema ${AT}${THEME_NAME}${NC} aktif!"; sleep 0.8 ;;
            0) break ;;
            *) warn "Pilihan tidak valid!"; sleep 0.5 ;;
        esac
    done
}

# ════════════════════════════════════════════════════════════
#  LOGO OGH-ZIV  — Premium Panel Style
# ════════════════════════════════════════════════════════════
draw_logo() {
    local cur_theme; cur_theme=$(cat "$THEMEF" 2>/dev/null || echo 1)
    local L1 L2 L3 L4 L5
    if [[ "$cur_theme" == "7" ]]; then
        L1='\033[38;5;196m'; L2='\033[38;5;214m'; L3='\033[38;5;226m'
        L4='\033[38;5;82m';  L5='\033[38;5;51m'
    else
        L1="$AL"; L2="$AL"; L3="$A3"; L4="$AL"; L5="$A3"
    fi

    # Top border dengan shimmer line
    echo ""
    echo -e "  ${A1}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "  ${A1}║${NC}  ${L1}${BLD}  ██████╗  ██████╗ ██╗  ██╗    ███████╗██╗██╗   ██╗${NC}  ${A1}║${NC}"
    echo -e "  ${A1}║${NC}  ${L2}${BLD} ██╔═══██╗██╔════╝ ██║  ██║    ╚══███╔╝██║██║   ██║${NC}  ${A1}║${NC}"
    echo -e "  ${A1}║${NC}  ${L3}${BLD} ██║   ██║██║  ███╗███████║      ███╔╝ ██║██║   ██║${NC}  ${A1}║${NC}"
    echo -e "  ${A1}║${NC}  ${L4}${BLD} ██║   ██║██║   ██║██╔══██║     ███╔╝  ██║╚██╗ ██╔╝${NC}  ${A1}║${NC}"
    echo -e "  ${A1}║${NC}  ${L5}${BLD} ╚██████╔╝╚██████╔╝██║  ██║    ███████╗██║ ╚████╔╝ ${NC}  ${A1}║${NC}"
    echo -e "  ${A1}║${NC}  ${DIM}      ╚═════╝  ╚═════╝ ╚═╝  ╚═╝    ╚══════╝╚═╝  ╚═══╝  ${NC}  ${A1}║${NC}"
    echo -e "  ${A1}╠══════════════════════════════════════════════════════════╣${NC}"
    printf  "  ${A1}║${NC}%*s${A4}★  SECURE VPN MANAGEMENT SYSTEM  ★${NC}%*s${A1}║${NC}\n" 11 "" 11 ""
    printf  "  ${A1}║${NC}%*s${DIM}◈ ─────────── ${A2}[ PREMIUM ]${DIM} ─────────── ◈${NC}%*s${A1}║${NC}\n" 8 "" 8 ""
    echo -e "  ${A1}╚══════════════════════════════════════════════════════════╝${NC}"
}

# ════════════════════════════════════════════════════════════
#  INFO VPS  — HTML Panel Style (2-column + stats bar)
# ════════════════════════════════════════════════════════════
draw_vps() {
    local ip;     ip=$(get_ip)
    local port;   port=$(get_port)
    local domain; domain=$(get_domain)
    local ram_u;  ram_u=$(free -m | awk '/^Mem/{print $3}')
    local ram_t;  ram_t=$(free -m | awk '/^Mem/{print $2}')
    local cpu;    cpu=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{printf "%.1f",$2}' || echo "0.0")
    local du;     du=$(df -h / | awk 'NR==2{print $3}')
    local dt;     dt=$(df -h / | awk 'NR==2{print $2}')
    local du_pct; du_pct=$(df / | awk 'NR==2{print $5}' | tr -d '%')
    local os;     os=$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || echo "Linux")
    local hn;     hn=$(hostname)
    local total;  total=$(total_user)
    local expc;   expc=$(exp_count)
    local now_time; now_time=$(date "+%H:%M")
    local now_date; now_date=$(date "+%d/%m/%Y")

    # RAM percent
    local ram_pct=0
    [[ $ram_t -gt 0 ]] && ram_pct=$(( ram_u * 100 / ram_t ))

    local svc_ic svc_txt svc_col
    if is_up; then svc_col="${LG}"; svc_ic="●"; svc_txt="RUNNING"
    else           svc_col="${LR}"; svc_ic="●"; svc_txt="STOPPED"; fi

    local bot_txt="Belum setup"
    local bot_col="${LR}"
    [[ -f "$BOTF" ]] && { source "$BOTF" 2>/dev/null; bot_txt="@${BOT_NAME}"; bot_col="${LG}"; }

    local brand="OGH-ZIV"
    [[ -f "$STRF" ]] && { source "$STRF" 2>/dev/null; brand="${BRAND:-OGH-ZIV}"; }

    local tema_display
    if [[ "$THEME_NAME" == "RAINBOW" ]]; then
        tema_display="\033[38;5;196mR\033[38;5;208mA\033[38;5;226mI\033[38;5;82mN\033[38;5;51mB\033[38;5;171mO\033[38;5;213mW\033[0m"
    else
        tema_display="${AL}${THEME_NAME}${NC}"
    fi

    # ── Header bar ───────────────────────────────────────────
    echo ""
    echo -e "  ${A1}╔══════════════════════════════════════════════════════════╗${NC}"
    printf  "  ${A1}║${NC}  ${A4}◈${NC} ${BLD}${A4}INFO VPS${NC}%*s${DIM}${now_time}  │  ${now_date}${NC}  ${A1}║${NC}\n" 28 ""
    echo -e "  ${A1}╠══════════════════════════════════════════════════════════╣${NC}"

    # ── 2-column grid ────────────────────────────────────────
    # Row 1: HOST | OS
    printf  "  ${A1}║${NC}  ${DIM}HOST    ${NC}${A1}│${NC} ${A3}%-16s${NC}  ${DIM}OS      ${NC}${A1}│${NC} ${W}%-14s${NC}${A1}║${NC}\n" \
        "$hn" "$(echo "$os" | cut -c1-14)"

    echo -e "  ${A1}╠╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╣${NC}"

    # Row 2: IP | DOMAIN
    printf  "  ${A1}║${NC}  ${DIM}IP ADDR ${NC}${A1}│${NC} ${A3}%-16s${NC}  ${DIM}DOMAIN  ${NC}${A1}│${NC} ${W}%-14s${NC}${A1}║${NC}\n" \
        "$ip" "$(echo "$domain" | cut -c1-14)"

    echo -e "  ${A1}╠╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╣${NC}"

    # Row 3: PORT | BRAND
    printf  "  ${A1}║${NC}  ${DIM}PORT    ${NC}${A1}│${NC} ${Y}%-16s${NC}  ${DIM}BRAND   ${NC}${A1}│${NC} ${A4}%-14s${NC}${A1}║${NC}\n" \
        "$port" "$brand"

    echo -e "  ${A1}╠══════════════════════════════════════════════════════════╣${NC}"

    # ── Stats bar: CPU | RAM | DISK ──────────────────────────
    # Build mini bar (12 chars wide)
    _mini_bar() {
        local pct=${1:-0}; local color="$2"
        local filled=$(( pct * 12 / 100 ))
        [[ $filled -gt 12 ]] && filled=12
        local empty=$(( 12 - filled ))
        printf "${color}"
        printf '█%.0s' $(seq 1 $filled 2>/dev/null) 2>/dev/null || printf '%0.s█' {1..1}
        [[ $filled -gt 0 ]] && printf '█%.0s' $(seq 2 $filled) 2>/dev/null
        printf "${DIM}"
        [[ $empty -gt 0 ]] && printf '░%.0s' $(seq 1 $empty) 2>/dev/null
        printf "${NC}"
    }

    local cpu_bar; cpu_bar=$(
        pct=${cpu%.*}; [[ -z "$pct" || "$pct" == "?" ]] && pct=0
        filled=$(( pct * 10 / 100 )); [[ $filled -gt 10 ]] && filled=10; empty=$(( 10 - filled ))
        bar=""; for ((i=0;i<filled;i++)); do bar+="█"; done
        for ((i=0;i<empty;i++)); do bar+="░"; done
        echo "$bar"
    )
    local ram_bar; ram_bar=$(
        pct=$ram_pct; filled=$(( pct * 10 / 100 )); [[ $filled -gt 10 ]] && filled=10; empty=$(( 10 - filled ))
        bar=""; for ((i=0;i<filled;i++)); do bar+="█"; done
        for ((i=0;i<empty;i++)); do bar+="░"; done
        echo "$bar"
    )
    local disk_bar; disk_bar=$(
        pct=${du_pct:-3}; filled=$(( pct * 10 / 100 )); [[ $filled -gt 10 ]] && filled=10; empty=$(( 10 - filled ))
        bar=""; for ((i=0;i<filled;i++)); do bar+="█"; done
        for ((i=0;i<empty;i++)); do bar+="░"; done
        echo "$bar"
    )

    printf  "  ${A1}║${NC}  ${DIM}CPU${NC} ${LG}%s%%${NC}  ${LG}%s${NC}  ${A1}│${NC}  ${DIM}RAM${NC} ${A3}%s/%sMB${NC}  ${A3}%s${NC}  ${A1}│${NC}  ${DIM}DISK${NC} ${Y}%s/%s${NC}  ${Y}%s${NC}  ${A1}║${NC}\n" \
        "${cpu}" "${cpu_bar}" "${ram_u}" "${ram_t}" "${ram_bar}" "${du}" "${dt}" "${disk_bar}"

    echo -e "  ${A1}╠══════════════════════════════════════════════════════════╣${NC}"

    # ── Status row ───────────────────────────────────────────
    printf  "  ${A1}║${NC}  ${svc_col}${svc_ic} %-8s${NC}  ${A1}│${NC}  ${DIM}AKUN${NC} ${A3}%-3s${NC}  ${A1}│${NC}  ${DIM}EXP${NC} ${LR}%-3s${NC}  ${A1}│${NC}  ${DIM}BOT${NC} ${bot_col}%-12s${NC}  ${A1}│${NC}  ${DIM}TEMA${NC} %-10b  ${A1}║${NC}\n" \
        "$svc_txt" "$total" "$expc" "$bot_txt" "$tema_display"

    echo -e "  ${A1}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_header() {
    clear; load_theme; draw_logo; draw_vps
}

# ════════════════════════════════════════════════════════════
#  BINGKAI AKUN
# ════════════════════════════════════════════════════════════
show_akun_box() {
    local u="$1" p="$2" domain="$3" port="$4" ql="$5" exp="$6" note="$7" ip_pub="$8" maxl="${9:-2}"
    local sisa=$(( ($(date -d "$exp" +%s 2>/dev/null || echo 0) - $(date +%s)) / 86400 ))
    local sisa_str
    [[ $sisa -lt 0 ]] && sisa_str="${LR}Expired${NC}" || sisa_str="${LG}${sisa} hari lagi${NC}"
    local brand="OGH-ZIV"
    [[ -f "$STRF" ]] && { source "$STRF" 2>/dev/null; brand="${BRAND:-OGH-ZIV}"; }

    echo ""
    echo -e "  ${A1}┌──────────────────────────────────────────────────────────┐${NC}"
    printf  "  ${A1}│${NC}  ${IT}${AL}  ✦ %-52s${NC}  ${A1}│${NC}\n" "$brand — AKUN VPN PREMIUM"
    echo -e "  ${A1}├──────────────┬───────────────────────────────────────────┤${NC}"
    printf  "  ${A1}│${NC} ${DIM} Username ${NC} ${A1}│${NC}  ${BLD}${W}%-41s${NC}  ${A1}│${NC}\n" "$u"
    echo -e "  ${A1}├╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┤${NC}"
    printf  "  ${A1}│${NC} ${DIM} Password ${NC} ${A1}│${NC}  ${BLD}${A3}%-41s${NC}  ${A1}│${NC}\n" "$p"
    echo -e "  ${A1}├──────────────┼───────────────────────────────────────────┤${NC}"
    printf  "  ${A1}│${NC} ${DIM} IP Publik ${NC}${A1}│${NC}  ${LG}%-41s${NC}  ${A1}│${NC}\n" "${ip_pub:-$(get_ip)}"
    echo -e "  ${A1}├╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┤${NC}"
    printf  "  ${A1}│${NC} ${DIM} Host     ${NC} ${A1}│${NC}  ${W}%-41s${NC}  ${A1}│${NC}\n" "$domain"
    echo -e "  ${A1}├╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┤${NC}"
    printf  "  ${A1}│${NC} ${DIM} Port     ${NC} ${A1}│${NC}  ${Y}%-41s${NC}  ${A1}│${NC}\n" "$port"
    echo -e "  ${A1}├╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┤${NC}"
    printf  "  ${A1}│${NC} ${DIM} Obfs     ${NC} ${A1}│${NC}  ${W}%-41s${NC}  ${A1}│${NC}\n" "zivpn"
    echo -e "  ${A1}├──────────────┼───────────────────────────────────────────┤${NC}"
    printf  "  ${A1}│${NC} ${DIM} Kuota    ${NC} ${A1}│${NC}  ${LG}%-41s${NC}  ${A1}│${NC}\n" "$ql"
    echo -e "  ${A1}├╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┤${NC}"
    printf  "  ${A1}│${NC} ${DIM} MaxLogin ${NC} ${A1}│${NC}  ${Y}%-41s${NC}  ${A1}│${NC}\n" "${maxl} device"
    echo -e "  ${A1}├╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┤${NC}"
    printf  "  ${A1}│${NC} ${DIM} Expired  ${NC} ${A1}│${NC}  ${Y}%-41s${NC}  ${A1}│${NC}\n" "$exp"
    echo -e "  ${A1}├╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┤${NC}"
    printf  "  ${A1}│${NC} ${DIM} Sisa     ${NC} ${A1}│${NC}  %-41b  ${A1}│${NC}\n" "$sisa_str"
    [[ "$note" != "-" ]] && {
        echo -e "  ${A1}├╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┤${NC}"
        printf  "  ${A1}│${NC} ${DIM} Pembeli  ${NC} ${A1}│${NC}  ${W}%-41s${NC}  ${A1}│${NC}\n" "$note"
    }
    echo -e "  ${A1}├──────────────┴───────────────────────────────────────────┤${NC}"
    echo -e "  ${A1}│${NC}  ${DIM}📱 Download ZiVPN → Play Store / App Store${NC}              ${A1}│${NC}"
    echo -e "  ${A1}│${NC}  ${DIM}⚠  Jangan share akun ini ke orang lain!${NC}                ${A1}│${NC}"
    echo -e "  ${A1}└──────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ════════════════════════════════════════════════════════════
#  HELPERS
# ════════════════════════════════════════════════════════════
_reload_pw() {
    [[ ! -f "$UDB" || ! -f "$CFG" ]] && return
    local pws=()
    while IFS='|' read -r _ pw _ _ _; do pws+=("\"$pw\""); done < "$UDB"
    local pwl; pwl=$(IFS=','; echo "${pws[*]}")
    python3 - <<PYEOF 2>/dev/null
import json
with open('$CFG') as f: c=json.load(f)
c['auth']['config']=[${pwl}]
with open('$CFG','w') as f: json.dump(c,f,indent=2)
PYEOF
    systemctl restart zivpn &>/dev/null
}

_tg_send() {
    [[ ! -f "$BOTF" ]] && return
    source "$BOTF" 2>/dev/null
    [[ -z "$BOT_TOKEN" || -z "$CHAT_ID" ]] && return
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}" -d "text=$1" -d "parse_mode=HTML" &>/dev/null
}

_tg_raw() {
    local tok="$1" cid="$2" msg="$3"
    curl -s -X POST "https://api.telegram.org/bot${tok}/sendMessage" \
        -d "chat_id=${cid}" -d "text=${msg}" -d "parse_mode=HTML" &>/dev/null
}

# ════════════════════════════════════════════════════════════
#  HELPER PANEL BUTTONS
# ════════════════════════════════════════════════════════════
# Lebar isi kotak = 56 karakter tercetak (tidak termasuk border ║)
_BOX_W=56
_LINE="════════════════════════════════════════════════════════"
_LINED="╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌"

_top()  { echo -e "  ${A1}╔${_LINE}╗${NC}"; }
_bot()  { echo -e "  ${A1}╚${_LINE}╝${NC}"; }
_sep()  { echo -e "  ${A1}╠${_LINE}╣${NC}"; }
_sep0() { echo -e "  ${A1}╠${_LINED}╣${NC}"; }

# Hitung lebar tampilan string (strip ANSI, hitung unicode display width)
_displen() {
    local raw="$1"
    local clean; clean=$(printf '%b' "$raw" 2>/dev/null | \
        sed 's/\x1b\[[0-9;]*[mJKHfABCDsuhlp]//g; s/\x1b[()][AB012]//g; s/\x1b//g' 2>/dev/null)
    # Hitung via python3 (akurat untuk emoji & CJK)
    python3 -c "
import unicodedata, sys
s = sys.argv[1]
w = sum(2 if unicodedata.east_asian_width(c) in ('W','F') else 1 for c in s)
print(w)
" "$clean" 2>/dev/null || echo "${#clean}"
}

# _btn: cetak baris dengan border ║ kiri-kanan selalu lurus
_btn() {
    local raw="$1"
    local dlen; dlen=$(_displen "$raw")
    local pad=$(( _BOX_W - dlen ))
    [[ $pad -lt 0 ]] && pad=0
    local spaces; spaces=$(printf '%*s' "$pad" '')
    printf "  ${A1}║${NC}%b%s${A1}║${NC}\n" "$raw" "$spaces"
}

# ════════════════════════════════════════════════════════════
#  INSTALL
# ════════════════════════════════════════════════════════════
do_install() {
    show_header
    _top; _btn "  ${IT}${AL}🚀  INSTALL ZIVPN${NC}"; _bot; echo ""

    # ── Hapus file lama otomatis setiap kali install dijalankan ──────
    inf "Membersihkan file lama (jika ada)..."
    systemctl stop    zivpn.service 2>/dev/null
    systemctl disable zivpn.service 2>/dev/null
    rm -f "$BIN"              # binary lama
    rm -f "$SVC"              # service lama
    rm -f "$DIR/zivpn.key"    # SSL key lama
    rm -f "$DIR/zivpn.crt"    # SSL cert lama
    rm -f "$DIR/config.json"  # config lama
    rm -f "$DIR/zivpn.log"    # log lama
    # ⚠ Data akun, domain, theme, bot, store TIDAK dihapus
    systemctl daemon-reload 2>/dev/null
    ok "File lama dibersihkan — data akun & konfigurasi dipertahankan"

    local sip; sip=$(get_ip)
    echo -ne "  ${A3}Domain / IP${NC}            : "; read -r inp_domain
    [[ -z "$inp_domain" ]] && inp_domain="$sip"
    echo -ne "  ${A3}Port${NC} [5667]             : "; read -r inp_port
    [[ -z "$inp_port" ]] && inp_port=5667
    echo -ne "  ${A3}Nama Brand / Toko${NC}       : "; read -r inp_brand
    [[ -z "$inp_brand" ]] && inp_brand="OGH-ZIV"
    echo -ne "  ${A3}Username Telegram Admin${NC}  : "; read -r inp_tg
    [[ -z "$inp_tg" ]] && inp_tg="-"

    echo ""
    echo -e "  ${A1}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    inf "Memulai instalasi ${AL}OGH-ZIV Premium${NC}..."
    echo -e "  ${A1}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo ""

    # ── Dependensi ───────────────────────────────────────────────────
    inf "Menginstall dependensi..."
    apt-get update -qq &>/dev/null
    apt-get install -y -qq curl wget openssl python3 iptables \
        iptables-persistent netfilter-persistent &>/dev/null
    ok "Dependensi terpasang"

    # ── Direktori & file konfigurasi awal ────────────────────────────
    mkdir -p "$DIR"
    touch "$UDB" "$LOG"
    echo "$inp_domain" > "$DOMF"
    echo "rainbow"     > "$THEMEF"
    printf "BRAND=%s\nADMIN_TG=%s\n" "$inp_brand" "$inp_tg" > "$STRF"
    ok "Direktori & konfigurasi dibuat"

    # ── Download binary ZiVPN ─────────────────────────────────────────
    echo -e "\n  ${A1}──────────────────────────────────────────────${NC}"
    inf "Downloading UDP Service..."
    wget "$BINARY_URL" -O "$BIN"
    if [[ ! -s "$BIN" ]]; then
        err "Gagal download binary ZiVPN!"
        echo -e "  ${Y}Coba jalankan manual:${NC}"
        echo -e "  ${W}wget $BINARY_URL -O $BIN${NC}"
        rm -f "$BIN"; pause; return 1
    fi
    chmod +x "$BIN"
    ok "Binary ZiVPN siap ($(du -sh "$BIN" 2>/dev/null | cut -f1))"

    # ── Download config.json resmi dari GitHub ───────────────────────
    inf "Mengunduh config.json..."
    wget "$CONFIG_URL" -O "$CFG"
    if [[ ! -s "$CFG" ]]; then
        warn "config.json tidak bisa diunduh, membuat manual..."
        cat > "$CFG" <<CFEOF
{
  "listen": ":${inp_port}",
  "cert": "/etc/zivpn/zivpn.crt",
  "key": "/etc/zivpn/zivpn.key",
  "obfs": "zivpn",
  "auth": {
    "mode": "passwords",
    "config": []
  }
}
CFEOF
    else
        # Update port di config.json yang didownload
        python3 - <<PYEOF 2>/dev/null
import json
try:
    with open('$CFG') as f: c = json.load(f)
    c['listen'] = ':${inp_port}'
    with open('$CFG','w') as f: json.dump(c, f, indent=2)
except: pass
PYEOF
    fi
    ok "config.json siap"

    # ── Generate SSL Certificate (RSA 4096, 1 tahun) ─────────────────
    echo -e "\n  ${A1}──────────────────────────────────────────────${NC}"
    inf "Generating cert files..."
    openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
        -subj "/C=US/ST=California/L=Los Angeles/O=Example Corp/OU=IT Department/CN=zivpn" \
        -keyout "$DIR/zivpn.key" \
        -out    "$DIR/zivpn.crt" &>/dev/null
    ok "SSL Certificate RSA-4096 (1 tahun) dibuat"

    # ── Optimasi kernel buffer UDP ────────────────────────────────────
    sysctl -w net.core.rmem_max=16777216 &>/dev/null
    sysctl -w net.core.wmem_max=16777216 &>/dev/null
    grep -q 'rmem_max' /etc/sysctl.conf 2>/dev/null || \
        printf "net.core.rmem_max=16777216\nnet.core.wmem_max=16777216\n" >> /etc/sysctl.conf
    ok "Buffer UDP dioptimasi (rmem/wmem 16MB)"

    # ── Systemd service ───────────────────────────────────────────────
    echo -e "\n  ${A1}──────────────────────────────────────────────${NC}"
    inf "Membuat systemd service..."
    cat > "$SVC" <<SVEOF
[Unit]
Description=zivpn VPN Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$DIR
ExecStart=$BIN server -c $CFG
Restart=always
RestartSec=3
Environment=ZIVPN_LOG_LEVEL=info
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true
LimitNOFILE=1048576
StandardOutput=append:$LOG
StandardError=append:$LOG

[Install]
WantedBy=multi-user.target
SVEOF
    ok "Systemd service dibuat"

    # ── IPTables: UDP port forwarding 6000-19999 → port VPN ──────────
    echo -e "\n  ${A1}──────────────────────────────────────────────${NC}"
    inf "Mengatur iptables & UDP port forwarding..."
    local IFACE
    IFACE=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)

    # Bersihkan rules lama
    while iptables -t nat -D PREROUTING \
        -i "$IFACE" -p udp --dport 6000:19999 \
        -j DNAT --to-destination :${inp_port} 2>/dev/null; do :; done

    # Tambah rules baru
    iptables -t nat -A PREROUTING \
        -i "$IFACE" -p udp --dport 6000:19999 \
        -j DNAT --to-destination :${inp_port}
    iptables -A FORWARD -p udp -d 127.0.0.1 --dport "${inp_port}" -j ACCEPT
    iptables -t nat -A POSTROUTING -s 127.0.0.1/32 -o "$IFACE" -j MASQUERADE

    # Simpan permanen
    netfilter-persistent save &>/dev/null
    ok "IPTables: UDP 6000-19999 → ${inp_port} via $IFACE"

    # ── Firewall UFW ──────────────────────────────────────────────────
    if command -v ufw &>/dev/null; then
        ufw allow 6000:19999/udp &>/dev/null
        ufw allow "${inp_port}/udp" &>/dev/null
        ok "UFW: port 6000-19999/udp & ${inp_port}/udp dibuka"
    fi
    iptables -I INPUT -p udp --dport "${inp_port}" -j ACCEPT 2>/dev/null

    # ── Aktifkan & start service ──────────────────────────────────────
    echo -e "\n  ${A1}──────────────────────────────────────────────${NC}"
    inf "Mengaktifkan service ZiVPN..."
    systemctl daemon-reload
    systemctl enable zivpn.service &>/dev/null
    systemctl start  zivpn.service
    sleep 1
    if systemctl is-active --quiet zivpn; then
        ok "Service ZiVPN aktif & berjalan"
    else
        warn "Service gagal start — cek: journalctl -u zivpn -n 20"
    fi

    # ── Setup menu command ────────────────────────────────────────────
    setup_menu_cmd &>/dev/null

    # ── Ringkasan instalasi ───────────────────────────────────────────
    echo ""
    echo -e "  ${A1}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "  ${A1}│${NC}  ${LG}${BLD}  ✦ OGH-ZIV PREMIUM BERHASIL DIINSTALL!${NC}                ${A1}│${NC}"
    echo -e "  ${A1}├──────────────┬───────────────────────────────────────────┤${NC}"
    printf  "  ${A1}│${NC} ${DIM} Domain    ${NC} ${A1}│${NC}  ${W}%-41s${NC}  ${A1}│${NC}\n" "$inp_domain"
    printf  "  ${A1}│${NC} ${DIM} Port      ${NC} ${A1}│${NC}  ${Y}%-41s${NC}  ${A1}│${NC}\n" "$inp_port"
    printf  "  ${A1}│${NC} ${DIM} Brand     ${NC} ${A1}│${NC}  ${AL}%-41s${NC}  ${A1}│${NC}\n" "$inp_brand"
    echo -e "  ${A1}├╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┤${NC}"
    printf  "  ${A1}│${NC} ${DIM} Forwarding${NC} ${A1}│${NC}  ${W}%-41s${NC}  ${A1}│${NC}\n" "UDP 6000-19999 → ${inp_port}"
    printf  "  ${A1}│${NC} ${DIM} Interface ${NC} ${A1}│${NC}  ${W}%-41s${NC}  ${A1}│${NC}\n" "$IFACE"
    echo -e "  ${A1}└──────────────┴───────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "  ${DIM}Ketik ${A1}menu${NC}${DIM} untuk membuka panel kapan saja.${NC}"
    echo ""
    pause
}

# ════════════════════════════════════════════════════════════
#  USER FUNCTIONS
# ════════════════════════════════════════════════════════════
u_add() {
    show_header
    _top; _btn "  ${IT}${AL}➕  TAMBAH AKUN BARU${NC}"; _bot; echo ""
    echo -ne "  ${A3}Username${NC}               : "; read -r un
    [[ -z "$un" ]] && { err "Username kosong!"; pause; return; }
    grep -q "^${un}|" "$UDB" 2>/dev/null && { err "Username sudah ada!"; pause; return; }
    echo -ne "  ${A3}Password${NC} [auto]         : "; read -r up
    [[ -z "$up" ]] && up=$(rand_pass)
    echo -ne "  ${A3}Masa aktif (hari)${NC} [30]  : "; read -r ud
    [[ -z "$ud" ]] && ud=30
    local ue; ue=$(date -d "+${ud} days" +"%Y-%m-%d")
    echo -ne "  ${A3}Kuota GB${NC} (0=unlimited)  : "; read -r uq
    [[ -z "$uq" ]] && uq=0
    echo -ne "  ${A3}Catatan / Nama Pembeli${NC}  : "; read -r note
    [[ -z "$note" ]] && note="-"
    echo -ne "  ${A3}Max Login Device${NC} [2]    : "; read -r uml
    [[ -z "$uml" || ! "$uml" =~ ^[0-9]+$ ]] && uml=2

    echo "${un}|${up}|${ue}|${uq}|${note}" >> "$UDB"
    set_maxlogin "$un" "$uml"
    _reload_pw

    local domain; domain=$(get_domain)
    local port;   port=$(get_port)
    local ip_pub; ip_pub=$(get_ip)
    local ql;     [[ "$uq" == "0" ]] && ql="Unlimited" || ql="${uq} GB"

    [[ -f "$STRF" ]] && source "$STRF" 2>/dev/null
    _tg_send "✅ <b>Akun Baru — ${BRAND:-OGH-ZIV}</b>
┌──────────────────────────
│ 👤 <b>Username</b> : <code>$un</code>
│ 🔑 <b>Password</b> : <code>$up</code>
├──────────────────────────
│ 🖥 <b>IP Publik</b> : <code>$ip_pub</code>
│ 🌐 <b>Host</b>     : <code>$domain</code>
│ 🔌 <b>Port</b>     : <code>$port</code>
│ 📡 <b>Obfs</b>     : <code>zivpn</code>
├──────────────────────────
│ 📦 <b>Kuota</b>    : $ql
│ 🔒 <b>MaxLogin</b> : ${uml} device
│ 📅 <b>Expired</b>  : $ue
│ 📝 <b>Pembeli</b>  : $note
└──────────────────────────"

    show_akun_box "$un" "$up" "$domain" "$port" "$ql" "$ue" "$note" "$ip_pub" "$uml"
    pause
}

u_list() {
    show_header
    _top; _btn "  ${IT}${AL}📋  LIST SEMUA AKUN${NC}"; _bot; echo ""
    [[ ! -s "$UDB" ]] && { warn "Belum ada akun terdaftar."; pause; return; }
    local today; today=$(date +"%Y-%m-%d"); local n=1
    echo -e "  ${A1}┌────┬──────────────────┬────────────┬────────────┬──────────┬─────────┐${NC}"
    printf  "  ${A1}│${NC}${BLD} %-2s ${A1}│${NC}${BLD} %-16s ${A1}│${NC}${BLD} %-10s ${A1}│${NC}${BLD} %-10s ${A1}│${NC}${BLD} %-8s ${A1}│${NC}${BLD} %-7s ${A1}│${NC}\n" \
        "#" "Username" "Password" "Expired" "Kuota" "Status"
    echo -e "  ${A1}├────┼──────────────────┼────────────┼────────────┼──────────┼─────────┤${NC}"
    while IFS='|' read -r u p e q _; do
        local sc sl
        [[ "$e" < "$today" ]] && sc="$LR" sl="EXPIRED" || sc="$LG" sl="AKTIF  "
        local ql; [[ "$q" == "0" ]] && ql="Unlim   " || ql="${q}GB     "
        printf "  ${A1}│${NC} ${DIM}%-2s${NC} ${A1}│${NC} ${W}%-16s${NC} ${A1}│${NC} ${A3}%-10s${NC} ${A1}│${NC} ${Y}%-10s${NC} ${A1}│${NC} %-8s ${A1}│${NC} ${sc}%-7s${NC} ${A1}│${NC}\n" \
            "$n" "$u" "$p" "$e" "$ql" "$sl"
        ((n++))
    done < "$UDB"
    echo -e "  ${A1}└────┴──────────────────┴────────────┴────────────┴──────────┴─────────┘${NC}"
    echo ""
    echo -e "  ${DIM}  Total: $((n-1)) akun  │  Expired: $(exp_count) akun${NC}"
    pause
}

u_info() {
    show_header
    _top; _btn "  ${IT}${AL}🔍  INFO DETAIL AKUN${NC}"; _bot; echo ""
    echo -ne "  ${A3}Username${NC}: "; read -r un
    local ln; ln=$(grep "^${un}|" "$UDB" 2>/dev/null)
    [[ -z "$ln" ]] && { err "User tidak ditemukan!"; pause; return; }
    IFS='|' read -r u p e q note <<< "$ln"
    local domain; domain=$(get_domain)
    local port;   port=$(get_port)
    local ip_pub; ip_pub=$(get_ip)
    local ql;     [[ "$q" == "0" ]] && ql="Unlimited" || ql="${q} GB"
    local maxl;   maxl=$(get_maxlogin "$un"); [[ -z "$maxl" ]] && maxl=2
    show_akun_box "$u" "$p" "$domain" "$port" "$ql" "$e" "$note" "$ip_pub" "$maxl"
    pause
}

u_del() {
    show_header
    _top; _btn "  ${IT}${AL}🗑️   HAPUS AKUN${NC}"; _bot; echo ""
    [[ ! -s "$UDB" ]] && { warn "Tidak ada akun."; pause; return; }
    local n=1
    while IFS='|' read -r u _ e _ _; do
        printf "  ${DIM}%3s.${NC}  ${W}%-22s${NC}  ${DIM}exp: %s${NC}\n" "$n" "$u" "$e"; ((n++))
    done < "$UDB"
    echo ""
    echo -ne "  ${A3}Username yang dihapus${NC}: "; read -r du
    grep -q "^${du}|" "$UDB" 2>/dev/null || { err "User tidak ditemukan!"; pause; return; }
    sed -i "/^${du}|/d" "$UDB"
    del_maxlogin "$du"
    _reload_pw
    _tg_send "🗑 <b>Akun Dihapus</b> : <code>$du</code>"
    ok "Akun '${W}$du${NC}' berhasil dihapus."
    pause
}

u_renew() {
    show_header
    _top; _btn "  ${IT}${AL}🔁  PERPANJANG AKUN${NC}"; _bot; echo ""
    echo -ne "  ${A3}Username${NC}    : "; read -r ru
    grep -q "^${ru}|" "$UDB" 2>/dev/null || { err "User tidak ditemukan!"; pause; return; }
    echo -ne "  ${A3}Tambah hari${NC} : "; read -r rd; [[ -z "$rd" ]] && rd=30
    local ce; ce=$(grep "^${ru}|" "$UDB" | cut -d'|' -f3)
    local today; today=$(date +%Y-%m-%d)
    [[ "$ce" < "$today" ]] && ce="$today"
    local ne; ne=$(date -d "${ce} +${rd} days" +"%Y-%m-%d")
    sed -i "s/^\(${ru}|[^|]*|\)[^|]*/\1${ne}/" "$UDB"
    _tg_send "🔁 <b>Akun Diperpanjang</b>
👤 User     : <code>$ru</code>
📅 Expired  : <b>$ne</b>  (+${rd} hari)"
    echo ""
    echo -e "  ${A1}┌──────────────┬───────────────────────────────────────────┤${NC}"
    echo -e "  ${A1}│${NC}  ${LG}✔  Akun berhasil diperpanjang!${NC}                        ${A1}│${NC}"
    echo -e "  ${A1}├──────────────┼───────────────────────────────────────────┤${NC}"
    printf  "  ${A1}│${NC} ${DIM} Username  ${NC} ${A1}│${NC}  ${W}%-41s${NC}  ${A1}│${NC}\n" "$ru"
    echo -e "  ${A1}├╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┤${NC}"
    printf  "  ${A1}│${NC} ${DIM} Expired   ${NC} ${A1}│${NC}  ${Y}%-41s${NC}  ${A1}│${NC}\n" "$ne"
    echo -e "  ${A1}├╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┤${NC}"
    printf  "  ${A1}│${NC} ${DIM} Tambahan  ${NC} ${A1}│${NC}  ${LG}+%-40s${NC}  ${A1}│${NC}\n" "${rd} hari"
    echo -e "  ${A1}└──────────────┴───────────────────────────────────────────┘${NC}"
    pause
}

u_chpass() {
    show_header
    _top; _btn "  ${IT}${AL}🔑  GANTI PASSWORD${NC}"; _bot; echo ""
    echo -ne "  ${A3}Username${NC}           : "; read -r pu
    grep -q "^${pu}|" "$UDB" 2>/dev/null || { err "User tidak ditemukan!"; pause; return; }
    echo -ne "  ${A3}Password baru${NC} [auto]: "; read -r pp
    [[ -z "$pp" ]] && pp=$(rand_pass)
    sed -i "s/^${pu}|[^|]*/${pu}|${pp}/" "$UDB"
    _reload_pw
    echo ""
    echo -e "  ${A1}┌──────────────┬───────────────────────────────────────────┤${NC}"
    echo -e "  ${A1}│${NC}  ${LG}✔  Password berhasil diubah!${NC}                          ${A1}│${NC}"
    echo -e "  ${A1}├──────────────┼───────────────────────────────────────────┤${NC}"
    printf  "  ${A1}│${NC} ${DIM} Username  ${NC} ${A1}│${NC}  ${W}%-41s${NC}  ${A1}│${NC}\n" "$pu"
    echo -e "  ${A1}├╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┤${NC}"
    printf  "  ${A1}│${NC} ${DIM} Password  ${NC} ${A1}│${NC}  ${A3}%-41s${NC}  ${A1}│${NC}\n" "$pp"
    echo -e "  ${A1}└──────────────┴───────────────────────────────────────────┘${NC}"
    pause
}

u_trial() {
    show_header
    _top; _btn "  ${IT}${AL}🎁  BUAT AKUN TRIAL${NC}"; _bot; echo ""
    local tu="trial$(tr -dc 'a-z0-9' </dev/urandom | head -c 6)"
    local tp; tp=$(rand_pass)
    local te; te=$(date -d "+1 day" +"%Y-%m-%d")
    local ip_pub; ip_pub=$(get_ip)
    echo "${tu}|${tp}|${te}|1|TRIAL" >> "$UDB"
    _reload_pw
    local domain; domain=$(get_domain); local port; port=$(get_port)
    _tg_send "🎁 <b>Akun Trial Dibuat</b>
👤 User  : <code>$tu</code>
🔑 Pass  : <code>$tp</code>
🖥 IP    : <code>$ip_pub</code>
📅 Exp   : $te  (1 hari / 1 GB)"
    show_akun_box "$tu" "$tp" "$domain" "$port" "1 GB" "$te" "TRIAL" "$ip_pub"
    pause
}

u_clean() {
    show_header
    _top; _btn "  ${IT}${AL}🧹  HAPUS AKUN EXPIRED${NC}"; _bot; echo ""
    local today; today=$(date +"%Y-%m-%d"); local cnt=0
    while IFS='|' read -r u _ e _ _; do
        if [[ "$e" < "$today" ]]; then
            sed -i "/^${u}|/d" "$UDB"
            del_maxlogin "$u"
            ok "Dihapus: ${W}$u${NC}  ${DIM}(exp: $e)${NC}"; ((cnt++))
        fi
    done < <(cat "$UDB" 2>/dev/null)
    echo ""
    [[ $cnt -gt 0 ]] && { _reload_pw; ok "Total ${W}$cnt${NC} akun expired dihapus."; } \
                     || inf "Tidak ada akun expired."
    pause
}

# ════════════════════════════════════════════════════════════
#  JUALAN
# ════════════════════════════════════════════════════════════
t_akun() {
    show_header
    _top; _btn "  ${IT}${AL}📨  TEMPLATE PESAN AKUN${NC}"; _bot; echo ""
    [[ -f "$STRF" ]] && source "$STRF" 2>/dev/null
    echo -ne "  ${A3}Username${NC}: "; read -r tu
    local ln; ln=$(grep "^${tu}|" "$UDB" 2>/dev/null)
    [[ -z "$ln" ]] && { err "User tidak ditemukan!"; pause; return; }
    IFS='|' read -r u p e q note <<< "$ln"
    local domain; domain=$(get_domain); local port; port=$(get_port)
    local ip_pub; ip_pub=$(get_ip)
    local ql; [[ "$q" == "0" ]] && ql="Unlimited" || ql="${q} GB"
    show_akun_box "$u" "$p" "$domain" "$port" "$ql" "$e" "$note" "$ip_pub"
    pause
}

set_store() {
    show_header
    _top; _btn "  ${IT}${AL}⚙️   PENGATURAN TOKO${NC}"; _bot; echo ""
    [[ -f "$STRF" ]] && source "$STRF" 2>/dev/null
    echo -ne "  ${A3}Nama Brand${NC} [${BRAND:-OGH-ZIV}]   : "; read -r ib
    echo -ne "  ${A3}Username TG Admin${NC} [${ADMIN_TG:--}]: "; read -r it
    printf "BRAND=%s\nADMIN_TG=%s\n" "${ib:-${BRAND:-OGH-ZIV}}" "${it:-${ADMIN_TG:--}}" > "$STRF"
    ok "Pengaturan toko disimpan!"
    pause
}

# ════════════════════════════════════════════════════════════
#  TELEGRAM BOT
# ════════════════════════════════════════════════════════════
tg_setup() {
    show_header
    _top; _btn "  ${IT}${AL}🤖  SETUP BOT TELEGRAM${NC}"; _bot; echo ""
    inf "Buka ${A3}@BotFather${NC} di Telegram → ketik /newbot → salin TOKEN"
    inf "Kirim /start ke bot → buka URL:"
    echo -e "  ${DIM}     api.telegram.org/bot<TOKEN>/getUpdates${NC}"; echo ""
    echo -ne "  ${A3}Bot Token${NC}     : "; read -r tok
    [[ -z "$tok" ]] && { err "Token kosong!"; pause; return; }
    echo -ne "  ${A3}Chat ID Admin${NC} : "; read -r cid
    [[ -z "$cid" ]] && { err "Chat ID kosong!"; pause; return; }
    local res; res=$(curl -s "https://api.telegram.org/bot${tok}/getMe")
    if echo "$res" | grep -q '"ok":true'; then
        local bname; bname=$(echo "$res" | python3 -c \
            "import sys,json;d=json.load(sys.stdin);print(d['result']['username'])" 2>/dev/null)
        printf "BOT_TOKEN=%s\nCHAT_ID=%s\nBOT_NAME=%s\n" "$tok" "$cid" "$bname" > "$BOTF"
        _tg_raw "$tok" "$cid" "✅ <b>OGH-ZIV Premium</b> bot terhubung ke server VPS!"
        echo ""
        echo -e "  ${A1}┌──────────────┬───────────────────────────────────────────┤${NC}"
        echo -e "  ${A1}│${NC}  ${LG}✔  Bot Telegram berhasil terhubung!${NC}                   ${A1}│${NC}"
        echo -e "  ${A1}├──────────────┼───────────────────────────────────────────┤${NC}"
        printf  "  ${A1}│${NC} ${DIM} Bot Name  ${NC} ${A1}│${NC}  ${W}@%-40s${NC}  ${A1}│${NC}\n" "$bname"
        echo -e "  ${A1}├╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┤${NC}"
        printf  "  ${A1}│${NC} ${DIM} Chat ID   ${NC} ${A1}│${NC}  ${Y}%-41s${NC}  ${A1}│${NC}\n" "$cid"
        echo -e "  ${A1}└──────────────┴───────────────────────────────────────────┘${NC}"
    else
        err "Token tidak valid atau tidak bisa terhubung!"
    fi
    pause
}

tg_status() {
    show_header
    _top; _btn "  ${IT}${AL}📡  STATUS BOT TELEGRAM${NC}"; _bot; echo ""
    if [[ ! -f "$BOTF" ]]; then
        warn "Bot belum dikonfigurasi."
        echo -ne "  Setup sekarang? [y/N]: "; read -r a
        [[ "$a" == [yY] ]] && tg_setup; return
    fi
    source "$BOTF" 2>/dev/null
    local res; res=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getMe")
    if echo "$res" | grep -q '"ok":true'; then
        local fn; fn=$(echo "$res" | python3 -c \
            "import sys,json;d=json.load(sys.stdin);print(d['result']['first_name'])" 2>/dev/null)
        echo ""
        echo -e "  ${A1}╔══════════════════════════════════════════════════════════╗${NC}"
        echo -e "  ${A1}║${NC}  ${LG}🟢  Bot Aktif & Terhubung${NC}                              ${A1}║${NC}"
        echo -e "  ${A1}╠══════════════╦═══════════════════════════════════════════╣${NC}"
        printf  "  ${A1}║${NC} ${DIM} Nama      ${NC} ${A1}║${NC}  ${W}%-41s${NC}  ${A1}║${NC}\n" "$fn"
        printf  "  ${A1}║${NC} ${DIM} Username  ${NC} ${A1}║${NC}  ${W}@%-40s${NC}  ${A1}║${NC}\n" "$BOT_NAME"
        printf  "  ${A1}║${NC} ${DIM} Chat ID   ${NC} ${A1}║${NC}  ${Y}%-41s${NC}  ${A1}║${NC}\n" "$CHAT_ID"
        echo -e "  ${A1}╚══════════════╩═══════════════════════════════════════════╝${NC}"
        echo ""
        echo -ne "  ${A3}Kirim pesan test?${NC} [y/N]: "; read -r ts
        [[ "$ts" == [yY] ]] && {
            _tg_send "🟢 <b>Test OGH-ZIV Premium</b> — Bot berjalan normal! ✅"
            ok "Pesan test dikirim ke Telegram!"
        }
    else
        err "Bot tidak dapat terhubung. Cek token!"
    fi
    pause
}

tg_kirim_akun() {
    show_header
    _top; _btn "  ${IT}${AL}📤  KIRIM AKUN KE TELEGRAM${NC}"; _bot; echo ""
    [[ ! -f "$BOTF" ]] && { err "Bot belum dikonfigurasi!"; pause; return; }
    source "$BOTF" 2>/dev/null
    [[ -f "$STRF" ]] && source "$STRF" 2>/dev/null
    echo -ne "  ${A3}Username akun${NC}    : "; read -r su
    local ln; ln=$(grep "^${su}|" "$UDB" 2>/dev/null)
    [[ -z "$ln" ]] && { err "User tidak ditemukan!"; pause; return; }
    IFS='|' read -r u p e q note <<< "$ln"
    echo -ne "  ${A3}Chat ID tujuan${NC} [$CHAT_ID]: "; read -r did
    [[ -z "$did" ]] && did="$CHAT_ID"
    local domain; domain=$(get_domain); local port; port=$(get_port)
    local ip_pub; ip_pub=$(get_ip)
    local ql; [[ "$q" == "0" ]] && ql="Unlimited" || ql="${q} GB"
    local sisa=$(( ($(date -d "$e" +%s 2>/dev/null || echo 0) - $(date +%s)) / 86400 ))
    local sisa_str; [[ $sisa -lt 0 ]] && sisa_str="Expired" || sisa_str="${sisa} hari lagi"
    local msg="🔒 <b>${BRAND:-OGH-ZIV} — Akun VPN UDP Premium</b>

┌────────────────────────────
│ 👤 <b>Username</b>  : <code>$u</code>
│ 🔑 <b>Password</b>  : <code>$p</code>
├────────────────────────────
│ 🖥 <b>IP Publik</b>  : <code>$ip_pub</code>
│ 🌐 <b>Host</b>      : <code>$domain</code>
│ 🔌 <b>Port</b>      : <code>$port</code>
│ 📡 <b>Obfs</b>      : <code>zivpn</code>
├────────────────────────────
│ 📦 <b>Kuota</b>     : $ql
│ 📅 <b>Expired</b>   : $e
│ ⏳ <b>Sisa</b>      : $sisa_str
└────────────────────────────

📱 Download <b>ZiVPN</b> di Play Store / App Store
⚠️ Jangan share akun ini ke orang lain!"
    local r; r=$(curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=${did}" -d "text=${msg}" -d "parse_mode=HTML")
    echo ""
    echo "$r" | grep -q '"ok":true' \
        && ok "Akun '${W}$u${NC}' berhasil dikirim ke Telegram!" \
        || err "Gagal kirim! Periksa Chat ID atau token."
    pause
}

tg_broadcast() {
    show_header
    _top; _btn "  ${IT}${AL}📢  BROADCAST PESAN${NC}"; _bot; echo ""
    [[ ! -f "$BOTF" ]] && { err "Bot belum dikonfigurasi!"; pause; return; }
    source "$BOTF" 2>/dev/null
    echo -e "  ${DIM}Ketik pesan. Ketik ${W}SELESAI${DIM} di baris baru untuk kirim.${NC}"; echo ""
    local msg="" line
    while IFS= read -r line; do
        [[ "$line" == "SELESAI" ]] && break
        msg+="$line
"
    done
    [[ -z "$msg" ]] && { err "Pesan kosong!"; pause; return; }
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}" -d "text=${msg}" &>/dev/null
    ok "Broadcast berhasil dikirim!"
    pause
}

tg_guide() {
    show_header
    _top; _btn "  ${IT}${AL}📖  PANDUAN BUAT BOT TELEGRAM${NC}"; _bot; echo ""
    echo -e "  ${A1}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "  ${A1}║${NC}  ${Y}LANGKAH 1 — Buat Bot di BotFather${NC}                      ${A1}║${NC}"
    echo -e "  ${A1}╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "  ${A1}║${NC}  ${W}1.${NC} Buka Telegram → cari ${A3}@BotFather${NC}                       ${A1}║${NC}"
    echo -e "  ${A1}║${NC}  ${W}2.${NC} Kirim perintah ${Y}/newbot${NC}                               ${A1}║${NC}"
    echo -e "  ${A1}║${NC}  ${W}3.${NC} Masukkan nama bot → contoh: ${W}OGH ZIV VPN${NC}              ${A1}║${NC}"
    echo -e "  ${A1}║${NC}  ${W}4.${NC} Masukkan username (akhiran ${Y}bot${NC})                       ${A1}║${NC}"
    echo -e "  ${A1}║${NC}  ${W}5.${NC} Salin ${Y}TOKEN${NC} yang diberikan BotFather               ${A1}║${NC}"
    echo -e "  ${A1}╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "  ${A1}║${NC}  ${Y}LANGKAH 2 — Ambil Chat ID${NC}                               ${A1}║${NC}"
    echo -e "  ${A1}╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "  ${A1}║${NC}  ${W}1.${NC} Kirim ${Y}/start${NC} ke bot kamu di Telegram               ${A1}║${NC}"
    echo -e "  ${A1}║${NC}  ${W}2.${NC} Buka: ${DIM}api.telegram.org/bot<TOKEN>/getUpdates${NC}       ${A1}║${NC}"
    echo -e "  ${A1}║${NC}  ${W}3.${NC} Cari nilai ${Y}\"id\"${NC} di bagian ${Y}\"from\"${NC}                  ${A1}║${NC}"
    echo -e "  ${A1}╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "  ${A1}║${NC}  ${Y}LANGKAH 3 — Hubungkan ke OGH-ZIV${NC}                        ${A1}║${NC}"
    echo -e "  ${A1}╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "  ${A1}║${NC}  ${W}1.${NC} Menu Telegram → ${A3}[1] Setup / Konfigurasi Bot${NC}         ${A1}║${NC}"
    echo -e "  ${A1}║${NC}  ${W}2.${NC} Masukkan Token dan Chat ID                           ${A1}║${NC}"
    echo -e "  ${A1}║${NC}  ${W}3.${NC} ${LG}✅ Selesai! Notifikasi otomatis aktif${NC}              ${A1}║${NC}"
    echo -e "  ${A1}╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "  ${A1}║${NC}  ${A3}https://t.me/BotFather${NC}                                   ${A1}║${NC}"
    echo -e "  ${A1}╚══════════════════════════════════════════════════════════╝${NC}"
    pause
}

# ════════════════════════════════════════════════════════════
#  SERVICE
# ════════════════════════════════════════════════════════════
svc_status() {
    show_header
    _top; _btn "  ${IT}${AL}🖥️   STATUS SERVICE${NC}"; _bot; echo ""
    systemctl status zivpn --no-pager -l
    pause
}

svc_bandwidth() {
    show_header
    _top; _btn "  ${IT}${AL}📊  BANDWIDTH / KONEKSI AKTIF${NC}"; _bot; echo ""
    local port; port=$(get_port)
    inf "Koneksi aktif ke port ${Y}$port${NC}:"; echo ""
    ss -u -n -p 2>/dev/null | grep ":$port" || inf "Tidak ada koneksi UDP aktif saat ini."
    echo ""
    inf "Statistik network interface:"
    cat /proc/net/dev 2>/dev/null | awk 'NR>2{
        split($1,a,":");gsub(/[[:space:]]/,"",a[1]);
        if(a[1]!="lo") printf "  %-12s RX: %-12s TX: %s\n", a[1], $2, $10
    }' | head -5
    pause
}

svc_log() {
    show_header
    _top; _btn "  ${IT}${AL}📄  LOG ZIVPN${NC}"; _bot; echo ""
    [[ -f "$LOG" ]] && tail -60 "$LOG" || journalctl -u zivpn -n 60 --no-pager
    pause
}

svc_port() {
    show_header
    _top; _btn "  ${IT}${AL}🔧  GANTI PORT${NC}"; _bot; echo ""
    local cp; cp=$(get_port)
    echo -e "  Port saat ini : ${Y}$cp${NC}"
    echo -ne "  ${A3}Port baru${NC}     : "; read -r np
    [[ ! "$np" =~ ^[0-9]+$ || $np -lt 1 || $np -gt 65535 ]] && { err "Port tidak valid!"; pause; return; }
    sed -i "s/\"listen\": *\":${cp}\"/\"listen\": \":${np}\"/" "$CFG"
    command -v ufw &>/dev/null && { ufw delete allow "$cp/udp" &>/dev/null; ufw allow "$np/udp" &>/dev/null; }
    iptables -D INPUT -p udp --dport "$cp" -j ACCEPT 2>/dev/null
    iptables -I INPUT -p udp --dport "$np" -j ACCEPT 2>/dev/null
    systemctl restart zivpn
    ok "Port diubah: ${Y}$cp${NC} → ${LG}$np${NC}"
    pause
}

svc_backup() {
    show_header
    _top; _btn "  ${IT}${AL}💾  BACKUP DATA${NC}"; _bot; echo ""
    local bfile="/root/oghziv-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    inf "Membuat backup → ${W}$bfile${NC}"
    tar -czf "$bfile" "$DIR" 2>/dev/null
    [[ $? -eq 0 ]] && ok "Backup berhasil: ${W}$bfile${NC}" || err "Backup gagal!"
    pause
}

svc_restore() {
    show_header
    _top; _btn "  ${IT}${AL}♻️   RESTORE DATA${NC}"; _bot; echo ""
    echo -ne "  ${A3}Path file backup (.tar.gz)${NC}: "; read -r bpath
    [[ ! -f "$bpath" ]] && { err "File tidak ditemukan!"; pause; return; }
    warn "Restore akan menimpa semua data saat ini!"
    echo -ne "  Lanjutkan? [y/N]: "; read -r cf
    [[ "$cf" != [yY] ]] && { inf "Dibatalkan."; pause; return; }
    tar -xzf "$bpath" -C / 2>/dev/null
    _reload_pw
    ok "Restore berhasil!"
    pause
}

# ════════════════════════════════════════════════════════════
#  DOMAIN MANAGEMENT
# ════════════════════════════════════════════════════════════
domain_set() {
    show_header
    _top; _btn "  ${IT}${AL}✏️   SET / GANTI DOMAIN${NC}"; _bot; echo ""
    local cur; cur=$(get_domain)
    local ip;  ip=$(get_ip)
    echo -e "  ${DIM}Domain saat ini : ${W}$cur${NC}"
    echo -e "  ${DIM}IP Publik VPS   : ${A3}$ip${NC}"; echo ""
    inf "Pastikan DNS domain sudah diarahkan ke IP: ${Y}$ip${NC}"
    echo ""
    echo -ne "  ${A3}Domain baru${NC} (kosongkan = pakai IP): "; read -r nd
    if [[ -z "$nd" ]]; then
        echo "$ip" > "$DOMF"; ok "Domain diatur ke IP publik: ${A3}$ip${NC}"
    else
        echo "$nd" > "$DOMF"; ok "Domain disimpan: ${W}$nd${NC}"
        echo -ne "  ${A3}Regenerasi SSL sekarang?${NC} [y/N]: "; read -r rs
        [[ "$rs" == [yY] ]] && domain_ssl
    fi
    pause
}

domain_use_ip() {
    show_header
    _top; _btn "  ${IT}${AL}🔄  GUNAKAN IP PUBLIK${NC}"; _bot; echo ""
    local ip; ip=$(get_ip)
    echo "$ip" > "$DOMF"
    ok "Domain direset ke IP publik: ${A3}$ip${NC}"
    pause
}

domain_check() {
    show_header
    _top; _btn "  ${IT}${AL}🔍  CEK DNS DOMAIN${NC}"; _bot; echo ""
    local dom; dom=$(get_domain)
    local ip;  ip=$(get_ip)
    echo -e "  ${DIM}Domain  : ${W}$dom${NC}"
    echo -e "  ${DIM}IP VPS  : ${A3}$ip${NC}"; echo ""
    inf "Resolving DNS..."
    local resolved
    resolved=$(host "$dom" 2>/dev/null | grep "has address" | awk '{print $NF}' | head -1)
    [[ -z "$resolved" ]] && resolved=$(nslookup "$dom" 2>/dev/null | awk '/^Address:/{print $2}' | grep -v '#' | head -1)
    if [[ -z "$resolved" ]]; then
        err "Tidak dapat meresolve domain: ${W}$dom${NC}"
    elif [[ "$resolved" == "$ip" ]]; then
        ok "DNS OK — ${W}$dom${NC} → ${A3}$resolved${NC} ${LG}(cocok dengan IP VPS)${NC}"
    else
        warn "DNS mismatch!"
        echo -e "  ${DIM}Domain resolve ke : ${LR}$resolved${NC}"
        echo -e "  ${DIM}IP VPS            : ${A3}$ip${NC}"
        inf "Arahkan DNS domain ke IP: ${Y}$ip${NC}"
    fi
    pause
}

domain_ssl() {
    show_header
    _top; _btn "  ${IT}${AL}🔄  REGENERASI SSL CERTIFICATE${NC}"; _bot; echo ""
    local dom; dom=$(get_domain)
    inf "Membuat SSL baru untuk: ${W}$dom${NC}"
    openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:P-256 \
        -keyout "$DIR/zivpn.key" -out "$DIR/zivpn.crt" \
        -subj "/CN=$dom" -days 3650 &>/dev/null \
        && ok "SSL Certificate (10 tahun) berhasil dibuat untuk ${W}$dom${NC}" \
        || { err "Gagal generate SSL!"; pause; return; }
    systemctl restart zivpn &>/dev/null
    ok "Service direstart dengan SSL baru."
    pause
}

menu_domain() {
    while true; do
        show_header
        local cur_domain; cur_domain=$(get_domain)
        local cur_ip;     cur_ip=$(get_ip)
        _top
        _btn "  ${IT}${AL}  🌐  MANAJEMEN DOMAIN${NC}"
        _sep
        printf "  ${A1}║${NC}  ${DIM}Domain aktif${NC} : ${W}%-36s${NC}  ${A1}║${NC}\n" "$cur_domain"
        printf "  ${A1}║${NC}  ${DIM}IP Publik   ${NC} : ${A3}%-36s${NC}  ${A1}║${NC}\n" "$cur_ip"
        _sep
        _btn "  ${A2}[1]${NC}  ✏️   Set / Ganti Domain"
        _sep
        _btn "  ${A2}[2]${NC}  🔄  Gunakan IP Publik (hapus domain)"
        _sep
        _btn "  ${A2}[3]${NC}  🔍  Cek DNS Domain"
        _sep
        _btn "  ${A2}[4]${NC}  🔐  Update SSL untuk Domain Baru"
        _sep
        _btn "  ${LR}[0]${NC}  ◀   Kembali"
        _bot; echo ""
        echo -ne "  ${A1}›${NC} "; read -r ch
        case $ch in
            1) domain_set ;;   2) domain_use_ip ;;
            3) domain_check ;; 4) domain_ssl ;;
            0) break ;; *) warn "Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}

do_uninstall() {
    show_header
    _top; _btn "  ${IT}${AL}⚠️   UNINSTALL OGH-ZIV${NC}"; _bot; echo ""
    warn "Semua data user & konfigurasi akan DIHAPUS PERMANEN!"
    echo -ne "  ${LR}Ketik 'HAPUS' untuk konfirmasi${NC}: "; read -r cf
    [[ "$cf" != "HAPUS" ]] && { inf "Dibatalkan."; pause; return; }
    systemctl stop    zivpn.service 2>/dev/null
    systemctl disable zivpn.service 2>/dev/null
    rm -f "$SVC" "$BIN"
    rm -rf "$DIR"
    systemctl daemon-reload 2>/dev/null

    # Hapus iptables rules
    local IFACE; IFACE=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
    while iptables -t nat -D PREROUTING         -i "$IFACE" -p udp --dport 6000:19999         -j DNAT --to-destination :5667 2>/dev/null; do :; done
    iptables -D FORWARD -p udp -d 127.0.0.1 --dport 5667 -j ACCEPT 2>/dev/null
    iptables -t nat -D POSTROUTING -s 127.0.0.1/32 -o "$IFACE" -j MASQUERADE 2>/dev/null
    netfilter-persistent save &>/dev/null

    # Hapus menu command
    rm -f /usr/local/bin/menu /usr/local/bin/ogh-ziv 2>/dev/null
    rm -f /etc/profile.d/ogh-ziv.sh 2>/dev/null
    sed -i "/alias menu=/d"  ~/.bashrc  2>/dev/null
    sed -i "/alias zivpn=/d" ~/.bashrc  2>/dev/null
    sed -i "/alias menu=/d"  /root/.profile 2>/dev/null

    ok "OGH-ZIV Premium berhasil diuninstall sepenuhnya."
    echo -e "  ${DIM}Semua binary, service, data, iptables & menu telah dihapus.${NC}"
    pause
    exit 0
}

# ════════════════════════════════════════════════════════════
#  MAXLOGIN MANAGEMENT
# ════════════════════════════════════════════════════════════
u_maxlogin() {
    show_header
    _top; _btn "  ${IT}${AL}🔒  SET MAXLOGIN DEVICE${NC}"; _bot; echo ""
    [[ ! -s "$UDB" ]] && { warn "Belum ada akun terdaftar."; pause; return; }
    echo ""
    echo -e "  ${A1}┌──────────────────────────────────────────────────────┐${NC}"
    printf  "  ${A1}│${NC}  ${DIM}%-20s  %-8s  %-10s${NC}  ${A1}│${NC}\n" "Username" "MaxDev" "Status"
    echo -e "  ${A1}├╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┤${NC}"
    while IFS='|' read -r u _ e _ _; do
        local ml; ml=$(get_maxlogin "$u"); [[ -z "$ml" ]] && ml="-"
        local today; today=$(date +%Y-%m-%d)
        local sc sl
        [[ "$e" < "$today" ]] && { sc="${LR}"; sl="EXPIRED"; } || { sc="${LG}"; sl="AKTIF  "; }
        printf "  ${A1}│${NC}  ${W}%-20s${NC}  ${Y}%-8s${NC}  ${sc}%-10s${NC}  ${A1}│${NC}\n" "$u" "$ml" "$sl"
    done < "$UDB"
    echo -e "  ${A1}└──────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -ne "  ${A3}Username${NC}          : "; read -r mu
    grep -q "^${mu}|" "$UDB" 2>/dev/null || { err "User tidak ditemukan!"; pause; return; }
    local cur_ml; cur_ml=$(get_maxlogin "$mu"); [[ -z "$cur_ml" ]] && cur_ml=2
    echo -e "  ${DIM}MaxLogin saat ini : ${Y}${cur_ml} device${NC}"
    echo -ne "  ${A3}Max Login Device${NC} [${cur_ml}]: "; read -r nml
    [[ -z "$nml" || ! "$nml" =~ ^[0-9]+$ ]] && nml="$cur_ml"
    set_maxlogin "$mu" "$nml"
    echo ""
    echo -e "  ${A1}┌──────────────┬───────────────────────────────────────────┤${NC}"
    echo -e "  ${A1}│${NC}  ${LG}✔  MaxLogin berhasil diatur!${NC}                          ${A1}│${NC}"
    echo -e "  ${A1}├──────────────┼───────────────────────────────────────────┤${NC}"
    printf  "  ${A1}│${NC} ${DIM} Username  ${NC} ${A1}│${NC}  ${W}%-41s${NC}  ${A1}│${NC}\n" "$mu"
    echo -e "  ${A1}├╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┤${NC}"
    printf  "  ${A1}│${NC} ${DIM} Max Dev   ${NC} ${A1}│${NC}  ${Y}%-41s${NC}  ${A1}│${NC}\n" "${nml} device"
    echo -e "  ${A1}├╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┤${NC}"
    printf  "  ${A1}│${NC} ${DIM} Info      ${NC} ${A1}│${NC}  ${DIM}%-41s${NC}  ${A1}│${NC}\n" "Auto-delete jika melebihi limit"
    echo -e "  ${A1}└──────────────┴───────────────────────────────────────────┘${NC}"
    # Setup cron untuk enforce maxlogin setiap 5 menit
    local cronline="*/5 * * * * bash /usr/local/bin/ogh-ziv --check-maxlogin >/dev/null 2>&1"
    (crontab -l 2>/dev/null | grep -q "check-maxlogin") || \
        (crontab -l 2>/dev/null; echo "$cronline") | crontab - 2>/dev/null
    pause
}

# ════════════════════════════════════════════════════════════
#  SUB MENUS
# ════════════════════════════════════════════════════════════
menu_akun() {
    while true; do
        show_header
        _top
        _btn "  ${IT}${AL}  👤  KELOLA AKUN USER${NC}"
        _sep; _btn "  ${A2}[1]${NC}  ➕  Tambah Akun Baru"
        _sep; _btn "  ${A2}[2]${NC}  📋  List Semua Akun"
        _sep; _btn "  ${A2}[3]${NC}  🔍  Detail Akun"
        _sep; _btn "  ${A2}[4]${NC}  🗑️   Hapus Akun"
        _sep; _btn "  ${A2}[5]${NC}  🔁  Perpanjang Akun"
        _sep; _btn "  ${A2}[6]${NC}  🔑  Ganti Password"
        _sep; _btn "  ${A2}[7]${NC}  🎁  Buat Akun Trial"
        _sep; _btn "  ${A2}[8]${NC}  🧹  Hapus Akun Expired"
        _sep; _btn "  ${A2}[9]${NC}  🔒  Set MaxLogin Device"
        _sep; _btn "  ${LR}[0]${NC}  ◀   Kembali"
        _bot; echo ""
        echo -ne "  ${A1}›${NC} "; read -r ch
        case $ch in
            1) u_add ;;  2) u_list ;; 3) u_info ;;
            4) u_del ;;  5) u_renew ;; 6) u_chpass ;;
            7) u_trial ;; 8) u_clean ;; 9) u_maxlogin ;;
            0) break ;; *) warn "Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}

menu_jualan() {
    while true; do
        show_header
        [[ -f "$STRF" ]] && source "$STRF" 2>/dev/null
        _top
        _btn "  ${IT}${AL}  🛒  MENU JUALAN${NC}"
        _sep; _btn "  ${A2}[1]${NC}  📨  Template Pesan Akun"
        _sep; _btn "  ${A2}[2]${NC}  📤  Kirim Akun via Telegram"
        _sep; _btn "  ${A2}[3]${NC}  ⚙️   Pengaturan Toko"
        _sep; _btn "  ${LR}[0]${NC}  ◀   Kembali"
        _bot; echo ""
        printf "  ${DIM}Brand: ${AL}%-20s${DIM}  TG: @%s${NC}\n" "${BRAND:-OGH-ZIV}" "${ADMIN_TG:--}"
        echo ""
        echo -ne "  ${A1}›${NC} "; read -r ch
        case $ch in
            1) t_akun ;; 2) tg_kirim_akun ;; 3) set_store ;;
            0) break ;; *) warn "Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}

menu_telegram() {
    while true; do
        show_header
        local bstat="${LR}Belum dikonfigurasi${NC}"
        [[ -f "$BOTF" ]] && { source "$BOTF" 2>/dev/null; bstat="${LG}@${BOT_NAME}${NC}"; }
        _top
        _btn "  ${IT}${AL}  🤖  TELEGRAM BOT${NC}"
        _sep
        printf "  ${A1}║${NC}  ${DIM}Status :${NC} $bstat\n"
        _sep; _btn "  ${A2}[1]${NC}  🔧  Setup / Konfigurasi Bot"
        _sep; _btn "  ${A2}[2]${NC}  📡  Cek Status Bot"
        _sep; _btn "  ${A2}[3]${NC}  📤  Kirim Akun ke Telegram"
        _sep; _btn "  ${A2}[4]${NC}  📢  Broadcast Pesan"
        _sep; _btn "  ${A2}[5]${NC}  📖  Panduan Buat Bot"
        _sep; _btn "  ${LR}[0]${NC}  ◀   Kembali"
        _bot; echo ""
        echo -ne "  ${A1}›${NC} "; read -r ch
        case $ch in
            1) tg_setup ;; 2) tg_status ;; 3) tg_kirim_akun ;;
            4) tg_broadcast ;; 5) tg_guide ;;
            0) break ;; *) warn "Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}

menu_service() {
    while true; do
        show_header
        _top
        _btn "  ${IT}${AL}  ⚙️   MANAJEMEN SERVICE${NC}"
        _sep; _btn "  ${A2}[1]${NC}  🖥️   Status Service"
        _sep; _btn "  ${A2}[2]${NC}  ▶️   Start ZiVPN"
        _sep; _btn "  ${A2}[3]${NC}  ⏹️   Stop ZiVPN"
        _sep; _btn "  ${A2}[4]${NC}  🔄  Restart ZiVPN"
        _sep; _btn "  ${A2}[5]${NC}  📄  Lihat Log"
        _sep; _btn "  ${A2}[6]${NC}  🔧  Ganti Port"
        _sep; _btn "  ${A2}[7]${NC}  🌐  Manajemen Domain"
        _sep; _btn "  ${A2}[8]${NC}  💾  Backup Data"
        _sep; _btn "  ${A2}[9]${NC}  ♻️   Restore Data"
        _sep; _btn "  ${LR}[0]${NC}  ◀   Kembali"
        _bot; echo ""
        echo -ne "  ${A1}›${NC} "; read -r ch
        case $ch in
            1) svc_status ;;
            2) systemctl start zivpn;   ok "ZiVPN dijalankan.";  pause ;;
            3) systemctl stop zivpn;    ok "ZiVPN dihentikan.";  pause ;;
            4) systemctl restart zivpn; sleep 1
               is_up && ok "Restart berhasil!" || err "Gagal restart!"; pause ;;
            5) svc_log ;;
            6) svc_port ;;
            7) menu_domain ;;
            8) svc_backup ;;
            9) svc_restore ;;
            0) break ;; *) warn "Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}

# ════════════════════════════════════════════════════════════
#  MENU UTAMA  — HTML Panel Style
# ════════════════════════════════════════════════════════════
main_menu() {
    while true; do
        show_header

        # ── Menu Header ──────────────────────────────────────
        echo -e "  ${A1}╔══════════════════════════════════════════════════════════╗${NC}"
        printf  "  ${A1}║${NC}  ${A1}◈${NC}─────────── ${BLD}${AL}  OGH-ZIV PREMIUM PANEL  ${NC}───────────${A1}◈${NC}  ${A1}║${NC}\n"
        echo -e "  ${A1}╠══════════════════════════════════════════════════════════╣${NC}"

        # ── Menu Items ───────────────────────────────────────
        printf  "  ${A1}║${NC}  ${A2}[1]${NC}  👤  %-40s  ${A1}║${NC}\n" "Kelola Akun User"
        echo -e "  ${A1}╠╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╣${NC}"
        printf  "  ${A1}║${NC}  ${A2}[2]${NC}  ⚙️   %-40s  ${A1}║${NC}\n" "Manajemen Service"
        echo -e "  ${A1}╠╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╣${NC}"
        printf  "  ${A1}║${NC}  ${A2}[3]${NC}  🤖  %-40s  ${A1}║${NC}\n" "Telegram Bot"
        echo -e "  ${A1}╠╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╣${NC}"
        printf  "  ${A1}║${NC}  ${A2}[4]${NC}  🛒  %-40s  ${A1}║${NC}\n" "Menu Jualan"
        echo -e "  ${A1}╠╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╣${NC}"
        printf  "  ${A1}║${NC}  ${A2}[5]${NC}  📊  %-40s  ${A1}║${NC}\n" "Bandwidth & Koneksi"
        echo -e "  ${A1}╠╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╣${NC}"
        printf  "  ${A1}║${NC}  ${A2}[6]${NC}  🔄  %-40s  ${A1}║${NC}\n" "Restart Service"
        echo -e "  ${A1}╠╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╣${NC}"
        printf  "  ${A1}║${NC}  ${A2}[7]${NC}  🚀  %-40s  ${A1}║${NC}\n" "Install ZiVPN"
        echo -e "  ${A1}╠╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╣${NC}"
        printf  "  ${A1}║${NC}  ${A2}[8]${NC}  🌐  %-40s  ${A1}║${NC}\n" "Manajemen Domain"
        echo -e "  ${A1}╠╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╣${NC}"
        printf  "  ${A1}║${NC}  ${A2}[9]${NC}  🎨  %-40s  ${A1}║${NC}\n" "Ganti Tema  [ ${THEME_NAME} ]"

        # ── Divider ──────────────────────────────────────────
        echo -e "  ${A1}╠══════════════════════════════════════════════════════════╣${NC}"

        # ── Danger / Exit ────────────────────────────────────
        printf  "  ${A1}║${NC}  ${LR}[E]${NC}  🗑️   %-40s  ${A1}║${NC}\n" "Uninstall ZiVPN"
        echo -e "  ${A1}╠╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╣${NC}"
        printf  "  ${A1}║${NC}  ${A4}[0]${NC}  ✖   %-40s  ${A1}║${NC}\n" "Keluar"

        # ── Footer ───────────────────────────────────────────
        echo -e "  ${A1}╠══════════════════════════════════════════════════════════╣${NC}"
        printf  "  ${A1}║${NC}  ${DIM}›${NC}                                        ${DIM}OGH-ZIV v1.0 PREMIUM${NC}  ${A1}║${NC}\n"
        echo -e "  ${A1}╚══════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -ne "  ${A1}›${NC} Pilih menu: "; read -r ch
        case ${ch,,} in
            1) menu_akun ;;
            2) menu_service ;;
            3) menu_telegram ;;
            4) menu_jualan ;;
            5) svc_bandwidth ;;
            6) systemctl restart zivpn; sleep 1
               is_up && ok "Service berhasil direstart!" || err "Gagal restart!"; pause ;;
            7) do_install ;;
            8) menu_domain ;;
            9) menu_tema ;;
            e) do_uninstall ;;
            0) echo -e "\n  ${IT}${AL}Sampai jumpa! — OGH-ZIV Premium${NC}\n"; exit 0 ;;
            *) warn "Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}

# ════════════════════════════════════════════════════════════
#  SETUP COMMAND 'menu'
# ════════════════════════════════════════════════════════════
setup_menu_cmd() {
    local sp; sp=$(realpath "$0" 2>/dev/null || echo "$0")

    # Salin script ke lokasi permanen
    if [[ "$sp" != "/usr/local/bin/ogh-ziv" ]]; then
        cp "$0" /usr/local/bin/ogh-ziv 2>/dev/null
        chmod +x /usr/local/bin/ogh-ziv 2>/dev/null
    fi

    # Symlink /usr/local/bin/menu → ogh-ziv (bisa langsung ketik: menu)
    ln -sf /usr/local/bin/ogh-ziv /usr/local/bin/menu 2>/dev/null
    chmod +x /usr/local/bin/menu 2>/dev/null

    # Tambah ke ~/.bashrc (user root saat ini)
    grep -q "alias menu=" ~/.bashrc 2>/dev/null ||         echo "alias menu='bash /usr/local/bin/ogh-ziv'" >> ~/.bashrc

    # Tambah ke /root/.profile (login shell)
    grep -q "alias menu=" /root/.profile 2>/dev/null ||         echo "alias menu='bash /usr/local/bin/ogh-ziv'" >> /root/.profile

    # Tambah ke /etc/profile.d/ supaya aktif global di semua user & login baru
    cat > /etc/profile.d/ogh-ziv.sh << 'PROFEOF'
#!/bin/bash
alias menu='bash /usr/local/bin/ogh-ziv'
alias zivpn='bash /usr/local/bin/ogh-ziv'
PROFEOF
    chmod +x /etc/profile.d/ogh-ziv.sh 2>/dev/null
}

# ════════════════════════════════════════════════════════════
#  MAIN
# ════════════════════════════════════════════════════════════
check_os
check_root
mkdir -p "$DIR"
load_theme

# Handle CLI flags
if [[ "${1:-}" == "--check-maxlogin" ]]; then
    check_maxlogin_all
    exit 0
fi

setup_menu_cmd 2>/dev/null
main_menu
