#!/bin/bash
# Comprehensive security testing script

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SECURITY_REPORTS_DIR="target/security-reports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="$SECURITY_REPORTS_DIR/security-report-$TIMESTAMP.json"
HTML_REPORT="$SECURITY_REPORTS_DIR/security-report-$TIMESTAMP.html"

echo -e "${GREEN}🔒 Running comprehensive security tests${NC}"

# Create reports directory
mkdir -p "$SECURITY_REPORTS_DIR"

# Function to install security tools
install_security_tools() {
    echo -e "${YELLOW}Installing security testing tools...${NC}"
    
    # Install cargo-audit for vulnerability scanning
    if ! command -v cargo-audit &> /dev/null; then
        cargo install cargo-audit
    fi
    
    # Install cargo-deny for license and security policy enforcement
    if ! command -v cargo-deny &> /dev/null; then
        cargo install cargo-deny
    fi
    
    # Install git-secrets for secret detection
    if ! command -v git-secrets &> /dev/null && command -v brew &> /dev/null; then
        brew install git-secrets
    fi
    
    # Install semgrep for static analysis
    if ! command -v semgrep &> /dev/null; then
        echo -e "${YELLOW}Installing semgrep...${NC}"
        python3 -m pip install semgrep
    fi
    
    # Install trivy for container scanning
    if ! command -v trivy &> /dev/null; then
        echo -e "${YELLOW}Installing trivy...${NC}"
        if command -v brew &> /dev/null; then
            brew install trivy
        elif command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y wget apt-transport-https gnupg lsb-release
            wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
            echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
            sudo apt-get update && sudo apt-get install -y trivy
        fi
    fi
}

# Function to run dependency audit
run_dependency_audit() {
    echo -e "${GREEN}Running dependency vulnerability audit...${NC}"
    
    local audit_file="$SECURITY_REPORTS_DIR/dependency-audit-$TIMESTAMP.json"
    
    if cargo audit --json > "$audit_file" 2>&1; then
        echo -e "${GREEN}✅ No vulnerabilities found in dependencies${NC}"
        return 0
    else
        echo -e "${RED}❌ Vulnerabilities found in dependencies${NC}"
        echo -e "${YELLOW}See details in: $audit_file${NC}"
        return 1
    fi
}

# Function to run static analysis with semgrep
run_static_analysis() {
    echo -e "${GREEN}Running static security analysis...${NC}"
    
    local semgrep_file="$SECURITY_REPORTS_DIR/semgrep-$TIMESTAMP.json"
    
    if command -v semgrep &> /dev/null; then
        semgrep --config=auto --json --output="$semgrep_file" . || true
        echo -e "${GREEN}Static analysis completed${NC}"
        echo -e "${YELLOW}Results saved to: $semgrep_file${NC}"
    else
        echo -e "${YELLOW}Semgrep not available, skipping static analysis${NC}"
    fi
}

# Function to run secret detection
run_secret_detection() {
    echo -e "${GREEN}Running secret detection...${NC}"
    
    local secrets_file="$SECURITY_REPORTS_DIR/secrets-$TIMESTAMP.txt"
    
    # Use git-secrets if available
    if command -v git-secrets &> /dev/null; then
        if git secrets --scan > "$secrets_file" 2>&1; then
            echo -e "${GREEN}✅ No secrets detected${NC}"
        else
            echo -e "${RED}❌ Potential secrets detected${NC}"
            echo -e "${YELLOW}See details in: $secrets_file${NC}"
        fi
    else
        # Fallback to basic pattern matching
        echo -e "${YELLOW}git-secrets not available, using basic pattern matching${NC}"
        
        # Search for common secret patterns
        grep -r -i -E "(password|passwd|pwd|secret|key|token|api_key|apikey)\s*[:=]\s*['\"]?[a-zA-Z0-9!@#$%^&*()_+\-=\[\]{}|;':\",./<>?`~]{8,}" \
            --exclude-dir=target \
            --exclude-dir=.git \
            --exclude="*.md" \
            --exclude="*.txt" \
            . > "$secrets_file" 2>/dev/null || true
        
        if [ -s "$secrets_file" ]; then
            echo -e "${RED}❌ Potential secrets detected${NC}"
            echo -e "${YELLOW}See details in: $secrets_file${NC}"
        else
            echo -e "${GREEN}✅ No obvious secrets detected${NC}"
        fi
    fi
}

# Function to run container security scanning
run_container_scan() {
    echo -e "${GREEN}Running container security scan...${NC}"
    
    local container_file="$SECURITY_REPORTS_DIR/container-scan-$TIMESTAMP.json"
    
    if command -v trivy &> /dev/null; then
        # Scan Dockerfile if it exists
        if [ -f "Dockerfile" ]; then
            trivy config --format json --output "$container_file" Dockerfile
            echo -e "${GREEN}Container configuration scan completed${NC}"
        fi
        
        # Scan container images if any are built
        if command -v docker &> /dev/null; then
            local images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>" | head -5)
            if [ -n "$images" ]; then
                for image in $images; do
                    local image_file="$SECURITY_REPORTS_DIR/image-scan-$(echo $image | tr '/:' '_')-$TIMESTAMP.json"
                    trivy image --format json --output "$image_file" "$image" || true
                done
                echo -e "${GREEN}Container image scans completed${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}Trivy not available, skipping container scanning${NC}"
    fi
}

# Function to run license compliance check
run_license_check() {
    echo -e "${GREEN}Running license compliance check...${NC}"
    
    local license_file="$SECURITY_REPORTS_DIR/license-check-$TIMESTAMP.txt"
    
    if command -v cargo-deny &> /dev/null; then
        if cargo deny check licenses > "$license_file" 2>&1; then
            echo -e "${GREEN}✅ License compliance check passed${NC}"
        else
            echo -e "${RED}❌ License compliance issues found${NC}"
            echo -e "${YELLOW}See details in: $license_file${NC}"
        fi
    else
        echo -e "${YELLOW}cargo-deny not available, skipping license check${NC}"
    fi
}

# Function to run security linting
run_security_linting() {
    echo -e "${GREEN}Running security-focused linting...${NC}"
    
    local clippy_file="$SECURITY_REPORTS_DIR/security-clippy-$TIMESTAMP.txt"
    
    # Run clippy with security-focused lints
    cargo clippy -- \
        -W clippy::all \
        -W clippy::pedantic \
        -W clippy::nursery \
        -W clippy::cargo \
        -W clippy::suspicious \
        -W clippy::perf \
        -W clippy::style \
        > "$clippy_file" 2>&1 || true
    
    echo -e "${GREEN}Security linting completed${NC}"
    echo -e "${YELLOW}Results saved to: $clippy_file${NC}"
}

# Function to generate comprehensive security report
generate_security_report() {
    echo -e "${GREEN}Generating comprehensive security report...${NC}"
    
    cat > "$HTML_REPORT" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Security Test Report - $TIMESTAMP</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .header { background-color: #f0f0f0; padding: 20px; border-radius: 5px; }
        .section { margin: 20px 0; padding: 15px; border-left: 4px solid #007cba; }
        .pass { border-left-color: #28a745; }
        .fail { border-left-color: #dc3545; }
        .warn { border-left-color: #ffc107; }
        .code { background-color: #f8f9fa; padding: 10px; border-radius: 3px; font-family: monospace; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔒 Security Test Report</h1>
        <p><strong>Generated:</strong> $(date)</p>
        <p><strong>Repository:</strong> $(git remote get-url origin 2>/dev/null || echo "Local repository")</p>
        <p><strong>Commit:</strong> $(git rev-parse --short HEAD 2>/dev/null || echo "Unknown")</p>
    </div>

    <div class="section">
        <h2>📊 Summary</h2>
        <table>
            <tr><th>Test Type</th><th>Status</th><th>Details</th></tr>
            <tr><td>Dependency Audit</td><td id="dep-status">-</td><td>Vulnerability scanning of dependencies</td></tr>
            <tr><td>Static Analysis</td><td id="static-status">-</td><td>Code security analysis with semgrep</td></tr>
            <tr><td>Secret Detection</td><td id="secret-status">-</td><td>Detection of hardcoded secrets</td></tr>
            <tr><td>Container Scanning</td><td id="container-status">-</td><td>Container and image security scanning</td></tr>
            <tr><td>License Compliance</td><td id="license-status">-</td><td>License compatibility and compliance</td></tr>
            <tr><td>Security Linting</td><td id="lint-status">-</td><td>Security-focused code linting</td></tr>
        </table>
    </div>

    <div class="section">
        <h2>📁 Report Files</h2>
        <ul>
EOF

    # Add links to generated report files
    for file in "$SECURITY_REPORTS_DIR"/*"$TIMESTAMP"*; do
        if [ -f "$file" ]; then
            local filename=$(basename "$file")
            echo "            <li><a href=\"$filename\">$filename</a></li>" >> "$HTML_REPORT"
        fi
    done

    cat >> "$HTML_REPORT" << EOF
        </ul>
    </div>

    <div class="section">
        <h2>🔧 Recommendations</h2>
        <ul>
            <li>Review all identified vulnerabilities and apply patches</li>
            <li>Update dependencies to latest secure versions</li>
            <li>Remove any detected secrets and rotate credentials</li>
            <li>Address license compliance issues</li>
            <li>Fix security linting warnings</li>
            <li>Implement security testing in CI/CD pipeline</li>
        </ul>
    </div>

    <div class="section">
        <h2>📚 Resources</h2>
        <ul>
            <li><a href="https://rustsec.org/">RustSec Advisory Database</a></li>
            <li><a href="https://github.com/RustSec/cargo-audit">cargo-audit Documentation</a></li>
            <li><a href="https://semgrep.dev/">Semgrep Security Rules</a></li>
            <li><a href="https://aquasecurity.github.io/trivy/">Trivy Container Scanner</a></li>
        </ul>
    </div>
</body>
</html>
EOF

    echo -e "${GREEN}Security report generated: $HTML_REPORT${NC}"
}

# Parse command line arguments
INSTALL_TOOLS=false
RUN_ALL=true
SKIP_CONTAINERS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --install-tools)
            INSTALL_TOOLS=true
            shift
            ;;
        --skip-containers)
            SKIP_CONTAINERS=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --install-tools    Install required security testing tools"
            echo "  --skip-containers  Skip container security scanning"
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
    install_security_tools
fi

# Run security tests
echo -e "${GREEN}Starting security test suite...${NC}"

# Track overall success
OVERALL_SUCCESS=true

# Run dependency audit
if ! run_dependency_audit; then
    OVERALL_SUCCESS=false
fi

# Run static analysis
run_static_analysis

# Run secret detection
run_secret_detection

# Run container scanning (unless skipped)
if [ "$SKIP_CONTAINERS" = false ]; then
    run_container_scan
fi

# Run license compliance check
if ! run_license_check; then
    OVERALL_SUCCESS=false
fi

# Run security linting
run_security_linting

# Generate comprehensive report
generate_security_report

# Final status
if [ "$OVERALL_SUCCESS" = true ]; then
    echo -e "${GREEN}✅ Security testing completed successfully${NC}"
    echo -e "${GREEN}📊 View detailed report: $HTML_REPORT${NC}"
    exit 0
else
    echo -e "${RED}❌ Security issues detected${NC}"
    echo -e "${YELLOW}📊 View detailed report: $HTML_REPORT${NC}"
    exit 1
fi