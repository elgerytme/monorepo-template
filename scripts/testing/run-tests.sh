#!/bin/bash

# Comprehensive test runner script for Unix systems

set -euo pipefail

# Default values
TEST_TYPE="all"
COVERAGE=false
VERBOSE=false
FILTER=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to run command and check exit code
run_test_command() {
    local command=$1
    local description=$2
    
    print_color $CYAN "📋 $description"
    print_color $GRAY "   Command: $command"
    
    if eval "$command"; then
        print_color $GREEN "✅ $description completed successfully"
        echo ""
    else
        local exit_code=$?
        print_color $RED "❌ $description failed with exit code $exit_code"
        exit $exit_code
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --type)
            TEST_TYPE="$2"
            shift 2
            ;;
        --coverage)
            COVERAGE=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --filter)
            FILTER="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --type TYPE      Test type: unit, integration, performance, security, all (default: all)"
            echo "  --coverage       Enable coverage reporting"
            echo "  --verbose        Enable verbose output"
            echo "  --filter FILTER  Filter tests by pattern"
            echo "  -h, --help       Show this help message"
            exit 0
            ;;
        *)
            print_color $RED "Unknown option: $1"
            exit 1
            ;;
    esac
done

print_color $GREEN "🧪 Running comprehensive test suite..."

# Set environment variables
if [ "$VERBOSE" = true ]; then
    export RUST_LOG="debug"
else
    export RUST_LOG="info"
fi
export RUST_BACKTRACE=1

# Build the project first
run_test_command "buck2 build //..." "Building all targets"

# Run different test types based on parameter
case "${TEST_TYPE,,}" in
    "unit")
        print_color $YELLOW "🔬 Running unit tests only"
        
        if [ "$COVERAGE" = true ]; then
            run_test_command "cargo nextest run --profile ci --workspace --exclude integration-tests" "Unit tests with coverage"
        else
            run_test_command "cargo nextest run --workspace --exclude integration-tests" "Unit tests"
        fi
        ;;
    
    "integration")
        print_color $YELLOW "🔗 Running integration tests only"
        
        # Start test containers
        print_color $CYAN "🐳 Starting test containers..."
        
        run_test_command "buck2 test //examples/testing:integration-tests" "Integration tests"
        ;;
    
    "performance")
        print_color $YELLOW "⚡ Running performance tests"
        
        run_test_command "cargo bench --workspace" "Performance benchmarks"
        run_test_command "buck2 test //examples/testing:benchmarks" "Buck2 benchmarks"
        ;;
    
    "security")
        print_color $YELLOW "🔒 Running security tests"
        
        run_test_command "cargo audit" "Dependency vulnerability scan"
        run_test_command "cargo clippy --all-targets --all-features -- -W clippy::security" "Security linting"
        
        # Run custom security tests
        run_test_command "buck2 test //libs/testing-framework:security-tests" "Custom security tests"
        ;;
    
    "all")
        print_color $YELLOW "🎯 Running all test types"
        
        # Unit tests
        print_color $MAGENTA "🔬 Phase 1: Unit Tests"
        if [ "$COVERAGE" = true ]; then
            run_test_command "cargo nextest run --profile ci --workspace" "Unit tests with coverage"
        else
            run_test_command "cargo nextest run --workspace" "Unit tests"
        fi
        
        # Integration tests
        print_color $MAGENTA "🔗 Phase 2: Integration Tests"
        run_test_command "buck2 test //examples/testing:integration-tests" "Integration tests"
        
        # Performance tests
        print_color $MAGENTA "⚡ Phase 3: Performance Tests"
        run_test_command "cargo bench --workspace" "Performance benchmarks"
        
        # Security tests
        print_color $MAGENTA "🔒 Phase 4: Security Tests"
        run_test_command "cargo audit" "Dependency vulnerability scan"
        run_test_command "cargo clippy --all-targets --all-features -- -W clippy::security" "Security linting"
        
        # Buck2 tests
        print_color $MAGENTA "🏗️ Phase 5: Buck2 Tests"
        run_test_command "buck2 test //..." "All Buck2 tests"
        ;;
    
    *)
        print_color $RED "❌ Unknown test type: $TEST_TYPE"
        print_color $YELLOW "Valid options: unit, integration, performance, security, all"
        exit 1
        ;;
esac

# Generate test report if coverage was requested
if [ "$COVERAGE" = true ]; then
    print_color $CYAN "📊 Generating test coverage report..."
    
    # Generate HTML coverage report
    if [ -d "target/nextest/coverage" ]; then
        run_test_command "grcov target/nextest/coverage --binary-path target/debug/ -s . -t html --branch --ignore-not-existing -o target/coverage/" "Coverage report generation"
        print_color $GREEN "📈 Coverage report generated at: target/coverage/index.html"
    fi
fi

# Summary
print_color $GREEN "🎉 Test execution completed successfully!"
print_color $CYAN "📋 Test Summary:"
print_color $GRAY "   - Test Type: $TEST_TYPE"
print_color $GRAY "   - Coverage: $([ "$COVERAGE" = true ] && echo 'Enabled' || echo 'Disabled')"
print_color $GRAY "   - Verbose: $([ "$VERBOSE" = true ] && echo 'Enabled' || echo 'Disabled')"

if [ -n "$FILTER" ]; then
    print_color $GRAY "   - Filter: $FILTER"
fi