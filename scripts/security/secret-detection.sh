#!/bin/bash
set -euo pipefail

# Secret detection and prevention system
# This script scans for secrets in code and prevents them from being committed

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔐 Starting secret detection scan..."

# Check if gitleaks is installed
if ! command -v gitleaks &> /dev/null; then
    echo -e "${YELLOW}Installing gitleaks...${NC}"
    
    # Detect OS and install gitleaks
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        curl -sSfL https://github.com/gitleaks/gitleaks/releases/latest/download/gitleaks_linux_x64.tar.gz | tar -xz -C /tmp
        sudo mv /tmp/gitleaks /usr/local/bin/
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install gitleaks
        else
            curl -sSfL https://github.com/gitleaks/gitleaks/releases/latest/download/gitleaks_darwin_x64.tar.gz | tar -xz -C /tmp
            sudo mv /tmp/gitleaks /usr/local/bin/
        fi
    else
        echo -e "${RED}❌ Unsupported OS for automatic gitleaks installation${NC}"
        echo "Please install gitleaks manually: https://github.com/gitleaks/gitleaks"
        exit 1
    fi
fi

# Create gitleaks configuration if it doesn't exist
GITLEAKS_CONFIG="$ROOT_DIR/.gitleaks.toml"
if [ ! -f "$GITLEAKS_CONFIG" ]; then
    echo "📝 Creating gitleaks configuration..."
    cat > "$GITLEAKS_CONFIG" << 'EOF'
title = "Gitleaks Configuration"

[extend]
# Extend default rules
useDefault = true

[[rules]]
description = "AWS Access Key ID"
id = "aws-access-key-id"
regex = '''AKIA[0-9A-Z]{16}'''
tags = ["key", "AWS"]

[[rules]]
description = "AWS Secret Access Key"
id = "aws-secret-access-key"
regex = '''[A-Za-z0-9/+=]{40}'''
tags = ["key", "AWS"]

[[rules]]
description = "GitHub Personal Access Token"
id = "github-pat"
regex = '''ghp_[0-9a-zA-Z]{36}'''
tags = ["key", "GitHub"]

[[rules]]
description = "GitHub OAuth Access Token"
id = "github-oauth"
regex = '''gho_[0-9a-zA-Z]{36}'''
tags = ["key", "GitHub"]

[[rules]]
description = "GitHub App Token"
id = "github-app-token"
regex = '''(ghu|ghs)_[0-9a-zA-Z]{36}'''
tags = ["key", "GitHub"]

[[rules]]
description = "GitHub Refresh Token"
id = "github-refresh-token"
regex = '''ghr_[0-9a-zA-Z]{76}'''
tags = ["key", "GitHub"]

[[rules]]
description = "Slack Token"
id = "slack-access-token"
regex = '''xox[baprs]-([0-9a-zA-Z]{10,48})?'''
tags = ["key", "Slack"]

[[rules]]
description = "Private Key"
id = "private-key"
regex = '''-----BEGIN[ A-Z]*PRIVATE KEY-----'''
tags = ["key", "private"]

[[rules]]
description = "Generic API Key"
id = "generic-api-key"
regex = '''(?i)(api[_-]?key|apikey|secret[_-]?key|secretkey)['"]*\s*[:=]\s*['"][0-9a-zA-Z\-_]{16,}['"]'''
tags = ["key", "API"]

# Allowlist for test files and documentation
[allowlist]
description = "Allowlisted files"
files = [
    '''\.md$''',
    '''\.txt$''',
    '''test.*\.rs$''',
    '''.*_test\.go$''',
    '''.*\.test\.ts$''',
    '''.*\.spec\.ts$''',
    '''examples/.*''',
    '''docs/.*''',
]

# Allowlist for specific patterns that are not secrets
paths = [
    '''gitleaks\.toml''',
    '''\.gitleaks\.toml''',
]

# Allowlist for test/example values
regexes = [
    '''(example|test|fake|dummy|placeholder)''',
    '''your[_-]?(api[_-]?key|token|secret)''',
    '''<[A-Z_]+>''',
    '''\$\{[A-Z_]+\}''',
    '''AKIA00000000000000000''',
    '''ghp_0000000000000000000000000000000000000000''',
]
EOF
fi

# Function to scan for secrets
scan_secrets() {
    local scan_type="$1"
    local additional_args="$2"
    
    echo "🔍 Running $scan_type scan..."
    
    cd "$ROOT_DIR"
    
    # Run gitleaks with specified arguments
    if gitleaks detect --config="$GITLEAKS_CONFIG" $additional_args --report-format=json --report-path=/tmp/gitleaks-report.json; then
        echo -e "${GREEN}✅ No secrets found in $scan_type${NC}"
        return 0
    else
        echo -e "${RED}❌ Secrets detected in $scan_type!${NC}"
        
        # Parse and display results
        if [ -f "/tmp/gitleaks-report.json" ]; then
            echo ""
            echo "🚨 Secret Detection Results:"
            echo "============================"
            
            # Use jq to parse results if available, otherwise show raw output
            if command -v jq &> /dev/null; then
                jq -r '.[] | "File: \(.File)\nLine: \(.StartLine)\nRule: \(.RuleID)\nDescription: \(.Description)\nMatch: \(.Match)\n---"' /tmp/gitleaks-report.json
            else
                cat /tmp/gitleaks-report.json
            fi
            
            echo ""
            echo "🔧 Remediation steps:"
            echo "1. Remove or replace the detected secrets"
            echo "2. Use environment variables or secure secret management"
            echo "3. Add legitimate test values to the allowlist if needed"
            echo "4. Rotate any exposed secrets immediately"
        fi
        
        return 1
    fi
}

# Initialize results
SECRETS_FOUND=0

# Scan current working directory (uncommitted changes)
echo "📁 Scanning working directory for secrets..."
if ! scan_secrets "working directory" "--no-git"; then
    SECRETS_FOUND=1
fi

# Scan git history if we're in a git repository
if [ -d "$ROOT_DIR/.git" ]; then
    echo "📚 Scanning git history for secrets..."
    if ! scan_secrets "git history" ""; then
        SECRETS_FOUND=1
    fi
fi

# Create pre-commit hook if it doesn't exist
HOOKS_DIR="$ROOT_DIR/.git/hooks"
PRE_COMMIT_HOOK="$HOOKS_DIR/pre-commit"

if [ -d "$HOOKS_DIR" ] && [ ! -f "$PRE_COMMIT_HOOK" ]; then
    echo "🪝 Installing pre-commit hook for secret detection..."
    
    cat > "$PRE_COMMIT_HOOK" << 'EOF'
#!/bin/bash
# Pre-commit hook for secret detection

echo "🔐 Checking for secrets before commit..."

# Run gitleaks on staged files
if ! gitleaks protect --staged --config=.gitleaks.toml; then
    echo "❌ Secrets detected! Commit blocked."
    echo "Please remove secrets and try again."
    exit 1
fi

echo "✅ No secrets detected. Proceeding with commit."
EOF
    
    chmod +x "$PRE_COMMIT_HOOK"
    echo -e "${GREEN}✅ Pre-commit hook installed${NC}"
fi

# Clean up temporary files
rm -f /tmp/gitleaks-report.json

# Generate summary
echo ""
echo "📊 Secret Detection Summary"
echo "==========================="

if [ "$SECRETS_FOUND" -eq 0 ]; then
    echo -e "${GREEN}✅ No secrets detected across all scans${NC}"
    echo "Your repository is secure!"
else
    echo -e "${RED}❌ Secrets were detected!${NC}"
    echo "Please address the issues above before proceeding."
fi

# Exit with error code if secrets found
exit $SECRETS_FOUND