# skills-apply.ps1 — リポジトリの skills/apm.yml を ~/.apm へ配置して反映する
# 使い方: pwsh -File tools/skills-apply.ps1 [-Lock]
#   -Lock : 配置後に `apm lock -g` を実行して apm.lock.yaml を再生成し、リポジトリへ戻す

[CmdletBinding()]
param([switch]$Lock)
$ErrorActionPreference = 'Stop'

$repo = Split-Path $PSScriptRoot -Parent
$src  = Join-Path $repo 'skills'
$dst  = Join-Path $env:USERPROFILE '.apm'

if (-not (Test-Path (Join-Path $src 'apm.yml'))) { throw "skills/apm.yml がありません" }
if (-not (Get-Command apm -ErrorAction SilentlyContinue)) { throw "apm CLI が見つかりません（winget: Microsoft.APM）" }

New-Item -ItemType Directory -Force -Path $dst | Out-Null

# 既存をバックアップ
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
foreach ($f in 'apm.yml', 'apm.lock.yaml') {
    $cur = Join-Path $dst $f
    if (Test-Path $cur) { Copy-Item $cur "$cur.bak-$stamp" -Force; Write-Host "[bak] $f" }
}

Copy-Item (Join-Path $src 'apm.yml') (Join-Path $dst 'apm.yml') -Force
Write-Host "[ok] ~/.apm/apm.yml"

if ($Lock) {
    Push-Location $dst
    try { & apm lock --global } finally { Pop-Location }
    $lock = Join-Path $dst 'apm.lock.yaml'
    if (Test-Path $lock) { Copy-Item $lock (Join-Path $src 'apm.lock.yaml') -Force; Write-Host "[ok] skills/apm.lock.yaml を更新" }
}

# グローバルへ適用（~/.apm に展開）
& apm install --global
Write-Host "`n検証: apm audit --ci / apm outdated --global"
