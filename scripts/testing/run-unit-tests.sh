#!/bin/bash
# Comprehensive unit testing script using nextest

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NEXTEST_CONFIG="config/nextest.toml"
COVERAGE_DIR="target/coverage"
JUNIT_OUTPUT="target/nextest-junit.xml"

echo -e "${GREEN}🧪 Running comprehensive unit tests with nextest${NC}"

# Ensure nextest is installed
if ! command -v cargo-nextest &> /dev/null; then
    echo -e "${YELLOW}Installing cargo-nextest...${NC}"
    cargo install cargo-nextest --locked
fi

# Create coverage directory
mkdir -p "$COVERAGE_DIR"

# Function to run tests with specific profile
run_tests_with_profile() {
    local profile=$1
    local description=$2
    
    echo -e "${GREEN}Running $description tests...${NC}"
    
    if [ "$profile" = "coverage" ]; then
        # Run with coverage collection
        RUSTFLAGS="-C instrument-coverage" \
        LLVM_PROFILE_FILE="$COVERAGE_DIR/nextest-%p-%m.profraw" \
        cargo nextest run \
            --config-file "$NEXTEST_CONFIG" \
            --profile "$profile" \
            --workspace \
            --all-features
    else
        cargo nextest run \
            --config-file "$NEXTEST_CONFIG" \
            --profile "$profile" \
            --workspace \
            --all-features
    fi
}

# Parse command line arguments
PROFILE="default"
COVERAGE=false
JUNIT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        --coverage)
            COVERAGE=true
            shift
            ;;
        --junit)
            JUNIT=true
            shift
            ;;
        --ci)
            PROFILE="ci"
            JUNIT=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --profile PROFILE    Use specific nextest profile (default, ci, coverage, bench)"
            echo "  --coverage          Generate code coverage report"
            echo "  --junit             Generate JUnit XML output"
            echo "  --ci                Use CI profile with JUnit output"
            echo "  -h, --help          Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Run tests based on configuration
if [ "$COVERAGE" = true ]; then
    run_tests_with_profile "coverage" "coverage"
    
    # Generate coverage report
    echo -e "${GREEN}Generating coverage report...${NC}"
    
    # Install grcov if not present
    if ! command -v grcov &> /dev/null; then
        echo -e "${YELLOW}Installing grcov...${NC}"
        cargo install grcov
    fi
    
    # Generate HTML coverage report
    grcov "$COVERAGE_DIR" \
        --source-dir . \
        --binary-path target/debug/ \
        --output-type html \
        --branch \
        --ignore-not-existing \
        --output-path "$COVERAGE_DIR/html"
    
    # Generate lcov format for CI
    grcov "$COVERAGE_DIR" \
        --source-dir . \
        --binary-path target/debug/ \
        --output-type lcov \
        --branch \
        --ignore-not-existing \
        --output-path "$COVERAGE_DIR/lcov.info"
    
    echo -e "${GREEN}Coverage report generated at $COVERAGE_DIR/html/index.html${NC}"
else
    run_tests_with_profile "$PROFILE" "$PROFILE"
fi

# Generate JUnit output if requested
if [ "$JUNIT" = true ] && [ -f "$JUNIT_OUTPUT" ]; then
    echo -e "${GREEN}JUnit XML report generated at $JUNIT_OUTPUT${NC}"
fi

echo -e "${GREEN}✅ Unit tests completed successfully${NC}"