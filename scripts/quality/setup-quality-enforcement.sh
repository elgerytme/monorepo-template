#!/bin/bash
# Setup script for code quality enforcement system
# Installs and configures pre-commit hooks and quality tools

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "🔧 Setting up code quality enforcement system..."

# Function to print status
print_status() {
    local status=$1
    local message=$2
    case "$status" in
        "INFO")
            echo -e "${BLUE}ℹ $message${NC}"
            ;;
        "SUCCESS")
            echo -e "${GREEN}✓ $message${NC}"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠ $message${NC}"
            ;;
        "ERROR")
            echo -e "${RED}✗ $message${NC}"
            ;;
    esac
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install Rust-based tools
install_rust_tools() {
    print_status "INFO" "Installing Rust-based quality tools..."
    
    # Essential tools
    local tools=(
        "dprint"
        "typos-cli"
        "cargo-audit"
        "cargo-nextest"
        "cargo-tarpaulin"
        "tokei"
        "ripgrep"
        "fd-find"
        "bat"
        "hyperfine"
        "watchexec-cli"
        "cargo-deny"
        "cargo-semver-checks"
    )
    
    for tool in "${tools[@]}"; do
        if ! command_exists "${tool//-cli/}"; then
            print_status "INFO" "Installing $tool..."
            if cargo install "$tool" >/dev/null 2>&1; then
                print_status "SUCCESS" "Installed $tool"
            else
                print_status "WARNING" "Failed to install $tool - continuing anyway"
            fi
        else
            print_status "SUCCESS" "$tool already installed"
        fi
    done
}

# Function to setup pre-commit
setup_precommit() {
    print_status "INFO" "Setting up pre-commit hooks..."
    
    if ! command_exists pre-commit; then
        print_status "INFO" "Installing pre-commit..."
        if command_exists pip; then
            pip install pre-commit >/dev/null 2>&1
        elif command_exists pip3; then
            pip3 install pre-commit >/dev/null 2>&1
        else
            print_status "ERROR" "pip not found - please install pre-commit manually"
            return 1
        fi
    fi
    
    # Install pre-commit hooks
    if pre-commit install >/dev/null 2>&1; then
        print_status "SUCCESS" "Pre-commit hooks installed"
    else
        print_status "ERROR" "Failed to install pre-commit hooks"
        return 1
    fi
    
    # Install pre-push hooks
    if pre-commit install --hook-type pre-push >/dev/null 2>&1; then
        print_status "SUCCESS" "Pre-push hooks installed"
    else
        print_status "WARNING" "Failed to install pre-push hooks"
    fi
}

# Function to create quality configuration files
create_config_files() {
    print_status "INFO" "Creating quality configuration files..."
    
    # Create dprint configuration if it doesn't exist
    if [ ! -f "dprint.json" ]; then
        cat > dprint.json << 'EOF'
{
  "typescript": {
    "lineWidth": 120,
    "indentWidth": 2,
    "useTabs": false,
    "semiColons": "always",
    "quoteStyle": "alwaysDouble",
    "newLineKind": "lf"
  },
  "json": {
    "lineWidth": 120,
    "indentWidth": 2,
    "useTabs": false
  },
  "markdown": {
    "lineWidth": 120,
    "textWrap": "maintain"
  },
  "toml": {},
  "includes": [
    "**/*.{ts,tsx,js,jsx,json,md,toml,yml,yaml}"
  ],
  "excludes": [
    "target/**",
    "node_modules/**",
    "dist/**",
    "build/**",
    ".git/**"
  ],
  "plugins": [
    "https://plugins.dprint.dev/typescript-0.88.1.wasm",
    "https://plugins.dprint.dev/json-0.17.4.wasm",
    "https://plugins.dprint.dev/markdown-0.16.4.wasm",
    "https://plugins.dprint.dev/toml-0.6.0.wasm"
  ]
}
EOF
        print_status "SUCCESS" "Created dprint.json configuration"
    fi
    
    # Create typos configuration if it doesn't exist
    if [ ! -f "_typos.toml" ]; then
        cat > _typos.toml << 'EOF'
[default]
extend-ignore-identifiers-re = [
    "clippy",
    "rustc",
    "nextest",
    "tokei",
    "dprint",
    "watchexec",
    "ripgrep",
    "hyperfine"
]

[default.extend-words]
# Add project-specific words that should not be flagged as typos
buckconfig = "buckconfig"
buckroot = "buckroot"
runbooks = "runbooks"
codegen = "codegen"

[files]
extend-exclude = [
    "target/",
    "node_modules/",
    "dist/",
    "build/",
    ".git/",
    "*.lock"
]
EOF
        print_status "SUCCESS" "Created _typos.toml configuration"
    fi
    
    # Create cargo-deny configuration if it doesn't exist
    if [ ! -f "deny.toml" ]; then
        cat > deny.toml << 'EOF'
[graph]
targets = [
    { triple = "x86_64-unknown-linux-gnu" },
    { triple = "x86_64-pc-windows-msvc" },
    { triple = "x86_64-apple-darwin" },
]

[advisories]
db-path = "~/.cargo/advisory-db"
db-urls = ["https://github.com/rustsec/advisory-db"]
vulnerability = "deny"
unmaintained = "warn"
yanked = "warn"
notice = "warn"
ignore = []

[licenses]
unlicensed = "deny"
allow = [
    "MIT",
    "Apache-2.0",
    "Apache-2.0 WITH LLVM-exception",
    "BSD-2-Clause",
    "BSD-3-Clause",
    "ISC",
    "Unicode-DFS-2016",
]
deny = [
    "GPL-2.0",
    "GPL-3.0",
    "AGPL-1.0",
    "AGPL-3.0",
]
copyleft = "warn"
allow-osi-fsf-free = "neither"
default = "deny"
confidence-threshold = 0.8

[bans]
multiple-versions = "warn"
wildcards = "allow"
highlight = "all"
workspace-default-features = "allow"
external-default-features = "allow"
allow = []
deny = []
skip = []
skip-tree = []

[sources]
unknown-registry = "warn"
unknown-git = "warn"
allow-registry = ["https://github.com/rust-lang/crates.io-index"]
allow-git = []
EOF
        print_status "SUCCESS" "Created deny.toml configuration"
    fi
}

# Function to setup git hooks
setup_git_hooks() {
    print_status "INFO" "Setting up additional git hooks..."
    
    # Create commit-msg hook for conventional commits
    if [ ! -f ".git/hooks/commit-msg" ]; then
        cat > .git/hooks/commit-msg << 'EOF'
#!/bin/bash
# Conventional commit message validation

commit_regex='^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\(.+\))?: .{1,50}'

if ! grep -qE "$commit_regex" "$1"; then
    echo "Invalid commit message format!"
    echo "Format: type(scope): description"
    echo "Types: feat, fix, docs, style, refactor, test, chore, perf, ci, build, revert"
    echo "Example: feat(auth): add user authentication"
    exit 1
fi
EOF
        chmod +x .git/hooks/commit-msg
        print_status "SUCCESS" "Created commit-msg hook for conventional commits"
    fi
}

# Function to test the setup
test_setup() {
    print_status "INFO" "Testing quality enforcement setup..."
    
    # Test pre-commit
    if command_exists pre-commit; then
        if pre-commit run --all-files >/dev/null 2>&1; then
            print_status "SUCCESS" "Pre-commit hooks working correctly"
        else
            print_status "WARNING" "Pre-commit hooks found issues - this is normal for initial setup"
        fi
    fi
    
    # Test quality gates script
    if [ -f "scripts/quality/quality-gates.sh" ]; then
        if bash scripts/quality/quality-gates.sh >/dev/null 2>&1; then
            print_status "SUCCESS" "Quality gates script working correctly"
        else
            print_status "WARNING" "Quality gates found issues - review and fix as needed"
        fi
    fi
}

# Main execution
main() {
    print_status "INFO" "Starting code quality enforcement setup..."
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_status "ERROR" "Not in a git repository"
        exit 1
    fi
    
    # Install Rust-based tools
    install_rust_tools
    
    # Setup pre-commit
    setup_precommit
    
    # Create configuration files
    create_config_files
    
    # Setup git hooks
    setup_git_hooks
    
    # Test the setup
    test_setup
    
    print_status "SUCCESS" "Code quality enforcement system setup complete!"
    
    echo ""
    echo "📋 Next steps:"
    echo "  1. Review and customize configuration files as needed"
    echo "  2. Run 'pre-commit run --all-files' to check existing code"
    echo "  3. Run 'scripts/quality/quality-gates.sh' to test quality gates"
    echo "  4. Commit changes to activate the hooks"
    echo ""
    echo "🔧 Available commands:"
    echo "  - pre-commit run --all-files    # Run all hooks on all files"
    echo "  - scripts/quality/quality-gates.sh    # Run quality gate checks"
    echo "  - scripts/quality/compatibility-check.sh    # Check backward compatibility"
    echo "  - scripts/quality/doc-validation.sh    # Validate documentation"
    echo "  - scripts/quality/code-review-assistant.sh    # Get automated code review"
}

# Run main function
main "$@"