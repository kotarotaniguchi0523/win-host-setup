# skills-verify.ps1 — Skills(APM) のマニフェスト配置・lock ドリフト検出・セキュリティ監査
# 使い方: pwsh -File tools/ci/skills-verify.ps1 [-SarifPath <path>] [-StrictAudit]
# 前提: apm CLI（Windows では winget Microsoft.APM）
# 終了コード: 0=成功 / 1=lock のピン不一致、または -StrictAudit 時の監査違反
#
# ドリフト判定は「ピン（repo_url / resolved_ref / resolved_commit）」で行う（整形差に強い）。

[CmdletBinding()]
param([string]$SarifPath, [switch]$StrictAudit)
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
    if ($diff) {
        throw "apm.lock.yaml のピン（repo_url / resolved_commit）が一致しません。tools/skills-apply.ps1 -Lock または tools/sync.ps1 を実行してください。"
    }
    Write-Host '[ok] apm.lock.yaml のピンは一致'
} else {
    Write-Host '[i] apm.lock.yaml が無いためドリフト検出をスキップ'
}

if ($SkipAudit) { return }

# --- セキュリティ監査（hidden Unicode / drift / policy）---
if (-not $SarifPath) { $SarifPath = Join-Path ([IO.Path]::GetTempPath()) 'apm-audit.sarif' }
Push-Location $apmHome
try { & $apm audit --ci --format sarif --output $SarifPath; $auditCode = $LASTEXITCODE }
finally { Pop-Location }

if (-not (Test-Path $SarifPath)) {
    '{"version":"2.1.0","$schema":"https://json.schemastore.org/sarif-2.1.0.json","runs":[]}' |
        Set-Content -Path $SarifPath -Encoding UTF8
}

if ($env:GITHUB_ENV) { "APM_AUDIT_EXIT=$auditCode" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding utf8 }

if ($auditCode -ne 0) {
    $msg = "apm audit が違反を検出しました（exit $auditCode、SARIF: $SarifPath）"
    if ($StrictAudit) { throw $msg }
    Write-Warning $msg
    if ($env:GITHUB_STEP_SUMMARY) { Add-Summary "### apm audit: 違反あり（SARIF を参照）" }
    return
}
Write-Host '[ok] apm audit クリーン'
