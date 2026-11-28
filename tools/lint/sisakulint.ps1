[CmdletBinding()]
param([switch]$Fix, [string]$SarifPath)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\common.ps1')

$cliArgs = @('--format', 'line')
if ($env:GITHUB_REPOSITORY -and $env:GITHUB_TOKEN) { $cliArgs += @('--online', '--repo', $env:GITHUB_REPOSITORY) }
if ($Fix) { $cliArgs += '--fix' }
if ($SarifPath) { $cliArgs += @('--sarif', $SarifPath) }

Push-Location (Get-RepoRoot)
try {
    & sisakulint @cliArgs
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
