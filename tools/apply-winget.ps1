# apply-winget.ps1 - Apply winget/host.dsc.yaml (requires elevation)
# Usage: pwsh -File tools/apply-winget.ps1
# Behaviour: when not elevated, prints a warning and exits 0 so that an unattended run
#            (e.g. a non-admin shell) does not fail the whole update.

[CmdletBinding()]
param([string]$Dsc = 'winget/host.dsc.yaml')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\common.ps1')

$repo = Get-RepoRoot
$dscPath = Join-Path $repo $Dsc
if (-not (Test-Path $dscPath)) { throw "見つかりません: $dscPath" }

$principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning '管理者権限がないため winget の適用をスキップしました（mise run update:winget を管理者で実行してください）'
    exit 0
}

Write-Host '[i] winget configure を適用します'
& winget configure -f $dscPath --accept-configuration-agreements
$code = $LASTEXITCODE
if ($code -eq 0) { Write-Host '[ok] winget configure 完了' }
else { Write-Warning "winget configure が exit=$code で終了しました" }
exit $code
