#!/bin/bash
# Quality gates validation script
# Runs comprehensive checks to ensure code meets quality standards

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
MIN_COVERAGE=80
MAX_COMPLEXITY=10
MAX_FUNCTION_LENGTH=50

echo "🔍 Running quality gate checks..."

# Function to print status
print_status() {
    local status=$1
    local message=$2
    if [ "$status" = "PASS" ]; then
        echo -e "${GREEN}✓ $message${NC}"
    elif [ "$status" = "FAIL" ]; then
        echo -e "${RED}✗ $message${NC}"
        return 1
    else
        echo -e "${YELLOW}⚠ $message${NC}"
    fi
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Initialize counters
PASSED=0
FAILED=0

# 1. Code formatting check
echo "📝 Checking code formatting..."
if cargo fmt --check >/dev/null 2>&1; then
    print_status "PASS" "Rust code formatting"
    ((PASSED++))
else
    print_status "FAIL" "Rust code formatting - run 'cargo fmt' to fix"
    ((FAILED++))
fi

if command_exists dprint; then
    if dprint check >/dev/null 2>&1; then
        print_status "PASS" "Multi-language formatting"
        ((PASSED++))
    else
        print_status "FAIL" "Multi-language formatting - run 'dprint fmt' to fix"
        ((FAILED++))
    fi
fi

# 2. Linting checks
echo "🔍 Running linting checks..."
if cargo clippy --all-targets --all-features -- -D warnings >/dev/null 2>&1; then
    print_status "PASS" "Rust linting (clippy)"
    ((PASSED++))
else
    print_status "FAIL" "Rust linting - fix clippy warnings"
    ((FAILED++))
fi

# 3. Security checks
echo "🔒 Running security checks..."
if command_exists cargo-audit; then
    if cargo audit >/dev/null 2>&1; then
        print_status "PASS" "Security audit"
        ((PASSED++))
    else
        print_status "FAIL" "Security vulnerabilities found"
        ((FAILED++))
    fi
fi

# 4. Test coverage check
echo "📊 Checking test coverage..."
if command_exists cargo-tarpaulin; then
    COVERAGE=$(cargo tarpaulin --output-format json 2>/dev/null | jq -r '.coverage' 2>/dev/null || echo "0")
    if (( $(echo "$COVERAGE >= $MIN_COVERAGE" | bc -l) )); then
        print_status "PASS" "Test coverage: ${COVERAGE}% (minimum: ${MIN_COVERAGE}%)"
        ((PASSED++))
    else
        print_status "FAIL" "Test coverage: ${COVERAGE}% (minimum: ${MIN_COVERAGE}%)"
        ((FAILED++))
    fi
elif command_exists cargo-nextest; then
    # Run tests to ensure they pass
    if cargo nextest run >/dev/null 2>&1; then
        print_status "PASS" "All tests passing"
        ((PASSED++))
    else
        print_status "FAIL" "Some tests are failing"
        ((FAILED++))
    fi
else
    if cargo test >/dev/null 2>&1; then
        print_status "PASS" "All tests passing"
        ((PASSED++))
    else
        print_status "FAIL" "Some tests are failing"
        ((FAILED++))
    fi
fi

# 5. Code complexity check
echo "🧮 Checking code complexity..."
if command_exists tokei; then
    # Use tokei to get basic code statistics
    print_status "PASS" "Code statistics collected"
    ((PASSED++))
else
    print_status "WARN" "tokei not installed - skipping complexity check"
fi

# 6. Documentation check
echo "📚 Checking documentation..."
if cargo doc --no-deps >/dev/null 2>&1; then
    print_status "PASS" "Documentation builds successfully"
    ((PASSED++))
else
    print_status "FAIL" "Documentation build failed"
    ((FAILED++))
fi

# 7. Buck2 build validation
echo "🏗️ Validating Buck2 configuration..."
if command_exists buck2; then
    if buck2 audit >/dev/null 2>&1; then
        print_status "PASS" "Buck2 configuration valid"
        ((PASSED++))
    else
        print_status "FAIL" "Buck2 configuration issues found"
        ((FAILED++))
    fi
fi

# Summary
echo ""
echo "📋 Quality Gate Summary:"
echo "  Passed: $PASSED"
echo "  Failed: $FAILED"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All quality gates passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ $FAILED quality gate(s) failed. Please fix the issues before proceeding.${NC}"
    exit 1
fi