# skills-verify.ps1 — Skills(APM) のマニフェスト配置・lock ドリフト検出・セキュリティ監査
# 使い方: pwsh -File tools/ci/skills-verify.ps1 [-SarifPath <path>] [-StrictAudit]
# 前提: apm CLI（Windows では winget Microsoft.APM）
# 終了コード: 0=成功 / 1=lock のピン不一致、または -StrictAudit 時の監査違反
#
# ドリフト判定は「ピン（repo_url / resolved_ref / resolved_commit）」で行う（整形差に強い）。

[CmdletBinding()]
param([string]$SarifPath, [switch]$StrictAudit, [switch]$SkipAudit, [switch]$Relock)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\common.ps1')

$repo    = Get-RepoRoot
$repoYml = Join-Path $repo 'skills/apm.yml'
$repoLck = Join-Path $repo 'skills/apm.lock.yaml'
$apmHome = Join-Path (Get-HomeDir) '.apm'

if (-not (Test-Path $repoYml)) { throw "skills/apm.yml が見つかりません" }
$apm = Resolve-Apm
Write-Host "[i] apm: $apm"

New-Item -ItemType Directory -Force -Path $apmHome | Out-Null
Copy-Item $repoYml (Join-Path $apmHome 'apm.yml') -Force
if (Test-Path $repoLck) { Copy-Item $repoLck (Join-Path $apmHome 'apm.lock.yaml') -Force }

Push-Location $apmHome
try {
    Invoke-Native $apm @('lock', '--global')    -What 'apm lock --global'
    Invoke-Native $apm @('install', '--global') -What 'apm install --global'
} finally { Pop-Location }

# --- lock ドリフト（ピンで比較）---
# 注意: resolved_ref は環境によりタグにも SHA にもなる（例: v0.39.1 / 1165952d…）ため、
#       実体を固定する **repo_url + resolved_commit** のみで比較する。
function Get-Pins([string]$Path) {
    if (-not (Test-Path $Path)) { return @() }
    $repoUrl = $null; $sha = $null; $out = @()
    foreach ($line in (Get-Content $Path -Encoding UTF8)) {
        if     ($line -match '^\s*-\s*repo_url:\s*(\S+)')    { if ($repoUrl) { $out += "$repoUrl|$sha" }; $repoUrl = $Matches[1]; $sha = $null }
        elseif ($line -match '^\s*resolved_commit:\s*(\S+)') { $sha = $Matches[1] }
    }
    if ($repoUrl) { $out += "$repoUrl|$sha" }
    return ($out | Sort-Object)
}

if (Test-Path $repoLck) {
    $expected = Get-Pins $repoLck
    $actual   = Get-Pins (Join-Path $apmHome 'apm.lock.yaml')
    Write-Host "--- リポジトリ ---"; $expected
    Write-Host "--- CI 生成 ---";     $actual
    $diff = Compare-Object $expected $actual
    # -SkipAudit（relock 用）ではロックが古い前提なのでドリフト判定で止めない
    if ($diff -and -not $SkipAudit) {
        throw "apm.lock.yaml のピン（repo_url / resolved_commit）が一致しません。tools/skills-apply.ps1 -Lock または tools/sync.ps1 を実行してください。"
    }
    Write-Host '[ok] apm.lock.yaml のピンは一致'
} else {
    Write-Host '[i] apm.lock.yaml が無いためドリフト検出をスキップ'
}

if ($SkipAudit) {
    if ($Relock) {
        Copy-Item (Join-Path $apmHome 'apm.yml') $repoYml -Force
        if (Test-Path (Join-Path $apmHome 'apm.lock.yaml')) { Copy-Item (Join-Path $apmHome 'apm.lock.yaml') $repoLck -Force }
        Write-Host '[ok] apm.yml / apm.lock.yaml をリポジトリへ書き戻しました'
    }
    return
}

# --- セキュリティ監査（hidden Unicode / drift / policy）---
# --ci は json / sarif のみ対応。SARIF を出力しつつ、要点をサマリに出す。
if (-not $SarifPath) { $SarifPath = Join-Path ([IO.Path]::GetTempPath()) 'apm-audit.sarif' }
Push-Location $apmHome
try { & $apm audit --ci --format sarif --output $SarifPath; $auditCode = $LASTEXITCODE }
finally { Pop-Location }

if (-not (Test-Path $SarifPath)) {
    '{"version":"2.1.0","$schema":"https://json.schemastore.org/sarif-2.1.0.json","runs":[]}' |
        Set-Content -Path $SarifPath -Encoding UTF8
}

# サマリ（SARIF から件数とルール内訳を出す）
try {
    $sarif = Get-Content $SarifPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $results = @($sarif.runs | ForEach-Object { $_.results } | Where-Object { $_ })
    $byRule = $results | Group-Object ruleId | Sort-Object Count -Descending | Select-Object -First 10
    $md = "### APM audit`n`n- 検出: $($results.Count) 件（exit $auditCode）`n`n"
    if ($byRule) {
        $md += "| ルール | 件数 |`n|---|---|`n"
        foreach ($g in $byRule) { $md += "| $($g.Name) | $($g.Count) |`n" }
    }
    Add-Summary $md
} catch {
    Write-Warning "SARIF の解析に失敗しました: $($_.Exception.Message)"
}

if ($env:GITHUB_ENV) { "APM_AUDIT_EXIT=$auditCode" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding utf8 }

if ($auditCode -ne 0) {
    $msg = "apm audit が違反を検出しました（exit $auditCode、SARIF: $SarifPath）"
    if ($StrictAudit) { throw $msg }
    Write-Warning $msg
} else {
    Write-Host '[ok] apm audit クリーン'
}

# 監査の非ゼロ終了を「スクリプトの終了コード」に漏らさない（呼び出し側で制御する）
exit 0
