# skills-verify.ps1 - Skills (APM) manifest deployment, lock drift detection, and security audit
# Usage: pwsh -File tools/ci/skills-verify.ps1 [-SarifPath <path>] [-StrictAudit]
# Requires: apm CLI (on Windows, winget Microsoft.APM)
# Exit code: 0=success / 1=lock pin mismatch, or an audit violation under -StrictAudit
#
# Drift is judged by the "pins" (repo_url / resolved_ref / resolved_commit), which are robust to formatting differences.

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

# --- lock drift (compare by pin) ---
# Note: resolved_ref can be a tag or a SHA depending on the environment (e.g. v0.39.1 / 1165952d...), so
#       compare only **repo_url + resolved_commit**, which fix the actual commit.
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
# Under -SkipAudit (for relock) the lock is expected to be old, so do not stop on drift
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

# --- security audit (hidden Unicode / drift / policy) ---
# --ci supports only json / sarif. Emit SARIF and put the highlights in the summary.
if (-not $SarifPath) { $SarifPath = Join-Path ([IO.Path]::GetTempPath()) 'apm-audit.sarif' }
Push-Location $apmHome
try { & $apm audit --ci --format sarif --output $SarifPath; $auditCode = $LASTEXITCODE }
finally { Pop-Location }

if (-not (Test-Path $SarifPath)) {
    '{"version":"2.1.0","$schema":"https://json.schemastore.org/sarif-2.1.0.json","runs":[]}' |
        Set-Content -Path $SarifPath -Encoding UTF8
}

# Summary (extract the count and rule breakdown from SARIF)
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

# Do not leak a non-zero audit exit into the "script exit code" (the caller decides)
exit 0
