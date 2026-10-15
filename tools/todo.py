# todo.py — グローバル全項目を「参照元つき」で全て列挙した TODO を生成（判断はしない）
import importlib.metadata as md
import json, os, re, glob, collections

from pathlib import Path

DST = str(Path(__file__).resolve().parents[1])  # リポジトリのルート
OUT = os.path.join(DST, "TODO-inventory.md")
APP = os.environ.get('APPDATA', '')
LOCAL = os.environ.get('LOCALAPPDATA', '')
USERP = os.environ.get('USERPROFILE', '')

def name_of(req):
    m = re.match(r'\s*([A-Za-z0-9][A-Za-z0-9._-]*)', req or '')
    return m.group(1) if m else None

def norm(n):
    return re.sub(r'[-_.]+', '-', (n or '').strip().lower())

def read_lines(p):
    try:
        return [l for l in open(p, encoding='utf-8').read().splitlines() if l != '']
    except Exception:
        return []

# ---------------- pip ----------------
def collect_pip():
    dists = {}
    for d in md.distributions():
        try:
            nm = (d.metadata.get('Name') or '').strip()
        except Exception:
            continue
        if not nm:
            continue
        try:
            path = str(getattr(d, '_path', ''))
        except Exception:
            path = ''
        where = 'user' if ('Roaming\\Python' in path or 'Roaming/Python' in path) else 'global'
        reqs = []
        for r in (d.requires or []):
            p = name_of(r)
            if p:
                reqs.append(p)
        k = norm(nm)
        rec = {'name': nm, 'version': d.version, 'requires': sorted(set(reqs)), 'where': where}
        if k not in dists or (dists[k]['where'] == 'user' and where == 'global'):
            dists[k] = rec
    return dists

def render_deps(dists):
    rev = collections.defaultdict(set)
    for k, v in dists.items():
        for r in v['requires']:
            rev[norm(r)].add(v['name'] + '@' + str(v['version']))
    L = []
    for k in sorted(dists, key=lambda x: dists[x]['name'].lower()):
        v = dists[k]
        refs = sorted(rev.get(k, []))
        reftxt = ', '.join(f"`{r}`" for r in refs) if refs else "なし"
        L.append(f"- [ ] `{v['name']}@{v['version']}` — 参照元: {reftxt}")
    L.append("")
    return L

# ---------------- npm ----------------
def collect_npm():
    root = os.path.join(APP, 'npm', 'node_modules')
    res = {}
    for d in glob.glob(os.path.join(root, '*')):
        if os.path.basename(d).startswith('@'):
            for s in glob.glob(os.path.join(d, '*')):
                res[os.path.basename(d) + '/' + os.path.basename(s)] = s
        else:
            res[os.path.basename(d)] = d
    out = {}
    for nm, d in res.items():
        ver = None; deps = []
        pj = os.path.join(d, 'package.json')
        if os.path.exists(pj):
            try:
                j = json.load(open(pj, encoding='utf-8'))
                ver = j.get('version')
                deps = list((j.get('dependencies') or {}).keys()) + list((j.get('optionalDependencies') or {}).keys())
            except Exception:
                pass
        out[norm(nm)] = {'name': nm, 'version': ver, 'requires': sorted(set(deps))}
    return out

# ---------------- build ----------------
L = []
L.append("# TODO — グローバル導入 全項目（1件ずつ・参照元つき）")
L.append("")
L.append("**判断は入れていません**（削除候補などのラベル無し）。各項目をチェックして判定してください。")
L.append("")
L.append("「参照元」= そのパッケージを依存として要求しているパッケージ（実メタデータから算出）。``なし`` は他から参照されていない。")
L.append("")
L.append("生成: ``tools/todo.py``（`importlib.metadata` / `package.json` / 各パッケージマネージャの実一覧を走査）")
L.append("")

pip = collect_pip()
g = {k: v for k, v in pip.items() if v['where'] == 'global'}
u = {k: v for k, v in pip.items() if v['where'] == 'user'}
L.append(f"## 1. pip — グローバル site（Python 3.13）: {len(g)} 件")
L.append("")
L += render_deps(g)
L.append(f"## 2. pip — ユーザー site（%APPDATA%\\Python）: {len(u)} 件")
L.append("")
L += render_deps(u)

npm = collect_npm()
L.append(f"## 3. npm -g（%APPDATA%\\npm）: {len(npm)} 件")
L.append("")
rev = collections.defaultdict(set)
for k, v in npm.items():
    for r in v['requires']:
        rev[norm(r)].add(v['name'] + '@' + str(v['version']))
for k in sorted(npm, key=lambda x: npm[x]['name'].lower()):
    v = npm[k]
    refs = sorted(rev.get(k, []))
    reftxt = ', '.join(f"`{r}`" for r in refs) if refs else "なし"
    ver = v['version'] if v['version'] else "(版不明)"
    L.append(f"- [ ] `{v['name']}@{ver}` — 参照元: {reftxt}")
L.append("")

# pnpm global
L.append("## 4. pnpm global（直接導入）")
L.append("")
for x in sorted(glob.glob(os.path.join(LOCAL, 'pnpm', 'global', '*', 'node_modules', '*'))):
    L.append(f"- [ ] `{os.path.basename(x)}` — 参照元: なし")
L.append("")

# mise
L.append("## 5. mise（`~/.config/mise/config.toml` の [tools]）")
L.append("")
cfg = os.path.join(USERP, '.config', 'mise', 'config.toml')
sec = None
for line in read_lines(cfg):
    s = line.strip()
    if s.startswith('['):
        sec = s
        continue
    if sec == '[tools]' and '=' in s:
        L.append(f"- [ ] `{s}` — 参照元: なし（ツール）")
L.append("")

# rust / uv / go
def dump_dir(title, path):
    L.append(f"## {title}")
    L.append("")
    items = sorted(os.listdir(path)) if os.path.isdir(path) else []
    for i in items:
        L.append(f"- [ ] `{i}` — 参照元: なし")
    if not items:
        L.append("- （なし）")
    L.append("")

dump_dir("6. Rust — ~/.cargo/bin", os.path.join(USERP, '.cargo', 'bin'))
dump_dir("7. uv — ~/.local/bin", os.path.join(USERP, '.local', 'bin'))
dump_dir("8. Go — ~/go/bin", os.path.join(USERP, 'go', 'bin'))

# nvm
L.append("## 9. nvm-windows（Node バージョン）")
L.append("")
for v in sorted(glob.glob(os.path.join(APP, 'nvm', 'v*'))):
    L.append(f"- [ ] `{os.path.basename(v)}` — 参照元: なし")
L.append("")

# winget export ids
ids = read_lines(os.path.join(DST, 'inventory-winget-ids.txt'))
L.append(f"## 10. winget export（{len(ids)} 件）")
L.append("")
for x in ids:
    L.append(f"- [ ] `{x}`")
L.append("")

# winget list (all)
wl = read_lines(os.path.join(DST, 'inventory-winget-clean.txt'))
L.append(f"## 11. winget list（全 {len(wl)} 件 / Store・ARP 含む）")
L.append("")
for x in wl:
    p = x.split('|')
    if len(p) >= 2:
        L.append(f"- [ ] `{p[0].strip()}` — `{p[1].strip()}`")
L.append("")

# choco
ch = read_lines(os.path.join(DST, 'inventory-choco.txt'))
L.append(f"## 12. Chocolatey（{len(ch)} 行）")
L.append("")
for x in ch:
    if x.lower().startswith('chocolatey v') or 'packages installed' in x:
        continue
    L.append(f"- [ ] `{x}`")
L.append("")

# appx
try:
    import subprocess
    r = subprocess.run(['powershell', '-NoProfile', '-Command',
                        '[Console]::OutputEncoding=[Text.Encoding]::UTF8; Get-AppxPackage | Select-Object -ExpandProperty Name | Sort-Object -Unique'],
                       capture_output=True, text=True, encoding='utf-8')
    ax = [l for l in (r.stdout or '').splitlines() if l.strip()]
except Exception as e:
    ax = []
L.append(f"## 13. Store/UWP（Appx）: {len(ax)} 件")
L.append("")
for x in ax:
    L.append(f"- [ ] `{x}`")
L.append("")

# program files
for title, path in [("14. C:\\Program Files", r"C:\Program Files"),
                    ("15. C:\\Program Files (x86)", r"C:\Program Files (x86)"),
                    ("16. %LOCALAPPDATA%\\Programs", os.path.join(LOCAL, 'Programs'))]:
    dirs = sorted([d for d in os.listdir(path)]) if os.path.isdir(path) else []
    L.append(f"## {title}（{len(dirs)} 件）")
    L.append("")
    for x in dirs:
        L.append(f"- [ ] `{x}`")
    L.append("")

open(OUT, 'w', encoding='utf-8').write('\n'.join(L))
print("written:", OUT)
print("lines:", len(L))
print("pip global:", len(g), "pip user:", len(u), "npm:", len(npm))
