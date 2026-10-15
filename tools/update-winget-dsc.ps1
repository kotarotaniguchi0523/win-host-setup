# update-winget-dsc.ps1 — winget 自身を情報源にして host.dsc.yaml のピンを最新化する
# 使い方: pwsh -File tools/update-winget-dsc.ps1          # 差分の表示のみ
#         pwsh -File tools/update-winget-dsc.ps1 -Apply   # 実際に書き換え
# 対象: `settings: { id: <winget-id>, source: winget, version: '<ver>' }` の行（msstore は対象外）

[CmdletBinding()]
param([switch]$Apply)
$ErrorActionPreference = 'Stop'

$repo = Split-Path $PSScriptRoot -Parent
$dsc  = Join-Path $repo 'winget/host.dsc.yaml'
if (-not (Test-Path $dsc)) { throw "見つかりません: $dsc" }

$text = [IO.File]::ReadAllText($dsc, [Text.Encoding]::UTF8)
$rx   = [regex]"settings: \{ id: (?<id>[^,]+), source: winget, version: '(?<ver>[^']+)' \}"
$rows = [System.Collections.Generic.List[object]]::new()

$evaluator = {
    param($m)
    $id  = $m.Groups['id'].Value.Trim()
    $cur = $m.Groups['ver'].Value
    $new = $cur
    try {
        $show = winget show --exact --id $id --source winget --accept-source-agreements --disable-interactivity 2>$null
        $line = $show | Where-Object { $_ -match '^\s*Version:\s' } | Select-Object -First 1
        if ($line) { $new = ($line -replace '^\s*Version:\s*', '').Trim() }
    } catch { }
    $isNew = ($new -and $new -ne $cur)
    $rows.Add([pscustomobject]@{ id = $id; current = $cur; latest = $new; update = $isNew })
    if ($isNew) { $m.Value.Replace("version: '$cur'", "version: '$new'") } else { $m.Value }
}

$out = $rx.Replace($text, $evaluator)
$rows | Format-Table -AutoSize
$changed = @($rows | Where-Object { $_.update })

if ($Apply -and $changed.Count -gt 0) {
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($dsc, $out, $utf8)
    Write-Host "[ok] $($changed.Count) 件を更新: $((($changed | ForEach-Object { "$($_.id) $($_.current)->$($_.latest)" }) -join ', '))"
} elseif ($changed.Count -eq 0) {
    Write-Host "[ok] すべて最新（winget の最新版と一致）"
} else {
    Write-Host "[i] $($changed.Count) 件の更新候補があります（-Apply で書き込み）"
}
