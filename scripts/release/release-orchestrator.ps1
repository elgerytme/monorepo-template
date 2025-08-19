# Release orchestration script for Windows
# Coordinates the entire release process including versioning, signing, and rollback capabilities

param(
    [Parameter(Position=0)]
    [ValidateSet("release", "rollback", "build", "sign", "status", "config", "help")]
    [string]$Command = "help",
    
    [Parameter(Position=1)]
    [string]$Parameter1,
    
    [Parameter(Position=2)]
    [string]$Parameter2,
    
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

# Get script and repository paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

# Configuration
$ReleaseConfig = Join-Path $RepoRoot ".release-config.json"
$ArtifactsDir = Join-Path $RepoRoot "artifacts"

# Import other release scripts
$VersionManagerScript = Join-Path $ScriptDir "version-manager.ps1"
$ReleaseNotesScript = Join-Path $ScriptDir "release-notes-generator.ps1"
$ArtifactSigningScript = Join-Path $ScriptDir "artifact-signing.ps1"
$RollbackManagerScript = Join-Path $ScriptDir "rollback-manager.ps1"

# Logging functions
function Write-Info {
    param([string]$Message)
    Write-Host "[ORCHESTRATOR] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[ORCHESTRATOR] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[ORCHESTRATOR] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ORCHESTRATOR] $Message" -ForegroundColor Red
}

# Load release configuration
function Import-ReleaseConfig {
    if (Test-Path $ReleaseConfig) {
        Write-Info "Loading release configuration from $ReleaseConfig"
        return Get-Content $ReleaseConfig | ConvertFrom-Json
    } else {
        Write-Info "Creating default release configuration"
        return New-DefaultConfig
    }
}

# Create default release configuration
function New-DefaultConfig {
    $defaultConfig = @{
        release = @{
            auto_version = $true
            generate_release_notes = $true
            sign_artifacts = $true
            enable_rollback = $true
            health_checks = @("basic")
            health_check_timeout = 300
            pre_release_hooks = @()
            post_release_hooks = @()
            notification = @{
                enabled = $false
                webhook_url = ""
                channels = @()
            }
        }
        artifacts = @{
            build_command = "just build-all"
            output_directory = "./artifacts"
            include_patterns = @("*.tar.gz", "*.zip", "*.deb", "*.rpm")
            exclude_patterns = @("*.tmp", "*.log")
        }
        signing = @{
            gpg_key_id = ""
            cosign_enabled = $true
            verify_signatures = $true
        }
        rollback = @{
            enabled = $true
            auto_rollback = $true
            rollback_types = @("git", "container")
            health_check_retries = 3
        }
    }
    
    $defaultConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $ReleaseConfig
    Write-Success "Created default release configuration at $ReleaseConfig"
    return $defaultConfig
}

# Get configuration value
function Get-ConfigValue {
    param(
        [object]$Config,
        [string]$Path,
        [object]$Default = $null
    )
    
    try {
        $pathParts = $Path -split '\.'
        $current = $Config
        
        foreach ($part in $pathParts) {
            if ($current -is [hashtable] -and $current.ContainsKey($part)) {
                $current = $current[$part]
            } elseif ($current.PSObject.Properties[$part]) {
                $current = $current.PSObject.Properties[$part].Value
            } else {
                return $Default
            }
        }
        
        return $current
    } catch {
        return $Default
    }
}

# Build artifacts
function Build-Artifacts {
    param([object]$Config)
    
    Write-Info "Building release artifacts"
    
    $buildCommand = Get-ConfigValue -Config $Config -Path "artifacts.build_command" -Default "just build-all"
    $outputDir = Get-ConfigValue -Config $Config -Path "artifacts.output_directory" -Default "./artifacts"
    
    # Ensure output directory exists
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    # Run build command
    Write-Info "Running build command: $buildCommand"
    
    try {
        Invoke-Expression $buildCommand
        Write-Success "Artifacts built successfully"
        
        # List built artifacts
        Write-Info "Built artifacts:"
        $artifacts = Get-ChildItem -Path $outputDir -File | Where-Object { 
            $_.Extension -in @('.tar.gz', '.zip', '.deb', '.rpm') 
        }
        
        foreach ($artifact in $artifacts) {
            Write-Info "  - $($artifact.Name)"
        }
        
        return $true
    } catch {
        Write-Error "Failed to build artifacts: $_"
        return $false
    }
}

# Run pre-release hooks
function Invoke-PreReleaseHooks {
    param([object]$Config)
    
    $hooks = Get-ConfigValue -Config $Config -Path "release.pre_release_hooks" -Default @()
    
    if ($hooks -and $hooks.Count -gt 0) {
        Write-Info "Running pre-release hooks"
        
        foreach ($hook in $hooks) {
            if ($hook) {
                Write-Info "Executing hook: $hook"
                try {
                    Invoke-Expression $hook
                    Write-Success "Hook completed: $hook"
                } catch {
                    Write-Error "Hook failed: $hook - $_"
                    return $false
                }
            }
        }
    }
    
    return $true
}

# Run post-release hooks
function Invoke-PostReleaseHooks {
    param([object]$Config)
    
    $hooks = Get-ConfigValue -Config $Config -Path "release.post_release_hooks" -Default @()
    
    if ($hooks -and $hooks.Count -gt 0) {
        Write-Info "Running post-release hooks"
        
        foreach ($hook in $hooks) {
            if ($hook) {
                Write-Info "Executing hook: $hook"
                try {
                    Invoke-Expression $hook
                    Write-Success "Hook completed: $hook"
                } catch {
                    Write-Warning "Hook failed (non-critical): $hook - $_"
                }
            }
        }
    }
}

# Send notification
function Send-Notification {
    param(
        [string]$Message,
        [object]$Config
    )
    
    $webhookUrl = Get-ConfigValue -Config $Config -Path "release.notification.webhook_url" -Default ""
    $notificationEnabled = Get-ConfigValue -Config $Config -Path "release.notification.enabled" -Default $false
    
    if ($notificationEnabled -and $webhookUrl) {
        Write-Info "Sending release notification"
        
        $payload = @{
            text = $Message
            timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        } | ConvertTo-Json
        
        try {
            Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $payload -ContentType "application/json" | Out-Null
        } catch {
            Write-Warning "Failed to send notification: $_"
        }
    }
}

# Perform full release
function Invoke-Release {
    param(
        [string]$IncrementType = "auto",
        [bool]$SkipBuild = $false
    )
    
    Write-Info "Starting release process with increment type: $IncrementType"
    
    # Load configuration
    $config = Import-ReleaseConfig
    
    # Run pre-release hooks
    if (-not (Invoke-PreReleaseHooks -Config $config)) {
        Write-Error "Pre-release hooks failed, aborting release"
        return $false
    }
    
    # Build artifacts (unless skipped)
    if (-not $SkipBuild) {
        if (-not (Build-Artifacts -Config $config)) {
            Write-Error "Artifact build failed, aborting release"
            return $false
        }
    }
    
    # Version management
    $autoVersion = Get-ConfigValue -Config $config -Path "release.auto_version" -Default $true
    
    if ($autoVersion) {
        Write-Info "Performing automatic version bump"
        try {
            $newVersion = & $VersionManagerScript bump $IncrementType
            if (-not $newVersion) {
                Write-Error "Version bump failed"
                return $false
            }
        } catch {
            Write-Error "Version bump failed: $_"
            return $false
        }
    } else {
        Write-Warning "Automatic versioning disabled, using current version"
        $newVersion = & $VersionManagerScript current
    }
    
    Write-Success "Release version: $newVersion"
    
    # Generate release notes
    $generateNotes = Get-ConfigValue -Config $config -Path "release.generate_release_notes" -Default $true
    
    if ($generateNotes) {
        Write-Info "Generating release notes"
        try {
            & $ReleaseNotesScript generate $newVersion
        } catch {
            Write-Warning "Release notes generation failed (non-critical): $_"
        }
    }
    
    # Sign artifacts
    $signArtifacts = Get-ConfigValue -Config $config -Path "release.sign_artifacts" -Default $true
    
    if ($signArtifacts) {
        Write-Info "Signing release artifacts"
        try {
            & $ArtifactSigningScript sign $ArtifactsDir
        } catch {
            Write-Error "Artifact signing failed: $_"
            return $false
        }
    }
    
    # Record deployment for rollback capability
    $rollbackEnabled = Get-ConfigValue -Config $config -Path "rollback.enabled" -Default $true
    
    if ($rollbackEnabled) {
        Write-Info "Recording deployment for rollback capability"
        try {
            & $RollbackManagerScript record $newVersion "release"
        } catch {
            Write-Warning "Failed to record deployment for rollback: $_"
        }
    }
    
    # Run post-release hooks
    Invoke-PostReleaseHooks -Config $config
    
    # Send notification
    Send-Notification -Message "Release $newVersion completed successfully" -Config $config
    
    Write-Success "Release $newVersion completed successfully!"
    
    # Start health monitoring if auto-rollback is enabled
    $autoRollback = Get-ConfigValue -Config $config -Path "rollback.auto_rollback" -Default $true
    
    if ($autoRollback) {
        Write-Info "Starting automatic health monitoring and rollback capability"
        
        $healthChecks = (Get-ConfigValue -Config $config -Path "release.health_checks" -Default @("basic")) -join ","
        $healthTimeout = Get-ConfigValue -Config $config -Path "release.health_check_timeout" -Default 300
        
        # Run health monitoring in background
        Start-Job -ScriptBlock {
            param($Script, $Version, $HealthChecks, $Timeout)
            Start-Sleep -Seconds 30  # Give deployment time to start
            & $Script auto-rollback $Version $HealthChecks $Timeout
        } -ArgumentList $RollbackManagerScript, $newVersion, $healthChecks, $healthTimeout | Out-Null
        
        Write-Info "Health monitoring started in background"
    }
    
    return $true
}

# Perform rollback
function Invoke-RollbackRelease {
    param(
        [string]$TargetVersion = "",
        [string]$RollbackType = "git"
    )
    
    Write-Info "Starting rollback process"
    
    # Load configuration
    $config = Import-ReleaseConfig
    
    # Check if rollback is enabled
    $rollbackEnabled = Get-ConfigValue -Config $config -Path "rollback.enabled" -Default $true
    
    if (-not $rollbackEnabled) {
        Write-Error "Rollback is disabled in configuration"
        return $false
    }
    
    # Perform rollback
    try {
        if ($TargetVersion) {
            & $RollbackManagerScript rollback $TargetVersion $RollbackType
        } else {
            & $RollbackManagerScript rollback
        }
        
        Write-Success "Rollback completed successfully"
        
        # Send notification
        $currentVersion = & $VersionManagerScript current
        Send-Notification -Message "Rollback to version $currentVersion completed successfully" -Config $config
        
        return $true
    } catch {
        Write-Error "Rollback failed: $_"
        Send-Notification -Message "Rollback failed - manual intervention required" -Config $config
        return $false
    }
}

# Show release status
function Show-ReleaseStatus {
    Write-Info "Release System Status"
    Write-Host "====================="
    
    # Current version
    try {
        $currentVersion = & $VersionManagerScript current
        Write-Host "Current Version: $currentVersion"
    } catch {
        Write-Host "Current Version: unknown"
    }
    
    # Git status
    try {
        $gitBranch = git branch --show-current 2>$null
        $gitCommit = git rev-parse --short HEAD 2>$null
        Write-Host "Git Branch: $gitBranch"
        Write-Host "Git Commit: $gitCommit"
    } catch {
        Write-Host "Git Branch: unknown"
        Write-Host "Git Commit: unknown"
    }
    
    # Rollback status
    Write-Host ""
    try {
        & $RollbackManagerScript status
    } catch {
        Write-Host "Rollback status: unavailable"
    }
    
    # Configuration
    Write-Host ""
    Write-Host "Configuration:"
    if (Test-Path $ReleaseConfig) {
        try {
            Get-Content $ReleaseConfig | ConvertFrom-Json | ConvertTo-Json -Depth 10
        } catch {
            Write-Host "Invalid JSON configuration"
        }
    } else {
        Write-Host "No configuration file found"
    }
}

# Show usage information
function Show-Usage {
    @"
Usage: .\release-orchestrator.ps1 [COMMAND] [OPTIONS]

Commands:
    release [major|minor|patch|auto] [-SkipBuild]  Perform full release
    rollback [version] [type]                      Rollback to previous version
    build                                         Build artifacts only
    sign                                          Sign artifacts only
    status                                        Show release system status
    config                                        Show/edit configuration
    help                                          Show this help message

Examples:
    .\release-orchestrator.ps1 release                    # Auto-detect version increment and release
    .\release-orchestrator.ps1 release minor              # Release with minor version bump
    .\release-orchestrator.ps1 release auto -SkipBuild    # Release without building artifacts
    .\release-orchestrator.ps1 rollback                   # Rollback to previous version
    .\release-orchestrator.ps1 rollback 1.2.2             # Rollback to specific version
    .\release-orchestrator.ps1 build                      # Build artifacts only
    .\release-orchestrator.ps1 sign                       # Sign existing artifacts
    .\release-orchestrator.ps1 status                     # Show system status

"@
}

# Main script logic
switch ($Command) {
    "release" {
        $incrementType = if ($Parameter1) { $Parameter1 } else { "auto" }
        Invoke-Release -IncrementType $incrementType -SkipBuild $SkipBuild
    }
    "rollback" {
        $rollbackType = if ($Parameter2) { $Parameter2 } else { "git" }
        Invoke-RollbackRelease -TargetVersion $Parameter1 -RollbackType $rollbackType
    }
    "build" {
        $config = Import-ReleaseConfig
        Build-Artifacts -Config $config
    }
    "sign" {
        & $ArtifactSigningScript sign $ArtifactsDir
    }
    "status" {
        Show-ReleaseStatus
    }
    "config" {
        if (Test-Path $ReleaseConfig) {
            Get-Content $ReleaseConfig | ConvertFrom-Json | ConvertTo-Json -Depth 10
        } else {
            New-DefaultConfig | Out-Null
        }
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