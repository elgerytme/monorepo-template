#!/bin/bash
# Automated rollback mechanism for failed releases
# Provides safe rollback capabilities for deployment failures

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Configuration
ROLLBACK_DIR="$REPO_ROOT/.rollback"
DEPLOYMENT_LOG="$ROLLBACK_DIR/deployment.log"
ROLLBACK_LOG="$ROLLBACK_DIR/rollback.log"
HEALTH_CHECK_TIMEOUT=300  # 5 minutes
HEALTH_CHECK_INTERVAL=10  # 10 seconds

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" >> "$ROLLBACK_LOG"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $1" >> "$ROLLBACK_LOG"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARNING] $1" >> "$ROLLBACK_LOG"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >> "$ROLLBACK_LOG"
}

# Ensure rollback directory exists
ensure_rollback_dir() {
    mkdir -p "$ROLLBACK_DIR"
    touch "$DEPLOYMENT_LOG" "$ROLLBACK_LOG"
}

# Record deployment state
record_deployment() {
    local version="$1"
    local deployment_type="${2:-standard}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    log_info "Recording deployment of version $version"
    
    # Create deployment record
    local deployment_record=$(cat << EOF
{
    "version": "$version",
    "deployment_type": "$deployment_type",
    "timestamp": "$timestamp",
    "git_commit": "$(git rev-parse HEAD)",
    "git_branch": "$(git branch --show-current)",
    "previous_version": "$(get_previous_deployment_version)",
    "rollback_available": true,
    "health_checks": []
}
EOF
    )
    
    echo "$deployment_record" > "$ROLLBACK_DIR/current_deployment.json"
    echo "$deployment_record" >> "$DEPLOYMENT_LOG"
    
    log_success "Deployment recorded for version $version"
}

# Get previous deployment version
get_previous_deployment_version() {
    if [[ -f "$ROLLBACK_DIR/current_deployment.json" ]]; then
        jq -r '.version' "$ROLLBACK_DIR/current_deployment.json" 2>/dev/null || echo "unknown"
    else
        echo "none"
    fi
}

# Get current deployment info
get_current_deployment() {
    if [[ -f "$ROLLBACK_DIR/current_deployment.json" ]]; then
        cat "$ROLLBACK_DIR/current_deployment.json"
    else
        echo "{}"
    fi
}

# Health check function (customizable)
perform_health_check() {
    local check_type="${1:-basic}"
    local endpoint="${2:-http://localhost:8080/health}"
    
    case "$check_type" in
        "basic")
            # Basic HTTP health check
            if command -v curl &> /dev/null; then
                curl -f -s "$endpoint" > /dev/null
            elif command -v wget &> /dev/null; then
                wget -q --spider "$endpoint"
            else
                log_warning "No HTTP client available for health check"
                return 0  # Assume healthy if no client available
            fi
            ;;
        "database")
            # Database connectivity check (example)
            # This would be customized based on your database
            log_info "Performing database health check"
            # Add your database health check logic here
            return 0
            ;;
        "service")
            # Service-specific health check
            log_info "Performing service health check"
            # Add your service health check logic here
            return 0
            ;;
        *)
            log_warning "Unknown health check type: $check_type"
            return 0
            ;;
    esac
}

# Monitor deployment health
monitor_deployment_health() {
    local version="$1"
    local health_checks="${2:-basic}"
    local timeout="${3:-$HEALTH_CHECK_TIMEOUT}"
    
    log_info "Monitoring deployment health for version $version"
    log_info "Health checks: $health_checks, timeout: ${timeout}s"
    
    local start_time=$(date +%s)
    local end_time=$((start_time + timeout))
    local check_count=0
    local failed_checks=0
    
    while [[ $(date +%s) -lt $end_time ]]; do
        ((check_count++))
        local all_checks_passed=true
        
        # Parse health checks (comma-separated)
        IFS=',' read -ra CHECKS <<< "$health_checks"
        for check in "${CHECKS[@]}"; do
            check=$(echo "$check" | xargs)  # Trim whitespace
            
            log_info "Performing health check: $check (attempt $check_count)"
            
            if ! perform_health_check "$check"; then
                log_warning "Health check failed: $check"
                all_checks_passed=false
                ((failed_checks++))
            else
                log_success "Health check passed: $check"
            fi
        done
        
        if [[ "$all_checks_passed" == true ]]; then
            log_success "All health checks passed for version $version"
            update_deployment_status "$version" "healthy"
            return 0
        fi
        
        # If too many consecutive failures, trigger rollback
        if [[ $failed_checks -ge 3 ]]; then
            log_error "Multiple consecutive health check failures detected"
            update_deployment_status "$version" "unhealthy"
            return 1
        fi
        
        sleep "$HEALTH_CHECK_INTERVAL"
    done
    
    log_error "Health check monitoring timed out for version $version"
    update_deployment_status "$version" "timeout"
    return 1
}

# Update deployment status
update_deployment_status() {
    local version="$1"
    local status="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ -f "$ROLLBACK_DIR/current_deployment.json" ]]; then
        # Update existing deployment record
        jq --arg status "$status" --arg timestamp "$timestamp" \
           '.status = $status | .last_health_check = $timestamp' \
           "$ROLLBACK_DIR/current_deployment.json" > "$ROLLBACK_DIR/current_deployment.json.tmp"
        mv "$ROLLBACK_DIR/current_deployment.json.tmp" "$ROLLBACK_DIR/current_deployment.json"
    fi
    
    log_info "Updated deployment status to: $status"
}

# Perform rollback to previous version
perform_rollback() {
    local target_version="${1:-}"
    local rollback_type="${2:-git}"
    
    log_info "Initiating rollback process"
    
    # Get current deployment info
    local current_deployment
    current_deployment=$(get_current_deployment)
    local current_version
    current_version=$(echo "$current_deployment" | jq -r '.version // "unknown"')
    
    # Determine target version for rollback
    if [[ -z "$target_version" ]]; then
        target_version=$(echo "$current_deployment" | jq -r '.previous_version // "unknown"')
        if [[ "$target_version" == "unknown" || "$target_version" == "none" ]]; then
            log_error "No previous version available for rollback"
            return 1
        fi
    fi
    
    log_info "Rolling back from version $current_version to $target_version"
    
    # Create rollback record
    local rollback_record=$(cat << EOF
{
    "rollback_timestamp": "$(date '+%Y-%m-%d %H:%M:%S')",
    "from_version": "$current_version",
    "to_version": "$target_version",
    "rollback_type": "$rollback_type",
    "reason": "automated_rollback",
    "initiated_by": "rollback_manager"
}
EOF
    )
    
    echo "$rollback_record" > "$ROLLBACK_DIR/rollback_in_progress.json"
    
    # Perform rollback based on type
    case "$rollback_type" in
        "git")
            perform_git_rollback "$target_version"
            ;;
        "container")
            perform_container_rollback "$target_version"
            ;;
        "database")
            perform_database_rollback "$target_version"
            ;;
        *)
            log_error "Unknown rollback type: $rollback_type"
            return 1
            ;;
    esac
    
    local rollback_result=$?
    
    if [[ $rollback_result -eq 0 ]]; then
        log_success "Rollback completed successfully"
        
        # Update deployment record
        record_deployment "$target_version" "rollback"
        
        # Clean up rollback in progress file
        rm -f "$ROLLBACK_DIR/rollback_in_progress.json"
        
        # Archive rollback record
        echo "$rollback_record" >> "$ROLLBACK_DIR/rollback_history.json"
        
    else
        log_error "Rollback failed"
        
        # Update rollback record with failure
        jq '.status = "failed"' "$ROLLBACK_DIR/rollback_in_progress.json" > "$ROLLBACK_DIR/rollback_failed.json"
        rm -f "$ROLLBACK_DIR/rollback_in_progress.json"
        
        return 1
    fi
}

# Git-based rollback
perform_git_rollback() {
    local target_version="$1"
    
    log_info "Performing git rollback to version $target_version"
    
    # Stash any uncommitted changes
    if ! git diff --quiet || ! git diff --cached --quiet; then
        log_info "Stashing uncommitted changes"
        git stash push -m "Pre-rollback stash $(date '+%Y-%m-%d %H:%M:%S')"
    fi
    
    # Checkout target version
    if git checkout "v$target_version" 2>/dev/null; then
        log_success "Successfully checked out version $target_version"
        return 0
    elif git checkout "$target_version" 2>/dev/null; then
        log_success "Successfully checked out commit $target_version"
        return 0
    else
        log_error "Failed to checkout version $target_version"
        return 1
    fi
}

# Container-based rollback
perform_container_rollback() {
    local target_version="$1"
    
    log_info "Performing container rollback to version $target_version"
    
    # This is a placeholder for container rollback logic
    # You would implement your specific container orchestration rollback here
    # Examples: Docker Compose, Kubernetes, etc.
    
    log_warning "Container rollback not implemented - add your container orchestration logic here"
    return 0
}

# Database rollback (migrations)
perform_database_rollback() {
    local target_version="$1"
    
    log_info "Performing database rollback to version $target_version"
    
    # This is a placeholder for database rollback logic
    # You would implement your specific database migration rollback here
    
    log_warning "Database rollback not implemented - add your database migration logic here"
    return 0
}

# Automatic rollback on failure
auto_rollback_on_failure() {
    local version="$1"
    local health_checks="${2:-basic}"
    local timeout="${3:-$HEALTH_CHECK_TIMEOUT}"
    
    log_info "Starting automatic rollback monitoring for version $version"
    
    # Monitor deployment health
    if ! monitor_deployment_health "$version" "$health_checks" "$timeout"; then
        log_error "Deployment health check failed, initiating automatic rollback"
        
        if perform_rollback; then
            log_success "Automatic rollback completed successfully"
            
            # Verify rollback health
            local previous_version
            previous_version=$(get_current_deployment | jq -r '.version')
            
            if monitor_deployment_health "$previous_version" "$health_checks" 60; then
                log_success "Rollback deployment is healthy"
                return 0
            else
                log_error "Rollback deployment is also unhealthy - manual intervention required"
                return 1
            fi
        else
            log_error "Automatic rollback failed - manual intervention required"
            return 1
        fi
    else
        log_success "Deployment is healthy, no rollback needed"
        return 0
    fi
}

# Show rollback status
show_rollback_status() {
    log_info "Rollback Manager Status"
    echo "========================"
    
    if [[ -f "$ROLLBACK_DIR/current_deployment.json" ]]; then
        echo "Current Deployment:"
        jq '.' "$ROLLBACK_DIR/current_deployment.json"
        echo
    fi
    
    if [[ -f "$ROLLBACK_DIR/rollback_in_progress.json" ]]; then
        echo "Rollback In Progress:"
        jq '.' "$ROLLBACK_DIR/rollback_in_progress.json"
        echo
    fi
    
    if [[ -f "$ROLLBACK_DIR/rollback_history.json" ]]; then
        echo "Recent Rollbacks:"
        tail -n 5 "$ROLLBACK_DIR/rollback_history.json" | jq '.'
    fi
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
    record <version> [type]           Record deployment of version
    monitor <version> [checks] [timeout]  Monitor deployment health
    rollback [version] [type]         Perform rollback to version
    auto-rollback <version> [checks] [timeout]  Monitor and auto-rollback on failure
    status                           Show rollback status
    help                            Show this help message

Examples:
    $0 record 1.2.3                 # Record deployment of version 1.2.3
    $0 monitor 1.2.3 basic,database 300  # Monitor with health checks for 5 minutes
    $0 rollback 1.2.2                # Rollback to version 1.2.2
    $0 auto-rollback 1.2.3 basic 300 # Monitor and auto-rollback if unhealthy

EOF
}

# Main script logic
main() {
    ensure_rollback_dir
    
    case "${1:-help}" in
        "record")
            if [[ -z "${2:-}" ]]; then
                log_error "Version required for record command"
                show_usage
                exit 1
            fi
            record_deployment "$2" "${3:-standard}"
            ;;
        "monitor")
            if [[ -z "${2:-}" ]]; then
                log_error "Version required for monitor command"
                show_usage
                exit 1
            fi
            monitor_deployment_health "$2" "${3:-basic}" "${4:-$HEALTH_CHECK_TIMEOUT}"
            ;;
        "rollback")
            perform_rollback "$2" "${3:-git}"
            ;;
        "auto-rollback")
            if [[ -z "${2:-}" ]]; then
                log_error "Version required for auto-rollback command"
                show_usage
                exit 1
            fi
            auto_rollback_on_failure "$2" "${3:-basic}" "${4:-$HEALTH_CHECK_TIMEOUT}"
            ;;
        "status")
            show_rollback_status
            ;;
        "help"|"--help"|"-h")
            show_usage
            ;;
        *)
            log_error "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi