# skills-apply.ps1 - Deploy this repository's skills/apm.yml to ~/.apm and apply it
# Usage: pwsh -File tools/skills-apply.ps1 [-Lock]
#   -Lock : after deploying, run `apm lock --global` to regenerate apm.lock.yaml and copy it back into the repository
#
# APM prerequisites (measured):
#   - `--global` does not depend on the CWD (it uses ~/.apm directly). Only audit looks at the CWD project
#   - Integration of new dependencies "may not run on the first install but on the next run" -> verify against the actual state and re-run
#   - It may return exit=1 for advisory messages (apm compile -g) -> do not rely on the exit code
#
# Known upstream bugs (workarounds are implemented in this script):
#   - microsoft/apm#2927 APM 0.30.0 audit reports freshly installed skills as unintegrated on Windows (missed first integration)
#   - microsoft/apm#3056 UnicodeDecodeError: 'gbk' codec can't decode byte on Windows during 'apm install' (cp932 family)
#   - microsoft/apm#3206 apm install writes stale version to apm.lock.yaml when apm_modules/ holds the previous tag
#   - microsoft/apm#2885 [FEATURE] Support atomic exact dependency reconciliation for global installs

[CmdletBinding()]
param([switch]$Lock)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\common.ps1')

$repo = Split-Path $PSScriptRoot -Parent
$src  = Join-Path $repo 'skills'
$dst  = Join-Path (Get-HomeDir) '.apm'
$skillsDest = Join-Path (Get-HomeDir) '.agents/skills'

if (-not (Test-Path (Join-Path $src 'apm.yml'))) { throw "skills/apm.yml がありません" }

# Resolve the apm CLI (look in PATH, then the winget package location)
$apm = (Get-Command apm -ErrorAction SilentlyContinue).Source
if (-not $apm) { $apm = Resolve-Apm }
Write-Host "[i] apm: $apm"

New-Item -ItemType Directory -Force -Path $dst | Out-Null

# Back up existing files (keep at most 2 generations)
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
foreach ($f in 'apm.yml', 'apm.lock.yaml') {
    $cur = Join-Path $dst $f
    if (Test-Path $cur) { Copy-Item $cur "$cur.bak-$stamp" -Force; Write-Host "[bak] $f" }
}
Get-ChildItem $dst -Filter '*.bak-*' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -Skip 2 |
    ForEach-Object { Remove-Item $_.FullName -Force }

Copy-Item (Join-Path $src 'apm.yml') (Join-Path $dst 'apm.yml') -Force
Write-Host "[ok] ~/.apm/apm.yml"

# --- lock (--global does not depend on the CWD) ---
# Note: do not name this variable $lock - PowerShell is case-insensitive, so it would be the
#       same variable as the -Lock switch parameter and assigning a string to it fails.
if ($Lock) {
    & $apm lock --global | Out-Null
    $lockPath = Join-Path $dst 'apm.lock.yaml'
    if (Test-Path $lockPath) { Copy-Item $lockPath (Join-Path $src 'apm.lock.yaml') -Force; Write-Host '[ok] skills/apm.lock.yaml を更新' }
}

# --- deploy (compare the lock's deployed_files with the actual state and re-run if anything is missing) ---
# The declared targets are codex (~/.agents/skills) and opencode (~/.config/opencode/skills); both are verified.
function Test-SkillsDeployed {
    $lockPath = Join-Path $dst 'apm.lock.yaml'
    if (-not (Test-Path $lockPath)) { return $true }
    $missing = @()
    foreach ($line in (Get-Content $lockPath -Encoding UTF8)) {
        # Check every deployed entry (files as well as directories). The first install can copy
        # only part of a package (e.g. .codex-plugin/ and references/ without SKILL.md), so
        # checking only the top-level directory would miss that.
        if ($line -match '^\s*-\s+(\.(?:agents/skills|config/opencode/skills)/\S+?)\s*$') {
            $rel = $Matches[1].TrimEnd('/')
            $p = Join-Path (Get-HomeDir) ($rel -replace '/', '\')
            if (-not (Test-Path $p)) { $missing += $rel }
        }
    }
    if ($missing.Count -gt 0) { Write-Host "[i] 未展開: $($missing -join ', ')" }
    return ($missing.Count -eq 0)
}

$null = & $apm install --global 2>&1   # it may return exit=1 for advisories, so ignore the exit code
if (-not (Test-SkillsDeployed)) {
    Write-Host '[i] 未展開の Skill があるため install を再実行します（APM の初回統合の癖）'
    $null = & $apm install --global 2>&1
    if (-not (Test-SkillsDeployed)) { throw 'apm install を 2 回実行しても Skill が展開されません（apm.yml と lock を確認してください）' }
}
Write-Host '[ok] すべての APM Skill が展開されています'

# --- deploy local skills (skills/local/*) to ~/.agents/skills ---
$localSrc = Join-Path $src 'local'
if (Test-Path $localSrc) {
    New-Item -ItemType Directory -Force -Path $skillsDest | Out-Null
    foreach ($d in (Get-ChildItem $localSrc -Directory)) {
        $t = Join-Path $skillsDest $d.Name
        if (Test-Path $t) { Remove-Item $t -Recurse -Force }
        Copy-Item $d.FullName $t -Recurse -Force
        Write-Host "[ok] ~/.agents/skills/$($d.Name)（自作）"
    }
}

Write-Host "`n検証: apm audit --ci / apm outdated --global / waza check"
exit 0   # judge success by the final state (all skills deployed)
