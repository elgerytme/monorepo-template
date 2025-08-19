# Secret detection and prevention system
# This script scans for secrets in code and prevents them from being committed

param(
    [switch]$SkipGitHistory = $false,
    [switch]$Verbose = $false
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent (Split-Path -Parent $ScriptDir)

Write-Host "🔐 Starting secret detection scan..." -ForegroundColor Cyan

# Check if gitleaks is installed
try {
    gitleaks version | Out-Null
} catch {
    Write-Host "Installing gitleaks..." -ForegroundColor Yellow
    
    # Download and install gitleaks for Windows
    $LatestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/gitleaks/gitleaks/releases/latest"
    $DownloadUrl = ($LatestRelease.assets | Where-Object { $_.name -like "*windows*x64*" }).browser_download_url
    
    $TempPath = "$env:TEMP\gitleaks.zip"
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $TempPath
    
    Expand-Archive -Path $TempPath -DestinationPath "$env:TEMP\gitleaks" -Force
    $GitleaksExe = Get-ChildItem -Path "$env:TEMP\gitleaks" -Name "gitleaks.exe" -Recurse | Select-Object -First 1
    
    $InstallPath = "$env:LOCALAPPDATA\gitleaks"
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    Copy-Item -Path "$env:TEMP\gitleaks\$GitleaksExe" -Destination "$InstallPath\gitleaks.exe" -Force
    
    # Add to PATH if not already there
    $CurrentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($CurrentPath -notlike "*$InstallPath*") {
        [Environment]::SetEnvironmentVariable("PATH", "$CurrentPath;$InstallPath", "User")
        $env:PATH += ";$InstallPath"
    }
    
    Remove-Item -Path $TempPath -Force
    Remove-Item -Path "$env:TEMP\gitleaks" -Recurse -Force
}

# Create gitleaks configuration if it doesn't exist
$GitleaksConfig = Join-Path $RootDir ".gitleaks.toml"
if (-not (Test-Path $GitleaksConfig)) {
    Write-Host "📝 Creating gitleaks configuration..." -ForegroundColor Cyan
    
    $ConfigContent = @'
title = "Gitleaks Configuration"

[extend]
# Extend default rules
useDefault = true

[[rules]]
description = "AWS Access Key ID"
id = "aws-access-key-id"
regex = '''AKIA[0-9A-Z]{16}'''
tags = ["key", "AWS"]

[[rules]]
description = "AWS Secret Access Key"
id = "aws-secret-access-key"
regex = '''[A-Za-z0-9/+=]{40}'''
tags = ["key", "AWS"]

[[rules]]
description = "GitHub Personal Access Token"
id = "github-pat"
regex = '''ghp_[0-9a-zA-Z]{36}'''
tags = ["key", "GitHub"]

[[rules]]
description = "GitHub OAuth Access Token"
id = "github-oauth"
regex = '''gho_[0-9a-zA-Z]{36}'''
tags = ["key", "GitHub"]

[[rules]]
description = "GitHub App Token"
id = "github-app-token"
regex = '''(ghu|ghs)_[0-9a-zA-Z]{36}'''
tags = ["key", "GitHub"]

[[rules]]
description = "GitHub Refresh Token"
id = "github-refresh-token"
regex = '''ghr_[0-9a-zA-Z]{76}'''
tags = ["key", "GitHub"]

[[rules]]
description = "Slack Token"
id = "slack-access-token"
regex = '''xox[baprs]-([0-9a-zA-Z]{10,48})?'''
tags = ["key", "Slack"]

[[rules]]
description = "Private Key"
id = "private-key"
regex = '''-----BEGIN[ A-Z]*PRIVATE KEY-----'''
tags = ["key", "private"]

[[rules]]
description = "Generic API Key"
id = "generic-api-key"
regex = '''(?i)(api[_-]?key|apikey|secret[_-]?key|secretkey)['"]*\s*[:=]\s*['"][0-9a-zA-Z\-_]{16,}['"]'''
tags = ["key", "API"]

# Allowlist for test files and documentation
[allowlist]
description = "Allowlisted files"
files = [
    '''\.md$''',
    '''\.txt$''',
    '''test.*\.rs$''',
    '''.*_test\.go$''',
    '''.*\.test\.ts$''',
    '''.*\.spec\.ts$''',
    '''examples/.*''',
    '''docs/.*''',
]

# Allowlist for specific patterns that are not secrets
paths = [
    '''gitleaks\.toml''',
    '''\.gitleaks\.toml''',
]

# Allowlist for test/example values
regexes = [
    '''(example|test|fake|dummy|placeholder)''',
    '''your[_-]?(api[_-]?key|token|secret)''',
    '''<[A-Z_]+>''',
    '''\$\{[A-Z_]+\}''',
    '''AKIA00000000000000000000''',
    '''ghp_0000000000000000000000000000000000000000''',
]
'@
    
    Set-Content -Path $GitleaksConfig -Value $ConfigContent -Encoding UTF8
}

# Function to scan for secrets
function Scan-Secrets {
    param(
        [string]$ScanType,
        [string]$AdditionalArgs
    )
    
    Write-Host "🔍 Running $ScanType scan..." -ForegroundColor Cyan
    
    Set-Location $RootDir
    
    $ReportPath = "$env:TEMP\gitleaks-report.json"
    
    # Run gitleaks with specified arguments
    $GitleaksArgs = @("detect", "--config=$GitleaksConfig", "--report-format=json", "--report-path=$ReportPath")
    if ($AdditionalArgs) {
        $GitleaksArgs += $AdditionalArgs.Split(' ')
    }
    
    try {
        & gitleaks @GitleaksArgs 2>$null
        Write-Host "✅ No secrets found in $ScanType" -ForegroundColor Green
        return $false
    } catch {
        Write-Host "❌ Secrets detected in $ScanType!" -ForegroundColor Red
        
        # Parse and display results
        if (Test-Path $ReportPath) {
            Write-Host ""
            Write-Host "🚨 Secret Detection Results:" -ForegroundColor Red
            Write-Host "============================" -ForegroundColor Red
            
            try {
                $Results = Get-Content $ReportPath | ConvertFrom-Json
                foreach ($result in $Results) {
                    Write-Host "File: $($result.File)" -ForegroundColor Yellow
                    Write-Host "Line: $($result.StartLine)" -ForegroundColor Yellow
                    Write-Host "Rule: $($result.RuleID)" -ForegroundColor Yellow
                    Write-Host "Description: $($result.Description)" -ForegroundColor Yellow
                    Write-Host "Match: $($result.Match)" -ForegroundColor Red
                    Write-Host "---" -ForegroundColor Gray
                }
            } catch {
                Get-Content $ReportPath
            }
            
            Write-Host ""
            Write-Host "🔧 Remediation steps:" -ForegroundColor Yellow
            Write-Host "1. Remove or replace the detected secrets"
            Write-Host "2. Use environment variables or secure secret management"
            Write-Host "3. Add legitimate test values to the allowlist if needed"
            Write-Host "4. Rotate any exposed secrets immediately"
        }
        
        return $true
    }
}

# Initialize results
$SecretsFound = $false

# Scan current working directory (uncommitted changes)
Write-Host "📁 Scanning working directory for secrets..." -ForegroundColor Cyan
if (Scan-Secrets "working directory" "--no-git") {
    $SecretsFound = $true
}

# Scan git history if we're in a git repository and not skipping
if ((Test-Path (Join-Path $RootDir ".git")) -and -not $SkipGitHistory) {
    Write-Host "📚 Scanning git history for secrets..." -ForegroundColor Cyan
    if (Scan-Secrets "git history" "") {
        $SecretsFound = $true
    }
}

# Create pre-commit hook if it doesn't exist
$HooksDir = Join-Path $RootDir ".git\hooks"
$PreCommitHook = Join-Path $HooksDir "pre-commit"

if ((Test-Path $HooksDir) -and -not (Test-Path $PreCommitHook)) {
    Write-Host "🪝 Installing pre-commit hook for secret detection..." -ForegroundColor Cyan
    
    $HookContent = @'
#!/bin/bash
# Pre-commit hook for secret detection

echo "🔐 Checking for secrets before commit..."

# Run gitleaks on staged files
if ! gitleaks protect --staged --config=.gitleaks.toml; then
    echo "❌ Secrets detected! Commit blocked."
    echo "Please remove secrets and try again."
    exit 1
fi

echo "✅ No secrets detected. Proceeding with commit."
'@
    
    Set-Content -Path $PreCommitHook -Value $HookContent -Encoding UTF8
    Write-Host "✅ Pre-commit hook installed" -ForegroundColor Green
}

# Clean up temporary files
$ReportPath = "$env:TEMP\gitleaks-report.json"
if (Test-Path $ReportPath) {
    Remove-Item $ReportPath -Force
}

# Generate summary
Write-Host ""
Write-Host "📊 Secret Detection Summary" -ForegroundColor Cyan
Write-Host "===========================" -ForegroundColor Cyan

if (-not $SecretsFound) {
    Write-Host "✅ No secrets detected across all scans" -ForegroundColor Green
    Write-Host "Your repository is secure!" -ForegroundColor Green
} else {
    Write-Host "❌ Secrets were detected!" -ForegroundColor Red
    Write-Host "Please address the issues above before proceeding." -ForegroundColor Red
}

# Exit with error code if secrets found
if ($SecretsFound) {
    exit 1
}

Write-Host "🎉 Secret detection completed successfully" -ForegroundColor Green