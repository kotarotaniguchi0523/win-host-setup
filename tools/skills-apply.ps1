# skills-apply.ps1 — リポジトリの skills/apm.yml を ~/.apm へ配置して反映する
# 使い方: pwsh -File tools/skills-apply.ps1 [-Lock]
#   -Lock : 配置後に `apm lock --global` を実行して apm.lock.yaml を再生成し、リポジトリへ戻す
#
# APM の前提（実測）:
#   - `--global` は CWD に依存しない（~/.apm を直接使う）。audit だけは CWD のプロジェクトを見る
#   - 新規依存の統合は「初回 install では走らず、次回実行で走る」ことがある → 実体で検証して再実行する
#   - 助言メッセージ（apm compile -g）で exit=1 を返すことがある → 終了コードでは判定しない
#
# 既知の upstream バグ（回避策はこのスクリプト側で実施）:
#   - microsoft/apm#2927 APM 0.30.0 audit reports freshly installed skills as unintegrated on Windows（初回統合漏れ）
#   - microsoft/apm#3056 UnicodeDecodeError: 'gbk' codec can't decode byte on Windows during 'apm install'（cp932 系）
#   - microsoft/apm#3206 apm install writes stale version to apm.lock.yaml when apm_modules/ holds the previous tag
#   - microsoft/apm#2885 [FEATURE] Support atomic exact dependency reconciliation for global installs

[CmdletBinding()]
param([switch]$Lock)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\common.ps1')

$repo = Split-Path $PSScriptRoot -Parent
$src  = Join-Path $repo 'skills'
$dst  = Join-Path (Get-HomeDir) '.apm'
$skillsDest = Join-Path (Get-HomeDir) '.agents/skills'

if (-not (Test-Path (Join-Path $src 'apm.yml'))) { throw "skills/apm.yml がありません" }

# apm CLI を解決（PATH に無ければ winget のパッケージ先を探す）
$apm = (Get-Command apm -ErrorAction SilentlyContinue).Source
if (-not $apm) { $apm = Resolve-Apm }
Write-Host "[i] apm: $apm"

New-Item -ItemType Directory -Force -Path $dst | Out-Null

# 既存をバックアップ（世代は 2 つまでに保つ）
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
foreach ($f in 'apm.yml', 'apm.lock.yaml') {
    $cur = Join-Path $dst $f
    if (Test-Path $cur) { Copy-Item $cur "$cur.bak-$stamp" -Force; Write-Host "[bak] $f" }
}
Get-ChildItem $dst -Filter '*.bak-*' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -Skip 2 |
    ForEach-Object { Remove-Item $_.FullName -Force }

Copy-Item (Join-Path $src 'apm.yml') (Join-Path $dst 'apm.yml') -Force
Write-Host "[ok] ~/.apm/apm.yml"

# --- lock（--global は CWD 非依存）---
if ($Lock) {
    & $apm lock --global | Out-Null
    $lock = Join-Path $dst 'apm.lock.yaml'
    if (Test-Path $lock) { Copy-Item $lock (Join-Path $src 'apm.lock.yaml') -Force; Write-Host '[ok] skills/apm.lock.yaml を更新' }
}

# --- 展開（lock の deployed_files と実体を突き合わせて不足なら再実行）---
function Test-SkillsDeployed {
    $lock = Join-Path $dst 'apm.lock.yaml'
    if (-not (Test-Path $lock)) { return $true }
    $missing = @()
    foreach ($line in (Get-Content $lock -Encoding UTF8)) {
        if ($line -match '^\s*-\s+(\.agents/skills/[^/\s]+)/?$') {
            $rel = $Matches[1]
            $p = Join-Path (Get-HomeDir) ($rel -replace '/', '\')
            if (-not (Test-Path $p)) { $missing += $rel }
        }
    }
    if ($missing.Count -gt 0) { Write-Host "[i] 未展開: $($missing -join ', ')" }
    return ($missing.Count -eq 0)
}

$null = & $apm install --global 2>&1   # 助言で exit=1 を返すことがあるため終了コードは見ない
if (-not (Test-SkillsDeployed)) {
    Write-Host '[i] 未展開の Skill があるため install を再実行します（APM の初回統合の癖）'
    $null = & $apm install --global 2>&1
    if (-not (Test-SkillsDeployed)) { throw 'apm install を 2 回実行しても Skill が展開されません（apm.yml と lock を確認してください）' }
}
Write-Host '[ok] すべての APM Skill が展開されています'

# --- 自作スキル（skills/local/*）を ~/.agents/skills へ配置 ---
$localSrc = Join-Path $src 'local'
if (Test-Path $localSrc) {
    New-Item -ItemType Directory -Force -Path $skillsDest | Out-Null
    foreach ($d in (Get-ChildItem $localSrc -Directory)) {
        $t = Join-Path $skillsDest $d.Name
        if (Test-Path $t) { Remove-Item $t -Recurse -Force }
        Copy-Item $d.FullName $t -Recurse -Force
        Write-Host "[ok] ~/.agents/skills/$($d.Name)（自作）"
    }
}

Write-Host "`n検証: apm audit --ci / apm outdated --global / waza check"
exit 0   # 最終状態（全 Skill 展開済み）で成功と判定する
