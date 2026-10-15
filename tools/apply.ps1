# apply.ps1 — リポジトリ（source）→ 実環境へ適用
# 使い方: pwsh -File tools/apply.ps1
#  - mise/mise.toml  → ~/.config/mise/config.toml へ複製
#  - mise/mise.lock  → ~/.config/mise/mise.lock  へ複製
#  - mise/locks/     → ~/.config/mise/locks/     へ複製（pypi の依存グラフ）
#  - mise install で不足ツールを導入
# 注意: 既存の config / lock はタイムスタンプ付きでバックアップする

[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$repo    = Split-Path $PSScriptRoot -Parent
$miseSrc = Join-Path $repo 'mise'
$miseDst = Join-Path $env:USERPROFILE '.config\mise'

$srcCfg  = Join-Path $miseSrc 'mise.toml'
$srcLock = Join-Path $miseSrc 'mise.lock'
if (-not (Test-Path $srcCfg)) { throw "mise/mise.toml がありません（先に tools/capture.ps1）" }

New-Item -ItemType Directory -Force -Path $miseDst | Out-Null

# 既存をバックアップ
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
foreach ($f in 'config.toml', 'mise.lock') {
    $cur = Join-Path $miseDst $f
    if (Test-Path $cur) { Copy-Item $cur "$cur.bak-$stamp" -Force; Write-Host "[bak] $f -> $f.bak-$stamp" }
}

Copy-Item $srcCfg  (Join-Path $miseDst 'config.toml') -Force
Copy-Item $srcLock (Join-Path $miseDst 'mise.lock')   -Force
Write-Host "[ok] config.toml / mise.lock を適用"

$locksSrc = Join-Path $miseSrc 'locks'
if (Test-Path $locksSrc) {
    $locksDst = Join-Path $miseDst 'locks'
    if (Test-Path $locksDst) { Remove-Item $locksDst -Recurse -Force }
    Copy-Item $locksSrc $locksDst -Recurse -Force
    Write-Host "[ok] locks/ を適用"
}

Write-Host "`n--- mise install ---"
& mise install

Write-Host "`n次の手順:"
Write-Host "  winget configure winget/host.dsc.yaml"
Write-Host "  tools/skills-apply.ps1 -Lock   # Skills（APM）を ~/.apm へ適用"
Write-Host "  tools/fix-machine-path.ps1 （管理者で実行）"
