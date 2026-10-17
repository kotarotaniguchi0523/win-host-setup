# fix-machine-path.ps1 - Clean up the Machine PATH (**run with administrator rights**)
# Usage: in an administrator PowerShell:  pwsh -File tools/fix-machine-path.ps1 [-Apply]
#   Without -Apply, this is a "preview" only
#
# Policy:
#   Machine PATH = Windows defaults + all-users shared entries only
#   - remove non-existent paths
#   - remove duplicates
#   - remove entries under %USERPROFILE% (per-user apps) -> those go into the User PATH

[CmdletBinding()]
param([switch]$Apply)
$ErrorActionPreference = 'Stop'

$elev = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

$cur = [Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';' | Where-Object { $_ }
function Norm($p) { ($p -replace '\\+$', '').Trim().ToLower() }

$keep = @(); $drop = @(); $seen = @{}
foreach ($p in $cur) {
    $n = Norm $p
    if (-not (Test-Path $p))            { $drop += "$p   （存在しない）"; continue }
    if ($n -like 'c:\users\*')          { $drop += "$p   （個人アプリ → User PATH へ）"; continue }
    if ($seen.ContainsKey($n))          { $drop += "$p   （重複）"; continue }
    $seen[$n] = $true; $keep += $p
}

Write-Host "=== 除去予定 ($($drop.Count)) ===" -ForegroundColor Yellow
$drop | ForEach-Object { Write-Host "  - $_" }
Write-Host "`n=== 残る ($($keep.Count)) ===" -ForegroundColor Green
$i = 0; $keep | ForEach-Object { $i++; Write-Host ("  {0,2}. {1}" -f $i, $_) }

if (-not $Apply) { Write-Host "`nプレビューのみ。-Apply を付けると適用します。" -ForegroundColor Cyan; return }
if (-not $elev)  { throw "Machine PATH の変更には管理者権限が必要です。管理者の PowerShell で再実行してください。" }

$bakDir = Join-Path (Split-Path $PSScriptRoot -Parent) '.agent'
New-Item -ItemType Directory -Force -Path $bakDir | Out-Null
$bak = Join-Path $bakDir ("machine-path-backup-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".txt")
$cur -join "`n" | Set-Content $bak -Encoding UTF8
Write-Host "[bak] $bak"

[Environment]::SetEnvironmentVariable('Path', ($keep -join ';'), 'Machine')
Write-Host "[ok] Machine PATH を更新（$($cur.Count) → $($keep.Count) 件）" -ForegroundColor Green
Write-Host "注意: 反映には新しいシェル（またはサインアウト/イン）が必要です。"
