#!/bin/bash
# Master script to run all types of tests

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPORTS_DIR="target/test-reports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

echo -e "${BLUE}🧪 Running comprehensive test suite${NC}"

# Create reports directory
mkdir -p "$REPORTS_DIR"

# Function to run tests and capture results
run_test_suite() {
    local test_type=$1
    local script_path=$2
    local args=${3:-""}
    
    echo -e "${GREEN}Running $test_type tests...${NC}"
    
    local log_file="$REPORTS_DIR/${test_type}-${TIMESTAMP}.log"
    local start_time=$(date +%s)
    
    if eval "$script_path $args" > "$log_file" 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${GREEN}✅ $test_type tests passed (${duration}s)${NC}"
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${RED}❌ $test_type tests failed (${duration}s)${NC}"
        echo -e "${YELLOW}See log: $log_file${NC}"
        return 1
    fi
}

# Parse command line arguments
RUN_UNIT=true
RUN_INTEGRATION=true
RUN_PERFORMANCE=false
RUN_SECURITY=true
INSTALL_TOOLS=false
FAIL_FAST=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --unit-only)
            RUN_INTEGRATION=false
            RUN_PERFORMANCE=false
            RUN_SECURITY=false
            shift
            ;;
        --integration-only)
            RUN_UNIT=false
            RUN_PERFORMANCE=false
            RUN_SECURITY=false
            shift
            ;;
        --performance)
            RUN_PERFORMANCE=true
            shift
            ;;
        --no-security)
            RUN_SECURITY=false
            shift
            ;;
        --install-tools)
            INSTALL_TOOLS=true
            shift
            ;;
        --fail-fast)
            FAIL_FAST=true
            shift
            ;;
        --all)
            RUN_UNIT=true
            RUN_INTEGRATION=true
            RUN_PERFORMANCE=true
            RUN_SECURITY=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --unit-only        Run only unit tests"
            echo "  --integration-only Run only integration tests"
            echo "  --performance      Include performance tests"
            echo "  --no-security      Skip security tests"
            echo "  --install-tools    Install required testing tools"
            echo "  --fail-fast        Stop on first test failure"
            echo "  --all              Run all test types"
            echo "  -h, --help         Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Install tools if requested
if [ "$INSTALL_TOOLS" = true ]; then
    echo -e "${YELLOW}Installing testing tools...${NC}"
    
    if [ "$RUN_UNIT" = true ]; then
        cargo install cargo-nextest --locked || true
    fi
    
    if [ "$RUN_PERFORMANCE" = true ]; then
        ./scripts/testing/run-performance-tests.sh --install-tools || true
    fi
    
    if [ "$RUN_SECURITY" = true ]; then
        ./scripts/testing/run-security-tests.sh --install-tools || true
    fi
fi

# Track overall results
OVERALL_SUCCESS=true
FAILED_TESTS=()

# Run test suites
if [ "$RUN_UNIT" = true ]; then
    if ! run_test_suite "unit" "./scripts/testing/run-unit-tests.sh" "--ci --coverage"; then
        OVERALL_SUCCESS=false
        FAILED_TESTS+=("unit")
        if [ "$FAIL_FAST" = true ]; then
            echo -e "${RED}Stopping due to --fail-fast${NC}"
            exit 1
        fi
    fi
fi

if [ "$RUN_INTEGRATION" = true ]; then
    if ! run_test_suite "integration" "cargo test" "--test integration_tests"; then
        OVERALL_SUCCESS=false
        FAILED_TESTS+=("integration")
        if [ "$FAIL_FAST" = true ]; then
            echo -e "${RED}Stopping due to --fail-fast${NC}"
            exit 1
        fi
    fi
fi

if [ "$RUN_PERFORMANCE" = true ]; then
    if ! run_test_suite "performance" "./scripts/testing/run-performance-tests.sh" "--all"; then
        OVERALL_SUCCESS=false
        FAILED_TESTS+=("performance")
        if [ "$FAIL_FAST" = true ]; then
            echo -e "${RED}Stopping due to --fail-fast${NC}"
            exit 1
        fi
    fi
fi

if [ "$RUN_SECURITY" = true ]; then
    if ! run_test_suite "security" "./scripts/testing/run-security-tests.sh" ""; then
        OVERALL_SUCCESS=false
        FAILED_TESTS+=("security")
        if [ "$FAIL_FAST" = true ]; then
            echo -e "${RED}Stopping due to --fail-fast${NC}"
            exit 1
        fi
    fi
fi

# Generate summary report
echo -e "${BLUE}Generating test summary report...${NC}"

cat > "$REPORTS_DIR/test-summary-$TIMESTAMP.md" << EOF
# Test Suite Summary Report

**Generated:** $(date)  
**Repository:** $(git remote get-url origin 2>/dev/null || echo "Local repository")  
**Commit:** $(git rev-parse --short HEAD 2>/dev/null || echo "Unknown")

## Results Summary

EOF

if [ "$OVERALL_SUCCESS" = true ]; then
    echo "**Overall Status:** ✅ PASSED" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
else
    echo "**Overall Status:** ❌ FAILED" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
    echo "" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
    echo "**Failed Test Suites:** ${FAILED_TESTS[*]}" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
fi

echo "" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
echo "## Test Suite Details" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
echo "" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"

# Add details for each test type
if [ "$RUN_UNIT" = true ]; then
    echo "### Unit Tests" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
    echo "- **Framework:** nextest" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
    echo "- **Coverage:** Enabled" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
    echo "- **Log:** [unit-$TIMESTAMP.log](unit-$TIMESTAMP.log)" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
    echo "" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
fi

if [ "$RUN_INTEGRATION" = true ]; then
    echo "### Integration Tests" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
    echo "- **Framework:** testcontainers" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
    echo "- **Containers:** PostgreSQL, Redis" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
    echo "- **Log:** [integration-$TIMESTAMP.log](integration-$TIMESTAMP.log)" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
    echo "" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
fi

if [ "$RUN_PERFORMANCE" = true ]; then
    echo "### Performance Tests" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
    echo "- **Framework:** criterion, hyperfine" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
    echo "- **Profiling:** flamegraph" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
    echo "- **Log:** [performance-$TIMESTAMP.log](performance-$TIMESTAMP.log)" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
    echo "" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
fi

if [ "$RUN_SECURITY" = true ]; then
    echo "### Security Tests" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
    echo "- **Tools:** cargo-audit, semgrep, trivy" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
    echo "- **Scans:** Dependencies, secrets, containers" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
    echo "- **Log:** [security-$TIMESTAMP.log](security-$TIMESTAMP.log)" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
    echo "" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
fi

echo "## Artifacts" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
echo "" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
echo "- Coverage Report: \`target/coverage/html/index.html\`" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
echo "- Performance Report: \`target/performance-reports/performance-summary.md\`" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
echo "- Security Report: \`target/security-reports/security-report-*.html\`" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
echo "" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"

echo "## Next Steps" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
echo "" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"

if [ "$OVERALL_SUCCESS" = true ]; then
    echo "- ✅ All tests passed - ready for deployment" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
    echo "- 📊 Review performance metrics for optimization opportunities" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
    echo "- 🔒 Review security scan results for compliance" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
else
    echo "- ❌ Fix failing tests before deployment" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
    echo "- 📋 Review detailed logs for failure analysis" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
    echo "- 🔄 Re-run tests after fixes" >> "$REPORTS_DIR/test-summary-$TIMESTAMP.md"
fi

# Final output
echo -e "${BLUE}📊 Test Summary Report: $REPORTS_DIR/test-summary-$TIMESTAMP.md${NC}"

if [ "$OVERALL_SUCCESS" = true ]; then
    echo -e "${GREEN}🎉 All test suites completed successfully!${NC}"
    exit 0
else
    echo -e "${RED}💥 Some test suites failed. Check the logs for details.${NC}"
    echo -e "${YELLOW}Failed suites: ${FAILED_TESTS[*]}${NC}"
    exit 1
fi