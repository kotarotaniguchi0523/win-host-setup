# mise-verify.ps1 - Deploy this repository's mise config globally and verify it installs as the lock specifies
# Usage: pwsh -File tools/ci/mise-verify.ps1 [-Lock] [-Summary]
#   -Lock    : run mise lock and write the results (config/lock/locks) back into the repository (for relock)
#   -Summary : write the install results and update candidates to GITHUB_STEP_SUMMARY
# Exit code: 0=success / 1=failure (lock mismatch or install failure)

[CmdletBinding()]
param([switch]$Lock, [switch]$Summary)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\common.ps1')

$repo    = Get-RepoRoot
$miseDst = Join-Path (Get-HomeDir) '.config/mise'
$srcToml = Join-Path $repo 'mise/mise.toml'
$srcLock = Join-Path $repo 'mise/mise.lock'
$srcLocks = Join-Path $repo 'mise/locks'

if (-not (Test-Path $srcToml)) { throw "mise/mise.toml が見つかりません: $srcToml" }
if (-not (Get-Command mise -ErrorAction SilentlyContinue)) { throw "mise が見つかりません（jdx/mise-action 等で導入してください）" }

New-Item -ItemType Directory -Force -Path $miseDst | Out-Null
Copy-Item $srcToml (Join-Path $miseDst 'config.toml') -Force
if (Test-Path $srcLock)  { Copy-Item $srcLock  (Join-Path $miseDst 'mise.lock')   -Force }
if (Test-Path $srcLocks) {
    $dstLocks = Join-Path $miseDst 'locks'
    if (Test-Path $dstLocks) { Remove-Item $dstLocks -Recurse -Force }
    Copy-Item $srcLocks $dstLocks -Recurse -Force
}

Invoke-Native mise @('--version') -What 'mise --version'

if ($Lock) { Invoke-Native mise @('lock', '--global') -What 'mise lock --global' }

# npm depends on node in mise, so install node first and then everything else
if ($Lock) {
    # Relock mode is allowed to bootstrap missing tool versions before rewriting the lock.
    Invoke-Native mise @('install', 'node') -What 'mise install node (relock)'
} else {
    Invoke-Native mise @('install', 'node', '--locked') -What 'mise install node --locked'
}

# mise's npm install hook needs pnpm, and the locked run does not provision it by itself, so install
# pnpm (npm's install dependency) before the full locked install.
if ($Lock) {
    Invoke-Native mise @('install', 'pnpm') -What 'mise install pnpm (relock)'
} else {
    Invoke-Native mise @('install', 'pnpm', '--locked') -What 'mise install pnpm --locked'
}

Invoke-Native mise @('install', '--locked') -What 'mise install --locked'

if ($Summary) {
    $outdated = (mise outdated --global 2>&1 | Out-String)
    $list     = (mise ls --global 2>&1 | Out-String)
    Add-Summary "## mise: 更新候補`n``````n$outdated```````n## mise: 導入済み`n``````n$list``````"
}

if (-not $Lock) { return }

# Write the results back into the repository
Copy-Item (Join-Path $miseDst 'config.toml') $srcToml -Force
Copy-Item (Join-Path $miseDst 'mise.lock')   $srcLock -Force
$dstLocks = Join-Path $miseDst 'locks'
if (Test-Path $dstLocks) {
    if (Test-Path $srcLocks) { Remove-Item $srcLocks -Recurse -Force }
    Copy-Item $dstLocks $srcLocks -Recurse -Force
} elseif (Test-Path $srcLocks) {
    Remove-Item $srcLocks -Recurse -Force
}
Write-Host '[ok] config / lock / locks をリポジトリへ書き戻しました'
