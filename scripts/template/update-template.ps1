# Template Update Script (PowerShell)
# Updates an existing project to use the latest template version

param(
    [Parameter(Mandatory=$false)]
    [Alias("v")]
    [string]$Version,
    
    [Parameter(Mandatory=$false)]
    [Alias("d")]
    [string]$Directory = ".",
    
    [Parameter(Mandatory=$false)]
    [Alias("b")]
    [string]$BackupDirectory,
    
    [Parameter(Mandatory=$false)]
    [Alias("n")]
    [switch]$DryRun,
    
    [Parameter(Mandatory=$false)]
    [Alias("f")]
    [switch]$Force,
    
    [Parameter(Mandatory=$false)]
    [Alias("r")]
    [string]$Repository = "https://github.com/your-org/monorepo-template.git",
    
    [Parameter(Mandatory=$false)]
    [Alias("h")]
    [switch]$Help
)

# Colors for output
$Red = "Red"
$Green = "Green"
$Yellow = "Yellow"
$Blue = "Blue"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor $Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor $Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor $Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $Red
}

function Show-Usage {
    @"
Usage: .\update-template.ps1 [OPTIONS]

Update an existing project to use the latest template version.

OPTIONS:
    -Version, -v VERSION      Template version to update to (default: latest)
    -Directory, -d DIR        Target directory (default: current directory)
    -BackupDirectory, -b DIR  Backup directory (default: auto-generated)
    -DryRun, -n              Show what would be updated without making changes
    -Force, -f               Force update even if there are conflicts
    -Repository, -r URL      Template repository URL
    -Help, -h                Show this help message

EXAMPLES:
    .\update-template.ps1                                    # Update to latest version
    .\update-template.ps1 -Version v1.2.0                   # Update to specific version
    .\update-template.ps1 -DryRun                           # Preview changes
    .\update-template.ps1 -BackupDirectory C:\backup -Force # Force update with custom backup

"@
}

function Get-CurrentTemplateVersion {
    $templateVersionFile = Join-Path $Directory ".template-version"
    $versionFile = Join-Path $Directory "VERSION"
    
    if (Test-Path $templateVersionFile) {
        return Get-Content $templateVersionFile -Raw | ForEach-Object { $_.Trim() }
    } elseif (Test-Path $versionFile) {
        return Get-Content $versionFile -Raw | ForEach-Object { $_.Trim() }
    } else {
        return "unknown"
    }
}

function Get-LatestTemplateVersion {
    if ($Version) {
        return $Version
    } else {
        try {
            # Get latest release from git
            $tags = git ls-remote --tags --refs $Repository 2>$null | 
                    Where-Object { $_ -match 'refs/tags/v(\d+\.\d+\.\d+)$' } |
                    ForEach-Object { $matches[1] } |
                    Sort-Object { [version]$_ } |
                    Select-Object -Last 1
            
            if ($tags) {
                return $tags
            } else {
                return "main"
            }
        } catch {
            Write-Warning "Could not determine latest version, using 'main'"
            return "main"
        }
    }
}

function New-Backup {
    param([string]$BackupPath)
    
    Write-Info "Creating backup at $BackupPath..."
    
    if ($DryRun) {
        Write-Info "[DRY RUN] Would create backup at $BackupPath"
        return
    }
    
    New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
    
    # Backup important files and directories
    $backupItems = @(
        ".buckconfig",
        ".buckroot",
        "BUCK",
        "config",
        "scripts",
        ".github",
        ".devcontainer",
        "justfile",
        "VERSION",
        ".template-version"
    )
    
    foreach ($item in $backupItems) {
        $sourcePath = Join-Path $Directory $item
        if (Test-Path $sourcePath) {
            $targetPath = Join-Path $BackupPath $item
            try {
                if (Test-Path $sourcePath -PathType Container) {
                    Copy-Item $sourcePath $targetPath -Recurse -Force
                } else {
                    Copy-Item $sourcePath $targetPath -Force
                }
            } catch {
                Write-Warning "Could not backup $item`: $($_.Exception.Message)"
            }
        }
    }
    
    Write-Success "Backup created at $BackupPath"
}

function Get-Template {
    param(
        [string]$TemplateVersion,
        [string]$TempDirectory
    )
    
    Write-Info "Downloading template version $TemplateVersion..."
    
    if ($DryRun) {
        Write-Info "[DRY RUN] Would download template version $TemplateVersion"
        return
    }
    
    try {
        if ($TemplateVersion -eq "main" -or $TemplateVersion -eq "latest") {
            git clone --depth 1 $Repository $TempDirectory
        } else {
            git clone --depth 1 --branch "v$TemplateVersion" $Repository $TempDirectory
        }
        
        Write-Success "Template downloaded to $TempDirectory"
    } catch {
        throw "Failed to download template: $($_.Exception.Message)"
    }
}

function Compare-Files {
    param(
        [string]$File1,
        [string]$File2
    )
    
    if (-not (Test-Path $File1) -and -not (Test-Path $File2)) {
        return $true  # Both don't exist, no difference
    } elseif (-not (Test-Path $File1) -or -not (Test-Path $File2)) {
        return $false  # One exists, one doesn't
    } else {
        $hash1 = Get-FileHash $File1 -Algorithm MD5
        $hash2 = Get-FileHash $File2 -Algorithm MD5
        return $hash1.Hash -eq $hash2.Hash
    }
}

function Update-File {
    param(
        [string]$SourceFile,
        [string]$TargetFile,
        [string]$Description
    )
    
    if (Compare-Files $SourceFile $TargetFile) {
        Write-Info "✓ $Description (no changes)"
        return
    }
    
    if ($DryRun) {
        Write-Warning "[DRY RUN] Would update: $Description"
        return
    }
    
    # Check if target file has local modifications
    if ((Test-Path $TargetFile) -and -not $Force) {
        Write-Warning "File has potential local modifications: $TargetFile"
        $response = Read-Host "Update this file? [y/N]"
        if ($response -notmatch "^[Yy]$") {
            Write-Info "Skipped: $Description"
            return
        }
    }
    
    # Create target directory if it doesn't exist
    $targetDir = Split-Path -Parent $TargetFile
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
    
    Copy-Item $SourceFile $TargetFile -Force
    Write-Success "Updated: $Description"
}

function Update-TemplateFiles {
    param([string]$TemplateDirectory)
    
    Write-Info "Updating template files..."
    
    # Core configuration files
    $coreFiles = @{
        ".buckconfig" = "Buck2 configuration"
        ".buckroot" = "Buck2 root marker"
        "BUCK" = "Root build file"
        "justfile" = "Just command runner configuration"
    }
    
    foreach ($file in $coreFiles.Keys) {
        $sourcePath = Join-Path $TemplateDirectory $file
        if (Test-Path $sourcePath) {
            $targetPath = Join-Path $Directory $file
            Update-File $sourcePath $targetPath $coreFiles[$file]
        }
    }
    
    # Configuration directory
    $configDir = Join-Path $TemplateDirectory "config"
    if (Test-Path $configDir) {
        Write-Info "Updating configuration files..."
        Get-ChildItem $configDir -Recurse -File | ForEach-Object {
            $relativePath = $_.FullName.Substring($TemplateDirectory.Length + 1)
            $targetPath = Join-Path $Directory $relativePath
            Update-File $_.FullName $targetPath "Config: $($_.Name)"
        }
    }
    
    # Scripts directory (be careful with local modifications)
    $scriptsDir = Join-Path $TemplateDirectory "scripts"
    if (Test-Path $scriptsDir) {
        Write-Info "Updating scripts..."
        Get-ChildItem $scriptsDir -Recurse -File -Include "*.sh", "*.ps1" | ForEach-Object {
            $relativePath = $_.FullName.Substring($TemplateDirectory.Length + 1)
            $targetPath = Join-Path $Directory $relativePath
            
            # Skip if target has local modifications (unless forced)
            if ((Test-Path $targetPath) -and -not $Force) {
                if (-not (Compare-Files $_.FullName $targetPath)) {
                    Write-Warning "Script may have local modifications: $relativePath"
                    return
                }
            }
            
            Update-File $_.FullName $targetPath "Script: $($_.Name)"
        }
    }
    
    # GitHub workflows
    $githubDir = Join-Path $TemplateDirectory ".github"
    if (Test-Path $githubDir) {
        Write-Info "Updating GitHub workflows..."
        Get-ChildItem $githubDir -Recurse -File | ForEach-Object {
            $relativePath = $_.FullName.Substring($TemplateDirectory.Length + 1)
            $targetPath = Join-Path $Directory $relativePath
            Update-File $_.FullName $targetPath "Workflow: $($_.Name)"
        }
    }
    
    # Development container
    $devcontainerDir = Join-Path $TemplateDirectory ".devcontainer"
    if (Test-Path $devcontainerDir) {
        Write-Info "Updating development container configuration..."
        Get-ChildItem $devcontainerDir -Recurse -File | ForEach-Object {
            $relativePath = $_.FullName.Substring($TemplateDirectory.Length + 1)
            $targetPath = Join-Path $Directory $relativePath
            Update-File $_.FullName $targetPath "DevContainer: $($_.Name)"
        }
    }
}

function Update-VersionTracking {
    param([string]$NewVersion)
    
    if ($DryRun) {
        Write-Info "[DRY RUN] Would update template version to $NewVersion"
        return
    }
    
    $templateVersionFile = Join-Path $Directory ".template-version"
    Set-Content -Path $templateVersionFile -Value $NewVersion -NoNewline
    Write-Success "Updated template version tracking to $NewVersion"
}

function Test-UpdatedTemplate {
    Write-Info "Validating updated template..."
    
    if ($DryRun) {
        Write-Info "[DRY RUN] Would run template validation"
        return
    }
    
    # Run template validation if available
    $validationScript = Join-Path $Directory "scripts\template\validate-template.ps1"
    if (Test-Path $validationScript) {
        Push-Location $Directory
        try {
            & $validationScript
            Write-Success "Template validation passed"
        } catch {
            Write-Warning "Template validation failed - please review the issues"
        } finally {
            Pop-Location
        }
    } else {
        Write-Warning "Template validation script not found"
    }
}

function Main {
    Write-Info "Template Update Tool"
    Write-Info "==================="
    
    if ($Help) {
        Show-Usage
        return
    }
    
    # Validate target directory
    if (-not (Test-Path $Directory)) {
        Write-Error "Target directory does not exist: $Directory"
        exit 1
    }
    
    # Convert to absolute path
    $Directory = Resolve-Path $Directory
    
    # Get current and target versions
    $currentVersion = Get-CurrentTemplateVersion
    $targetVersion = Get-LatestTemplateVersion
    
    Write-Info "Current template version: $currentVersion"
    Write-Info "Target template version: $targetVersion"
    
    if ($currentVersion -eq $targetVersion -and -not $Force) {
        Write-Info "Already up to date!"
        return
    }
    
    # Set up backup directory
    if (-not $BackupDirectory) {
        $BackupDirectory = Join-Path $env:TEMP "template-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    }
    
    # Create backup
    New-Backup $BackupDirectory
    
    # Download template
    $tempDir = Join-Path $env:TEMP "template-update-$PID"
    Get-Template $targetVersion $tempDir
    
    try {
        # Update files
        Update-TemplateFiles $tempDir
        
        # Update version tracking
        Update-VersionTracking $targetVersion
        
        # Validate update
        Test-UpdatedTemplate
        
        Write-Success "Template update completed!"
        Write-Info "Backup available at: $BackupDirectory"
        Write-Info "Next steps:"
        Write-Info "  1. Review the changes"
        Write-Info "  2. Test your project builds and runs correctly"
        Write-Info "  3. Commit the template updates"
        Write-Info "  4. Remove backup when satisfied: Remove-Item '$BackupDirectory' -Recurse"
    } finally {
        # Cleanup
        if (-not $DryRun -and (Test-Path $tempDir)) {
            Remove-Item $tempDir -Recurse -Force
        }
    }
}

# Run main function
Main