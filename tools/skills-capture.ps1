# skills-capture.ps1 - Write the real environment's Skills into the repository (for local updates -> push)
# Usage: pwsh -File tools/skills-capture.ps1 [-Check]
#   -Check : do not rewrite; only show diffs and planned overwrites
#  - ~/.apm/apm.yml / apm.lock.yaml         → skills/
#  - ~/.agents/skills/* that are not APM-managed -> skills/local/* (local skills)
#
# * Direction: local skills use **the host (~/.agents/skills) as the source of truth**. An existing skills/local/<name> is
#   replaced with the host's content (and that is always logged). If you edited the repository side directly,
#   first run tools/skills-apply.ps1 to reflect it into the host, then run this script.

[CmdletBinding()]
param([switch]$Check, [switch]$Force)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\common.ps1')

$repo     = Split-Path $PSScriptRoot -Parent
$repoSk   = Join-Path $repo 'skills'
$apmDir   = Join-Path $env:USERPROFILE '.apm'
$skillDir = Join-Path $env:USERPROFILE '.agents\skills'
$localDst = Join-Path $repoSk 'local'

New-Item -ItemType Directory -Force -Path $repoSk | Out-Null

# 1) Global manifest and lock
foreach ($f in 'apm.yml', 'apm.lock.yaml') {
    $src = Join-Path $apmDir $f
    if (-not (Test-Path $src)) { Write-Warning "見つかりません（スキップ）: $src"; continue }
    $dst = Join-Path $repoSk $f

    if ($Check) {
        if (-not (Test-Path $dst)) { Write-Host "[+] skills/$f（新規）" }
        elseif ((Get-FileHash $src).Hash -ne (Get-FileHash $dst).Hash) { Write-Host "[~] skills/$f（更新あり）" }
        else { Write-Host "[=] skills/$f" }
        continue
    }

    if (-not $Force -and (Test-Path $dst) -and ((Get-FileHash $src).Hash -ne (Get-FileHash $dst).Hash)) {
        Write-Warning "skills/$f がホストと不一致: スキップ（-Force でホスト優先 / tools/pull.ps1 でリポジトリ優先）"
    } else {
        Copy-Item $src $dst -Force
        Write-Host "[ok] skills/$f"
    }
}

# 2) Skill names managed by APM (from the lock's deployed_files)
$managed = @()
$lock = Join-Path $repoSk 'apm.lock.yaml'
if (Test-Path $lock) {
    $managed = Get-Content $lock -Encoding UTF8 |
        ForEach-Object { if ($_ -match '^\s*-\s+\.agents/skills/([^/\s]+)\s*$') { $Matches[1] } } |
        Sort-Object -Unique
}

# 3) Local skills (not APM-managed) -> skills/local/
if (-not (Test-Path $skillDir)) {
    Write-Host "[i] $skillDir がありません（自作スキルなし）"
    return
}

$captured = 0
foreach ($d in (Get-ChildItem $skillDir -Directory -ErrorAction SilentlyContinue)) {
    if ($managed -contains $d.Name) { continue }   # APM-managed ones are out of scope

    $target = Join-Path $localDst $d.Name
    $exists = Test-Path $target

    if ($Check) {
        Write-Host ("[{0}] skills/local/{1}" -f $(if ($exists) { '~' } else { '+' }), $d.Name)
        $captured++
        continue
    }

    if ($exists) { Write-Host "[!] 上書き: skills/local/$($d.Name)（ホスト側の内容で置換）" -ForegroundColor Yellow }
    else         { Write-Host "[+] 新規: skills/local/$($d.Name)" }

    New-Item -ItemType Directory -Force -Path $localDst | Out-Null
    if ($exists) { Remove-Item $target -Recurse -Force }
    Copy-Item $d.FullName $target -Recurse -Force
    $captured++
}

if ($captured -eq 0) { Write-Host "[i] 自作スキルはありません（APM 管理: $($managed.Count) 件）" }

# Do not leave an empty skills/local behind
if ((Test-Path $localDst) -and -not (Get-ChildItem $localDst -Force -ErrorAction SilentlyContinue)) {
    Remove-Item $localDst -Recurse -Force
}
