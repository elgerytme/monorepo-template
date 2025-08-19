#!/bin/bash

# Template Packaging Script
# Creates distributable packages of the monorepo template

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTPUT_DIR="$REPO_ROOT/releases"
PACKAGE_NAME="monorepo-template"
VERSION=""
FORMAT="tar.gz"
INCLUDE_EXAMPLES=true
INCLUDE_DOCS=true

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

Package the monorepo template for distribution.

OPTIONS:
    -v, --version VERSION     Package version (default: from VERSION file)
    -o, --output DIRECTORY    Output directory (default: releases/)
    -n, --name NAME          Package name (default: monorepo-template)
    -f, --format FORMAT      Package format: tar.gz, zip, both (default: tar.gz)
    --no-examples            Exclude example projects
    --no-docs               Exclude documentation
    -h, --help              Show this help message

EXAMPLES:
    $0                                    # Package with defaults
    $0 --version 1.0.0 --format both     # Specific version, both formats
    $0 --no-examples --output /tmp       # Minimal package to /tmp

EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--version)
                VERSION="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -n|--name)
                PACKAGE_NAME="$2"
                shift 2
                ;;
            -f|--format)
                FORMAT="$2"
                shift 2
                ;;
            --no-examples)
                INCLUDE_EXAMPLES=false
                shift
                ;;
            --no-docs)
                INCLUDE_DOCS=false
                shift
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

get_version() {
    if [[ -n "$VERSION" ]]; then
        echo "$VERSION"
    elif [[ -f "$REPO_ROOT/VERSION" ]]; then
        cat "$REPO_ROOT/VERSION"
    else
        git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "0.1.0"
    fi
}

validate_format() {
    case "$FORMAT" in
        "tar.gz"|"zip"|"both")
            return 0
            ;;
        *)
            print_error "Invalid format: $FORMAT. Use tar.gz, zip, or both."
            exit 1
            ;;
    esac
}

create_temp_directory() {
    local temp_dir="/tmp/${PACKAGE_NAME}-packaging-$$"
    mkdir -p "$temp_dir"
    echo "$temp_dir"
}

copy_core_files() {
    local temp_dir="$1"
    local package_dir="$temp_dir/$PACKAGE_NAME"
    
    print_info "Copying core template files..."
    
    mkdir -p "$package_dir"
    
    # Core configuration files
    local core_files=(
        ".buckconfig"
        ".buckroot"
        "BUCK"
        "justfile"
        "VERSION"
        "README.md"
        ".gitignore"
        ".pre-commit-config.yaml"
        ".markdownlint.yml"
        ".yamllint.yml"
        ".secrets.baseline"
        ".release-config.json"
    )
    
    for file in "${core_files[@]}"; do
        if [[ -f "$REPO_ROOT/$file" ]]; then
            cp "$REPO_ROOT/$file" "$package_dir/"
        fi
    done
    
    # Core directories
    local core_dirs=(
        "config"
        "scripts"
        ".github"
        ".devcontainer"
        ".vscode"
    )
    
    for dir in "${core_dirs[@]}"; do
        if [[ -d "$REPO_ROOT/$dir" ]]; then
            cp -r "$REPO_ROOT/$dir" "$package_dir/"
        fi
    done
    
    # Create empty directories with .gitkeep
    local empty_dirs=(
        "apps"
        "libs"
        "tools"
        "infra"
        "releases"
        "signatures"
        "artifacts"
    )
    
    for dir in "${empty_dirs[@]}"; do
        mkdir -p "$package_dir/$dir"
        touch "$package_dir/$dir/.gitkeep"
    done
}

copy_examples() {
    local temp_dir="$1"
    local package_dir="$temp_dir/$PACKAGE_NAME"
    
    if [[ "$INCLUDE_EXAMPLES" == true ]]; then
        print_info "Including example projects..."
        if [[ -d "$REPO_ROOT/examples" ]]; then
            cp -r "$REPO_ROOT/examples" "$package_dir/"
        fi
    else
        print_info "Excluding example projects..."
        mkdir -p "$package_dir/examples"
        touch "$package_dir/examples/.gitkeep"
    fi
}

copy_documentation() {
    local temp_dir="$1"
    local package_dir="$temp_dir/$PACKAGE_NAME"
    
    if [[ "$INCLUDE_DOCS" == true ]]; then
        print_info "Including documentation..."
        if [[ -d "$REPO_ROOT/docs" ]]; then
            cp -r "$REPO_ROOT/docs" "$package_dir/"
        fi
    else
        print_info "Excluding documentation..."
        mkdir -p "$package_dir/docs"
        touch "$package_dir/docs/.gitkeep"
    fi
}

create_package_metadata() {
    local temp_dir="$1"
    local package_dir="$temp_dir/$PACKAGE_NAME"
    local version="$2"
    
    print_info "Creating package metadata..."
    
    # Create template metadata file
    cat > "$package_dir/.template-metadata.json" << EOF
{
  "name": "$PACKAGE_NAME",
  "version": "$version",
  "description": "Enterprise-grade monorepo template with Buck2 and Rust tooling",
  "created": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "languages": ["rust", "typescript", "python", "go"],
  "features": [
    "buck2-build-system",
    "rust-tooling",
    "ci-cd-pipelines",
    "development-containers",
    "security-scanning",
    "observability",
    "documentation"
  ],
  "requirements": {
    "buck2": ">=2024.01.01",
    "rust": ">=1.70.0",
    "git": ">=2.30.0"
  },
  "repository": "https://github.com/your-org/monorepo-template",
  "license": "MIT",
  "maintainers": [
    "Template Team <template-team@your-org.com>"
  ]
}
EOF
    
    # Create installation instructions
    cat > "$package_dir/INSTALL.md" << 'EOF'
# Installation Instructions

## Quick Start

1. Extract the template package:
   ```bash
   tar -xzf monorepo-template-*.tar.gz
   # or
   unzip monorepo-template-*.zip
   ```

2. Initialize a new project:
   ```bash
   cd monorepo-template
   ./scripts/template/init-template.sh --name my-project --org my-company
   ```

3. Set up development environment:
   ```bash
   cd my-project
   ./scripts/setup/bootstrap.sh
   ```

## Requirements

- **Buck2**: Build system (install from https://buck2.build/)
- **Rust**: Programming language and toolchain (install from https://rustup.rs/)
- **Git**: Version control system
- **Docker**: For development containers (optional)

## Supported Languages

- Rust (primary)
- TypeScript/JavaScript
- Python
- Go

## Features Included

- ✅ Buck2 build system configuration
- ✅ Rust-based development tooling
- ✅ CI/CD pipelines (GitHub Actions)
- ✅ Development containers
- ✅ Security scanning and policies
- ✅ Observability and monitoring setup
- ✅ Comprehensive documentation
- ✅ Example projects

## Next Steps

1. Read the documentation in `docs/`
2. Review example projects in `examples/`
3. Customize the template for your needs
4. Start building your monorepo!

For detailed migration guides and advanced usage, see the documentation.
EOF
    
    # Create version tracking file
    echo "$version" > "$package_dir/.template-version"
}

create_checksums() {
    local output_dir="$1"
    local package_file="$2"
    
    print_info "Creating checksums for $package_file..."
    
    cd "$output_dir"
    
    # Create SHA256 checksum
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$(basename "$package_file")" > "${package_file}.sha256"
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$(basename "$package_file")" > "${package_file}.sha256"
    else
        print_warning "No SHA256 utility found, skipping checksum"
    fi
    
    # Create MD5 checksum (for compatibility)
    if command -v md5sum >/dev/null 2>&1; then
        md5sum "$(basename "$package_file")" > "${package_file}.md5"
    elif command -v md5 >/dev/null 2>&1; then
        md5 "$(basename "$package_file")" > "${package_file}.md5"
    else
        print_warning "No MD5 utility found, skipping MD5 checksum"
    fi
}

create_tar_package() {
    local temp_dir="$1"
    local version="$2"
    local output_file="$OUTPUT_DIR/${PACKAGE_NAME}-${version}.tar.gz"
    
    print_info "Creating tar.gz package..."
    
    mkdir -p "$OUTPUT_DIR"
    
    cd "$temp_dir"
    tar -czf "$output_file" "$PACKAGE_NAME"
    
    create_checksums "$OUTPUT_DIR" "$output_file"
    
    print_success "Created: $output_file"
    print_info "Size: $(du -h "$output_file" | cut -f1)"
}

create_zip_package() {
    local temp_dir="$1"
    local version="$2"
    local output_file="$OUTPUT_DIR/${PACKAGE_NAME}-${version}.zip"
    
    print_info "Creating zip package..."
    
    mkdir -p "$OUTPUT_DIR"
    
    cd "$temp_dir"
    zip -r "$output_file" "$PACKAGE_NAME" >/dev/null
    
    create_checksums "$OUTPUT_DIR" "$output_file"
    
    print_success "Created: $output_file"
    print_info "Size: $(du -h "$output_file" | cut -f1)"
}

cleanup_temp() {
    local temp_dir="$1"
    rm -rf "$temp_dir"
}

main() {
    print_info "Template Packaging Tool"
    print_info "======================="
    
    parse_args "$@"
    validate_format
    
    local version
    version=$(get_version)
    
    print_info "Package name: $PACKAGE_NAME"
    print_info "Version: $version"
    print_info "Format: $FORMAT"
    print_info "Output directory: $OUTPUT_DIR"
    print_info "Include examples: $INCLUDE_EXAMPLES"
    print_info "Include docs: $INCLUDE_DOCS"
    
    # Create temporary directory
    local temp_dir
    temp_dir=$(create_temp_directory)
    
    # Copy files
    copy_core_files "$temp_dir"
    copy_examples "$temp_dir"
    copy_documentation "$temp_dir"
    create_package_metadata "$temp_dir" "$version"
    
    # Create packages
    case "$FORMAT" in
        "tar.gz")
            create_tar_package "$temp_dir" "$version"
            ;;
        "zip")
            create_zip_package "$temp_dir" "$version"
            ;;
        "both")
            create_tar_package "$temp_dir" "$version"
            create_zip_package "$temp_dir" "$version"
            ;;
    esac
    
    # Cleanup
    cleanup_temp "$temp_dir"
    
    print_success "Template packaging completed!"
    print_info "Packages available in: $OUTPUT_DIR"
    
    # List created files
    print_info "Created files:"
    find "$OUTPUT_DIR" -name "${PACKAGE_NAME}-${version}*" -type f | while read -r file; do
        echo "  - $(basename "$file")"
    done
}

main "$@"