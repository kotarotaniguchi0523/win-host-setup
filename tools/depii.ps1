# depii.ps1 - Remove personal information from **source-side** publish-target files (in-place, idempotent)
# Usage: pwsh -File tools/depii.ps1 [-Check]
#   -Check : detect only, without rewriting. **Exit 1 if detection occurs inside code (.ps1)** (for CI).
#
# Policy:
#   - Text / config (.md / .json / .yaml / .toml / .yml) ... replace automatically
#   - Code (.ps1) ... **do not replace automatically** (path strings would break). Report detections and ask for manual fixes to $env:USERPROFILE etc.
#   - Put local-only data under `.agent/` (already in .gitignore)
# Rules consist of tools/pii-rules.ps1 (generic) plus .agent/pii-rules.local.ps1 (real values).

[CmdletBinding()]
param(
    [switch]$Check,
    # Skip the rules derived from this machine's account / host name (used by CI, where the runner's
    # own name is not personal information). Generic personal paths are covered by tools/ci/hygiene.ps1.
    [switch]$SkipEnvRules,
    # When files are given, inspect only those files (so hooks such as hk can pass them in)
    [Parameter(ValueFromRemainingArguments)][string[]]$Files = @()
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'pii-rules.ps1')

$rules     = Get-PiiRules -Repo $repo -SkipEnvRules:$SkipEnvRules
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$total     = 0
$codeHits  = 0
$report    = @()

# Resolve targets (file / glob / directory. If positional arguments are given, only those files)
$targets = [System.Collections.Generic.List[string]]::new()
if ($Files.Count -gt 0) {
    foreach ($f in $Files) {
        if (Test-Path $f -PathType Leaf) { $targets.Add((Resolve-Path $f).Path) }
    }
} else {
    foreach ($pat in (Get-PiiTargets -Repo $repo)) {
        $full = Join-Path $repo $pat
        if (Test-Path $full -PathType Container) {
            $found = @(Get-ChildItem -Path $full -File -Recurse -ErrorAction SilentlyContinue)
        } else {
            $found = @(Get-ChildItem -Path $full -File -ErrorAction SilentlyContinue)
        }
        foreach ($f in $found) { if (-not $targets.Contains($f.FullName)) { $targets.Add($f.FullName) } }
    }
}

foreach ($path in ($targets | Sort-Object)) {
    if ($path -like '*\.agent\*') { continue }
    if ($path -like '*\public\*')  { continue }
    # Build artifacts (Python / Node) are neither published nor scanned
    if ($path -match '\\(\.venv|__pycache__|node_modules|\.git|\.mypy_cache|\.ruff_cache|\.pytest_cache)\\') { continue }
    # Exclude the rule definitions themselves (their key strings would self-detect)
    $leaf = Split-Path $path -Leaf
    if ($leaf -in @('pii-rules.ps1', 'depii.ps1')) { continue }

    $text = [string](Get-Content $path -Raw -Encoding UTF8)
    if ([string]::IsNullOrEmpty($text)) { continue }

    $n = 0; $new = $text
    foreach ($k in $rules.Keys) {
        if ([string]::IsNullOrEmpty($k)) { continue }
        $c = ([regex]::Matches($new, [regex]::Escape($k))).Count
        if ($c -gt 0) { $n += $c; $new = $new.Replace($k, $rules[$k]) }
    }
    if ($n -eq 0) { continue }

    $rel = $path.Substring($repo.Length + 1)

    $codeExt = @('.ps1', '.py', '.js', '.mjs', '.ts', '.sh', '.bash', '.cmd', '.bat', '.nu')
    if ($codeExt -contains [IO.Path]::GetExtension($path).ToLower()) {
        # Do not auto-replace code (it would break)
        $codeHits += $n
        $report += [pscustomobject]@{ Path = $rel; Replaced = $n; Action = '要手直し（コード）' }
        continue
    }

    $total += $n
    $report += [pscustomobject]@{ Path = $rel; Replaced = $n; Action = '置換' }
    if (-not $Check) { [IO.File]::WriteAllText($path, $new, $utf8NoBom) }
}

$report | Format-Table -AutoSize
Write-Host "文章・設定の置換: $total 件 / コードの検出: $codeHits 件 / 対象 $($report.Count) ファイル"

if ($codeHits -gt 0) {
    Write-Warning ('コード（.ps1）に PII が {0} 件あります。実パスは $env:USERPROFILE / $PSScriptRoot 等に置き換えてください（自動置換はしません）。' -f $codeHits)
}
if ($Check) {
    Write-Host '(チェックのみ。ファイルは変更していません)'
    if ($codeHits -gt 0) { throw "コード（.ps1/.py 等）に PII が $codeHits 件あります。`$env:USERPROFILE / `$PSScriptRoot に直してください。" }
}
elseif ($total -eq 0 -and $codeHits -eq 0) { Write-Host '[ok] ソースは PII フリーです' }
else { Write-Host '[ok] ソースを更新しました' }
