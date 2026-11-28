# apply.ps1 - repository (source) -> real environment
# Usage: pwsh -File tools/apply.ps1
#  - mise/mise.toml  -> copy to ~/.config/mise/config.toml
#  - mise/mise.lock  -> copy to ~/.config/mise/mise.lock
#  - mise/locks/     -> copy to ~/.config/mise/locks/ (pypi dependency graph)
#  - install missing tools with mise install
#  - set self-update guard env vars (AGY_CLI_DISABLE_AUTO_UPDATE=1)
# Note: existing config / lock are backed up with a timestamp

[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\common.ps1')
$repo    = Split-Path $PSScriptRoot -Parent
$miseSrc = Join-Path $repo 'mise'
$miseDst = Join-Path $env:USERPROFILE '.config\mise'

$srcCfg  = Join-Path $miseSrc 'mise.toml'
$srcLock = Join-Path $miseSrc 'mise.lock'
if (-not (Test-Path $srcCfg)) { throw "mise/mise.toml がありません（先に tools/capture.ps1）" }

New-Item -ItemType Directory -Force -Path $miseDst | Out-Null

# Back up the existing files
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
foreach ($f in 'config.toml', 'mise.lock') {
    $cur = Join-Path $miseDst $f
    if (Test-Path $cur) { Copy-Item $cur "$cur.bak-$stamp" -Force; Write-Host "[bak] $f -> $f.bak-$stamp" }
}

Copy-Item $srcCfg  (Join-Path $miseDst 'config.toml') -Force
Copy-Item $srcLock (Join-Path $miseDst 'mise.lock')   -Force
Write-Host "[ok] config.toml / mise.lock を適用"

$locksSrc = Join-Path $miseSrc 'locks'
if (Test-Path $locksSrc) {
    $locksDst = Join-Path $miseDst 'locks'
    if (Test-Path $locksDst) { Remove-Item $locksDst -Recurse -Force }
    Copy-Item $locksSrc $locksDst -Recurse -Force
    Write-Host "[ok] locks/ を適用"
}

# --- shell config (Nushell): shell/nushell -> ~/.config/nushell ---
$shellSrc = Join-Path $repo 'shell/nushell'
$shellDst = Join-Path (Get-HomeDir) '.config/nushell'
if (Test-Path $shellSrc) {
    New-Item -ItemType Directory -Force -Path $shellDst | Out-Null
    foreach ($f in 'config.nu', 'env.nu') {
        $p = Join-Path $shellSrc $f
        if (Test-Path $p) { Copy-Item $p (Join-Path $shellDst $f) -Force; Write-Host "[ok] shell/nushell/$f" }
    }
    $autoSrc = Join-Path $shellSrc 'autoload'
    if (Test-Path $autoSrc) {
        $autoDst = Join-Path $shellDst 'autoload'
        New-Item -ItemType Directory -Force -Path $autoDst | Out-Null
        Get-ChildItem $autoSrc -File | Where-Object { $_.Name -ne 'mise.nu' } | ForEach-Object {
            Copy-Item $_.FullName (Join-Path $autoDst $_.Name) -Force
            Write-Host "[ok] shell/nushell/autoload/$($_.Name)"
        }
    }
}

if (Get-Command nu -ErrorAction SilentlyContinue) {
    & nu -c 'mise activate nu' | Set-Content (Join-Path $shellDst 'autoload\mise.nu') -Encoding UTF8
    Write-Host '[ok] shell/nushell/autoload/mise.nu（再生成）'
}

# --- self-update guards (declaration → User environment) ---
# pin は「更新経路がパッケージマネージャだけ」のときだけ意味を持つ。自己更新する CLI は
# 上流の更新を環境変数で止める（tools/verify-host.ps1 の `agy-self-update` が同じ値を検査する）。
$selfUpdateGuards = [ordered]@{ 'AGY_CLI_DISABLE_AUTO_UPDATE' = '1' }   # agy (Google.AntigravityCLI)
foreach ($name in $selfUpdateGuards.Keys) {
    $want = $selfUpdateGuards[$name]
    if ([Environment]::GetEnvironmentVariable($name, 'User') -ne $want) {
        [Environment]::SetEnvironmentVariable($name, $want, 'User')
        Write-Host "[ok] $name=$want（User 環境変数）"
    }
}

Write-Host "`n--- mise install ---"
& mise install node    # install node first because npm depends on it
& mise install
if ($LASTEXITCODE -ne 0) {
    Write-Warning "mise install が失敗しました。依存順序の競合の可能性があるため再試行します。"
    & mise install
}

Write-Host "`n次の手順:"
Write-Host "  winget configure winget/host.dsc.yaml"
Write-Host "  tools/overrides.ps1 -Apply     # Windows 同梱コマンドの上書き（管理者で実行）"
Write-Host "  tools/skills-apply.ps1 -Lock   # Skills（APM）を ~/.apm へ適用"
Write-Host "  tools/fix-machine-path.ps1 （管理者で実行）"
