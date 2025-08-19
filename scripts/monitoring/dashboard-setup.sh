#!/bin/bash

# Dashboard Setup Script
# Sets up monitoring dashboards for system health, build metrics, security, and developer productivity

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

# Check if required tools are installed
check_dependencies() {
    log_info "Checking dependencies..."
    
    local missing_deps=()
    
    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        missing_deps+=("docker-compose")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_error "Please install the missing dependencies and try again."
        exit 1
    fi
    
    log_info "All dependencies are installed."
}

# Create dashboard configuration directories
create_directories() {
    log_info "Creating dashboard directories..."
    
    mkdir -p "$PROJECT_ROOT/infra/monitoring/dashboards"
    mkdir -p "$PROJECT_ROOT/infra/monitoring/grafana/provisioning/dashboards"
    mkdir -p "$PROJECT_ROOT/infra/monitoring/grafana/provisioning/datasources"
    mkdir -p "$PROJECT_ROOT/infra/monitoring/prometheus"
    mkdir -p "$PROJECT_ROOT/config/monitoring"
}

# Deploy monitoring stack
deploy_monitoring_stack() {
    log_info "Deploying monitoring stack..."
    
    cd "$PROJECT_ROOT/infra/monitoring"
    
    if [ -f "docker-compose.yml" ]; then
        docker-compose up -d
        log_info "Monitoring stack deployed successfully"
    else
        log_warn "docker-compose.yml not found. Creating monitoring stack configuration..."
        create_monitoring_stack
        docker-compose up -d
    fi
}

# Create monitoring stack configuration
create_monitoring_stack() {
    log_info "Creating monitoring stack configuration..."
    
    cat > "$PROJECT_ROOT/infra/monitoring/docker-compose.yml" << 'EOF'
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
EOF
}

# Setup Prometheus configuration
setup_prometheus() {
    log_info "Setting up Prometheus configuration..."
    
    cat > "$PROJECT_ROOT/infra/monitoring/prometheus/prometheus.yml" << 'EOF'
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
EOF
}

# Setup Grafana datasources
setup_grafana_datasources() {
    log_info "Setting up Grafana datasources..."
    
    cat > "$PROJECT_ROOT/infra/monitoring/grafana/provisioning/datasources/prometheus.yml" << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF
}

# Setup Grafana dashboard provisioning
setup_grafana_provisioning() {
    log_info "Setting up Grafana dashboard provisioning..."
    
    cat > "$PROJECT_ROOT/infra/monitoring/grafana/provisioning/dashboards/dashboards.yml" << 'EOF'
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
EOF
}

# Main execution
main() {
    log_info "Starting dashboard setup..."
    
    check_dependencies
    create_directories
    setup_prometheus
    setup_grafana_datasources
    setup_grafana_provisioning
    deploy_monitoring_stack
    
    log_info "Dashboard setup completed successfully!"
    log_info "Access Grafana at: http://localhost:3000 (admin/admin)"
    log_info "Access Prometheus at: http://localhost:9090"
}

# Run main function
main "$@"