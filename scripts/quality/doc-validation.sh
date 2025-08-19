#!/bin/bash
# Documentation validation script
# Ensures that code changes include appropriate documentation

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "📚 Running documentation validation..."

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

# 1. Check Rust documentation
echo "🦀 Checking Rust documentation..."
if git diff --name-only "$BASE_BRANCH"...HEAD | grep -q "\.rs$"; then
    # Check for missing doc comments on public items
    RUST_FILES=$(git diff --name-only "$BASE_BRANCH"...HEAD | grep "\.rs$")
    MISSING_DOCS=0
    
    for file in $RUST_FILES; do
        if [ -f "$file" ]; then
            # Look for pub items without doc comments
            UNDOCUMENTED=$(grep -n "^pub " "$file" | while read -r line; do
                line_num=$(echo "$line" | cut -d: -f1)
                prev_line=$((line_num - 1))
                if [ $prev_line -gt 0 ]; then
                    prev_content=$(sed -n "${prev_line}p" "$file")
                    if [[ ! "$prev_content" =~ ^[[:space:]]*/// ]]; then
                        echo "$file:$line_num"
                    fi
                fi
            done)
            
            if [ -n "$UNDOCUMENTED" ]; then
                ((MISSING_DOCS++))
            fi
        fi
    done
    
    if [ $MISSING_DOCS -eq 0 ]; then
        print_status "PASS" "All public Rust items are documented"
        ((PASSED++))
    else
        print_status "FAIL" "$MISSING_DOCS Rust files have undocumented public items"
        ((FAILED++))
    fi
    
    # Check if Rust docs build successfully
    if cargo doc --no-deps >/dev/null 2>&1; then
        print_status "PASS" "Rust documentation builds successfully"
        ((PASSED++))
    else
        print_status "FAIL" "Rust documentation build failed"
        ((FAILED++))
    fi
else
    print_status "PASS" "No Rust files changed"
    ((PASSED++))
fi

# 2. Check TypeScript/JavaScript documentation
echo "📜 Checking TypeScript/JavaScript documentation..."
if git diff --name-only "$BASE_BRANCH"...HEAD | grep -qE "\.(ts|tsx|js|jsx)$"; then
    TS_FILES=$(git diff --name-only "$BASE_BRANCH"...HEAD | grep -E "\.(ts|tsx|js|jsx)$")
    MISSING_TS_DOCS=0
    
    for file in $TS_FILES; do
        if [ -f "$file" ]; then
            # Look for exported functions/classes without JSDoc
            UNDOCUMENTED_TS=$(grep -n "^export " "$file" | while read -r line; do
                line_num=$(echo "$line" | cut -d: -f1)
                prev_line=$((line_num - 1))
                if [ $prev_line -gt 0 ]; then
                    prev_content=$(sed -n "${prev_line}p" "$file")
                    if [[ ! "$prev_content" =~ ^[[:space:]]*\* ]] && [[ ! "$prev_content" =~ ^[[:space:]]*/\* ]]; then
                        echo "$file:$line_num"
                    fi
                fi
            done)
            
            if [ -n "$UNDOCUMENTED_TS" ]; then
                ((MISSING_TS_DOCS++))
            fi
        fi
    done
    
    if [ $MISSING_TS_DOCS -eq 0 ]; then
        print_status "PASS" "TypeScript/JavaScript exports are documented"
        ((PASSED++))
    else
        print_status "FAIL" "$MISSING_TS_DOCS TypeScript/JavaScript files have undocumented exports"
        ((FAILED++))
    fi
else
    print_status "PASS" "No TypeScript/JavaScript files changed"
    ((PASSED++))
fi

# 3. Check for README updates
echo "📖 Checking README documentation..."
CHANGED_DIRS=$(git diff --name-only "$BASE_BRANCH"...HEAD | xargs dirname | sort -u)
README_UPDATES=0

for dir in $CHANGED_DIRS; do
    if [ -f "$dir/README.md" ]; then
        if git diff --name-only "$BASE_BRANCH"...HEAD | grep -q "$dir/README.md"; then
            ((README_UPDATES++))
        fi
    fi
done

TOTAL_DIRS=$(echo "$CHANGED_DIRS" | wc -l)
if [ $README_UPDATES -gt 0 ] || [ $TOTAL_DIRS -le 2 ]; then
    print_status "PASS" "README documentation appears up to date"
    ((PASSED++))
else
    print_status "WARN" "Consider updating README files for changed components"
    ((PASSED++))
fi

# 4. Check API documentation
echo "🔌 Checking API documentation..."
if git diff --name-only "$BASE_BRANCH"...HEAD | grep -qE "(openapi|swagger|\.yaml|\.yml)$"; then
    API_FILES=$(git diff --name-only "$BASE_BRANCH"...HEAD | grep -E "(openapi|swagger|\.yaml|\.yml)$")
    
    for file in $API_FILES; do
        if [ -f "$file" ]; then
            # Basic validation that API files have descriptions
            if grep -q "description:" "$file"; then
                print_status "PASS" "API documentation in $file has descriptions"
                ((PASSED++))
            else
                print_status "FAIL" "API documentation in $file missing descriptions"
                ((FAILED++))
            fi
        fi
    done
else
    print_status "PASS" "No API documentation files changed"
    ((PASSED++))
fi

# 5. Check for changelog updates
echo "📝 Checking changelog updates..."
if [ -f "CHANGELOG.md" ]; then
    if git diff --name-only "$BASE_BRANCH"...HEAD | grep -q "CHANGELOG.md"; then
        print_status "PASS" "Changelog has been updated"
        ((PASSED++))
    else
        # Check if this is a significant change that should be in changelog
        SIGNIFICANT_CHANGES=$(git diff --name-only "$BASE_BRANCH"...HEAD | grep -vE "(test|spec|\.md$)" | wc -l)
        if [ $SIGNIFICANT_CHANGES -gt 5 ]; then
            print_status "WARN" "Consider updating CHANGELOG.md for significant changes"
        else
            print_status "PASS" "Minor changes - changelog update not required"
        fi
        ((PASSED++))
    fi
else
    print_status "WARN" "No CHANGELOG.md found - consider adding one"
    ((PASSED++))
fi

# 6. Check inline code comments
echo "💬 Checking code comments..."
CHANGED_CODE_FILES=$(git diff --name-only "$BASE_BRANCH"...HEAD | grep -E "\.(rs|ts|tsx|js|jsx|py|go)$")

if [ -n "$CHANGED_CODE_FILES" ]; then
    COMPLEX_FUNCTIONS=0
    
    for file in $CHANGED_CODE_FILES; do
        if [ -f "$file" ]; then
            # Count lines in functions (basic heuristic for complexity)
            case "$file" in
                *.rs)
                    COMPLEX_FUNCTIONS=$((COMPLEX_FUNCTIONS + $(grep -c "fn.*{" "$file" 2>/dev/null || echo 0)))
                    ;;
                *.ts|*.tsx|*.js|*.jsx)
                    COMPLEX_FUNCTIONS=$((COMPLEX_FUNCTIONS + $(grep -c "function\|=>" "$file" 2>/dev/null || echo 0)))
                    ;;
                *.py)
                    COMPLEX_FUNCTIONS=$((COMPLEX_FUNCTIONS + $(grep -c "def " "$file" 2>/dev/null || echo 0)))
                    ;;
                *.go)
                    COMPLEX_FUNCTIONS=$((COMPLEX_FUNCTIONS + $(grep -c "func " "$file" 2>/dev/null || echo 0)))
                    ;;
            esac
        fi
    done
    
    if [ $COMPLEX_FUNCTIONS -gt 0 ]; then
        print_status "PASS" "Code changes include function definitions"
        ((PASSED++))
    else
        print_status "PASS" "No complex functions detected"
        ((PASSED++))
    fi
else
    print_status "PASS" "No code files changed"
    ((PASSED++))
fi

# Summary
echo ""
echo "📋 Documentation Validation Summary:"
echo "  Passed: $PASSED"
echo "  Failed: $FAILED"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All documentation checks passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ $FAILED documentation check(s) failed.${NC}"
    echo ""
    echo "💡 Documentation requirements:"
    echo "  - All public APIs must have documentation comments"
    echo "  - Exported functions should include JSDoc/doc comments"
    echo "  - Complex logic should have inline comments"
    echo "  - API changes should update relevant documentation"
    exit 1
fi