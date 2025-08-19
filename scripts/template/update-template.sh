#!/bin/bash

# Template Update Script
# Updates an existing project to use the latest template version

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TEMPLATE_REPO="https://github.com/your-org/monorepo-template.git"
TEMPLATE_VERSION=""
TARGET_DIR="."
BACKUP_DIR=""
DRY_RUN=false
FORCE_UPDATE=false

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Update an existing project to use the latest template version.

OPTIONS:
    -v, --version VERSION     Template version to update to (default: latest)
    -d, --dir DIRECTORY       Target directory (default: current directory)
    -b, --backup DIRECTORY    Backup directory (default: auto-generated)
    -n, --dry-run            Show what would be updated without making changes
    -f, --force              Force update even if there are conflicts
    -r, --repo URL           Template repository URL
    -h, --help               Show this help message

EXAMPLES:
    $0                                    # Update to latest version
    $0 --version v1.2.0                  # Update to specific version
    $0 --dry-run                         # Preview changes
    $0 --backup /tmp/backup --force      # Force update with custom backup

EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--version)
                TEMPLATE_VERSION="$2"
                shift 2
                ;;
            -d|--dir)
                TARGET_DIR="$2"
                shift 2
                ;;
            -b|--backup)
                BACKUP_DIR="$2"
                shift 2
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force)
                FORCE_UPDATE=true
                shift
                ;;
            -r|--repo)
                TEMPLATE_REPO="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

get_current_template_version() {
    if [[ -f "$TARGET_DIR/.template-version" ]]; then
        cat "$TARGET_DIR/.template-version"
    elif [[ -f "$TARGET_DIR/VERSION" ]]; then
        cat "$TARGET_DIR/VERSION"
    else
        echo "unknown"
    fi
}

get_latest_template_version() {
    if [[ -n "$TEMPLATE_VERSION" ]]; then
        echo "$TEMPLATE_VERSION"
    else
        # Get latest release from git
        git ls-remote --tags --refs "$TEMPLATE_REPO" | \
            grep -E 'refs/tags/v[0-9]+\.[0-9]+\.[0-9]+$' | \
            sed 's/.*refs\/tags\/v//' | \
            sort -V | \
            tail -1 || echo "main"
    fi
}

create_backup() {
    local backup_dir="$1"
    
    print_info "Creating backup at $backup_dir..."
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY RUN] Would create backup at $backup_dir"
        return
    fi
    
    mkdir -p "$backup_dir"
    
    # Backup important files and directories
    local backup_items=(
        ".buckconfig"
        ".buckroot"
        "BUCK"
        "config/"
        "scripts/"
        ".github/"
        ".devcontainer/"
        "justfile"
        "VERSION"
        ".template-version"
    )
    
    for item in "${backup_items[@]}"; do
        if [[ -e "$TARGET_DIR/$item" ]]; then
            cp -r "$TARGET_DIR/$item" "$backup_dir/" 2>/dev/null || true
        fi
    done
    
    print_success "Backup created at $backup_dir"
}

download_template() {
    local version="$1"
    local temp_dir="$2"
    
    print_info "Downloading template version $version..."
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY RUN] Would download template version $version"
        return
    fi
    
    if [[ "$version" == "main" || "$version" == "latest" ]]; then
        git clone --depth 1 "$TEMPLATE_REPO" "$temp_dir"
    else
        git clone --depth 1 --branch "v$version" "$TEMPLATE_REPO" "$temp_dir"
    fi
    
    print_success "Template downloaded to $temp_dir"
}

compare_files() {
    local file1="$1"
    local file2="$2"
    
    if [[ ! -f "$file1" && ! -f "$file2" ]]; then
        return 0  # Both don't exist, no difference
    elif [[ ! -f "$file1" ]]; then
        return 1  # file1 doesn't exist, file2 does
    elif [[ ! -f "$file2" ]]; then
        return 1  # file2 doesn't exist, file1 does
    else
        diff -q "$file1" "$file2" >/dev/null 2>&1
        return $?
    fi
}

update_file() {
    local source_file="$1"
    local target_file="$2"
    local description="$3"
    
    if compare_files "$source_file" "$target_file"; then
        print_info "✓ $description (no changes)"
        return
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        print_warning "[DRY RUN] Would update: $description"
        return
    fi
    
    # Check if target file has local modifications
    if [[ -f "$target_file" && "$FORCE_UPDATE" != true ]]; then
        print_warning "File has potential local modifications: $target_file"
        read -p "Update this file? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Skipped: $description"
            return
        fi
    fi
    
    # Create target directory if it doesn't exist
    local target_dir
    target_dir=$(dirname "$target_file")
    mkdir -p "$target_dir"
    
    cp "$source_file" "$target_file"
    print_success "Updated: $description"
}

update_template_files() {
    local template_dir="$1"
    
    print_info "Updating template files..."
    
    # Core configuration files
    local core_files=(
        ".buckconfig:Buck2 configuration"
        ".buckroot:Buck2 root marker"
        "BUCK:Root build file"
        "justfile:Just command runner configuration"
    )
    
    for file_desc in "${core_files[@]}"; do
        IFS=':' read -r file desc <<< "$file_desc"
        if [[ -f "$template_dir/$file" ]]; then
            update_file "$template_dir/$file" "$TARGET_DIR/$file" "$desc"
        fi
    done
    
    # Configuration directory
    if [[ -d "$template_dir/config" ]]; then
        print_info "Updating configuration files..."
        find "$template_dir/config" -type f | while read -r config_file; do
            local rel_path="${config_file#$template_dir/}"
            local target_path="$TARGET_DIR/$rel_path"
            local file_name
            file_name=$(basename "$config_file")
            update_file "$config_file" "$target_path" "Config: $file_name"
        done
    fi
    
    # Scripts directory (be careful with local modifications)
    if [[ -d "$template_dir/scripts" ]]; then
        print_info "Updating scripts..."
        find "$template_dir/scripts" -name "*.sh" -o -name "*.ps1" | while read -r script_file; do
            local rel_path="${script_file#$template_dir/}"
            local target_path="$TARGET_DIR/$rel_path"
            local script_name
            script_name=$(basename "$script_file")
            
            # Skip if target has local modifications (unless forced)
            if [[ -f "$target_path" && "$FORCE_UPDATE" != true ]]; then
                if ! compare_files "$script_file" "$target_path"; then
                    print_warning "Script may have local modifications: $rel_path"
                    continue
                fi
            fi
            
            update_file "$script_file" "$target_path" "Script: $script_name"
            
            # Make scripts executable
            if [[ "$DRY_RUN" != true ]]; then
                chmod +x "$target_path" 2>/dev/null || true
            fi
        done
    fi
    
    # GitHub workflows
    if [[ -d "$template_dir/.github" ]]; then
        print_info "Updating GitHub workflows..."
        find "$template_dir/.github" -type f | while read -r workflow_file; do
            local rel_path="${workflow_file#$template_dir/}"
            local target_path="$TARGET_DIR/$rel_path"
            local file_name
            file_name=$(basename "$workflow_file")
            update_file "$workflow_file" "$target_path" "Workflow: $file_name"
        done
    fi
    
    # Development container
    if [[ -d "$template_dir/.devcontainer" ]]; then
        print_info "Updating development container configuration..."
        find "$template_dir/.devcontainer" -type f | while read -r devcontainer_file; do
            local rel_path="${devcontainer_file#$template_dir/}"
            local target_path="$TARGET_DIR/$rel_path"
            local file_name
            file_name=$(basename "$devcontainer_file")
            update_file "$devcontainer_file" "$target_path" "DevContainer: $file_name"
        done
    fi
}

update_version_tracking() {
    local new_version="$1"
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY RUN] Would update template version to $new_version"
        return
    fi
    
    echo "$new_version" > "$TARGET_DIR/.template-version"
    print_success "Updated template version tracking to $new_version"
}

validate_update() {
    print_info "Validating updated template..."
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY RUN] Would run template validation"
        return
    fi
    
    # Run template validation if available
    if [[ -f "$TARGET_DIR/scripts/template/validate-template.sh" ]]; then
        cd "$TARGET_DIR"
        if ./scripts/template/validate-template.sh; then
            print_success "Template validation passed"
        else
            print_warning "Template validation failed - please review the issues"
        fi
    else
        print_warning "Template validation script not found"
    fi
}

main() {
    print_info "Template Update Tool"
    print_info "==================="
    
    parse_args "$@"
    
    # Validate target directory
    if [[ ! -d "$TARGET_DIR" ]]; then
        print_error "Target directory does not exist: $TARGET_DIR"
        exit 1
    fi
    
    cd "$TARGET_DIR"
    
    # Get current and target versions
    local current_version
    current_version=$(get_current_template_version)
    local target_version
    target_version=$(get_latest_template_version)
    
    print_info "Current template version: $current_version"
    print_info "Target template version: $target_version"
    
    if [[ "$current_version" == "$target_version" && "$FORCE_UPDATE" != true ]]; then
        print_info "Already up to date!"
        exit 0
    fi
    
    # Set up backup directory
    if [[ -z "$BACKUP_DIR" ]]; then
        BACKUP_DIR="/tmp/template-backup-$(date +%Y%m%d-%H%M%S)"
    fi
    
    # Create backup
    create_backup "$BACKUP_DIR"
    
    # Download template
    local temp_dir="/tmp/template-update-$$"
    download_template "$target_version" "$temp_dir"
    
    # Update files
    update_template_files "$temp_dir"
    
    # Update version tracking
    update_version_tracking "$target_version"
    
    # Validate update
    validate_update
    
    # Cleanup
    if [[ "$DRY_RUN" != true ]]; then
        rm -rf "$temp_dir"
    fi
    
    print_success "Template update completed!"
    print_info "Backup available at: $BACKUP_DIR"
    print_info "Next steps:"
    print_info "  1. Review the changes"
    print_info "  2. Test your project builds and runs correctly"
    print_info "  3. Commit the template updates"
    print_info "  4. Remove backup when satisfied: rm -rf $BACKUP_DIR"
}

main "$@"