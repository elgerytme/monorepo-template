#!/bin/bash

# Environment Health Check Script
# Validates that all required tools are installed and working correctly

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[⚠]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

# Check if command exists and optionally verify version
check_tool() {
    local tool="$1"
    local description="$2"
    local version_cmd="${3:-}"
    local required_version="${4:-}"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if command -v "$tool" >/dev/null 2>&1; then
        if [ -n "$version_cmd" ]; then
            local version
            version=$(eval "$version_cmd" 2>/dev/null || echo "unknown")
            if [ -n "$required_version" ] && [ "$version" != "$required_version" ]; then
                log_warning "$description: $version (expected: $required_version)"
            else
                log_success "$description: $version"
            fi
        else
            log_success "$description: installed"
        fi
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        log_error "$description: not found"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
}

# Check file exists
check_file() {
    local file="$1"
    local description="$2"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [ -f "$file" ]; then
        log_success "$description: exists"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        log_error "$description: missing"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
}

# Check directory exists
check_directory() {
    local dir="$1"
    local description="$2"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [ -d "$dir" ]; then
        log_success "$description: exists"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        log_error "$description: missing"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
}

# Test tool functionality
test_tool_functionality() {
    local tool="$1"
    local test_cmd="$2"
    local description="$3"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if eval "$test_cmd" >/dev/null 2>&1; then
        log_success "$description: functional"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        log_error "$description: not functional"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
}

main() {
    log_info "Starting environment health check..."
    echo
    
    # Core build tools
    log_info "Checking core build tools..."
    check_tool "rustc" "Rust compiler" "rustc --version | cut -d' ' -f2"
    check_tool "cargo" "Cargo package manager" "cargo --version | cut -d' ' -f2"
    check_tool "buck2" "Buck2 build system" "buck2 --version 2>/dev/null | head -1 | cut -d' ' -f2"
    echo
    
    # Rust development tools
    log_info "Checking Rust development tools..."
    check_tool "rustfmt" "Rust formatter" "rustfmt --version | cut -d' ' -f2"
    check_tool "clippy-driver" "Rust linter" "clippy-driver --version | cut -d' ' -f2"
    check_tool "cargo-audit" "Security auditor" "cargo audit --version | cut -d' ' -f2"
    check_tool "cargo-nextest" "Advanced test runner" "cargo nextest --version | cut -d' ' -f2"
    echo  
  # System tools (Rust-based)
    log_info "Checking system tools..."
    check_tool "rg" "ripgrep (fast search)" "rg --version | head -1 | cut -d' ' -f2"
    check_tool "fd" "fd (fast find)" "fd --version | cut -d' ' -f2"
    check_tool "bat" "bat (better cat)" "bat --version | cut -d' ' -f2"
    check_tool "exa" "exa (better ls)" "exa --version | cut -d' ' -f2"
    check_tool "tokei" "tokei (code stats)" "tokei --version | cut -d' ' -f2"
    check_tool "hyperfine" "hyperfine (benchmarking)" "hyperfine --version | cut -d' ' -f2"
    check_tool "watchexec" "watchexec (file watcher)" "watchexec --version | cut -d' ' -f2"
    check_tool "typos" "typos (spell checker)" "typos --version | cut -d' ' -f2"
    check_tool "dprint" "dprint (formatter)" "dprint --version"
    check_tool "just" "just (command runner)" "just --version | cut -d' ' -f2"
    echo
    
    # Language tools
    log_info "Checking language tools..."
    check_tool "node" "Node.js" "node --version | sed 's/v//'"
    check_tool "npm" "npm" "npm --version"
    check_tool "python3" "Python 3" "python3 --version | cut -d' ' -f2"
    check_tool "pip3" "pip3" "pip3 --version | cut -d' ' -f2"
    check_tool "go" "Go" "go version | cut -d' ' -f3 | sed 's/go//'"
    echo
    
    # Configuration files
    log_info "Checking configuration files..."
    check_file ".buckconfig" "Buck2 configuration"
    check_file ".buckroot" "Buck2 root marker"
    check_file "BUCK" "Root build file"
    check_file "config/rust-toolchain.toml" "Rust toolchain config"
    check_file "config/rustfmt.toml" "Rust formatter config"
    check_file "config/clippy.toml" "Clippy linter config"
    check_file "config/tools-versions.toml" "Tools versions config"
    echo
    
    # Directory structure
    log_info "Checking directory structure..."
    check_directory "apps" "Applications directory"
    check_directory "libs" "Libraries directory"
    check_directory "tools" "Tools directory"
    check_directory "infra" "Infrastructure directory"
    check_directory "docs" "Documentation directory"
    check_directory "scripts" "Scripts directory"
    check_directory "config" "Configuration directory"
    echo
    
    # Git configuration
    log_info "Checking Git configuration..."
    if [ -d ".git" ]; then
        check_file ".git/hooks/pre-commit" "Pre-commit hook"
        test_tool_functionality "git" "git status" "Git repository"
    else
        log_warning "Not a Git repository"
    fi
    echo
    
    # Tool functionality tests
    log_info "Testing tool functionality..."
    test_tool_functionality "rustc" "echo 'fn main() {}' | rustc - --crate-type bin -o /tmp/test_rust && /tmp/test_rust" "Rust compilation"
    test_tool_functionality "buck2" "buck2 targets //... --show-output" "Buck2 target resolution"
    test_tool_functionality "cargo" "cargo --version" "Cargo functionality"
    test_tool_functionality "dprint" "dprint check --config config/dprint.json || true" "dprint formatting check"
    echo
    
    # Performance tests
    log_info "Running performance tests..."
    if command -v hyperfine >/dev/null 2>&1; then
        log_info "Testing search performance..."
        if [ -d "target" ] || [ -d "node_modules" ] || [ -d ".git" ]; then
            hyperfine --warmup 1 --runs 3 'rg "function" . || true' 'grep -r "function" . || true' 2>/dev/null | head -5 || log_warning "Performance test failed"
        else
            log_warning "No large directories found for performance testing"
        fi
    fi
    echo
    
    # Security checks
    log_info "Running security checks..."
    if command -v cargo-audit >/dev/null 2>&1 && [ -f "Cargo.toml" ]; then
        test_tool_functionality "cargo-audit" "cargo audit" "Security audit"
    else
        log_warning "No Cargo.toml found, skipping security audit"
    fi
    echo
    
    # Summary
    log_info "Health check summary:"
    echo "  Total checks: $TOTAL_CHECKS"
    echo -e "  ${GREEN}Passed: $PASSED_CHECKS${NC}"
    echo -e "  ${RED}Failed: $FAILED_CHECKS${NC}"
    
    if [ $FAILED_CHECKS -eq 0 ]; then
        echo
        log_success "All checks passed! Your development environment is ready."
        exit 0
    else
        echo
        log_error "Some checks failed. Please review the output above and install missing tools."
        log_info "Run 'scripts/setup/bootstrap.sh' to install missing tools automatically."
        exit 1
    fi
}

# Handle command line arguments
case "${1:-full}" in
    "full")
        main
        ;;
    "quick")
        log_info "Running quick health check..."
        check_tool "rustc" "Rust compiler"
        check_tool "buck2" "Buck2 build system"
        check_tool "cargo" "Cargo"
        log_success "Quick check complete"
        ;;
    "tools")
        log_info "Checking development tools only..."
        check_tool "rg" "ripgrep"
        check_tool "fd" "fd"
        check_tool "bat" "bat"
        check_tool "dprint" "dprint"
        log_success "Tools check complete"
        ;;
    *)
        echo "Usage: $0 [full|quick|tools]"
        exit 1
        ;;
esac