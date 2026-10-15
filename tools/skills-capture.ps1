# skills-capture.ps1 — 実環境の Skills をリポジトリへ書き出す（ローカル更新 → Push 用）
# 使い方: pwsh -File tools/skills-capture.ps1
#  - ~/.apm/apm.yml / apm.lock.yaml           → skills/
#  - ~/.agents/skills/* のうち APM 管理外   → skills/local/*（自作 Skill）
#
# ★ 向きに注意: 自作 Skill は **ホスト側が正**。このスクリプトは skills/local/<name> を
#   ホストの内容で上書きする。リポジトリで直接編集した場合は、先に tools/skills-apply.ps1 で
#   ホストへ反映してから実行すること（順序を誤るとリポジトリ側の編集が失われる）。

[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$repo    = Split-Path $PSScriptRoot -Parent
$repoSk  = Join-Path $repo 'skills'
$apmDir  = Join-Path $env:USERPROFILE '.apm'
$skillDir= Join-Path $env:USERPROFILE '.agents\skills'

New-Item -ItemType Directory -Force -Path $repoSk | Out-Null

# 1) グローバル・マニフェストとロック
foreach ($f in 'apm.yml', 'apm.lock.yaml') {
    $src = Join-Path $apmDir $f
    if (Test-Path $src) { Copy-Item $src (Join-Path $repoSk $f) -Force; Write-Host "[ok] skills/$f" }
    else { Write-Warning "見つかりません: $src" }
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
$localDst = Join-Path $repoSk 'local'
if (Test-Path $skillDir) {
    $found = 0
    foreach ($d in (Get-ChildItem $skillDir -Directory -ErrorAction SilentlyContinue)) {
        if ($managed -contains $d.Name) { continue }
        $t = Join-Path $localDst $d.Name
        if (Test-Path $t) { Remove-Item $t -Recurse -Force }
        New-Item -ItemType Directory -Force -Path $localDst | Out-Null
        Copy-Item $d.FullName $t -Recurse -Force
        Write-Host "[ok] skills/local/$($d.Name)（自作）"
        $found++
    }
    if ($found -eq 0) { Write-Host "[i] 自作スキルはありません（APM 管理: $($managed.Count) 件）" }
}

# 4) 空ディレクトリを掃除
if ((Test-Path $localDst) -and -not (Get-ChildItem $localDst -Force -ErrorAction SilentlyContinue)) {
    Remove-Item $localDst -Recurse -Force
}
