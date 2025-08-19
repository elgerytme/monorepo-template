#!/bin/bash
# Automated semantic versioning system
# Follows semantic versioning (semver) principles

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Configuration
VERSION_FILE="$REPO_ROOT/VERSION"
CHANGELOG_FILE="$REPO_ROOT/CHANGELOG.md"
RELEASE_NOTES_DIR="$REPO_ROOT/releases"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get current version from VERSION file or git tags
get_current_version() {
    if [[ -f "$VERSION_FILE" ]]; then
        cat "$VERSION_FILE"
    else
        # Fallback to git tags
        git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "0.0.0"
    fi
}

# Parse version into components
parse_version() {
    local version="$1"
    echo "$version" | sed -E 's/([0-9]+)\.([0-9]+)\.([0-9]+).*/\1 \2 \3/'
}

# Increment version based on type
increment_version() {
    local current_version="$1"
    local increment_type="$2"
    
    read -r major minor patch <<< "$(parse_version "$current_version")"
    
    case "$increment_type" in
        "major")
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        "minor")
            minor=$((minor + 1))
            patch=0
            ;;
        "patch")
            patch=$((patch + 1))
            ;;
        *)
            log_error "Invalid increment type: $increment_type. Use major, minor, or patch."
            exit 1
            ;;
    esac
    
    echo "$major.$minor.$patch"
}

# Analyze commits to determine version increment type
analyze_commits() {
    local last_tag
    last_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    
    local commit_range
    if [[ -n "$last_tag" ]]; then
        commit_range="$last_tag..HEAD"
    else
        commit_range="HEAD"
    fi
    
    local commits
    commits=$(git log --oneline --no-merges "$commit_range" 2>/dev/null || echo "")
    
    if [[ -z "$commits" ]]; then
        echo "none"
        return
    fi
    
    # Check for breaking changes (major version)
    if echo "$commits" | grep -qE "(BREAKING CHANGE|!:)"; then
        echo "major"
        return
    fi
    
    # Check for new features (minor version)
    if echo "$commits" | grep -qE "^[a-f0-9]+ (feat|feature)"; then
        echo "minor"
        return
    fi
    
    # Default to patch for bug fixes and other changes
    echo "patch"
}

# Create or update VERSION file
update_version_file() {
    local new_version="$1"
    echo "$new_version" > "$VERSION_FILE"
    log_success "Updated VERSION file to $new_version"
}

# Create git tag for version
create_git_tag() {
    local version="$1"
    local tag_name="v$version"
    
    git tag -a "$tag_name" -m "Release $tag_name"
    log_success "Created git tag: $tag_name"
}

# Main version bump function
bump_version() {
    local increment_type="${1:-auto}"
    
    local current_version
    current_version=$(get_current_version)
    log_info "Current version: $current_version"
    
    if [[ "$increment_type" == "auto" ]]; then
        increment_type=$(analyze_commits)
        if [[ "$increment_type" == "none" ]]; then
            log_info "No changes detected, skipping version bump"
            return
        fi
        log_info "Auto-detected increment type: $increment_type"
    fi
    
    local new_version
    new_version=$(increment_version "$current_version" "$increment_type")
    log_info "New version: $new_version"
    
    # Update version file
    update_version_file "$new_version"
    
    # Create git tag
    create_git_tag "$new_version"
    
    echo "$new_version"
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
    bump [major|minor|patch|auto]  Bump version (default: auto)
    current                        Show current version
    analyze                        Analyze commits for version increment
    help                          Show this help message

Examples:
    $0 bump                       # Auto-detect version increment
    $0 bump minor                 # Bump minor version
    $0 current                    # Show current version
    $0 analyze                    # Show suggested version increment

EOF
}

# Main script logic
main() {
    case "${1:-help}" in
        "bump")
            bump_version "${2:-auto}"
            ;;
        "current")
            get_current_version
            ;;
        "analyze")
            analyze_commits
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