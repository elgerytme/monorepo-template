#!/bin/bash

# Project Assessment Script for Monorepo Template Migration
# This script analyzes an existing project to determine migration complexity and strategy

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Assessment results
PROJECT_PATH=""
ASSESSMENT_RESULTS=()
MIGRATION_COMPLEXITY="UNKNOWN"
RECOMMENDED_STRATEGY=""

# Print colored output
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

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 PROJECT_PATH [OPTIONS]

Assess an existing project for monorepo template migration.

ARGUMENTS:
    PROJECT_PATH          Path to the project to assess

OPTIONS:
    -o, --output FILE     Output assessment report to file
    -f, --format FORMAT   Output format (text, json, markdown)
    -v, --verbose         Verbose output
    -h, --help            Show this help message

EXAMPLES:
    $0 /path/to/my-project
    $0 ./my-app --output assessment.md --format markdown
    $0 ../legacy-service --verbose

EOF
}

# Add assessment result
add_result() {
    local category="$1"
    local item="$2"
    local status="$3"
    local message="$4"
    local impact="${5:-MEDIUM}"
    
    ASSESSMENT_RESULTS+=("$category|$item|$status|$message|$impact")
}

# Analyze project structure
analyze_structure() {
    print_info "Analyzing project structure..."
    
    cd "$PROJECT_PATH"
    
    # Check for monorepo indicators
    if [[ -f "lerna.json" || -f "nx.json" || -f "rush.json" ]]; then
        add_result "STRUCTURE" "Monorepo" "DETECTED" "Existing monorepo structure found" "LOW"
        print_success "Existing monorepo structure detected"
    elif [[ -f "Cargo.toml" && $(grep -c "workspace" Cargo.toml 2>/dev/null || echo 0) -gt 0 ]]; then
        add_result "STRUCTURE" "Cargo Workspace" "DETECTED" "Rust workspace structure found" "LOW"
        print_success "Rust workspace structure detected"
    elif [[ -f "package.json" && $(grep -c "workspaces" package.json 2>/dev/null || echo 0) -gt 0 ]]; then
        add_result "STRUCTURE" "npm Workspaces" "DETECTED" "npm workspace structure found" "LOW"
        print_success "npm workspace structure detected"
    else
        add_result "STRUCTURE" "Single Project" "DETECTED" "Single project structure" "MEDIUM"
        print_warning "Single project structure - will need reorganization"
    fi
    
    # Count directories and files
    local dir_count=$(find . -maxdepth 2 -type d | wc -l)
    local file_count=$(find . -type f | wc -l)
    
    add_result "STRUCTURE" "Size" "INFO" "$dir_count directories, $file_count files" "LOW"
    
    if [[ $file_count -gt 1000 ]]; then
        add_result "STRUCTURE" "Complexity" "HIGH" "Large project with $file_count files" "HIGH"
        print_warning "Large project detected - consider gradual migration"
    elif [[ $file_count -gt 100 ]]; then
        add_result "STRUCTURE" "Complexity" "MEDIUM" "Medium project with $file_count files" "MEDIUM"
        print_info "Medium-sized project"
    else
        add_result "STRUCTURE" "Complexity" "LOW" "Small project with $file_count files" "LOW"
        print_success "Small project - good candidate for complete migration"
    fi
}

# Analyze languages and technologies
analyze_languages() {
    print_info "Analyzing languages and technologies..."
    
    cd "$PROJECT_PATH"
    
    # Detect languages
    local languages=()
    
    if [[ -f "Cargo.toml" || $(find . -name "*.rs" | head -1) ]]; then
        languages+=("Rust")
        add_result "LANGUAGE" "Rust" "SUPPORTED" "Rust code detected - fully supported" "LOW"
        print_success "Rust detected - fully supported"
    fi
    
    if [[ -f "package.json" || -f "tsconfig.json" || $(find . -name "*.ts" -o -name "*.tsx" | head -1) ]]; then
        languages+=("TypeScript")
        add_result "LANGUAGE" "TypeScript" "SUPPORTED" "TypeScript code detected - fully supported" "LOW"
        print_