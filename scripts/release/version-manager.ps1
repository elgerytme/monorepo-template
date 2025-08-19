# Automated semantic versioning system for Windows
# Follows semantic versioning (semver) principles

param(
    [Parameter(Position=0)]
    [ValidateSet("bump", "current", "analyze", "help")]
    [string]$Command = "help",
    
    [Parameter(Position=1)]
    [ValidateSet("major", "minor", "patch", "auto")]
    [string]$IncrementType = "auto"
)

$ErrorActionPreference = "Stop"

# Get script and repository paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

# Configuration
$VersionFile = Join-Path $RepoRoot "VERSION"
$ChangelogFile = Join-Path $RepoRoot "CHANGELOG.md"
$ReleaseNotesDir = Join-Path $RepoRoot "releases"

# Logging functions
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Get current version from VERSION file or git tags
function Get-CurrentVersion {
    if (Test-Path $VersionFile) {
        return Get-Content $VersionFile -Raw | ForEach-Object { $_.Trim() }
    } else {
        # Fallback to git tags
        try {
            $tag = git describe --tags --abbrev=0 2>$null
            if ($tag) {
                return $tag -replace '^v', ''
            }
        } catch {
            # Ignore git errors
        }
        return "0.0.0"
    }
}

# Parse version into components
function Parse-Version {
    param([string]$Version)
    
    if ($Version -match '^(\d+)\.(\d+)\.(\d+)') {
        return @{
            Major = [int]$Matches[1]
            Minor = [int]$Matches[2]
            Patch = [int]$Matches[3]
        }
    } else {
        throw "Invalid version format: $Version"
    }
}

# Increment version based on type
function Increment-Version {
    param(
        [string]$CurrentVersion,
        [string]$IncrementType
    )
    
    $versionParts = Parse-Version $CurrentVersion
    
    switch ($IncrementType) {
        "major" {
            $versionParts.Major++
            $versionParts.Minor = 0
            $versionParts.Patch = 0
        }
        "minor" {
            $versionParts.Minor++
            $versionParts.Patch = 0
        }
        "patch" {
            $versionParts.Patch++
        }
        default {
            throw "Invalid increment type: $IncrementType. Use major, minor, or patch."
        }
    }
    
    return "$($versionParts.Major).$($versionParts.Minor).$($versionParts.Patch)"
}

# Analyze commits to determine version increment type
function Analyze-Commits {
    try {
        $lastTag = git describe --tags --abbrev=0 2>$null
    } catch {
        $lastTag = $null
    }
    
    $commitRange = if ($lastTag) { "$lastTag..HEAD" } else { "HEAD" }
    
    try {
        $commits = git log --oneline --no-merges $commitRange 2>$null
    } catch {
        return "none"
    }
    
    if (-not $commits) {
        return "none"
    }
    
    # Check for breaking changes (major version)
    if ($commits -match "(BREAKING CHANGE|!:)") {
        return "major"
    }
    
    # Check for new features (minor version)
    if ($commits -match "^[a-f0-9]+ (feat|feature)") {
        return "minor"
    }
    
    # Default to patch for bug fixes and other changes
    return "patch"
}

# Create or update VERSION file
function Update-VersionFile {
    param([string]$NewVersion)
    
    Set-Content -Path $VersionFile -Value $NewVersion -NoNewline
    Write-Success "Updated VERSION file to $NewVersion"
}

# Create git tag for version
function New-GitTag {
    param([string]$Version)
    
    $tagName = "v$Version"
    git tag -a $tagName -m "Release $tagName"
    Write-Success "Created git tag: $tagName"
}

# Main version bump function
function Invoke-VersionBump {
    param([string]$IncrementType = "auto")
    
    $currentVersion = Get-CurrentVersion
    Write-Info "Current version: $currentVersion"
    
    if ($IncrementType -eq "auto") {
        $IncrementType = Analyze-Commits
        if ($IncrementType -eq "none") {
            Write-Info "No changes detected, skipping version bump"
            return
        }
        Write-Info "Auto-detected increment type: $IncrementType"
    }
    
    $newVersion = Increment-Version $currentVersion $IncrementType
    Write-Info "New version: $newVersion"
    
    # Update version file
    Update-VersionFile $newVersion
    
    # Create git tag
    New-GitTag $newVersion
    
    return $newVersion
}

# Show usage information
function Show-Usage {
    @"
Usage: .\version-manager.ps1 [COMMAND] [OPTIONS]

Commands:
    bump [major|minor|patch|auto]  Bump version (default: auto)
    current                        Show current version
    analyze                        Analyze commits for version increment
    help                          Show this help message

Examples:
    .\version-manager.ps1 bump                    # Auto-detect version increment
    .\version-manager.ps1 bump minor              # Bump minor version
    .\version-manager.ps1 current                 # Show current version
    .\version-manager.ps1 analyze                 # Show suggested version increment

"@
}

# Main script logic
switch ($Command) {
    "bump" {
        Invoke-VersionBump $IncrementType
    }
    "current" {
        Get-CurrentVersion
    }
    "analyze" {
        Analyze-Commits
    }
    "help" {
        Show-Usage
    }
    default {
        Write-Error "Unknown command: $Command"
        Show-Usage
        exit 1
    }
}