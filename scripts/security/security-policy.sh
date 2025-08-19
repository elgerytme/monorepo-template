#!/bin/bash
set -euo pipefail

# Security policy enforcement automation
# This script enforces security policies across the codebase

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "🛡️  Starting security policy enforcement..."

# Configuration
POLICY_CONFIG="$ROOT_DIR/.security-policy.toml"
VIOLATIONS_FOUND=0

# Create default security policy configuration if it doesn't exist
create_default_policy() {
    cat > "$POLICY_CONFIG" << 'EOF'
# Security Policy Configuration

[general]
# Maximum allowed severity level for vulnerabilities
max_vulnerability_severity = "MEDIUM"
# Block commits with secrets
block_secrets = true
# Require security review for certain file types
require_security_review = [".env*", "*.key", "*.pem", "*.p12", "*.pfx"]

[dependencies]
# Allowed licenses for dependencies
allowed_licenses = [
    "MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", 
    "ISC", "MPL-2.0", "LGPL-2.1", "LGPL-3.0"
]
# Blocked packages (known security issues)
blocked_packages = []
# Maximum age for dependencies (days)
max_dependency_age = 365

[containers]
# Allowed base images
allowed_base_images = [
    "alpine:*", "ubuntu:*", "debian:*", "scratch",
    "gcr.io/distroless/*", "chainguard/*"
]
# Blocked base images (known vulnerabilities)
blocked_base_images = [
    "*:latest"  # Discourage latest tag
]
# Required security practices
require_non_root_user = true
require_health_check = true

[code]
# File patterns that require security review
security_sensitive_patterns = [
    "password", "secret", "token", "key", "auth",
    "crypto", "hash", "encrypt", "decrypt"
]
# Blocked functions/patterns
blocked_patterns = [
    "eval\\(", "exec\\(", "system\\(", "shell_exec\\(",
    "md5\\(", "sha1\\("  # Weak hashing
]

[network]
# Allowed outbound connections
allowed_domains = []
# Blocked domains
blocked_domains = []
# Require HTTPS for external connections
require_https = true
EOF
}

# Function to check dependency licenses
check_dependency_licenses() {
    echo -e "${BLUE}📋 Checking dependency licenses...${NC}"
    
    local violations=0
    
    # Check Rust dependencies
    if command -v cargo-license &> /dev/null || cargo install cargo-license; then
        find "$ROOT_DIR" -name "Cargo.toml" -not -path "*/target/*" | while read -r cargo_file; do
            local project_dir="$(dirname "$cargo_file")"
            local project_name="$(basename "$project_dir")"
            
            cd "$project_dir"
            
            # Get licenses in JSON format
            if cargo license --json > /tmp/licenses.json 2>/dev/null; then
                # Check for disallowed licenses
                local disallowed=$(jq -r '.[] | select(.license | test("GPL-3.0|AGPL|SSPL|Commons Clause") and (test("MIT|Apache|BSD") | not)) | .name' /tmp/licenses.json 2>/dev/null || echo "")
                
                if [ -n "$disallowed" ]; then
                    echo -e "${RED}❌ Disallowed licenses found in $project_name:${NC}"
                    echo "$disallowed" | while read -r pkg; do
                        echo "  - $pkg"
                    done
                    violations=$((violations + 1))
                fi
            fi
            
            cd "$ROOT_DIR"
        done
    fi
    
    return $violations
}

# Function to check for blocked patterns in code
check_blocked_patterns() {
    echo -e "${BLUE}🔍 Checking for blocked code patterns...${NC}"
    
    local violations=0
    
    # Define blocked patterns
    local patterns=(
        "eval\\("
        "exec\\("
        "system\\("
        "shell_exec\\("
        "md5\\("
        "sha1\\("
        "password.*=.*['\"][^'\"]{1,8}['\"]"  # Weak passwords
        "secret.*=.*['\"][^'\"]{1,12}['\"]"   # Hardcoded secrets
    )
    
    for pattern in "${patterns[@]}"; do
        echo "Checking pattern: $pattern"
        
        # Search for pattern in source files
        if grep -r -n --include="*.rs" --include="*.js" --include="*.ts" --include="*.py" --include="*.go" \
               --exclude-dir="target" --exclude-dir="node_modules" --exclude-dir=".git" \
               -E "$pattern" "$ROOT_DIR" > /tmp/pattern_matches.txt 2>/dev/null; then
            
            echo -e "${RED}❌ Blocked pattern found: $pattern${NC}"
            cat /tmp/pattern_matches.txt | head -5
            violations=$((violations + 1))
        fi
    done
    
    return $violations
}

# Function to check container security policies
check_container_policies() {
    echo -e "${BLUE}🐳 Checking container security policies...${NC}"
    
    local violations=0
    
    # Check Dockerfiles
    find "$ROOT_DIR" -name "Dockerfile*" -type f -not -path "*/node_modules/*" -not -path "*/target/*" | while read -r dockerfile; do
        local dockerfile_name="$(basename "$(dirname "$dockerfile")")/$(basename "$dockerfile")"
        
        echo "Checking Dockerfile: $dockerfile_name"
        
        # Check for latest tag usage
        if grep -q "FROM.*:latest" "$dockerfile"; then
            echo -e "${RED}❌ Using 'latest' tag in $dockerfile_name${NC}"
            violations=$((violations + 1))
        fi
        
        # Check for root user
        if ! grep -q "USER [^r]" "$dockerfile" && ! grep -q "USER [0-9]" "$dockerfile"; then
            echo -e "${YELLOW}⚠️  No non-root user specified in $dockerfile_name${NC}"
        fi
        
        # Check for health check
        if ! grep -q "HEALTHCHECK" "$dockerfile"; then
            echo -e "${YELLOW}⚠️  No health check specified in $dockerfile_name${NC}"
        fi
        
        # Check for secrets in build args
        if grep -i -E "(password|secret|token|key).*=" "$dockerfile"; then
            echo -e "${RED}❌ Potential secrets in build args in $dockerfile_name${NC}"
            violations=$((violations + 1))
        fi
    done
    
    return $violations
}

# Function to check file permissions and sensitive files
check_file_security() {
    echo -e "${BLUE}📁 Checking file security...${NC}"
    
    local violations=0
    
    # Check for sensitive files that shouldn't be committed
    local sensitive_files=(
        "*.key" "*.pem" "*.p12" "*.pfx" "*.jks"
        ".env" ".env.*" "*.env"
        "id_rsa" "id_dsa" "id_ecdsa" "id_ed25519"
        "*.sql" "*.dump"
    )
    
    for pattern in "${sensitive_files[@]}"; do
        if find "$ROOT_DIR" -name "$pattern" -not -path "*/.git/*" -not -path "*/target/*" -not -path "*/node_modules/*" | grep -q .; then
            echo -e "${RED}❌ Sensitive files found matching pattern: $pattern${NC}"
            find "$ROOT_DIR" -name "$pattern" -not -path "*/.git/*" -not -path "*/target/*" -not -path "*/node_modules/*" | head -5
            violations=$((violations + 1))
        fi
    done
    
    # Check for overly permissive files
    find "$ROOT_DIR" -type f -perm -o+w -not -path "*/.git/*" -not -path "*/target/*" -not -path "*/node_modules/*" | while read -r file; do
        echo -e "${YELLOW}⚠️  World-writable file found: $file${NC}"
    done
    
    return $violations
}

# Function to check network security configurations
check_network_security() {
    echo -e "${BLUE}🌐 Checking network security configurations...${NC}"
    
    local violations=0
    
    # Check for HTTP URLs in configuration files
    if grep -r -n --include="*.toml" --include="*.yaml" --include="*.yml" --include="*.json" \
           --exclude-dir="target" --exclude-dir="node_modules" --exclude-dir=".git" \
           "http://[^/]" "$ROOT_DIR" > /tmp/http_urls.txt 2>/dev/null; then
        
        echo -e "${YELLOW}⚠️  HTTP URLs found (consider using HTTPS):${NC}"
        cat /tmp/http_urls.txt | head -5
    fi
    
    # Check for hardcoded IP addresses
    if grep -r -n --include="*.rs" --include="*.js" --include="*.ts" --include="*.py" --include="*.go" \
           --exclude-dir="target" --exclude-dir="node_modules" --exclude-dir=".git" \
           -E "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" "$ROOT_DIR" > /tmp/ip_addresses.txt 2>/dev/null; then
        
        # Filter out common non-sensitive IPs
        if grep -v -E "(127\.0\.0\.1|0\.0\.0\.0|255\.255\.255\.255|192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)" /tmp/ip_addresses.txt > /tmp/suspicious_ips.txt; then
            if [ -s /tmp/suspicious_ips.txt ]; then
                echo -e "${YELLOW}⚠️  Hardcoded IP addresses found:${NC}"
                cat /tmp/suspicious_ips.txt | head -5
            fi
        fi
    fi
    
    return $violations
}

# Function to generate security policy report
generate_policy_report() {
    local total_violations="$1"
    
    echo ""
    echo "📊 Security Policy Enforcement Summary"
    echo "======================================"
    echo "Total policy violations: $total_violations"
    
    if [ "$total_violations" -eq 0 ]; then
        echo -e "${GREEN}✅ All security policies are compliant${NC}"
        echo "Your codebase follows security best practices!"
    else
        echo -e "${RED}❌ Security policy violations detected!${NC}"
        echo ""
        echo "🔧 Remediation steps:"
        echo "1. Review and fix all identified violations"
        echo "2. Update dependencies to secure versions"
        echo "3. Remove or secure sensitive files"
        echo "4. Follow container security best practices"
        echo "5. Use secure coding patterns"
        echo "6. Configure proper network security"
    fi
}

# Create default policy if it doesn't exist
if [ ! -f "$POLICY_CONFIG" ]; then
    echo "📝 Creating default security policy configuration..."
    create_default_policy
fi

# Run all security policy checks
echo "🔍 Running security policy checks..."

# Check dependency licenses
if ! check_dependency_licenses; then
    VIOLATIONS_FOUND=$((VIOLATIONS_FOUND + 1))
fi

# Check for blocked code patterns
if ! check_blocked_patterns; then
    VIOLATIONS_FOUND=$((VIOLATIONS_FOUND + 1))
fi

# Check container security policies
if ! check_container_policies; then
    VIOLATIONS_FOUND=$((VIOLATIONS_FOUND + 1))
fi

# Check file security
if ! check_file_security; then
    VIOLATIONS_FOUND=$((VIOLATIONS_FOUND + 1))
fi

# Check network security
if ! check_network_security; then
    VIOLATIONS_FOUND=$((VIOLATIONS_FOUND + 1))
fi

# Clean up temporary files
rm -f /tmp/licenses.json /tmp/pattern_matches.txt /tmp/http_urls.txt /tmp/ip_addresses.txt /tmp/suspicious_ips.txt

# Generate final report
generate_policy_report "$VIOLATIONS_FOUND"

# Exit with error code if violations found
if [ "$VIOLATIONS_FOUND" -gt 0 ]; then
    exit 1
fi

echo -e "${GREEN}🎉 Security policy enforcement completed successfully${NC}"