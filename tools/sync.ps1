# sync.ps1 - Do "update locally -> repository -> publish" with a single command
# Usage: pwsh -File tools/sync.ps1 [-Message "..."] [-NoPush] [-Check]
#  1. capture.ps1        : real environment's mise config -> repository
#  2. skills-capture.ps1 : real environment's Skills (~/.apm and local) -> repository
#  3. depii.ps1          : remove PII from the source side
#  4. sanitize.ps1       : regenerate public/ (mask personal information)
#  5. commit source / public and push public
# Stop at the point of failure (also treat abnormal git exits as exceptions).

[CmdletBinding()]
param([string]$Message = "", [switch]$NoPush, [switch]$Check)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\common.ps1')

$repo = Split-Path $PSScriptRoot -Parent
$pub  = Join-Path $repo 'public'
if ([string]::IsNullOrWhiteSpace($Message)) { $Message = "chore: sync from host ($(Get-Date -Format 'yyyy-MM-dd HH:mm'))" }

function Invoke-Step {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][scriptblock]$Body)
    Write-Host "`n=== $Name ===" -ForegroundColor Cyan
    & $Body
}

# 1-4) generate / convert (child scripts propagate exceptions, so call them directly)
Invoke-Step 'pull（public → source → 実環境。Renovate/Dependabot の更新を取り込む）' {
    if (Test-Path (Join-Path $PSScriptRoot 'pull.ps1')) {
        # -Apply: reflects into the real environment before capture (host is the source of truth), so pulled content is not lost
        & (Join-Path $PSScriptRoot 'pull.ps1') -Apply
    }
}
Invoke-Step 'capture（mise）'          { & (Join-Path $PSScriptRoot 'capture.ps1') -Force }
Invoke-Step 'skills-capture（Skills）' { & (Join-Path $PSScriptRoot 'skills-capture.ps1') -Force }
Invoke-Step 'depii（PII 除去）'        { & (Join-Path $PSScriptRoot 'depii.ps1') }
Invoke-Step 'sanitize（公開版）'       { & (Join-Path $PSScriptRoot 'sanitize.ps1') }

if ($Check) {
    Write-Host "`n[ok] -Check のためコミット / push はしていません" -ForegroundColor Green
    return
}

# 5) commit (do nothing when there are no changes)
function Commit-IfChanged {
    param([Parameter(Mandatory)][string]$GitDir, [Parameter(Mandatory)][string]$Label)
    Invoke-Native 'git' @('-C', $GitDir, 'add', '-A') -What "git add ($Label)"

    $hasStaged = -not (Test-Native 'git' @('-C', $GitDir, 'diff', '--cached', '--quiet'))
    if (-not $hasStaged) { Write-Host "[i] $Label に変更なし"; return $false }

    Invoke-Native 'git' @('-C', $GitDir, 'commit', '-q', '-m', $Message) -What "git commit ($Label)"
    Write-Host "[ok] $Label をコミット"
    return $true
}

Invoke-Step 'source リポジトリ' { Commit-IfChanged -GitDir $repo -Label 'source' | Out-Null }
Invoke-Step 'public リポジトリ' {
    if (-not (Test-Path (Join-Path $pub '.git'))) { throw "public/ が git リポジトリではありません" }
    $committed = Commit-IfChanged -GitDir $pub -Label 'public'
    if ($NoPush) { Write-Host '[i] -NoPush のため push しません'; return }
    if (-not $committed) {
        # Even with no commit, there may be unpushed commits left over
        $ahead = (git -C $pub rev-list --count '@{u}..HEAD' 2>$null)
        if (-not $ahead -or [int]$ahead -eq 0) { Write-Host '[i] push する変更なし'; return }
    }
    Invoke-Native 'git' @('-C', $pub, 'push') -What "git push (public)"
    Write-Host '[ok] public を push'
}
