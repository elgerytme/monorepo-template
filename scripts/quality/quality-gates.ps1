# Quality gates validation script for Windows
# Runs comprehensive checks to ensure code meets quality standards

param(
    [int]$MinCoverage = 80,
    [int]$MaxComplexity = 10,
    [int]$MaxFunctionLength = 50
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
            throw "Quality gate failed: $Message"
        }
        "WARN" {
            [System.Console]::ForegroundColor = $Yellow
            Write-Host "⚠ $Message"
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

Write-Host "🔍 Running quality gate checks..." -ForegroundColor Cyan

$Passed = 0
$Failed = 0

try {
    # 1. Code formatting check
    Write-Host "📝 Checking code formatting..."
    
    $formatResult = & cargo fmt --check 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Status "PASS" "Rust code formatting"
        $Passed++
    } else {
        Write-Status "FAIL" "Rust code formatting - run 'cargo fmt' to fix"
        $Failed++
    }

    if (Test-Command "dprint") {
        $dprintResult = & dprint check 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Status "PASS" "Multi-language formatting"
            $Passed++
        } else {
            Write-Status "FAIL" "Multi-language formatting - run 'dprint fmt' to fix"
            $Failed++
        }
    }

    # 2. Linting checks
    Write-Host "🔍 Running linting checks..."
    
    $clippyResult = & cargo clippy --all-targets --all-features -- -D warnings 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Status "PASS" "Rust linting (clippy)"
        $Passed++
    } else {
        Write-Status "FAIL" "Rust linting - fix clippy warnings"
        $Failed++
    }

    # 3. Security checks
    Write-Host "🔒 Running security checks..."
    
    if (Test-Command "cargo-audit") {
        $auditResult = & cargo audit 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Status "PASS" "Security audit"
            $Passed++
        } else {
            Write-Status "FAIL" "Security vulnerabilities found"
            $Failed++
        }
    }

    # 4. Test execution
    Write-Host "📊 Running tests..."
    
    if (Test-Command "cargo-nextest") {
        $testResult = & cargo nextest run 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Status "PASS" "All tests passing"
            $Passed++
        } else {
            Write-Status "FAIL" "Some tests are failing"
            $Failed++
        }
    } else {
        $testResult = & cargo test 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Status "PASS" "All tests passing"
            $Passed++
        } else {
            Write-Status "FAIL" "Some tests are failing"
            $Failed++
        }
    }

    # 5. Documentation check
    Write-Host "📚 Checking documentation..."
    
    $docResult = & cargo doc --no-deps 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Status "PASS" "Documentation builds successfully"
        $Passed++
    } else {
        Write-Status "FAIL" "Documentation build failed"
        $Failed++
    }

    # 6. Buck2 build validation
    Write-Host "🏗️ Validating Buck2 configuration..."
    
    if (Test-Command "buck2") {
        $buck2Result = & buck2 audit 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Status "PASS" "Buck2 configuration valid"
            $Passed++
        } else {
            Write-Status "FAIL" "Buck2 configuration issues found"
            $Failed++
        }
    }

    # Summary
    Write-Host ""
    Write-Host "📋 Quality Gate Summary:" -ForegroundColor Cyan
    Write-Host "  Passed: $Passed" -ForegroundColor Green
    Write-Host "  Failed: $Failed" -ForegroundColor $(if ($Failed -eq 0) { $Green } else { $Red })

    if ($Failed -eq 0) {
        Write-Host "🎉 All quality gates passed!" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "❌ $Failed quality gate(s) failed. Please fix the issues before proceeding." -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "❌ Quality gate execution failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}