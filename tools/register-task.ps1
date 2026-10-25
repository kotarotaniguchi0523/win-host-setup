# register-task.ps1 - Register (or remove) the Windows Task Scheduler entry
# Usage: pwsh -File tools/register-task.ps1 [-At 06:30] [-Unregister]
# Requires: an elevated shell for registration with -RunLevel Highest.
#
# The task runs:  pwsh -NoProfile -File tools/run-task.ps1 -Task update
#                 -> mise run update (logs to %LOCALAPPDATA%\win-host-setup\logs)

[CmdletBinding()]
param(
    [string]$Name = 'win-host-setup\update',
    [string]$At = '06:30',
    [switch]$Unregister
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\common.ps1')

if ($Unregister) {
    Unregister-ScheduledTask -TaskName $Name -Confirm:$false -ErrorAction Stop
    Write-Host "[ok] タスクを削除しました: $Name"
    return
}

$principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'タスクの登録は管理者権限で実行してください（RunLevel Highest のため）'
}

$repo = Get-RepoRoot
$pwsh = (Get-Command pwsh).Source
$runner = Join-Path $repo 'tools\run-task.ps1'
if (-not (Test-Path $runner)) { throw "見つかりません: $runner" }

$action = New-ScheduledTaskAction `
    -Execute $pwsh `
    -Argument ('-NoProfile -ExecutionPolicy Bypass -File "{0}" -Task update -AiFallback' -f $runner) `
    -WorkingDirectory $repo

$trigger = New-ScheduledTaskTrigger -Weekly `
    -DaysOfWeek Monday, Tuesday, Wednesday, Thursday, Friday -At $At

$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -WakeToRun `
    -MultipleInstances IgnoreNew `
    -RunOnlyIfNetworkAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Hours 2)

$userPrincipal = New-ScheduledTaskPrincipal `
    -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive `
    -RunLevel Highest

Register-ScheduledTask -TaskName $Name `
    -Action $action -Trigger $trigger -Settings $settings -Principal $userPrincipal `
    -Description 'win-host-setup: pull the public mirror, apply it to this host, and verify' `
    -Force | Out-Null

Write-Host "[ok] 登録しました: $Name（平日 $At / 最高権限 / 取りこぼし実行）"
Write-Host "     実行: $pwsh -NoProfile -File `"$runner`""
Write-Host "     ログ: $env:LOCALAPPDATA\win-host-setup\logs"
