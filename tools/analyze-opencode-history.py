import sqlite3, os, json, collections, re, sys

sys.stdout.reconfigure(encoding='utf-8', errors='replace')
db = os.path.join(os.environ['USERPROFILE'], '.local', 'share', 'opencode', 'opencode.db')
con = sqlite3.connect(f'file:{db}?mode=ro', uri=True)
cur = con.cursor()

tools = collections.Counter()
bash_firstword = collections.Counter()
bash_all = []

def walk(node, out):
    if isinstance(node, dict):
        if node.get('type') in ('tool', 'tool-invocation', 'tool_use') or ('tool' in node and 'state' in node):
            out.append(node)
        for v in node.values():
            walk(v, out)
    elif isinstance(node, list):
        for v in node:
            walk(v, out)

cur.execute("select data from session_message where type='assistant'")
for (d,) in cur.fetchall():
    try:
        j = json.loads(d)
    except Exception:
        continue
    found = []
    walk(j.get('content'), found)
    for t in found:
        name = t.get('tool') or t.get('name') or t.get('toolName')
        tools[name] += 1
        inp = t.get('state', {}).get('input') if isinstance(t.get('state'), dict) else t.get('input')
        if name in ('bash', 'shell') and isinstance(inp, dict) and inp.get('command'):
            cmd = inp['command']
            bash_all.append(cmd)
            first = re.split(r'[\s|;&]', cmd.strip())[0]
            bash_firstword[first] += 1

print("== tool 使用回数 ==")
for k, v in tools.most_common(30):
    print(f"  {k}: {v}")

print("\n== bash コマンド数:", len(bash_all), "==")
print("== 先頭トークン TOP40 ==")
for k, v in bash_firstword.most_common(40):
    print(f"  {k}: {v}")

pats = {
    'python -c': r'python\s+-c', 'python スクリプト': r'python\s+\S+\.py',
    'node -e': r'node\s+-e', 'node スクリプト': r'node\s+\S+\.js',
    'curl': r'\bcurl\b', 'wget': r'\bwget\b', 'jq': r'\bjq\b',
    'grep/rg/tgrep': r'\b(rg|grep|tgrep)\b', 'find': r'\bfind\b',
    'sed': r'\bsed\b', 'awk': r'\bawk\b', 'sort': r'\bsort\b', 'uniq': r'\buniq\b',
    'xargs': r'\bxargs\b', 'cat': r'\bcat\b', 'ls/dir': r'\b(ls|Get-ChildItem|dir)\b',
    'wc': r'\bwc\b', 'tr': r'\btr\b', 'head/tail': r'\b(head|tail)\b',
    'pipe |': r'\|', 'redirect >': r'>', 'heredoc': r'<<',
    'powershell/ps': r'\b(powershell|pwsh|Get-|Set-|Select-Object|Where-Object)\b',
    'npm/npx': r'\b(npm|npx|pnpm|bunx)\b', 'pip/uv': r'\b(pip|uv|uvx|pipx)\b',
    'git': r'\bgit\b', 'docker': r'\bdocker\b', 'sbx': r'\bsbx\b',
    'mise': r'\bmise\b', 'winget': r'\bwinget\b', 'choco': r'\bchoco\b',
    'zip/tar': r'\b(zip|tar|Compress-Archive|Expand-Archive|7z)\b',
    'Invoke-RestMethod/REST': r'\bInvoke-RestMethod|Invoke-WebRequest\b',
}
print("\n== パターン出現 ==")
for name, p in pats.items():
    c = sum(1 for cmd in bash_all if re.search(p, cmd))
    if c:
        print(f"  {name}: {c}")

print("\n== bash コマンド例（長い順 15）==")
for cmd in sorted(bash_all, key=len, reverse=True)[:15]:
    print("  ---")
    print("  " + cmd[:500].replace("\n", " \\n "))
