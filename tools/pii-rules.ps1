# pii-rules.ps1 — 個人情報 → プレースホルダの置換ルール（sanitize.ps1 / depii.ps1 で共有）
# ここには **実値（PII）を書かない**。固有のアカウント名・案件名は .agent/pii-rules.local.ps1
#（.gitignore 済み・ローカルのみ）に置き、Get-PiiRules が読み込んで合成する。

function Get-PiiRules {
    param([string]$Repo)

    $user  = $env:USERNAME
    $host_ = $env:COMPUTERNAME
    $rules = [ordered]@{}

    # 1) ホームディレクトリ（表記ゆれを先に潰す）
    $rules["C:\Users\$user"] = '%USERPROFILE%'
    $rules["c:\Users\$user"] = '%USERPROFILE%'
    $rules["C:/Users/$user"] = '%USERPROFILE%'
    $rules["\\Users\\$user"] = '\\Users\\%USERNAME%'
    # 2) ユーザー名（単独出現）
    if ($user) { $rules[$user] = '%USERNAME%' }
    # 3) ホスト名
    if ($host_) { $rules[$host_] = '%COMPUTERNAME%' }
    # 4) Git のメールアドレス（動的・実値を書かない）
    $email = (git config --global user.email 2>$null)
    if ($email) { $rules[$email.Trim()] = '%EMAIL%' }
    # 5) リポジトリの置き場所
    $rules['win-host-setup'] = 'win-host-setup'

    # 6) ローカル専用の明示リスト（実値。コミットされない）
    if ($Repo) {
        $local = Join-Path $Repo '.agent\pii-rules.local.ps1'
        if (Test-Path $local) {
            . $local
            if ($LocalPiiRules) { foreach ($k in $LocalPiiRules.Keys) { $rules[$k] = $LocalPiiRules[$k] } }
        }
    }

    return $rules
}

# 公開してよい（＝PII を除去して管理する）トラック済みファイル
function Get-PiiTargets {
    param([string]$Repo)
    return @(
        'README.md', 'AGENTS.md', 'PLAN.md', 'AUDIT.md', 'winget-vs-mise.md',
        'repos.md', 'repos-analysis.md', 'binaries-scan.md',
        'inventory.md', 'TODO-inventory.md', 'migration-npm.md', 'migration-pip.md',
        'renovate.json', '.gitattributes',
        'winget/host.dsc.yaml',
        'mise/mise.toml', 'mise/mise.lock',
        'skills/apm.yml', 'skills/apm.lock.yaml', 'skills/local',
        'env/variables.md',
        '.github/workflows/*.yml',
        'tools/*.ps1'
    )
}
