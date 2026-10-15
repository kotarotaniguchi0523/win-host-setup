# pull.ps1 — 逆同期: public（または GitHub）→ source → 実環境
# 使い方: pwsh -File tools/pull.ps1 [-Apply] [-From <dir>]
#   -Apply : 取り込んだ後に実環境へ適用する（apply.ps1 / skills-apply.ps1 -Lock）
#   -From  : 取り込み元（既定: ./public。GitHub から取る場合は clone 済みディレクトリを指定）
#
# 目的: Renovate / Dependabot が GitHub 側で更新した「宣言」（mise/mise.toml, skills/apm.yml,
#       winget/host.dsc.yaml）と「ロック」を source に取り込み、実環境へ反映する。
#       これが無いと capture（ホストが正）が GitHub の更新を上書きしてしまう。

[CmdletBinding()]
param([switch]$Apply, [string]$From)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\common.ps1')

$repo = Split-Path $PSScriptRoot -Parent
if (-not $From) { $From = Join-Path $repo 'public' }
if (-not (Test-Path $From)) { throw "取り込み元がありません: $From（先に public を clone / fetch してください）" }

# 取り込む対象（宣言とロック）
$files = @(
    'mise/mise.toml',
    'mise/mise.lock',
    'skills/apm.yml',
    'skills/apm.lock.yaml',
    'winget/host.dsc.yaml'
)

$changed = @()
foreach ($rel in $files) {
    $src = Join-Path $From $rel
    $dst = Join-Path $repo $rel
    if (-not (Test-Path $src)) { Write-Warning "取り込み元に無い: $rel"; continue }

    $same = (Test-Path $dst) -and ((Get-FileHash $src).Hash -eq (Get-FileHash $dst).Hash)
    if ($same) { Write-Host "[=] $rel"; continue }

    Copy-Item $src $dst -Force
    Write-Host "[ok] $rel を取り込み"
    $changed += $rel
}

if ($changed.Count -eq 0) { Write-Host '[i] 取り込む変更はありません'; return }

Write-Host "`n取り込み: $($changed.Count) 件"
if (-not $Apply) {
    Write-Host '次の手順: pwsh -File tools/apply.ps1 / tools/skills-apply.ps1 -Lock（または -Apply 付きで再実行）'
    return
}

Push-Location $repo
try {
    & (Join-Path $PSScriptRoot 'apply.ps1')
    & (Join-Path $PSScriptRoot 'skills-apply.ps1') -Lock
} finally { Pop-Location }
Write-Host '[ok] 実環境へ適用しました'
