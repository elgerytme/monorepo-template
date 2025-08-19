# Automated rollback mechanism for failed releases (Windows)
# Provides safe rollback capabilities for deployment failures

param(
    [Parameter(Position=0)]
    [ValidateSet("record", "monitor", "rollback", "auto-rollback", "status", "help")]
    [string]$Command = "help",
    
    [Parameter(Position=1)]
    [string]$Version,
    
    [Parameter(Position=2)]
    [string]$Parameter2,
    
    [Parameter(Position=3)]
    [string]$Parameter3
)

$ErrorActionPreference = "Stop"

# Get script and repository paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

# Configuration
$RollbackDir = Join-Path $RepoRoot ".rollback"
$DeploymentLog = Join-Path $RollbackDir "deployment.log"
$RollbackLog = Join-Path $RollbackDir "rollback.log"
$HealthCheckTimeout = 300  # 5 minutes
$HealthCheckInterval = 10  # 10 seconds

# Logging functions
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
    Add-Content -Path $RollbackLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [INFO] $Message"
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
    Add-Content -Path $RollbackLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [SUCCESS] $Message"
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
    Add-Content -Path $RollbackLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [WARNING] $Message"
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    Add-Content -Path $RollbackLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [ERROR] $Message"
}

# Ensure rollback directory exists
function Ensure-RollbackDir {
    if (-not (Test-Path $RollbackDir)) {
        New-Item -ItemType Directory -Path $RollbackDir -Force | Out-Null
    }
    
    if (-not (Test-Path $DeploymentLog)) {
        New-Item -ItemType File -Path $DeploymentLog -Force | Out-Null
    }
    
    if (-not (Test-Path $RollbackLog)) {
        New-Item -ItemType File -Path $RollbackLog -Force | Out-Null
    }
}

# Record deployment state
function Record-Deployment {
    param(
        [string]$Version,
        [string]$DeploymentType = "standard"
    )
    
    Write-Info "Recording deployment of version $Version"
    
    try {
        $gitCommit = git rev-parse HEAD
        $gitBranch = git branch --show-current
    } catch {
        $gitCommit = "unknown"
        $gitBranch = "unknown"
    }
    
    $previousVersion = Get-PreviousDeploymentVersion
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Create deployment record
    $deploymentRecord = @{
        version = $Version
        deployment_type = $DeploymentType
        timestamp = $timestamp
        git_commit = $gitCommit
        git_branch = $gitBranch
        previous_version = $previousVersion
        rollback_available = $true
        health_checks = @()
    } | ConvertTo-Json -Depth 10
    
    $currentDeploymentFile = Join-Path $RollbackDir "current_deployment.json"
    Set-Content -Path $currentDeploymentFile -Value $deploymentRecord
    Add-Content -Path $DeploymentLog -Value $deploymentRecord
    
    Write-Success "Deployment recorded for version $Version"
}

# Get previous deployment version
function Get-PreviousDeploymentVersion {
    $currentDeploymentFile = Join-Path $RollbackDir "current_deployment.json"
    
    if (Test-Path $currentDeploymentFile) {
        try {
            $deployment = Get-Content $currentDeploymentFile | ConvertFrom-Json
            return $deployment.version
        } catch {
            return "unknown"
        }
    } else {
        return "none"
    }
}

# Get current deployment info
function Get-CurrentDeployment {
    $currentDeploymentFile = Join-Path $RollbackDir "current_deployment.json"
    
    if (Test-Path $currentDeploymentFile) {
        return Get-Content $currentDeploymentFile | ConvertFrom-Json
    } else {
        return @{}
    }
}

# Health check function (customizable)
function Invoke-HealthCheck {
    param(
        [string]$CheckType = "basic",
        [string]$Endpoint = "http://localhost:8080/health"
    )
    
    switch ($CheckType) {
        "basic" {
            # Basic HTTP health check
            try {
                $response = Invoke-WebRequest -Uri $Endpoint -Method Get -TimeoutSec 10 -UseBasicParsing
                return $response.StatusCode -eq 200
            } catch {
                return $false
            }
        }
        "database" {
            # Database connectivity check (example)
            Write-Info "Performing database health check"
            # Add your database health check logic here
            return $true
        }
        "service" {
            # Service-specific health check
            Write-Info "Performing service health check"
            # Add your service health check logic here
            return $true
        }
        default {
            Write-Warning "Unknown health check type: $CheckType"
            return $true
        }
    }
}

# Monitor deployment health
function Watch-DeploymentHealth {
    param(
        [string]$Version,
        [string]$HealthChecks = "basic",
        [int]$Timeout = $HealthCheckTimeout
    )
    
    Write-Info "Monitoring deployment health for version $Version"
    Write-Info "Health checks: $HealthChecks, timeout: ${Timeout}s"
    
    $startTime = Get-Date
    $endTime = $startTime.AddSeconds($Timeout)
    $checkCount = 0
    $failedChecks = 0
    
    while ((Get-Date) -lt $endTime) {
        $checkCount++
        $allChecksPassed = $true
        
        # Parse health checks (comma-separated)
        $checks = $HealthChecks -split ',' | ForEach-Object { $_.Trim() }
        
        foreach ($check in $checks) {
            Write-Info "Performing health check: $check (attempt $checkCount)"
            
            if (-not (Invoke-HealthCheck -CheckType $check)) {
                Write-Warning "Health check failed: $check"
                $allChecksPassed = $false
                $failedChecks++
            } else {
                Write-Success "Health check passed: $check"
            }
        }
        
        if ($allChecksPassed) {
            Write-Success "All health checks passed for version $Version"
            Update-DeploymentStatus -Version $Version -Status "healthy"
            return $true
        }
        
        # If too many consecutive failures, trigger rollback
        if ($failedChecks -ge 3) {
            Write-Error "Multiple consecutive health check failures detected"
            Update-DeploymentStatus -Version $Version -Status "unhealthy"
            return $false
        }
        
        Start-Sleep -Seconds $HealthCheckInterval
    }
    
    Write-Error "Health check monitoring timed out for version $Version"
    Update-DeploymentStatus -Version $Version -Status "timeout"
    return $false
}

# Update deployment status
function Update-DeploymentStatus {
    param(
        [string]$Version,
        [string]$Status
    )
    
    $currentDeploymentFile = Join-Path $RollbackDir "current_deployment.json"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    if (Test-Path $currentDeploymentFile) {
        try {
            $deployment = Get-Content $currentDeploymentFile | ConvertFrom-Json
            $deployment | Add-Member -NotePropertyName "status" -NotePropertyValue $Status -Force
            $deployment | Add-Member -NotePropertyName "last_health_check" -NotePropertyValue $timestamp -Force
            
            $deployment | ConvertTo-Json -Depth 10 | Set-Content -Path $currentDeploymentFile
        } catch {
            Write-Warning "Failed to update deployment status"
        }
    }
    
    Write-Info "Updated deployment status to: $Status"
}

# Perform rollback to previous version
function Invoke-Rollback {
    param(
        [string]$TargetVersion = "",
        [string]$RollbackType = "git"
    )
    
    Write-Info "Initiating rollback process"
    
    # Get current deployment info
    $currentDeployment = Get-CurrentDeployment
    $currentVersion = if ($currentDeployment.version) { $currentDeployment.version } else { "unknown" }
    
    # Determine target version for rollback
    if ([string]::IsNullOrEmpty($TargetVersion)) {
        $TargetVersion = if ($currentDeployment.previous_version) { $currentDeployment.previous_version } else { "unknown" }
        if ($TargetVersion -eq "unknown" -or $TargetVersion -eq "none") {
            Write-Error "No previous version available for rollback"
            return $false
        }
    }
    
    Write-Info "Rolling back from version $currentVersion to $TargetVersion"
    
    # Create rollback record
    $rollbackRecord = @{
        rollback_timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        from_version = $currentVersion
        to_version = $TargetVersion
        rollback_type = $RollbackType
        reason = "automated_rollback"
        initiated_by = "rollback_manager"
    } | ConvertTo-Json -Depth 10
    
    $rollbackInProgressFile = Join-Path $RollbackDir "rollback_in_progress.json"
    Set-Content -Path $rollbackInProgressFile -Value $rollbackRecord
    
    # Perform rollback based on type
    $rollbackResult = switch ($RollbackType) {
        "git" { Invoke-GitRollback -TargetVersion $TargetVersion }
        "container" { Invoke-ContainerRollback -TargetVersion $TargetVersion }
        "database" { Invoke-DatabaseRollback -TargetVersion $TargetVersion }
        default {
            Write-Error "Unknown rollback type: $RollbackType"
            $false
        }
    }
    
    if ($rollbackResult) {
        Write-Success "Rollback completed successfully"
        
        # Update deployment record
        Record-Deployment -Version $TargetVersion -DeploymentType "rollback"
        
        # Clean up rollback in progress file
        Remove-Item $rollbackInProgressFile -ErrorAction SilentlyContinue
        
        # Archive rollback record
        $rollbackHistoryFile = Join-Path $RollbackDir "rollback_history.json"
        Add-Content -Path $rollbackHistoryFile -Value $rollbackRecord
        
        return $true
    } else {
        Write-Error "Rollback failed"
        
        # Update rollback record with failure
        $failedRecord = $rollbackRecord | ConvertFrom-Json
        $failedRecord | Add-Member -NotePropertyName "status" -NotePropertyValue "failed" -Force
        
        $rollbackFailedFile = Join-Path $RollbackDir "rollback_failed.json"
        $failedRecord | ConvertTo-Json -Depth 10 | Set-Content -Path $rollbackFailedFile
        Remove-Item $rollbackInProgressFile -ErrorAction SilentlyContinue
        
        return $false
    }
}

# Git-based rollback
function Invoke-GitRollback {
    param([string]$TargetVersion)
    
    Write-Info "Performing git rollback to version $TargetVersion"
    
    try {
        # Stash any uncommitted changes
        $gitStatus = git status --porcelain
        if ($gitStatus) {
            Write-Info "Stashing uncommitted changes"
            git stash push -m "Pre-rollback stash $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        }
        
        # Checkout target version
        try {
            git checkout "v$TargetVersion" 2>$null
            Write-Success "Successfully checked out version $TargetVersion"
            return $true
        } catch {
            try {
                git checkout $TargetVersion 2>$null
                Write-Success "Successfully checked out commit $TargetVersion"
                return $true
            } catch {
                Write-Error "Failed to checkout version $TargetVersion"
                return $false
            }
        }
    } catch {
        Write-Error "Git rollback failed: $_"
        return $false
    }
}

# Container-based rollback
function Invoke-ContainerRollback {
    param([string]$TargetVersion)
    
    Write-Info "Performing container rollback to version $TargetVersion"
    
    # This is a placeholder for container rollback logic
    # You would implement your specific container orchestration rollback here
    # Examples: Docker Compose, Kubernetes, etc.
    
    Write-Warning "Container rollback not implemented - add your container orchestration logic here"
    return $true
}

# Database rollback (migrations)
function Invoke-DatabaseRollback {
    param([string]$TargetVersion)
    
    Write-Info "Performing database rollback to version $TargetVersion"
    
    # This is a placeholder for database rollback logic
    # You would implement your specific database migration rollback here
    
    Write-Warning "Database rollback not implemented - add your database migration logic here"
    return $true
}

# Automatic rollback on failure
function Invoke-AutoRollbackOnFailure {
    param(
        [string]$Version,
        [string]$HealthChecks = "basic",
        [int]$Timeout = $HealthCheckTimeout
    )
    
    Write-Info "Starting automatic rollback monitoring for version $Version"
    
    # Monitor deployment health
    if (-not (Watch-DeploymentHealth -Version $Version -HealthChecks $HealthChecks -Timeout $Timeout)) {
        Write-Error "Deployment health check failed, initiating automatic rollback"
        
        if (Invoke-Rollback) {
            Write-Success "Automatic rollback completed successfully"
            
            # Verify rollback health
            $currentDeployment = Get-CurrentDeployment
            $previousVersion = $currentDeployment.version
            
            if (Watch-DeploymentHealth -Version $previousVersion -HealthChecks $HealthChecks -Timeout 60) {
                Write-Success "Rollback deployment is healthy"
                return $true
            } else {
                Write-Error "Rollback deployment is also unhealthy - manual intervention required"
                return $false
            }
        } else {
            Write-Error "Automatic rollback failed - manual intervention required"
            return $false
        }
    } else {
        Write-Success "Deployment is healthy, no rollback needed"
        return $true
    }
}

# Show rollback status
function Show-RollbackStatus {
    Write-Info "Rollback Manager Status"
    Write-Host "========================"
    
    $currentDeploymentFile = Join-Path $RollbackDir "current_deployment.json"
    if (Test-Path $currentDeploymentFile) {
        Write-Host "Current Deployment:"
        Get-Content $currentDeploymentFile | ConvertFrom-Json | ConvertTo-Json -Depth 10
        Write-Host ""
    }
    
    $rollbackInProgressFile = Join-Path $RollbackDir "rollback_in_progress.json"
    if (Test-Path $rollbackInProgressFile) {
        Write-Host "Rollback In Progress:"
        Get-Content $rollbackInProgressFile | ConvertFrom-Json | ConvertTo-Json -Depth 10
        Write-Host ""
    }
    
    $rollbackHistoryFile = Join-Path $RollbackDir "rollback_history.json"
    if (Test-Path $rollbackHistoryFile) {
        Write-Host "Recent Rollbacks:"
        Get-Content $rollbackHistoryFile | Select-Object -Last 5
    }
}

# Show usage information
function Show-Usage {
    @"
Usage: .\rollback-manager.ps1 [COMMAND] [OPTIONS]

Commands:
    record <version> [type]           Record deployment of version
    monitor <version> [checks] [timeout]  Monitor deployment health
    rollback [version] [type]         Perform rollback to version
    auto-rollback <version> [checks] [timeout]  Monitor and auto-rollback on failure
    status                           Show rollback status
    help                            Show this help message

Examples:
    .\rollback-manager.ps1 record 1.2.3                 # Record deployment of version 1.2.3
    .\rollback-manager.ps1 monitor 1.2.3 basic,database 300  # Monitor with health checks for 5 minutes
    .\rollback-manager.ps1 rollback 1.2.2                # Rollback to version 1.2.2
    .\rollback-manager.ps1 auto-rollback 1.2.3 basic 300 # Monitor and auto-rollback if unhealthy

"@
}

# Main script logic
Ensure-RollbackDir

switch ($Command) {
    "record" {
        if ([string]::IsNullOrEmpty($Version)) {
            Write-Error "Version required for record command"
            Show-Usage
            exit 1
        }
        Record-Deployment -Version $Version -DeploymentType ($Parameter2 -or "standard")
    }
    "monitor" {
        if ([string]::IsNullOrEmpty($Version)) {
            Write-Error "Version required for monitor command"
            Show-Usage
            exit 1
        }
        $healthChecks = if ($Parameter2) { $Parameter2 } else { "basic" }
        $timeout = if ($Parameter3) { [int]$Parameter3 } else { $HealthCheckTimeout }
        Watch-DeploymentHealth -Version $Version -HealthChecks $healthChecks -Timeout $timeout
    }
    "rollback" {
        $rollbackType = if ($Parameter2) { $Parameter2 } else { "git" }
        Invoke-Rollback -TargetVersion $Version -RollbackType $rollbackType
    }
    "auto-rollback" {
        if ([string]::IsNullOrEmpty($Version)) {
            Write-Error "Version required for auto-rollback command"
            Show-Usage
            exit 1
        }
        $healthChecks = if ($Parameter2) { $Parameter2 } else { "basic" }
        $timeout = if ($Parameter3) { [int]$Parameter3 } else { $HealthCheckTimeout }
        Invoke-AutoRollbackOnFailure -Version $Version -HealthChecks $healthChecks -Timeout $timeout
    }
    "status" {
        Show-RollbackStatus
    }
    "help" {
        Show-Usage
    }
    default {
        Write-Error "Unknown command: $Command"
        Show-Usage
        exit 1
    }
}