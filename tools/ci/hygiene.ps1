# hygiene.ps1 - Hygiene check for a public repository (prevents leaking personal paths and account names)
# Usage: pwsh -File tools/ci/hygiene.ps1 [-Root <dir>] [-WarnOnly]
# Exit code: 0=clean / 1=findings (unless -WarnOnly)
#
# To avoid false positives, placeholders (%VAR% form) and ellipses (...) are excluded.

[CmdletBinding()]
param([string]$Root, [switch]$WarnOnly)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\common.ps1')

if (-not $Root) { $Root = Get-RepoRoot }
if (-not (Test-Path $Root)) { throw "対象ディレクトリがありません: $Root" }

# Detect only absolute paths of real home directories
#   C:\Users\<name>   /home/<name>   /Users/<name>   (<name> excludes %...% and ...)
$pattern = '(?i)(C:\\+Users\\+(?!%|\.\.\.)[A-Za-z0-9._-]+|/home/(?!%|\.\.\.)[A-Za-z0-9._-]+|/Users/(?!%|\.\.\.)[A-Za-z0-9._-]+)'
$emailPattern = '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'

$skipDirs = @('.git', '.agent', 'node_modules', 'public')

$files = Get-ChildItem -Path $Root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $p = $_.FullName; -not ($skipDirs | Where-Object { $p -match "[\\/]$([regex]::Escape($_))[\\/]" }) }

$pathHits  = @()
$emailHits = @()
foreach ($f in $files) {
    $text = [string](Get-Content $f.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue)
    if ([string]::IsNullOrEmpty($text)) { continue }
    if ([regex]::IsMatch($text, $pattern))      { $pathHits  += $f.FullName.Substring($Root.Length + 1) }
    if ([regex]::IsMatch($text, $emailPattern)) { $emailHits += $f.FullName.Substring($Root.Length + 1) }
}

if ($pathHits.Count -gt 0) {
    Write-Host "個人パスらしき記述（要修正）:" -ForegroundColor Red
    $pathHits | Sort-Object -Unique | ForEach-Object { Write-Host "  - $_" }
}
if ($emailHits.Count -gt 0) {
    Write-Host "メールアドレスらしき記述:" -ForegroundColor Yellow
    $emailHits | Sort-Object -Unique | ForEach-Object { Write-Host "  - $_" }
}

if ($pathHits.Count -eq 0) { Write-Host '[ok] 個人パスの露出なし' }

if ($pathHits.Count -gt 0 -and -not $WarnOnly) { exit 1 }
