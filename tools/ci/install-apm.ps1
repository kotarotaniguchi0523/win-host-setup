# install-apm.ps1 - Install the APM CLI (winget Microsoft.APM) at the version declared in the host DSC, and export its path to GITHUB_ENV
# Usage: pwsh -File tools/ci/install-apm.ps1
# Requires: Windows (winget must be available)
# Output: APM_DIR=<directory containing apm.exe>
#
# The version is read from winget/host.dsc.yaml (Microsoft.APM) so CI follows the
# host declaration, the same way .github/actions/mise-setup follows jdx.mise. Without
# the pin, `winget install` takes the latest release while the host (and the committed
# apm.lock.yaml) stays on the declared one, and the lock is rejected by the content
# hash check on every run.

[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\common.ps1')

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw "winget が見つかりません（Windows ランナーで実行してください）" }

$repo = Get-RepoRoot
$dsc  = Join-Path $repo 'winget/host.dsc.yaml'
if (-not (Test-Path $dsc)) { throw "winget/host.dsc.yaml が見つかりません: $dsc" }
$text = Get-Content -Raw -Encoding utf8 $dsc
if ($text -notmatch "(?s)id:\s*Microsoft\.APM.*?version:\s*'([^']+)'") {
    throw 'Microsoft.APM の version が winget/host.dsc.yaml に見つかりません'
}
$version = $Matches[1]

$apmExe    = (Get-Command apm -ErrorAction SilentlyContinue).Source
$installed = $null
if ($apmExe) {
    $out = (& $apmExe --version 2>&1 | Out-String)
    if ($out -match '(\d+\.\d+\.\d+)') { $installed = $Matches[1] }
}

if ($installed -eq $version) {
    Write-Host "[ok] apm $installed（winget/host.dsc.yaml の宣言どおり）"
} else {
    $arguments = @(
        'install', '--id', 'Microsoft.APM', '--exact', '--version', $version, '--silent',
        '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity'
    )
    # --force replaces a different (including newer) version with the declared one.
    if ($installed) { $arguments += '--force' }
    try {
        Invoke-Native 'winget' $arguments -What "winget install Microsoft.APM $version"
    } catch {
        Write-Warning "winget install が失敗しました（既存の導入を試します）: $($_.Exception.Message)"
    }
}

$apm = Resolve-Apm
Write-Host "[ok] apm: $apm"
Invoke-Native $apm @('--version') -What 'apm --version'

if ($env:GITHUB_ENV) {
    "APM_DIR=" + (Split-Path $apm -Parent) | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding utf8
}
