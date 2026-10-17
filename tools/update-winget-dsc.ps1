# update-winget-dsc.ps1 - Use winget itself as the source of truth to update the pins in host.dsc.yaml
# Usage: pwsh -File tools/update-winget-dsc.ps1          # show the diff only
#         pwsh -File tools/update-winget-dsc.ps1 -Apply   # actually rewrite
# Target: lines of `settings: { id: <winget-id>, source: winget, version: '<ver>' }` (msstore is out of scope)

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
    $note = ''
    try {
        $show = winget show --exact --id $id --source winget --accept-source-agreements --disable-interactivity 2>$null
        $line = $show | Where-Object { $_ -match '^\s*Version:\s' } | Select-Object -First 1
        if ($line) { $new = ($line -replace '^\s*Version:\s*', '').Trim() }
    } catch { }
    # Only move forward: winget sometimes reports an older build than the installed one
    # (e.g. Canonical.Ubuntu offers 22.04 while 26.04 is installed), and pinning that would
    # downgrade the host. Unparsable versions are left alone too.
    $isNewer = $false
    if ($new -and $new -ne $cur) {
        $a = $null; $b = $null
        if ([version]::TryParse($cur, [ref]$a) -and [version]::TryParse($new, [ref]$b)) {
            if ($b -gt $a) { $isNewer = $true } else { $note = 'installed is newer (no downgrade)' }
        } else { $note = 'cannot compare versions (skipped)' }
    }
    $rows.Add([pscustomobject]@{ id = $id; current = $cur; latest = $new; update = $isNewer; note = $note })
    if ($isNewer) { $m.Value.Replace("version: '$cur'", "version: '$new'") } else { $m.Value }
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
