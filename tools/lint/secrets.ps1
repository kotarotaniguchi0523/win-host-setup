# secrets.ps1 - Secret scanning (betterleaks + secretlint)
# Usage: pwsh -File tools/lint/secrets.ps1 [<paths...>]
#   When paths is omitted: betterleaks scans the git history, secretlint scans the main files
# Exit code: 0=clean / 1=findings
#
# Note: secretlint's preset (@secretlint/secretlint-rule-preset-recommend) is a separate package, so
#       resolve NODE_PATH from the mise install location and load it from there.

[CmdletBinding()]
param([string[]]$Paths = @())
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\common.ps1')

$repo = Get-RepoRoot
Push-Location $repo
try {
    $failed = $false

    # --- betterleaks (history + tracked files) ---
    # Note: exclude untracked files such as .agent/ (private backup data).
    #       Targeting only tracked files checks "what goes into the repository".
    if (-not (Get-Command betterleaks -ErrorAction SilentlyContinue)) { throw 'betterleaks が見つかりません（mise install）' }
    Write-Host '=== betterleaks (git history) ===' -ForegroundColor Cyan
    & betterleaks git $repo --no-banner
    if ($LASTEXITCODE -ne 0) { $failed = $true }

    Write-Host '=== betterleaks (tracked files) ===' -ForegroundColor Cyan
    $tracked = @(git -C $repo ls-files)
    if ($tracked.Count -gt 0) {
        # Split the scan to stay under the command-line length limit (about 32KB on Windows)
        $batch = @(); $len = 0
        foreach ($f in $tracked) {
            $batch += $f; $len += $f.Length + 1
            if ($len -gt 6000) {
                & betterleaks dir @batch --no-banner
                if ($LASTEXITCODE -ne 0) { $failed = $true }
                $batch = @(); $len = 0
            }
        }
        if ($batch.Count -gt 0) {
            & betterleaks dir @batch --no-banner
            if ($LASTEXITCODE -ne 0) { $failed = $true }
        }
    }

    # --- secretlint (with preset) ---
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
