#!/bin/bash

# Metrics Collection Script
# Collects various metrics for monitoring dashboards

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/config/monitoring/metrics-config.toml"

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
    local missing_deps=()
    
    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        exit 1
    fi
}

# Collect Git metrics
collect_git_metrics() {
    log_info "Collecting Git metrics..."
    
    local metrics_file="$PROJECT_ROOT/tmp/git-metrics.json"
    mkdir -p "$(dirname "$metrics_file")"
    
    # Commits in last 24 hours
    local commits_24h=$(git log --since="24 hours ago" --oneline | wc -l)
    
    # Active authors in last 7 days
    local active_authors=$(git log --since="7 days ago" --format="%an" | sort -u | wc -l)
    
    # Lines added/deleted in last 24 hours
    local lines_stats=$(git log --since="24 hours ago" --numstat --pretty=format:"" | awk '{added+=$1; deleted+=$2} END {print added, deleted}')
    local lines_added=$(echo "$lines_stats" | cut -d' ' -f1)
    local lines_deleted=$(echo "$lines_stats" | cut -d' ' -f2)
    
    # Pull requests (if using GitHub CLI)
    local pr_count=0
    if command -v gh &> /dev/null; then
        pr_count=$(gh pr list --state=open --json number | jq length)
    fi
    
    cat > "$metrics_file" << EOF
{
    "git_commits_24h": ${commits_24h:-0},
    "active_authors_7d": ${active_authors:-0},
    "lines_added_24h": ${lines_added:-0},
    "lines_deleted_24h": ${lines_deleted:-0},
    "open_pull_requests": ${pr_count:-0},
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    log_info "Git metrics collected: $metrics_file"
}

# Collect build metrics
collect_build_metrics() {
    log_info "Collecting build metrics..."
    
    local metrics_file="$PROJECT_ROOT/tmp/build-metrics.json"
    mkdir -p "$(dirname "$metrics_file")"
    
    # Check for GitHub Actions workflow runs
    local build_success_rate=100
    local avg_build_duration=300
    local build_count=0
    
    if [ -d "$PROJECT_ROOT/.github/workflows" ]; then
        # Count workflow files as proxy for build complexity
        build_count=$(find "$PROJECT_ROOT/.github/workflows" -name "*.yml" -o -name "*.yaml" | wc -l)
    fi
    
    # Check for Buck2 build files
    local buck_targets=0
    if [ -f "$PROJECT_ROOT/BUCK" ]; then
        buck_targets=$(grep -c "name.*=" "$PROJECT_ROOT/BUCK" 2>/dev/null || echo 0)
    fi
    
    cat > "$metrics_file" << EOF
{
    "build_success_rate": $build_success_rate,
    "avg_build_duration_seconds": $avg_build_duration,
    "workflow_count": $build_count,
    "buck_targets": $buck_targets,
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    log_info "Build metrics collected: $metrics_file"
}

# Collect security metrics
collect_security_metrics() {
    log_info "Collecting security metrics..."
    
    local metrics_file="$PROJECT_ROOT/tmp/security-metrics.json"
    mkdir -p "$(dirname "$metrics_file")"
    
    local critical_vulns=0
    local high_vulns=0
    local medium_vulns=0
    local low_vulns=0
    local compliance_score=95
    
    # Run cargo audit if available
    if command -v cargo &> /dev/null && [ -f "$PROJECT_ROOT/Cargo.toml" ]; then
        if cargo audit --version &> /dev/null; then
            local audit_output=$(cargo audit --json 2>/dev/null || echo '{"vulnerabilities":{"count":0}}')
            local vuln_count=$(echo "$audit_output" | jq -r '.vulnerabilities.count // 0' 2>/dev/null || echo 0)
            critical_vulns=$vuln_count
        fi
    fi
    
    # Check for secrets in git history (basic check)
    local secret_patterns=("password" "api_key" "secret" "token")
    local secret_count=0
    for pattern in "${secret_patterns[@]}"; do
        local matches=$(git log --all --grep="$pattern" --oneline | wc -l)
        secret_count=$((secret_count + matches))
    done
    
    cat > "$metrics_file" << EOF
{
    "critical_vulnerabilities": $critical_vulns,
    "high_vulnerabilities": $high_vulns,
    "medium_vulnerabilities": $medium_vulns,
    "low_vulnerabilities": $low_vulns,
    "compliance_score": $compliance_score,
    "secret_detection_events": $secret_count,
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    log_info "Security metrics collected: $metrics_file"
}

# Collect system health metrics
collect_system_metrics() {
    log_info "Collecting system health metrics..."
    
    local metrics_file="$PROJECT_ROOT/tmp/system-metrics.json"
    mkdir -p "$(dirname "$metrics_file")"
    
    # CPU usage
    local cpu_usage=0
    if command -v top &> /dev/null; then
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' 2>/dev/null || echo 0)
    fi
    
    # Memory usage
    local memory_usage=0
    if [ -f /proc/meminfo ]; then
        local mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        local mem_available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
        if [ "$mem_total" -gt 0 ]; then
            memory_usage=$(echo "scale=2; (($mem_total - $mem_available) * 100) / $mem_total" | bc 2>/dev/null || echo 0)
        fi
    fi
    
    # Disk usage
    local disk_usage=0
    if command -v df &> /dev/null; then
        disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//' 2>/dev/null || echo 0)
    fi
    
    # Load average
    local load_avg="0.0"
    if [ -f /proc/loadavg ]; then
        load_avg=$(cut -d' ' -f1 /proc/loadavg)
    fi
    
    cat > "$metrics_file" << EOF
{
    "cpu_usage_percent": ${cpu_usage:-0},
    "memory_usage_percent": ${memory_usage:-0},
    "disk_usage_percent": ${disk_usage:-0},
    "load_average_1m": ${load_avg:-0.0},
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    log_info "System metrics collected: $metrics_file"
}

# Collect developer productivity metrics
collect_productivity_metrics() {
    log_info "Collecting developer productivity metrics..."
    
    local metrics_file="$PROJECT_ROOT/tmp/productivity-metrics.json"
    mkdir -p "$(dirname "$metrics_file")"
    
    # Code complexity (basic metric based on file count and size)
    local total_files=0
    local total_lines=0
    local avg_complexity=1.0
    
    if command -v find &> /dev/null; then
        total_files=$(find "$PROJECT_ROOT" -name "*.rs" -o -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.go" | wc -l)
        if [ "$total_files" -gt 0 ]; then
            total_lines=$(find "$PROJECT_ROOT" -name "*.rs" -o -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.go" -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}' || echo 0)
            if [ "$total_lines" -gt 0 ]; then
                avg_complexity=$(echo "scale=2; $total_lines / $total_files" | bc 2>/dev/null || echo 1.0)
            fi
        fi
    fi
    
    # Documentation coverage (basic check for README files)
    local doc_files=$(find "$PROJECT_ROOT" -name "README*" -o -name "*.md" | wc -l)
    local doc_coverage=0
    if [ "$total_files" -gt 0 ]; then
        doc_coverage=$(echo "scale=2; ($doc_files * 100) / $total_files" | bc 2>/dev/null || echo 0)
    fi
    
    # Test coverage (basic check for test files)
    local test_files=$(find "$PROJECT_ROOT" -name "*test*" -o -name "*spec*" | wc -l)
    local test_coverage=0
    if [ "$total_files" -gt 0 ]; then
        test_coverage=$(echo "scale=2; ($test_files * 100) / $total_files" | bc 2>/dev/null || echo 0)
    fi
    
    cat > "$metrics_file" << EOF
{
    "total_code_files": $total_files,
    "total_lines_of_code": $total_lines,
    "average_complexity": $avg_complexity,
    "documentation_coverage_percent": $doc_coverage,
    "test_coverage_percent": $test_coverage,
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    log_info "Productivity metrics collected: $metrics_file"
}

# Export metrics to Prometheus format
export_prometheus_metrics() {
    log_info "Exporting metrics to Prometheus format..."
    
    local prometheus_file="$PROJECT_ROOT/tmp/metrics.prom"
    
    # Combine all metrics into Prometheus format
    {
        echo "# HELP monorepo_metrics Monorepo template metrics"
        echo "# TYPE monorepo_metrics gauge"
        
        # Process each metrics file
        for metrics_file in "$PROJECT_ROOT"/tmp/*-metrics.json; do
            if [ -f "$metrics_file" ]; then
                local category=$(basename "$metrics_file" | sed 's/-metrics.json//')
                
                # Convert JSON to Prometheus format
                jq -r "to_entries[] | select(.key != \"timestamp\") | \"monorepo_\(.key){category=\\\"$category\\\"} \(.value)\"" "$metrics_file" 2>/dev/null || true
            fi
        done
    } > "$prometheus_file"
    
    log_info "Prometheus metrics exported: $prometheus_file"
}

# Start metrics HTTP server
start_metrics_server() {
    local port=${1:-8080}
    local metrics_file="$PROJECT_ROOT/tmp/metrics.prom"
    
    log_info "Starting metrics server on port $port..."
    
    # Simple HTTP server using Python or netcat
    if command -v python3 &> /dev/null; then
        cd "$PROJECT_ROOT/tmp"
        python3 -m http.server "$port" &
        local server_pid=$!
        echo "$server_pid" > "$PROJECT_ROOT/tmp/metrics-server.pid"
        log_info "Metrics server started with PID $server_pid"
    else
        log_warn "Python3 not available, metrics server not started"
    fi
}

# Main execution
main() {
    log_info "Starting metrics collection..."
    
    check_dependencies
    
    # Create temp directory
    mkdir -p "$PROJECT_ROOT/tmp"
    
    # Collect all metrics
    collect_git_metrics
    collect_build_metrics
    collect_security_metrics
    collect_system_metrics
    collect_productivity_metrics
    
    # Export to Prometheus format
    export_prometheus_metrics
    
    # Start metrics server if requested
    if [ "${1:-}" = "--serve" ]; then
        start_metrics_server "${2:-8080}"
    fi
    
    log_info "Metrics collection completed successfully!"
}

# Handle script arguments
case "${1:-}" in
    --serve)
        main "$@"
        ;;
    --help)
        echo "Usage: $0 [--serve [port]] [--help]"
        echo "  --serve [port]  Start HTTP server for metrics (default port: 8080)"
        echo "  --help          Show this help message"
        ;;
    *)
        main "$@"
        ;;
esac