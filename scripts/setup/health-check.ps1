# Environment Health Check Script (PowerShell)
# Validates that all required tools are installed and working correctly

param(
    [string]$Mode = "full"
)

$ErrorActionPreference = "Continue"

# Colors
$Colors = @{
    Red = "Red"
    Green = "Green"
    Yellow = "Yellow"
    Blue = "Blue"
    White = "White"
}

# Counters
$script:TotalChecks = 0
$script:PassedChecks = 0
$script:FailedChecks = 0

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "Info"
    )
    
    $color = switch ($Level) {
        "Info" { $Colors.Blue }
        "Success" { $Colors.Green }
        "Warning" { $Colors.Yellow }
        "Error" { $Colors.Red }
        default { $Colors.White }
    }
    
    $prefix = switch ($Level) {
        "Info" { "[INFO]" }
        "Success" { "[✓]" }
        "Warning" { "[⚠]" }
        "Error" { "[✗]" }
        default { "[INFO]" }
    }
    
    Write-Host "$prefix $Message" -ForegroundColor $color
}

function Test-CommandExists {
    param([string]$Command)
    
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Test-Tool {
    param(
        [string]$Tool,
        [string]$Description,
        [string]$VersionCommand = "",
        [string]$RequiredVersion = ""
    )
    
    $script:TotalChecks++
    
    if (Test-CommandExists $Tool) {
        if ($VersionCommand) {
            try {
                $version = Invoke-Expression $VersionCommand 2>$null
                if ($RequiredVersion -and $version -ne $RequiredVersion) {
                    Write-Log "$Description`: $version (expected: $RequiredVersion)" -Level "Warning"
                } else {
                    Write-Log "$Description`: $version" -Level "Success"
                }
            }
            catch {
                Write-Log "$Description`: installed (version unknown)" -Level "Success"
            }
        } else {
            Write-Log "$Description`: installed" -Level "Success"
        }
        $script:PassedChecks++
        return $true
    } else {
        Write-Log "$Description`: not found" -Level "Error"
        $script:FailedChecks++
        return $false
    }
}

function Test-FileExists {
    param(
        [string]$Path,
        [string]$Description
    )
    
    $script:TotalChecks++
    
    if (Test-Path $Path) {
        Write-Log "$Description`: exists" -Level "Success"
        $script:PassedChecks++
        return $true
    } else {
        Write-Log "$Description`: missing" -Level "Error"
        $script:FailedChecks++
        return $false
    }
}

function Test-DirectoryExists {
    param(
        [string]$Path,
        [string]$Description
    )
    
    $script:TotalChecks++
    
    if (Test-Path $Path -PathType Container) {
        Write-Log "$Description`: exists" -Level "Success"
        $script:PassedChecks++
        return $true
    } else {
        Write-Log "$Description`: missing" -Level "Error"
        $script:FailedChecks++
        return $false
    }
}

function Test-ToolFunctionality {
    param(
        [string]$Tool,
        [string]$TestCommand,
        [string]$Description
    )
    
    $script:TotalChecks++
    
    try {
        Invoke-Expression $TestCommand | Out-Null
        Write-Log "$Description`: functional" -Level "Success"
        $script:PassedChecks++
        return $true
    }
    catch {
        Write-Log "$Description`: not functional" -Level "Error"
        $script:FailedChecks++
        return $false
    }
}

function Start-FullHealthCheck {
    Write-Log "Starting environment health check..."
    Write-Host
    
    # Core build tools
    Write-Log "Checking core build tools..."
    Test-Tool "rustc" "Rust compiler" "rustc --version | Select-String -Pattern '\d+\.\d+\.\d+' | ForEach-Object { $_.Matches[0].Value }"
    Test-Tool "cargo" "Cargo package manager" "cargo --version | Select-String -Pattern '\d+\.\d+\.\d+' | ForEach-Object { $_.Matches[0].Value }"
    Test-Tool "buck2" "Buck2 build system" "buck2 --version 2>$null | Select-String -Pattern '\d+\.\d+\.\d+' | ForEach-Object { $_.Matches[0].Value }"
    Write-Host
    
    # Rust development tools
    Write-Log "Checking Rust development tools..."
    Test-Tool "rustfmt" "Rust formatter"
    Test-Tool "cargo" "Cargo (clippy check)" "" ""
    Test-Tool "cargo" "Security auditor (cargo-audit)" "" ""
    Test-Tool "cargo" "Advanced test runner (cargo-nextest)" "" ""
    Write-Host
    
    # System tools
    Write-Log "Checking system tools..."
    Test-Tool "rg" "ripgrep (fast search)"
    Test-Tool "fd" "fd (fast find)"
    Test-Tool "bat" "bat (better cat)"
    Test-Tool "exa" "exa (better ls)"
    Test-Tool "tokei" "tokei (code stats)"
    Test-Tool "hyperfine" "hyperfine (benchmarking)"
    Test-Tool "watchexec" "watchexec (file watcher)"
    Test-Tool "typos" "typos (spell checker)"
    Test-Tool "dprint" "dprint (formatter)"
    Test-Tool "just" "just (command runner)"
    Write-Host
    
    # Language tools
    Write-Log "Checking language tools..."
    Test-Tool "node" "Node.js" "node --version"
    Test-Tool "npm" "npm" "npm --version"
    Test-Tool "python" "Python" "python --version"
    Test-Tool "pip" "pip" "pip --version"
    Test-Tool "go" "Go" "go version"
    Write-Host
    
    # Configuration files
    Write-Log "Checking configuration files..."
    Test-FileExists ".buckconfig" "Buck2 configuration"
    Test-FileExists ".buckroot" "Buck2 root marker"
    Test-FileExists "BUCK" "Root build file"
    Test-FileExists "config\rust-toolchain.toml" "Rust toolchain config"
    Test-FileExists "config\rustfmt.toml" "Rust formatter config"
    Test-FileExists "config\clippy.toml" "Clippy linter config"
    Test-FileExists "config\tools-versions.toml" "Tools versions config"
    Write-Host
    
    # Directory structure
    Write-Log "Checking directory structure..."
    Test-DirectoryExists "apps" "Applications directory"
    Test-DirectoryExists "libs" "Libraries directory"
    Test-DirectoryExists "tools" "Tools directory"
    Test-DirectoryExists "infra" "Infrastructure directory"
    Test-DirectoryExists "docs" "Documentation directory"
    Test-DirectoryExists "scripts" "Scripts directory"
    Test-DirectoryExists "config" "Configuration directory"
    Write-Host
    
    # Git configuration
    Write-Log "Checking Git configuration..."
    if (Test-Path ".git") {
        Test-FileExists ".git\hooks\pre-commit" "Pre-commit hook"
        Test-ToolFunctionality "git" "git status" "Git repository"
    } else {
        Write-Log "Not a Git repository" -Level "Warning"
    }
    Write-Host
    
    # Summary
    Write-Log "Health check summary:"
    Write-Host "  Total checks: $script:TotalChecks"
    Write-Host "  Passed: $script:PassedChecks" -ForegroundColor Green
    Write-Host "  Failed: $script:FailedChecks" -ForegroundColor Red
    
    if ($script:FailedChecks -eq 0) {
        Write-Host
        Write-Log "All checks passed! Your development environment is ready." -Level "Success"
        exit 0
    } else {
        Write-Host
        Write-Log "Some checks failed. Please review the output above and install missing tools." -Level "Error"
        Write-Log "Run 'scripts\setup\bootstrap.ps1' to install missing tools automatically."
        exit 1
    }
}

function Start-QuickHealthCheck {
    Write-Log "Running quick health check..."
    Test-Tool "rustc" "Rust compiler"
    Test-Tool "buck2" "Buck2 build system"
    Test-Tool "cargo" "Cargo"
    Write-Log "Quick check complete" -Level "Success"
}

function Start-ToolsCheck {
    Write-Log "Checking development tools only..."
    Test-Tool "rg" "ripgrep"
    Test-Tool "fd" "fd"
    Test-Tool "bat" "bat"
    Test-Tool "dprint" "dprint"
    Write-Log "Tools check complete" -Level "Success"
}

# Main execution
switch ($Mode.ToLower()) {
    "full" { Start-FullHealthCheck }
    "quick" { Start-QuickHealthCheck }
    "tools" { Start-ToolsCheck }
    default {
        Write-Host "Usage: .\health-check.ps1 [full|quick|tools]"
        exit 1
    }
}