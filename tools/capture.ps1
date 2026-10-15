# capture.ps1 — 実環境 → リポジトリ（source）へ書き出す
# 使い方: pwsh -File tools/capture.ps1
#  - ~/.config/mise/config.toml → mise/mise.toml
#  - ~/.config/mise/mise.lock   → mise/mise.lock
#  - ~/.config/mise/locks/      → mise/locks/
#  - ユーザー環境変数 → env/variables.md（**秘密は伏せる**）

[CmdletBinding()]
param([switch]$Force)
$ErrorActionPreference = 'Stop'
$repo    = Split-Path $PSScriptRoot -Parent
$miseSrc = Join-Path $env:USERPROFILE '.config\mise'
$miseDst = Join-Path $repo 'mise'

if (-not (Test-Path $miseSrc)) { throw "見つかりません: $miseSrc" }
New-Item -ItemType Directory -Force -Path $miseDst | Out-Null

# config.toml はリポジトリ内で mise に拾われないよう mise.toml の名前で保存する
if (-not $Force -and (Test-Path "$miseDst\mise.toml") -and ((Get-FileHash "$miseSrc\config.toml").Hash -ne (Get-FileHash "$miseDst\mise.toml").Hash)) {
    Write-Warning 'mise/mise.toml がホストと不一致: スキップ（-Force でホスト優先 / tools/pull.ps1 でリポジトリ優先）'
} else {
    Copy-Item (Join-Path $miseSrc 'config.toml') (Join-Path $miseDst 'mise.toml') -Force
    Write-Host '[ok] mise/mise.toml'
}
Copy-Item (Join-Path $miseSrc 'mise.lock')   (Join-Path $miseDst 'mise.lock') -Force
Write-Host "[ok] mise/mise.lock"

$locks = Join-Path $miseSrc 'locks'
if (Test-Path $locks) {
    $dst = Join-Path $miseDst 'locks'
    if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
    Copy-Item $locks $dst -Recurse -Force
    Write-Host "[ok] mise/locks （$((Get-ChildItem $dst -Recurse -File).Count) ファイル）"
}

# 環境変数（User スコープ）— 秘密は保存しない
$secret = @('CONTEXT7_API_KEY', 'GH_TOKEN', 'GITHUB_TOKEN', 'OPENAI_API_KEY', 'ANTHROPIC_API_KEY', 'TAKUMI_TOKEN', 'RENOVATE_TOKEN')
$envDir = Join-Path $repo 'env'
New-Item -ItemType Directory -Force -Path $envDir | Out-Null
$lines = @('# ユーザー環境変数（User スコープ・キャプチャ）', '', '| 変数 | 値 |', '|---|---|')
foreach ($name in ([Environment]::GetEnvironmentVariables('User').Keys | Sort-Object)) {
    $val = [Environment]::GetEnvironmentVariable($name, 'User')
    $shown = if ($secret -contains $name) { '<secret: リポジトリに保存しない>' } else { $val }
    $lines += ('| `' + $name + '` | `' + $shown + '` |')
}
$lines += @('', '> 生成: `tools/capture.ps1`。秘密値は保存していない。')
$lines | Set-Content (Join-Path $envDir 'variables.md') -Encoding UTF8
Write-Host "[ok] env/variables.md"
