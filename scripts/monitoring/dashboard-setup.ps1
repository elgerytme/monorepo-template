# Dashboard Setup Script (PowerShell)
# Sets up monitoring dashboards for system health, build metrics, security, and developer productivity

param(
    [switch]$Force = $false
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

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
    Write-Info "Checking dependencies..."
    
    $missingDeps = @()
    
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        $missingDeps += "docker"
    }
    
    if (-not (Get-Command docker-compose -ErrorAction SilentlyContinue)) {
        $missingDeps += "docker-compose"
    }
    
    if ($missingDeps.Count -gt 0) {
        Write-Error "Missing dependencies: $($missingDeps -join ', ')"
        Write-Error "Please install the missing dependencies and try again."
        exit 1
    }
    
    Write-Info "All dependencies are installed."
}

function New-Directories {
    Write-Info "Creating dashboard directories..."
    
    $dirs = @(
        "$ProjectRoot/infra/monitoring/dashboards",
        "$ProjectRoot/infra/monitoring/grafana/provisioning/dashboards",
        "$ProjectRoot/infra/monitoring/grafana/provisioning/datasources",
        "$ProjectRoot/infra/monitoring/prometheus",
        "$ProjectRoot/config/monitoring"
    )
    
    foreach ($dir in $dirs) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
}

function New-MonitoringStack {
    Write-Info "Creating monitoring stack configuration..."
    
    $dockerComposeContent = @'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
    restart: unless-stopped

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    restart: unless-stopped

volumes:
  prometheus_data:
  grafana_data:
'@
    
    $dockerComposeContent | Out-File -FilePath "$ProjectRoot/infra/monitoring/docker-compose.yml" -Encoding UTF8
}

function Set-PrometheusConfig {
    Write-Info "Setting up Prometheus configuration..."
    
    $prometheusConfig = @'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "rules/*.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'build-metrics'
    static_configs:
      - targets: ['localhost:8080']
    metrics_path: '/metrics'
    scrape_interval: 30s

  - job_name: 'security-metrics'
    static_configs:
      - targets: ['localhost:8081']
    metrics_path: '/security/metrics'
    scrape_interval: 60s

  - job_name: 'developer-productivity'
    static_configs:
      - targets: ['localhost:8082']
    metrics_path: '/productivity/metrics'
    scrape_interval: 300s
'@
    
    $prometheusConfig | Out-File -FilePath "$ProjectRoot/infra/monitoring/prometheus/prometheus.yml" -Encoding UTF8
}

function Set-GrafanaDatasources {
    Write-Info "Setting up Grafana datasources..."
    
    $datasourceConfig = @'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
'@
    
    $datasourceConfig | Out-File -FilePath "$ProjectRoot/infra/monitoring/grafana/provisioning/datasources/prometheus.yml" -Encoding UTF8
}

function Set-GrafanaProvisioning {
    Write-Info "Setting up Grafana dashboard provisioning..."
    
    $provisioningConfig = @'
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
'@
    
    $provisioningConfig | Out-File -FilePath "$ProjectRoot/infra/monitoring/grafana/provisioning/dashboards/dashboards.yml" -Encoding UTF8
}

function Start-MonitoringStack {
    Write-Info "Deploying monitoring stack..."
    
    Push-Location "$ProjectRoot/infra/monitoring"
    
    try {
        if (Test-Path "docker-compose.yml") {
            docker-compose up -d
            Write-Info "Monitoring stack deployed successfully"
        } else {
            Write-Warn "docker-compose.yml not found. Creating monitoring stack configuration..."
            New-MonitoringStack
            docker-compose up -d
        }
    }
    finally {
        Pop-Location
    }
}

function Main {
    Write-Info "Starting dashboard setup..."
    
    Test-Dependencies
    New-Directories
    Set-PrometheusConfig
    Set-GrafanaDatasources
    Set-GrafanaProvisioning
    Start-MonitoringStack
    
    Write-Info "Dashboard setup completed successfully!"
    Write-Info "Access Grafana at: http://localhost:3000 (admin/admin)"
    Write-Info "Access Prometheus at: http://localhost:9090"
}

# Run main function
Main