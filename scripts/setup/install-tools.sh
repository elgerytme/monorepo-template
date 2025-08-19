#!/bin/bash

# Tool Installation and Version Management Script
# Manages installation and updates of development tools with version pinning

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../../config"
TOOLS_CONFIG="$CONFIG_DIR/tools-versions.toml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Get installed version of a tool
get_installed_version() {
    local tool="$1"
    case "$tool" in
        "rust")
            if command_exists rustc; then
                rustc --version | cut -d' ' -f2
            fi
            ;;
        "buck2")
            if command_exists buck2; then
                buck2 --version 2>/dev/null | head -1 | cut -d' ' -f2 || echo "unknown"
            fi
            ;;
        "node")
            if command_exists node; then
                node --version | sed 's/v//'
            fi
            ;;
        *)
            if command_exists "$tool"; then
                $tool --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown"
            fi
            ;;
    esac
}

# Parse version from tools-versions.toml
get_required_version() {
    local tool="$1"
    if [ -f "$TOOLS_CONFIG" ]; then
        grep "^$tool" "$TOOLS_CONFIG" | cut -d'=' -f2 | tr -d ' "' || echo ""
    fi
}

# Compare versions (returns 0 if versions match, 1 if update needed)
version_compare() {
    local installed="$1"
    local required="$2"
    
    if [ "$installed" = "$required" ] || [ "$required" = "latest" ]; then
        return 0
    else
        return 1
    fi
}# In
stall or update Rust toolchain
install_rust() {
    local required_version
    required_version=$(get_required_version "rust")
    local installed_version
    installed_version=$(get_installed_version "rust")
    
    if [ -n "$installed_version" ] && version_compare "$installed_version" "$required_version"; then
        log_success "Rust $installed_version is up to date"
        return 0
    fi
    
    log_info "Installing/updating Rust toolchain..."
    
    if ! command_exists rustup; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
    fi
    
    if [ -n "$required_version" ] && [ "$required_version" != "latest" ]; then
        rustup install "$required_version"
        rustup default "$required_version"
    else
        rustup update stable
        rustup default stable
    fi
    
    log_success "Rust toolchain updated to $(rustc --version | cut -d' ' -f2)"
}

# Install or update Buck2
install_buck2() {
    local required_version
    required_version=$(get_required_version "buck2")
    local installed_version
    installed_version=$(get_installed_version "buck2")
    
    if [ -n "$installed_version" ] && version_compare "$installed_version" "$required_version"; then
        log_success "Buck2 $installed_version is up to date"
        return 0
    fi
    
    log_info "Installing/updating Buck2..."
    
    local os
    case "$(uname -s)" in
        Linux*) os="linux";;
        Darwin*) os="macos";;
        *) log_error "Unsupported OS for Buck2 installation"; return 1;;
    esac
    
    local arch
    case "$(uname -m)" in
        x86_64) arch="x86_64";;
        arm64|aarch64) arch="aarch64";;
        *) log_error "Unsupported architecture for Buck2"; return 1;;
    esac
    
    local download_url
    if [ "$required_version" = "latest" ] || [ -z "$required_version" ]; then
        download_url="https://github.com/facebook/buck2/releases/latest/download/buck2-${arch}-unknown-${os}-gnu.zst"
    else
        download_url="https://github.com/facebook/buck2/releases/download/${required_version}/buck2-${arch}-unknown-${os}-gnu.zst"
    fi
    
    local temp_file="/tmp/buck2.zst"
    curl -L -o "$temp_file" "$download_url"
    zstd -d "$temp_file" -o /tmp/buck2
    chmod +x /tmp/buck2
    
    if [ -w "/usr/local/bin" ]; then
        mv /tmp/buck2 /usr/local/bin/
    else
        sudo mv /tmp/buck2 /usr/local/bin/
    fi
    
    rm -f "$temp_file"
    log_success "Buck2 updated to $(buck2 --version | head -1)"
}

# Install Rust tools with version management
install_rust_tools() {
    log_info "Installing/updating Rust-based tools..."
    
    local tools=(
        "ripgrep:rg"
        "fd-find:fd"
        "bat:bat"
        "exa:exa"
        "tokei:tokei"
        "hyperfine:hyperfine"
        "watchexec-cli:watchexec"
        "typos-cli:typos"
        "dprint:dprint"
        "just:just"
        "cargo-nextest:cargo-nextest"
        "cargo-audit:cargo-audit"
        "cargo-deny:cargo-deny"
    )
    
    for tool_spec in "${tools[@]}"; do
        local crate_name="${tool_spec%:*}"
        local binary_name="${tool_spec#*:}"
        
        local required_version
        required_version=$(get_required_version "$binary_name")
        local installed_version
        installed_version=$(get_installed_version "$binary_name")
        
        if [ -n "$installed_version" ] && version_compare "$installed_version" "$required_version"; then
            log_success "$binary_name $installed_version is up to date"
            continue
        fi
        
        log_info "Installing/updating $crate_name..."
        if [ -n "$required_version" ] && [ "$required_version" != "latest" ]; then
            cargo install "$crate_name" --version "$required_version" --force
        else
            cargo install "$crate_name" --force
        fi
        
        log_success "$crate_name installed/updated"
    done
}

# Main function
main() {
    log_info "Starting tool installation and version management..."
    
    # Create tools config if it doesn't exist
    if [ ! -f "$TOOLS_CONFIG" ]; then
        log_info "Creating tools-versions.toml configuration..."
        mkdir -p "$CONFIG_DIR"
        cat > "$TOOLS_CONFIG" << 'EOF'
# Tool versions configuration
# Use "latest" for the most recent version or specify exact versions

[tools]
rust = "1.75.0"
buck2 = "latest"
node = "20.10.0"
go = "1.21.5"
python = "3.11"

# Rust tools
rg = "latest"
fd = "latest"
bat = "latest"
exa = "latest"
tokei = "latest"
hyperfine = "latest"
watchexec = "latest"
typos = "latest"
dprint = "latest"
just = "latest"
cargo-nextest = "latest"
cargo-audit = "latest"
cargo-deny = "latest"
EOF
        log_success "Created $TOOLS_CONFIG"
    fi
    
    # Install/update tools
    install_rust
    install_buck2
    install_rust_tools
    
    log_success "Tool installation and version management complete!"
}

# Handle command line arguments
case "${1:-install}" in
    "install"|"update")
        main
        ;;
    "check")
        log_info "Checking tool versions..."
        # Implementation for version checking
        ;;
    "list")
        log_info "Listing installed tools..."
        # Implementation for listing tools
        ;;
    *)
        echo "Usage: $0 [install|update|check|list]"
        exit 1
        ;;
esac