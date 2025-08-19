#!/bin/bash
# Release orchestration script
# Coordinates the entire release process including versioning, signing, and rollback capabilities

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Import other release scripts
source "$SCRIPT_DIR/version-manager.sh"
source "$SCRIPT_DIR/release-notes-generator.sh"
source "$SCRIPT_DIR/artifact-signing.sh"
source "$SCRIPT_DIR/rollback-manager.sh"

# Configuration
RELEASE_CONFIG="$REPO_ROOT/.release-config.json"
ARTIFACTS_DIR="$REPO_ROOT/artifacts"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[ORCHESTRATOR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[ORCHESTRATOR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[ORCHESTRATOR]${NC} $1"
}

log_error() {
    echo -e "${RED}[ORCHESTRATOR]${NC} $1"
}

# Load release configuration
load_release_config() {
    if [[ -f "$RELEASE_CONFIG" ]]; then
        log_info "Loading release configuration from $RELEASE_CONFIG"
    else
        log_info "Creating default release configuration"
        create_default_config
    fi
}

# Create default release configuration
create_default_config() {
    cat > "$RELEASE_CONFIG" << EOF
{
    "release": {
        "auto_version": true,
        "generate_release_notes": true,
        "sign_artifacts": true,
        "enable_rollback": true,
        "health_checks": ["basic"],
        "health_check_timeout": 300,
        "pre_release_hooks": [],
        "post_release_hooks": [],
        "notification": {
            "enabled": false,
            "webhook_url": "",
            "channels": []
        }
    },
    "artifacts": {
        "build_command": "just build-all",
        "output_directory": "./artifacts",
        "include_patterns": ["*.tar.gz", "*.zip", "*.deb", "*.rpm"],
        "exclude_patterns": ["*.tmp", "*.log"]
    },
    "signing": {
        "gpg_key_id": "",
        "cosign_enabled": true,
        "verify_signatures": true
    },
    "rollback": {
        "enabled": true,
        "auto_rollback": true,
        "rollback_types": ["git", "container"],
        "health_check_retries": 3
    }
}
EOF
    log_success "Created default release configuration at $RELEASE_CONFIG"
}

# Get configuration value
get_config() {
    local key="$1"
    local default="${2:-}"
    
    if [[ -f "$RELEASE_CONFIG" ]] && command -v jq &> /dev/null; then
        jq -r "$key // \"$default\"" "$RELEASE_CONFIG" 2>/dev/null || echo "$default"
    else
        echo "$default"
    fi
}

# Build artifacts
build_artifacts() {
    log_info "Building release artifacts"
    
    local build_command
    build_command=$(get_config '.artifacts.build_command' 'just build-all')
    
    local output_dir
    output_dir=$(get_config '.artifacts.output_directory' './artifacts')
    
    # Ensure output directory exists
    mkdir -p "$output_dir"
    
    # Run build command
    log_info "Running build command: $build_command"
    if eval "$build_command"; then
        log_success "Artifacts built successfully"
        
        # List built artifacts
        log_info "Built artifacts:"
        find "$output_dir" -type f -name "*.tar.gz" -o -name "*.zip" -o -name "*.deb" -o -name "*.rpm" | while read -r artifact; do
            log_info "  - $(basename "$artifact")"
        done
        
        return 0
    else
        log_error "Failed to build artifacts"
        return 1
    fi
}

# Run pre-release hooks
run_pre_release_hooks() {
    local hooks
    hooks=$(get_config '.release.pre_release_hooks[]' '')
    
    if [[ -n "$hooks" ]]; then
        log_info "Running pre-release hooks"
        
        while IFS= read -r hook; do
            if [[ -n "$hook" ]]; then
                log_info "Executing hook: $hook"
                if eval "$hook"; then
                    log_success "Hook completed: $hook"
                else
                    log_error "Hook failed: $hook"
                    return 1
                fi
            fi
        done <<< "$hooks"
    fi
}

# Run post-release hooks
run_post_release_hooks() {
    local hooks
    hooks=$(get_config '.release.post_release_hooks[]' '')
    
    if [[ -n "$hooks" ]]; then
        log_info "Running post-release hooks"
        
        while IFS= read -r hook; do
            if [[ -n "$hook" ]]; then
                log_info "Executing hook: $hook"
                if eval "$hook"; then
                    log_success "Hook completed: $hook"
                else
                    log_warning "Hook failed (non-critical): $hook"
                fi
            fi
        done <<< "$hooks"
    fi
}

# Send notification
send_notification() {
    local message="$1"
    local webhook_url
    webhook_url=$(get_config '.release.notification.webhook_url' '')
    
    local notification_enabled
    notification_enabled=$(get_config '.release.notification.enabled' 'false')
    
    if [[ "$notification_enabled" == "true" && -n "$webhook_url" ]]; then
        log_info "Sending release notification"
        
        local payload=$(cat << EOF
{
    "text": "$message",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
        )
        
        if command -v curl &> /dev/null; then
            curl -X POST -H "Content-Type: application/json" -d "$payload" "$webhook_url" &>/dev/null || true
        fi
    fi
}

# Perform full release
perform_release() {
    local increment_type="${1:-auto}"
    local skip_build="${2:-false}"
    
    log_info "Starting release process with increment type: $increment_type"
    
    # Load configuration
    load_release_config
    
    # Run pre-release hooks
    if ! run_pre_release_hooks; then
        log_error "Pre-release hooks failed, aborting release"
        return 1
    fi
    
    # Build artifacts (unless skipped)
    if [[ "$skip_build" != "true" ]]; then
        if ! build_artifacts; then
            log_error "Artifact build failed, aborting release"
            return 1
        fi
    fi
    
    # Version management
    local auto_version
    auto_version=$(get_config '.release.auto_version' 'true')
    
    local new_version
    if [[ "$auto_version" == "true" ]]; then
        log_info "Performing automatic version bump"
        new_version=$(bump_version "$increment_type")
        if [[ -z "$new_version" ]]; then
            log_error "Version bump failed"
            return 1
        fi
    else
        log_warning "Automatic versioning disabled, using current version"
        new_version=$(get_current_version)
    fi
    
    log_success "Release version: $new_version"
    
    # Generate release notes
    local generate_notes
    generate_notes=$(get_config '.release.generate_release_notes' 'true')
    
    if [[ "$generate_notes" == "true" ]]; then
        log_info "Generating release notes"
        if ! generate_release "$new_version"; then
            log_warning "Release notes generation failed (non-critical)"
        fi
    fi
    
    # Sign artifacts
    local sign_artifacts_enabled
    sign_artifacts_enabled=$(get_config '.release.sign_artifacts' 'true')
    
    if [[ "$sign_artifacts_enabled" == "true" ]]; then
        log_info "Signing release artifacts"
        if ! sign_artifacts "$ARTIFACTS_DIR"; then
            log_error "Artifact signing failed"
            return 1
        fi
    fi
    
    # Record deployment for rollback capability
    local rollback_enabled
    rollback_enabled=$(get_config '.rollback.enabled' 'true')
    
    if [[ "$rollback_enabled" == "true" ]]; then
        log_info "Recording deployment for rollback capability"
        record_deployment "$new_version" "release"
    fi
    
    # Run post-release hooks
    run_post_release_hooks
    
    # Send notification
    send_notification "Release $new_version completed successfully"
    
    log_success "Release $new_version completed successfully!"
    
    # Start health monitoring if auto-rollback is enabled
    local auto_rollback
    auto_rollback=$(get_config '.rollback.auto_rollback' 'true')
    
    if [[ "$auto_rollback" == "true" ]]; then
        log_info "Starting automatic health monitoring and rollback capability"
        
        local health_checks
        health_checks=$(get_config '.release.health_checks[]' 'basic' | tr '\n' ',' | sed 's/,$//')
        
        local health_timeout
        health_timeout=$(get_config '.release.health_check_timeout' '300')
        
        # Run health monitoring in background
        (
            sleep 30  # Give deployment time to start
            auto_rollback_on_failure "$new_version" "$health_checks" "$health_timeout"
        ) &
        
        log_info "Health monitoring started in background (PID: $!)"
    fi
    
    return 0
}

# Perform rollback
perform_rollback_release() {
    local target_version="${1:-}"
    local rollback_type="${2:-git}"
    
    log_info "Starting rollback process"
    
    # Load configuration
    load_release_config
    
    # Check if rollback is enabled
    local rollback_enabled
    rollback_enabled=$(get_config '.rollback.enabled' 'true')
    
    if [[ "$rollback_enabled" != "true" ]]; then
        log_error "Rollback is disabled in configuration"
        return 1
    fi
    
    # Perform rollback
    if perform_rollback "$target_version" "$rollback_type"; then
        log_success "Rollback completed successfully"
        
        # Send notification
        local current_version
        current_version=$(get_current_version)
        send_notification "Rollback to version $current_version completed successfully"
        
        return 0
    else
        log_error "Rollback failed"
        send_notification "Rollback failed - manual intervention required"
        return 1
    fi
}

# Show release status
show_release_status() {
    log_info "Release System Status"
    echo "====================="
    
    # Current version
    local current_version
    current_version=$(get_current_version)
    echo "Current Version: $current_version"
    
    # Git status
    echo "Git Branch: $(git branch --show-current 2>/dev/null || echo 'unknown')"
    echo "Git Commit: $(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
    
    # Rollback status
    echo ""
    show_rollback_status
    
    # Configuration
    echo ""
    echo "Configuration:"
    if [[ -f "$RELEASE_CONFIG" ]]; then
        jq '.' "$RELEASE_CONFIG" 2>/dev/null || echo "Invalid JSON configuration"
    else
        echo "No configuration file found"
    fi
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
    release [major|minor|patch|auto] [--skip-build]  Perform full release
    rollback [version] [type]                        Rollback to previous version
    build                                           Build artifacts only
    sign                                            Sign artifacts only
    status                                          Show release system status
    config                                          Show/edit configuration
    help                                            Show this help message

Examples:
    $0 release                          # Auto-detect version increment and release
    $0 release minor                    # Release with minor version bump
    $0 release auto --skip-build        # Release without building artifacts
    $0 rollback                         # Rollback to previous version
    $0 rollback 1.2.2                   # Rollback to specific version
    $0 build                            # Build artifacts only
    $0 sign                             # Sign existing artifacts
    $0 status                           # Show system status

EOF
}

# Main script logic
main() {
    case "${1:-help}" in
        "release")
            local increment_type="${2:-auto}"
            local skip_build="false"
            if [[ "${3:-}" == "--skip-build" ]]; then
                skip_build="true"
            fi
            perform_release "$increment_type" "$skip_build"
            ;;
        "rollback")
            perform_rollback_release "$2" "${3:-git}"
            ;;
        "build")
            load_release_config
            build_artifacts
            ;;
        "sign")
            load_release_config
            sign_artifacts "$ARTIFACTS_DIR"
            ;;
        "status")
            show_release_status
            ;;
        "config")
            if [[ -f "$RELEASE_CONFIG" ]]; then
                jq '.' "$RELEASE_CONFIG"
            else
                create_default_config
            fi
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