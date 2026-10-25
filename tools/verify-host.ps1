# verify-host.ps1 - Verify that this host matches the repository's pinned state
# Usage: pwsh -File tools/verify-host.ps1 [-Report <path>] [-SkipNetwork] [-SkipWinget] [-Quiet]
# Exit: 0 = ok / 1 = drift / 2 = error
#
# Checks:
#   mise-missing    : every pinned tool is installed (mise ls --missing)
#   mise-config     : ~/.config/mise/{config.toml,mise.lock} match mise/
#   mise-pins       : installed versions match every pin (all array elements, e.g. node/python)
#   declarations    : source and public agree on the declaration/lock files
#   skills-files    : every deployed_files entry in skills/apm.lock.yaml exists
#   skills-skillmd  : every deployed skill directory has SKILL.md with a frontmatter name
#   winget-dsc      : winget configure test reports no drift
#   git             : public is level with origin/main and no worktree is dirty
#   apm             : apm doctor passes / stale dependencies are reported (unless -SkipNetwork)

[CmdletBinding()]
param(
    [string]$Report = '.agent/update-report.json',
    [switch]$SkipNetwork,
    [switch]$SkipWinget,
    [switch]$Quiet
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\common.ps1')

$repo = Get-RepoRoot
$homeDir = Get-HomeDir
$env:MISE_NOT_FOUND_AUTO_INSTALL = '0'   # never let a version check start an install

$checks = [System.Collections.Generic.List[object]]::new()
$drift  = [ordered]@{}
$actions = [System.Collections.Generic.List[string]]::new()

function Add-Check {
    param([string]$Name, [ValidateSet('ok', 'warn', 'ng', 'skip')][string]$Status, [string]$Detail)
    $checks.Add([pscustomobject]@{ name = $Name; status = $Status; detail = $Detail })
    if (-not $Quiet) {
        $mark = switch ($Status) { 'ok' { '[ok]' } 'warn' { '[!] ' } 'ng' { '[ng]' } 'skip' { '[--]' } }
        Write-Host ("{0} {1}: {2}" -f $mark, $Name, $Detail)
    }
}

function Get-ToolPins {
    param([Parameter(Mandatory)][string]$Path)
    $pins = [ordered]@{}
    $section = ''
    foreach ($line in (Get-Content $Path -Encoding UTF8)) {
        if ($line -match '^\s*\[([^\]]+)\]\s*$') { $section = $Matches[1]; continue }
        if ($section -ne 'tools') { continue }
        if ($line -match '^\s*#') { continue }
        if ($line -match '^\s*"([^"]+)"\s*=\s*\{[^}]*\bversion\s*=\s*"([^"]+)"') { $pins[$Matches[1]] = @($Matches[2]); continue }
        if ($line -match '^\s*([A-Za-z0-9_.:-]+)\s*=\s*\{[^}]*\bversion\s*=\s*"([^"]+)"') { $pins[$Matches[1]] = @($Matches[2]); continue }
        if ($line -match '^\s*"([^"]+)"\s*=\s*\[(.*)\]') {
            $vals = @([regex]::Matches($Matches[2], '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
            if ($vals.Count -gt 0) { $pins[$Matches[1]] = $vals }
            continue
        }
        if ($line -match '^\s*([A-Za-z0-9_.:-]+)\s*=\s*\[(.*)\]') {
            $vals = @([regex]::Matches($Matches[2], '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
            if ($vals.Count -gt 0) { $pins[$Matches[1]] = $vals }
            continue
        }
        if ($line -match '^\s*"([^"]+)"\s*=\s*"([^"]+)"') { $pins[$Matches[1]] = @($Matches[2]); continue }
        if ($line -match '^\s*([A-Za-z0-9_.:-]+)\s*=\s*"([^"]+)"') { $pins[$Matches[1]] = @($Matches[2]); continue }
    }
    return $pins
}

function Normalize-Version {
    param([string]$Value)
    if ($null -eq $Value) { return '' }
    return ($Value.Trim() -replace '^v', '')
}

try {
    # --- 1. mise: missing tools -------------------------------------------------
    $missingTools = @()
    try {
        $missingTools = @(& mise ls --missing 2>$null | Where-Object { $_ -match '\(missing\)' } | ForEach-Object { $_.Trim() })
        if ($missingTools.Count -eq 0) { Add-Check 'mise-missing' 'ok' '0' }
        else {
            $drift.miseMissing = $missingTools
            Add-Check 'mise-missing' 'ng' ("{0} 件: {1}" -f $missingTools.Count, (($missingTools | Select-Object -First 3) -join ' / '))
            $actions.Add('mise install（または mise run update:mise）')
        }
    } catch {
        Add-Check 'mise-missing' 'ng' $_.Exception.Message
    }

    # --- 2. mise: config / lock applied -----------------------------------------
    $configPairs = @(
        @{ name = 'mise-config'; src = 'mise/mise.toml'; dst = (Join-Path $homeDir '.config/mise/config.toml') },
        @{ name = 'mise-lock';   src = 'mise/mise.lock'; dst = (Join-Path $homeDir '.config/mise/mise.lock') }
    )
    foreach ($pair in $configPairs) {
        $srcPath = Join-Path $repo $pair.src
        if (-not (Test-Path $srcPath) -or -not (Test-Path $pair.dst)) {
            Add-Check $pair.name 'ng' 'ファイルが見つかりません'
            $actions.Add('mise run update:mise')
            continue
        }
        if ((Get-FileHash $srcPath).Hash -eq (Get-FileHash $pair.dst).Hash) {
            Add-Check $pair.name 'ok' 'repo と一致'
        } else {
            $drift[$pair.name] = $true
            Add-Check $pair.name 'ng' 'repo と不一致'
            $actions.Add('mise run update:mise')
        }
    }

    # --- 3. mise: installed versions match every pin ----------------------------
    try {
        $installedJson = & mise ls --installed --json 2>$null | ConvertFrom-Json
        $pins = Get-ToolPins -Path (Join-Path $repo 'mise/mise.toml')
        $pinDrift = @()
        foreach ($name in $pins.Keys) {
            $prop = $installedJson.PSObject.Properties[$name]
            $entries = @()
            if ($prop) { $entries = @($prop.Value) }
            foreach ($want in $pins[$name]) {
                $w = Normalize-Version $want
                $hit = @($entries | Where-Object {
                        (Normalize-Version $_.version) -eq $w -and ($_.installed -ne $false)
                    })
                if ($hit.Count -eq 0) { $pinDrift += "$name=$want" }
            }
        }
        if ($pinDrift.Count -eq 0) {
            Add-Check 'mise-pins' 'ok' ("{0} ツール" -f $pins.Keys.Count)
        } else {
            $drift.misePins = $pinDrift
            Add-Check 'mise-pins' 'ng' ("{0} 件: {1}" -f $pinDrift.Count, (($pinDrift | Select-Object -First 4) -join ', '))
            $actions.Add('mise run update:mise')
        }
    } catch {
        Add-Check 'mise-pins' 'ng' $_.Exception.Message
    }

    # --- 4. declarations: source and public agree -------------------------------
    $declFiles = @(
        'mise/mise.toml', 'mise/mise.lock', 'skills/apm.yml', 'skills/apm.lock.yaml',
        'winget/host.dsc.yaml', 'mise.toml', 'mise.lock'
    )
    $declDiff = @()
    foreach ($rel in $declFiles) {
        $a = Join-Path $repo $rel
        $b = Join-Path (Join-Path $repo 'public') $rel
        if (-not (Test-Path $a) -or -not (Test-Path $b)) { continue }
        if ((Get-FileHash $a).Hash -ne (Get-FileHash $b).Hash) { $declDiff += $rel }
    }
    if ($declDiff.Count -eq 0) {
        Add-Check 'declarations' 'ok' 'source と public が一致'
    } else {
        $drift.declarations = $declDiff
        Add-Check 'declarations' 'ng' (($declDiff | Select-Object -First 4) -join ', ')
        $actions.Add('mise run update:pull')
    }

    # --- 5. skills: every deployed file exists ----------------------------------
    $lockPath = Join-Path $repo 'skills/apm.lock.yaml'
    if (Test-Path $lockPath) {
        $missingFiles = @()
        foreach ($line in (Get-Content $lockPath -Encoding UTF8)) {
            if ($line -match '^\s*-\s+(\.(?:agents/skills|config/opencode/skills)/\S+?)\s*$') {
                $rel = $Matches[1].TrimEnd('/')
                $p = Join-Path $homeDir ($rel -replace '/', '\')
                if (-not (Test-Path $p)) { $missingFiles += $rel }
            }
        }
        if ($missingFiles.Count -eq 0) {
            Add-Check 'skills-files' 'ok' '全て配置済み'
        } else {
            $drift.skillsMissingFiles = $missingFiles
            Add-Check 'skills-files' 'ng' ("{0} 件欠落（例: {1}）" -f $missingFiles.Count, ($missingFiles | Select-Object -First 2) -join ', ')
            $actions.Add('mise run update:skills')
        }
    }

    # --- 6. skills: SKILL.md present and named ----------------------------------
    $noSkillMd = @()
    $unnamed = @()
    foreach ($root in @((Join-Path $homeDir '.agents/skills'), (Join-Path $homeDir '.config/opencode/skills'))) {
        if (-not (Test-Path $root)) { continue }
        foreach ($dir in (Get-ChildItem $root -Directory -ErrorAction SilentlyContinue)) {
            $skillMd = Join-Path $dir.FullName 'SKILL.md'
            if (-not (Test-Path $skillMd)) { $noSkillMd += $dir.Name; continue }
            $head = Get-Content $skillMd -TotalCount 15 -Encoding UTF8 -ErrorAction SilentlyContinue
            if (-not ($head | Where-Object { $_ -match '^name:\s*\S' })) { $unnamed += $dir.Name }
        }
    }
    if ($noSkillMd.Count -eq 0) {
        Add-Check 'skills-skillmd' 'ok' 'SKILL.md あり'
    } else {
        $drift.skillsNoSkillMd = $noSkillMd
        Add-Check 'skills-skillmd' 'ng' ("SKILL.md 欠落: {0}" -f (($noSkillMd | Select-Object -First 4) -join ', '))
        $actions.Add('mise run update:skills')
    }
    if ($unnamed.Count -gt 0) {
        Add-Check 'skills-frontmatter' 'warn' ("name が無い: {0}" -f (($unnamed | Select-Object -First 4) -join ', '))
    } else {
        Add-Check 'skills-frontmatter' 'ok' 'name あり'
    }

    # --- 7. winget DSC ----------------------------------------------------------
    # Resource allowlist first (offline): the configuration must only use WinGetPackage.
    $dscPath = Join-Path $repo 'winget/host.dsc.yaml'
    if (Test-Path $dscPath) {
        $allowedResource = 'Microsoft.WinGet.DSC/WinGetPackage'
        $badResources = @()
        foreach ($line in (Get-Content $dscPath -Encoding UTF8)) {
            if ($line -match '^\s*-\s*resource:\s*(\S+)\s*$' -and $Matches[1] -ne $allowedResource) { $badResources += $Matches[1] }
            if ($line -match '^\s*module:\s*(\S+)\s*$' -and $Matches[1] -ne 'Microsoft.WinGet.DSC') { $badResources += "module:$($Matches[1])" }
        }
        if ($badResources.Count -eq 0) {
            Add-Check 'dsc-resources' 'ok' 'WinGetPackage のみ'
        } else {
            $drift.dscResources = @($badResources | Select-Object -Unique)
            Add-Check 'dsc-resources' 'ng' (($badResources | Select-Object -Unique) -join ', ')
            $actions.Add('winget/host.dsc.yaml は WinGetPackage 以外の resource を許可しない')
        }
    }

    if ($SkipWinget) {
        Add-Check 'winget-dsc' 'skip' '-SkipWinget'
    } elseif (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Add-Check 'winget-dsc' 'skip' 'winget がありません'
    } else {
        $dscPath = Join-Path $repo 'winget/host.dsc.yaml'
        $out = & winget configure test -f $dscPath --accept-configuration-agreements 2>&1
        $notInState = @()
        $current = ''
        foreach ($line in $out) {
            if ($line -match '^WinGetPackage \[(.+?)\]') { $current = $Matches[1] }
            elseif ($line -match 'is not in the described configuration state' -and $current) { $notInState += $current }
        }
        if ($notInState.Count -eq 0) {
            Add-Check 'winget-dsc' 'ok' '全て望ましい状態'
        } else {
            $drift.dscNotInState = @($notInState | Select-Object -Unique)
            Add-Check 'winget-dsc' 'ng' (($notInState | Select-Object -Unique) -join ', ')
            $actions.Add('管理者で mise run update:winget（または winget configure -f winget/host.dsc.yaml）')
        }
    }

    # --- 8. git -----------------------------------------------------------------
    if (-not $SkipNetwork) {
        & git -C (Join-Path $repo 'public') fetch --prune 2>$null | Out-Null
    }
    $counts = (& git -C (Join-Path $repo 'public') rev-list --left-right --count 'HEAD...origin/main' 2>$null) -split '\s+'
    $ahead = [int]$counts[0]; $behind = [int]$counts[1]
    $pubDirty = @(& git -C (Join-Path $repo 'public') status --porcelain 2>$null).Count
    $srcDirty = @(& git status --porcelain 2>$null).Count
    if ($ahead -eq 0 -and $behind -eq 0) {
        Add-Check 'git-remote' 'ok' 'public = origin/main'
    } else {
        $drift.git = @{ ahead = $ahead; behind = $behind }
        Add-Check 'git-remote' 'ng' ("ahead={0} behind={1}" -f $ahead, $behind)
        $actions.Add('mise run update:pull')
    }
    if ($pubDirty -eq 0 -and $srcDirty -eq 0) {
        Add-Check 'git-worktree' 'ok' 'クリーン'
    } else {
        Add-Check 'git-worktree' 'warn' ("public={0} source={1} 件の変更" -f $pubDirty, $srcDirty)
    }

    # --- 9. apm -----------------------------------------------------------------
    if ($SkipNetwork) {
        Add-Check 'apm' 'skip' '-SkipNetwork'
    } elseif (-not (Get-Command apm -ErrorAction SilentlyContinue)) {
        Add-Check 'apm' 'skip' 'apm がありません'
    } else {
        & apm doctor *>$null
        if ($LASTEXITCODE -eq 0) { Add-Check 'apm-doctor' 'ok' 'pass' }
        else { Add-Check 'apm-doctor' 'warn' "exit=$LASTEXITCODE" }

        $outdatedOut = & apm outdated -g 2>&1 | Out-String
        $summary = ($outdatedOut -split "`n" | Where-Object { $_ -match 'outdated dependencies found' } | Select-Object -First 1)
        if ($summary -match '(\d+)') {
            $n = [int]$Matches[1]
            $drift.apmOutdated = $n
            if ($n -eq 0) { Add-Check 'apm-outdated' 'ok' '0' }
            else {
                Add-Check 'apm-outdated' 'warn' "$n 件（Renovate 対象外の Skill 更新を含む）"
                $actions.Add('apm outdated -g を確認（major は Dashboard 承認）')
            }
        } else {
            Add-Check 'apm-outdated' 'ok' '判定不能（指摘なし）'
        }
    }
}
catch {
    Add-Check 'internal' 'ng' $_.Exception.Message
}

# --- report -------------------------------------------------------------------
$ngCount = @($checks | Where-Object { $_.status -eq 'ng' }).Count
$warnCount = @($checks | Where-Object { $_.status -eq 'warn' }).Count
$result = if ($ngCount -gt 0) { 'drift' } else { 'ok' }

$reportPath = $Report
if (-not [IO.Path]::IsPathRooted($reportPath)) { $reportPath = Join-Path $repo $reportPath }
$reportDir = Split-Path $reportPath -Parent
if ($reportDir -and -not (Test-Path $reportDir)) { New-Item -ItemType Directory -Force -Path $reportDir | Out-Null }

$payload = [ordered]@{
    generatedAt = (Get-Date).ToString('o')
    result      = $result
    summary     = @{ ok = @($checks | Where-Object { $_.status -eq 'ok' }).Count; warn = $warnCount; ng = $ngCount }
    checks      = $checks
    drift       = $drift
    nextActions = @($actions | Select-Object -Unique)
}
$utf8 = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($reportPath, ($payload | ConvertTo-Json -Depth 8), $utf8)

if (-not $Quiet) {
    Write-Host ''
    Write-Host ("result: {0} (ok={1} warn={2} ng={3})" -f $result, $payload.summary.ok, $warnCount, $ngCount)
    Write-Host ("report: {0}" -f $reportPath)
    if ($actions.Count -gt 0) {
        Write-Host 'next actions:'
        foreach ($a in ($actions | Select-Object -Unique)) { Write-Host "  - $a" }
    }
}

if ($ngCount -gt 0) { exit 1 } else { exit 0 }
