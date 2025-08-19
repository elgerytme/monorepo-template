#!/bin/bash
# Setup monitoring infrastructure for the monorepo
# This script sets up Prometheus, Grafana, and Jaeger for observability

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is available
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is required but not installed"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        exit 1
    fi

    log_info "Docker is available"
}

# Create monitoring configuration
create_monitoring_config() {
    local config_dir="$PROJECT_ROOT/infra/monitoring"
    mkdir -p "$config_dir"

    # Prometheus configuration
    cat > "$config_dir/prometheus.yml" << 'EOF'
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
EOF

    # Prometheus alert rules
    cat > "$config_dir/alert_rules.yml" << 'EOF'
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
EOF

    # Alertmanager configuration
    cat > "$config_dir/alertmanager.yml" << 'EOF'
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
EOF

    # Grafana datasource configuration
    cat > "$config_dir/grafana-datasources.yml" << 'EOF'
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
EOF

    # Docker Compose for monitoring stack
    cat > "$config_dir/docker-compose.yml" << 'EOF'
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
EOF

    log_info "Monitoring configuration created in $config_dir"
}

# Start monitoring stack
start_monitoring() {
    local config_dir="$PROJECT_ROOT/infra/monitoring"
    
    if [ ! -f "$config_dir/docker-compose.yml" ]; then
        log_error "Monitoring configuration not found. Run with --setup first."
        exit 1
    fi

    log_info "Starting monitoring stack..."
    
    cd "$config_dir"
    docker-compose up -d

    log_info "Monitoring stack started successfully!"
    log_info "Access points:"
    log_info "  - Prometheus: http://localhost:9090"
    log_info "  - Grafana: http://localhost:3000 (admin/admin)"
    log_info "  - Jaeger: http://localhost:16686"
    log_info "  - Alertmanager: http://localhost:9093"
}

# Stop monitoring stack
stop_monitoring() {
    local config_dir="$PROJECT_ROOT/infra/monitoring"
    
    if [ ! -f "$config_dir/docker-compose.yml" ]; then
        log_warn "Monitoring configuration not found"
        return 0
    fi

    log_info "Stopping monitoring stack..."
    
    cd "$config_dir"
    docker-compose down

    log_info "Monitoring stack stopped"
}

# Show monitoring status
show_status() {
    local config_dir="$PROJECT_ROOT/infra/monitoring"
    
    if [ ! -f "$config_dir/docker-compose.yml" ]; then
        log_warn "Monitoring configuration not found"
        return 0
    fi

    cd "$config_dir"
    docker-compose ps
}

# Main function
main() {
    case "${1:-}" in
        --setup)
            check_docker
            create_monitoring_config
            ;;
        --start)
            check_docker
            start_monitoring
            ;;
        --stop)
            stop_monitoring
            ;;
        --status)
            show_status
            ;;
        --restart)
            stop_monitoring
            sleep 2
            start_monitoring
            ;;
        *)
            echo "Usage: $0 [--setup|--start|--stop|--status|--restart]"
            echo ""
            echo "Commands:"
            echo "  --setup    Create monitoring configuration files"
            echo "  --start    Start the monitoring stack"
            echo "  --stop     Stop the monitoring stack"
            echo "  --status   Show monitoring stack status"
            echo "  --restart  Restart the monitoring stack"
            exit 1
            ;;
    esac
}

main "$@"