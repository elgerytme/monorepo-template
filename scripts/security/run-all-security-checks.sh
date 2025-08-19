#!/bin/bash
set -euo pipefail

# Comprehensive security check orchestration
# This script runs all security checks in the correct order

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
PARALLEL_EXECUTION=false
FAIL_FAST=false
GENERATE_REPORT=true

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --parallel)
            PARALLEL_EXECUTION=true
            shift
            ;;
        --fail-fast)
            FAIL_FAST=true
            shift
            ;;
        --no-report)
            GENERATE_REPORT=false
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --parallel     Run security checks in parallel"
            echo "  --fail-fast    Stop on first failure"
            echo "  --no-report    Skip generating final report"
            echo "  -h, --help     Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo -e "${CYAN}🛡️  Starting comprehensive security assessment...${NC}"
echo "========================================================"

# Initialize results tracking
declare -A CHECK_RESULTS
declare -A CHECK_TIMES
TOTAL_CHECKS=0
FAILED_CHECKS=0
START_TIME=$(date +%s)

# Function to run a security check
run_security_check() {
    local check_name="$1"
    local script_path="$2"
    local description="$3"
    
    echo ""
    echo -e "${BLUE}🔍 Running: $description${NC}"
    echo "----------------------------------------"
    
    local check_start=$(date +%s)
    
    if [ -x "$script_path" ]; then
        if "$script_path"; then
            CHECK_RESULTS["$check_name"]="PASS"
            echo -e "${GREEN}✅ $check_name: PASSED${NC}"
        else
            CHECK_RESULTS["$check_name"]="FAIL"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            echo -e "${RED}❌ $check_name: FAILED${NC}"
            
            if [ "$FAIL_FAST" = true ]; then
                echo -e "${RED}Stopping due to --fail-fast flag${NC}"
                exit 1
            fi
        fi
    else
        CHECK_RESULTS["$check_name"]="SKIP"
        echo -e "${YELLOW}⚠️  $check_name: SKIPPED (script not executable)${NC}"
    fi
    
    local check_end=$(date +%s)
    CHECK_TIMES["$check_name"]=$((check_end - check_start))
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
}

# Function to run checks in parallel
run_parallel_checks() {
    echo -e "${CYAN}Running security checks in parallel...${NC}"
    
    # Create temporary directory for parallel execution
    local temp_dir=$(mktemp -d)
    
    # Define checks to run in parallel
    local checks=(
        "vulnerability-scan:$SCRIPT_DIR/vulnerability-scan.sh:Dependency vulnerability scanning"
        "secret-detection:$SCRIPT_DIR/secret-detection.sh:Secret detection and prevention"
        "container-security:$SCRIPT_DIR/container-security.sh:Container security scanning"
        "security-policy:$SCRIPT_DIR/security-policy.sh:Security policy enforcement"
    )
    
    # Start all checks in background
    for check in "${checks[@]}"; do
        IFS=':' read -r name script desc <<< "$check"
        
        (
            echo "Starting $name..." > "$temp_dir/$name.log"
            if "$script" >> "$temp_dir/$name.log" 2>&1; then
                echo "PASS" > "$temp_dir/$name.result"
            else
                echo "FAIL" > "$temp_dir/$name.result"
            fi
        ) &
    done
    
    # Wait for all background jobs to complete
    wait
    
    # Collect results
    for check in "${checks[@]}"; do
        IFS=':' read -r name script desc <<< "$check"
        
        local result=$(cat "$temp_dir/$name.result" 2>/dev/null || echo "ERROR")
        CHECK_RESULTS["$name"]="$result"
        
        if [ "$result" = "FAIL" ]; then
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            echo -e "${RED}❌ $name: FAILED${NC}"
            echo "Log output:"
            cat "$temp_dir/$name.log" | tail -10
        elif [ "$result" = "PASS" ]; then
            echo -e "${GREEN}✅ $name: PASSED${NC}"
        else
            echo -e "${YELLOW}⚠️  $name: ERROR${NC}"
        fi
        
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    done
    
    # Clean up
    rm -rf "$temp_dir"
}

# Function to run checks sequentially
run_sequential_checks() {
    echo -e "${CYAN}Running security checks sequentially...${NC}"
    
    # Run each security check
    run_security_check "vulnerability-scan" "$SCRIPT_DIR/vulnerability-scan.sh" "Dependency vulnerability scanning with cargo-audit"
    run_security_check "secret-detection" "$SCRIPT_DIR/secret-detection.sh" "Secret detection and prevention system"
    run_security_check "container-security" "$SCRIPT_DIR/container-security.sh" "Container security scanning integration"
    run_security_check "security-policy" "$SCRIPT_DIR/security-policy.sh" "Security policy enforcement automation"
}

# Function to generate comprehensive report
generate_security_report() {
    local end_time=$(date +%s)
    local total_time=$((end_time - START_TIME))
    
    echo ""
    echo -e "${CYAN}📊 Comprehensive Security Assessment Report${NC}"
    echo "=============================================="
    echo "Assessment completed at: $(date)"
    echo "Total execution time: ${total_time}s"
    echo "Total checks run: $TOTAL_CHECKS"
    echo "Failed checks: $FAILED_CHECKS"
    echo "Success rate: $(( (TOTAL_CHECKS - FAILED_CHECKS) * 100 / TOTAL_CHECKS ))%"
    echo ""
    
    echo -e "${CYAN}Check Results:${NC}"
    echo "-------------"
    for check in "${!CHECK_RESULTS[@]}"; do
        local result="${CHECK_RESULTS[$check]}"
        local time="${CHECK_TIMES[$check]:-0}"
        
        case $result in
            "PASS")
                echo -e "✅ $check: ${GREEN}PASSED${NC} (${time}s)"
                ;;
            "FAIL")
                echo -e "❌ $check: ${RED}FAILED${NC} (${time}s)"
                ;;
            "SKIP")
                echo -e "⚠️  $check: ${YELLOW}SKIPPED${NC} (${time}s)"
                ;;
            *)
                echo -e "❓ $check: ${YELLOW}UNKNOWN${NC} (${time}s)"
                ;;
        esac
    done
    
    echo ""
    if [ $FAILED_CHECKS -eq 0 ]; then
        echo -e "${GREEN}🎉 All security checks passed!${NC}"
        echo -e "${GREEN}Your codebase meets all security requirements.${NC}"
    else
        echo -e "${RED}⚠️  Security issues detected!${NC}"
        echo -e "${RED}Please review and address the failed checks above.${NC}"
        echo ""
        echo -e "${YELLOW}Recommended next steps:${NC}"
        echo "1. Review detailed output from failed checks"
        echo "2. Fix identified security vulnerabilities"
        echo "3. Update dependencies and configurations"
        echo "4. Re-run security assessment"
        echo "5. Consider implementing additional security measures"
    fi
    
    # Save report to file
    local report_file="$ROOT_DIR/security-assessment-report.txt"
    {
        echo "Security Assessment Report"
        echo "========================="
        echo "Generated: $(date)"
        echo "Total checks: $TOTAL_CHECKS"
        echo "Failed checks: $FAILED_CHECKS"
        echo ""
        echo "Results:"
        for check in "${!CHECK_RESULTS[@]}"; do
            echo "$check: ${CHECK_RESULTS[$check]}"
        done
    } > "$report_file"
    
    echo ""
    echo -e "${CYAN}📄 Detailed report saved to: $report_file${NC}"
}

# Main execution
echo "Configuration:"
echo "- Parallel execution: $PARALLEL_EXECUTION"
echo "- Fail fast: $FAIL_FAST"
echo "- Generate report: $GENERATE_REPORT"
echo ""

# Make sure all scripts are executable
chmod +x "$SCRIPT_DIR"/*.sh

# Run security checks
if [ "$PARALLEL_EXECUTION" = true ]; then
    run_parallel_checks
else
    run_sequential_checks
fi

# Generate report if requested
if [ "$GENERATE_REPORT" = true ]; then
    generate_security_report
fi

# Exit with appropriate code
if [ $FAILED_CHECKS -gt 0 ]; then
    echo ""
    echo -e "${RED}Security assessment completed with $FAILED_CHECKS failed checks.${NC}"
    exit 1
else
    echo ""
    echo -e "${GREEN}Security assessment completed successfully!${NC}"
    exit 0
fi