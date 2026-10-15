# mise-verify.ps1 — リポジトリの mise 設定をグローバルへ配置し、lock どおりに導入できるか検証する
# 使い方: pwsh -File tools/ci/mise-verify.ps1 [-Lock] [-Summary]
#   -Lock    : mise lock を実行し、結果（config/lock/locks）をリポジトリへ書き戻す（relock 用）
#   -Summary : 導入結果と更新候補を GITHUB_STEP_SUMMARY に出力する
# 終了コード: 0=成功 / 1=失敗（lock 不一致・導入失敗）

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

# npm は mise 上で node に依存するため、node を先に入れてから全体を導入する
try   { Invoke-Native mise @('install', 'node', '--locked') -What 'mise install node --locked' }
catch { Write-Warning "node の lock 導入に失敗したため lock 無しで再試行します: $($_.Exception.Message)"
        Invoke-Native mise @('install', 'node') -What 'mise install node' }

Invoke-Native mise @('install', '--locked') -What 'mise install --locked'

if ($Summary) {
    $outdated = (mise outdated --global 2>&1 | Out-String)
    $list     = (mise ls --global 2>&1 | Out-String)
    Add-Summary "## mise: 更新候補`n``````n$outdated```````n## mise: 導入済み`n``````n$list``````"
}

if (-not $Lock) { return }

# 結果をリポジトリへ書き戻す
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
