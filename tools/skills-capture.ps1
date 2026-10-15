# skills-capture.ps1 — 実環境の Skills をリポジトリへ書き出す（ローカル更新 → Push 用）
# 使い方: pwsh -File tools/skills-capture.ps1 [-Check]
#   -Check : 書き換えず、差分・上書き予定だけを表示
#  - ~/.apm/apm.yml / apm.lock.yaml         → skills/
#  - ~/.agents/skills/* のうち APM 管理外 → skills/local/*（自作 Skill）
#
# ★ 向き: 自作 Skill は **ホスト（~/.agents/skills）が正**。既存の skills/local/<name> は
#   ホストの内容で置き換わる（その場合は必ずログに出す）。リポジトリ側を直接編集した場合は、
#   先に tools/skills-apply.ps1 を実行してホストへ反映してから本スクリプトを実行すること。

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

# 1) グローバル・マニフェストとロック
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

# 2) APM が管理しているスキル名（ロックの deployed_files から）
$managed = @()
$lock = Join-Path $repoSk 'apm.lock.yaml'
if (Test-Path $lock) {
    $managed = Get-Content $lock -Encoding UTF8 |
        ForEach-Object { if ($_ -match '^\s*-\s+\.agents/skills/([^/\s]+)\s*$') { $Matches[1] } } |
        Sort-Object -Unique
}

# 3) 自作スキル（APM 管理外）→ skills/local/
if (-not (Test-Path $skillDir)) {
    Write-Host "[i] $skillDir がありません（自作スキルなし）"
    return
}

$captured = 0
foreach ($d in (Get-ChildItem $skillDir -Directory -ErrorAction SilentlyContinue)) {
    if ($managed -contains $d.Name) { continue }   # APM 管理下は対象外

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

# 空の skills/local は残さない
if ((Test-Path $localDst) -and -not (Get-ChildItem $localDst -Force -ErrorAction SilentlyContinue)) {
    Remove-Item $localDst -Recurse -Force
}
