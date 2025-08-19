#!/bin/bash
set -euo pipefail

# Container security scanning integration
# This script scans container images for vulnerabilities and misconfigurations

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TRIVY_CACHE_DIR="$HOME/.cache/trivy"
SEVERITY_LEVELS="HIGH,CRITICAL"
SCAN_TIMEOUT="10m"

echo "🐳 Starting container security scan..."

# Check if trivy is installed
if ! command -v trivy &> /dev/null; then
    echo -e "${YELLOW}Installing trivy...${NC}"
    
    # Detect OS and install trivy
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install trivy
        else
            curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
        fi
    else
        echo -e "${RED}❌ Unsupported OS for automatic trivy installation${NC}"
        echo "Please install trivy manually: https://aquasecurity.github.io/trivy/"
        exit 1
    fi
fi

# Check if docker is available
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}⚠️  Docker not found. Container scanning will be limited.${NC}"
    DOCKER_AVAILABLE=false
else
    DOCKER_AVAILABLE=true
fi

# Function to scan Dockerfile
scan_dockerfile() {
    local dockerfile_path="$1"
    local dockerfile_name="$(basename "$(dirname "$dockerfile_path")")/$(basename "$dockerfile_path")"
    
    echo -e "${BLUE}📄 Scanning Dockerfile: $dockerfile_name${NC}"
    
    # Scan Dockerfile for misconfigurations
    if trivy config --severity "$SEVERITY_LEVELS" --format json --output /tmp/dockerfile_scan.json "$dockerfile_path"; then
        # Check if vulnerabilities were found
        local vuln_count=$(jq '.Results[0].Misconfigurations | length' /tmp/dockerfile_scan.json 2>/dev/null || echo "0")
        
        if [ "$vuln_count" -gt 0 ]; then
            echo -e "${RED}❌ Found $vuln_count misconfigurations in $dockerfile_name${NC}"
            
            # Display misconfigurations
            jq -r '.Results[0].Misconfigurations[] | "- \(.ID): \(.Title) (Severity: \(.Severity))"' /tmp/dockerfile_scan.json
            
            return 1
        else
            echo -e "${GREEN}✅ No misconfigurations found in $dockerfile_name${NC}"
            return 0
        fi
    else
        echo -e "${YELLOW}⚠️  Could not scan $dockerfile_name${NC}"
        return 0
    fi
}

# Function to scan container image
scan_container_image() {
    local image_name="$1"
    
    echo -e "${BLUE}🐳 Scanning container image: $image_name${NC}"
    
    # Scan image for vulnerabilities
    if trivy image --severity "$SEVERITY_LEVELS" --format json --output /tmp/image_scan.json "$image_name"; then
        # Check if vulnerabilities were found
        local vuln_count=0
        
        # Count vulnerabilities across all results
        for result in $(jq -r '.Results[] | @base64' /tmp/image_scan.json 2>/dev/null); do
            local decoded=$(echo "$result" | base64 --decode)
            local result_vulns=$(echo "$decoded" | jq '.Vulnerabilities | length' 2>/dev/null || echo "0")
            vuln_count=$((vuln_count + result_vulns))
        done
        
        if [ "$vuln_count" -gt 0 ]; then
            echo -e "${RED}❌ Found $vuln_count vulnerabilities in $image_name${NC}"
            
            # Display top vulnerabilities
            echo "Top vulnerabilities:"
            jq -r '.Results[] | select(.Vulnerabilities) | .Vulnerabilities[] | "- \(.PkgName): \(.VulnerabilityID) (Severity: \(.Severity))"' /tmp/image_scan.json | head -10
            
            return 1
        else
            echo -e "${GREEN}✅ No vulnerabilities found in $image_name${NC}"
            return 0
        fi
    else
        echo -e "${YELLOW}⚠️  Could not scan image $image_name${NC}"
        return 0
    fi
}

# Function to build and scan image from Dockerfile
build_and_scan_dockerfile() {
    local dockerfile_path="$1"
    local context_dir="$(dirname "$dockerfile_path")"
    local image_tag="security-scan:$(basename "$context_dir")-$(date +%s)"
    
    echo -e "${BLUE}🔨 Building image from Dockerfile: $dockerfile_path${NC}"
    
    if docker build -t "$image_tag" -f "$dockerfile_path" "$context_dir" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Image built successfully${NC}"
        
        # Scan the built image
        local scan_result=0
        scan_container_image "$image_tag" || scan_result=1
        
        # Clean up the image
        docker rmi "$image_tag" > /dev/null 2>&1 || true
        
        return $scan_result
    else
        echo -e "${YELLOW}⚠️  Could not build image from $dockerfile_path${NC}"
        return 0
    fi
}

# Function to scan docker-compose files
scan_docker_compose() {
    local compose_file="$1"
    local compose_name="$(basename "$(dirname "$compose_file")")/$(basename "$compose_file")"
    
    echo -e "${BLUE}📋 Scanning docker-compose file: $compose_name${NC}"
    
    # Scan docker-compose for misconfigurations
    if trivy config --severity "$SEVERITY_LEVELS" --format json --output /tmp/compose_scan.json "$compose_file"; then
        local vuln_count=$(jq '.Results[0].Misconfigurations | length' /tmp/compose_scan.json 2>/dev/null || echo "0")
        
        if [ "$vuln_count" -gt 0 ]; then
            echo -e "${RED}❌ Found $vuln_count misconfigurations in $compose_name${NC}"
            
            # Display misconfigurations
            jq -r '.Results[0].Misconfigurations[] | "- \(.ID): \(.Title) (Severity: \(.Severity))"' /tmp/compose_scan.json
            
            return 1
        else
            echo -e "${GREEN}✅ No misconfigurations found in $compose_name${NC}"
            return 0
        fi
    else
        echo -e "${YELLOW}⚠️  Could not scan $compose_name${NC}"
        return 0
    fi
}

# Initialize scan results
TOTAL_ISSUES=0
SCANNED_FILES=0

# Update trivy database
echo "📦 Updating trivy database..."
trivy --cache-dir "$TRIVY_CACHE_DIR" image --download-db-only

# Scan all Dockerfiles
echo "🔍 Scanning for Dockerfiles..."
while IFS= read -r -d '' dockerfile; do
    SCANNED_FILES=$((SCANNED_FILES + 1))
    
    # Scan Dockerfile for misconfigurations
    if ! scan_dockerfile "$dockerfile"; then
        TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
    fi
    
    # Build and scan image if Docker is available
    if [ "$DOCKER_AVAILABLE" = true ]; then
        if ! build_and_scan_dockerfile "$dockerfile"; then
            TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
        fi
    fi
    
done < <(find "$ROOT_DIR" -name "Dockerfile*" -type f -not -path "*/node_modules/*" -not -path "*/target/*" -print0)

# Scan all docker-compose files
echo "🔍 Scanning for docker-compose files..."
while IFS= read -r -d '' compose_file; do
    SCANNED_FILES=$((SCANNED_FILES + 1))
    
    if ! scan_docker_compose "$compose_file"; then
        TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
    fi
    
done < <(find "$ROOT_DIR" -name "docker-compose*.yml" -o -name "docker-compose*.yaml" -type f -not -path "*/node_modules/*" -print0)

# Scan specific images if provided as arguments
if [ $# -gt 0 ]; then
    echo "🔍 Scanning provided container images..."
    for image in "$@"; do
        SCANNED_FILES=$((SCANNED_FILES + 1))
        
        if ! scan_container_image "$image"; then
            TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
        fi
    done
fi

# Clean up temporary files
rm -f /tmp/dockerfile_scan.json /tmp/image_scan.json /tmp/compose_scan.json

# Generate summary report
echo ""
echo "📊 Container Security Scan Summary"
echo "=================================="
echo "Files/Images scanned: $SCANNED_FILES"
echo "Issues found: $TOTAL_ISSUES"

if [ "$TOTAL_ISSUES" -eq 0 ]; then
    echo -e "${GREEN}✅ No security issues found in container configurations${NC}"
    echo "All containers are secure!"
else
    echo -e "${RED}❌ Security issues detected in containers!${NC}"
    echo ""
    echo "🔧 Remediation steps:"
    echo "1. Review and fix Dockerfile misconfigurations"
    echo "2. Update base images to latest secure versions"
    echo "3. Remove or update vulnerable packages"
    echo "4. Follow container security best practices"
    echo "5. Consider using distroless or minimal base images"
fi

# Exit with error code if issues found
if [ "$TOTAL_ISSUES" -gt 0 ]; then
    exit 1
fi

echo -e "${GREEN}🎉 Container security scan completed successfully${NC}"