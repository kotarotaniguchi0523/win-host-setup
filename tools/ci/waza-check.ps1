# waza-check.ps1 - Inspect skills with Waza (the Agent Skills evaluation CLI)
# Usage: pwsh -File tools/ci/waza-check.ps1 [-Path skills] [-Strict]
#   -Strict : exit 1 when there are findings (default is warnings only)
# Requires: waza (managed by mise; install via jdx/mise-action etc.)

[CmdletBinding()]
param([string]$Path = 'skills', [switch]$Strict)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\common.ps1')

$repo = Get-RepoRoot
$target = Join-Path $repo $Path

# If waza is missing, deploy this repository's mise config globally and then install it
if (-not (Get-Command waza -ErrorAction SilentlyContinue)) {
    if (-not (Get-Command mise -ErrorAction SilentlyContinue)) { throw "waza も mise も見つかりません" }
    Write-Host '[i] waza を mise で導入します'
    $miseDst = Join-Path (Get-HomeDir) '.config/mise'
    New-Item -ItemType Directory -Force -Path $miseDst | Out-Null
    Copy-Item (Join-Path $repo 'mise/mise.toml') (Join-Path $miseDst 'config.toml') -Force
    if (Test-Path (Join-Path $repo 'mise/mise.lock')) { Copy-Item (Join-Path $repo 'mise/mise.lock') (Join-Path $miseDst 'mise.lock') -Force }
    Invoke-Native 'mise' @('install', 'github:microsoft/waza') -What 'mise install github:microsoft/waza'
}

if (-not (Get-Command waza -ErrorAction SilentlyContinue)) { throw "waza が見つかりません（mise で導入してください）" }
if (-not (Test-Path $target)) { Write-Host "[i] $Path が無いためスキップ"; return }

Invoke-Native 'waza' @('--version') -What 'waza --version'

& waza check $target
$code = $LASTEXITCODE
if ($code -ne 0) {
    $msg = "waza check が指摘を返しました（exit $code）: $Path"
    if ($Strict) { throw $msg }
    Write-Warning $msg
    exit 0
}
Write-Host '[ok] waza check'
