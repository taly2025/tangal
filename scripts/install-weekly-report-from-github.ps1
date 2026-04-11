param(
    [string]$Repo = "taly2025/tangal",
    [string]$Ref = "master",
    [string]$SkillPath = "skills/weekly-report",
    [string]$InstallerRoot = "$env:USERPROFILE\.codex\skills\.system\skill-installer",
    [string]$CodexHome = "$env:USERPROFILE\.codex"
)

$ErrorActionPreference = "Stop"

$installerScript = Join-Path $InstallerRoot "scripts\install-skill-from-github.py"
$destinationPath = Join-Path (Join-Path $CodexHome "skills") "weekly-report"

if (-not (Test-Path -LiteralPath $installerScript)) {
    throw "Skill installer was not found: $installerScript"
}

if (Test-Path -LiteralPath $destinationPath) {
    $skillsRoot = [System.IO.Path]::GetFullPath((Join-Path $CodexHome "skills"))
    $resolvedDestination = [System.IO.Path]::GetFullPath($destinationPath)

    if (-not $resolvedDestination.StartsWith($skillsRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove an unexpected destination: $resolvedDestination"
    }

    Remove-Item -LiteralPath $destinationPath -Recurse -Force
}

Write-Host "Installing weekly-report from GitHub..."
python $installerScript --repo $Repo --ref $Ref --path $SkillPath --method download

if ($LASTEXITCODE -ne 0) {
    throw "Remote skill installation failed."
}

Write-Host "weekly-report installed successfully."
Write-Host "Restart Codex to pick up the installed skill."
