# PowerShell script to run comprehensive tests

param(
    [string]$TestType = "all",
    [switch]$Coverage = $false,
    [switch]$Verbose = $false,
    [string]$Filter = ""
)

Write-Host "🧪 Running comprehensive test suite..." -ForegroundColor Green

# Set environment variables
$env:RUST_LOG = if ($Verbose) { "debug" } else { "info" }
$env:RUST_BACKTRACE = "1"

# Function to run command and check exit code
function Invoke-TestCommand {
    param([string]$Command, [string]$Description)
    
    Write-Host "📋 $Description" -ForegroundColor Cyan
    Write-Host "   Command: $Command" -ForegroundColor Gray
    
    Invoke-Expression $Command
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ $Description failed with exit code $LASTEXITCODE" -ForegroundColor Red
        exit $LASTEXITCODE
    }
    Write-Host "✅ $Description completed successfully" -ForegroundColor Green
    Write-Host ""
}

# Build the project first
Invoke-TestCommand "buck2 build //..." "Building all targets"

# Run different test types based on parameter
switch ($TestType.ToLower()) {
    "unit" {
        Write-Host "🔬 Running unit tests only" -ForegroundColor Yellow
        
        if ($Coverage) {
            Invoke-TestCommand "cargo nextest run --profile ci --workspace --exclude integration-tests" "Unit tests with coverage"
        } else {
            Invoke-TestCommand "cargo nextest run --workspace --exclude integration-tests" "Unit tests"
        }
    }
    
    "integration" {
        Write-Host "🔗 Running integration tests only" -ForegroundColor Yellow
        
        # Start test containers
        Write-Host "🐳 Starting test containers..." -ForegroundColor Cyan
        
        Invoke-TestCommand "buck2 test //examples/testing:integration-tests" "Integration tests"
    }
    
    "performance" {
        Write-Host "⚡ Running performance tests" -ForegroundColor Yellow
        
        Invoke-TestCommand "cargo bench --workspace" "Performance benchmarks"
        Invoke-TestCommand "buck2 test //examples/testing:benchmarks" "Buck2 benchmarks"
    }
    
    "security" {
        Write-Host "🔒 Running security tests" -ForegroundColor Yellow
        
        Invoke-TestCommand "cargo audit" "Dependency vulnerability scan"
        Invoke-TestCommand "cargo clippy --all-targets --all-features -- -W clippy::security" "Security linting"
        
        # Run custom security tests
        Invoke-TestCommand "buck2 test //libs/testing-framework:security-tests" "Custom security tests"
    }
    
    "all" {
        Write-Host "🎯 Running all test types" -ForegroundColor Yellow
        
        # Unit tests
        Write-Host "🔬 Phase 1: Unit Tests" -ForegroundColor Magenta
        if ($Coverage) {
            Invoke-TestCommand "cargo nextest run --profile ci --workspace" "Unit tests with coverage"
        } else {
            Invoke-TestCommand "cargo nextest run --workspace" "Unit tests"
        }
        
        # Integration tests
        Write-Host "🔗 Phase 2: Integration Tests" -ForegroundColor Magenta
        Invoke-TestCommand "buck2 test //examples/testing:integration-tests" "Integration tests"
        
        # Performance tests
        Write-Host "⚡ Phase 3: Performance Tests" -ForegroundColor Magenta
        Invoke-TestCommand "cargo bench --workspace" "Performance benchmarks"
        
        # Security tests
        Write-Host "🔒 Phase 4: Security Tests" -ForegroundColor Magenta
        Invoke-TestCommand "cargo audit" "Dependency vulnerability scan"
        Invoke-TestCommand "cargo clippy --all-targets --all-features -- -W clippy::security" "Security linting"
        
        # Buck2 tests
        Write-Host "🏗️ Phase 5: Buck2 Tests" -ForegroundColor Magenta
        Invoke-TestCommand "buck2 test //..." "All Buck2 tests"
    }
    
    default {
        Write-Host "❌ Unknown test type: $TestType" -ForegroundColor Red
        Write-Host "Valid options: unit, integration, performance, security, all" -ForegroundColor Yellow
        exit 1
    }
}

# Generate test report if coverage was requested
if ($Coverage) {
    Write-Host "📊 Generating test coverage report..." -ForegroundColor Cyan
    
    # Generate HTML coverage report
    if (Test-Path "target/nextest/coverage") {
        Invoke-TestCommand "grcov target/nextest/coverage --binary-path target/debug/ -s . -t html --branch --ignore-not-existing -o target/coverage/" "Coverage report generation"
        Write-Host "📈 Coverage report generated at: target/coverage/index.html" -ForegroundColor Green
    }
}

# Summary
Write-Host "🎉 Test execution completed successfully!" -ForegroundColor Green
Write-Host "📋 Test Summary:" -ForegroundColor Cyan
Write-Host "   - Test Type: $TestType" -ForegroundColor Gray
Write-Host "   - Coverage: $(if ($Coverage) { 'Enabled' } else { 'Disabled' })" -ForegroundColor Gray
Write-Host "   - Verbose: $(if ($Verbose) { 'Enabled' } else { 'Disabled' })" -ForegroundColor Gray

if ($Filter) {
    Write-Host "   - Filter: $Filter" -ForegroundColor Gray
}