# Automated release notes generation system for Windows
# Generates comprehensive release notes from git commits and pull requests

param(
    [Parameter(Position=0)]
    [ValidateSet("generate", "help")]
    [string]$Command = "help",
    
    [Parameter(Position=1)]
    [string]$Version
)

$ErrorActionPreference = "Stop"

# Get script and repository paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

# Configuration
$ReleaseNotesDir = Join-Path $RepoRoot "releases"
$ChangelogFile = Join-Path $RepoRoot "CHANGELOG.md"

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

# Ensure release notes directory exists
function Ensure-ReleaseDir {
    if (-not (Test-Path $ReleaseNotesDir)) {
        New-Item -ItemType Directory -Path $ReleaseNotesDir -Force | Out-Null
    }
}

# Get commits between two references
function Get-Commits {
    param(
        [string]$FromRef,
        [string]$ToRef = "HEAD"
    )
    
    try {
        if ([string]::IsNullOrEmpty($FromRef)) {
            # If no previous tag, get all commits
            return git log --oneline --no-merges $ToRef 2>$null
        } else {
            return git log --oneline --no-merges "$FromRef..$ToRef" 2>$null
        }
    } catch {
        return @()
    }
}

# Categorize commits by type
function Categorize-Commits {
    param([string[]]$Commits)
    
    $categories = @{
        breaking = @()
        features = @()
        fixes = @()
        docs = @()
        style = @()
        refactor = @()
        perf = @()
        test = @()
        chore = @()
        other = @()
    }
    
    foreach ($commit in $Commits) {
        if ([string]::IsNullOrEmpty($commit)) {
            continue
        }
        
        $parts = $commit -split ' ', 2
        $hash = $parts[0]
        $message = if ($parts.Length -gt 1) { $parts[1] } else { "" }
        
        $commitLine = "- $message ($hash)"
        
        # Check for breaking changes
        if ($message -match "(BREAKING CHANGE|!:)") {
            $categories.breaking += $commitLine
        }
        # Check commit type prefixes
        elseif ($message -match "^feat(\(.+\))?:") {
            $categories.features += $commitLine
        }
        elseif ($message -match "^fix(\(.+\))?:") {
            $categories.fixes += $commitLine
        }
        elseif ($message -match "^docs(\(.+\))?:") {
            $categories.docs += $commitLine
        }
        elseif ($message -match "^style(\(.+\))?:") {
            $categories.style += $commitLine
        }
        elseif ($message -match "^refactor(\(.+\))?:") {
            $categories.refactor += $commitLine
        }
        elseif ($message -match "^perf(\(.+\))?:") {
            $categories.perf += $commitLine
        }
        elseif ($message -match "^test(\(.+\))?:") {
            $categories.test += $commitLine
        }
        elseif ($message -match "^chore(\(.+\))?:") {
            $categories.chore += $commitLine
        }
        else {
            $categories.other += $commitLine
        }
    }
    
    return $categories
}

# Generate release notes content
function Generate-ReleaseNotes {
    param(
        [string]$Version,
        [string]$PreviousTag
    )
    
    Write-Info "Generating release notes for version $Version"
    
    # Get commits since last release
    $commits = Get-Commits -FromRef $PreviousTag
    
    if (-not $commits -or $commits.Count -eq 0) {
        Write-Warning "No commits found for release $Version"
        return ""
    }
    
    # Categorize commits
    $categorized = Categorize-Commits -Commits $commits
    
    # Start building release notes
    $releaseDate = Get-Date -Format "yyyy-MM-dd"
    $releaseNotes = @()
    
    $releaseNotes += "# Release $Version"
    $releaseNotes += ""
    $releaseNotes += "**Release Date:** $releaseDate"
    $releaseNotes += ""
    
    # Add summary
    $commitCount = $commits.Count
    $releaseNotes += "## Summary"
    $releaseNotes += ""
    $releaseNotes += "This release includes $commitCount commits with the following changes:"
    $releaseNotes += ""
    
    # Add breaking changes first (if any)
    if ($categorized.breaking.Count -gt 0) {
        $releaseNotes += "## ⚠️ Breaking Changes"
        $releaseNotes += ""
        $releaseNotes += $categorized.breaking
        $releaseNotes += ""
    }
    
    # Add features
    if ($categorized.features.Count -gt 0) {
        $releaseNotes += "## ✨ New Features"
        $releaseNotes += ""
        $releaseNotes += $categorized.features
        $releaseNotes += ""
    }
    
    # Add bug fixes
    if ($categorized.fixes.Count -gt 0) {
        $releaseNotes += "## 🐛 Bug Fixes"
        $releaseNotes += ""
        $releaseNotes += $categorized.fixes
        $releaseNotes += ""
    }
    
    # Add performance improvements
    if ($categorized.perf.Count -gt 0) {
        $releaseNotes += "## ⚡ Performance Improvements"
        $releaseNotes += ""
        $releaseNotes += $categorized.perf
        $releaseNotes += ""
    }
    
    # Add documentation updates
    if ($categorized.docs.Count -gt 0) {
        $releaseNotes += "## 📚 Documentation"
        $releaseNotes += ""
        $releaseNotes += $categorized.docs
        $releaseNotes += ""
    }
    
    # Add other changes
    if ($categorized.other.Count -gt 0) {
        $releaseNotes += "## 🔧 Other Changes"
        $releaseNotes += ""
        $releaseNotes += $categorized.other
        $releaseNotes += ""
    }
    
    # Add contributors section
    try {
        $contributors = git log --format='%an' "$PreviousTag..HEAD" 2>$null | Sort-Object -Unique
        if ($contributors) {
            $contributorList = $contributors -join ', '
            $releaseNotes += "## 👥 Contributors"
            $releaseNotes += ""
            $releaseNotes += "Thanks to the following contributors: $contributorList"
            $releaseNotes += ""
        }
    } catch {
        # Ignore git errors
    }
    
    # Add installation/upgrade instructions
    $releaseNotes += "## 📦 Installation"
    $releaseNotes += ""
    $releaseNotes += "To install or upgrade to this version:"
    $releaseNotes += ""
    $releaseNotes += "``````bash"
    $releaseNotes += "# Clone or update the repository"
    $releaseNotes += "git checkout v$Version"
    $releaseNotes += "``````"
    $releaseNotes += ""
    
    return $releaseNotes -join "`n"
}

# Save release notes to file
function Save-ReleaseNotes {
    param(
        [string]$Version,
        [string]$Content
    )
    
    Ensure-ReleaseDir
    
    $releaseFile = Join-Path $ReleaseNotesDir "v$Version.md"
    Set-Content -Path $releaseFile -Value $Content -Encoding UTF8
    
    Write-Success "Release notes saved to: $releaseFile"
}

# Update changelog
function Update-Changelog {
    param(
        [string]$Version,
        [string]$Content
    )
    
    $existingContent = ""
    if (Test-Path $ChangelogFile) {
        $existingContent = Get-Content $ChangelogFile -Raw
    }
    
    $newContent = $Content + "`n`n" + $existingContent
    Set-Content -Path $ChangelogFile -Value $newContent -Encoding UTF8
    
    Write-Success "Updated CHANGELOG.md"
}

# Get previous release tag
function Get-PreviousTag {
    try {
        return git describe --tags --abbrev=0 HEAD^ 2>$null
    } catch {
        return ""
    }
}

# Main release notes generation function
function Invoke-GenerateRelease {
    param([string]$Version)
    
    # Get previous tag for comparison
    $previousTag = Get-PreviousTag
    
    if ($previousTag) {
        Write-Info "Generating release notes from $previousTag to v$Version"
    } else {
        Write-Info "Generating release notes for initial release v$Version"
    }
    
    # Generate release notes content
    $releaseNotes = Generate-ReleaseNotes -Version $Version -PreviousTag $previousTag
    
    if ([string]::IsNullOrEmpty($releaseNotes)) {
        Write-Warning "No release notes generated"
        return
    }
    
    # Save to release notes file
    Save-ReleaseNotes -Version $Version -Content $releaseNotes
    
    # Update changelog
    Update-Changelog -Version $Version -Content $releaseNotes
    
    Write-Success "Release notes generated for version $Version"
}

# Show usage information
function Show-Usage {
    @"
Usage: .\release-notes-generator.ps1 [COMMAND] [VERSION]

Commands:
    generate <version>    Generate release notes for specified version
    help                  Show this help message

Examples:
    .\release-notes-generator.ps1 generate 1.2.3     # Generate release notes for version 1.2.3

"@
}

# Main script logic
switch ($Command) {
    "generate" {
        if ([string]::IsNullOrEmpty($Version)) {
            Write-Error "Version required for generate command"
            Show-Usage
            exit 1
        }
        Invoke-GenerateRelease -Version $Version
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