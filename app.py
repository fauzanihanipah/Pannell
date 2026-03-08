#!/usr/bin/env python3
# ============================================================
#   OGH-ZIV Web Panel — Backend Lengkap
#   Gabungan ogh-ziv.sh + Web Panel
#   Jalankan : python3 app.py
#   Browser  : http://IP_VPS:8080
#   Default  : admin / oghziv123
# ============================================================

import os, json, subprocess, hashlib, secrets, threading, time, queue
from datetime import datetime, timedelta
from functools import wraps
from flask import Flask, request, jsonify, session, send_from_directory, Response, stream_with_context

app = Flask(__name__, static_folder='.', static_url_path='')
app.secret_key = secrets.token_hex(32)

# ── PATHS (sama persis dengan ogh-ziv.sh) ───────────────────
DIR    = "/etc/zivpn"
CFG    = f"{DIR}/config.json"
BIN    = "/usr/local/bin/zivpn-bin"
SVC    = "/etc/systemd/system/zivpn.service"
LOG    = f"{DIR}/zivpn.log"
UDB    = f"{DIR}/users.db"
DOMF   = f"{DIR}/domain.conf"
BOTF   = f"{DIR}/bot.conf"
STRF   = f"{DIR}/store.conf"
THEMEF = f"{DIR}/theme.conf"
MLDB   = f"{DIR}/maxlogin.db"
AUTH_F = f"{DIR}/webpanel.auth"

BINARY_URL = "https://github.com/fauzanihanipah/ziv-udp/releases/download/udp-zivpn/udp-zivpn-linux-amd64"
CONFIG_URL = "https://raw.githubusercontent.com/fauzanihanipah/ziv-udp/main/config.json"

PANEL_USER         = "admin"
PANEL_PASS_DEFAULT = "oghziv123"

install_log_queue = queue.Queue()
install_running   = False

# ════════════════════════════════════════════════════════════
#  AUTH
# ════════════════════════════════════════════════════════════
def get_panel_pass():
    try:
        if os.path.exists(AUTH_F):
            return open(AUTH_F).read().strip()
    except: pass
    return hashlib.sha256(PANEL_PASS_DEFAULT.encode()).hexdigest()

def hash_pass(p):
    return hashlib.sha256(p.encode()).hexdigest()

def login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if not session.get('logged_in'):
            return jsonify({'error': 'Unauthorized'}), 401
        return f(*args, **kwargs)
    return decorated

# ════════════════════════════════════════════════════════════
#  UTILS
# ════════════════════════════════════════════════════════════
def run(cmd, timeout=30):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return r.stdout.strip(), r.stderr.strip(), r.returncode
    except subprocess.TimeoutExpired:
        return '', 'Timeout', 1
    except Exception as e:
        return '', str(e), 1

def get_ip():
    out, _, _ = run("curl -s4 --max-time 5 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}'")
    return out.strip() or '0.0.0.0'

def get_port():
    try:
        with open(CFG) as f: c = json.load(f)
        return c.get('listen', ':5667').lstrip(':').split(':')[-1]
    except: return '5667'

def get_domain():
    try: return open(DOMF).read().strip()
    except: return get_ip()

def is_up():
    _, _, rc = run("systemctl is-active --quiet zivpn")
    return rc == 0

def is_installed():
    return os.path.exists(BIN) and os.path.exists(CFG)

def total_user():
    try:
        with open(UDB) as f: return sum(1 for l in f if l.strip())
    except: return 0

def exp_count():
    today = datetime.now().strftime('%Y-%m-%d')
    cnt = 0
    try:
        with open(UDB) as f:
            for line in f:
                p = line.strip().split('|')
                if len(p) >= 3 and p[2] < today: cnt += 1
    except: pass
    return cnt

def read_conf(path):
    conf = {}
    try:
        with open(path) as f:
            for line in f:
                if '=' in line:
                    k, v = line.strip().split('=', 1)
                    conf[k.strip()] = v.strip()
    except: pass
    return conf

def get_maxlogin(user):
    try:
        with open(MLDB) as f:
            for line in f:
                p = line.strip().split('|')
                if len(p) >= 2 and p[0] == user: return p[1]
    except: pass
    return '2'

def set_maxlogin(user, ml):
    lines = []
    try:
        with open(MLDB) as f:
            lines = [l for l in f if not l.startswith(f"{user}|")]
    except: pass
    lines.append(f"{user}|{ml}\n")
    os.makedirs(DIR, exist_ok=True)
    with open(MLDB, 'w') as f: f.writelines(lines)

def del_maxlogin(user):
    try:
        with open(MLDB) as f: lines = [l for l in f if not l.startswith(f"{user}|")]
        with open(MLDB, 'w') as f: f.writelines(lines)
    except: pass

def reload_pw():
    try:
        with open(UDB) as f: pws = [l.split('|')[1] for l in f if l.strip()]
        with open(CFG) as f: c = json.load(f)
        c['auth']['config'] = pws
        with open(CFG, 'w') as f: json.dump(c, f, indent=2)
        run("systemctl restart zivpn")
    except: pass

def rand_pass(n=12):
    import random, string
    return ''.join(random.choices(string.ascii_letters + string.digits, k=n))

def vps_stats():
    cpu, _, _  = run("top -bn1 | grep 'Cpu(s)' | awk '{printf \"%.1f\",$2}'")
    ram, _, _  = run("free -m | awk '/^Mem/{print $3\"|\"$2}'")
    disk, _, _ = run("df -h / | awk 'NR==2{print $3\"|\"$2\"|\"$5}'")
    os_n, _, _ = run(". /etc/os-release 2>/dev/null && echo \"$PRETTY_NAME\"")
    hn, _, _   = run("hostname")
    up, _, _   = run("uptime -p 2>/dev/null || uptime")
    net, _, _  = run("cat /proc/net/dev | awk 'NR>2{split($1,a,\":\");if(a[1]!=\"lo\"){printf a[1]\"|\"$2\"|\"$10\"\\n\"}}'")
    rp = ram.split('|') if ram else ['0','1']
    dp = disk.split('|') if disk else ['0','0','0%']
    ru = int(rp[0]) if rp[0].isdigit() else 0
    rt = int(rp[1]) if len(rp)>1 and rp[1].isdigit() else 1
    rpc = round(ru*100/rt) if rt else 0
    dpc = int(dp[2].replace('%','')) if len(dp)>2 else 0
    nets = []
    for line in net.split('\n'):
        if '|' in line:
            p = line.split('|')
            if len(p)==3: nets.append({'iface':p[0],'rx':p[1],'tx':p[2]})
    return {'cpu':cpu or '0.0','ram_used':ru,'ram_total':rt,'ram_pct':rpc,
            'disk_used':dp[0],'disk_total':dp[1],'disk_pct':dpc,
            'os':os_n or 'Linux','hostname':hn or 'vps','uptime':up or '-','network':nets}

def tg_send(msg):
    conf = read_conf(BOTF); tok = conf.get('BOT_TOKEN',''); cid = conf.get('CHAT_ID','')
    if not tok or not cid: return
    import urllib.request, urllib.parse
    try:
        url = f"https://api.telegram.org/bot{tok}/sendMessage"
        payload = urllib.parse.urlencode({'chat_id':cid,'text':msg,'parse_mode':'HTML'}).encode()
        urllib.request.urlopen(url, data=payload, timeout=8)
    except: pass

# ════════════════════════════════════════════════════════════
#  INSTALL THREAD — Streaming realtime ke browser via SSE
# ════════════════════════════════════════════════════════════
def _log(msg, t='info'):
    install_log_queue.put(json.dumps({'type': t, 'msg': msg}))

def _run_stream(cmd, desc=''):
    if desc: _log(f"  ▶ {desc}", 'step')
    try:
        proc = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, bufsize=1)
        for line in proc.stdout:
            line = line.rstrip()
            if line: _log(f"    {line}")
        proc.wait()
        return proc.returncode == 0
    except Exception as e:
        _log(f"  ✘ Error: {e}", 'err')
        return False

def do_install_thread(domain, port, brand, tg_admin):
    global install_running
    install_running = True
    try:
        _log('══════════════════════════════════════════════════', 'sep')
        _log('   OGH-ZIV PREMIUM — INSTALL ZIVPN', 'title')
        _log('══════════════════════════════════════════════════', 'sep')
        _log(f'  Domain   : {domain}')
        _log(f'  Port     : {port}')
        _log(f'  Brand    : {brand}')
        _log('')

        # Bersihkan file lama
        _log('  ── [1/8] Membersihkan file lama...', 'step')
        run("systemctl stop zivpn.service 2>/dev/null")
        run("systemctl disable zivpn.service 2>/dev/null")
        for f in [BIN, SVC, f"{DIR}/zivpn.key", f"{DIR}/zivpn.crt",
                  CFG, LOG]:
            try: os.remove(f)
            except: pass
        run("systemctl daemon-reload 2>/dev/null")
        _log('  ✔ File lama dibersihkan', 'ok')

        # Dependensi
        _log('  ── [2/8] Install dependensi...', 'step')
        _run_stream("apt-get update -q 2>&1 | tail -2")
        _run_stream("apt-get install -y -q curl wget openssl python3 iptables iptables-persistent netfilter-persistent 2>&1 | tail -3")
        _log('  ✔ Dependensi terpasang', 'ok')

        # Direktori
        _log('  ── [3/8] Setup direktori & konfigurasi...', 'step')
        os.makedirs(DIR, exist_ok=True)
        open(UDB, 'a').close(); open(LOG, 'a').close()
        with open(DOMF,'w') as f: f.write(domain)
        with open(THEMEF,'w') as f: f.write('7')
        with open(STRF,'w') as f: f.write(f"BRAND={brand}\nADMIN_TG={tg_admin}\n")
        _log('  ✔ Direktori & konfigurasi dibuat', 'ok')

        # Download binary
        _log('  ── [4/8] Download binary ZiVPN...', 'step')
        _log(f'  URL: {BINARY_URL}')
        ok_bin = _run_stream(f'wget "{BINARY_URL}" -O "{BIN}" 2>&1', 'Downloading...')
        if not ok_bin or not os.path.exists(BIN) or os.path.getsize(BIN) == 0:
            _log('  ✘ GAGAL download binary ZiVPN!', 'err')
            _log(f'  Coba manual: wget {BINARY_URL} -O {BIN}', 'warn')
            _log('INSTALL_FAILED', 'done')
            install_running = False
            return
        run(f"chmod +x {BIN}")
        sz = os.path.getsize(BIN)
        _log(f'  ✔ Binary ZiVPN siap ({sz//1024} KB)', 'ok')

        # Download config.json
        _log('  ── [5/8] Download config.json...', 'step')
        ok_cfg = _run_stream(f'wget -q "{CONFIG_URL}" -O "{CFG}" 2>&1', 'Downloading config...')
        if not ok_cfg or not os.path.exists(CFG) or os.path.getsize(CFG) == 0:
            _log('  ⚠ config.json tidak bisa diunduh, membuat manual...', 'warn')
            cfg_data = {"listen":f":{port}","cert":f"{DIR}/zivpn.crt",
                        "key":f"{DIR}/zivpn.key","obfs":"zivpn",
                        "auth":{"mode":"passwords","config":[]}}
            with open(CFG,'w') as f: json.dump(cfg_data, f, indent=2)
        else:
            try:
                with open(CFG) as f: c = json.load(f)
                c['listen'] = f':{port}'
                with open(CFG,'w') as f: json.dump(c, f, indent=2)
            except: pass
        _log(f'  ✔ config.json siap (port: {port})', 'ok')

        # SSL Certificate
        _log('  ── [6/8] Generate SSL Certificate RSA-4096...', 'step')
        ssl_cmd = (f'openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 '
                   f'-subj "/C=US/ST=California/L=Los Angeles/O=Example Corp/OU=IT/CN=zivpn" '
                   f'-keyout "{DIR}/zivpn.key" -out "{DIR}/zivpn.crt" 2>&1')
        _run_stream(ssl_cmd, 'Generating SSL...')
        if os.path.exists(f"{DIR}/zivpn.crt"):
            _log('  ✔ SSL Certificate RSA-4096 (1 tahun) dibuat', 'ok')
        else:
            _log('  ⚠ SSL warning, lanjutkan...', 'warn')

        # Optimasi UDP
        run("sysctl -w net.core.rmem_max=16777216 2>/dev/null")
        run("sysctl -w net.core.wmem_max=16777216 2>/dev/null")
        _log('  ✔ Buffer UDP dioptimasi (16MB)', 'ok')

        # Systemd service
        _log('  ── [7/8] Membuat systemd service...', 'step')
        svc_content = (f"[Unit]\nDescription=zivpn VPN Server\nAfter=network.target\n\n"
                       f"[Service]\nType=simple\nUser=root\nWorkingDirectory={DIR}\n"
                       f"ExecStart={BIN} server -c {CFG}\nRestart=always\nRestartSec=3\n"
                       f"Environment=ZIVPN_LOG_LEVEL=info\n"
                       f"CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW\n"
                       f"AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW\n"
                       f"NoNewPrivileges=true\nLimitNOFILE=1048576\n"
                       f"StandardOutput=append:{LOG}\nStandardError=append:{LOG}\n\n"
                       f"[Install]\nWantedBy=multi-user.target\n")
        with open(SVC,'w') as f: f.write(svc_content)
        _log('  ✔ Systemd service dibuat', 'ok')

        # IPTables
        _log('  ── [8/8] Atur iptables & UDP forwarding...', 'step')
        iface_out, _, _ = run("ip -4 route ls | grep default | grep -Po '(?<=dev )(\\S+)' | head -1")
        iface = iface_out.strip() or 'eth0'
        _log(f'  Interface: {iface}')
        run(f"while iptables -t nat -D PREROUTING -i {iface} -p udp --dport 6000:19999 -j DNAT --to-destination :{port} 2>/dev/null; do :; done")
        run(f"iptables -t nat -A PREROUTING -i {iface} -p udp --dport 6000:19999 -j DNAT --to-destination :{port}")
        run(f"iptables -A FORWARD -p udp -d 127.0.0.1 --dport {port} -j ACCEPT")
        run(f"iptables -t nat -A POSTROUTING -s 127.0.0.1/32 -o {iface} -j MASQUERADE")
        run("netfilter-persistent save 2>/dev/null")
        run(f"iptables -I INPUT -p udp --dport {port} -j ACCEPT 2>/dev/null")
        ufw_out,_,_ = run("command -v ufw 2>/dev/null")
        if ufw_out:
            run(f"ufw allow 6000:19999/udp 2>/dev/null; ufw allow {port}/udp 2>/dev/null")
            _log(f'  ✔ UFW: port dibuka', 'ok')
        _log(f'  ✔ IPTables: UDP 6000-19999 → {port} via {iface}', 'ok')

        # Start service
        run("systemctl daemon-reload")
        run("systemctl enable zivpn.service 2>/dev/null")
        run("systemctl start zivpn.service")
        time.sleep(2)

        if is_up():
            _log('  ✔ Service ZiVPN AKTIF & berjalan!', 'ok')
        else:
            _log('  ⚠ Service belum aktif — cek: journalctl -u zivpn -n 20', 'warn')

        # Setup menu bash
        script_src = os.path.abspath(__file__)
        run(f"ln -sf {script_src} /usr/local/bin/menu 2>/dev/null")

        # Telegram notif
        ip_pub = get_ip()
        tg_send(f"✅ <b>ZiVPN Berhasil Diinstall — {brand}</b>\n"
                f"🖥 IP: <code>{ip_pub}</code>\n🌐 Domain: <code>{domain}</code>\n"
                f"🔌 Port: <code>{port}</code>\n📡 Obfs: <code>zivpn</code>")

        _log('')
        _log('══════════════════════════════════════════════════', 'sep')
        _log('   ✔ OGH-ZIV PREMIUM BERHASIL DIINSTALL!', 'success')
        _log('──────────────────────────────────────────────────', 'sep')
        _log(f'   Domain     : {domain}')
        _log(f'   Port       : {port}')
        _log(f'   Brand      : {brand}')
        _log(f'   Interface  : {iface}')
        _log(f'   Forwarding : UDP 6000-19999 → {port}')
        _log('══════════════════════════════════════════════════', 'sep')

    except Exception as e:
        _log(f'  ✘ Error tidak terduga: {e}', 'err')
    finally:
        install_running = False
        _log('INSTALL_DONE', 'done')

def do_uninstall_thread():
    global install_running
    install_running = True
    try:
        _log('══════════════════════════════════════════════════', 'sep')
        _log('   OGH-ZIV — UNINSTALL', 'title')
        _log('══════════════════════════════════════════════════', 'sep')
        run("systemctl stop zivpn.service 2>/dev/null")
        run("systemctl disable zivpn.service 2>/dev/null")
        _log('  ✔ Service dihentikan', 'ok')
        for f in [SVC, BIN]:
            try: os.remove(f)
            except: pass
        import shutil
        try: shutil.rmtree(DIR)
        except: pass
        run("systemctl daemon-reload 2>/dev/null")
        _log('  ✔ File binary & data dihapus', 'ok')
        iface_out,_,_ = run("ip -4 route ls | grep default | grep -Po '(?<=dev )(\\S+)' | head -1")
        iface = iface_out.strip() or 'eth0'
        run(f"while iptables -t nat -D PREROUTING -i {iface} -p udp --dport 6000:19999 -j DNAT --to-destination :5667 2>/dev/null; do :; done")
        run("iptables -D FORWARD -p udp -d 127.0.0.1 --dport 5667 -j ACCEPT 2>/dev/null")
        run(f"iptables -t nat -D POSTROUTING -s 127.0.0.1/32 -o {iface} -j MASQUERADE 2>/dev/null")
        run("netfilter-persistent save 2>/dev/null")
        _log('  ✔ IPTables dibersihkan', 'ok')
        for f in ['/usr/local/bin/menu','/usr/local/bin/ogh-ziv','/etc/profile.d/ogh-ziv.sh']:
            try: os.remove(f)
            except: pass
        run("sed -i '/alias menu=/d' ~/.bashrc 2>/dev/null")
        _log('  ✔ Menu command dihapus', 'ok')
        _log('')
        _log('  ✔ OGH-ZIV berhasil diuninstall sepenuhnya!', 'success')
    except Exception as e:
        _log(f'  ✘ Error: {e}', 'err')
    finally:
        install_running = False
        _log('INSTALL_DONE', 'done')

# ════════════════════════════════════════════════════════════
#  ROUTES — AUTH
# ════════════════════════════════════════════════════════════
@app.route('/api/login', methods=['POST'])
def api_login():
    data = request.json or {}
    if data.get('username') == PANEL_USER and hash_pass(data.get('password','')) == get_panel_pass():
        session['logged_in'] = True
        return jsonify({'ok': True})
    return jsonify({'ok': False, 'error': 'Username atau password salah!'}), 401

@app.route('/api/logout', methods=['POST'])
def api_logout():
    session.clear(); return jsonify({'ok': True})

@app.route('/api/session')
def api_session():
    return jsonify({'logged_in': bool(session.get('logged_in'))})

@app.route('/api/change-panel-pass', methods=['POST'])
@login_required
def api_change_panel_pass():
    data = request.json or {}
    if hash_pass(data.get('old','')) != get_panel_pass():
        return jsonify({'ok':False,'error':'Password lama salah!'})
    new = data.get('new','')
    if len(new) < 6: return jsonify({'ok':False,'error':'Minimal 6 karakter!'})
    os.makedirs(DIR, exist_ok=True)
    with open(AUTH_F,'w') as f: f.write(hash_pass(new))
    return jsonify({'ok':True,'msg':'Password panel diubah!'})

# ════════════════════════════════════════════════════════════
#  ROUTES — DASHBOARD
# ════════════════════════════════════════════════════════════
@app.route('/api/dashboard')
@login_required
def api_dashboard():
    strf=read_conf(STRF); botf=read_conf(BOTF); s=vps_stats()
    return jsonify({'ok':True,'ip':get_ip(),'port':get_port(),'domain':get_domain(),
                    'hostname':s['hostname'],'os':s['os'],'brand':strf.get('BRAND','OGH-ZIV'),
                    'bot_name':botf.get('BOT_NAME',''),'service_status':'RUNNING' if is_up() else 'STOPPED',
                    'is_installed':is_installed(),'total_user':total_user(),'exp_count':exp_count(),
                    'time':datetime.now().strftime('%H:%M'),'date':datetime.now().strftime('%d/%m/%Y'),**s})

# ════════════════════════════════════════════════════════════
#  ROUTES — INSTALL / UNINSTALL
# ════════════════════════════════════════════════════════════
@app.route('/api/install/start', methods=['POST'])
@login_required
def api_install_start():
    global install_running
    if install_running: return jsonify({'ok':False,'error':'Proses sedang berjalan!'})
    data = request.json or {}
    domain   = data.get('domain','').strip() or get_ip()
    port     = data.get('port','5667').strip() or '5667'
    brand    = data.get('brand','OGH-ZIV').strip() or 'OGH-ZIV'
    tg_admin = data.get('tg_admin','-').strip() or '-'
    while not install_log_queue.empty():
        try: install_log_queue.get_nowait()
        except: break
    threading.Thread(target=do_install_thread, args=(domain,port,brand,tg_admin), daemon=True).start()
    return jsonify({'ok':True,'msg':'Install dimulai!'})

@app.route('/api/install/uninstall', methods=['POST'])
@login_required
def api_uninstall_start():
    global install_running
    if install_running: return jsonify({'ok':False,'error':'Proses sedang berjalan!'})
    while not install_log_queue.empty():
        try: install_log_queue.get_nowait()
        except: break
    threading.Thread(target=do_uninstall_thread, daemon=True).start()
    return jsonify({'ok':True,'msg':'Uninstall dimulai!'})

@app.route('/api/install/stream')
@login_required
def api_install_stream():
    def event_stream():
        while True:
            try:
                data = install_log_queue.get(timeout=30)
                yield f"data: {data}\n\n"
                if json.loads(data).get('type') == 'done': break
            except queue.Empty:
                yield 'data: {"type":"ping"}\n\n'
    return Response(stream_with_context(event_stream()), mimetype='text/event-stream',
                    headers={'Cache-Control':'no-cache','X-Accel-Buffering':'no'})

@app.route('/api/install/status')
@login_required
def api_install_status():
    return jsonify({'ok':True,'running':install_running,'installed':is_installed()})

# ════════════════════════════════════════════════════════════
#  ROUTES — USERS
# ════════════════════════════════════════════════════════════
@app.route('/api/users')
@login_required
def api_users():
    users=[]; today=datetime.now().strftime('%Y-%m-%d')
    try:
        with open(UDB) as f:
            for i,line in enumerate(f):
                line=line.strip()
                if not line: continue
                p=line.split('|'); u,pw,e=p[0],p[1],p[2]
                q=p[3] if len(p)>3 else '0'; note=p[4] if len(p)>4 else '-'
                ml=get_maxlogin(u); expired=e<today
                try: sisa=(datetime.strptime(e,'%Y-%m-%d')-datetime.now()).days
                except: sisa=-99
                users.append({'no':i+1,'username':u,'password':pw,'expired':e,
                               'quota':'∞' if q=='0' else f'{q} GB','quota_raw':q,
                               'note':note,'maxlogin':ml,'status':'EXPIRED' if expired else 'AKTIF','sisa':sisa})
    except: pass
    return jsonify({'ok':True,'users':users,'total':len(users),'expired':exp_count()})

@app.route('/api/users/add', methods=['POST'])
@login_required
def api_user_add():
    data=request.json or {}; un=data.get('username','').strip()
    if not un: return jsonify({'ok':False,'error':'Username kosong!'})
    try:
        with open(UDB) as f:
            if any(l.startswith(f"{un}|") for l in f):
                return jsonify({'ok':False,'error':'Username sudah ada!'})
    except: pass
    up=data.get('password','').strip() or rand_pass()
    days=int(data.get('days',30))
    ue=(datetime.now()+timedelta(days=days)).strftime('%Y-%m-%d')
    uq=data.get('quota','0').strip() or '0'
    note=data.get('note','-').strip() or '-'
    uml=data.get('maxlogin','2').strip() or '2'
    os.makedirs(DIR, exist_ok=True)
    with open(UDB,'a') as f: f.write(f"{un}|{up}|{ue}|{uq}|{note}\n")
    set_maxlogin(un,uml); reload_pw()
    ql='∞' if uq=='0' else f'{uq} GB'
    tg_send(f"✅ <b>Akun Baru</b>\n👤 {un}\n🔑 {up}\n🖥 {get_ip()}\n🌐 {get_domain()}\n🔌 {get_port()}\n📦 {ql}\n📅 {ue}\n📝 {note}")
    return jsonify({'ok':True,'msg':f'Akun {un} dibuat!','user':{'username':un,'password':up,'expired':ue,'quota':ql,'maxlogin':uml,'note':note}})

@app.route('/api/users/delete', methods=['POST'])
@login_required
def api_user_delete():
    data=request.json or {}; un=data.get('username','').strip()
    if not un: return jsonify({'ok':False,'error':'Username kosong!'})
    found=False; lines=[]
    try:
        with open(UDB) as f:
            for line in f:
                if line.startswith(f"{un}|"): found=True
                else: lines.append(line)
    except: return jsonify({'ok':False,'error':'DB error!'})
    if not found: return jsonify({'ok':False,'error':'User tidak ditemukan!'})
    with open(UDB,'w') as f: f.writelines(lines)
    del_maxlogin(un); reload_pw()
    tg_send(f"🗑 <b>Akun Dihapus</b>: <code>{un}</code>")
    return jsonify({'ok':True,'msg':f'Akun {un} dihapus!'})

@app.route('/api/users/renew', methods=['POST'])
@login_required
def api_user_renew():
    data=request.json or {}; un=data.get('username','').strip()
    days=int(data.get('days',30)); found=False; lines=[]; ne=''
    today=datetime.now().strftime('%Y-%m-%d')
    try:
        with open(UDB) as f:
            for line in f:
                if line.startswith(f"{un}|"):
                    p=line.strip().split('|'); ce=p[2]
                    base=ce if ce>=today else today
                    ne=(datetime.strptime(base,'%Y-%m-%d')+timedelta(days=days)).strftime('%Y-%m-%d')
                    p[2]=ne; lines.append('|'.join(p)+'\n'); found=True
                else: lines.append(line)
    except: return jsonify({'ok':False,'error':'DB error!'})
    if not found: return jsonify({'ok':False,'error':'User tidak ditemukan!'})
    with open(UDB,'w') as f: f.writelines(lines)
    tg_send(f"🔁 <b>Diperpanjang</b>\n👤 {un}\n📅 {ne} (+{days} hari)")
    return jsonify({'ok':True,'msg':f'Akun {un} +{days} hari → {ne}','new_exp':ne})

@app.route('/api/users/chpass', methods=['POST'])
@login_required
def api_user_chpass():
    data=request.json or {}; un=data.get('username','').strip()
    np=data.get('password','').strip() or rand_pass()
    found=False; lines=[]
    try:
        with open(UDB) as f:
            for line in f:
                if line.startswith(f"{un}|"):
                    p=line.strip().split('|'); p[1]=np; lines.append('|'.join(p)+'\n'); found=True
                else: lines.append(line)
    except: return jsonify({'ok':False,'error':'DB error!'})
    if not found: return jsonify({'ok':False,'error':'User tidak ditemukan!'})
    with open(UDB,'w') as f: f.writelines(lines)
    reload_pw()
    return jsonify({'ok':True,'msg':f'Password {un} → {np}','new_pass':np})

@app.route('/api/users/trial', methods=['POST'])
@login_required
def api_user_trial():
    import random, string
    un='trial'+''.join(random.choices(string.ascii_lowercase+string.digits,k=6))
    up=rand_pass(); ue=(datetime.now()+timedelta(days=1)).strftime('%Y-%m-%d')
    os.makedirs(DIR, exist_ok=True)
    with open(UDB,'a') as f: f.write(f"{un}|{up}|{ue}|1|TRIAL\n")
    set_maxlogin(un,'2'); reload_pw()
    tg_send(f"🎁 <b>Trial</b>\n👤 {un}\n🔑 {up}\n🖥 {get_ip()}\n🌐 {get_domain()}\n🔌 {get_port()}\n📦 1 GB\n📅 {ue}")
    return jsonify({'ok':True,'msg':'Trial dibuat!','user':{'username':un,'password':up,'expired':ue,'quota':'1 GB','note':'TRIAL'}})

@app.route('/api/users/clean', methods=['POST'])
@login_required
def api_user_clean():
    today=datetime.now().strftime('%Y-%m-%d'); cleaned=[]; kept=[]
    try:
        with open(UDB) as f:
            for line in f:
                p=line.strip().split('|')
                if len(p)>=3 and p[2]<today: cleaned.append(p[0])
                else: kept.append(line)
        with open(UDB,'w') as f: f.writelines(kept)
        for u in cleaned: del_maxlogin(u)
        if cleaned: reload_pw()
    except: pass
    return jsonify({'ok':True,'msg':f'{len(cleaned)} akun expired dihapus.','cleaned':cleaned})

@app.route('/api/users/maxlogin', methods=['POST'])
@login_required
def api_user_maxlogin():
    data=request.json or {}; un=data.get('username','').strip(); ml=data.get('maxlogin','2').strip()
    found=False
    try:
        with open(UDB) as f:
            for line in f:
                if line.startswith(f"{un}|"): found=True; break
    except: pass
    if not found: return jsonify({'ok':False,'error':'User tidak ditemukan!'})
    set_maxlogin(un,ml)
    cronline="*/5 * * * * bash /usr/local/bin/ogh-ziv --check-maxlogin >/dev/null 2>&1"
    cron_out,_,_=run("crontab -l 2>/dev/null")
    if 'check-maxlogin' not in cron_out:
        run(f'(crontab -l 2>/dev/null; echo "{cronline}") | crontab -')
    return jsonify({'ok':True,'msg':f'MaxLogin {un} → {ml} device'})

# ════════════════════════════════════════════════════════════
#  ROUTES — SERVICE
# ════════════════════════════════════════════════════════════
@app.route('/api/service/status')
@login_required
def api_svc_status():
    out,_,_=run("systemctl status zivpn --no-pager -l 2>&1 | head -30")
    return jsonify({'ok':True,'status':out,'running':is_up()})

@app.route('/api/service/start', methods=['POST'])
@login_required
def api_svc_start():
    run("systemctl start zivpn"); time.sleep(1)
    return jsonify({'ok':True,'running':is_up(),'msg':'ZiVPN dijalankan.'})

@app.route('/api/service/stop', methods=['POST'])
@login_required
def api_svc_stop():
    run("systemctl stop zivpn")
    return jsonify({'ok':True,'running':False,'msg':'ZiVPN dihentikan.'})

@app.route('/api/service/restart', methods=['POST'])
@login_required
def api_svc_restart():
    run("systemctl restart zivpn"); time.sleep(1)
    return jsonify({'ok':True,'running':is_up(),'msg':'ZiVPN direstart.'})

@app.route('/api/service/log')
@login_required
def api_svc_log():
    lines=int(request.args.get('lines',60))
    if os.path.exists(LOG): out,_,_=run(f"tail -{lines} {LOG}")
    else: out,_,_=run(f"journalctl -u zivpn -n {lines} --no-pager")
    return jsonify({'ok':True,'log':out})

@app.route('/api/service/port', methods=['POST'])
@login_required
def api_svc_port():
    data=request.json or {}; np=data.get('port','').strip()
    if not np.isdigit() or not (1<=int(np)<=65535):
        return jsonify({'ok':False,'error':'Port tidak valid!'})
    cp=get_port()
    try:
        with open(CFG) as f: c=json.load(f)
        c['listen']=f':{np}'
        with open(CFG,'w') as f: json.dump(c,f,indent=2)
    except: return jsonify({'ok':False,'error':'Gagal update config!'})
    run(f"ufw delete allow {cp}/udp 2>/dev/null; ufw allow {np}/udp 2>/dev/null")
    run(f"iptables -D INPUT -p udp --dport {cp} -j ACCEPT 2>/dev/null")
    run(f"iptables -I INPUT -p udp --dport {np} -j ACCEPT 2>/dev/null")
    run("systemctl restart zivpn")
    return jsonify({'ok':True,'msg':f'Port {cp} → {np}','new_port':np})

@app.route('/api/service/backup', methods=['POST'])
@login_required
def api_svc_backup():
    bfile=f"/root/oghziv-backup-{datetime.now().strftime('%Y%m%d-%H%M%S')}.tar.gz"
    _,err,rc=run(f"tar -czf {bfile} {DIR}")
    if rc==0: return jsonify({'ok':True,'msg':f'Backup: {bfile}','file':bfile})
    return jsonify({'ok':False,'error':f'Backup gagal: {err}'})

@app.route('/api/bandwidth')
@login_required
def api_bandwidth():
    port=get_port()
    co,_,_=run(f"ss -u -n -p 2>/dev/null | grep ':{port}'")
    no,_,_=run("cat /proc/net/dev | awk 'NR>2{split($1,a,\":\");if(a[1]!=\"lo\"){printf \"%s|%s|%s\\n\",a[1],$2,$10}}'")
    conns=[l for l in co.split('\n') if l.strip()]
    nets=[]
    for line in no.split('\n'):
        if '|' in line:
            p=line.split('|')
            if len(p)==3: nets.append({'iface':p[0],'rx':p[1],'tx':p[2]})
    return jsonify({'ok':True,'port':port,'connections':conns,'network':nets})

# ════════════════════════════════════════════════════════════
#  ROUTES — DOMAIN
# ════════════════════════════════════════════════════════════
@app.route('/api/domain')
@login_required
def api_domain_get():
    return jsonify({'ok':True,'domain':get_domain(),'ip':get_ip()})

@app.route('/api/domain/set', methods=['POST'])
@login_required
def api_domain_set():
    data=request.json or {}; nd=data.get('domain','').strip() or get_ip()
    os.makedirs(DIR, exist_ok=True)
    with open(DOMF,'w') as f: f.write(nd)
    return jsonify({'ok':True,'msg':f'Domain: {nd}','domain':nd})

@app.route('/api/domain/check')
@login_required
def api_domain_check():
    dom=get_domain(); ip=get_ip()
    out,_,_=run(f"host {dom} 2>/dev/null | grep 'has address' | awk '{{print $NF}}' | head -1")
    if not out: out,_,_=run(f"nslookup {dom} 2>/dev/null | awk '/^Address:/{{print $2}}' | grep -v '#' | head -1")
    match=out.strip()==ip
    return jsonify({'ok':True,'domain':dom,'ip':ip,'resolved':out.strip(),'match':match})

@app.route('/api/domain/ssl', methods=['POST'])
@login_required
def api_domain_ssl():
    dom=get_domain()
    _,_,rc=run(f"openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:P-256 -keyout {DIR}/zivpn.key -out {DIR}/zivpn.crt -subj '/CN={dom}' -days 3650")
    if rc==0: run("systemctl restart zivpn"); return jsonify({'ok':True,'msg':f'SSL dibuat untuk {dom}'})
    return jsonify({'ok':False,'error':'Gagal generate SSL!'})

# ════════════════════════════════════════════════════════════
#  ROUTES — TELEGRAM
# ════════════════════════════════════════════════════════════
@app.route('/api/bot')
@login_required
def api_bot_get():
    conf=read_conf(BOTF)
    return jsonify({'ok':True,'configured':bool(conf.get('BOT_TOKEN')),
                    'bot_name':conf.get('BOT_NAME',''),'chat_id':conf.get('CHAT_ID','')})

@app.route('/api/bot/setup', methods=['POST'])
@login_required
def api_bot_setup():
    data=request.json or {}; tok=data.get('token','').strip(); cid=data.get('chat_id','').strip()
    if not tok or not cid: return jsonify({'ok':False,'error':'Token dan Chat ID wajib!'})
    import urllib.request
    try:
        with urllib.request.urlopen(f"https://api.telegram.org/bot{tok}/getMe",timeout=10) as r:
            res=json.loads(r.read())
        if not res.get('ok'): return jsonify({'ok':False,'error':'Token tidak valid!'})
        bname=res['result']['username']
        os.makedirs(DIR, exist_ok=True)
        with open(BOTF,'w') as f: f.write(f"BOT_TOKEN={tok}\nCHAT_ID={cid}\nBOT_NAME={bname}\n")
        return jsonify({'ok':True,'msg':f'Bot @{bname} terhubung!','bot_name':bname})
    except Exception as e: return jsonify({'ok':False,'error':str(e)})

@app.route('/api/bot/status')
@login_required
def api_bot_status():
    conf=read_conf(BOTF); tok=conf.get('BOT_TOKEN','')
    if not tok: return jsonify({'ok':False,'error':'Bot belum dikonfigurasi!'})
    import urllib.request
    try:
        with urllib.request.urlopen(f"https://api.telegram.org/bot{tok}/getMe",timeout=10) as r:
            res=json.loads(r.read())
        return jsonify({'ok':True,'bot_name':res['result']['username'],'first_name':res['result']['first_name']})
    except Exception as e: return jsonify({'ok':False,'error':str(e)})

@app.route('/api/bot/broadcast', methods=['POST'])
@login_required
def api_bot_broadcast():
    data=request.json or {}; msg=data.get('message','').strip()
    if not msg: return jsonify({'ok':False,'error':'Pesan kosong!'})
    conf=read_conf(BOTF); tok=conf.get('BOT_TOKEN',''); cid=conf.get('CHAT_ID','')
    if not tok: return jsonify({'ok':False,'error':'Bot belum dikonfigurasi!'})
    import urllib.request, urllib.parse
    try:
        url=f"https://api.telegram.org/bot{tok}/sendMessage"
        payload=urllib.parse.urlencode({'chat_id':cid,'text':msg,'parse_mode':'HTML'}).encode()
        with urllib.request.urlopen(url,data=payload,timeout=10) as r: res=json.loads(r.read())
        return jsonify({'ok':res.get('ok',False),'msg':'Broadcast terkirim!' if res.get('ok') else 'Gagal!'})
    except Exception as e: return jsonify({'ok':False,'error':str(e)})

# ════════════════════════════════════════════════════════════
#  ROUTES — STORE
# ════════════════════════════════════════════════════════════
@app.route('/api/store')
@login_required
def api_store_get():
    conf=read_conf(STRF)
    return jsonify({'ok':True,'brand':conf.get('BRAND','OGH-ZIV'),'admin_tg':conf.get('ADMIN_TG','-')})

@app.route('/api/store/set', methods=['POST'])
@login_required
def api_store_set():
    data=request.json or {}
    brand=data.get('brand','OGH-ZIV').strip() or 'OGH-ZIV'
    tg=data.get('admin_tg','-').strip() or '-'
    os.makedirs(DIR, exist_ok=True)
    with open(STRF,'w') as f: f.write(f"BRAND={brand}\nADMIN_TG={tg}\n")
    return jsonify({'ok':True,'msg':'Pengaturan toko disimpan!'})

# ════════════════════════════════════════════════════════════
#  SERVE FRONTEND
# ════════════════════════════════════════════════════════════
@app.route('/')
def index():
    return send_from_directory('.', 'index.html')

if __name__ == '__main__':
    print("\n" + "="*55)
    print("  OGH-ZIV Web Panel — Full Edition")
    print("  URL  : http://0.0.0.0:8080")
    print("  User : admin")
    print("  Pass : oghziv123")
    print("="*55 + "\n")
    app.run(host='0.0.0.0', port=8080, debug=False, threaded=True)
