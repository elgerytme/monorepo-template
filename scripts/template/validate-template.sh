#!/bin/bash

# Template Validation and Health Check Script
# This script validates the monorepo template structure and configuration

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Validation results
VALIDATION_ERRORS=0
VALIDATION_WARNINGS=0

# Print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    ((VALIDATION_WARNINGS++))
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    ((VALIDATION_ERRORS++))
}

print_check() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_fail() {
    echo -e "${RED}[✗]${NC} $1"
    ((VALIDATION_ERRORS++))
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if a file exists and is readable
check_file() {
    local file="$1"
    local description="$2"
    
    if [[ -f "$file" && -r "$file" ]]; then
        print_check "$description: $file"
        return 0
    else
        print_fail "$description: $file (missing or not readable)"
        return 1
    fi
}

# Check if a directory exists
check_directory() {
    local dir="$1"
    local description="$2"
    
    if [[ -d "$dir" ]]; then
        print_check "$description: $dir"
        return 0
    else
        print_fail "$description: $dir (missing)"
        return 1
    fi
}

# Validate Buck2 configuration
validate_buck2_config() {
    print_info "Validating Buck2 configuration..."
    
    check_file ".buckconfig" "Buck2 configuration file"
    check_file ".buckroot" "Buck2 root marker"
    check_file "BUCK" "Root Buck2 build file"
    
    # Check Buck2 installation
    if command_exists buck2; then
        print_check "Buck2 is installed: $(buck2 --version 2>/dev/null || echo 'version check failed')"
    else
        print_warning "Buck2 is not installed or not in PATH"
    fi
    
    # Validate .buckconfig syntax
    if [[ -f ".buckconfig" ]]; then
        if python3 -c "
import configparser
try:
    config = configparser.ConfigParser()
    config.read('.buckconfig')
    print('Buck2 configuration syntax is valid')
except Exception as e:
    print(f'Buck2 configuration syntax error: {e}')
    exit(1)
" 2>/dev/null; then
            print_check "Buck2 configuration syntax is valid"
        else
            print_error "Buck2 configuration has syntax errors"
        fi
    fi
}

# Validate Rust toolchain configuration
validate_rust_config() {
    print_info "Validating Rust configuration..."
    
    check_file "config/rust-toolchain.toml" "Rust toolchain configuration"
    check_file "config/rustfmt.toml" "Rust formatter configuration"
    check_file "config/clippy.toml" "Clippy configuration"
    
    # Check Rust installation
    if command_exists rustc; then
        local rust_version=$(rustc --version)
        print_check "Rust is installed: $rust_version"
        
        # Check if installed version matches toolchain file
        if [[ -f "config/rust-toolchain.toml" ]]; then
            local toolchain_version=$(grep -E '^channel\s*=' config/rust-toolchain.toml | sed 's/.*=\s*"\([^"]*\)".*/\1/' || echo "unknown")
            if [[ "$rust_version" == *"$toolchain_version"* ]]; then
                print_check "Rust version matches toolchain configuration"
            else
                print_warning "Rust version ($rust_version) may not match toolchain configuration ($toolchain_version)"
            fi
        fi
    else
        print_error "Rust is not installed or not in PATH"
    fi
    
    # Check Rust tools
    local rust_tools=("cargo" "rustfmt" "clippy" "cargo-audit")
    for tool in "${rust_tools[@]}"; do
        if command_exists "$tool"; then
            print_check "Rust tool available: $tool"
        else
            print_warning "Rust tool not available: $tool"
        fi
    done
}

# Validate directory structure
validate_directory_structure() {
    print_info "Validating directory structure..."
    
    local required_dirs=(
        "apps"
        "libs" 
        "tools"
        "infra"
        "docs"
        "scripts"
        "config"
        "examples"
        ".github"
        ".devcontainer"
    )
    
    for dir in "${required_dirs[@]}"; do
        check_directory "$dir" "Required directory"
    done
    
    # Check for .gitkeep files in empty directories
    local empty_dirs=("apps" "libs" "tools" "infra" "releases" "signatures" "artifacts")
    for dir in "${empty_dirs[@]}"; do
        if [[ -d "$dir" && -f "$dir/.gitkeep" ]]; then
            print_check "Directory placeholder: $dir/.gitkeep"
        elif [[ -d "$dir" ]]; then
            local file_count=$(find "$dir" -type f | wc -l)
            if [[ $file_count -eq 0 ]]; then
                print_warning "Empty directory without .gitkeep: $dir"
            fi
        fi
    done
}

# Validate CI/CD configuration
validate_cicd_config() {
    print_info "Validating CI/CD configuration..."
    
    check_directory ".github/workflows" "GitHub Actions workflows directory"
    
    # Check for essential workflow files
    local workflow_files=(
        ".github/workflows/ci.yml"
        ".github/workflows/security.yml"
        ".github/workflows/release.yml"
    )
    
    for workflow in "${workflow_files[@]}"; do
        if [[ -f "$workflow" ]]; then
            print_check "Workflow file: $workflow"
            
            # Basic YAML syntax validation
            if command_exists yq; then
                if yq eval '.' "$workflow" >/dev/null 2>&1; then
                    print_check "YAML syntax valid: $workflow"
                else
                    print_error "YAML syntax error: $workflow"
                fi
            elif command_exists python3; then
                if python3 -c "
import yaml
try:
    with open('$workflow', 'r') as f:
        yaml.safe_load(f)
    print('YAML syntax valid')
except Exception as e:
    print(f'YAML syntax error: {e}')
    exit(1)
" 2>/dev/null; then
                    print_check "YAML syntax valid: $workflow"
                else
                    print_error "YAML syntax error: $workflow"
                fi
            fi
        else
            print_warning "Missing workflow file: $workflow"
        fi
    done
}

# Validate development environment configuration
validate_dev_environment() {
    print_info "Validating development environment configuration..."
    
    check_file ".devcontainer/devcontainer.json" "Dev container configuration"
    check_file ".devcontainer/Dockerfile" "Dev container Dockerfile"
    
    # Validate devcontainer.json syntax
    if [[ -f ".devcontainer/devcontainer.json" ]]; then
        if command_exists jq; then
            if jq empty .devcontainer/devcontainer.json 2>/dev/null; then
                print_check "Dev container JSON syntax is valid"
            else
                print_error "Dev container JSON syntax error"
            fi
        elif command_exists python3; then
            if python3 -c "
import json
try:
    with open('.devcontainer/devcontainer.json', 'r') as f:
        json.load(f)
    print('JSON syntax valid')
except Exception as e:
    print(f'JSON syntax error: {e}')
    exit(1)
" 2>/dev/null; then
                print_check "Dev container JSON syntax is valid"
            else
                print_error "Dev container JSON syntax error"
            fi
        fi
    fi
    
    # Check VS Code configuration
    if [[ -d ".vscode" ]]; then
        print_check "VS Code configuration directory exists"
        
        local vscode_files=(".vscode/settings.json" ".vscode/extensions.json")
        for file in "${vscode_files[@]}"; do
            if [[ -f "$file" ]]; then
                print_check "VS Code configuration: $file"
            else
                print_warning "Missing VS Code configuration: $file"
            fi
        done
    else
        print_warning "VS Code configuration directory missing"
    fi
}

# Validate scripts and automation
validate_scripts() {
    print_info "Validating scripts and automation..."
    
    check_directory "scripts/setup" "Setup scripts directory"
    check_directory "scripts/ci" "CI scripts directory"
    
    # Check for essential scripts
    local essential_scripts=(
        "scripts/setup/bootstrap.sh"
        "scripts/ci/validate.sh"
        "scripts/security/audit.sh"
    )
    
    for script in "${essential_scripts[@]}"; do
        if [[ -f "$script" ]]; then
            print_check "Script exists: $script"
            
            # Check if script is executable
            if [[ -x "$script" ]]; then
                print_check "Script is executable: $script"
            else
                print_warning "Script is not executable: $script"
            fi
            
            # Basic shell syntax check
            if bash -n "$script" 2>/dev/null; then
                print_check "Script syntax valid: $script"
            else
                print_error "Script syntax error: $script"
            fi
        else
            print_warning "Missing script: $script"
        fi
    done
    
    # Check justfile
    if [[ -f "justfile" ]]; then
        print_check "Justfile exists"
        
        if command_exists just; then
            if just --list >/dev/null 2>&1; then
                print_check "Justfile syntax is valid"
            else
                print_error "Justfile syntax error"
            fi
        else
            print_warning "Just command runner not installed"
        fi
    else
        print_warning "Justfile missing"
    fi
}

# Validate configuration files
validate_config_files() {
    print_info "Validating configuration files..."
    
    local config_files=(
        "config/rust-toolchain.toml"
        "config/rustfmt.toml"
        "config/clippy.toml"
        "config/nextest.toml"
        "config/dprint.json"
        ".gitignore"
        ".pre-commit-config.yaml"
    )
    
    for config in "${config_files[@]}"; do
        if [[ -f "$config" ]]; then
            print_check "Configuration file: $config"
            
            # Validate specific file formats
            case "$config" in
                *.toml)
                    if command_exists toml-test; then
                        if toml-test "$config" >/dev/null 2>&1; then
                            print_check "TOML syntax valid: $config"
                        else
                            print_error "TOML syntax error: $config"
                        fi
                    fi
                    ;;
                *.json)
                    if command_exists jq; then
                        if jq empty "$config" >/dev/null 2>&1; then
                            print_check "JSON syntax valid: $config"
                        else
                            print_error "JSON syntax error: $config"
                        fi
                    fi
                    ;;
                *.yaml|*.yml)
                    if command_exists yq; then
                        if yq eval '.' "$config" >/dev/null 2>&1; then
                            print_check "YAML syntax valid: $config"
                        else
                            print_error "YAML syntax error: $config"
                        fi
                    fi
                    ;;
            esac
        else
            print_warning "Missing configuration file: $config"
        fi
    done
}

# Validate example projects
validate_examples() {
    print_info "Validating example projects..."
    
    check_directory "examples" "Examples directory"
    
    # Check for example projects
    local example_dirs=("web-service" "frontend-app" "shared-library" "infrastructure")
    for example in "${example_dirs[@]}"; do
        local example_path="examples/$example"
        if [[ -d "$example_path" ]]; then
            print_check "Example project: $example"
            
            # Validate specific example types
            case "$example" in
                "web-service")
                    if [[ -f "$example_path/Cargo.toml" ]]; then
                        print_check "Rust web service example has Cargo.toml"
                    else
                        print_warning "Rust web service example missing Cargo.toml"
                    fi
                    ;;
                "frontend-app")
                    if [[ -f "$example_path/package.json" ]]; then
                        print_check "Frontend app example has package.json"
                    else
                        print_warning "Frontend app example missing package.json"
                    fi
                    ;;
            esac
        else
            print_warning "Missing example project: $example"
        fi
    done
}

# Validate documentation
validate_documentation() {
    print_info "Validating documentation..."
    
    check_file "README.md" "Main README file"
    check_directory "docs" "Documentation directory"
    
    local doc_dirs=("docs/architecture" "docs/onboarding" "docs/runbooks")
    for doc_dir in "${doc_dirs[@]}"; do
        if [[ -d "$doc_dir" ]]; then
            print_check "Documentation directory: $doc_dir"
        else
            print_warning "Missing documentation directory: $doc_dir"
        fi
    done
    
    # Check for essential documentation files
    local essential_docs=(
        "docs/architecture/README.md"
        "docs/onboarding/README.md"
        "docs/SECURITY.md"
    )
    
    for doc in "${essential_docs[@]}"; do
        if [[ -f "$doc" ]]; then
            print_check "Documentation file: $doc"
        else
            print_warning "Missing documentation file: $doc"
        fi
    done
}

# Run health checks
run_health_checks() {
    print_info "Running health checks..."
    
    # Check disk space
    local available_space=$(df . | awk 'NR==2 {print $4}')
    if [[ $available_space -gt 1000000 ]]; then  # 1GB in KB
        print_check "Sufficient disk space available"
    else
        print_warning "Low disk space: $(df -h . | awk 'NR==2 {print $4}') available"
    fi
    
    # Check git repository status
    if [[ -d ".git" ]]; then
        print_check "Git repository initialized"
        
        # Check for uncommitted changes
        if git diff --quiet && git diff --cached --quiet; then
            print_check "Working directory is clean"
        else
            print_warning "Working directory has uncommitted changes"
        fi
        
        # Check for remote repository
        if git remote -v | grep -q origin; then
            print_check "Git remote 'origin' configured"
        else
            print_warning "Git remote 'origin' not configured"
        fi
    else
        print_warning "Not a git repository"
    fi
    
    # Check for common development tools
    local dev_tools=("git" "curl" "wget" "make" "docker")
    for tool in "${dev_tools[@]}"; do
        if command_exists "$tool"; then
            print_check "Development tool available: $tool"
        else
            print_warning "Development tool not available: $tool"
        fi
    done
}

# Generate validation report
generate_report() {
    print_info "Validation Summary"
    print_info "=================="
    
    if [[ $VALIDATION_ERRORS -eq 0 && $VALIDATION_WARNINGS -eq 0 ]]; then
        print_success "✅ Template validation passed with no issues!"
    elif [[ $VALIDATION_ERRORS -eq 0 ]]; then
        print_success "✅ Template validation passed with $VALIDATION_WARNINGS warning(s)"
        print_info "Review warnings above for potential improvements"
    else
        print_error "❌ Template validation failed with $VALIDATION_ERRORS error(s) and $VALIDATION_WARNINGS warning(s)"
        print_info "Fix errors above before using the template"
    fi
    
    echo
    print_info "Validation completed at $(date)"
    
    return $VALIDATION_ERRORS
}

# Main execution
main() {
    print_info "Monorepo Template Validation"
    print_info "============================="
    
    # Change to script directory to ensure relative paths work
    cd "$(dirname "$(dirname "$(realpath "$0")")")"
    
    validate_directory_structure
    validate_buck2_config
    validate_rust_config
    validate_cicd_config
    validate_dev_environment
    validate_scripts
    validate_config_files
    validate_examples
    validate_documentation
    run_health_checks
    
    generate_report
}

# Run main function
main "$@"