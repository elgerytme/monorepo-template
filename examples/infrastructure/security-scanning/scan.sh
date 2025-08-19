#!/bin/bash

# Infrastructure Security Scanning Script
# This script runs multiple security scanning tools against the infrastructure code

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"
RESULTS_DIR="$SCRIPT_DIR/results"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create results directory
mkdir -p "$RESULTS_DIR"

echo -e "${BLUE}🔍 Starting Infrastructure Security Scan${NC}"
echo "Terraform directory: $TERRAFORM_DIR"
echo "Results directory: $RESULTS_DIR"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install tools if needed
install_tools() {
    echo -e "${YELLOW}📦 Checking and installing security scanning tools...${NC}"
    
    # Install tfsec
    if ! command_exists tfsec; then
        echo "Installing tfsec..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install tfsec
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
        else
            echo "Please install tfsec manually: https://github.com/aquasecurity/tfsec#installation"
            exit 1
        fi
    fi
    
    # Install checkov
    if ! command_exists checkov; then
        echo "Installing checkov..."
        pip3 install checkov
    fi
    
    # Install terrascan
    if ! command_exists terrascan; then
        echo "Installing terrascan..."
        curl -L "$(curl -s https://api.github.com/repos/tenable/terrascan/releases/latest | grep -o -E "https://.+?_Linux_x86_64.tar.gz")" > terrascan.tar.gz
        tar -xf terrascan.tar.gz terrascan && rm terrascan.tar.gz
        sudo mv terrascan /usr/local/bin && chmod +x /usr/local/bin/terrascan
    fi
    
    echo -e "${GREEN}✅ Tools installation complete${NC}"
    echo ""
}

# Function to run tfsec
run_tfsec() {
    echo -e "${BLUE}🔒 Running tfsec security scan...${NC}"
    
    cd "$TERRAFORM_DIR"
    
    # Run tfsec with configuration
    if tfsec --config-file "$SCRIPT_DIR/tfsec.yml" \
             --format json \
             --out "$RESULTS_DIR/tfsec-results.json" \
             --format lovely \
             --out "$RESULTS_DIR/tfsec-results.txt" \
             .; then
        echo -e "${GREEN}✅ tfsec scan completed successfully${NC}"
    else
        echo -e "${RED}❌ tfsec scan found security issues${NC}"
        return 1
    fi
    
    cd "$SCRIPT_DIR"
}

# Function to run checkov
run_checkov() {
    echo -e "${BLUE}🔍 Running checkov security scan...${NC}"
    
    # Run checkov with configuration
    if checkov --config-file "$SCRIPT_DIR/checkov.yml" \
               --directory "$TERRAFORM_DIR" \
               --output json \
               --output-file-path "$RESULTS_DIR/checkov-results.json" \
               --output cli; then
        echo -e "${GREEN}✅ checkov scan completed successfully${NC}"
    else
        echo -e "${RED}❌ checkov scan found security issues${NC}"
        return 1
    fi
}

# Function to run terrascan
run_terrascan() {
    echo -e "${BLUE}🛡️  Running terrascan security scan...${NC}"
    
    cd "$TERRAFORM_DIR"
    
    # Run terrascan
    if terrascan scan \
                --iac-type terraform \
                --output json \
                --output-file "$RESULTS_DIR/terrascan-results.json" \
                --verbose; then
        echo -e "${GREEN}✅ terrascan scan completed successfully${NC}"
    else
        echo -e "${RED}❌ terrascan scan found security issues${NC}"
        return 1
    fi
    
    cd "$SCRIPT_DIR"
}

# Function to generate summary report
generate_summary() {
    echo -e "${BLUE}📊 Generating security scan summary...${NC}"
    
    cat > "$RESULTS_DIR/security-summary.md" << EOF
# Infrastructure Security Scan Summary

Generated on: $(date)

## Scan Results

### tfsec Results
$(if [ -f "$RESULTS_DIR/tfsec-results.json" ]; then
    echo "✅ Scan completed - see tfsec-results.json for details"
else
    echo "❌ Scan failed or not run"
fi)

### checkov Results
$(if [ -f "$RESULTS_DIR/checkov-results.json" ]; then
    echo "✅ Scan completed - see checkov-results.json for details"
else
    echo "❌ Scan failed or not run"
fi)

### terrascan Results
$(if [ -f "$RESULTS_DIR/terrascan-results.json" ]; then
    echo "✅ Scan completed - see terrascan-results.json for details"
else
    echo "❌ Scan failed or not run"
fi)

## Files Scanned
- Terraform configuration files in: $TERRAFORM_DIR
- Docker files (if present)
- Kubernetes manifests (if present)

## Next Steps
1. Review the detailed results in the JSON files
2. Address any HIGH or CRITICAL severity findings
3. Update security baseline if needed
4. Re-run scans after fixes

## Tool Versions
- tfsec: $(tfsec --version 2>/dev/null || echo "Not installed")
- checkov: $(checkov --version 2>/dev/null || echo "Not installed")
- terrascan: $(terrascan version 2>/dev/null || echo "Not installed")
EOF

    echo -e "${GREEN}✅ Summary report generated: $RESULTS_DIR/security-summary.md${NC}"
}

# Main execution
main() {
    local exit_code=0
    
    # Install tools if needed
    install_tools
    
    # Run security scans
    echo -e "${YELLOW}🚀 Starting security scans...${NC}"
    echo ""
    
    # Run tfsec
    if ! run_tfsec; then
        exit_code=1
    fi
    echo ""
    
    # Run checkov
    if ! run_checkov; then
        exit_code=1
    fi
    echo ""
    
    # Run terrascan
    if ! run_terrascan; then
        exit_code=1
    fi
    echo ""
    
    # Generate summary
    generate_summary
    echo ""
    
    # Final status
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}🎉 All security scans completed successfully!${NC}"
        echo -e "${GREEN}Results available in: $RESULTS_DIR${NC}"
    else
        echo -e "${RED}⚠️  Security scans completed with issues found${NC}"
        echo -e "${YELLOW}Please review the results and address any security findings${NC}"
        echo -e "${BLUE}Results available in: $RESULTS_DIR${NC}"
    fi
    
    return $exit_code
}

# Run main function
main "$@"