# build-inventory.ps1 — inventory.md を生データから生成（会話に内容を出さない）
$ErrorActionPreference = 'Stop'
$dst = "C:\Users\%USERNAME%\win-host-setup"

# ---- fresh raw capture (UTF-8) ----
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch {}
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')

$raw = winget list --accept-source-agreements --disable-interactivity 2>&1
$done = $false; $w = New-Object System.Collections.Generic.List[string]
foreach ($l in $raw) {
  if ($l -match '^\s*-{5,}') { $done = $true; continue }
  if (-not $done) { continue }
  if ($l -match '^\s*$') { continue }
  $p = $l -split '\s{2,}' | Where-Object { $_ -ne '' }
  if ($p.Count -ge 3) { $w.Add($p[0].Trim() + '|' + $p[1].Trim() + '|' + $p[2].Trim()) }
}
$w | Set-Content -Encoding utf8 "$dst\inventory-winget-clean.txt"

$rust = (Get-ChildItem "$env:USERPROFILE\.cargo\bin" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
$uvb  = (Get-ChildItem "$env:USERPROFILE\.local\bin" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
$pnpmg= (Get-ChildItem "$env:LOCALAPPDATA\pnpm\global\5\node_modules" -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
$go   = (Get-ChildItem "$env:USERPROFILE\go\bin" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
$miseInst = (Get-ChildItem "$env:LOCALAPPDATA\mise\installs" -Directory -ErrorAction SilentlyContinue | ForEach-Object { $t = $_.Name; Get-ChildItem $_.FullName -Directory -ErrorAction SilentlyContinue | ForEach-Object { "$t@$($_.Name)" } })
$miseShim = (Get-ChildItem "$env:LOCALAPPDATA\mise\shims" -ErrorAction SilentlyContinue | Where-Object { $_.Extension -eq '.exe' } | Select-Object -ExpandProperty BaseName)

# ---- helpers (build line list) ----
$L = New-Object System.Collections.Generic.List[string]
function T([string]$s) { $L.Add($s) }
function Bul([string]$f) { if (Test-Path -LiteralPath $f) { Get-Content -LiteralPath $f | ForEach-Object { if ($_ -ne '') { $L.Add("- " + $_) } } } }
function Code([string]$f) { if (Test-Path -LiteralPath $f) { $L.Add('```toml'); Get-Content -LiteralPath $f | ForEach-Object { $L.Add($_) }; $L.Add('```') } }
function Arr([object[]]$items) { foreach ($i in $items) { if ($i) { $L.Add("- " + $i) } } }
function Win([string]$f) {
  $L.Add("| Name | Id | Version |"); $L.Add("|---|---|---|")
  if (Test-Path -LiteralPath $f) {
    Get-Content -LiteralPath $f | Where-Object { $_ -match '\|' } | ForEach-Object {
      $p = $_ -split '\|'
      if ($p.Count -ge 3) { $L.Add("| " + $p[0].Trim() + " | " + $p[1].Trim() + " | " + $p[2].Trim() + " |") }
    }
  }
}
function Pkg([string]$f) {
  $L.Add('```'); if (Test-Path -LiteralPath $f) { Get-Content -LiteralPath $f | ForEach-Object { if ($_ -ne '') { $L.Add($_) } } }; $L.Add('```')
}
$cfgPath = "$env:USERPROFILE\.config\mise\config.toml"

# ================= document =================
T "# Inventory — Windows ホストのグローバル導入（完全版・全一覧）"
T ""
T "収集: 2026-10-13〜15 / 場所: ``C:\Users\%USERNAME%\win-host-setup``"
T "対象: **Windows 本体のグローバル導入のみ**（プロジェクトローカル、エディタ/ブラウザ拡張は対象外）。"
T "目標: **mise へ統一**（Python ``3.14`` / Node ``26`` / Go ``1.27`` / ``hk``）。手順は ``PLAN.md``、移行分析は ``migration-npm.md``/``migration-pip.md``。"
T ""
T "## 0. 重要な訂正"
T ""
T "``Get-Command`` が (none) でも **PATH 未通過なだけ**で実体があるもの:"
T ""
Arr @(
  "**Rust** — ``~/.cargo/bin``（cargo/rustc/rustup/clippy/rustfmt/rust-analyzer/rls/miri/gdb/lldb…）＋ toolchain ``stable-x86_64-pc-windows-msvc``",
  "**uv** — ``~/.local/bin``（``uv``, ``uvx``, ``uvw``）＋ **``claude.exe``**（Claude Code CLI）。uv tool は無し",
  "**mise** — ``…\WinGet\Packages\jdx.mise_…\mise\bin\mise.exe``（既に使用中）",
  "**Go** — toolchain 無し（``~/go/bin/gopls.exe`` の残骸のみ）"
)
T ""
T "## 1. mise（既存設定・実体）"
T ""
T "``~/.config/mise/config.toml``:"
T ""
Code $cfgPath
T ""
T "**mise installs（実体）**:"
Arr $miseInst
T ""
T "**mise shims（.exe）**:"
Arr $miseShim
T ""
T "## 2. パッケージマネージャ別（全一覧）"
T ""
T "### 2.1 winget — export 可能（77）"
T ""
T "``winget export`` の PackageIdentifier:"
T ""
Pkg "$dst\inventory-winget-ids.txt"
T ""
T "### 2.2 winget list（全 275 / Store・ARP 含む）"
T ""
Win "$dst\inventory-winget-clean.txt"
T ""
T "### 2.3 Chocolatey（16）"
T ""
Pkg "$dst\inventory-choco.txt"
T ""
T "### 2.4 npm -g（24）"
T ""
Pkg "$dst\inventory-npm-global.txt"
T ""
T "### 2.5 pnpm global（直接導入）"
T ""
Arr $pnpmg
T ""
T "### 2.6 pip — グローバル（Python 3.13, 134）"
T ""
Pkg "$dst\inventory-pip.txt"
T ""
T "### 2.7 pip — ユーザー site（``%APPDATA%\Python``）"
T ""
Pkg "$dst\inventory-pip-user.txt"
T ""
T "### 2.8 Rust — ``~/.cargo/bin``"
T ""
Arr $rust
T ""
T "### 2.9 uv — ``~/.local/bin``"
T ""
Arr $uvb
T ""
T "### 2.10 Go — ``~/go/bin``"
T ""
Arr $go
T ""
T "### 2.11 nvm-windows（Node）"
T ""
Pkg "$dst\inventory-nvm.txt"
T ""
T "### 2.12 dotnet"
T ""
T "**SDK 無し** → グローバルツール無し（``dotnet tool`` 不可）。"
T ""
T "### 2.13 PowerShell Gallery モジュール（既定 + 追加）"
T ""
Arr @("``GoogleCloud``", "``GoogleCloudBeta``", "（他は PowerShell 同梱モジュール）")
T ""
T "### 2.14 未導入の確認済みマネージャ"
T ""
Arr @("scoop / cargo(第三者) / go toolchain / gem(ruby) / composer / conda / pipx / bun / yarn / deno / volta / asdf / fnm / pixi — **いずれも無し**")
T ""
T "## 3. 言語ランタイム/スタック"
T ""
Arr @(
  "**Node**: nvm-windows（18.20.4 / 22.22.0* / 24.13.0）＋ mise node@24.16.0（二重）→ 目標 mise ``26.x``",
  "**Python**: 下記 §3.1 → 目標 mise ``3.14.x``",
  "**Rust**: stable-msvc",
  "**PHP**: MAMP 7.4.16",
  "**Java**: Amazon Corretto JDK17",
  "**.NET**: runtime のみ（SDK 無し）",
  "**Go**: 無し",
  "**Docker**: Docker Desktop ＋ Sandboxes（``sbx, sbx-gui, llmman``）"
)
T ""
T "### 3.1 Python の全実体（削除計画）"
T ""
T "| 実体 | 版 | サイズ | 状態 |"
T "|---|---|---|---|"
T "| ``Programs\Python310`` | (python.exe 欠落) | 45 MB | **🗑 削除済 2026-10-15**（PATH 2 件も除去） |"
T "| ``Programs\Python313`` | 3.13.11 | 2,272 MB | ⚠️ **134 pip** を内包 → uv 移行後に削除 |"
T "| mise python | 3.13.13 | 60 MB | → 目標 ``3.14.x`` |"
T "| ``~/.pyenv``（pyenv-win + 3.10.0/3.11.0/3.12.2） | — | 452 MB | **🗑 削除済 2026-10-15**（プロジェクトは退避） |"
T "| ``%APPDATA%\Python\Python313`` | — | — | pip **ユーザー site**（§2.7） |"
T ""
T "**`~/.pyenv` に同居していたプロジェクト**（削除時に ``backup-pyenv-2026-10-15/`` へ退避）:"
T ""
T "| プロジェクト | 要求 Python |"
T "|---|---|"
T "| ``edinet`` | ``^3.11`` |"
T "| ``ai-bot/line-bot-local`` | 3.11.0 |"
T "| ``ai-bot/line-bot-local/claude`` | 3.11.0 |"
T "| ``ai-bot/line-bot-local/python-gcp-linebot`` | 3.10.0 |"
T ""
T "## 4. アプリ（Program Files / LocalAppData）"
T ""
T "### 4.1 ``C:\Program Files``"
T ""
T "``````"
Get-ChildItem "C:\Program Files" -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name | ForEach-Object { $L.Add($_) }
T "``````"
T ""
T "### 4.2 ``C:\Program Files (x86)``"
T ""
T "``````"
Get-ChildItem "C:\Program Files (x86)" -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name | ForEach-Object { $L.Add($_) }
T "``````"
T ""
T "### 4.3 ``%LOCALAPPDATA%\Programs``"
T ""
T "``````"
Get-ChildItem "$env:LOCALAPPDATA\Programs" -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name | ForEach-Object { $L.Add($_) }
T "``````"
T ""
T "## 5. Store / UWP（Appx）"
T ""
T "件数: **200**。全名（``Get-AppxPackage``）:"
T ""
T "``````"
Get-AppxPackage -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name | Sort-Object -Unique | ForEach-Object { $L.Add($_) }
T "``````"
T ""
T "## 6. PATH 上の手置き / アプリ同梱"
T ""
Bul "$dst\inventory-path-user.txt"
T ""
T "（PATH 上の exe スキャン詳細は ``inventory-path-exes.txt``）"
T ""
T "## 7. スコープ外（確定）"
T ""
Arr @(
  "**WSL（Ubuntu）— 無視**。Ubuntu 内部に直接導入されたものは**不可侵**（変更・削除しない）。Windows 側の **WSL マウント/成果物のみ**整理可。",
  "エディタ拡張（VS Code / Cursor / Zed）",
  "ブラウザ拡張（Chrome / Dev / Zen / Slack）",
  "UWP/Store アプリの一部（winget 側で扱う）"
)
T ""
T "## 8. 移行先の分類"
T ""
T "| 種別 | 例 | 移行先 |"
T "|---|---|---|"
T "| mise registry あり | node, python, uv, gh, jq, rg, fd, **hk**(旧 lefthook), doppler, mo, waza, rtk, betterleaks | **mise**（正確ピン + lock） |"
T "| Python CLI | apm, skillspector, 既存 pip 群 | **mise ``pypi:``**（Takumi Guard 済） |"
T "| npm 由来 | safe-chain, codex, gemini-cli, copilot, MCP 群, vercel, netlify… | **Takumi Guard npm**（or mise ``npm:``） |"
T "| Windows 専用/GUI | Office, Chrome, MySQL, Podman, Zen, Cinema4D, Weka, MATLAB… | **winget(DSC)** |"
T "| 野良/残骸 | nvm-windows, choco 一部, Python 3.10/3.13, pyenv, ``gopls`` 残骸, lefthook, PATH 残骸(``node_mod``) | 移行後**撤去** |"
T ""
T "## 9. 削除/変更履歴"
T ""
Arr @(
  "2026-10-15: ``Programs\Python310`` 削除 + User PATH 2 件除去",
  "2026-10-15: ``~/.pyenv``（pyenv-win + 3.10/3.11/3.12, 452MB）削除。プロジェクトは ``backup-pyenv-2026-10-15/`` へ退避（58 files / 0.61MB）",
  "2026-10-15: 方針確定 — Python=3.14系 / Node=26系 / Go=1.27.2 / lefthook→hk"
)
T ""
T "## 10. 生データファイル"
T ""
T "``inventory-winget-ids.txt``, ``inventory-winget-clean.txt``, ``inventory-winget.txt``, ``winget-export.json``, ``inventory-choco.txt``, ``inventory-npm-global.txt``, ``inventory-pip.txt``, ``inventory-pip-user.txt``, ``inventory-nvm.txt``, ``inventory-path-user.txt``, ``inventory-path-exes.txt``, ``inventory-sweep-A〜D.txt``, ``backup-pyenv-2026-10-15/``"

[System.IO.File]::WriteAllLines("$dst\inventory.md", $L, (New-Object System.Text.UTF8Encoding($false)))
"written: $dst\inventory.md  lines=$($L.Count)"
