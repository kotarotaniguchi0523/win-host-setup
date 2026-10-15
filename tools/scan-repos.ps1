# scan-repos.ps1 - List the Git repositories under the user profile
$ErrorActionPreference = 'SilentlyContinue'
$root = $env:USERPROFILE
$DST = Split-Path $PSScriptRoot -Parent
$OUT = Join-Path $DST 'repos.md'

$skip = @('AppData','node_modules','.git','.cargo','.rustup','.cache','.local','.npm','.pnpm-store',
          '.m2','.gradle','.nuget','.vscode','.cursor','.config','.docker','venv','.venv','.idea',
          'Application Data','Local Settings','Cookies','NetHood','PrintHood','Recent','SendTo','Templates',
          'IntelGraphicsProfiles','MicrosoftEdgeBackups','OneDrive')

$found = New-Object System.Collections.Generic.List[string]
function Walk($dir, $depth) {
  if ($depth -gt 5) { return }
  $name = Split-Path $dir -Leaf
  if ($skip -contains $name) { return }
  if (Test-Path (Join-Path $dir '.git')) { $found.Add($dir) }
  Get-ChildItem $dir -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object { Walk $_.FullName ($depth + 1) }
}
Walk $root 0

$rows = New-Object System.Collections.Generic.List[string]
$rows.Add("# Git リポジトリ一覧（ユーザー配下をスキャン）")
$rows.Add("")
$rows.Add("root: ``$root`` / 除外: AppData,node_modules,.cargo,.rustup,... / 深さ5")
$rows.Add("")
$rows.Add("| # | Path | Remote | Branch | Last commit | 未コミット | サイズ |")
$rows.Add("|---|---|---|---|---|---|---|")

$i = 0
foreach ($r in ($found | Sort-Object)) {
  $i++
  $remote = (git -C $r remote get-url origin 2>$null)
  if (-not $remote) { $remote = '(no remote)' }
  $branch = (git -C $r rev-parse --abbrev-ref HEAD 2>$null)
  $last = (git -C $r log -1 --format='%ad' --date=short 2>$null)
  $dirty = (git -C $r status --porcelain 2>$null | Measure-Object).Count
  $size = (Get-ChildItem $r -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
  $rows.Add(("| {0} | ``{1}`` | {2} | {3} | {4} | {5} | {6:N1} MB |" -f $i, $r.Replace($root,'~'), $remote, $branch, $last, $dirty, ($size/1MB)))
}
$rows.Add("")
$rows.Add("total: $($found.Count)")
$rows | Set-Content -Encoding utf8 $OUT
"repos: $($found.Count)"
"written: $OUT"
