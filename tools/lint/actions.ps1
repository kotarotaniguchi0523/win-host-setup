# actions.ps1 — GitHub Actions の Lint（jactionlint + sisakulint + pinact）
# 使い方: pwsh -File tools/lint/actions.ps1 [-Fix]
#   -Fix : jactionlint / sisakulint の自動修正と pinact のピン留めを適用する
# 終了コード: 0=クリーン / 1=検出あり
#
# 役割分担:
#   jactionlint … GitHub Actions の静的チェッカ（actionlint のチェックを包含し、zizmor 系の
#                 セキュリティ規則・Dependabot 設定・Actions lock（.github/workflows/actions.lock）まで見る）
#   sisakulint … 追加の SAST。**jactionlint が包含する actionlint 相当のルールは無効化**する
#   pinact     … uses: の SHA 固定・バージョンコメント・最小経過日数の検証

[CmdletBinding()]
param([switch]$Fix)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\common.ps1')

$repo = Get-RepoRoot

# jactionlint（= actionlint 相当）が担当するルールは sisakulint 側で無効化する（重複報告を避ける）
# commit-sha は GitHub の Actions lock（.github/workflows/actions.lock）が不変性を保証するため無効化する
# （ワークフローはタグ参照 + lock でコミットを固定するモデルを採用）
$sisakuIgnore = @('expression', 'cond', 'job-needs', 'env-var', 'workflow-call', 'deprecated-commands', 'commit-sha')
$ignoreArgs = @()
foreach ($r in $sisakuIgnore) { $ignoreArgs += @('-ignore', $r) }

Push-Location $repo
try {
    $failed = $false

    # --- jactionlint（構文・式・shellcheck・セキュリティ・Dependabot・Actions lock）---
    if (-not (Get-Command jactionlint -ErrorAction SilentlyContinue)) { throw 'jactionlint が見つかりません（mise install）' }
    Write-Host '=== jactionlint ===' -ForegroundColor Cyan
    if ($Fix) {
        & jactionlint --fix
        # 自動修正できない指摘が残っていないか再チェックする（--fix の exit は 1 でも成功扱いになるため）
        Write-Host '[i] 修正後に再チェックします' -ForegroundColor DarkGray
        & jactionlint
        if ($LASTEXITCODE -ne 0) { $failed = $true; Write-Warning 'jactionlint: 自動修正できない指摘が残っています' }
        else { Write-Host '[ok] jactionlint（修正後クリーン）' }
    } else {
        & jactionlint
        if ($LASTEXITCODE -gt 1) { $failed = $true }
        elseif ($LASTEXITCODE -eq 1) { $failed = $true; Write-Warning 'jactionlint: 指摘あり（-Fix で自動修正できるものがあります）' }
        else { Write-Host '[ok] jactionlint' }
    }

    # --- sisakulint（追加の SAST）---
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

    # --- pinact（任意。Actions lock 採用後はタグ参照が正となるため既定では実行しない）---
    if ($env:JACTIONLINT_USE_PINACT -eq '1') {
        if (Get-Command pinact -ErrorAction SilentlyContinue) {
            Write-Host '=== pinact ===' -ForegroundColor Cyan
            if ($Fix) { & pinact run --fix; if ($LASTEXITCODE -ne 0) { $failed = $true } }
            else {
                & pinact run --fix=false --no-api
                if ($LASTEXITCODE -ne 0) { $failed = $true; Write-Warning 'pinact: SHA 未固定のアクションがあります' }
                else { Write-Host '[ok] pinact' }
            }
        }
    } else {
        Write-Host '[i] pinact はスキップ（Actions lock が不変性を保証。実行するには JACTIONLINT_USE_PINACT=1）'
    }

    if ($failed) { throw 'actions lint で問題を検出しました（-Fix で自動修正できます）' }
    Write-Host '[ok] actions lint'
} finally { Pop-Location }
