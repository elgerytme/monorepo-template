# Template Validation and Health Check Script (PowerShell)
# This script validates the monorepo template structure and configuration

param(
    [Parameter(Mandatory=$false)]
    [switch]$Detailed,
    
    [Parameter(Mandatory=$false)]
    [switch]$FixIssues,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputFormat = "console"  # console, json, xml
)

# Validation results
$script:ValidationErrors = 0
$script:ValidationWarnings = 0
$script:ValidationResults = @()

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
    $script:ValidationWarnings++
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $Red
    $script:ValidationErrors++
}

function Write-Check {
    param([string]$Message)
    Write-Host "[✓] $Message" -ForegroundColor $Green
}

function Write-Fail {
    param([string]$Message)
    Write-Host "[✗] $Message" -ForegroundColor $Red
    $script:ValidationErrors++
}

function Add-ValidationResult {
    param(
        [string]$Category,
        [string]$Item,
        [string]$Status,
        [string]$Message,
        [string]$Severity = "Info"
    )
    
    $script:ValidationResults += [PSCustomObject]@{
        Category = $Category
        Item = $Item
        Status = $Status
        Message = $Message
        Severity = $Severity
        Timestamp = Get-Date
    }
}

function Test-FileExists {
    param(
        [string]$Path,
        [string]$Description
    )
    
    if (Test-Path $Path -PathType Leaf) {
        Write-Check "$Description`: $Path"
        Add-ValidationResult -Category "Files" -Item $Path -Status "Pass" -Message $Description
        return $true
    } else {
        Write-Fail "$Description`: $Path (missing or not readable)"
        Add-ValidationResult -Category "Files" -Item $Path -Status "Fail" -Message "$Description (missing)" -Severity "Error"
        return $false
    }
}

function Test-DirectoryExists {
    param(
        [string]$Path,
        [string]$Description
    )
    
    if (Test-Path $Path -PathType Container) {
        Write-Check "$Description`: $Path"
        Add-ValidationResult -Category "Directories" -Item $Path -Status "Pass" -Message $Description
        return $true
    } else {
        Write-Fail "$Description`: $Path (missing)"
        Add-ValidationResult -Category "Directories" -Item $Path -Status "Fail" -Message "$Description (missing)" -Severity "Error"
        return $false
    }
}

function Test-CommandExists {
    param([string]$Command)
    
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Test-Buck2Configuration {
    Write-Info "Validating Buck2 configuration..."
    
    Test-FileExists -Path ".buckconfig" -Description "Buck2 configuration file"
    Test-FileExists -Path ".buckroot" -Description "Buck2 root marker"
    Test-FileExists -Path "BUCK" -Description "Root Buck2 build file"
    
    # Check Buck2 installation
    if (Test-CommandExists "buck2") {
        try {
            $version = & buck2 --version 2>$null
            Write-Check "Buck2 is installed: $version"
            Add-ValidationResult -Category "Tools" -Item "buck2" -Status "Pass" -Message "Buck2 installed: $version"
        } catch {
            Write-Warning "Buck2 is installed but version check failed"
            Add-ValidationResult -Category "Tools" -Item "buck2" -Status "Warning" -Message "Buck2 version check failed" -Severity "Warning"
        }
    } else {
        Write-Warning "Buck2 is not installed or not in PATH"
        Add-ValidationResult -Category "Tools" -Item "buck2" -Status "Warning" -Message "Buck2 not found in PATH" -Severity "Warning"
    }
    
    # Validate .buckconfig syntax (basic check)
    if (Test-Path ".buckconfig") {
        try {
            $content = Get-Content ".buckconfig" -Raw
            if ($content -match '^\[.*\]') {
                Write-Check "Buck2 configuration appears to have valid INI format"
                Add-ValidationResult -Category "Configuration" -Item ".buckconfig" -Status "Pass" -Message "Valid INI format"
            } else {
                Write-Error "Buck2 configuration does not appear to be valid INI format"
                Add-ValidationResult -Category "Configuration" -Item ".buckconfig" -Status "Fail" -Message "Invalid INI format" -Severity "Error"
            }
        } catch {
            Write-Error "Failed to read Buck2 configuration file"
            Add-ValidationResult -Category "Configuration" -Item ".buckconfig" -Status "Fail" -Message "Failed to read file" -Severity "Error"
        }
    }
}

function Test-RustConfiguration {
    Write-Info "Validating Rust configuration..."
    
    Test-FileExists -Path "config/rust-toolchain.toml" -Description "Rust toolchain configuration"
    Test-FileExists -Path "config/rustfmt.toml" -Description "Rust formatter configuration"
    Test-FileExists -Path "config/clippy.toml" -Description "Clippy configuration"
    
    # Check Rust installation
    if (Test-CommandExists "rustc") {
        try {
            $rustVersion = & rustc --version
            Write-Check "Rust is installed: $rustVersion"
            Add-ValidationResult -Category "Tools" -Item "rustc" -Status "Pass" -Message "Rust installed: $rustVersion"
            
            # Check if installed version matches toolchain file
            if (Test-Path "config/rust-toolchain.toml") {
                try {
                    $toolchainContent = Get-Content "config/rust-toolchain.toml" -Raw
                    if ($toolchainContent -match 'channel\s*=\s*"([^"]*)"') {
                        $toolchainVersion = $matches[1]
                        if ($rustVersion -like "*$toolchainVersion*") {
                            Write-Check "Rust version matches toolchain configuration"
                            Add-ValidationResult -Category "Configuration" -Item "rust-toolchain" -Status "Pass" -Message "Version matches toolchain"
                        } else {
                            Write-Warning "Rust version ($rustVersion) may not match toolchain configuration ($toolchainVersion)"
                            Add-ValidationResult -Category "Configuration" -Item "rust-toolchain" -Status "Warning" -Message "Version mismatch" -Severity "Warning"
                        }
                    }
                } catch {
                    Write-Warning "Could not parse toolchain configuration"
                    Add-ValidationResult -Category "Configuration" -Item "rust-toolchain" -Status "Warning" -Message "Parse error" -Severity "Warning"
                }
            }
        } catch {
            Write-Error "Rust is installed but version check failed"
            Add-ValidationResult -Category "Tools" -Item "rustc" -Status "Fail" -Message "Version check failed" -Severity "Error"
        }
    } else {
        Write-Error "Rust is not installed or not in PATH"
        Add-ValidationResult -Category "Tools" -Item "rustc" -Status "Fail" -Message "Rust not found in PATH" -Severity "Error"
    }
    
    # Check Rust tools
    $rustTools = @("cargo", "rustfmt", "clippy")
    foreach ($tool in $rustTools) {
        if (Test-CommandExists $tool) {
            Write-Check "Rust tool available: $tool"
            Add-ValidationResult -Category "Tools" -Item $tool -Status "Pass" -Message "Tool available"
        } else {
            Write-Warning "Rust tool not available: $tool"
            Add-ValidationResult -Category "Tools" -Item $tool -Status "Warning" -Message "Tool not available" -Severity "Warning"
        }
    }
    
    # Check cargo-audit separately as it's typically installed via cargo install
    if (Test-CommandExists "cargo-audit") {
        Write-Check "Rust tool available: cargo-audit"
        Add-ValidationResult -Category "Tools" -Item "cargo-audit" -Status "Pass" -Message "Tool available"
    } else {
        Write-Warning "Rust tool not available: cargo-audit (install with: cargo install cargo-audit)"
        Add-ValidationResult -Category "Tools" -Item "cargo-audit" -Status "Warning" -Message "Tool not available" -Severity "Warning"
    }
}

function Test-DirectoryStructure {
    Write-Info "Validating directory structure..."
    
    $requiredDirs = @(
        "apps",
        "libs", 
        "tools",
        "infra",
        "docs",
        "scripts",
        "config",
        "examples",
        ".github",
        ".devcontainer"
    )
    
    foreach ($dir in $requiredDirs) {
        Test-DirectoryExists -Path $dir -Description "Required directory"
    }
    
    # Check for .gitkeep files in empty directories
    $emptyDirs = @("apps", "libs", "tools", "infra", "releases", "signatures", "artifacts")
    foreach ($dir in $emptyDirs) {
        if (Test-Path $dir -PathType Container) {
            $gitkeepPath = Join-Path $dir ".gitkeep"
            if (Test-Path $gitkeepPath) {
                Write-Check "Directory placeholder: $gitkeepPath"
                Add-ValidationResult -Category "Structure" -Item $gitkeepPath -Status "Pass" -Message "Placeholder file exists"
            } else {
                $fileCount = (Get-ChildItem $dir -Recurse -File).Count
                if ($fileCount -eq 0) {
                    Write-Warning "Empty directory without .gitkeep: $dir"
                    Add-ValidationResult -Category "Structure" -Item $dir -Status "Warning" -Message "Empty directory without .gitkeep" -Severity "Warning"
                }
            }
        }
    }
}

function Test-CICDConfiguration {
    Write-Info "Validating CI/CD configuration..."
    
    Test-DirectoryExists -Path ".github/workflows" -Description "GitHub Actions workflows directory"
    
    # Check for essential workflow files
    $workflowFiles = @(
        ".github/workflows/ci.yml",
        ".github/workflows/security.yml",
        ".github/workflows/release.yml"
    )
    
    foreach ($workflow in $workflowFiles) {
        if (Test-Path $workflow) {
            Write-Check "Workflow file: $workflow"
            Add-ValidationResult -Category "CI/CD" -Item $workflow -Status "Pass" -Message "Workflow file exists"
            
            # Basic YAML syntax validation
            try {
                $content = Get-Content $workflow -Raw
                # Basic YAML structure check
                if ($content -match '^\s*name\s*:' -and $content -match '^\s*on\s*:') {
                    Write-Check "YAML structure appears valid: $workflow"
                    Add-ValidationResult -Category "CI/CD" -Item "$workflow-syntax" -Status "Pass" -Message "YAML structure valid"
                } else {
                    Write-Warning "YAML structure may be invalid: $workflow"
                    Add-ValidationResult -Category "CI/CD" -Item "$workflow-syntax" -Status "Warning" -Message "YAML structure questionable" -Severity "Warning"
                }
            } catch {
                Write-Error "Failed to read workflow file: $workflow"
                Add-ValidationResult -Category "CI/CD" -Item "$workflow-syntax" -Status "Fail" -Message "Failed to read file" -Severity "Error"
            }
        } else {
            Write-Warning "Missing workflow file: $workflow"
            Add-ValidationResult -Category "CI/CD" -Item $workflow -Status "Warning" -Message "Missing workflow file" -Severity "Warning"
        }
    }
}

function Test-DevEnvironment {
    Write-Info "Validating development environment configuration..."
    
    Test-FileExists -Path ".devcontainer/devcontainer.json" -Description "Dev container configuration"
    Test-FileExists -Path ".devcontainer/Dockerfile" -Description "Dev container Dockerfile"
    
    # Validate devcontainer.json syntax
    if (Test-Path ".devcontainer/devcontainer.json") {
        try {
            $content = Get-Content ".devcontainer/devcontainer.json" -Raw | ConvertFrom-Json
            Write-Check "Dev container JSON syntax is valid"
            Add-ValidationResult -Category "DevEnvironment" -Item "devcontainer.json" -Status "Pass" -Message "JSON syntax valid"
        } catch {
            Write-Error "Dev container JSON syntax error: $($_.Exception.Message)"
            Add-ValidationResult -Category "DevEnvironment" -Item "devcontainer.json" -Status "Fail" -Message "JSON syntax error" -Severity "Error"
        }
    }
    
    # Check VS Code configuration
    if (Test-Path ".vscode" -PathType Container) {
        Write-Check "VS Code configuration directory exists"
        Add-ValidationResult -Category "DevEnvironment" -Item ".vscode" -Status "Pass" -Message "VS Code config directory exists"
        
        $vscodeFiles = @(".vscode/settings.json", ".vscode/extensions.json")
        foreach ($file in $vscodeFiles) {
            if (Test-Path $file) {
                Write-Check "VS Code configuration: $file"
                Add-ValidationResult -Category "DevEnvironment" -Item $file -Status "Pass" -Message "VS Code config file exists"
            } else {
                Write-Warning "Missing VS Code configuration: $file"
                Add-ValidationResult -Category "DevEnvironment" -Item $file -Status "Warning" -Message "Missing VS Code config" -Severity "Warning"
            }
        }
    } else {
        Write-Warning "VS Code configuration directory missing"
        Add-ValidationResult -Category "DevEnvironment" -Item ".vscode" -Status "Warning" -Message "VS Code config directory missing" -Severity "Warning"
    }
}

function Test-Scripts {
    Write-Info "Validating scripts and automation..."
    
    Test-DirectoryExists -Path "scripts/setup" -Description "Setup scripts directory"
    Test-DirectoryExists -Path "scripts/ci" -Description "CI scripts directory"
    
    # Check for essential scripts (both .sh and .ps1 versions)
    $essentialScripts = @(
        @{ Path = "scripts/setup/bootstrap.sh"; Alt = "scripts/setup/bootstrap.ps1" },
        @{ Path = "scripts/ci/validate.sh"; Alt = "scripts/ci/validate.ps1" },
        @{ Path = "scripts/security/audit.sh"; Alt = "scripts/security/audit.ps1" }
    )
    
    foreach ($scriptInfo in $essentialScripts) {
        $found = $false
        if (Test-Path $scriptInfo.Path) {
            Write-Check "Script exists: $($scriptInfo.Path)"
            Add-ValidationResult -Category "Scripts" -Item $scriptInfo.Path -Status "Pass" -Message "Script exists"
            $found = $true
        }
        if (Test-Path $scriptInfo.Alt) {
            Write-Check "Script exists: $($scriptInfo.Alt)"
            Add-ValidationResult -Category "Scripts" -Item $scriptInfo.Alt -Status "Pass" -Message "Script exists"
            $found = $true
        }
        
        if (-not $found) {
            Write-Warning "Missing script: $($scriptInfo.Path) or $($scriptInfo.Alt)"
            Add-ValidationResult -Category "Scripts" -Item $scriptInfo.Path -Status "Warning" -Message "Missing script" -Severity "Warning"
        }
    }
    
    # Check justfile
    if (Test-Path "justfile") {
        Write-Check "Justfile exists"
        Add-ValidationResult -Category "Scripts" -Item "justfile" -Status "Pass" -Message "Justfile exists"
        
        if (Test-CommandExists "just") {
            try {
                & just --list | Out-Null
                Write-Check "Justfile syntax is valid"
                Add-ValidationResult -Category "Scripts" -Item "justfile-syntax" -Status "Pass" -Message "Justfile syntax valid"
            } catch {
                Write-Error "Justfile syntax error"
                Add-ValidationResult -Category "Scripts" -Item "justfile-syntax" -Status "Fail" -Message "Justfile syntax error" -Severity "Error"
            }
        } else {
            Write-Warning "Just command runner not installed"
            Add-ValidationResult -Category "Tools" -Item "just" -Status "Warning" -Message "Just not installed" -Severity "Warning"
        }
    } else {
        Write-Warning "Justfile missing"
        Add-ValidationResult -Category "Scripts" -Item "justfile" -Status "Warning" -Message "Justfile missing" -Severity "Warning"
    }
}

function Test-ConfigurationFiles {
    Write-Info "Validating configuration files..."
    
    $configFiles = @(
        "config/rust-toolchain.toml",
        "config/rustfmt.toml",
        "config/clippy.toml",
        "config/nextest.toml",
        "config/dprint.json",
        ".gitignore",
        ".pre-commit-config.yaml"
    )
    
    foreach ($config in $configFiles) {
        if (Test-Path $config) {
            Write-Check "Configuration file: $config"
            Add-ValidationResult -Category "Configuration" -Item $config -Status "Pass" -Message "Configuration file exists"
            
            # Validate specific file formats
            $extension = [System.IO.Path]::GetExtension($config)
            switch ($extension) {
                ".json" {
                    try {
                        Get-Content $config -Raw | ConvertFrom-Json | Out-Null
                        Write-Check "JSON syntax valid: $config"
                        Add-ValidationResult -Category "Configuration" -Item "$config-syntax" -Status "Pass" -Message "JSON syntax valid"
                    } catch {
                        Write-Error "JSON syntax error: $config"
                        Add-ValidationResult -Category "Configuration" -Item "$config-syntax" -Status "Fail" -Message "JSON syntax error" -Severity "Error"
                    }
                }
                ".toml" {
                    # Basic TOML validation (check for common patterns)
                    try {
                        $content = Get-Content $config -Raw
                        if ($content -match '^\s*\[.*\]' -or $content -match '^\s*\w+\s*=') {
                            Write-Check "TOML structure appears valid: $config"
                            Add-ValidationResult -Category "Configuration" -Item "$config-syntax" -Status "Pass" -Message "TOML structure valid"
                        } else {
                            Write-Warning "TOML structure may be invalid: $config"
                            Add-ValidationResult -Category "Configuration" -Item "$config-syntax" -Status "Warning" -Message "TOML structure questionable" -Severity "Warning"
                        }
                    } catch {
                        Write-Error "Failed to read TOML file: $config"
                        Add-ValidationResult -Category "Configuration" -Item "$config-syntax" -Status "Fail" -Message "Failed to read TOML" -Severity "Error"
                    }
                }
            }
        } else {
            Write-Warning "Missing configuration file: $config"
            Add-ValidationResult -Category "Configuration" -Item $config -Status "Warning" -Message "Missing configuration file" -Severity "Warning"
        }
    }
}

function Test-Examples {
    Write-Info "Validating example projects..."
    
    Test-DirectoryExists -Path "examples" -Description "Examples directory"
    
    # Check for example projects
    $exampleDirs = @("web-service", "frontend-app", "shared-library", "infrastructure")
    foreach ($example in $exampleDirs) {
        $examplePath = "examples/$example"
        if (Test-Path $examplePath -PathType Container) {
            Write-Check "Example project: $example"
            Add-ValidationResult -Category "Examples" -Item $example -Status "Pass" -Message "Example project exists"
            
            # Validate specific example types
            switch ($example) {
                "web-service" {
                    $cargoPath = "$examplePath/Cargo.toml"
                    if (Test-Path $cargoPath) {
                        Write-Check "Rust web service example has Cargo.toml"
                        Add-ValidationResult -Category "Examples" -Item "$example-cargo" -Status "Pass" -Message "Cargo.toml exists"
                    } else {
                        Write-Warning "Rust web service example missing Cargo.toml"
                        Add-ValidationResult -Category "Examples" -Item "$example-cargo" -Status "Warning" -Message "Missing Cargo.toml" -Severity "Warning"
                    }
                }
                "frontend-app" {
                    $packagePath = "$examplePath/package.json"
                    if (Test-Path $packagePath) {
                        Write-Check "Frontend app example has package.json"
                        Add-ValidationResult -Category "Examples" -Item "$example-package" -Status "Pass" -Message "package.json exists"
                    } else {
                        Write-Warning "Frontend app example missing package.json"
                        Add-ValidationResult -Category "Examples" -Item "$example-package" -Status "Warning" -Message "Missing package.json" -Severity "Warning"
                    }
                }
            }
        } else {
            Write-Warning "Missing example project: $example"
            Add-ValidationResult -Category "Examples" -Item $example -Status "Warning" -Message "Missing example project" -Severity "Warning"
        }
    }
}

function Test-Documentation {
    Write-Info "Validating documentation..."
    
    Test-FileExists -Path "README.md" -Description "Main README file"
    Test-DirectoryExists -Path "docs" -Description "Documentation directory"
    
    $docDirs = @("docs/architecture", "docs/onboarding", "docs/runbooks")
    foreach ($docDir in $docDirs) {
        if (Test-Path $docDir -PathType Container) {
            Write-Check "Documentation directory: $docDir"
            Add-ValidationResult -Category "Documentation" -Item $docDir -Status "Pass" -Message "Documentation directory exists"
        } else {
            Write-Warning "Missing documentation directory: $docDir"
            Add-ValidationResult -Category "Documentation" -Item $docDir -Status "Warning" -Message "Missing documentation directory" -Severity "Warning"
        }
    }
    
    # Check for essential documentation files
    $essentialDocs = @(
        "docs/architecture/README.md",
        "docs/onboarding/README.md",
        "docs/SECURITY.md"
    )
    
    foreach ($doc in $essentialDocs) {
        if (Test-Path $doc) {
            Write-Check "Documentation file: $doc"
            Add-ValidationResult -Category "Documentation" -Item $doc -Status "Pass" -Message "Documentation file exists"
        } else {
            Write-Warning "Missing documentation file: $doc"
            Add-ValidationResult -Category "Documentation" -Item $doc -Status "Warning" -Message "Missing documentation file" -Severity "Warning"
        }
    }
}

function Invoke-HealthChecks {
    Write-Info "Running health checks..."
    
    # Check disk space
    try {
        $drive = Get-PSDrive -Name (Get-Location).Drive.Name
        $freeSpaceGB = [math]::Round($drive.Free / 1GB, 2)
        if ($freeSpaceGB -gt 1) {
            Write-Check "Sufficient disk space available: $freeSpaceGB GB"
            Add-ValidationResult -Category "Health" -Item "disk-space" -Status "Pass" -Message "Sufficient disk space: $freeSpaceGB GB"
        } else {
            Write-Warning "Low disk space: $freeSpaceGB GB available"
            Add-ValidationResult -Category "Health" -Item "disk-space" -Status "Warning" -Message "Low disk space: $freeSpaceGB GB" -Severity "Warning"
        }
    } catch {
        Write-Warning "Could not check disk space"
        Add-ValidationResult -Category "Health" -Item "disk-space" -Status "Warning" -Message "Could not check disk space" -Severity "Warning"
    }
    
    # Check git repository status
    if (Test-Path ".git" -PathType Container) {
        Write-Check "Git repository initialized"
        Add-ValidationResult -Category "Health" -Item "git-repo" -Status "Pass" -Message "Git repository initialized"
        
        # Check for uncommitted changes
        try {
            $status = & git status --porcelain 2>$null
            if ([string]::IsNullOrEmpty($status)) {
                Write-Check "Working directory is clean"
                Add-ValidationResult -Category "Health" -Item "git-status" -Status "Pass" -Message "Working directory clean"
            } else {
                Write-Warning "Working directory has uncommitted changes"
                Add-ValidationResult -Category "Health" -Item "git-status" -Status "Warning" -Message "Uncommitted changes" -Severity "Warning"
            }
        } catch {
            Write-Warning "Could not check git status"
            Add-ValidationResult -Category "Health" -Item "git-status" -Status "Warning" -Message "Could not check git status" -Severity "Warning"
        }
        
        # Check for remote repository
        try {
            $remotes = & git remote -v 2>$null
            if ($remotes -match "origin") {
                Write-Check "Git remote 'origin' configured"
                Add-ValidationResult -Category "Health" -Item "git-remote" -Status "Pass" -Message "Git remote configured"
            } else {
                Write-Warning "Git remote 'origin' not configured"
                Add-ValidationResult -Category "Health" -Item "git-remote" -Status "Warning" -Message "Git remote not configured" -Severity "Warning"
            }
        } catch {
            Write-Warning "Could not check git remotes"
            Add-ValidationResult -Category "Health" -Item "git-remote" -Status "Warning" -Message "Could not check git remotes" -Severity "Warning"
        }
    } else {
        Write-Warning "Not a git repository"
        Add-ValidationResult -Category "Health" -Item "git-repo" -Status "Warning" -Message "Not a git repository" -Severity "Warning"
    }
    
    # Check for common development tools
    $devTools = @("git", "curl", "docker")
    foreach ($tool in $devTools) {
        if (Test-CommandExists $tool) {
            Write-Check "Development tool available: $tool"
            Add-ValidationResult -Category "Health" -Item "tool-$tool" -Status "Pass" -Message "Tool available"
        } else {
            Write-Warning "Development tool not available: $tool"
            Add-ValidationResult -Category "Health" -Item "tool-$tool" -Status "Warning" -Message "Tool not available" -Severity "Warning"
        }
    }
}

function Export-ValidationReport {
    param([string]$Format)
    
    switch ($Format.ToLower()) {
        "json" {
            $report = @{
                Summary = @{
                    Errors = $script:ValidationErrors
                    Warnings = $script:ValidationWarnings
                    Total = $script:ValidationResults.Count
                    Timestamp = Get-Date
                }
                Results = $script:ValidationResults
            }
            $report | ConvertTo-Json -Depth 3
        }
        "xml" {
            # Create XML report
            $xml = New-Object System.Xml.XmlDocument
            $root = $xml.CreateElement("ValidationReport")
            $xml.AppendChild($root) | Out-Null
            
            $summary = $xml.CreateElement("Summary")
            $summary.SetAttribute("Errors", $script:ValidationErrors)
            $summary.SetAttribute("Warnings", $script:ValidationWarnings)
            $summary.SetAttribute("Total", $script:ValidationResults.Count)
            $summary.SetAttribute("Timestamp", (Get-Date).ToString())
            $root.AppendChild($summary) | Out-Null
            
            $results = $xml.CreateElement("Results")
            foreach ($result in $script:ValidationResults) {
                $item = $xml.CreateElement("Item")
                $item.SetAttribute("Category", $result.Category)
                $item.SetAttribute("Name", $result.Item)
                $item.SetAttribute("Status", $result.Status)
                $item.SetAttribute("Severity", $result.Severity)
                $item.InnerText = $result.Message
                $results.AppendChild($item) | Out-Null
            }
            $root.AppendChild($results) | Out-Null
            
            return $xml.OuterXml
        }
        default {
            # Console output (already done)
            return $null
        }
    }
}

function New-ValidationReport {
    Write-Info "Validation Summary"
    Write-Info "=================="
    
    if ($script:ValidationErrors -eq 0 -and $script:ValidationWarnings -eq 0) {
        Write-Success "✅ Template validation passed with no issues!"
    } elseif ($script:ValidationErrors -eq 0) {
        Write-Success "✅ Template validation passed with $script:ValidationWarnings warning(s)"
        Write-Info "Review warnings above for potential improvements"
    } else {
        Write-Error "❌ Template validation failed with $script:ValidationErrors error(s) and $script:ValidationWarnings warning(s)"
        Write-Info "Fix errors above before using the template"
    }
    
    Write-Host ""
    Write-Info "Validation completed at $(Get-Date)"
    
    # Export report if requested
    if ($OutputFormat -ne "console") {
        $report = Export-ValidationReport -Format $OutputFormat
        if ($report) {
            $reportFile = "validation-report.$($OutputFormat.ToLower())"
            Set-Content -Path $reportFile -Value $report
            Write-Info "Report exported to: $reportFile"
        }
    }
    
    return $script:ValidationErrors
}

# Main execution
function Main {
    Write-Info "Monorepo Template Validation"
    Write-Info "============================="
    
    # Change to script directory to ensure relative paths work
    $scriptDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    if (Test-Path $scriptDir) {
        Set-Location $scriptDir
    }
    
    Test-DirectoryStructure
    Test-Buck2Configuration
    Test-RustConfiguration
    Test-CICDConfiguration
    Test-DevEnvironment
    Test-Scripts
    Test-ConfigurationFiles
    Test-Examples
    Test-Documentation
    Invoke-HealthChecks
    
    $exitCode = New-ValidationReport
    exit $exitCode
}

# Run main function
Main