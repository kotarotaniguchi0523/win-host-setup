# actions.ps1 - Lint GitHub Actions (jactionlint + sisakulint + pinact)
# Usage: pwsh -File tools/lint/actions.ps1 [-Fix]
#   -Fix : apply jactionlint / sisakulint auto-fixes and pinact pinning
# Exit code: 0=clean / 1=findings
#
# Division of labor:
#   jactionlint ... static checker for GitHub Actions (includes actionlint checks, zizmor-style
#                 security rules, Dependabot config)
#   sisakulint ... extra SAST (every rule on; overlap with jactionlint is intentional)
#   pinact     ... verify that every uses: is pinned to a full commit SHA (tag kept as a comment)

[CmdletBinding()]
param([switch]$Fix)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\common.ps1')

$repo = Get-RepoRoot

# Strict: every sisakulint rule is on. Overlap with jactionlint is intentional (both must stay
# green), so nothing is suppressed here and a regression is caught by either linter.
$sisakuIgnore = @()
$ignoreArgs = @()
foreach ($r in $sisakuIgnore) { $ignoreArgs += @('-ignore', $r) }

Push-Location $repo
try {
    $failed = $false

    # --- jactionlint (syntax, expressions, shellcheck, security, Dependabot) ---
    if (-not (Get-Command jactionlint -ErrorAction SilentlyContinue)) { throw 'jactionlint が見つかりません（mise install）' }
    Write-Host '=== jactionlint ===' -ForegroundColor Cyan
    if ($Fix) {
        & jactionlint --fix
        # Re-check whether any non-auto-fixable findings remain (--fix exits 1 even on success)
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

    # --- sisakulint (extra SAST) ---
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

    # --- pinact: every uses: must be pinned to a full commit SHA (the tag stays as a comment) ---
    # Runs by default now that SHA pinning is the policy (the Actions lock file was removed).
    if (Get-Command pinact -ErrorAction SilentlyContinue) {
        Write-Host '=== pinact ===' -ForegroundColor Cyan
        if ($Fix) { & pinact run; if ($LASTEXITCODE -ne 0) { $failed = $true } }
        else {
            & pinact run --fix=false --no-api
            if ($LASTEXITCODE -ne 0) { $failed = $true; Write-Warning 'pinact: SHA 未固定のアクションがあります' }
            else { Write-Host '[ok] pinact' }
        }
    } else {
        Write-Warning 'pinact が見つかりません（mise install）'
    }

    if ($failed) { throw 'actions lint で問題を検出しました（-Fix で自動修正できます）' }
    Write-Host '[ok] actions lint'
} finally { Pop-Location }
