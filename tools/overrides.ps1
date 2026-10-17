# overrides.ps1 - make managed tools win over the Windows equivalents (**run as administrator**)
# Usage: in an administrator PowerShell:  pwsh -File tools/overrides.ps1 [-Apply]
#   Without -Apply this is a preview only.
#
# Why a Machine-scope directory:
#   The effective PATH is "Machine PATH; User PATH", so a per-user shim
#   (mise shims, winget Links) can never shadow C:\Windows\System32.
#   Commands that must win therefore live in an all-users directory placed at the
#   FRONT of the Machine PATH. The files are copies refreshed from the winget
#   package, so the directory name - and the PATH entry - never changes when the
#   package is updated. Re-run this script after tools/update-winget-dsc.ps1.
#
# Managed overrides (source: winget/host.dsc.yaml):
#   curl <- cURL.cURL   (Windows ships an older curl.exe in System32)

[CmdletBinding()]
param(
    [switch]$Apply,
    [string]$OverrideDir = 'C:\ProgramData\win-host-setup\bin'
)
$ErrorActionPreference = 'Stop'
$repo      = Split-Path $PSScriptRoot -Parent
$backupDir = Join-Path $repo '.agent'   # host-specific data stays out of git

$overrides = @(
    [pscustomobject]@{
        id      = 'cURL.cURL'
        pattern = 'curl-*win64*'
        files   = @('curl.exe', 'libcurl-x64.dll', 'curl-ca-bundle.crt')
    }
)

function Find-Bin([string]$id, [string]$pattern) {
    $roots = @(
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'),
        (Join-Path $env:ProgramFiles 'WinGet\Packages')
    )
    foreach ($root in $roots) {
        if (-not (Test-Path $root)) { continue }
        foreach ($pkg in Get-ChildItem $root -Directory -Filter "$($id)_*" -ErrorAction SilentlyContinue) {
            $inner = Get-ChildItem $pkg.FullName -Directory -Filter $pattern -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($inner) {
                $bin = Join-Path $inner.FullName 'bin'
                if (Test-Path $bin) { return $bin }
            }
        }
    }
    return $null
}

$copy = @()
$missing = @()
foreach ($o in $overrides) {
    $bin = Find-Bin $o.id $o.pattern
    if (-not $bin) {
        $missing += "$($o.id): 未導入です（先に winget configure winget/host.dsc.yaml）"
        continue
    }
    foreach ($f in $o.files) {
        $src = Join-Path $bin $f
        if (Test-Path $src) {
            $copy += [pscustomobject]@{ src = $src; dst = Join-Path $OverrideDir $f; from = $o.id }
        }
    }
}

Write-Host "=== 配置 ($($copy.Count) ファイル) ===" -ForegroundColor Yellow
$copy | ForEach-Object { Write-Host ("  {0,-22} -> {1}" -f (Split-Path $_.src -Leaf), $_.dst) }
$missing | ForEach-Object { Write-Host "  ! $_" -ForegroundColor Red }

function Norm([string]$p) { ($p -replace '\\+$', '').Trim().ToLower() }

$machine = @([Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';' | Where-Object { $_ })
$target  = Norm $OverrideDir
$rest    = @($machine | Where-Object { (Norm $_) -ne $target })
$after   = @($OverrideDir) + $rest
$pathChanged = ($machine.Count -eq 0) -or ((Norm $machine[0]) -ne $target)

Write-Host "`n=== Machine PATH ===" -ForegroundColor Yellow
Write-Host "  現在の先頭: $($machine | Select-Object -First 1)"
if ($pathChanged) {
    Write-Host "  変更後    : $OverrideDir  を先頭へ（$($machine.Count) -> $($after.Count) 件）"
} else {
    Write-Host "  変更不要（すでに先頭です）" -ForegroundColor Green
}

if (-not $Apply) {
    Write-Host "`nプレビューのみ。-Apply を付けると適用します。" -ForegroundColor Cyan
    return
}
$elev = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $elev) { throw "管理者権限が必要です。管理者の PowerShell で再実行してください。" }

if ($copy.Count -gt 0) {
    New-Item -ItemType Directory -Force -Path $OverrideDir | Out-Null
    foreach ($c in $copy) {
        Copy-Item $c.src $c.dst -Force
        Write-Host "[ok] $(Split-Path $c.dst -Leaf) <- $($c.from)"
    }
}

if ($pathChanged) {
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
    $bak = Join-Path $backupDir ("machine-path-backup-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".txt")
    $machine -join "`n" | Set-Content $bak -Encoding UTF8
    Write-Host "[bak] $bak"
    [Environment]::SetEnvironmentVariable('Path', ($after -join ';'), 'Machine')
    Write-Host "[ok] Machine PATH を更新（$OverrideDir を先頭に追加）" -ForegroundColor Green
}

$curl = Join-Path $OverrideDir 'curl.exe'
if (Test-Path $curl) {
    Write-Host "`n=== 検証 ===" -ForegroundColor Yellow
    Write-Host "  $(& $curl --version | Select-Object -First 1)"
    Write-Host "  新しいシェルで  where.exe curl.exe  →  $OverrideDir\curl.exe"
}
Write-Host "`n新しいシェル（またはサインアウト/イン）から反映されます。"
