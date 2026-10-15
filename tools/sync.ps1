# sync.ps1 — 「ローカルで更新 → リポジトリ → 公開」を 1 コマンドで行う
# 使い方: pwsh -File tools/sync.ps1 [-Message "..." ] [-NoPush]
#  1. capture.ps1        : 実環境の mise 設定をリポジトリへ
#  2. skills-capture.ps1 : 実環境の Skills（~/.apm・自作）をリポジトリへ
#  3. sanitize.ps1       : public/ を再生成（個人情報を伏せる）
#  4. source リポジトリをコミット
#  5. public リポジトリをコミットして push

[CmdletBinding()]
param([string]$Message = "", [switch]$NoPush)
$ErrorActionPreference = 'Stop'

$repo = Split-Path $PSScriptRoot -Parent
$pub  = Join-Path $repo 'public'
if ([string]::IsNullOrWhiteSpace($Message)) { $Message = "chore: sync from host ($(Get-Date -Format 'yyyy-MM-dd HH:mm'))" }

function Invoke-Step([string]$name, [scriptblock]$body) {
    Write-Host "`n=== $name ===" -ForegroundColor Cyan
    & $body
}

Invoke-Step 'capture（mise）'        { & (Join-Path $PSScriptRoot 'capture.ps1') }
Invoke-Step 'skills-capture（Skills）' { & (Join-Path $PSScriptRoot 'skills-capture.ps1') }
Invoke-Step 'depii（ソースの PII 除去）' { & (Join-Path $PSScriptRoot 'depii.ps1') }
Invoke-Step 'sanitize（公開版）'      { & (Join-Path $PSScriptRoot 'sanitize.ps1') }

Invoke-Step 'source リポジトリをコミット' {
    git -C $repo add -A
    git -C $repo diff --cached --quiet
    if ($LASTEXITCODE -ne 0) { git -C $repo commit -q -m $Message; Write-Host "[ok] source committed" }
    else { Write-Host "[i] source に変更なし" }
}

Invoke-Step 'public リポジトリをコミット / push' {
    if (-not (Test-Path (Join-Path $pub '.git'))) { throw "public/ が git リポジトリではありません" }
    git -C $pub add -A
    git -C $pub diff --cached --quiet
    if ($LASTEXITCODE -ne 0) { git -C $pub commit -q -m $Message; Write-Host "[ok] public committed" }
    else { Write-Host "[i] public に変更なし" }
    if (-not $NoPush) { git -C $pub push; Write-Host "[ok] pushed" } else { Write-Host "[i] -NoPush のため push していません" }
}
