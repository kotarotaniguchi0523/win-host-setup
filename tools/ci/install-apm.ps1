# install-apm.ps1 — APM CLI（winget Microsoft.APM）を導入し、実行パスを GITHUB_ENV に出す
# 使い方: pwsh -File tools/ci/install-apm.ps1
# 前提: Windows（winget が使えること）
# 出力: APM_DIR=<apm.exe のあるディレクトリ>

[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\common.ps1')

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw "winget が見つかりません（Windows ランナーで実行してください）" }

# 既に入っていれば入れ直さない
if (-not (Get-Command apm -ErrorAction SilentlyContinue)) {
    try {
        Invoke-Native 'winget' @(
            'install', '--id', 'Microsoft.APM', '--exact', '--silent',
            '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity'
        ) -What 'winget install Microsoft.APM'
    } catch {
        Write-Warning "winget install が失敗しました（既存の導入を試します）: $($_.Exception.Message)"
    }
}

$apm = Resolve-Apm
Write-Host "[ok] apm: $apm"
Invoke-Native $apm @('--version') -What 'apm --version'

if ($env:GITHUB_ENV) {
    "APM_DIR=" + (Split-Path $apm -Parent) | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding utf8
}
