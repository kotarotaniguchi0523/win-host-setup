# all.ps1 - Run all Lints for this repository together (shared by hk / CI / manual)
# Usage: pwsh -File tools/lint/all.ps1 [-Fix]
#   1. PII check      (tools/depii.ps1 -Check)
#   2. Actions Lint   (tools/lint/actions.ps1: actionlint + sisakulint)
#   3. Secrets        (tools/lint/secrets.ps1: betterleaks + secretlint)
#   4. Skills eval    (tools/ci/waza-check.ps1: waza)
# Exit code: 0=all clean / 1=findings

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
