# run-task.ps1 - Single entry point for the mise tasks (interactive and scheduled)
# Usage: pwsh -File tools/run-task.ps1 [-Task check|update|verify] [-KeepDays 30]
#
# Why this wrapper exists:
#   MISE_SAFE=1 is set as a User environment variable on this host (PLAN.md), which
#   disables `mise run` entirely. The task definitions live in this trusted repository,
#   so this entry point deliberately clears MISE_SAFE for its own invocation only.
#   Direct `mise run ...` from a shell still requires `$env:MISE_SAFE=0`.
#
# The task itself is defined in mise.toml; this script only adds logging and the
# safe-mode exception.

[CmdletBinding()]
param(
    [ValidateSet('check', 'update', 'verify')][string]$Task = 'check',
    [int]$KeepDays = 30,
    [switch]$NoLog
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\common.ps1')

$repo = Get-RepoRoot
$logDir = Join-Path $env:LOCALAPPDATA 'win-host-setup\logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$log = Join-Path $logDir ("{0}-{1}.log" -f $Task, (Get-Date -Format 'yyyyMMdd-HHmmss'))

$env:MISE_SAFE = '0'   # see the note above
$env:MISE_NOT_FOUND_AUTO_INSTALL = '0'

Push-Location $repo
try {
    if ($NoLog) {
        & mise run $Task
    } else {
        & mise run $Task *>&1 | Tee-Object -FilePath $log
    }
    $code = $LASTEXITCODE
} finally {
    Pop-Location
}

$status = [ordered]@{
    task       = $Task
    exit       = $code
    log        = if ($NoLog) { $null } else { $log }
    finishedAt = (Get-Date).ToString('o')
}
$utf8 = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $logDir 'last-run.json'), ($status | ConvertTo-Json), $utf8)

Get-ChildItem $logDir -Filter '*.log' -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$KeepDays) } |
    Remove-Item -Force -ErrorAction SilentlyContinue

exit $code
