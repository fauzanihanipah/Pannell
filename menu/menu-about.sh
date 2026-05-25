#!/bin/bash
# ALL PRO - About
source /etc/allpro/lib-common.sh
show_header
_top; _btn "  ${IT}${AL}📋  ABOUT ALL PRO${NC}"; _bot
_btn "  ${BLD}${AL}ALL PRO Premium Tunneling Panel${NC}"
_btn "  ${DIM}Version : ${W}1.0.0${NC}"
_btn "  ${DIM}OS      : ${W}Debian / Ubuntu${NC}"
_sep
_btn "  ${A4}Protocols Supported:${NC}"
_btn "  ${A2}•${NC} SSH / OpenSSH (22, 442)"
_btn "  ${A2}•${NC} Dropbear (109, 143)"
_btn "  ${A2}•${NC} Stunnel SSL (443, 777)"
_btn "  ${A2}•${NC} SSH WS CDN TLS / NTLS (443 / 80, path /ssh-ws)"
_btn "  ${A2}•${NC} Xray VMess WS TLS+NTLS (443 / 80)"
_btn "  ${A2}•${NC} Xray VLess WS TLS+NTLS (443 / 80)"
_btn "  ${A2}•${NC} Xray Trojan WS+gRPC TLS (443)"
_btn "  ${A2}•${NC} Trojan-Go (port 2087, /trojango-ws)"
_btn "  ${A2}•${NC} Hysteria 2 (UDP 8443, range 20000-50000)"
_btn "  ${A2}•${NC} SlowDNS (UDP 53 → 5300, NS-mode)"
_btn "  ${A2}•${NC} BadVPN UDPGW (7100/7200/7300)"
_btn "  ${A2}•${NC} OHP Server (8080 HTTP / 8443 SSL)"
_sep
_btn "  ${DIM}Brand   : ${W}$(get_brand)${NC}"
_btn "  ${DIM}Domain  : ${W}$(get_domain)${NC}"
_btn "  ${DIM}IP VPS  : ${W}$(get_ip)${NC}"
_bot
pause
