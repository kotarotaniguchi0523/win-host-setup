# tool-inventory.ps1 — 管理主体ごとに「ツール × 実体バイナリ × backend × 検証」を列挙
$miseDir = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\jdx.mise_Microsoft.Winget.Source_8wekyb3d8bbwe\mise\bin"
$env:Path = "$env:LOCALAPPDATA\mise\shims;$miseDir;" + [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
$mise = Join-Path $miseDir 'mise.exe'
$installs = "$env:LOCALAPPDATA\mise\installs"

"## 1. mise 管理ツール（実体バイナリまで）"
$ls = & $mise ls 2>&1 | Where-Object { $_ -match 'config.toml' }
foreach ($line in $ls) {
  $parts = ($line -replace '\s+', ' ') -split ' '
  $name = $parts[0]
  $ver  = $parts[1]
  $dirName = ($name -replace '[:/]', '-')
  $dir = Get-ChildItem "$installs\$dirName*" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
  $exes = if ($dir) { (Get-ChildItem $dir.FullName -Recurse -Depth 2 -File -Filter *.exe -ErrorAction SilentlyContinue | Select-Object -First 6 -ExpandProperty Name) -join ', ' } else { '(実体なし)' }
  $sec = (& $mise tool $name 2>&1 | Select-String 'Security:' | ForEach-Object { ($_.Line -replace '.*Security:\s*', '').Trim() })
  "{0,-22} {1,-12} | {2,-28} | {3}" -f $name, $ver, $sec, $exes
}

"`n## 2. mise 外のバイナリ置き場（管理主体）"
foreach ($p in @(
  @{n='gopls (go install)'; d="$env:USERPROFILE\go\bin"},
  @{n='Rust (rustup)';      d="$env:USERPROFILE\.cargo\bin"},
  @{n='Docker Sandboxes (winget)'; d="$env:LOCALAPPDATA\DockerSandboxes\bin"},
  @{n='Docker (winget)';    d="C:\Program Files\Docker\Docker\resources\bin"},
  @{n='Git (winget)';       d="C:\Program Files\Git\cmd"},
  @{n='User Programs';      d="$env:LOCALAPPDATA\Programs"},
  @{n='WinGet portable';    d="$env:LOCALAPPDATA\Microsoft\WinGet\Packages"},
  @{n='MSIX aliases';       d="$env:LOCALAPPDATA\Microsoft\WindowsApps"},
  @{n='MAMP';               d="C:\MAMP\bin\php\php7.4.16"}
)) {
  if (Test-Path $p.d) {
    $exes = Get-ChildItem $p.d -Recurse -Depth 1 -File -Filter *.exe -ErrorAction SilentlyContinue | Select-Object -First 12 -ExpandProperty Name
    "{0,-28} {1,-30} {2}" -f $p.n, $p.d, (($exes) -join ', ')
  }
}

"`n## 3. AI ツールの設定ディレクトリ（残存・要判断）"
Get-ChildItem $env:USERPROFILE -Directory -Force -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match '^\.(trae|cursor|claude|gemini|serena|copilot|codex|opencode|jules|aider|windsurf|qwen|mcp)' } |
  ForEach-Object { $s=[math]::Round(((Get-ChildItem $_.FullName -Recurse -File -Force -EA SilentlyContinue|Measure-Object Length -Sum).Sum/1MB),1); "{0,10:N1} MB  {1}" -f $s, $_.FullName }
