# common.ps1 - Shared utilities (dot-source from each script)
# Policy: native commands must always have their exit code checked; failures are raised as exceptions and handled by the caller.

# Run a native command and raise an exception on a non-zero exit
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
    # When calling a .ps1 or a function, $LASTEXITCODE is not updated ($null), so treat that as success
    if ($null -ne $code -and $code -ne 0) { throw "$label が失敗しました（exit $code）" }
}

# Use when you only want the exit code (failures are tolerated)
function Test-Native {
    param([Parameter(Mandatory)][string]$FilePath, [string[]]$Arguments = @())
    & $FilePath @Arguments *> $null
    return ($LASTEXITCODE -eq 0)
}

# Resolve the apm CLI (PATH, then the winget package location)
function Resolve-Apm {
    $apm = (Get-Command apm -ErrorAction SilentlyContinue).Source
    if (-not $apm) {
        $apm = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Microsoft.APM_*" -Recurse -Filter 'apm.exe' -ErrorAction SilentlyContinue |
               Select-Object -First 1 -ExpandProperty FullName
    }
    if (-not $apm) { throw "apm CLI が見つかりません（winget: Microsoft.APM）" }
    return $apm
}

# Repository root (two levels up from tools/lib/)
function Get-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}

# Home directory (works on Windows and Linux)
function Get-HomeDir {
    if ($env:USERPROFILE) { return $env:USERPROFILE }
    if ($env:HOME)        { return $env:HOME }
    throw 'ホームディレクトリを特定できません（USERPROFILE / HOME が未設定）'
}

# Raise if an environment variable is unset (makes required prerequisites explicit)
function Assert-Env {
    param([Parameter(Mandatory)][string[]]$Names)
    foreach ($n in $Names) {
        if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($n))) {
            throw "環境変数 $n が設定されていません"
        }
    }
}

# GitHub Actions summary (ignored on local runs)
function Add-Summary {
    param([Parameter(Mandatory)][string]$Text)
    if ($env:GITHUB_STEP_SUMMARY) { Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value $Text -Encoding UTF8 }
    else { Write-Host $Text }
}
