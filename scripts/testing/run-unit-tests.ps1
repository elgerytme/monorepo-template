# Comprehensive unit testing script using nextest for Windows

param(
    [string]$Profile = "default",
    [switch]$Coverage,
    [switch]$JUnit,
    [switch]$CI,
    [switch]$Help
)

# Configuration
$NextestConfig = "config/nextest.toml"
$CoverageDir = "target/coverage"
$JUnitOutput = "target/nextest-junit.xml"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    
    $colors = @{
        "Red" = "Red"
        "Green" = "Green" 
        "Yellow" = "Yellow"
        "White" = "White"
    }
    
    Write-Host $Message -ForegroundColor $colors[$Color]
}

if ($Help) {
    Write-Host "Usage: .\run-unit-tests.ps1 [OPTIONS]"
    Write-Host "Options:"
    Write-Host "  -Profile PROFILE     Use specific nextest profile (default, ci, coverage, bench)"
    Write-Host "  -Coverage           Generate code coverage report"
    Write-Host "  -JUnit              Generate JUnit XML output"
    Write-Host "  -CI                 Use CI profile with JUnit output"
    Write-Host "  -Help               Show this help message"
    exit 0
}

if ($CI) {
    $Profile = "ci"
    $JUnit = $true
}

Write-ColorOutput "🧪 Running comprehensive unit tests with nextest" "Green"

# Ensure nextest is installed
if (!(Get-Command cargo-nextest -ErrorAction SilentlyContinue)) {
    Write-ColorOutput "Installing cargo-nextest..." "Yellow"
    cargo install cargo-nextest --locked
}

# Create coverage directory
New-Item -ItemType Directory -Force -Path $CoverageDir | Out-Null

# Function to run tests with specific profile
function Invoke-TestsWithProfile {
    param([string]$TestProfile, [string]$Description)
    
    Write-ColorOutput "Running $Description tests..." "Green"
    
    if ($TestProfile -eq "coverage") {
        # Run with coverage collection
        $env:RUSTFLAGS = "-C instrument-coverage"
        $env:LLVM_PROFILE_FILE = "$CoverageDir/nextest-%p-%m.profraw"
        
        cargo nextest run `
            --config-file $NextestConfig `
            --profile $TestProfile `
            --workspace `
            --all-features
    } else {
        cargo nextest run `
            --config-file $NextestConfig `
            --profile $TestProfile `
            --workspace `
            --all-features
    }
    
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "Tests failed with exit code $LASTEXITCODE" "Red"
        exit $LASTEXITCODE
    }
}

# Run tests based on configuration
if ($Coverage) {
    Invoke-TestsWithProfile "coverage" "coverage"
    
    # Generate coverage report
    Write-ColorOutput "Generating coverage report..." "Green"
    
    # Install grcov if not present
    if (!(Get-Command grcov -ErrorAction SilentlyContinue)) {
        Write-ColorOutput "Installing grcov..." "Yellow"
        cargo install grcov
    }
    
    # Generate HTML coverage report
    grcov $CoverageDir `
        --source-dir . `
        --binary-path target/debug/ `
        --output-type html `
        --branch `
        --ignore-not-existing `
        --output-path "$CoverageDir/html"
    
    # Generate lcov format for CI
    grcov $CoverageDir `
        --source-dir . `
        --binary-path target/debug/ `
        --output-type lcov `
        --branch `
        --ignore-not-existing `
        --output-path "$CoverageDir/lcov.info"
    
    Write-ColorOutput "Coverage report generated at $CoverageDir/html/index.html" "Green"
} else {
    Invoke-TestsWithProfile $Profile $Profile
}

# Generate JUnit output if requested
if ($JUnit -and (Test-Path $JUnitOutput)) {
    Write-ColorOutput "JUnit XML report generated at $JUnitOutput" "Green"
}

Write-ColorOutput "✅ Unit tests completed successfully" "Green"