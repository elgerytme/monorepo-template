# Setup script for code quality enforcement system on Windows
# Installs and configures pre-commit hooks and quality tools

param(
    [switch]$SkipToolInstall = $false
)

# Colors for output
$Red = [System.ConsoleColor]::Red
$Green = [System.ConsoleColor]::Green
$Yellow = [System.ConsoleColor]::Yellow
$Blue = [System.ConsoleColor]::Blue
$DefaultColor = [System.Console]::ForegroundColor

function Write-Status {
    param(
        [string]$Status,
        [string]$Message
    )
    
    switch ($Status) {
        "INFO" {
            [System.Console]::ForegroundColor = $Blue
            Write-Host "ℹ $Message"
        }
        "SUCCESS" {
            [System.Console]::ForegroundColor = $Green
            Write-Host "✓ $Message"
        }
        "WARNING" {
            [System.Console]::ForegroundColor = $Yellow
            Write-Host "⚠ $Message"
        }
        "ERROR" {
            [System.Console]::ForegroundColor = $Red
            Write-Host "✗ $Message"
        }
    }
    [System.Console]::ForegroundColor = $DefaultColor
}

function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Install-RustTools {
    if ($SkipToolInstall) {
        Write-Status "INFO" "Skipping tool installation as requested"
        return
    }
    
    Write-Status "INFO" "Installing Rust-based quality tools..."
    
    $tools = @(
        "dprint",
        "typos-cli",
        "cargo-audit",
        "cargo-nextest",
        "cargo-tarpaulin",
        "tokei",
        "ripgrep",
        "fd-find",
        "bat",
        "hyperfine",
        "watchexec-cli",
        "cargo-deny",
        "cargo-semver-checks"
    )
    
    foreach ($tool in $tools) {
        $commandName = $tool -replace "-cli", ""
        if (-not (Test-Command $commandName)) {
            Write-Status "INFO" "Installing $tool..."
            try {
                & cargo install $tool 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Status "SUCCESS" "Installed $tool"
                } else {
                    Write-Status "WARNING" "Failed to install $tool - continuing anyway"
                }
            }
            catch {
                Write-Status "WARNING" "Failed to install $tool - continuing anyway"
            }
        } else {
            Write-Status "SUCCESS" "$tool already installed"
        }
    }
}

function Setup-PreCommit {
    Write-Status "INFO" "Setting up pre-commit hooks..."
    
    if (-not (Test-Command "pre-commit")) {
        Write-Status "INFO" "Installing pre-commit..."
        try {
            if (Test-Command "pip") {
                & pip install pre-commit 2>&1 | Out-Null
            } elseif (Test-Command "pip3") {
                & pip3 install pre-commit 2>&1 | Out-Null
            } else {
                Write-Status "ERROR" "pip not found - please install pre-commit manually"
                return $false
            }
        }
        catch {
            Write-Status "ERROR" "Failed to install pre-commit"
            return $false
        }
    }
    
    # Install pre-commit hooks
    try {
        & pre-commit install 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Status "SUCCESS" "Pre-commit hooks installed"
        } else {
            Write-Status "ERROR" "Failed to install pre-commit hooks"
            return $false
        }
    }
    catch {
        Write-Status "ERROR" "Failed to install pre-commit hooks"
        return $false
    }
    
    # Install pre-push hooks
    try {
        & pre-commit install --hook-type pre-push 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Status "SUCCESS" "Pre-push hooks installed"
        } else {
            Write-Status "WARNING" "Failed to install pre-push hooks"
        }
    }
    catch {
        Write-Status "WARNING" "Failed to install pre-push hooks"
    }
    
    return $true
}

function Create-ConfigFiles {
    Write-Status "INFO" "Creating quality configuration files..."
    
    # Create dprint configuration if it doesn't exist
    if (-not (Test-Path "dprint.json")) {
        $dprintConfig = @'
{
  "typescript": {
    "lineWidth": 120,
    "indentWidth": 2,
    "useTabs": false,
    "semiColons": "always",
    "quoteStyle": "alwaysDouble",
    "newLineKind": "lf"
  },
  "json": {
    "lineWidth": 120,
    "indentWidth": 2,
    "useTabs": false
  },
  "markdown": {
    "lineWidth": 120,
    "textWrap": "maintain"
  },
  "toml": {},
  "includes": [
    "**/*.{ts,tsx,js,jsx,json,md,toml,yml,yaml}"
  ],
  "excludes": [
    "target/**",
    "node_modules/**",
    "dist/**",
    "build/**",
    ".git/**"
  ],
  "plugins": [
    "https://plugins.dprint.dev/typescript-0.88.1.wasm",
    "https://plugins.dprint.dev/json-0.17.4.wasm",
    "https://plugins.dprint.dev/markdown-0.16.4.wasm",
    "https://plugins.dprint.dev/toml-0.6.0.wasm"
  ]
}
'@
        Set-Content -Path "dprint.json" -Value $dprintConfig -Encoding UTF8
        Write-Status "SUCCESS" "Created dprint.json configuration"
    }
    
    # Create typos configuration if it doesn't exist
    if (-not (Test-Path "_typos.toml")) {
        $typosConfig = @'
[default]
extend-ignore-identifiers-re = [
    "clippy",
    "rustc",
    "nextest",
    "tokei",
    "dprint",
    "watchexec",
    "ripgrep",
    "hyperfine"
]

[default.extend-words]
# Add project-specific words that should not be flagged as typos
buckconfig = "buckconfig"
buckroot = "buckroot"
runbooks = "runbooks"
codegen = "codegen"

[files]
extend-exclude = [
    "target/",
    "node_modules/",
    "dist/",
    "build/",
    ".git/",
    "*.lock"
]
'@
        Set-Content -Path "_typos.toml" -Value $typosConfig -Encoding UTF8
        Write-Status "SUCCESS" "Created _typos.toml configuration"
    }
    
    # Create cargo-deny configuration if it doesn't exist
    if (-not (Test-Path "deny.toml")) {
        $denyConfig = @'
[graph]
targets = [
    { triple = "x86_64-unknown-linux-gnu" },
    { triple = "x86_64-pc-windows-msvc" },
    { triple = "x86_64-apple-darwin" },
]

[advisories]
db-path = "~/.cargo/advisory-db"
db-urls = ["https://github.com/rustsec/advisory-db"]
vulnerability = "deny"
unmaintained = "warn"
yanked = "warn"
notice = "warn"
ignore = []

[licenses]
unlicensed = "deny"
allow = [
    "MIT",
    "Apache-2.0",
    "Apache-2.0 WITH LLVM-exception",
    "BSD-2-Clause",
    "BSD-3-Clause",
    "ISC",
    "Unicode-DFS-2016",
]
deny = [
    "GPL-2.0",
    "GPL-3.0",
    "AGPL-1.0",
    "AGPL-3.0",
]
copyleft = "warn"
allow-osi-fsf-free = "neither"
default = "deny"
confidence-threshold = 0.8

[bans]
multiple-versions = "warn"
wildcards = "allow"
highlight = "all"
workspace-default-features = "allow"
external-default-features = "allow"
allow = []
deny = []
skip = []
skip-tree = []

[sources]
unknown-registry = "warn"
unknown-git = "warn"
allow-registry = ["https://github.com/rust-lang/crates.io-index"]
allow-git = []
'@
        Set-Content -Path "deny.toml" -Value $denyConfig -Encoding UTF8
        Write-Status "SUCCESS" "Created deny.toml configuration"
    }
}

function Setup-GitHooks {
    Write-Status "INFO" "Setting up additional git hooks..."
    
    # Create commit-msg hook for conventional commits
    $hookPath = ".git/hooks/commit-msg"
    if (-not (Test-Path $hookPath)) {
        $commitMsgHook = @'
#!/bin/bash
# Conventional commit message validation

commit_regex='^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\(.+\))?: .{1,50}'

if ! grep -qE "$commit_regex" "$1"; then
    echo "Invalid commit message format!"
    echo "Format: type(scope): description"
    echo "Types: feat, fix, docs, style, refactor, test, chore, perf, ci, build, revert"
    echo "Example: feat(auth): add user authentication"
    exit 1
fi
'@
        Set-Content -Path $hookPath -Value $commitMsgHook -Encoding UTF8
        Write-Status "SUCCESS" "Created commit-msg hook for conventional commits"
    }
}

function Test-Setup {
    Write-Status "INFO" "Testing quality enforcement setup..."
    
    # Test pre-commit
    if (Test-Command "pre-commit") {
        try {
            & pre-commit run --all-files 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Status "SUCCESS" "Pre-commit hooks working correctly"
            } else {
                Write-Status "WARNING" "Pre-commit hooks found issues - this is normal for initial setup"
            }
        }
        catch {
            Write-Status "WARNING" "Pre-commit hooks found issues - this is normal for initial setup"
        }
    }
    
    # Test quality gates script
    if (Test-Path "scripts/quality/quality-gates.ps1") {
        try {
            & powershell -File "scripts/quality/quality-gates.ps1" 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Status "SUCCESS" "Quality gates script working correctly"
            } else {
                Write-Status "WARNING" "Quality gates found issues - review and fix as needed"
            }
        }
        catch {
            Write-Status "WARNING" "Quality gates found issues - review and fix as needed"
        }
    }
}

# Main execution
Write-Status "INFO" "Starting code quality enforcement setup..."

# Check if we're in a git repository
try {
    git rev-parse --git-dir | Out-Null
}
catch {
    Write-Status "ERROR" "Not in a git repository"
    exit 1
}

# Install Rust-based tools
Install-RustTools

# Setup pre-commit
if (-not (Setup-PreCommit)) {
    Write-Status "ERROR" "Failed to setup pre-commit - aborting"
    exit 1
}

# Create configuration files
Create-ConfigFiles

# Setup git hooks
Setup-GitHooks

# Test the setup
Test-Setup

Write-Status "SUCCESS" "Code quality enforcement system setup complete!"

Write-Host ""
Write-Host "📋 Next steps:" -ForegroundColor Cyan
Write-Host "  1. Review and customize configuration files as needed"
Write-Host "  2. Run 'pre-commit run --all-files' to check existing code"
Write-Host "  3. Run 'scripts/quality/quality-gates.ps1' to test quality gates"
Write-Host "  4. Commit changes to activate the hooks"
Write-Host ""
Write-Host "🔧 Available commands:" -ForegroundColor Cyan
Write-Host "  - pre-commit run --all-files    # Run all hooks on all files"
Write-Host "  - scripts/quality/quality-gates.ps1    # Run quality gate checks"
Write-Host "  - scripts/quality/compatibility-check.ps1    # Check backward compatibility"
Write-Host "  - scripts/quality/doc-validation.ps1    # Validate documentation"
Write-Host "  - scripts/quality/code-review-assistant.ps1    # Get automated code review"