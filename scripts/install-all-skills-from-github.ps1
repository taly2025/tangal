param(
    [string]$Repo = "taly2025/tangal",
    [string]$Ref = "master",
    [string]$InstallerRoot = "$env:USERPROFILE\.codex\skills\.system\skill-installer",
    [string]$CodexHome = "$env:USERPROFILE\.codex"
)

$ErrorActionPreference = "Stop"

$installerScript = Join-Path $InstallerRoot "scripts\install-skill-from-github.py"
$skillsRoot = Join-Path $CodexHome "skills"

$skills = @(
    @{ Name = "weekly-report"; Path = ".github/skills/weekly-report" },
    @{ Name = "postgresql-sql"; Path = ".github/skills/postgresql-sql" },
    @{ Name = "github-commit-helper"; Path = ".github/skills/github-commit-helper" }
)

if (-not (Test-Path -LiteralPath $installerScript)) {
    throw "Skill installer was not found: $installerScript"
}

$resolvedSkillsRoot = [System.IO.Path]::GetFullPath($skillsRoot)

foreach ($skill in $skills) {
    $destinationPath = Join-Path $skillsRoot $skill.Name

    if (Test-Path -LiteralPath $destinationPath) {
        $resolvedDestination = [System.IO.Path]::GetFullPath($destinationPath)

        if (-not $resolvedDestination.StartsWith($resolvedSkillsRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to remove an unexpected destination: $resolvedDestination"
        }

        Remove-Item -LiteralPath $destinationPath -Recurse -Force
    }

    Write-Host "Installing $($skill.Name) from GitHub..."
    python $installerScript --repo $Repo --ref $Ref --path $skill.Path --method download

    if ($LASTEXITCODE -ne 0) {
        throw "Remote skill installation failed for $($skill.Name)."
    }

    Write-Host "$($skill.Name) installed successfully."
}

Write-Host "All skills installed successfully."
Write-Host "Restart Codex to pick up the installed skills."
