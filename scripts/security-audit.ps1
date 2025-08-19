# Security audit script using cargo-audit (PowerShell version)

param(
    [switch]$UpdateDb = $true,
    [switch]$Verbose = $false
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$ConfigFile = Join-Path $RepoRoot "config\audit.toml"

Write-Host "Running security audit with cargo-audit..." -ForegroundColor Green

# Check if cargo-audit is installed
try {
    cargo audit --version | Out-Null
} catch {
    Write-Host "cargo-audit not found. Installing..." -ForegroundColor Yellow
    cargo install cargo-audit --features=fix
}

# Update advisory database
if ($UpdateDb) {
    Write-Host "Updating advisory database..." -ForegroundColor Blue
    cargo audit --config $ConfigFile --db-update
}

# Find all Cargo.toml files
$CargoFiles = Get-ChildItem -Path $RepoRoot -Name "Cargo.toml" -Recurse | Where-Object { $_ -notmatch "target" }

# Run audit on all Rust projects
Write-Host "Running security audit..." -ForegroundColor Blue
foreach ($CargoFile in $CargoFiles) {
    $ProjectDir = Split-Path -Parent (Join-Path $RepoRoot $CargoFile)
    Write-Host "Auditing project: $ProjectDir" -ForegroundColor Cyan
    
    Push-Location $ProjectDir
    try {
        $AuditOutput = cargo audit --config $ConfigFile --json 2>&1
        $AuditOutput | Out-File -FilePath "audit-report.json" -Encoding UTF8
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Security vulnerabilities found in $ProjectDir" -ForegroundColor Red
            cargo audit --config $ConfigFile
            exit 1
        }
    } finally {
        Pop-Location
    }
}

Write-Host "Security audit completed successfully!" -ForegroundColor Green