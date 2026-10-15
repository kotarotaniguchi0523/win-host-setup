# all.ps1 — このリポジトリの Lint をまとめて実行（hk / CI / 手動で共用）
# 使い方: pwsh -File tools/lint/all.ps1 [-Fix]
#   1. PII 検査      （tools/depii.ps1 -Check）
#   2. Actions Lint  （tools/lint/actions.ps1: actionlint + sisakulint）
#   3. 秘密情報      （tools/lint/secrets.ps1: betterleaks + secretlint）
#   4. Skills 評価   （tools/ci/waza-check.ps1: waza）
# 終了コード: 0=すべてクリーン / 1=検出あり

[CmdletBinding()]
param([switch]$Fix)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\common.ps1')

$script:results = @()

function Invoke-Lint {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][scriptblock]$Body)
    Write-Host "`n### $Name" -ForegroundColor Cyan
    try {
        & $Body
        $script:results += [pscustomobject]@{ Lint = $Name; Result = 'ok' }
    } catch {
        Write-Warning "$Name : $($_.Exception.Message)"
        $script:results += [pscustomobject]@{ Lint = $Name; Result = 'NG' }
    }
}

Invoke-Lint 'PII'     { & (Join-Path $PSScriptRoot '..\depii.ps1') -Check }
Invoke-Lint 'actions' { if ($Fix) { & (Join-Path $PSScriptRoot 'actions.ps1') -Fix } else { & (Join-Path $PSScriptRoot 'actions.ps1') } }
Invoke-Lint 'secrets' { & (Join-Path $PSScriptRoot 'secrets.ps1') }
Invoke-Lint 'skills'  { & (Join-Path $PSScriptRoot '..\ci\waza-check.ps1') }

Write-Host "`n=== まとめ ===" -ForegroundColor Cyan
$script:results | Format-Table -AutoSize

$ng = @($script:results | Where-Object { $_.Result -ne 'ok' })
if ($ng.Count -gt 0) { throw "$($ng.Count) 件の Lint が失敗しました" }
Write-Host '[ok] すべての Lint が通りました'
