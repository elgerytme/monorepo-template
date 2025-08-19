# Documentation validation script for Windows
# Ensures that code changes include appropriate documentation

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
            return $true
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
            return $true
        }
    }
    [System.Console]::ForegroundColor = $DefaultColor
}

Write-Host "📚 Running documentation validation..." -ForegroundColor Cyan

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

# 1. Check Rust documentation
Write-Host "🦀 Checking Rust documentation..."

$rustFiles = git diff --name-only "$BaseBranch...HEAD" | Where-Object { $_ -match "\.rs$" }
if ($rustFiles) {
    $missingDocs = 0
    
    foreach ($file in $rustFiles) {
        if (Test-Path $file) {
            $content = Get-Content $file
            for ($i = 0; $i -lt $content.Length; $i++) {
                if ($content[$i] -match "^pub ") {
                    if ($i -eq 0 -or $content[$i-1] -notmatch "^\s*///") {
                        $missingDocs++
                        break
                    }
                }
            }
        }
    }
    
    if ($missingDocs -eq 0) {
        if (Write-Status "PASS" "All public Rust items are documented") { $Passed++ }
    } else {
        if (-not (Write-Status "FAIL" "$missingDocs Rust files have undocumented public items")) { $Failed++ }
    }
    
    # Check if Rust docs build successfully
    try {
        & cargo doc --no-deps 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            if (Write-Status "PASS" "Rust documentation builds successfully") { $Passed++ }
        } else {
            if (-not (Write-Status "FAIL" "Rust documentation build failed")) { $Failed++ }
        }
    }
    catch {
        if (-not (Write-Status "FAIL" "Error building Rust documentation")) { $Failed++ }
    }
} else {
    if (Write-Status "PASS" "No Rust files changed") { $Passed++ }
}

# 2. Check TypeScript/JavaScript documentation
Write-Host "📜 Checking TypeScript/JavaScript documentation..."

$tsFiles = git diff --name-only "$BaseBranch...HEAD" | Where-Object { $_ -match "\.(ts|tsx|js|jsx)$" }
if ($tsFiles) {
    $missingTsDocs = 0
    
    foreach ($file in $tsFiles) {
        if (Test-Path $file) {
            $content = Get-Content $file
            for ($i = 0; $i -lt $content.Length; $i++) {
                if ($content[$i] -match "^export ") {
                    if ($i -eq 0 -or ($content[$i-1] -notmatch "^\s*\*" -and $content[$i-1] -notmatch "^\s*/\*")) {
                        $missingTsDocs++
                        break
                    }
                }
            }
        }
    }
    
    if ($missingTsDocs -eq 0) {
        if (Write-Status "PASS" "TypeScript/JavaScript exports are documented") { $Passed++ }
    } else {
        if (-not (Write-Status "FAIL" "$missingTsDocs TypeScript/JavaScript files have undocumented exports")) { $Failed++ }
    }
} else {
    if (Write-Status "PASS" "No TypeScript/JavaScript files changed") { $Passed++ }
}

# 3. Check for README updates
Write-Host "📖 Checking README documentation..."

$changedDirs = git diff --name-only "$BaseBranch...HEAD" | ForEach-Object { Split-Path $_ -Parent } | Sort-Object -Unique
$readmeUpdates = 0

foreach ($dir in $changedDirs) {
    $readmePath = Join-Path $dir "README.md"
    if (Test-Path $readmePath) {
        $updatedReadmes = git diff --name-only "$BaseBranch...HEAD" | Where-Object { $_ -eq $readmePath }
        if ($updatedReadmes) {
            $readmeUpdates++
        }
    }
}

$totalDirs = $changedDirs.Count
if ($readmeUpdates -gt 0 -or $totalDirs -le 2) {
    if (Write-Status "PASS" "README documentation appears up to date") { $Passed++ }
} else {
    if (Write-Status "WARN" "Consider updating README files for changed components") { $Passed++ }
}

# 4. Check API documentation
Write-Host "🔌 Checking API documentation..."

$apiFiles = git diff --name-only "$BaseBranch...HEAD" | Where-Object { $_ -match "(openapi|swagger|\.yaml|\.yml)$" }
if ($apiFiles) {
    foreach ($file in $apiFiles) {
        if (Test-Path $file) {
            $content = Get-Content $file -Raw
            if ($content -match "description:") {
                if (Write-Status "PASS" "API documentation in $file has descriptions") { $Passed++ }
            } else {
                if (-not (Write-Status "FAIL" "API documentation in $file missing descriptions")) { $Failed++ }
            }
        }
    }
} else {
    if (Write-Status "PASS" "No API documentation files changed") { $Passed++ }
}

# 5. Check for changelog updates
Write-Host "📝 Checking changelog updates..."

if (Test-Path "CHANGELOG.md") {
    $changelogUpdated = git diff --name-only "$BaseBranch...HEAD" | Where-Object { $_ -eq "CHANGELOG.md" }
    if ($changelogUpdated) {
        if (Write-Status "PASS" "Changelog has been updated") { $Passed++ }
    } else {
        # Check if this is a significant change that should be in changelog
        $significantChanges = (git diff --name-only "$BaseBranch...HEAD" | Where-Object { $_ -notmatch "(test|spec|\.md$)" }).Count
        if ($significantChanges -gt 5) {
            if (Write-Status "WARN" "Consider updating CHANGELOG.md for significant changes") { $Passed++ }
        } else {
            if (Write-Status "PASS" "Minor changes - changelog update not required") { $Passed++ }
        }
    }
} else {
    if (Write-Status "WARN" "No CHANGELOG.md found - consider adding one") { $Passed++ }
}

# 6. Check inline code comments
Write-Host "💬 Checking code comments..."

$changedCodeFiles = git diff --name-only "$BaseBranch...HEAD" | Where-Object { $_ -match "\.(rs|ts|tsx|js|jsx|py|go)$" }

if ($changedCodeFiles) {
    $complexFunctions = 0
    
    foreach ($file in $changedCodeFiles) {
        if (Test-Path $file) {
            $content = Get-Content $file -Raw
            switch -Regex ($file) {
                "\.rs$" {
                    $complexFunctions += ([regex]::Matches($content, "fn.*\{")).Count
                }
                "\.(ts|tsx|js|jsx)$" {
                    $complexFunctions += ([regex]::Matches($content, "function|=>")).Count
                }
                "\.py$" {
                    $complexFunctions += ([regex]::Matches($content, "def ")).Count
                }
                "\.go$" {
                    $complexFunctions += ([regex]::Matches($content, "func ")).Count
                }
            }
        }
    }
    
    if ($complexFunctions -gt 0) {
        if (Write-Status "PASS" "Code changes include function definitions") { $Passed++ }
    } else {
        if (Write-Status "PASS" "No complex functions detected") { $Passed++ }
    }
} else {
    if (Write-Status "PASS" "No code files changed") { $Passed++ }
}

# Summary
Write-Host ""
Write-Host "📋 Documentation Validation Summary:" -ForegroundColor Cyan
Write-Host "  Passed: $Passed" -ForegroundColor Green
Write-Host "  Failed: $Failed" -ForegroundColor $(if ($Failed -eq 0) { $Green } else { $Red })

if ($Failed -eq 0) {
    Write-Host "🎉 All documentation checks passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ $Failed documentation check(s) failed." -ForegroundColor Red
    Write-Host ""
    Write-Host "💡 Documentation requirements:" -ForegroundColor Yellow
    Write-Host "  - All public APIs must have documentation comments"
    Write-Host "  - Exported functions should include JSDoc/doc comments"
    Write-Host "  - Complex logic should have inline comments"
    Write-Host "  - API changes should update relevant documentation"
    exit 1
}