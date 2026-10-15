# common.ps1 — 共有ユーティリティ（各スクリプトから dot-source して使う）
# 方針: ネイティブコマンドは必ず終了コードを検査し、失敗は例外にして呼び出し側で扱う。

# ネイティブコマンドを実行し、非ゼロ終了なら例外にする
function Invoke-Native {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$Arguments = @(),
        [string]$What
    )
    $label = if ($What) { $What } else { "$FilePath $($Arguments -join ' ')" }
    Write-Verbose "run: $label"
    $exe = Get-Command $FilePath -ErrorAction SilentlyContinue
    if (-not $exe) { throw "コマンドが見つかりません: $FilePath" }
    & $FilePath @Arguments
    $code = $LASTEXITCODE
    # .ps1 や関数を呼んだ場合は $LASTEXITCODE が更新されない（$null）ので、その時は成功扱い
    if ($null -ne $code -and $code -ne 0) { throw "$label が失敗しました（exit $code）" }
}

# 終了コードだけを見たい場合（失敗を許容する）
function Test-Native {
    param([Parameter(Mandatory)][string]$FilePath, [string[]]$Arguments = @())
    & $FilePath @Arguments *> $null
    return ($LASTEXITCODE -eq 0)
}

# apm CLI を解決（PATH → winget のパッケージ先）
function Resolve-Apm {
    $apm = (Get-Command apm -ErrorAction SilentlyContinue).Source
    if (-not $apm) {
        $apm = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Microsoft.APM_*" -Recurse -Filter 'apm.exe' -ErrorAction SilentlyContinue |
               Select-Object -First 1 -ExpandProperty FullName
    }
    if (-not $apm) { throw "apm CLI が見つかりません（winget: Microsoft.APM）" }
    return $apm
}

# リポジトリのルート（tools/lib/ から 2 つ上）
function Get-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}

# ホームディレクトリ（Windows / Linux 両対応）
function Get-HomeDir {
    if ($env:USERPROFILE) { return $env:USERPROFILE }
    if ($env:HOME)        { return $env:HOME }
    throw 'ホームディレクトリを特定できません（USERPROFILE / HOME が未設定）'
}

# 環境変数が未設定なら例外（必須の前提を明示する）
function Assert-Env {
    param([Parameter(Mandatory)][string[]]$Names)
    foreach ($n in $Names) {
        if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($n))) {
            throw "環境変数 $n が設定されていません"
        }
    }
}

# GitHub Actions のサマリ（ローカル実行では無視される）
function Add-Summary {
    param([Parameter(Mandatory)][string]$Text)
    if ($env:GITHUB_STEP_SUMMARY) { Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value $Text -Encoding UTF8 }
    else { Write-Host $Text }
}
