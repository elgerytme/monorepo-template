#!/bin/bash
# Automated code review assistance script
# Provides automated feedback and suggestions for code changes

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "🤖 Running automated code review assistance..."

# Function to print status
print_status() {
    local status=$1
    local message=$2
    case "$status" in
        "INFO")
            echo -e "${BLUE}ℹ $message${NC}"
            ;;
        "SUGGESTION")
            echo -e "${YELLOW}💡 $message${NC}"
            ;;
        "ISSUE")
            echo -e "${RED}⚠ $message${NC}"
            ;;
        "GOOD")
            echo -e "${GREEN}✓ $message${NC}"
            ;;
    esac
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Get the base branch (usually main or master)
BASE_BRANCH=${1:-"origin/main"}

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    print_status "ISSUE" "Not in a git repository"
    exit 1
fi

# Get changed files
CHANGED_FILES=$(git diff --name-only "$BASE_BRANCH"...HEAD)
if [ -z "$CHANGED_FILES" ]; then
    print_status "INFO" "No files changed"
    exit 0
fi

echo "📁 Analyzing $(echo "$CHANGED_FILES" | wc -l) changed files..."

# 1. Analyze code complexity
echo ""
echo "🧮 Code Complexity Analysis:"

for file in $CHANGED_FILES; do
    if [[ "$file" =~ \.(rs|ts|tsx|js|jsx|py|go)$ ]] && [ -f "$file" ]; then
        # Count lines of code
        LOC=$(wc -l < "$file")
        
        # Count functions/methods
        case "$file" in
            *.rs)
                FUNCTIONS=$(grep -c "fn " "$file" 2>/dev/null || echo 0)
                ;;
            *.ts|*.tsx|*.js|*.jsx)
                FUNCTIONS=$(grep -cE "(function|=>|\bclass\b)" "$file" 2>/dev/null || echo 0)
                ;;
            *.py)
                FUNCTIONS=$(grep -c "def " "$file" 2>/dev/null || echo 0)
                ;;
            *.go)
                FUNCTIONS=$(grep -c "func " "$file" 2>/dev/null || echo 0)
                ;;
        esac
        
        # Analyze complexity
        if [ $LOC -gt 500 ]; then
            print_status "ISSUE" "$file: Large file ($LOC lines) - consider splitting"
        elif [ $LOC -gt 200 ]; then
            print_status "SUGGESTION" "$file: Consider breaking down large file ($LOC lines)"
        fi
        
        if [ $FUNCTIONS -gt 20 ]; then
            print_status "SUGGESTION" "$file: Many functions ($FUNCTIONS) - consider organizing into modules"
        fi
        
        # Check for long functions
        if [[ "$file" =~ \.rs$ ]]; then
            LONG_FUNCTIONS=$(awk '/^fn / {start=NR} /^}/ && start {if(NR-start > 50) print "Line " start ": " (NR-start) " lines"; start=0}' "$file")
            if [ -n "$LONG_FUNCTIONS" ]; then
                print_status "SUGGESTION" "$file: Long functions detected - consider refactoring"
            fi
        fi
    fi
done

# 2. Security analysis
echo ""
echo "🔒 Security Analysis:"

for file in $CHANGED_FILES; do
    if [ -f "$file" ]; then
        # Check for potential security issues
        SECURITY_PATTERNS=(
            "password.*=.*[\"'].*[\"']"
            "api[_-]?key.*=.*[\"'].*[\"']"
            "secret.*=.*[\"'].*[\"']"
            "token.*=.*[\"'].*[\"']"
            "unsafe"
            "eval\("
            "innerHTML"
            "dangerouslySetInnerHTML"
        )
        
        for pattern in "${SECURITY_PATTERNS[@]}"; do
            if grep -qiE "$pattern" "$file"; then
                print_status "ISSUE" "$file: Potential security issue - review pattern: $pattern"
            fi
        done
        
        # Check for TODO/FIXME comments
        TODOS=$(grep -n "TODO\|FIXME\|XXX\|HACK" "$file" 2>/dev/null || echo "")
        if [ -n "$TODOS" ]; then
            print_status "SUGGESTION" "$file: Contains TODO/FIXME comments - consider addressing"
        fi
    fi
done

# 3. Performance analysis
echo ""
echo "⚡ Performance Analysis:"

for file in $CHANGED_FILES; do
    if [ -f "$file" ]; then
        # Check for potential performance issues
        case "$file" in
            *.rs)
                # Check for inefficient patterns in Rust
                if grep -q "clone()" "$file"; then
                    print_status "SUGGESTION" "$file: Consider if all clone() calls are necessary"
                fi
                if grep -q "unwrap()" "$file"; then
                    print_status "SUGGESTION" "$file: Consider proper error handling instead of unwrap()"
                fi
                ;;
            *.ts|*.tsx|*.js|*.jsx)
                # Check for inefficient patterns in TypeScript/JavaScript
                if grep -q "for.*in.*" "$file"; then
                    print_status "SUGGESTION" "$file: Consider using for...of or array methods for better performance"
                fi
                if grep -qE "document\.getElementById|document\.querySelector" "$file"; then
                    print_status "SUGGESTION" "$file: Consider caching DOM queries"
                fi
                ;;
            *.py)
                # Check for inefficient patterns in Python
                if grep -q "for.*in.*range(len(" "$file"; then
                    print_status "SUGGESTION" "$file: Consider using enumerate() instead of range(len())"
                fi
                ;;
        esac
    fi
done

# 4. Code style and best practices
echo ""
echo "🎨 Code Style Analysis:"

for file in $CHANGED_FILES; do
    if [ -f "$file" ]; then
        # Check line length
        LONG_LINES=$(awk 'length > 120 {print NR ": " length " chars"}' "$file")
        if [ -n "$LONG_LINES" ]; then
            print_status "SUGGESTION" "$file: Some lines exceed 120 characters"
        fi
        
        # Check for consistent naming
        case "$file" in
            *.rs)
                # Check for snake_case in Rust
                if grep -qE "fn [a-z]*[A-Z]" "$file"; then
                    print_status "SUGGESTION" "$file: Use snake_case for function names in Rust"
                fi
                ;;
            *.ts|*.tsx|*.js|*.jsx)
                # Check for camelCase in TypeScript/JavaScript
                if grep -qE "function [a-z]*_[a-z]" "$file"; then
                    print_status "SUGGESTION" "$file: Use camelCase for function names in TypeScript/JavaScript"
                fi
                ;;
        esac
    fi
done

# 5. Test coverage analysis
echo ""
echo "🧪 Test Coverage Analysis:"

TEST_FILES=$(echo "$CHANGED_FILES" | grep -E "(test|spec)" || echo "")
SOURCE_FILES=$(echo "$CHANGED_FILES" | grep -vE "(test|spec)" | grep -E "\.(rs|ts|tsx|js|jsx|py|go)$" || echo "")

if [ -n "$SOURCE_FILES" ]; then
    SOURCE_COUNT=$(echo "$SOURCE_FILES" | wc -l)
    TEST_COUNT=$(echo "$TEST_FILES" | wc -l)
    
    if [ -z "$TEST_FILES" ]; then
        print_status "ISSUE" "No test files found for $SOURCE_COUNT changed source files"
    elif [ $TEST_COUNT -lt $((SOURCE_COUNT / 2)) ]; then
        print_status "SUGGESTION" "Consider adding more tests (found $TEST_COUNT test files for $SOURCE_COUNT source files)"
    else
        print_status "GOOD" "Good test coverage ratio ($TEST_COUNT test files for $SOURCE_COUNT source files)"
    fi
fi

# 6. Documentation analysis
echo ""
echo "📚 Documentation Analysis:"

DOC_FILES=$(echo "$CHANGED_FILES" | grep -E "\.md$" || echo "")
if [ -n "$SOURCE_FILES" ] && [ -z "$DOC_FILES" ]; then
    print_status "SUGGESTION" "Consider updating documentation for code changes"
fi

# Check for API changes that might need documentation
API_CHANGES=$(git diff "$BASE_BRANCH"...HEAD | grep -E "^[+].*pub |^[+].*export " | wc -l)
if [ $API_CHANGES -gt 0 ]; then
    print_status "SUGGESTION" "API changes detected ($API_CHANGES) - ensure documentation is updated"
fi

# 7. Dependency analysis
echo ""
echo "📦 Dependency Analysis:"

DEP_FILES=$(echo "$CHANGED_FILES" | grep -E "(Cargo\.toml|package\.json|requirements\.txt|go\.mod)" || echo "")
if [ -n "$DEP_FILES" ]; then
    print_status "INFO" "Dependency files changed - ensure security scanning is run"
    
    # Check for version pinning
    for dep_file in $DEP_FILES; do
        if [[ "$dep_file" == "package.json" ]] && [ -f "$dep_file" ]; then
            UNPINNED=$(grep -E '"[^"]*": "\^|~' "$dep_file" | wc -l)
            if [ $UNPINNED -gt 0 ]; then
                print_status "SUGGESTION" "$dep_file: Consider pinning dependency versions for reproducible builds"
            fi
        fi
    done
fi

# 8. Generate summary
echo ""
echo "📋 Code Review Summary:"

# Count different types of feedback
ISSUES=$(grep -c "⚠" <<< "$(print_status "ISSUE" "test" 2>&1)" 2>/dev/null || echo 0)
SUGGESTIONS=$(grep -c "💡" <<< "$(print_status "SUGGESTION" "test" 2>&1)" 2>/dev/null || echo 0)

echo "  Files analyzed: $(echo "$CHANGED_FILES" | wc -l)"
echo "  Source files: $(echo "$SOURCE_FILES" | wc -l)"
echo "  Test files: $(echo "$TEST_FILES" | wc -l)"

print_status "INFO" "Automated review complete. Please address any issues and consider suggestions."
print_status "INFO" "Remember: This is automated analysis. Human review is still essential!"

echo ""
echo "🔗 Next steps:"
echo "  1. Address any security issues immediately"
echo "  2. Consider refactoring suggestions for maintainability"
echo "  3. Ensure adequate test coverage"
echo "  4. Update documentation as needed"
echo "  5. Run full quality gates before merging"