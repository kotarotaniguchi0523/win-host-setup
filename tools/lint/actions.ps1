# actions.ps1 — GitHub Actions の Lint（actionlint + sisakulint + pinact）
# 使い方: pwsh -File tools/lint/actions.ps1 [-Fix]
#   -Fix : sisakulint の自動修正と pinact のピン留めを適用する
# 終了コード: 0=クリーン / 1=検出あり
#
# 役割分担:
#   actionlint … 構文・式・shellcheck・ジョブ依存などの「正しさ」
#   sisakulint … GitHub Actions のセキュリティ (SAST)。**actionlint と重複するルールは無効化**する
#   pinact     … uses: の SHA 固定・バージョンコメント・最小経過日数（= アクションの“lock”検証）

[CmdletBinding()]
param([switch]$Fix)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\common.ps1')

$repo = Get-RepoRoot

# actionlint が担当するルールは sisakulint 側で無効化する（重複報告を避ける）
$sisakuIgnore = @('expression', 'cond', 'job-needs', 'env-var', 'workflow-call', 'deprecated-commands')
$ignoreArgs = @()
foreach ($r in $sisakuIgnore) { $ignoreArgs += @('-ignore', $r) }

Push-Location $repo
try {
    $failed = $false

    # --- actionlint（構文・式・shellcheck）---
    if (-not (Get-Command actionlint -ErrorAction SilentlyContinue)) { throw 'actionlint が見つかりません（mise install）' }
    Write-Host '=== actionlint ===' -ForegroundColor Cyan
    & actionlint
    if ($LASTEXITCODE -ne 0) { $failed = $true }

    # --- sisakulint（セキュリティ / SAST）---
    if (-not (Get-Command sisakulint -ErrorAction SilentlyContinue)) { throw 'sisakulint が見つかりません（mise install）' }
    Write-Host '=== sisakulint ===' -ForegroundColor Cyan
    if ($Fix) {
        & sisakulint @ignoreArgs -fix on
        if ($LASTEXITCODE -ne 0) { $failed = $true }
    } else {
        $out = & sisakulint @ignoreArgs 2>&1 | Out-String
        $findings = @($out -split "`n" | Where-Object { $_ -match ':\d+:\d+:' })
        if ($findings.Count -gt 0) {
            $findings | ForEach-Object { Write-Host $_.Trim() }
            Write-Warning "sisakulint: $($findings.Count) 件の指摘（-Fix で自動修正できます）"
            $failed = $true
        } else {
            Write-Host '[ok] sisakulint'
        }
    }

    # --- pinact（アクションの SHA 固定・コメント・最小経過日数の検証）---
    if (Get-Command pinact -ErrorAction SilentlyContinue) {
        Write-Host '=== pinact ===' -ForegroundColor Cyan
        if ($Fix) {
            & pinact run --fix
            if ($LASTEXITCODE -ne 0) { $failed = $true }
        } else {
            # --fix=false --no-api: ネットワーク無しで 40 桁 SHA 固定だけを検証する
            & pinact run --fix=false --no-api
            if ($LASTEXITCODE -ne 0) { $failed = $true; Write-Warning 'pinact: SHA 未固定のアクションがあります（-Fix で固定）' }
            else { Write-Host '[ok] pinact（全アクションが SHA 固定）' }
        }
    } else {
        Write-Warning 'pinact が見つかりません（mise install）'
    }

    if ($failed) { throw 'actions lint で問題を検出しました（-Fix で自動修正できます）' }
    Write-Host '[ok] actions lint'
} finally { Pop-Location }
