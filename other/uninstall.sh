#!/bin/bash
# ALL PRO - Uninstall (mempertahankan akun system)
RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
echo ""
echo -e "  ${YELLOW}⚠  Yakin uninstall ALL PRO Panel?${NC} (data akan dihapus!)"
echo -ne "  Ketik ${RED}YA${NC} untuk konfirmasi: "; read -r c
[[ "$c" != "YA" ]] && { echo "Dibatalkan"; exit 0; }

# Stop & disable services
for s in xray trojan-go hysteria-server slowdns ws ohp badvpn stunnel4; do
    systemctl stop "$s" 2>/dev/null
    systemctl disable "$s" 2>/dev/null
    rm -f "/etc/systemd/system/$s.service"
done
systemctl daemon-reload

# Hapus binary
rm -f /usr/local/bin/{xray,hysteria,trojan-go,badvpn-udpgw,sldns-server,ohpserver,ws}

# Hapus config dir
rm -rf /etc/allpro /etc/xray /etc/trojan-go /etc/hysteria /etc/slowdns
rm -f /etc/nginx/conf.d/allpro-*.conf

# Hapus menu commands
rm -f /usr/local/sbin/menu*

# Restart nginx supaya bersih
systemctl restart nginx 2>/dev/null

echo -e "  ${GREEN}✔${NC}  ALL PRO Panel berhasil di-uninstall"
echo -e "  ${YELLOW}Note: SSH/Dropbear/Stunnel tetap aktif (system service).${NC}"
