#!/bin/bash
# ALL PRO - Auto cleanup expired user (jalankan via cron harian)
ALLPRO_DIR="/etc/allpro"
TODAY=$(date +%Y-%m-%d)

# SSH
if [[ -f "$ALLPRO_DIR/ssh.db" ]]; then
    while IFS='|' read -r u p e; do
        [[ "$e" < "$TODAY" ]] && {
            userdel -f "$u" &>/dev/null
            sed -i "/^${u}|/d" "$ALLPRO_DIR/ssh.db"
        }
    done < "$ALLPRO_DIR/ssh.db"
fi

# Xray (vmess/vless/trojan) — hapus dari config & DB
for proto in vmess vless trojan; do
    DB="$ALLPRO_DIR/${proto}.db"
    [[ ! -f "$DB" ]] && continue
    while IFS='|' read -r u id e; do
        if [[ "$e" < "$TODAY" ]]; then
            sed -i "/^${u}|/d" "$DB"
            python3 - <<PY 2>/dev/null
import json
with open("/etc/xray/config.json") as f: c=json.load(f)
for ib in c["inbounds"]:
    if ib["protocol"]=="$proto":
        if "$proto"=="trojan":
            ib["settings"]["clients"]=[x for x in ib["settings"]["clients"] if x.get("password")!="$id"]
        else:
            ib["settings"]["clients"]=[x for x in ib["settings"]["clients"] if x.get("id")!="$id"]
with open("/etc/xray/config.json","w") as f: json.dump(c,f,indent=2)
PY
        fi
    done < "$DB"
done
systemctl restart xray 2>/dev/null

# Trojan-Go & Hysteria 2 — hapus dari DB (config rebuild via menu)
for proto in trojango hy2; do
    DB="$ALLPRO_DIR/${proto}.db"
    [[ ! -f "$DB" ]] && continue
    awk -F'|' -v t="$TODAY" '$3>=t' "$DB" > "$DB.tmp" && mv "$DB.tmp" "$DB"
done
systemctl restart trojan-go hysteria-server 2>/dev/null
