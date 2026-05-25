# ALL PRO — Premium Tunneling Panel

Panel tunneling all-in-one untuk **Debian / Ubuntu** dengan dukungan SSH, V2Ray, Trojan-Go, Hysteria 2, SlowDNS, dan SSH WS CDN TLS/NTLS.

## Fitur

- **SSH / OpenSSH** — port `22`, `442`
- **Dropbear** — port `109`, `143`
- **Stunnel SSL** — port `443`, `777`
- **SSH WS CDN TLS / NTLS** — port `443` (TLS) & `80` (NTLS), path `/ssh-ws` — Cloudflare-friendly
- **Xray VMess** — WS TLS (`443/vmess`) + WS NTLS (`80/vmess-ntls`)
- **Xray VLess** — WS TLS (`443/vless`) + WS NTLS (`80/vless-ntls`)
- **Xray Trojan** — WS TLS (`443/trojan-ws`) + gRPC TLS (`trojan-grpc`)
- **Trojan-Go** — port `2087` (WS path `/trojango-ws`)
- **Hysteria 2** — UDP `8443`, range `20000-50000`
- **SlowDNS** — UDP `53` → `5300`, NS-mode
- **BadVPN UDPGW** — `7100`, `7200`, `7300`
- **OHP Server** — `8080` (HTTP), `8443` (SSL)
- **Auto-cleanup expired** — cron harian

## Instalasi

```bash
wget https://raw.githubusercontent.com/fauzanihanipah/Pannell/main/setup.sh
chmod +x setup.sh
bash setup.sh
```

Atau langsung:

```bash
bash <(curl -s https://raw.githubusercontent.com/fauzanihanipah/Pannell/main/setup.sh)
```

## Penggunaan

Setelah install, ketik:

```bash
menu
```

untuk membuka panel ALL PRO.

## Struktur Repo

```
Pannell/
├── setup.sh               # Main installer
├── menu/                  # Semua menu (Bash)
│   ├── lib-common.sh      # Library bersama (theme, helpers, header)
│   ├── menu.sh            # Main menu
│   ├── menu-ssh.sh        # SSH user manager
│   ├── menu-xray.sh       # Xray submenu selector
│   ├── menu-vmess.sh      # VMess (Xray)
│   ├── menu-vless.sh      # VLess (Xray)
│   ├── menu-trojan.sh     # Trojan (Xray)
│   ├── menu-trojango.sh   # Trojan-Go
│   ├── menu-hy2.sh        # Hysteria 2
│   ├── menu-slowdns.sh    # SlowDNS info
│   ├── menu-system.sh     # System tools
│   ├── menu-backup.sh     # Backup & Restore
│   ├── menu-tema.sh       # Pilih tema warna
│   ├── menu-pengaturan.sh # Settings (brand, domain, admin)
│   └── menu-about.sh      # About
├── ssh/install-ssh.sh
├── xray/install-xray.sh
├── trojan-go/install-trojango.sh
├── hysteria2/install-hy2.sh
└── other/
    ├── install-slowdns.sh
    ├── install-fail2ban.sh
    ├── clean-expired.sh
    └── uninstall.sh
```

## Binary URLs

Panel ini menggunakan binary dari `chanelog/max`:

| Binary           | URL                                                                                    |
|------------------|----------------------------------------------------------------------------------------|
| Xray             | `https://github.com/chanelog/max/releases/download/bin/Xray-linux-64.zip`              |
| Hysteria 2       | `https://github.com/chanelog/max/releases/download/bin/hysteria-linux-amd64`           |
| Trojan-Go        | `https://github.com/chanelog/max/releases/download/bin/trojan-go-linux-amd64.zip`      |
| BadVPN UDPGW     | `https://raw.githubusercontent.com/chanelog/max/main/udpgw`                            |
| SlowDNS          | `https://github.com/chanelog/max/raw/main/sldns-server`                                |
| OHP              | `https://github.com/chanelog/max/raw/main/ohpserver`                                   |
| WS proxy         | `https://raw.githubusercontent.com/chanelog/max/main/ws`                               |
| WS service file  | `https://raw.githubusercontent.com/chanelog/max/main/ws.service`                       |

## Uninstall

```bash
bash /etc/allpro/uninstall.sh
```
