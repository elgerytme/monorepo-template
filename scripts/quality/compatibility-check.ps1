# Backward compatibility checking script for Windows
# Ensures that changes don't break existing APIs and interfaces

param(
    [string]$BaseBranch = "origin/main"
)

# Colors for output
$Red = [System.ConsoleColor]::Red
$Green = [System.ConsoleColor]::Green
$Yellow = [System.ConsoleColor]::Yellow
$DefaultColor = [System.Console]::ForegroundColor

function Write-Status {
    param(
        [string]$Status,
        [string]$Message
    )
    
    switch ($Status) {
        "PASS" {
            [System.Console]::ForegroundColor = $Green
            Write-Host "✓ $Message"
        }
        "FAIL" {
            [System.Console]::ForegroundColor = $Red
            Write-Host "✗ $Message"
            [System.Console]::ForegroundColor = $DefaultColor
            return $false
        }
        "WARN" {
            [System.Console]::ForegroundColor = $Yellow
            Write-Host "⚠ $Message"
        }
    }
    [System.Console]::ForegroundColor = $DefaultColor
    return $true
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

Write-Host "🔄 Running backward compatibility checks..." -ForegroundColor Cyan

$Passed = 0
$Failed = 0

# Check if we're in a git repository
try {
    git rev-parse --git-dir | Out-Null
}
catch {
    Write-Status "FAIL" "Not in a git repository"
    exit 1
}

# 1. Check for breaking changes in Rust APIs
Write-Host "🦀 Checking Rust API compatibility..."

if (Test-Command "cargo-semver-checks") {
    try {
        & cargo semver-checks check-release 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            if (Write-Status "PASS" "No breaking changes in Rust APIs") { $Passed++ }
        } else {
            if (-not (Write-Status "FAIL" "Breaking changes detected in Rust APIs")) { $Failed++ }
        }
    }
    catch {
        if (-not (Write-Status "FAIL" "Error running cargo-semver-checks")) { $Failed++ }
    }
} else {
    # Fallback: check for removed public items
    $changedRustFiles = git diff --name-only "$BaseBranch...HEAD" | Where-Object { $_ -match "\.rs$" }
    if ($changedRustFiles) {
        $removedPubs = (git diff "$BaseBranch...HEAD" -- "*.rs" | Select-String "^-.*pub ").Count
        if ($removedPubs -gt 0) {
            if (-not (Write-Status "FAIL" "Potential breaking changes: $removedPubs public items removed")) { $Failed++ }
        } else {
            if (Write-Status "PASS" "No obvious breaking changes in Rust code") { $Passed++ }
        }
    } else {
        if (Write-Status "PASS" "No Rust files changed") { $Passed++ }
    }
}

# 2. Check TypeScript/JavaScript API compatibility
Write-Host "📜 Checking TypeScript/JavaScript API compatibility..."

$changedTsFiles = git diff --name-only "$BaseBranch...HEAD" | Where-Object { $_ -match "\.(ts|tsx|js|jsx)$" }
if ($changedTsFiles) {
    $removedExports = (git diff "$BaseBranch...HEAD" -- "*.ts" "*.tsx" "*.js" "*.jsx" | Select-String "^-.*export ").Count
    if ($removedExports -gt 0) {
        if (-not (Write-Status "FAIL" "Potential breaking changes: $removedExports exports removed")) { $Failed++ }
    } else {
        if (Write-Status "PASS" "No obvious breaking changes in TypeScript/JavaScript") { $Passed++ }
    }
} else {
    if (Write-Status "PASS" "No TypeScript/JavaScript files changed") { $Passed++ }
}

# 3. Check for database schema changes
Write-Host "🗄️ Checking database schema compatibility..."

$dbFiles = git diff --name-only "$BaseBranch...HEAD" | Where-Object { 
    $_ -match "(migration|schema)" -or $_ -match "\.(sql|prisma)$" 
}
if ($dbFiles) {
    $breakingDbChanges = (git diff "$BaseBranch...HEAD" | Select-String "^[+].*DROP|^[+].*ALTER.*DROP" -AllMatches).Count
    if ($breakingDbChanges -gt 0) {
        if (-not (Write-Status "FAIL" "Breaking database changes detected")) { $Failed++ }
    } else {
        if (Write-Status "PASS" "Database changes appear backward compatible") { $Passed++ }
    }
} else {
    if (Write-Status "PASS" "No database schema changes") { $Passed++ }
}

# 4. Check API contract changes
Write-Host "📋 Checking API contract compatibility..."

$apiFiles = git diff --name-only "$BaseBranch...HEAD" | Where-Object { 
    $_ -match "(openapi|swagger|graphql)" -or $_ -match "\.(yaml|yml|json)$" 
}
if ($apiFiles) {
    $removedEndpoints = (git diff "$BaseBranch...HEAD" | Select-String "^-.*/(get|post|put|delete|patch)" -AllMatches).Count
    if ($removedEndpoints -gt 0) {
        if (-not (Write-Status "FAIL" "API endpoints may have been removed")) { $Failed++ }
    } else {
        if (Write-Status "PASS" "No obvious API contract breaking changes") { $Passed++ }
    }
} else {
    if (Write-Status "PASS" "No API contract files changed") { $Passed++ }
}

# 5. Check configuration file changes
Write-Host "⚙️ Checking configuration compatibility..."

$configFiles = git diff --name-only "$BaseBranch...HEAD" | Where-Object { 
    $_ -match "(config|\.env|\.toml|\.yaml|\.yml|\.json)$" 
}
if ($configFiles) {
    $removedConfigKeys = (git diff "$BaseBranch...HEAD" | Select-String "^-\s*[a-zA-Z_].*=" -AllMatches).Count
    if ($removedConfigKeys -gt 0) {
        if (-not (Write-Status "FAIL" "Configuration keys may have been removed: $removedConfigKeys")) { $Failed++ }
    } else {
        if (Write-Status "PASS" "Configuration changes appear backward compatible") { $Passed++ }
    }
} else {
    if (Write-Status "PASS" "No configuration files changed") { $Passed++ }
}

# 6. Check for version bumps in dependencies
Write-Host "📦 Checking dependency version compatibility..."

$depFiles = git diff --name-only "$BaseBranch...HEAD" | Where-Object { 
    $_ -match "(Cargo\.toml|package\.json|requirements\.txt|go\.mod)$" 
}
if ($depFiles) {
    $majorBumps = (git diff "$BaseBranch...HEAD" | Select-String "^[+].*[0-9]+\.[0-9]+\.[0-9]+" -AllMatches).Count
    
    if ($majorBumps -gt 0) {
        Write-Status "WARN" "Dependency versions changed - review for compatibility"
    } else {
        if (Write-Status "PASS" "No major dependency version changes") { $Passed++ }
    }
    $Passed++
} else {
    if (Write-Status "PASS" "No dependency files changed") { $Passed++ }
}

# Summary
Write-Host ""
Write-Host "📋 Compatibility Check Summary:" -ForegroundColor Cyan
Write-Host "  Passed: $Passed" -ForegroundColor Green
Write-Host "  Failed: $Failed" -ForegroundColor $(if ($Failed -eq 0) { $Green } else { $Red })

if ($Failed -eq 0) {
    Write-Host "🎉 All compatibility checks passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ $Failed compatibility check(s) failed. Please review breaking changes." -ForegroundColor Red
    Write-Host ""
    Write-Host "💡 Tips for fixing compatibility issues:" -ForegroundColor Yellow
    Write-Host "  - Use deprecation warnings instead of removing APIs"
    Write-Host "  - Add new fields as optional"
    Write-Host "  - Maintain backward-compatible database migrations"
    Write-Host "  - Version your APIs appropriately"
    exit 1
}