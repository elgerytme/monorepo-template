# Template Packaging Script (PowerShell)
# Creates distributable packages of the monorepo template

param(
    [Parameter(Mandatory=$false)]
    [Alias("v")]
    [string]$Version,
    
    [Parameter(Mandatory=$false)]
    [Alias("o")]
    [string]$OutputDirectory,
    
    [Parameter(Mandatory=$false)]
    [Alias("n")]
    [string]$PackageName = "monorepo-template",
    
    [Parameter(Mandatory=$false)]
    [Alias("f")]
    [ValidateSet("zip", "tar.gz", "both")]
    [string]$Format = "zip",
    
    [Parameter(Mandatory=$false)]
    [switch]$NoExamples,
    
    [Parameter(Mandatory=$false)]
    [switch]$NoDocs,
    
    [Parameter(Mandatory=$false)]
    [Alias("h")]
    [switch]$Help
)

# Get script and repository paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $RepoRoot "releases"
}

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
Usage: .\package-template.ps1 [OPTIONS]

Package the monorepo template for distribution.

OPTIONS:
    -Version, -v VERSION      Package version (default: from VERSION file)
    -OutputDirectory, -o DIR  Output directory (default: releases/)
    -PackageName, -n NAME     Package name (default: monorepo-template)
    -Format, -f FORMAT        Package format: zip, tar.gz, both (default: zip)
    -NoExamples              Exclude example projects
    -NoDocs                  Exclude documentation
    -Help, -h                Show this help message

EXAMPLES:
    .\package-template.ps1                                    # Package with defaults
    .\package-template.ps1 -Version 1.0.0 -Format both       # Specific version, both formats
    .\package-template.ps1 -NoExamples -OutputDirectory C:\temp # Minimal package to C:\temp

"@
}

function Get-TemplateVersion {
    if ($Version) {
        return $Version
    }
    
    $versionFile = Join-Path $RepoRoot "VERSION"
    if (Test-Path $versionFile) {
        return Get-Content $versionFile -Raw | ForEach-Object { $_.Trim() }
    }
    
    try {
        $tag = git describe --tags --abbrev=0 2>$null
        if ($tag) {
            return $tag -replace '^v', ''
        }
    } catch {
        # Ignore git errors
    }
    
    return "0.1.0"
}

function New-TempDirectory {
    $tempDir = Join-Path $env:TEMP "$PackageName-packaging-$PID"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    return $tempDir
}

function Copy-CoreFiles {
    param(
        [string]$TempDirectory,
        [string]$PackageDirectory
    )
    
    Write-Info "Copying core template files..."
    
    New-Item -ItemType Directory -Path $PackageDirectory -Force | Out-Null
    
    # Core configuration files
    $coreFiles = @(
        ".buckconfig",
        ".buckroot",
        "BUCK",
        "justfile",
        "VERSION",
        "README.md",
        ".gitignore",
        ".pre-commit-config.yaml",
        ".markdownlint.yml",
        ".yamllint.yml",
        ".secrets.baseline",
        ".release-config.json"
    )
    
    foreach ($file in $coreFiles) {
        $sourcePath = Join-Path $RepoRoot $file
        if (Test-Path $sourcePath) {
            $targetPath = Join-Path $PackageDirectory $file
            Copy-Item $sourcePath $targetPath -Force
        }
    }
    
    # Core directories
    $coreDirs = @(
        "config",
        "scripts",
        ".github",
        ".devcontainer",
        ".vscode"
    )
    
    foreach ($dir in $coreDirs) {
        $sourcePath = Join-Path $RepoRoot $dir
        if (Test-Path $sourcePath) {
            $targetPath = Join-Path $PackageDirectory $dir
            Copy-Item $sourcePath $targetPath -Recurse -Force
        }
    }
    
    # Create empty directories with .gitkeep
    $emptyDirs = @(
        "apps",
        "libs",
        "tools",
        "infra",
        "releases",
        "signatures",
        "artifacts"
    )
    
    foreach ($dir in $emptyDirs) {
        $dirPath = Join-Path $PackageDirectory $dir
        New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
        $gitkeepPath = Join-Path $dirPath ".gitkeep"
        New-Item -ItemType File -Path $gitkeepPath -Force | Out-Null
    }
}

function Copy-Examples {
    param(
        [string]$PackageDirectory
    )
    
    if (-not $NoExamples) {
        Write-Info "Including example projects..."
        $examplesSource = Join-Path $RepoRoot "examples"
        if (Test-Path $examplesSource) {
            $examplesTarget = Join-Path $PackageDirectory "examples"
            Copy-Item $examplesSource $examplesTarget -Recurse -Force
        }
    } else {
        Write-Info "Excluding example projects..."
        $examplesDir = Join-Path $PackageDirectory "examples"
        New-Item -ItemType Directory -Path $examplesDir -Force | Out-Null
        $gitkeepPath = Join-Path $examplesDir ".gitkeep"
        New-Item -ItemType File -Path $gitkeepPath -Force | Out-Null
    }
}

function Copy-Documentation {
    param(
        [string]$PackageDirectory
    )
    
    if (-not $NoDocs) {
        Write-Info "Including documentation..."
        $docsSource = Join-Path $RepoRoot "docs"
        if (Test-Path $docsSource) {
            $docsTarget = Join-Path $PackageDirectory "docs"
            Copy-Item $docsSource $docsTarget -Recurse -Force
        }
    } else {
        Write-Info "Excluding documentation..."
        $docsDir = Join-Path $PackageDirectory "docs"
        New-Item -ItemType Directory -Path $docsDir -Force | Out-Null
        $gitkeepPath = Join-Path $docsDir ".gitkeep"
        New-Item -ItemType File -Path $gitkeepPath -Force | Out-Null
    }
}

function New-PackageMetadata {
    param(
        [string]$PackageDirectory,
        [string]$TemplateVersion
    )
    
    Write-Info "Creating package metadata..."
    
    # Create template metadata file
    $metadata = @{
        name = $PackageName
        version = $TemplateVersion
        description = "Enterprise-grade monorepo template with Buck2 and Rust tooling"
        created = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        languages = @("rust", "typescript", "python", "go")
        features = @(
            "buck2-build-system",
            "rust-tooling",
            "ci-cd-pipelines",
            "development-containers",
            "security-scanning",
            "observability",
            "documentation"
        )
        requirements = @{
            buck2 = ">=2024.01.01"
            rust = ">=1.70.0"
            git = ">=2.30.0"
        }
        repository = "https://github.com/your-org/monorepo-template"
        license = "MIT"
        maintainers = @(
            "Template Team <template-team@your-org.com>"
        )
    }
    
    $metadataPath = Join-Path $PackageDirectory ".template-metadata.json"
    $metadata | ConvertTo-Json -Depth 3 | Set-Content $metadataPath
    
    # Create installation instructions
    $installInstructions = @'
# Installation Instructions

## Quick Start

1. Extract the template package:
   ```powershell
   Expand-Archive monorepo-template-*.zip
   # or extract tar.gz with your preferred tool
   ```

2. Initialize a new project:
   ```powershell
   cd monorepo-template
   .\scripts\template\init-template.ps1 -Name my-project -Organization my-company
   ```

3. Set up development environment:
   ```powershell
   cd my-project
   .\scripts\setup\bootstrap.ps1
   ```

## Requirements

- **Buck2**: Build system (install from https://buck2.build/)
- **Rust**: Programming language and toolchain (install from https://rustup.rs/)
- **Git**: Version control system
- **Docker**: For development containers (optional)

## Supported Languages

- Rust (primary)
- TypeScript/JavaScript
- Python
- Go

## Features Included

- ✅ Buck2 build system configuration
- ✅ Rust-based development tooling
- ✅ CI/CD pipelines (GitHub Actions)
- ✅ Development containers
- ✅ Security scanning and policies
- ✅ Observability and monitoring setup
- ✅ Comprehensive documentation
- ✅ Example projects

## Next Steps

1. Read the documentation in `docs/`
2. Review example projects in `examples/`
3. Customize the template for your needs
4. Start building your monorepo!

For detailed migration guides and advanced usage, see the documentation.
'@
    
    $installPath = Join-Path $PackageDirectory "INSTALL.md"
    Set-Content $installPath $installInstructions
    
    # Create version tracking file
    $versionPath = Join-Path $PackageDirectory ".template-version"
    Set-Content $versionPath $TemplateVersion -NoNewline
}

function New-Checksums {
    param(
        [string]$PackageFile
    )
    
    Write-Info "Creating checksums for $(Split-Path -Leaf $PackageFile)..."
    
    try {
        # Create SHA256 checksum
        $hash = Get-FileHash $PackageFile -Algorithm SHA256
        $sha256File = "$PackageFile.sha256"
        "$($hash.Hash.ToLower())  $(Split-Path -Leaf $PackageFile)" | Set-Content $sha256File
        
        # Create MD5 checksum (for compatibility)
        $md5Hash = Get-FileHash $PackageFile -Algorithm MD5
        $md5File = "$PackageFile.md5"
        "$($md5Hash.Hash.ToLower())  $(Split-Path -Leaf $PackageFile)" | Set-Content $md5File
    } catch {
        Write-Warning "Failed to create checksums: $($_.Exception.Message)"
    }
}

function New-ZipPackage {
    param(
        [string]$TempDirectory,
        [string]$TemplateVersion
    )
    
    Write-Info "Creating zip package..."
    
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    
    $outputFile = Join-Path $OutputDirectory "$PackageName-$TemplateVersion.zip"
    $packageDir = Join-Path $TempDirectory $PackageName
    
    try {
        Compress-Archive -Path $packageDir -DestinationPath $outputFile -Force
        New-Checksums $outputFile
        
        Write-Success "Created: $outputFile"
        $size = (Get-Item $outputFile).Length
        $sizeKB = [math]::Round($size / 1KB, 2)
        Write-Info "Size: $sizeKB KB"
    } catch {
        Write-Error "Failed to create zip package: $($_.Exception.Message)"
    }
}

function New-TarGzPackage {
    param(
        [string]$TempDirectory,
        [string]$TemplateVersion
    )
    
    Write-Info "Creating tar.gz package..."
    
    # Check if tar is available (Windows 10 1803+ has built-in tar)
    try {
        $null = Get-Command tar -ErrorAction Stop
    } catch {
        Write-Warning "tar command not available, skipping tar.gz package creation"
        return
    }
    
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    
    $outputFile = Join-Path $OutputDirectory "$PackageName-$TemplateVersion.tar.gz"
    
    try {
        Push-Location $TempDirectory
        & tar -czf $outputFile $PackageName
        Pop-Location
        
        New-Checksums $outputFile
        
        Write-Success "Created: $outputFile"
        $size = (Get-Item $outputFile).Length
        $sizeKB = [math]::Round($size / 1KB, 2)
        Write-Info "Size: $sizeKB KB"
    } catch {
        Write-Error "Failed to create tar.gz package: $($_.Exception.Message)"
        if ($PWD.Path -ne $originalLocation) {
            Pop-Location
        }
    }
}

function Remove-TempDirectory {
    param([string]$TempDirectory)
    
    try {
        Remove-Item $TempDirectory -Recurse -Force
    } catch {
        Write-Warning "Could not remove temporary directory: $TempDirectory"
    }
}

function Main {
    Write-Info "Template Packaging Tool"
    Write-Info "======================="
    
    if ($Help) {
        Show-Usage
        return
    }
    
    $templateVersion = Get-TemplateVersion
    $includeExamples = -not $NoExamples
    $includeDocs = -not $NoDocs
    
    Write-Info "Package name: $PackageName"
    Write-Info "Version: $templateVersion"
    Write-Info "Format: $Format"
    Write-Info "Output directory: $OutputDirectory"
    Write-Info "Include examples: $includeExamples"
    Write-Info "Include docs: $includeDocs"
    
    # Create temporary directory
    $tempDir = New-TempDirectory
    $packageDir = Join-Path $tempDir $PackageName
    
    try {
        # Copy files
        Copy-CoreFiles $tempDir $packageDir
        Copy-Examples $packageDir
        Copy-Documentation $packageDir
        New-PackageMetadata $packageDir $templateVersion
        
        # Create packages
        switch ($Format) {
            "zip" {
                New-ZipPackage $tempDir $templateVersion
            }
            "tar.gz" {
                New-TarGzPackage $tempDir $templateVersion
            }
            "both" {
                New-ZipPackage $tempDir $templateVersion
                New-TarGzPackage $tempDir $templateVersion
            }
        }
        
        Write-Success "Template packaging completed!"
        Write-Info "Packages available in: $OutputDirectory"
        
        # List created files
        Write-Info "Created files:"
        Get-ChildItem $OutputDirectory -Filter "$PackageName-$templateVersion*" | ForEach-Object {
            Write-Host "  - $($_.Name)"
        }
    } finally {
        # Cleanup
        Remove-TempDirectory $tempDir
    }
}

# Run main function
Main