# sisakulint.ps1 - Run sisakulint with a ghtkn-backed GitHub token when one is available.
# Usage: pwsh -File tools/lint/sisakulint.ps1 [-Fix]
#
# Why: without a token, sisakulint's GitHub API checks (known-vulnerable-actions,
# commit-SHA autofix) are limited to 60 requests/hour. ghtkn issues a short-lived
# GitHub App user token, so the limit becomes the normal per-user quota.
# The token is put in SISAKULINT_GITHUB_TOKEN and never printed.
#
# Precedence: an already-set token wins (CI sets GITHUB_TOKEN), then ghtkn.
# If ghtkn is missing or has no cached token, sisakulint runs unauthenticated
# (it still works, only at the lower rate limit).

[CmdletBinding()]
param([switch]$Fix)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\common.ps1')

if (-not $env:SISAKULINT_GITHUB_TOKEN -and -not $env:GH_TOKEN -and -not $env:GITHUB_TOKEN) {
    if (Get-Command ghtkn -ErrorAction SilentlyContinue) {
        $token = & ghtkn get 2>$null
        if ($LASTEXITCODE -eq 0 -and $token) {
            $env:SISAKULINT_GITHUB_TOKEN = ($token | Select-Object -First 1).Trim()
        }
    }
}

$cliArgs = @('-ignore', 'syntax')
if ($Fix) { $cliArgs += @('-fix', 'on') }

Push-Location (Get-RepoRoot)
try {
    & sisakulint @cliArgs
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
