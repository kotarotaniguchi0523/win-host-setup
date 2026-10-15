# install-apm.ps1 - Install the APM CLI (winget Microsoft.APM) and export its path to GITHUB_ENV
# Usage: pwsh -File tools/ci/install-apm.ps1
# Requires: Windows (winget must be available)
# Output: APM_DIR=<directory containing apm.exe>

[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\common.ps1')

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw "winget が見つかりません（Windows ランナーで実行してください）" }

# Skip reinstall if it is already present
if (-not (Get-Command apm -ErrorAction SilentlyContinue)) {
    try {
        Invoke-Native 'winget' @(
            'install', '--id', 'Microsoft.APM', '--exact', '--silent',
            '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity'
        ) -What 'winget install Microsoft.APM'
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
