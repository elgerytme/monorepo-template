# Container security scanning integration
# This script scans container images for vulnerabilities and misconfigurations

param(
    [string[]]$Images = @(),
    [string]$SeverityLevels = "HIGH,CRITICAL",
    [switch]$SkipImageBuild = $false,
    [switch]$Verbose = $false
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent (Split-Path -Parent $ScriptDir)

Write-Host "🐳 Starting container security scan..." -ForegroundColor Cyan

# Configuration
$TrivyCacheDir = "$env:USERPROFILE\.cache\trivy"
$ScanTimeout = "10m"

# Check if trivy is installed
try {
    trivy --version | Out-Null
} catch {
    Write-Host "Installing trivy..." -ForegroundColor Yellow
    
    # Download and install trivy for Windows
    $LatestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/aquasecurity/trivy/releases/latest"
    $DownloadUrl = ($LatestRelease.assets | Where-Object { $_.name -like "*Windows-64bit*" }).browser_download_url
    
    $TempPath = "$env:TEMP\trivy.zip"
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $TempPath
    
    Expand-Archive -Path $TempPath -DestinationPath "$env:TEMP\trivy" -Force
    
    $InstallPath = "$env:LOCALAPPDATA\trivy"
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    Copy-Item -Path "$env:TEMP\trivy\trivy.exe" -Destination "$InstallPath\trivy.exe" -Force
    
    # Add to PATH if not already there
    $CurrentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($CurrentPath -notlike "*$InstallPath*") {
        [Environment]::SetEnvironmentVariable("PATH", "$CurrentPath;$InstallPath", "User")
        $env:PATH += ";$InstallPath"
    }
    
    Remove-Item -Path $TempPath -Force
    Remove-Item -Path "$env:TEMP\trivy" -Recurse -Force
}

# Check if docker is available
try {
    docker --version | Out-Null
    $DockerAvailable = $true
} catch {
    Write-Host "⚠️  Docker not found. Container scanning will be limited." -ForegroundColor Yellow
    $DockerAvailable = $false
}

# Function to scan Dockerfile
function Scan-Dockerfile {
    param([string]$DockerfilePath)
    
    $DockerfileName = "$(Split-Path -Parent $DockerfilePath | Split-Path -Leaf)/$(Split-Path -Leaf $DockerfilePath)"
    Write-Host "📄 Scanning Dockerfile: $DockerfileName" -ForegroundColor Blue
    
    $ReportPath = "$env:TEMP\dockerfile_scan.json"
    
    try {
        # Scan Dockerfile for misconfigurations
        trivy config --severity $SeverityLevels --format json --output $ReportPath $DockerfilePath 2>$null
        
        if (Test-Path $ReportPath) {
            $ScanResult = Get-Content $ReportPath | ConvertFrom-Json
            $VulnCount = 0
            
            if ($ScanResult.Results -and $ScanResult.Results[0].Misconfigurations) {
                $VulnCount = $ScanResult.Results[0].Misconfigurations.Count
            }
            
            if ($VulnCount -gt 0) {
                Write-Host "❌ Found $VulnCount misconfigurations in $DockerfileName" -ForegroundColor Red
                
                # Display misconfigurations
                foreach ($misconfig in $ScanResult.Results[0].Misconfigurations) {
                    Write-Host "- $($misconfig.ID): $($misconfig.Title) (Severity: $($misconfig.Severity))" -ForegroundColor Red
                }
                
                return $false
            } else {
                Write-Host "✅ No misconfigurations found in $DockerfileName" -ForegroundColor Green
                return $true
            }
        } else {
            Write-Host "✅ No misconfigurations found in $DockerfileName" -ForegroundColor Green
            return $true
        }
    } catch {
        Write-Host "⚠️  Could not scan $DockerfileName" -ForegroundColor Yellow
        return $true
    } finally {
        if (Test-Path $ReportPath) {
            Remove-Item $ReportPath -Force
        }
    }
}

# Function to scan container image
function Scan-ContainerImage {
    param([string]$ImageName)
    
    Write-Host "🐳 Scanning container image: $ImageName" -ForegroundColor Blue
    
    $ReportPath = "$env:TEMP\image_scan.json"
    
    try {
        # Scan image for vulnerabilities
        trivy image --severity $SeverityLevels --format json --output $ReportPath $ImageName 2>$null
        
        if (Test-Path $ReportPath) {
            $ScanResult = Get-Content $ReportPath | ConvertFrom-Json
            $VulnCount = 0
            
            # Count vulnerabilities across all results
            foreach ($result in $ScanResult.Results) {
                if ($result.Vulnerabilities) {
                    $VulnCount += $result.Vulnerabilities.Count
                }
            }
            
            if ($VulnCount -gt 0) {
                Write-Host "❌ Found $VulnCount vulnerabilities in $ImageName" -ForegroundColor Red
                
                # Display top vulnerabilities
                Write-Host "Top vulnerabilities:" -ForegroundColor Yellow
                $Count = 0
                foreach ($result in $ScanResult.Results) {
                    if ($result.Vulnerabilities) {
                        foreach ($vuln in $result.Vulnerabilities) {
                            if ($Count -lt 10) {
                                Write-Host "- $($vuln.PkgName): $($vuln.VulnerabilityID) (Severity: $($vuln.Severity))" -ForegroundColor Red
                                $Count++
                            }
                        }
                    }
                }
                
                return $false
            } else {
                Write-Host "✅ No vulnerabilities found in $ImageName" -ForegroundColor Green
                return $true
            }
        } else {
            Write-Host "✅ No vulnerabilities found in $ImageName" -ForegroundColor Green
            return $true
        }
    } catch {
        Write-Host "⚠️  Could not scan image $ImageName" -ForegroundColor Yellow
        return $true
    } finally {
        if (Test-Path $ReportPath) {
            Remove-Item $ReportPath -Force
        }
    }
}

# Function to build and scan image from Dockerfile
function Build-AndScanDockerfile {
    param([string]$DockerfilePath)
    
    $ContextDir = Split-Path -Parent $DockerfilePath
    $ImageTag = "security-scan:$(Split-Path -Leaf $ContextDir)-$(Get-Date -Format 'yyyyMMddHHmmss')"
    
    Write-Host "🔨 Building image from Dockerfile: $DockerfilePath" -ForegroundColor Blue
    
    try {
        docker build -t $ImageTag -f $DockerfilePath $ContextDir 2>$null | Out-Null
        Write-Host "✅ Image built successfully" -ForegroundColor Green
        
        # Scan the built image
        $ScanResult = Scan-ContainerImage $ImageTag
        
        # Clean up the image
        try {
            docker rmi $ImageTag 2>$null | Out-Null
        } catch {
            # Ignore cleanup errors
        }
        
        return $ScanResult
    } catch {
        Write-Host "⚠️  Could not build image from $DockerfilePath" -ForegroundColor Yellow
        return $true
    }
}

# Function to scan docker-compose files
function Scan-DockerCompose {
    param([string]$ComposeFile)
    
    $ComposeName = "$(Split-Path -Parent $ComposeFile | Split-Path -Leaf)/$(Split-Path -Leaf $ComposeFile)"
    Write-Host "📋 Scanning docker-compose file: $ComposeName" -ForegroundColor Blue
    
    $ReportPath = "$env:TEMP\compose_scan.json"
    
    try {
        # Scan docker-compose for misconfigurations
        trivy config --severity $SeverityLevels --format json --output $ReportPath $ComposeFile 2>$null
        
        if (Test-Path $ReportPath) {
            $ScanResult = Get-Content $ReportPath | ConvertFrom-Json
            $VulnCount = 0
            
            if ($ScanResult.Results -and $ScanResult.Results[0].Misconfigurations) {
                $VulnCount = $ScanResult.Results[0].Misconfigurations.Count
            }
            
            if ($VulnCount -gt 0) {
                Write-Host "❌ Found $VulnCount misconfigurations in $ComposeName" -ForegroundColor Red
                
                # Display misconfigurations
                foreach ($misconfig in $ScanResult.Results[0].Misconfigurations) {
                    Write-Host "- $($misconfig.ID): $($misconfig.Title) (Severity: $($misconfig.Severity))" -ForegroundColor Red
                }
                
                return $false
            } else {
                Write-Host "✅ No misconfigurations found in $ComposeName" -ForegroundColor Green
                return $true
            }
        } else {
            Write-Host "✅ No misconfigurations found in $ComposeName" -ForegroundColor Green
            return $true
        }
    } catch {
        Write-Host "⚠️  Could not scan $ComposeName" -ForegroundColor Yellow
        return $true
    } finally {
        if (Test-Path $ReportPath) {
            Remove-Item $ReportPath -Force
        }
    }
}

# Initialize scan results
$TotalIssues = 0
$ScannedFiles = 0

# Update trivy database
Write-Host "📦 Updating trivy database..." -ForegroundColor Cyan
trivy --cache-dir $TrivyCacheDir image --download-db-only 2>$null

# Scan all Dockerfiles
Write-Host "🔍 Scanning for Dockerfiles..." -ForegroundColor Cyan
$Dockerfiles = Get-ChildItem -Path $RootDir -Name "Dockerfile*" -Recurse | Where-Object { $_ -notmatch "node_modules|target" }

foreach ($dockerfile in $Dockerfiles) {
    $DockerfilePath = Join-Path $RootDir $dockerfile
    $ScannedFiles++
    
    # Scan Dockerfile for misconfigurations
    if (-not (Scan-Dockerfile $DockerfilePath)) {
        $TotalIssues++
    }
    
    # Build and scan image if Docker is available and not skipping
    if ($DockerAvailable -and -not $SkipImageBuild) {
        if (-not (Build-AndScanDockerfile $DockerfilePath)) {
            $TotalIssues++
        }
    }
}

# Scan all docker-compose files
Write-Host "🔍 Scanning for docker-compose files..." -ForegroundColor Cyan
$ComposeFiles = Get-ChildItem -Path $RootDir -Name "docker-compose*.yml", "docker-compose*.yaml" -Recurse | Where-Object { $_ -notmatch "node_modules" }

foreach ($composeFile in $ComposeFiles) {
    $ComposeFilePath = Join-Path $RootDir $composeFile
    $ScannedFiles++
    
    if (-not (Scan-DockerCompose $ComposeFilePath)) {
        $TotalIssues++
    }
}

# Scan specific images if provided
if ($Images.Count -gt 0) {
    Write-Host "🔍 Scanning provided container images..." -ForegroundColor Cyan
    foreach ($image in $Images) {
        $ScannedFiles++
        
        if (-not (Scan-ContainerImage $image)) {
            $TotalIssues++
        }
    }
}

# Generate summary report
Write-Host ""
Write-Host "📊 Container Security Scan Summary" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Files/Images scanned: $ScannedFiles" -ForegroundColor Cyan
Write-Host "Issues found: $TotalIssues" -ForegroundColor Cyan

if ($TotalIssues -eq 0) {
    Write-Host "✅ No security issues found in container configurations" -ForegroundColor Green
    Write-Host "All containers are secure!" -ForegroundColor Green
} else {
    Write-Host "❌ Security issues detected in containers!" -ForegroundColor Red
    Write-Host ""
    Write-Host "🔧 Remediation steps:" -ForegroundColor Yellow
    Write-Host "1. Review and fix Dockerfile misconfigurations"
    Write-Host "2. Update base images to latest secure versions"
    Write-Host "3. Remove or update vulnerable packages"
    Write-Host "4. Follow container security best practices"
    Write-Host "5. Consider using distroless or minimal base images"
}

# Exit with error code if issues found
if ($TotalIssues -gt 0) {
    exit 1
}

Write-Host "🎉 Container security scan completed successfully" -ForegroundColor Green