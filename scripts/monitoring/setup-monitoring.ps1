# Setup monitoring infrastructure for the monorepo
# This script sets up Prometheus, Grafana, and Jaeger for observability

param(
    [switch]$Setup,
    [switch]$Start,
    [switch]$Stop,
    [switch]$Status,
    [switch]$Restart
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

function Test-Docker {
    try {
        $null = docker --version
        $null = docker info 2>$null
        Write-Info "Docker is available"
        return $true
    }
    catch {
        Write-Error "Docker is required but not available or not running"
        return $false
    }
}

function New-MonitoringConfig {
    $ConfigDir = Join-Path $ProjectRoot "infra\monitoring"
    New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null

    # Prometheus configuration
    $PrometheusConfig = @'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alert_rules.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'monorepo-services'
    static_configs:
      - targets: ['host.docker.internal:9090']
    metrics_path: /metrics
    scrape_interval: 15s

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
'@
    $PrometheusConfig | Out-File -FilePath (Join-Path $ConfigDir "prometheus.yml") -Encoding UTF8

    # Prometheus alert rules
    $AlertRules = @'
groups:
  - name: system_alerts
    rules:
      - alert: HighCPUUsage
        expr: system_cpu_usage_percent > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage detected"
          description: "CPU usage is {{ $value }}% for more than 5 minutes"

      - alert: HighMemoryUsage
        expr: system_memory_usage_bytes / (8 * 1024 * 1024 * 1024) * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage detected"
          description: "Memory usage is {{ $value }}% for more than 5 minutes"

      - alert: HighDiskUsage
        expr: system_disk_usage_percent > 90
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "High disk usage detected"
          description: "Disk usage is {{ $value }}% for more than 2 minutes"

  - name: application_alerts
    rules:
      - alert: HighErrorRate
        expr: rate(http_errors_total[5m]) / rate(http_requests_total[5m]) * 100 > 5
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value }}% for more than 2 minutes"

      - alert: SlowResponseTime
        expr: histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m])) > 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Slow response time detected"
          description: "99th percentile response time is {{ $value }}s for more than 5 minutes"

  - name: security_alerts
    rules:
      - alert: HighAuthFailures
        expr: rate(auth_failures_total[5m]) > 10
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "High authentication failure rate"
          description: "Authentication failure rate is {{ $value }} per second"

      - alert: SecurityVulnerabilitiesFound
        expr: security_vulnerabilities_found > 0
        for: 0m
        labels:
          severity: warning
        annotations:
          summary: "Security vulnerabilities detected"
          description: "{{ $value }} security vulnerabilities found in latest scan"
'@
    $AlertRules | Out-File -FilePath (Join-Path $ConfigDir "alert_rules.yml") -Encoding UTF8

    # Alertmanager configuration
    $AlertmanagerConfig = @'
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alerts@company.com'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'

receivers:
  - name: 'web.hook'
    webhook_configs:
      - url: 'http://host.docker.internal:9093/api/v1/alerts'
        send_resolved: true

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'dev', 'instance']
'@
    $AlertmanagerConfig | Out-File -FilePath (Join-Path $ConfigDir "alertmanager.yml") -Encoding UTF8

    # Grafana datasource configuration
    $GrafanaDatasources = @'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true

  - name: Jaeger
    type: jaeger
    access: proxy
    url: http://jaeger:16686
'@
    $GrafanaDatasources | Out-File -FilePath (Join-Path $ConfigDir "grafana-datasources.yml") -Encoding UTF8

    # Docker Compose for monitoring stack
    $DockerCompose = @'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - ./alert_rules.yml:/etc/prometheus/alert_rules.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
      - '--web.enable-admin-api'

  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    ports:
      - "9093:9093"
    volumes:
      - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml
      - alertmanager_data:/alertmanager

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana-datasources.yml:/etc/grafana/provisioning/datasources/datasources.yml
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false

  jaeger:
    image: jaegertracing/all-in-one:latest
    container_name: jaeger
    ports:
      - "16686:16686"
      - "14268:14268"
      - "4317:4317"
      - "4318:4318"
    environment:
      - COLLECTOR_OTLP_ENABLED=true

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

volumes:
  prometheus_data:
  grafana_data:
  alertmanager_data:
'@
    $DockerCompose | Out-File -FilePath (Join-Path $ConfigDir "docker-compose.yml") -Encoding UTF8

    Write-Info "Monitoring configuration created in $ConfigDir"
}

function Start-Monitoring {
    $ConfigDir = Join-Path $ProjectRoot "infra\monitoring"
    $DockerComposePath = Join-Path $ConfigDir "docker-compose.yml"
    
    if (-not (Test-Path $DockerComposePath)) {
        Write-Error "Monitoring configuration not found. Run with -Setup first."
        exit 1
    }

    Write-Info "Starting monitoring stack..."
    
    Push-Location $ConfigDir
    try {
        docker-compose up -d
        Write-Info "Monitoring stack started successfully!"
        Write-Info "Access points:"
        Write-Info "  - Prometheus: http://localhost:9090"
        Write-Info "  - Grafana: http://localhost:3000 (admin/admin)"
        Write-Info "  - Jaeger: http://localhost:16686"
        Write-Info "  - Alertmanager: http://localhost:9093"
    }
    finally {
        Pop-Location
    }
}

function Stop-Monitoring {
    $ConfigDir = Join-Path $ProjectRoot "infra\monitoring"
    $DockerComposePath = Join-Path $ConfigDir "docker-compose.yml"
    
    if (-not (Test-Path $DockerComposePath)) {
        Write-Warn "Monitoring configuration not found"
        return
    }

    Write-Info "Stopping monitoring stack..."
    
    Push-Location $ConfigDir
    try {
        docker-compose down
        Write-Info "Monitoring stack stopped"
    }
    finally {
        Pop-Location
    }
}

function Show-Status {
    $ConfigDir = Join-Path $ProjectRoot "infra\monitoring"
    $DockerComposePath = Join-Path $ConfigDir "docker-compose.yml"
    
    if (-not (Test-Path $DockerComposePath)) {
        Write-Warn "Monitoring configuration not found"
        return
    }

    Push-Location $ConfigDir
    try {
        docker-compose ps
    }
    finally {
        Pop-Location
    }
}

# Main execution
if ($Setup) {
    if (-not (Test-Docker)) { exit 1 }
    New-MonitoringConfig
}
elseif ($Start) {
    if (-not (Test-Docker)) { exit 1 }
    Start-Monitoring
}
elseif ($Stop) {
    Stop-Monitoring
}
elseif ($Status) {
    Show-Status
}
elseif ($Restart) {
    Stop-Monitoring
    Start-Sleep -Seconds 2
    Start-Monitoring
}
else {
    Write-Host "Usage: .\setup-monitoring.ps1 [-Setup|-Start|-Stop|-Status|-Restart]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  -Setup    Create monitoring configuration files"
    Write-Host "  -Start    Start the monitoring stack"
    Write-Host "  -Stop     Stop the monitoring stack"
    Write-Host "  -Status   Show monitoring stack status"
    Write-Host "  -Restart  Restart the monitoring stack"
    exit 1
}