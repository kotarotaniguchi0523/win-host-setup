# secrets.ps1 — 秘密情報のスキャン（betterleaks + secretlint）
# 使い方: pwsh -File tools/lint/secrets.ps1 [<paths...>]
#   paths 省略時: betterleaks は git 履歴、secretlint は主要ファイル
# 終了コード: 0=クリーン / 1=検出あり
#
# 注: secretlint の preset（@secretlint/secretlint-rule-preset-recommend）は別パッケージのため、
#     mise のインストール先から NODE_PATH を解決して読み込む。

[CmdletBinding()]
param([string[]]$Paths = @())
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\common.ps1')

$repo = Get-RepoRoot
Push-Location $repo
try {
    $failed = $false

    # --- betterleaks（履歴 + 追跡ファイル）---
    # 注: .agent/（非公開の退避データ）等の未追跡ファイルは対象外にする。
    #     追跡ファイルのみを対象にすることで「リポジトリに入るもの」を検査する。
    if (-not (Get-Command betterleaks -ErrorAction SilentlyContinue)) { throw 'betterleaks が見つかりません（mise install）' }
    Write-Host '=== betterleaks (git history) ===' -ForegroundColor Cyan
    & betterleaks git $repo --no-banner
    if ($LASTEXITCODE -ne 0) { $failed = $true }

    Write-Host '=== betterleaks (tracked files) ===' -ForegroundColor Cyan
    $tracked = @(git -C $repo ls-files)
    if ($tracked.Count -gt 0) {
        & betterleaks dir @tracked --no-banner
        if ($LASTEXITCODE -ne 0) { $failed = $true }
    }

    # --- secretlint（preset 付き）---
    if (-not (Get-Command secretlint -ErrorAction SilentlyContinue)) {
        Write-Warning 'secretlint が見つかりません（mise install）。betterleaks のみで判定します。'
    } else {
        Write-Host '=== secretlint ===' -ForegroundColor Cyan
        $presetRoot = Join-Path (Get-HomeDir) 'AppData\Local\mise\installs\npm-secretlint-secretlint-rule-preset-recommend'
        if (-not (Test-Path $presetRoot)) { $presetRoot = Join-Path (Get-HomeDir) '.local/share/mise/installs/npm-secretlint-secretlint-rule-preset-recommend' }
        $pkg = Get-ChildItem $presetRoot -Recurse -Directory -Filter 'secretlint-rule-preset-recommend' -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $pkg) { throw "secretlint の preset が見つかりません（mise install npm:@secretlint/secretlint-rule-preset-recommend）" }
        $env:NODE_PATH = Split-Path (Split-Path $pkg.FullName -Parent) -Parent

        if ($Paths.Count -eq 0) {
            $Paths = @('**/*.md', '**/*.json', '**/*.toml', '**/*.yml', '*.ps1', 'tools/**/*.ps1')
        }
        & secretlint @Paths
        if ($LASTEXITCODE -ne 0) { $failed = $true }
    }

    if ($failed) { throw '秘密情報の可能性を検出しました' }
    Write-Host '[ok] 秘密情報なし'
} finally { Pop-Location }
