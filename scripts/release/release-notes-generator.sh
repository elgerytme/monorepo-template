#!/bin/bash
# Automated release notes generation system
# Generates comprehensive release notes from git commits and pull requests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Configuration
RELEASE_NOTES_DIR="$REPO_ROOT/releases"
CHANGELOG_FILE="$REPO_ROOT/CHANGELOG.md"
TEMPLATE_DIR="$SCRIPT_DIR/templates"

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

# Ensure release notes directory exists
ensure_release_dir() {
    mkdir -p "$RELEASE_NOTES_DIR"
}

# Get commits between two references
get_commits() {
    local from_ref="$1"
    local to_ref="${2:-HEAD}"
    
    if [[ -z "$from_ref" ]]; then
        # If no previous tag, get all commits
        git log --oneline --no-merges "$to_ref"
    else
        git log --oneline --no-merges "$from_ref..$to_ref"
    fi
}

# Categorize commits by type
categorize_commits() {
    local commits="$1"
    
    # Initialize arrays
    declare -A categories
    categories[breaking]=""
    categories[features]=""
    categories[fixes]=""
    categories[docs]=""
    categories[style]=""
    categories[refactor]=""
    categories[perf]=""
    categories[test]=""
    categories[chore]=""
    categories[other]=""
    
    while IFS= read -r commit; do
        if [[ -z "$commit" ]]; then
            continue
        fi
        
        local hash=$(echo "$commit" | cut -d' ' -f1)
        local message=$(echo "$commit" | cut -d' ' -f2-)
        
        # Check for breaking changes
        if echo "$message" | grep -qE "(BREAKING CHANGE|!:)"; then
            categories[breaking]+="- $message ($hash)\n"
        # Check commit type prefixes
        elif echo "$message" | grep -qE "^feat(\(.+\))?:"; then
            categories[features]+="- $message ($hash)\n"
        elif echo "$message" | grep -qE "^fix(\(.+\))?:"; then
            categories[fixes]+="- $message ($hash)\n"
        elif echo "$message" | grep -qE "^docs(\(.+\))?:"; then
            categories[docs]+="- $message ($hash)\n"
        elif echo "$message" | grep -qE "^style(\(.+\))?:"; then
            categories[style]+="- $message ($hash)\n"
        elif echo "$message" | grep -qE "^refactor(\(.+\))?:"; then
            categories[refactor]+="- $message ($hash)\n"
        elif echo "$message" | grep -qE "^perf(\(.+\))?:"; then
            categories[perf]+="- $message ($hash)\n"
        elif echo "$message" | grep -qE "^test(\(.+\))?:"; then
            categories[test]+="- $message ($hash)\n"
        elif echo "$message" | grep -qE "^chore(\(.+\))?:"; then
            categories[chore]+="- $message ($hash)\n"
        else
            categories[other]+="- $message ($hash)\n"
        fi
    done <<< "$commits"
    
    # Output categorized commits
    for category in breaking features fixes docs style refactor perf test chore other; do
        echo "$category:${categories[$category]}"
    done
}

# Generate release notes content
generate_release_notes() {
    local version="$1"
    local previous_tag="$2"
    local release_date="$(date '+%Y-%m-%d')"
    
    log_info "Generating release notes for version $version"
    
    # Get commits since last release
    local commits
    commits=$(get_commits "$previous_tag")
    
    if [[ -z "$commits" ]]; then
        log_warning "No commits found for release $version"
        return
    fi
    
    # Categorize commits
    local categorized
    categorized=$(categorize_commits "$commits")
    
    # Start building release notes
    local release_notes=""
    release_notes+="# Release $version\n\n"
    release_notes+="**Release Date:** $release_date\n\n"
    
    # Add summary
    local commit_count
    commit_count=$(echo "$commits" | wc -l)
    release_notes+="## Summary\n\n"
    release_notes+="This release includes $commit_count commits with the following changes:\n\n"
    
    # Add breaking changes first (if any)
    local breaking_changes
    breaking_changes=$(echo "$categorized" | grep "^breaking:" | cut -d':' -f2-)
    if [[ -n "$breaking_changes" && "$breaking_changes" != "" ]]; then
        release_notes+="## ⚠️ Breaking Changes\n\n"
        release_notes+="$breaking_changes\n"
    fi
    
    # Add features
    local features
    features=$(echo "$categorized" | grep "^features:" | cut -d':' -f2-)
    if [[ -n "$features" && "$features" != "" ]]; then
        release_notes+="## ✨ New Features\n\n"
        release_notes+="$features\n"
    fi
    
    # Add bug fixes
    local fixes
    fixes=$(echo "$categorized" | grep "^fixes:" | cut -d':' -f2-)
    if [[ -n "$fixes" && "$fixes" != "" ]]; then
        release_notes+="## 🐛 Bug Fixes\n\n"
        release_notes+="$fixes\n"
    fi
    
    # Add performance improvements
    local perf
    perf=$(echo "$categorized" | grep "^perf:" | cut -d':' -f2-)
    if [[ -n "$perf" && "$perf" != "" ]]; then
        release_notes+="## ⚡ Performance Improvements\n\n"
        release_notes+="$perf\n"
    fi
    
    # Add documentation updates
    local docs
    docs=$(echo "$categorized" | grep "^docs:" | cut -d':' -f2-)
    if [[ -n "$docs" && "$docs" != "" ]]; then
        release_notes+="## 📚 Documentation\n\n"
        release_notes+="$docs\n"
    fi
    
    # Add other changes
    local other
    other=$(echo "$categorized" | grep "^other:" | cut -d':' -f2-)
    if [[ -n "$other" && "$other" != "" ]]; then
        release_notes+="## 🔧 Other Changes\n\n"
        release_notes+="$other\n"
    fi
    
    # Add contributors section
    local contributors
    contributors=$(git log --format='%an' "$previous_tag..HEAD" 2>/dev/null | sort -u | tr '\n' ', ' | sed 's/, $//')
    if [[ -n "$contributors" ]]; then
        release_notes+="## 👥 Contributors\n\n"
        release_notes+="Thanks to the following contributors: $contributors\n\n"
    fi
    
    # Add installation/upgrade instructions
    release_notes+="## 📦 Installation\n\n"
    release_notes+="To install or upgrade to this version:\n\n"
    release_notes+="\`\`\`bash\n"
    release_notes+="# Clone or update the repository\n"
    release_notes+="git checkout v$version\n"
    release_notes+="\`\`\`\n\n"
    
    echo -e "$release_notes"
}

# Save release notes to file
save_release_notes() {
    local version="$1"
    local content="$2"
    
    ensure_release_dir
    
    local release_file="$RELEASE_NOTES_DIR/v$version.md"
    echo -e "$content" > "$release_file"
    
    log_success "Release notes saved to: $release_file"
}

# Update changelog
update_changelog() {
    local version="$1"
    local content="$2"
    
    local temp_file=$(mktemp)
    
    # Create new changelog content
    echo -e "$content" > "$temp_file"
    
    # If changelog exists, append existing content
    if [[ -f "$CHANGELOG_FILE" ]]; then
        echo "" >> "$temp_file"
        cat "$CHANGELOG_FILE" >> "$temp_file"
    fi
    
    # Replace changelog
    mv "$temp_file" "$CHANGELOG_FILE"
    
    log_success "Updated CHANGELOG.md"
}

# Get previous release tag
get_previous_tag() {
    git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo ""
}

# Main release notes generation function
generate_release() {
    local version="$1"
    
    # Get previous tag for comparison
    local previous_tag
    previous_tag=$(get_previous_tag)
    
    if [[ -n "$previous_tag" ]]; then
        log_info "Generating release notes from $previous_tag to v$version"
    else
        log_info "Generating release notes for initial release v$version"
    fi
    
    # Generate release notes content
    local release_notes
    release_notes=$(generate_release_notes "$version" "$previous_tag")
    
    # Save to release notes file
    save_release_notes "$version" "$release_notes"
    
    # Update changelog
    update_changelog "$version" "$release_notes"
    
    log_success "Release notes generated for version $version"
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [COMMAND] [VERSION]

Commands:
    generate <version>    Generate release notes for specified version
    help                  Show this help message

Examples:
    $0 generate 1.2.3     # Generate release notes for version 1.2.3

EOF
}

# Main script logic
main() {
    case "${1:-help}" in
        "generate")
            if [[ -z "${2:-}" ]]; then
                log_error "Version required for generate command"
                show_usage
                exit 1
            fi
            generate_release "$2"
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