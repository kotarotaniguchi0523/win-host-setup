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
    # Never interpret a network/API/parse failure as "up to date".
    $show = & winget show --exact --id $id --source winget --accept-source-agreements --disable-interactivity 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) { throw "winget show failed for $id (exit $exitCode)" }
    # `winget show` prints its labels in the OS display language, and the console decoding of
    # that text is not stable enough to match on. Parse structurally instead: the "found" line
    # carries the id in brackets and the next line is the version (label: value).
    $lines = @($show)
    $new = $null
    $startIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -like "*[$id]*") { $startIdx = $i; break } }
    if ($startIdx -ge 0) {
        for ($j = $startIdx + 1; $j -lt $lines.Count; $j++) {
            if ($lines[$j] -match '^\s*[^:：]+[:：]\s*(\S+)\s*$') { $new = $Matches[1].Trim(); break }
        }
    }
    if (-not $new) { throw "winget show returned no Version for $id" }
    if (-not $new) { throw "winget show returned an empty Version for $id" }
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
