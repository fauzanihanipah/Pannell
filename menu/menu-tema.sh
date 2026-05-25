#!/bin/bash
# ALL PRO - Tema warna
source /etc/allpro/lib-common.sh

while true; do
    show_header
    _top; _btn "  ${IT}${AL}🎨  PILIH TEMA WARNA${NC}"; _bot
    local cur; cur=$(cat "$THEMEF" 2>/dev/null || echo 1)
    _btn "  ${A2}[1]${NC}  💜  VIOLET        (default)"
    _btn "  ${A2}[2]${NC}  🩵  ARCTIC CYAN"
    _btn "  ${A2}[3]${NC}  💚  MATRIX GREEN"
    _btn "  ${A2}[4]${NC}  💛  ROYAL GOLD"
    _btn "  ${A2}[5]${NC}  ❤️   CRIMSON RED"
    _btn "  ${A2}[6]${NC}  🩷  SAKURA PINK"
    _btn "  ${A2}[7]${NC}  🌊  OCEAN BLUE"
    _sep
    _btn "  ${DIM}Tema aktif: ${AL}${THEME_NAME}${NC} (#${cur})"
    _btn "  ${LR}[0]${NC}  ◀   Kembali"
    _bot
    echo -ne "  ${A1}›${NC} "; read -r ch
    case "$ch" in
        [1-7]) echo "$ch" > "$THEMEF"; ok "Tema diubah"; sleep 1 ;;
        0) break ;;
        *) warn "Invalid"; sleep 1 ;;
    esac
done
