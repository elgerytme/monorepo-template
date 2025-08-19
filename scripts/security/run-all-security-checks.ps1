# Comprehensive security check orchestration
# This script runs all security checks in the correct order

param(
    [switch]$Parallel = $false,
    [switch]$FailFast = $false,
    [switch]$NoReport = $false,
    [switch]$Help = $false
)

if ($Help) {
    Write-Host "Usage: .\run-all-security-checks.ps1 [OPTIONS]"
    Write-Host "Options:"
    Write-Host "  -Parallel     Run security checks in parallel"
    Write-Host "  -FailFast     Stop on first failure"
    Write-Host "  -NoReport     Skip generating final report"
    Write-Host "  -Help         Show this help message"
    exit 0
}

$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent (Split-Path -Parent $ScriptDir)

Write-Host "🛡️  Starting comprehensive security assessment..." -ForegroundColor Cyan
Write-Host "========================================================"

# Initialize results tracking
$CheckResults = @{}
$CheckTimes = @{}
$TotalChecks = 0
$FailedChecks = 0
$StartTime = Get-Date

# Function to run a security check
function Invoke-SecurityCheck {
    param(
        [string]$CheckName,
        [string]$ScriptPath,
        [string]$Description
    )
    
    Write-Host ""
    Write-Host "🔍 Running: $Description" -ForegroundColor Blue
    Write-Host "----------------------------------------"
    
    $CheckStart = Get-Date
    
    if (Test-Path $ScriptPath) {
        try {
            & $ScriptPath
            if ($LASTEXITCODE -eq 0) {
                $script:CheckResults[$CheckName] = "PASS"
                Write-Host "✅ $CheckName`: PASSED" -ForegroundColor Green
            } else {
                $script:CheckResults[$CheckName] = "FAIL"
                $script:FailedChecks++
                Write-Host "❌ $CheckName`: FAILED" -ForegroundColor Red
                
                if ($FailFast) {
                    Write-Host "Stopping due to -FailFast flag" -ForegroundColor Red
                    exit 1
                }
            }
        } catch {
            $script:CheckResults[$CheckName] = "ERROR"
            $script:FailedChecks++
            Write-Host "❌ $CheckName`: ERROR - $($_.Exception.Message)" -ForegroundColor Red
            
            if ($FailFast) {
                Write-Host "Stopping due to -FailFast flag" -ForegroundColor Red
                exit 1
            }
        }
    } else {
        $script:CheckResults[$CheckName] = "SKIP"
        Write-Host "⚠️  $CheckName`: SKIPPED (script not found)" -ForegroundColor Yellow
    }
    
    $CheckEnd = Get-Date
    $script:CheckTimes[$CheckName] = ($CheckEnd - $CheckStart).TotalSeconds
    $script:TotalChecks++
}

# Function to run checks in parallel
function Invoke-ParallelChecks {
    Write-Host "Running security checks in parallel..." -ForegroundColor Cyan
    
    # Define checks to run in parallel
    $Checks = @(
        @{
            Name = "vulnerability-scan"
            Script = Join-Path $ScriptDir "vulnerability-scan.ps1"
            Description = "Dependency vulnerability scanning"
        },
        @{
            Name = "secret-detection"
            Script = Join-Path $ScriptDir "secret-detection.ps1"
            Description = "Secret detection and prevention"
        },
        @{
            Name = "container-security"
            Script = Join-Path $ScriptDir "container-security.ps1"
            Description = "Container security scanning"
        },
        @{
            Name = "security-policy"
            Script = Join-Path $ScriptDir "security-policy.ps1"
            Description = "Security policy enforcement"
        }
    )
    
    # Start all checks as background jobs
    $Jobs = @()
    foreach ($check in $Checks) {
        $Job = Start-Job -ScriptBlock {
            param($ScriptPath, $CheckName)
            
            try {
                & $ScriptPath
                return @{
                    Name = $CheckName
                    Result = if ($LASTEXITCODE -eq 0) { "PASS" } else { "FAIL" }
                    ExitCode = $LASTEXITCODE
                }
            } catch {
                return @{
                    Name = $CheckName
                    Result = "ERROR"
                    Error = $_.Exception.Message
                    ExitCode = 1
                }
            }
        } -ArgumentList $check.Script, $check.Name
        
        $Jobs += @{
            Job = $Job
            Name = $check.Name
            Description = $check.Description
        }
    }
    
    # Wait for all jobs to complete and collect results
    foreach ($jobInfo in $Jobs) {
        $Result = Receive-Job -Job $jobInfo.Job -Wait
        Remove-Job -Job $jobInfo.Job
        
        $script:CheckResults[$jobInfo.Name] = $Result.Result
        $script:TotalChecks++
        
        switch ($Result.Result) {
            "PASS" {
                Write-Host "✅ $($jobInfo.Name): PASSED" -ForegroundColor Green
            }
            "FAIL" {
                Write-Host "❌ $($jobInfo.Name): FAILED" -ForegroundColor Red
                $script:FailedChecks++
            }
            "ERROR" {
                Write-Host "❌ $($jobInfo.Name): ERROR - $($Result.Error)" -ForegroundColor Red
                $script:FailedChecks++
            }
            default {
                Write-Host "❓ $($jobInfo.Name): UNKNOWN" -ForegroundColor Yellow
            }
        }
    }
}

# Function to run checks sequentially
function Invoke-SequentialChecks {
    Write-Host "Running security checks sequentially..." -ForegroundColor Cyan
    
    # Run each security check
    Invoke-SecurityCheck "vulnerability-scan" (Join-Path $ScriptDir "vulnerability-scan.ps1") "Dependency vulnerability scanning with cargo-audit"
    Invoke-SecurityCheck "secret-detection" (Join-Path $ScriptDir "secret-detection.ps1") "Secret detection and prevention system"
    Invoke-SecurityCheck "container-security" (Join-Path $ScriptDir "container-security.ps1") "Container security scanning integration"
    Invoke-SecurityCheck "security-policy" (Join-Path $ScriptDir "security-policy.ps1") "Security policy enforcement automation"
}

# Function to generate comprehensive report
function New-SecurityReport {
    $EndTime = Get-Date
    $TotalTime = ($EndTime - $StartTime).TotalSeconds
    
    Write-Host ""
    Write-Host "📊 Comprehensive Security Assessment Report" -ForegroundColor Cyan
    Write-Host "=============================================="
    Write-Host "Assessment completed at: $(Get-Date)"
    Write-Host "Total execution time: $([math]::Round($TotalTime, 2))s"
    Write-Host "Total checks run: $TotalChecks"
    Write-Host "Failed checks: $FailedChecks"
    
    if ($TotalChecks -gt 0) {
        $SuccessRate = [math]::Round((($TotalChecks - $FailedChecks) * 100 / $TotalChecks), 1)
        Write-Host "Success rate: $SuccessRate%"
    }
    
    Write-Host ""
    Write-Host "Check Results:" -ForegroundColor Cyan
    Write-Host "-------------"
    
    foreach ($check in $CheckResults.Keys) {
        $result = $CheckResults[$check]
        $time = if ($CheckTimes.ContainsKey($check)) { [math]::Round($CheckTimes[$check], 2) } else { 0 }
        
        switch ($result) {
            "PASS" {
                Write-Host "✅ $check`: " -NoNewline
                Write-Host "PASSED" -ForegroundColor Green -NoNewline
                Write-Host " ($($time)s)"
            }
            "FAIL" {
                Write-Host "❌ $check`: " -NoNewline
                Write-Host "FAILED" -ForegroundColor Red -NoNewline
                Write-Host " ($($time)s)"
            }
            "SKIP" {
                Write-Host "⚠️  $check`: " -NoNewline
                Write-Host "SKIPPED" -ForegroundColor Yellow -NoNewline
                Write-Host " ($($time)s)"
            }
            default {
                Write-Host "❓ $check`: " -NoNewline
                Write-Host "UNKNOWN" -ForegroundColor Yellow -NoNewline
                Write-Host " ($($time)s)"
            }
        }
    }
    
    Write-Host ""
    if ($FailedChecks -eq 0) {
        Write-Host "🎉 All security checks passed!" -ForegroundColor Green
        Write-Host "Your codebase meets all security requirements." -ForegroundColor Green
    } else {
        Write-Host "⚠️  Security issues detected!" -ForegroundColor Red
        Write-Host "Please review and address the failed checks above." -ForegroundColor Red
        Write-Host ""
        Write-Host "Recommended next steps:" -ForegroundColor Yellow
        Write-Host "1. Review detailed output from failed checks"
        Write-Host "2. Fix identified security vulnerabilities"
        Write-Host "3. Update dependencies and configurations"
        Write-Host "4. Re-run security assessment"
        Write-Host "5. Consider implementing additional security measures"
    }
    
    # Save report to file
    $ReportFile = Join-Path $RootDir "security-assessment-report.txt"
    $ReportContent = @"
Security Assessment Report
=========================
Generated: $(Get-Date)
Total checks: $TotalChecks
Failed checks: $FailedChecks

Results:
"@
    
    foreach ($check in $CheckResults.Keys) {
        $ReportContent += "`n$check`: $($CheckResults[$check])"
    }
    
    Set-Content -Path $ReportFile -Value $ReportContent -Encoding UTF8
    
    Write-Host ""
    Write-Host "📄 Detailed report saved to: $ReportFile" -ForegroundColor Cyan
}

# Main execution
Write-Host "Configuration:"
Write-Host "- Parallel execution: $Parallel"
Write-Host "- Fail fast: $FailFast"
Write-Host "- Generate report: $(-not $NoReport)"
Write-Host ""

# Run security checks
if ($Parallel) {
    Invoke-ParallelChecks
} else {
    Invoke-SequentialChecks
}

# Generate report if requested
if (-not $NoReport) {
    New-SecurityReport
}

# Exit with appropriate code
if ($FailedChecks -gt 0) {
    Write-Host ""
    Write-Host "Security assessment completed with $FailedChecks failed checks." -ForegroundColor Red
    exit 1
} else {
    Write-Host ""
    Write-Host "Security assessment completed successfully!" -ForegroundColor Green
    exit 0
}