# Security policy enforcement automation
# This script enforces security policies across the codebase

param(
    [switch]$CreateDefaultPolicy = $false,
    [switch]$Verbose = $false
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent (Split-Path -Parent $ScriptDir)

Write-Host "🛡️  Starting security policy enforcement..." -ForegroundColor Cyan

# Configuration
$PolicyConfig = Join-Path $RootDir ".security-policy.toml"
$ViolationsFound = 0

# Function to create default security policy configuration
function New-DefaultPolicy {
    $PolicyContent = @'
# Security Policy Configuration

[general]
# Maximum allowed severity level for vulnerabilities
max_vulnerability_severity = "MEDIUM"
# Block commits with secrets
block_secrets = true
# Require security review for certain file types
require_security_review = [".env*", "*.key", "*.pem", "*.p12", "*.pfx"]

[dependencies]
# Allowed licenses for dependencies
allowed_licenses = [
    "MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", 
    "ISC", "MPL-2.0", "LGPL-2.1", "LGPL-3.0"
]
# Blocked packages (known security issues)
blocked_packages = []
# Maximum age for dependencies (days)
max_dependency_age = 365

[containers]
# Allowed base images
allowed_base_images = [
    "alpine:*", "ubuntu:*", "debian:*", "scratch",
    "gcr.io/distroless/*", "chainguard/*"
]
# Blocked base images (known vulnerabilities)
blocked_base_images = [
    "*:latest"  # Discourage latest tag
]
# Required security practices
require_non_root_user = true
require_health_check = true

[code]
# File patterns that require security review
security_sensitive_patterns = [
    "password", "secret", "token", "key", "auth",
    "crypto", "hash", "encrypt", "decrypt"
]
# Blocked functions/patterns
blocked_patterns = [
    "eval\\(", "exec\\(", "system\\(", "shell_exec\\(",
    "md5\\(", "sha1\\("  # Weak hashing
]

[network]
# Allowed outbound connections
allowed_domains = []
# Blocked domains
blocked_domains = []
# Require HTTPS for external connections
require_https = true
'@
    
    Set-Content -Path $PolicyConfig -Value $PolicyContent -Encoding UTF8
}

# Function to check dependency licenses
function Test-DependencyLicenses {
    Write-Host "📋 Checking dependency licenses..." -ForegroundColor Blue
    
    $Violations = 0
    
    # Check Rust dependencies
    try {
        cargo-license --version | Out-Null
    } catch {
        cargo install cargo-license
    }
    
    $CargoFiles = Get-ChildItem -Path $RootDir -Name "Cargo.toml" -Recurse | Where-Object { $_ -notmatch "target" }
    
    foreach ($cargoFile in $CargoFiles) {
        $ProjectDir = Split-Path -Parent (Join-Path $RootDir $cargoFile)
        $ProjectName = Split-Path -Leaf $ProjectDir
        
        Push-Location $ProjectDir
        
        try {
            $LicenseOutput = cargo license --json 2>$null | ConvertFrom-Json
            
            # Check for disallowed licenses
            $DisallowedLicenses = $LicenseOutput | Where-Object { 
                $_.license -match "GPL-3.0|AGPL|SSPL|Commons Clause" -and 
                $_.license -notmatch "MIT|Apache|BSD" 
            }
            
            if ($DisallowedLicenses) {
                Write-Host "❌ Disallowed licenses found in $ProjectName:" -ForegroundColor Red
                foreach ($pkg in $DisallowedLicenses) {
                    Write-Host "  - $($pkg.name): $($pkg.license)" -ForegroundColor Red
                }
                $Violations++
            }
        } catch {
            # Ignore errors for non-Rust projects
        }
        
        Pop-Location
    }
    
    return $Violations -eq 0
}

# Function to check for blocked patterns in code
function Test-BlockedPatterns {
    Write-Host "🔍 Checking for blocked code patterns..." -ForegroundColor Blue
    
    $Violations = 0
    
    # Define blocked patterns
    $Patterns = @(
        "eval\(",
        "exec\(",
        "system\(",
        "shell_exec\(",
        "md5\(",
        "sha1\(",
        "password.*=.*['""][^'""]{1,8}['""]",  # Weak passwords
        "secret.*=.*['""][^'""]{1,12}['""]"    # Hardcoded secrets
    )
    
    foreach ($pattern in $Patterns) {
        Write-Host "Checking pattern: $pattern" -ForegroundColor Gray
        
        # Search for pattern in source files
        $Matches = Select-String -Path "$RootDir\*" -Pattern $pattern -Include "*.rs", "*.js", "*.ts", "*.py", "*.go" -Recurse -Exclude "target", "node_modules", ".git"
        
        if ($Matches) {
            Write-Host "❌ Blocked pattern found: $pattern" -ForegroundColor Red
            $Matches | Select-Object -First 5 | ForEach-Object {
                Write-Host "  $($_.Filename):$($_.LineNumber): $($_.Line.Trim())" -ForegroundColor Red
            }
            $Violations++
        }
    }
    
    return $Violations -eq 0
}

# Function to check container security policies
function Test-ContainerPolicies {
    Write-Host "🐳 Checking container security policies..." -ForegroundColor Blue
    
    $Violations = 0
    
    # Check Dockerfiles
    $Dockerfiles = Get-ChildItem -Path $RootDir -Name "Dockerfile*" -Recurse | Where-Object { $_ -notmatch "node_modules|target" }
    
    foreach ($dockerfile in $Dockerfiles) {
        $DockerfilePath = Join-Path $RootDir $dockerfile
        $DockerfileName = "$(Split-Path -Parent $DockerfilePath | Split-Path -Leaf)/$(Split-Path -Leaf $DockerfilePath)"
        
        Write-Host "Checking Dockerfile: $DockerfileName" -ForegroundColor Gray
        
        $Content = Get-Content $DockerfilePath -Raw
        
        # Check for latest tag usage
        if ($Content -match "FROM.*:latest") {
            Write-Host "❌ Using 'latest' tag in $DockerfileName" -ForegroundColor Red
            $Violations++
        }
        
        # Check for root user
        if ($Content -notmatch "USER [^r]" -and $Content -notmatch "USER [0-9]") {
            Write-Host "⚠️  No non-root user specified in $DockerfileName" -ForegroundColor Yellow
        }
        
        # Check for health check
        if ($Content -notmatch "HEALTHCHECK") {
            Write-Host "⚠️  No health check specified in $DockerfileName" -ForegroundColor Yellow
        }
        
        # Check for secrets in build args
        if ($Content -match "(?i)(password|secret|token|key).*=") {
            Write-Host "❌ Potential secrets in build args in $DockerfileName" -ForegroundColor Red
            $Violations++
        }
    }
    
    return $Violations -eq 0
}

# Function to check file security
function Test-FileSecurity {
    Write-Host "📁 Checking file security..." -ForegroundColor Blue
    
    $Violations = 0
    
    # Check for sensitive files that shouldn't be committed
    $SensitivePatterns = @("*.key", "*.pem", "*.p12", "*.pfx", "*.jks", ".env", ".env.*", "*.env", "id_rsa", "id_dsa", "id_ecdsa", "id_ed25519", "*.sql", "*.dump")
    
    foreach ($pattern in $SensitivePatterns) {
        $SensitiveFiles = Get-ChildItem -Path $RootDir -Name $pattern -Recurse | Where-Object { $_ -notmatch "\.git|target|node_modules" }
        
        if ($SensitiveFiles) {
            Write-Host "❌ Sensitive files found matching pattern: $pattern" -ForegroundColor Red
            $SensitiveFiles | Select-Object -First 5 | ForEach-Object {
                Write-Host "  $_" -ForegroundColor Red
            }
            $Violations++
        }
    }
    
    return $Violations -eq 0
}

# Function to check network security configurations
function Test-NetworkSecurity {
    Write-Host "🌐 Checking network security configurations..." -ForegroundColor Blue
    
    $Violations = 0
    
    # Check for HTTP URLs in configuration files
    $HttpUrls = Select-String -Path "$RootDir\*" -Pattern "http://[^/]" -Include "*.toml", "*.yaml", "*.yml", "*.json" -Recurse -Exclude "target", "node_modules", ".git"
    
    if ($HttpUrls) {
        Write-Host "⚠️  HTTP URLs found (consider using HTTPS):" -ForegroundColor Yellow
        $HttpUrls | Select-Object -First 5 | ForEach-Object {
            Write-Host "  $($_.Filename):$($_.LineNumber): $($_.Line.Trim())" -ForegroundColor Yellow
        }
    }
    
    # Check for hardcoded IP addresses
    $IpAddresses = Select-String -Path "$RootDir\*" -Pattern "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" -Include "*.rs", "*.js", "*.ts", "*.py", "*.go" -Recurse -Exclude "target", "node_modules", ".git"
    
    if ($IpAddresses) {
        # Filter out common non-sensitive IPs
        $SuspiciousIps = $IpAddresses | Where-Object { 
            $_.Line -notmatch "(127\.0\.0\.1|0\.0\.0\.0|255\.255\.255\.255|192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)" 
        }
        
        if ($SuspiciousIps) {
            Write-Host "⚠️  Hardcoded IP addresses found:" -ForegroundColor Yellow
            $SuspiciousIps | Select-Object -First 5 | ForEach-Object {
                Write-Host "  $($_.Filename):$($_.LineNumber): $($_.Line.Trim())" -ForegroundColor Yellow
            }
        }
    }
    
    return $Violations -eq 0
}

# Function to generate security policy report
function Write-PolicyReport {
    param([int]$TotalViolations)
    
    Write-Host ""
    Write-Host "📊 Security Policy Enforcement Summary" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "Total policy violations: $TotalViolations" -ForegroundColor Cyan
    
    if ($TotalViolations -eq 0) {
        Write-Host "✅ All security policies are compliant" -ForegroundColor Green
        Write-Host "Your codebase follows security best practices!" -ForegroundColor Green
    } else {
        Write-Host "❌ Security policy violations detected!" -ForegroundColor Red
        Write-Host ""
        Write-Host "🔧 Remediation steps:" -ForegroundColor Yellow
        Write-Host "1. Review and fix all identified violations"
        Write-Host "2. Update dependencies to secure versions"
        Write-Host "3. Remove or secure sensitive files"
        Write-Host "4. Follow container security best practices"
        Write-Host "5. Use secure coding patterns"
        Write-Host "6. Configure proper network security"
    }
}

# Create default policy if it doesn't exist or if requested
if (-not (Test-Path $PolicyConfig) -or $CreateDefaultPolicy) {
    Write-Host "📝 Creating default security policy configuration..." -ForegroundColor Cyan
    New-DefaultPolicy
}

# Run all security policy checks
Write-Host "🔍 Running security policy checks..." -ForegroundColor Cyan

# Check dependency licenses
if (-not (Test-DependencyLicenses)) {
    $ViolationsFound++
}

# Check for blocked code patterns
if (-not (Test-BlockedPatterns)) {
    $ViolationsFound++
}

# Check container security policies
if (-not (Test-ContainerPolicies)) {
    $ViolationsFound++
}

# Check file security
if (-not (Test-FileSecurity)) {
    $ViolationsFound++
}

# Check network security
if (-not (Test-NetworkSecurity)) {
    $ViolationsFound++
}

# Generate final report
Write-PolicyReport $ViolationsFound

# Exit with error code if violations found
if ($ViolationsFound -gt 0) {
    exit 1
}

Write-Host "🎉 Security policy enforcement completed successfully" -ForegroundColor Green