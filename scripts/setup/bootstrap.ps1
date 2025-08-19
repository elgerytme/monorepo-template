# Monorepo Development Environment Bootstrap Script (PowerShell)
# This script sets up the complete development environment with a single command

param(
    [switch]$SkipRust,
    [switch]$SkipBuck2,
    [switch]$SkipTools,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

# Colors for output
$Colors = @{
    Red = "Red"
    Green = "Green" 
    Yellow = "Yellow"
    Blue = "Blue"
    White = "White"
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "Info" { $Colors.Blue }
        "Success" { $Colors.Green }
        "Warning" { $Colors.Yellow }
        "Error" { $Colors.Red }
        default { $Colors.White }
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
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

function Install-Rust {
    if ($SkipRust) {
        Write-Log "Skipping Rust installation" -Level "Warning"
        return
    }
    
    Write-Log "Installing Rust toolchain..."
    
    if (Test-CommandExists "rustc") {
        $version = & rustc --version
        Write-Log "Rust already installed: $version" -Level "Success"
        return
    }
    
    # Download and install rustup
    $rustupUrl = "https://win.rustup.rs/x86_64"
    $rustupPath = "$env:TEMP\rustup-init.exe"
    
    Write-Log "Downloading rustup..."
    Invoke-WebRequest -Uri $rustupUrl -OutFile $rustupPath
    
    Write-Log "Installing Rust..."
    & $rustupPath -y --default-toolchain stable
    
    # Add to PATH for current session
    $env:PATH += ";$env:USERPROFILE\.cargo\bin"
    
    # Install specific toolchain if rust-toolchain.toml exists
    if (Test-Path "config\rust-toolchain.toml") {
        Write-Log "Installing toolchain from rust-toolchain.toml..."
        & rustup show
    }
    
    $version = & rustc --version
    Write-Log "Rust toolchain installed: $version" -Level "Success"
}

function Install-Buck2 {
    if ($SkipBuck2) {
        Write-Log "Skipping Buck2 installation" -Level "Warning"
        return
    }
    
    Write-Log "Installing Buck2..."
    
    if (Test-CommandExists "buck2") {
        $version = & buck2 --version
        Write-Log "Buck2 already installed: $version" -Level "Success"
        return
    }
    
    Write-Log "Please install Buck2 manually from: https://github.com/facebook/buck2/releases" -Level "Warning"
    Write-Log "Download the Windows binary and add it to your PATH" -Level "Warning"
}

function Install-RustTools {
    if ($SkipTools) {
        Write-Log "Skipping Rust tools installation" -Level "Warning"
        return
    }
    
    Write-Log "Installing Rust-based development tools..."
    
    $tools = @(
        "ripgrep",
        "fd-find", 
        "bat",
        "exa",
        "tokei",
        "hyperfine",
        "watchexec-cli",
        "typos-cli",
        "dprint",
        "just",
        "cargo-nextest",
        "cargo-audit",
        "cargo-deny"
    )
    
    foreach ($tool in $tools) {
        $commandName = $tool -replace "-.*", ""
        if (-not (Test-CommandExists $commandName)) {
            Write-Log "Installing $tool..."
            try {
                & cargo install $tool
                Write-Log "$tool installed successfully" -Level "Success"
            }
            catch {
                Write-Log "Failed to install $tool: $_" -Level "Error"
            }
        }
        else {
            Write-Log "$tool already installed" -Level "Success"
        }
    }
    
    Write-Log "Rust tools installation complete" -Level "Success"
}

function Install-LanguageTools {
    Write-Log "Installing language-specific tools..."
    
    # Check for Node.js
    if (-not (Test-CommandExists "node")) {
        Write-Log "Please install Node.js manually from nodejs.org" -Level "Warning"
    }
    else {
        $version = & node --version
        Write-Log "Node.js already installed: $version" -Level "Success"
    }
    
    # Check for Python
    if (-not (Test-CommandExists "python")) {
        Write-Log "Please install Python manually from python.org" -Level "Warning"
    }
    else {
        $version = & python --version
        Write-Log "Python already installed: $version" -Level "Success"
    }
    
    # Check for Go
    if (-not (Test-CommandExists "go")) {
        Write-Log "Please install Go manually from golang.org" -Level "Warning"
    }
    else {
        $version = & go version
        Write-Log "Go already installed: $version" -Level "Success"
    }
}

function Setup-GitHooks {
    Write-Log "Setting up Git hooks..."
    
    if (-not (Test-Path ".git")) {
        Write-Log "Not a Git repository, skipping Git hooks setup" -Level "Warning"
        return
    }
    
    $preCommitHook = @"
#!/bin/bash
set -e

echo "Running pre-commit checks..."

# Format check
if command -v dprint >/dev/null 2>&1; then
    echo "Checking formatting with dprint..."
    dprint check
fi

# Rust formatting
if command -v rustfmt >/dev/null 2>&1; then
    echo "Checking Rust formatting..."
    cargo fmt -- --check
fi

# Rust linting
if command -v clippy >/dev/null 2>&1; then
    echo "Running Rust linting..."
    cargo clippy -- -D warnings
fi

# Spell check
if command -v typos >/dev/null 2>&1; then
    echo "Running spell check..."
    typos
fi

# Security audit
if command -v cargo-audit >/dev/null 2>&1; then
    echo "Running security audit..."
    cargo audit
fi

echo "Pre-commit checks passed!"
"@
    
    $hookPath = ".git\hooks\pre-commit"
    $preCommitHook | Out-File -FilePath $hookPath -Encoding UTF8
    
    Write-Log "Git hooks configured" -Level "Success"
}

function Create-DevDirectories {
    Write-Log "Creating development directories..."
    
    $dirs = @(
        "apps",
        "libs",
        "tools", 
        "infra",
        "docs",
        "scripts\ci",
        "scripts\deployment",
        ".github\workflows",
        "config\platforms",
        "config\cpu",
        "config\os"
    )
    
    foreach ($dir in $dirs) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Log "Created directory: $dir"
        }
    }
    
    Write-Log "Development directories created" -Level "Success"
}

function Main {
    Write-Log "Starting monorepo development environment setup..."
    
    try {
        # Install core tools
        Install-Rust
        Install-Buck2
        Install-RustTools
        Install-LanguageTools
        
        # Setup environment
        Setup-GitHooks
        Create-DevDirectories
        
        # Run health check if available
        if (Test-Path "scripts\setup\health-check.ps1") {
            Write-Log "Running environment health check..."
            & "scripts\setup\health-check.ps1"
        }
        
        Write-Log "Development environment setup complete!" -Level "Success"
        Write-Log "You may need to restart your shell to use new tools"
        Write-Log "Run 'scripts\setup\health-check.ps1' to verify your environment"
    }
    catch {
        Write-Log "Setup failed: $_" -Level "Error"
        exit 1
    }
}

# Run main function
Main