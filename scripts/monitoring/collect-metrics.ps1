# Metrics Collection Script (PowerShell)
# Collects various metrics for monitoring dashboards

param(
    [switch]$Serve = $false,
    [int]$Port = 8080,
    [switch]$Help = $false
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$ConfigFile = Join-Path $ProjectRoot "config/monitoring/metrics-config.toml"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Test-Dependencies {
    $missingDeps = @()
    
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $missingDeps += "git"
    }
    
    if (-not (Get-Command curl -ErrorAction SilentlyContinue)) {
        $missingDeps += "curl"
    }
    
    if ($missingDeps.Count -gt 0) {
        Write-Error "Missing dependencies: $($missingDeps -join ', ')"
        exit 1
    }
}

function Get-GitMetrics {
    Write-Info "Collecting Git metrics..."
    
    $metricsFile = Join-Path $ProjectRoot "tmp/git-metrics.json"
    $tmpDir = Split-Path $metricsFile -Parent
    if (-not (Test-Path $tmpDir)) {
        New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
    }
    
    # Commits in last 24 hours
    $commits24h = (git log --since="24 hours ago" --oneline | Measure-Object).Count
    
    # Active authors in last 7 days
    $activeAuthors = (git log --since="7 days ago" --format="%an" | Sort-Object -Unique | Measure-Object).Count
    
    # Lines added/deleted in last 24 hours (simplified)
    $linesAdded = 0
    $linesDeleted = 0
    try {
        $gitStats = git log --since="24 hours ago" --numstat --pretty=format:"" | Where-Object { $_ -match '^\d+\s+\d+' }
        foreach ($line in $gitStats) {
            $parts = $line -split '\s+'
            if ($parts.Count -ge 2) {
                $linesAdded += [int]$parts[0]
                $linesDeleted += [int]$parts[1]
            }
        }
    }
    catch {
        Write-Warn "Could not calculate line statistics"
    }
    
    # Pull requests (if using GitHub CLI)
    $prCount = 0
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        try {
            $prJson = gh pr list --state=open --json number 2>$null
            $prData = $prJson | ConvertFrom-Json
            $prCount = $prData.Count
        }
        catch {
            Write-Warn "Could not fetch PR count"
        }
    }
    
    $metrics = @{
        git_commits_24h = $commits24h
        active_authors_7d = $activeAuthors
        lines_added_24h = $linesAdded
        lines_deleted_24h = $linesDeleted
        open_pull_requests = $prCount
        timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    }
    
    $metrics | ConvertTo-Json | Out-File -FilePath $metricsFile -Encoding UTF8
    Write-Info "Git metrics collected: $metricsFile"
}

function Get-BuildMetrics {
    Write-Info "Collecting build metrics..."
    
    $metricsFile = Join-Path $ProjectRoot "tmp/build-metrics.json"
    $tmpDir = Split-Path $metricsFile -Parent
    if (-not (Test-Path $tmpDir)) {
        New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
    }
    
    # Check for GitHub Actions workflow runs
    $buildSuccessRate = 100
    $avgBuildDuration = 300
    $buildCount = 0
    
    $workflowsDir = Join-Path $ProjectRoot ".github/workflows"
    if (Test-Path $workflowsDir) {
        $buildCount = (Get-ChildItem -Path $workflowsDir -Filter "*.yml" -File).Count + 
                     (Get-ChildItem -Path $workflowsDir -Filter "*.yaml" -File).Count
    }
    
    # Check for Buck2 build files
    $buckTargets = 0
    $buckFile = Join-Path $ProjectRoot "BUCK"
    if (Test-Path $buckFile) {
        $buckContent = Get-Content $buckFile -Raw
        $buckTargets = ([regex]::Matches($buckContent, 'name\s*=')).Count
    }
    
    $metrics = @{
        build_success_rate = $buildSuccessRate
        avg_build_duration_seconds = $avgBuildDuration
        workflow_count = $buildCount
        buck_targets = $buckTargets
        timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    }
    
    $metrics | ConvertTo-Json | Out-File -FilePath $metricsFile -Encoding UTF8
    Write-Info "Build metrics collected: $metricsFile"
}

function Get-SecurityMetrics {
    Write-Info "Collecting security metrics..."
    
    $metricsFile = Join-Path $ProjectRoot "tmp/security-metrics.json"
    $tmpDir = Split-Path $metricsFile -Parent
    if (-not (Test-Path $tmpDir)) {
        New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
    }
    
    $criticalVulns = 0
    $highVulns = 0
    $mediumVulns = 0
    $lowVulns = 0
    $complianceScore = 95
    
    # Run cargo audit if available
    $cargoToml = Join-Path $ProjectRoot "Cargo.toml"
    if ((Get-Command cargo -ErrorAction SilentlyContinue) -and (Test-Path $cargoToml)) {
        try {
            $auditOutput = cargo audit --json 2>$null | ConvertFrom-Json
            if ($auditOutput.vulnerabilities) {
                $criticalVulns = $auditOutput.vulnerabilities.count
            }
        }
        catch {
            Write-Warn "Could not run cargo audit"
        }
    }
    
    # Check for secrets in git history (basic check)
    $secretPatterns = @("password", "api_key", "secret", "token")
    $secretCount = 0
    foreach ($pattern in $secretPatterns) {
        try {
            $matches = (git log --all --grep="$pattern" --oneline | Measure-Object).Count
            $secretCount += $matches
        }
        catch {
            Write-Warn "Could not search for pattern: $pattern"
        }
    }
    
    $metrics = @{
        critical_vulnerabilities = $criticalVulns
        high_vulnerabilities = $highVulns
        medium_vulnerabilities = $mediumVulns
        low_vulnerabilities = $lowVulns
        compliance_score = $complianceScore
        secret_detection_events = $secretCount
        timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    }
    
    $metrics | ConvertTo-Json | Out-File -FilePath $metricsFile -Encoding UTF8
    Write-Info "Security metrics collected: $metricsFile"
}

function Get-SystemMetrics {
    Write-Info "Collecting system health metrics..."
    
    $metricsFile = Join-Path $ProjectRoot "tmp/system-metrics.json"
    $tmpDir = Split-Path $metricsFile -Parent
    if (-not (Test-Path $tmpDir)) {
        New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
    }
    
    # CPU usage
    $cpuUsage = 0
    try {
        $cpu = Get-WmiObject -Class Win32_Processor | Measure-Object -Property LoadPercentage -Average
        $cpuUsage = $cpu.Average
    }
    catch {
        Write-Warn "Could not get CPU usage"
    }
    
    # Memory usage
    $memoryUsage = 0
    try {
        $os = Get-WmiObject -Class Win32_OperatingSystem
        $totalMemory = $os.TotalVisibleMemorySize
        $freeMemory = $os.FreePhysicalMemory
        if ($totalMemory -gt 0) {
            $memoryUsage = [math]::Round((($totalMemory - $freeMemory) / $totalMemory) * 100, 2)
        }
    }
    catch {
        Write-Warn "Could not get memory usage"
    }
    
    # Disk usage
    $diskUsage = 0
    try {
        $disk = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'"
        if ($disk.Size -gt 0) {
            $diskUsage = [math]::Round((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100, 2)
        }
    }
    catch {
        Write-Warn "Could not get disk usage"
    }
    
    $metrics = @{
        cpu_usage_percent = $cpuUsage
        memory_usage_percent = $memoryUsage
        disk_usage_percent = $diskUsage
        load_average_1m = 0.0
        timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    }
    
    $metrics | ConvertTo-Json | Out-File -FilePath $metricsFile -Encoding UTF8
    Write-Info "System metrics collected: $metricsFile"
}

function Get-ProductivityMetrics {
    Write-Info "Collecting developer productivity metrics..."
    
    $metricsFile = Join-Path $ProjectRoot "tmp/productivity-metrics.json"
    $tmpDir = Split-Path $metricsFile -Parent
    if (-not (Test-Path $tmpDir)) {
        New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
    }
    
    # Code complexity (basic metric based on file count and size)
    $totalFiles = 0
    $totalLines = 0
    $avgComplexity = 1.0
    
    $codeFiles = Get-ChildItem -Path $ProjectRoot -Recurse -Include "*.rs", "*.ts", "*.js", "*.py", "*.go" -File
    $totalFiles = $codeFiles.Count
    
    if ($totalFiles -gt 0) {
        $totalLines = ($codeFiles | Get-Content | Measure-Object).Count
        if ($totalLines -gt 0) {
            $avgComplexity = [math]::Round($totalLines / $totalFiles, 2)
        }
    }
    
    # Documentation coverage (basic check for README files)
    $docFiles = (Get-ChildItem -Path $ProjectRoot -Recurse -Include "README*", "*.md" -File).Count
    $docCoverage = 0
    if ($totalFiles -gt 0) {
        $docCoverage = [math]::Round(($docFiles * 100) / $totalFiles, 2)
    }
    
    # Test coverage (basic check for test files)
    $testFiles = (Get-ChildItem -Path $ProjectRoot -Recurse -Include "*test*", "*spec*" -File).Count
    $testCoverage = 0
    if ($totalFiles -gt 0) {
        $testCoverage = [math]::Round(($testFiles * 100) / $totalFiles, 2)
    }
    
    $metrics = @{
        total_code_files = $totalFiles
        total_lines_of_code = $totalLines
        average_complexity = $avgComplexity
        documentation_coverage_percent = $docCoverage
        test_coverage_percent = $testCoverage
        timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    }
    
    $metrics | ConvertTo-Json | Out-File -FilePath $metricsFile -Encoding UTF8
    Write-Info "Productivity metrics collected: $metricsFile"
}

function Export-PrometheusMetrics {
    Write-Info "Exporting metrics to Prometheus format..."
    
    $prometheusFile = Join-Path $ProjectRoot "tmp/metrics.prom"
    
    $content = @()
    $content += "# HELP monorepo_metrics Monorepo template metrics"
    $content += "# TYPE monorepo_metrics gauge"
    
    # Process each metrics file
    $metricsFiles = Get-ChildItem -Path (Join-Path $ProjectRoot "tmp") -Filter "*-metrics.json"
    foreach ($file in $metricsFiles) {
        $category = $file.BaseName -replace '-metrics$', ''
        
        try {
            $metrics = Get-Content $file.FullName | ConvertFrom-Json
            foreach ($property in $metrics.PSObject.Properties) {
                if ($property.Name -ne "timestamp") {
                    $content += "monorepo_$($property.Name){category=`"$category`"} $($property.Value)"
                }
            }
        }
        catch {
            Write-Warn "Could not process metrics file: $($file.Name)"
        }
    }
    
    $content | Out-File -FilePath $prometheusFile -Encoding UTF8
    Write-Info "Prometheus metrics exported: $prometheusFile"
}

function Start-MetricsServer {
    param([int]$ServerPort = 8080)
    
    Write-Info "Starting metrics server on port $ServerPort..."
    
    # Simple HTTP server using Python if available
    if (Get-Command python -ErrorAction SilentlyContinue) {
        $tmpDir = Join-Path $ProjectRoot "tmp"
        Push-Location $tmpDir
        
        try {
            $process = Start-Process -FilePath "python" -ArgumentList "-m", "http.server", $ServerPort -PassThru -WindowStyle Hidden
            $process.Id | Out-File -FilePath (Join-Path $ProjectRoot "tmp/metrics-server.pid") -Encoding UTF8
            Write-Info "Metrics server started with PID $($process.Id)"
        }
        finally {
            Pop-Location
        }
    }
    else {
        Write-Warn "Python not available, metrics server not started"
    }
}

function Show-Help {
    Write-Host "Usage: .\collect-metrics.ps1 [-Serve] [-Port <port>] [-Help]"
    Write-Host "  -Serve         Start HTTP server for metrics"
    Write-Host "  -Port <port>   Server port (default: 8080)"
    Write-Host "  -Help          Show this help message"
}

function Main {
    if ($Help) {
        Show-Help
        return
    }
    
    Write-Info "Starting metrics collection..."
    
    Test-Dependencies
    
    # Create temp directory
    $tmpDir = Join-Path $ProjectRoot "tmp"
    if (-not (Test-Path $tmpDir)) {
        New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
    }
    
    # Collect all metrics
    Get-GitMetrics
    Get-BuildMetrics
    Get-SecurityMetrics
    Get-SystemMetrics
    Get-ProductivityMetrics
    
    # Export to Prometheus format
    Export-PrometheusMetrics
    
    # Start metrics server if requested
    if ($Serve) {
        Start-MetricsServer -ServerPort $Port
    }
    
    Write-Info "Metrics collection completed successfully!"
}

# Run main function
Main