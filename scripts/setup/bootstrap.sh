#!/bin/bash

# Monorepo Development Environment Bootstrap Script
# This script sets up the complete development environment with a single command

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Linux*)     OS=linux;;
        Darwin*)    OS=macos;;
        CYGWIN*|MINGW*|MSYS*) OS=windows;;
        *)          OS=unknown;;
    esac
    log_info "Detected OS: $OS"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install Rust toolchain
install_rust() {
    log_info "Installing Rust toolchain..."
    
    if command_exists rustc; then
        log_success "Rust already installed: $(rustc --version)"
        return 0
    fi
    
    # Install rustup
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    
    # Install specific toolchain version from rust-toolchain.toml
    if [ -f "config/rust-toolchain.toml" ]; then
        log_info "Installing toolchain from rust-toolchain.toml..."
        rustup show
    fi
    
    log_success "Rust toolchain installed: $(rustc --version)"
}

# Install Buck2
install_buck2() {
    log_info "Installing Buck2..."
    
    if command_exists buck2; then
        log_success "Buck2 already installed: $(buck2 --version)"
        return 0
    fi
    
    case "$OS" in
        linux)
            curl -L -o buck2 https://github.com/facebook/buck2/releases/latest/download/buck2-x86_64-unknown-linux-gnu.zst
            zstd -d buck2
            chmod +x buck2
            sudo mv buck2 /usr/local/bin/
            ;;
        macos)
            if command_exists brew; then
                brew install buck2
            else
                curl -L -o buck2 https://github.com/facebook/buck2/releases/latest/download/buck2-x86_64-apple-darwin.zst
                zstd -d buck2
                chmod +x buck2
                sudo mv buck2 /usr/local/bin/
            fi
            ;;
        windows)
            log_error "Please install Buck2 manually on Windows from: https://github.com/facebook/buck2/releases"
            return 1
            ;;
    esac
    
    log_success "Buck2 installed: $(buck2 --version)"
}# Install
 Rust-based development tools
install_rust_tools() {
    log_info "Installing Rust-based development tools..."
    
    local tools=(
        "ripgrep"           # Fast text search
        "fd-find"           # Fast file finder
        "bat"               # Better cat
        "exa"               # Better ls
        "tokei"             # Code statistics
        "hyperfine"         # Benchmarking
        "watchexec-cli"     # File watcher
        "typos-cli"         # Spell checker
        "dprint"            # Multi-language formatter
        "just"              # Command runner
        "cargo-nextest"     # Advanced test runner
        "cargo-audit"       # Security scanner
        "cargo-deny"        # Dependency analyzer
    )
    
    for tool in "${tools[@]}"; do
        if ! command_exists "${tool%%-*}"; then
            log_info "Installing $tool..."
            cargo install "$tool"
        else
            log_success "$tool already installed"
        fi
    done
    
    log_success "Rust tools installation complete"
}

# Install language-specific tools
install_language_tools() {
    log_info "Installing language-specific tools..."
    
    # Node.js and npm (for TypeScript/JavaScript)
    if ! command_exists node; then
        case "$OS" in
            linux)
                curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
                sudo apt-get install -y nodejs
                ;;
            macos)
                if command_exists brew; then
                    brew install node
                else
                    log_warning "Please install Node.js manually"
                fi
                ;;
            windows)
                log_warning "Please install Node.js manually from nodejs.org"
                ;;
        esac
    else
        log_success "Node.js already installed: $(node --version)"
    fi
    
    # Python (if not already installed)
    if ! command_exists python3; then
        case "$OS" in
            linux)
                sudo apt-get update
                sudo apt-get install -y python3 python3-pip
                ;;
            macos)
                if command_exists brew; then
                    brew install python3
                else
                    log_warning "Please install Python3 manually"
                fi
                ;;
            windows)
                log_warning "Please install Python3 manually from python.org"
                ;;
        esac
    else
        log_success "Python3 already installed: $(python3 --version)"
    fi
    
    # Go (if not already installed)
    if ! command_exists go; then
        case "$OS" in
            linux)
                GO_VERSION="1.21.0"
                wget "https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz"
                sudo tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz"
                echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
                rm "go${GO_VERSION}.linux-amd64.tar.gz"
                ;;
            macos)
                if command_exists brew; then
                    brew install go
                else
                    log_warning "Please install Go manually"
                fi
                ;;
            windows)
                log_warning "Please install Go manually from golang.org"
                ;;
        esac
    else
        log_success "Go already installed: $(go version)"
    fi
}

# Setup Git hooks
setup_git_hooks() {
    log_info "Setting up Git hooks..."
    
    if [ ! -d ".git" ]; then
        log_warning "Not a Git repository, skipping Git hooks setup"
        return 0
    fi
    
    # Create pre-commit hook
    cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
set -e

echo "Running pre-commit checks..."

# Format check
if command -v dprint >/dev/null 2>&1; then
    echo "Checking formatting with dprint..."
    dprint check
fi

# Rust formatting
if command -v rustfmt >/dev/null 2>&1; then
    echo "Checking Rust formatting..."
    cargo fmt -- --check
fi

# Rust linting
if command -v clippy >/dev/null 2>&1; then
    echo "Running Rust linting..."
    cargo clippy -- -D warnings
fi

# Spell check
if command -v typos >/dev/null 2>&1; then
    echo "Running spell check..."
    typos
fi

# Security audit
if command -v cargo-audit >/dev/null 2>&1; then
    echo "Running security audit..."
    cargo audit
fi

echo "Pre-commit checks passed!"
EOF
    
    chmod +x .git/hooks/pre-commit
    log_success "Git hooks configured"
}

# Create development directories
create_dev_directories() {
    log_info "Creating development directories..."
    
    local dirs=(
        "apps"
        "libs" 
        "tools"
        "infra"
        "docs"
        "scripts/ci"
        "scripts/deployment"
        ".github/workflows"
        "config/platforms"
        "config/cpu"
        "config/os"
    )
    
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            log_info "Created directory: $dir"
        fi
    done
    
    log_success "Development directories created"
}

# Main installation function
main() {
    log_info "Starting monorepo development environment setup..."
    
    detect_os
    
    # Install core tools
    install_rust
    install_buck2
    install_rust_tools
    install_language_tools
    
    # Setup environment
    setup_git_hooks
    create_dev_directories
    
    # Run health check
    if [ -f "scripts/setup/health-check.sh" ]; then
        log_info "Running environment health check..."
        bash scripts/setup/health-check.sh
    fi
    
    log_success "Development environment setup complete!"
    log_info "You may need to restart your shell or run 'source ~/.bashrc' to use new tools"
    log_info "Run 'scripts/setup/health-check.sh' to verify your environment"
}

# Run main function
main "$@"