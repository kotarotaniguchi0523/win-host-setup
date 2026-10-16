# sanitize.ps1 - Generate a "personal-information-masked copy" from the source repository into public/
# Usage: pwsh -File tools/sanitize.ps1 [-Check]
#   -Check : do not generate; just report replacement counts (exit 1 if PII is detected in code)
#
# Policy:
#   - Text / config ... replace and write to public/
#   - Code (.ps1) ... **do not replace**. If PII remains, do not publish it (leak prevention) and warn
#     (code should use $env:USERPROFILE / $PSScriptRoot instead of real paths. tools/depii.ps1 detects violations)
# Replacement rules are in tools/pii-rules.ps1 (+ .agent/pii-rules.local.ps1)

[CmdletBinding()]
param([switch]$Check)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\common.ps1')
. (Join-Path $PSScriptRoot 'pii-rules.ps1')

$repo = Split-Path $PSScriptRoot -Parent
$pub  = Join-Path $repo 'public'
$rules = Get-PiiRules -Repo $repo
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# Resolve targets (file / glob / directory)
$targets = [System.Collections.Generic.List[string]]::new()
foreach ($pat in (Get-PiiTargets -Repo $repo)) {
    $full = Join-Path $repo $pat
    if (Test-Path $full -PathType Container) {
        $found = @(Get-ChildItem -Path $full -File -Recurse -ErrorAction SilentlyContinue)
    } else {
        $found = @(Get-ChildItem -Path $full -File -ErrorAction SilentlyContinue)
    }
    if ($found.Count -eq 0) { Write-Warning "skip（無い）: $pat"; continue }
    foreach ($f in $found) { if (-not $targets.Contains($f.FullName)) { $targets.Add($f.FullName) } }
}

# Publish every tool, including the sanitizer and the PII rules, but copy the rule definitions
# verbatim: they contain the pattern strings themselves, so the replacement pass would report a
# false PII hit and keep an outdated copy out of the public repository. CI runs tools/depii.ps1
# with tools/pii-rules.ps1 (-Check), and those copies must match the source.
$verbatim = @('tools\sanitize.ps1', 'tools\pii-rules.ps1', 'tools\depii.ps1')
$verbatimRel = @{}; foreach ($v in $verbatim) { $verbatimRel[$v] = $true }

$total = 0
$codeHits = 0
$report = @()
# Files written by this run (used to prune stale copies in public/ at the end)
$written = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

foreach ($srcPath in ($targets | Sort-Object)) {
    $rel = $srcPath.Substring($repo.Length + 1)
    # Build artifacts (Python / Node) are not published
    if ($rel -match '(^|\\)(\.venv|__pycache__|node_modules|\.git|\.mypy_cache|\.ruff_cache|\.pytest_cache)(\\|$)') { continue }

    $text = [string](Get-Content $srcPath -Raw -Encoding UTF8)
    if ($null -eq $text) { $text = '' }

    $n = 0; $new = $text
    # Rule definitions are published without the replacement pass (they hold the pattern strings)
    $ruleKeys = if ($verbatimRel.ContainsKey($rel)) { @() } else { @($rules.Keys) }
    foreach ($k in $ruleKeys) {
        if ([string]::IsNullOrEmpty($k)) { continue }
        $c = ([regex]::Matches($new, [regex]::Escape($k))).Count
        if ($c -gt 0) { $n += $c; $new = $new.Replace($k, $rules[$k]) }
    }

    $codeExt = @('.ps1', '.py', '.js', '.mjs', '.ts', '.sh', '.bash', '.cmd', '.bat', '.nu')
    if (($codeExt -contains [IO.Path]::GetExtension($srcPath).ToLower()) -and $n -gt 0) {
        # Do not rewrite code. Publishing would leak PII, so exclude it from publication and report it.
        $codeHits += $n
        $report += [pscustomobject]@{ Path = $rel; Replaced = $n; Action = '公開しない（コードに PII）' }
        continue
    }

    $total += $n
    $report += [pscustomobject]@{ Path = $rel; Replaced = $n; Action = '置換' }

    if (-not $Check) {
        $dst = Join-Path $pub $rel
        New-Item -ItemType Directory -Force -Path (Split-Path $dst -Parent) | Out-Null
        # Use WriteAllText so line endings are not lost (Set-Content -NoNewline drops the final newline)
        [IO.File]::WriteAllText($dst, $new, $utf8NoBom)
        $null = $written.Add($rel)
    }
}

$report | Format-Table -AutoSize
Write-Host "置換: $total 件 / 公開除外（コード）: $codeHits 件 / 対象 $($report.Count) ファイル"

if ($codeHits -gt 0) {
    Write-Warning ('コード（.ps1）に PII が {0} 件あります。public へは出していません。$env:USERPROFILE / $PSScriptRoot に直してください。' -f $codeHits)
}
if ($Check) {
    Write-Host '(チェックのみ。public/ は更新していません)'
    if ($codeHits -gt 0) { exit 1 }
    return
}

# Put a note that this is generated content at the top of the README
$readme = Join-Path $pub 'README.md'
if (Test-Path $readme) {
    $head = "> このリポジトリは ``tools/sanitize.ps1`` の生成物です（ユーザー名・パス・ホスト名をプレースホルダ化）。`n> 実環境の値は含みません。`n`n"
    [IO.File]::WriteAllText($readme, $head + [IO.File]::ReadAllText($readme, [Text.Encoding]::UTF8), $utf8NoBom)
}

# Prune stale files: public/ is generated, so anything not produced by this run (a deleted file,
# a file that is no longer a target, a file whose copy holds PII) must not stay published.
# Without this, deleting a file in the source leaves the old copy on GitHub (which has happened
# with renovate.yml, dependabot.yml and actions.lock).
$pubFull = (Resolve-Path $pub).Path
$pruned = 0
Get-ChildItem $pubFull -Recurse -File -Force | ForEach-Object {
    $relPath = $_.FullName.Substring($pubFull.Length + 1)
    if ($relPath -like '.git\*' -or $relPath -eq '.git') { return }
    if (-not $written.Contains($relPath)) {
        Remove-Item $_.FullName -Force
        Write-Host "[prune] $relPath"
        $pruned++
    }
}
if ($pruned -gt 0) { Write-Host "[i] public/ から $pruned 件の古いファイルを削除しました" }

# Drop directories that became empty (keep .git)
Get-ChildItem $pubFull -Recurse -Directory -Force |
    Where-Object { $_.FullName -notlike "$pubFull\.git*" } |
    Sort-Object { $_.FullName.Length } -Descending |
    ForEach-Object {
        if (-not (Get-ChildItem $_.FullName -Force | Select-Object -First 1)) { Remove-Item $_.FullName -Force }
    }

Write-Host "-> $pub"
