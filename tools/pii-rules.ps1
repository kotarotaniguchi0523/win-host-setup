# pii-rules.ps1 - Replacement rules for personal information -> placeholders (shared by sanitize.ps1 / depii.ps1)
# Do **not write real values (PII)** here. Put specific account names / project names in .agent/pii-rules.local.ps1
# (already in .gitignore, local only), which Get-PiiRules loads and merges in.

function Get-PiiRules {
    param(
        [string]$Repo,
        # CI has no .agent/pii-rules.local.ps1, and the account / host name of the machine that runs the
        # check must not become a pattern: a CI runner reports a generic name (USERNAME=runner) that
        # matches ordinary words in the documents and fails the check on false positives.
        [switch]$SkipEnvRules
    )

    $user  = $env:USERNAME
    $host_ = $env:COMPUTERNAME
    $rules = [ordered]@{}

    # Generic account / host names (CI runners, containers) are not personal information.
    $genericNames = @('runner', 'user', 'admin', 'root', 'vscode', 'build', 'ci', 'ubuntu', 'guest', 'test')
    $useUser = (-not $SkipEnvRules) -and $user  -and ($genericNames -notcontains $user.ToLower())
    $useHost = (-not $SkipEnvRules) -and $host_ -and ($genericNames -notcontains $host_.ToLower())

    # 1) Home directory (collapses spelling variants first)
    if ($useUser) {
        $rules["C:\Users\$user"] = '%USERPROFILE%'
        $rules["c:\Users\$user"] = '%USERPROFILE%'
        $rules["C:/Users/$user"] = '%USERPROFILE%'
        $rules["\\Users\\$user"] = '\\Users\\%USERNAME%'
    }
    # 2) User name (standalone occurrences)
    if ($useUser) { $rules[$user] = '%USERNAME%' }
    # 3) Host name
    if ($useHost) { $rules[$host_] = '%COMPUTERNAME%' }
    # 4) Git email address (dynamic; do not write real values)
    $email = if ($SkipEnvRules) { $null } else { (git config --global user.email 2>$null) }
    if ($email) { $rules[$email.Trim()] = '%EMAIL%' }
    # 5) Repository location
    $rules['Desktop\win-host-setup'] = 'win-host-setup'

    # 6) Explicit local-only list (real values; not committed)
    if ($Repo) {
        $local = Join-Path $Repo '.agent\pii-rules.local.ps1'
        if (Test-Path $local) {
            . $local
            if ($LocalPiiRules) { foreach ($k in $LocalPiiRules.Keys) { $rules[$k] = $LocalPiiRules[$k] } }
        }
    }

    return $rules
}

# Tracked files that are safe to publish (i.e. managed with PII removed)
function Get-PiiTargets {
    param([string]$Repo)
    return @(
        'README.md', 'ARCHITECTURE.md', 'AGENTS.md', 'PLAN.md', 'AUDIT.md', 'winget-vs-mise.md',
        # Analysis documents (inventory/repos/migration etc.) are not published (moved to .agent/)
        'renovate.json', '.secretlintrc.json', '.gitattributes', 'hk.pkl',
        'mise.toml', 'mise.lock',
        'winget/host.dsc.yaml',
        'mise/mise.toml', 'mise/mise.lock',
        'skills/apm.yml', 'skills/apm.lock.yaml', 'skills/local',
        'env/variables.md',
        'shell',
        '.github',
        '.opencode',
        'tools'
    )
}
