#!/bin/bash
# Backward compatibility checking script
# Ensures that changes don't break existing APIs and interfaces

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔄 Running backward compatibility checks..."

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

# Get the base branch (usually main or master)
BASE_BRANCH=${1:-"origin/main"}

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    print_status "FAIL" "Not in a git repository"
    exit 1
fi

# 1. Check for breaking changes in Rust APIs
echo "🦀 Checking Rust API compatibility..."
if command_exists cargo-semver-checks; then
    if cargo semver-checks check-release >/dev/null 2>&1; then
        print_status "PASS" "No breaking changes in Rust APIs"
        ((PASSED++))
    else
        print_status "FAIL" "Breaking changes detected in Rust APIs"
        ((FAILED++))
    fi
else
    # Fallback: check for removed public items
    if git diff --name-only "$BASE_BRANCH"...HEAD | grep -q "\.rs$"; then
        # Check for removed pub items
        REMOVED_PUBS=$(git diff "$BASE_BRANCH"...HEAD -- "*.rs" | grep "^-.*pub " | wc -l)
        if [ "$REMOVED_PUBS" -gt 0 ]; then
            print_status "FAIL" "Potential breaking changes: $REMOVED_PUBS public items removed"
            ((FAILED++))
        else
            print_status "PASS" "No obvious breaking changes in Rust code"
            ((PASSED++))
        fi
    else
        print_status "PASS" "No Rust files changed"
        ((PASSED++))
    fi
fi

# 2. Check TypeScript/JavaScript API compatibility
echo "📜 Checking TypeScript/JavaScript API compatibility..."
if git diff --name-only "$BASE_BRANCH"...HEAD | grep -qE "\.(ts|tsx|js|jsx)$"; then
    # Check for removed exports
    REMOVED_EXPORTS=$(git diff "$BASE_BRANCH"...HEAD -- "*.ts" "*.tsx" "*.js" "*.jsx" | grep "^-.*export " | wc -l)
    if [ "$REMOVED_EXPORTS" -gt 0 ]; then
        print_status "FAIL" "Potential breaking changes: $REMOVED_EXPORTS exports removed"
        ((FAILED++))
    else
        print_status "PASS" "No obvious breaking changes in TypeScript/JavaScript"
        ((PASSED++))
    fi
else
    print_status "PASS" "No TypeScript/JavaScript files changed"
    ((PASSED++))
fi

# 3. Check for database schema changes
echo "🗄️ Checking database schema compatibility..."
if git diff --name-only "$BASE_BRANCH"...HEAD | grep -qE "(migration|schema)" || \
   git diff --name-only "$BASE_BRANCH"...HEAD | grep -qE "\.(sql|prisma)$"; then
    
    # Check for DROP statements or column removals
    BREAKING_DB_CHANGES=$(git diff "$BASE_BRANCH"...HEAD | grep -iE "^[+].*DROP|^[+].*ALTER.*DROP" | wc -l)
    if [ "$BREAKING_DB_CHANGES" -gt 0 ]; then
        print_status "FAIL" "Breaking database changes detected"
        ((FAILED++))
    else
        print_status "PASS" "Database changes appear backward compatible"
        ((PASSED++))
    fi
else
    print_status "PASS" "No database schema changes"
    ((PASSED++))
fi

# 4. Check API contract changes (OpenAPI/GraphQL)
echo "📋 Checking API contract compatibility..."
if git diff --name-only "$BASE_BRANCH"...HEAD | grep -qE "(openapi|swagger|graphql)" || \
   git diff --name-only "$BASE_BRANCH"...HEAD | grep -qE "\.(yaml|yml|json)$" | head -5 | xargs grep -l "openapi\|swagger\|graphql" 2>/dev/null; then
    
    # Basic check for removed endpoints or fields
    REMOVED_ENDPOINTS=$(git diff "$BASE_BRANCH"...HEAD | grep -E "^-.*/(get|post|put|delete|patch)" | wc -l)
    if [ "$REMOVED_ENDPOINTS" -gt 0 ]; then
        print_status "FAIL" "API endpoints may have been removed"
        ((FAILED++))
    else
        print_status "PASS" "No obvious API contract breaking changes"
        ((PASSED++))
    fi
else
    print_status "PASS" "No API contract files changed"
    ((PASSED++))
fi

# 5. Check configuration file changes
echo "⚙️ Checking configuration compatibility..."
if git diff --name-only "$BASE_BRANCH"...HEAD | grep -qE "(config|\.env|\.toml|\.yaml|\.yml|\.json)$"; then
    # Check for removed configuration keys
    REMOVED_CONFIG_KEYS=$(git diff "$BASE_BRANCH"...HEAD | grep -E "^-[[:space:]]*[a-zA-Z_].*=" | wc -l)
    if [ "$REMOVED_CONFIG_KEYS" -gt 0 ]; then
        print_status "FAIL" "Configuration keys may have been removed: $REMOVED_CONFIG_KEYS"
        ((FAILED++))
    else
        print_status "PASS" "Configuration changes appear backward compatible"
        ((PASSED++))
    fi
else
    print_status "PASS" "No configuration files changed"
    ((PASSED++))
fi

# 6. Check for version bumps in dependencies
echo "📦 Checking dependency version compatibility..."
if git diff --name-only "$BASE_BRANCH"...HEAD | grep -qE "(Cargo\.toml|package\.json|requirements\.txt|go\.mod)"; then
    # Check for major version bumps
    MAJOR_BUMPS=$(git diff "$BASE_BRANCH"...HEAD | grep -E "^[+].*[0-9]+\.[0-9]+\.[0-9]+" | \
                  grep -v "^-.*[0-9]+\.[0-9]+\.[0-9]+" | wc -l)
    
    if [ "$MAJOR_BUMPS" -gt 0 ]; then
        print_status "WARN" "Dependency versions changed - review for compatibility"
    else
        print_status "PASS" "No major dependency version changes"
    fi
    ((PASSED++))
else
    print_status "PASS" "No dependency files changed"
    ((PASSED++))
fi

# Summary
echo ""
echo "📋 Compatibility Check Summary:"
echo "  Passed: $PASSED"
echo "  Failed: $FAILED"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All compatibility checks passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ $FAILED compatibility check(s) failed. Please review breaking changes.${NC}"
    echo ""
    echo "💡 Tips for fixing compatibility issues:"
    echo "  - Use deprecation warnings instead of removing APIs"
    echo "  - Add new fields as optional"
    echo "  - Maintain backward-compatible database migrations"
    echo "  - Version your APIs appropriately"
    exit 1
fi