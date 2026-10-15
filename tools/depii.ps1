# depii.ps1 — **ソース側**の公開対象ファイルから個人情報を除去する（in-place・冪等）
# 使い方: pwsh -File tools/depii.ps1 [-Check]
#   -Check : 書き換えずに検出だけ行う。**コード（.ps1）内の検出があれば exit 1**（CI 用）。
#
# 方針:
#   - 文章・設定（.md / .json / .yaml / .toml / .yml）… 自動で置換する
#   - コード（.ps1）… **自動置換しない**（パス文字列が壊れるため）。検出を報告し、$env:USERPROFILE 等への手直しを促す
#   - ローカル専用データは `.agent/`（.gitignore 済み）へ置く
# ルールは tools/pii-rules.ps1（汎用）＋ .agent/pii-rules.local.ps1（実値）で構成される。

[CmdletBinding()]
param([switch]$Check)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'pii-rules.ps1')

$rules     = Get-PiiRules -Repo $repo
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$total     = 0
$codeHits  = 0
$report    = @()

# 対象を解決（ファイル / glob / ディレクトリ）
$targets = [System.Collections.Generic.List[string]]::new()
foreach ($pat in (Get-PiiTargets -Repo $repo)) {
    $full = Join-Path $repo $pat
    if (Test-Path $full -PathType Container) {
        $found = @(Get-ChildItem -Path $full -File -Recurse -ErrorAction SilentlyContinue)
    } else {
        $found = @(Get-ChildItem -Path $full -File -ErrorAction SilentlyContinue)
    }
    foreach ($f in $found) { if (-not $targets.Contains($f.FullName)) { $targets.Add($f.FullName) } }
}

foreach ($path in ($targets | Sort-Object)) {
    if ($path -like '*\.agent\*') { continue }
    if ($path -like '*\public\*')  { continue }
    # ルール定義自身は対象外（キー文字列が自己検出されるため）
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

    if ($path -like '*.ps1') {
        # コードは自動置換しない（壊れるため）
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
    if ($codeHits -gt 0) { exit 1 }
}
elseif ($total -eq 0 -and $codeHits -eq 0) { Write-Host '[ok] ソースは PII フリーです' }
else { Write-Host '[ok] ソースを更新しました' }
