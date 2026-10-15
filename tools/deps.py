# deps.py - Generate a TODO inventory of global installs "with references"
import importlib.metadata as md
import json, os, re, glob, collections

from pathlib import Path

DST = str(Path(__file__).resolve().parents[1])  # repository root
OUT = os.path.join(DST, "TODO-inventory.md")

def name_of(req):
    m = re.match(r'\s*([A-Za-z0-9][A-Za-z0-9._-]*)', req or '')
    return m.group(1) if m else None

def norm(n):
    return re.sub(r'[-_.]+', '-', (n or '').strip().lower())

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

def collect_npm():
    root = os.path.join(os.environ.get('APPDATA', ''), 'npm', 'node_modules')
    npm = {}
    pats = [os.path.join(root, '*', 'package.json'), os.path.join(root, '@*', '*', 'package.json')]
    for pat in pats:
        for pj in glob.glob(pat):
            try:
                j = json.load(open(pj, encoding='utf-8'))
            except Exception:
                continue
            nm = j.get('name')
            if not nm:
                continue
            deps = list((j.get('dependencies') or {}).keys())
            deps += list((j.get('optionalDependencies') or {}).keys())
            npm[norm(nm)] = {'name': nm, 'version': j.get('version'), 'requires': sorted(set(deps))}
    return npm

def render(title, dists, note=''):
    rev = collections.defaultdict(set)
    for k, v in dists.items():
        for r in v['requires']:
            rev[norm(r)].add(v['name'] + '@' + str(v['version']))
    roots = sorted([k for k in dists if not rev.get(k)], key=lambda k: dists[k]['name'].lower())
    rest = sorted([k for k in dists if rev.get(k)], key=lambda k: dists[k]['name'].lower())
    L = [f"## {title}", ""]
    if note:
        L += [note, ""]
    L.append(f"### roots — どこからも参照されていない（削除候補）: {len(roots)}")
    L.append("")
    if not roots:
        L.append("- （なし）")
    for k in roots:
        v = dists[k]
        deps = ', '.join(f"`{x}`" for x in v['requires'][:25]) or '—'
        L.append(f"- [ ] `{v['name']}@{v['version']}` — **被参照: なし(root)** ／ 依存: {deps}")
    L.append("")
    L.append(f"### 被参照あり（他が依存）: {len(rest)}")
    L.append("")
    for k in rest:
        v = dists[k]
        refs = ', '.join(f"`{r}`" for r in sorted(rev[k]))
        L.append(f"- [ ] `{v['name']}@{v['version']}` — **被参照: {refs}**")
    L.append("")
    return L

L = []
L.append("# TODO — グローバル「残っているもの」keep/remove 判定（参照元つき）")
L.append("")
L.append("目的: **いらないものを確定**する。各項目に **誰が依存しているか（被参照）** を付与。チェックで判定。")
L.append("")
L.append("凡例: **root** = どのパッケージからも参照されていない＝**削除候補**。**被参照あり** = 他が依存（消すと連鎖破壊）。")
L.append("")
L.append("生成: `tools/deps.py`（`importlib.metadata` と各 `package.json` を実走査。`pip list` の推測ではない）")
L.append("")

pip = collect_pip()
L += render("A. pip — グローバル site（Python 3.13）", {k: v for k, v in pip.items() if v['where'] == 'global'})
L += render("B. pip — ユーザー site（%APPDATA%\\Python）", {k: v for k, v in pip.items() if v['where'] == 'user'},
            note="→ `poetry` の依存閉包。poetry を `uv tool` へ移せば**丸ごと撤去可**。")

npm = collect_npm()
L += render("C. npm -g（%APPDATA%\\npm）", npm)

# D. pnpm global (direct installs only)
L.append("## D. pnpm global（直接導入）")
L.append("")
L.append("- [ ] `osgrep` — 被参照: なし(root) ／ 依存: 巨大（`@huggingface/transformers`, `@lancedb`, `@swc`, `sharp` 等）")
L.append("- [ ] `pnpm@10.17.1` — npm -g 経由。**mise 管理へ移行**（現行は古い）")
L.append("")

# E. mise-managed
L.append("## E. mise 管理（`~/.config/mise/config.toml`）")
L.append("")
for t in ["betterleaks@1.2.0", "node@24.16.0", "python@3.13.13", "gh@2.92.0", "doppler@3.76.0",
          "github:microsoft/apm@0.14.0", "aqua:k1LoW/mo@1.5.5", "github:microsoft/waza@0.33.0", "rtk@0.40.0"]:
    L.append(f"- [ ] `{t}` — 独立（ツール、依存なし）")
L.append("")

L.append("## F. その他（アプリ／独立・依存グラフなし）")
L.append("")
L.append("- [ ] winget export 77 / winget list 275 / Chocolatey 16 / Rust(~/.cargo/bin) / uv / Go(~/go/bin) / nvm 3 版 / Appx 200")
L.append("     → 一覧は `inventory.md` §2, §4, §5 を参照（依存関係は無い＝個別 keep/remove 判定）")
L.append("")

open(OUT, 'w', encoding='utf-8').write('\n'.join(L))
print("written:", OUT)
print("lines:", len(L))
