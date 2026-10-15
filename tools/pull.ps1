# pull.ps1 - Reverse sync: public (or GitHub) -> source -> real environment
# Usage: pwsh -File tools/pull.ps1 [-Apply] [-From <dir>]
#   -Apply : after pulling, apply to the real environment (apply.ps1 / skills-apply.ps1 -Lock)
#   -From  : pull source (default: ./public. To pull from GitHub, specify a cloned directory)
#
# Purpose: pull the "declarations" that Renovate / Dependabot updated on the GitHub side (mise/mise.toml, skills/apm.yml,
#          winget/host.dsc.yaml) and the "locks" into source, then reflect them into the real environment.
#          Without this, capture (host is the source of truth) would overwrite GitHub's updates.

[CmdletBinding()]
param([switch]$Apply, [string]$From)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\common.ps1')

$repo = Split-Path $PSScriptRoot -Parent
if (-not $From) { $From = Join-Path $repo 'public' }
if (-not (Test-Path $From)) { throw "取り込み元がありません: $From（先に public を clone / fetch してください）" }

# Files to pull (declarations and locks)
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
