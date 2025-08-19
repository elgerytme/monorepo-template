# Development Environment Setup

This directory contains scripts and configurations for setting up the monorepo development environment.

## Quick Start

### One-Command Setup

**Linux/macOS:**
```bash
bash scripts/setup/bootstrap.sh
```

**Windows:**
```powershell
.\scripts\setup\bootstrap.ps1
```

### Using Development Container

If you have Docker and VS Code with the Dev Containers extension:

1. Open the project in VS Code
2. Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on macOS)
3. Select "Dev Containers: Reopen in Container"
4. Wait for the container to build and start

## Manual Setup

If you prefer to set up tools manually or the bootstrap script fails:

### Core Requirements

1. **Rust Toolchain**
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   source ~/.cargo/env
   ```

2. **Buck2 Build System**
   - Download from: https://github.com/facebook/buck2/releases
   - Add to your PATH

3. **Node.js** (for TypeScript/JavaScript projects)
   - Download from: https://nodejs.org/

4. **Python 3** (for Python projects)
   - Most systems have this pre-installed
   - Install pip if not available

5. **Go** (for Go projects)
   - Download from: https://golang.org/

### Development Tools

Install Rust-based development tools:

```bash
cargo install ripgrep fd-find bat exa tokei hyperfine watchexec-cli typos-cli dprint just cargo-nextest cargo-audit cargo-deny
```

## Scripts Overview

### `bootstrap.sh` / `bootstrap.ps1`
Complete environment setup script that:
- Installs Rust toolchain
- Installs Buck2 build system
- Installs all development tools
- Sets up Git hooks
- Creates directory structure
- Runs health check

### `install-tools.sh`
Tool installation and version management:
- Manages tool versions from `config/tools-versions.toml`
- Supports version pinning
- Can update individual tools

Usage:
```bash
bash scripts/setup/install-tools.sh [install|update|check|list]
```

### `health-check.sh` / `health-check.ps1`
Environment validation script that:
- Checks all required tools are installed
- Verifies tool versions
- Tests basic functionality
- Validates configuration files
- Runs performance tests

Usage:
```bash
bash scripts/setup/health-check.sh [full|quick|tools]
```

## Configuration Files

### `config/tools-versions.toml`
Defines required versions for all development tools. Edit this file to:
- Pin specific tool versions
- Use "latest" for most recent versions
- Add new tools to the managed list

### `.devcontainer/`
Development container configuration for consistent environments:
- `devcontainer.json` - Container configuration
- `Dockerfile` - Container image definition

## Troubleshooting

### Common Issues

**Buck2 installation fails:**
- Download manually from GitHub releases
- Ensure you have the correct architecture (x86_64/aarch64)
- Check that zstd is installed for decompression

**Rust tools fail to install:**
- Ensure Rust toolchain is properly installed
- Check internet connection
- Try installing tools individually: `cargo install <tool-name>`

**Permission errors:**
- Use `sudo` for system-wide installations
- Consider using user-local installations
- Check directory permissions

**Windows-specific issues:**
- Install Visual Studio Build Tools for Rust compilation
- Use PowerShell as Administrator if needed
- Consider using WSL2 for better compatibility

### Getting Help

1. Run the health check to identify issues:
   ```bash
   bash scripts/setup/health-check.sh
   ```

2. Check tool versions:
   ```bash
   bash scripts/setup/install-tools.sh check
   ```

3. Re-run bootstrap script:
   ```bash
   bash scripts/setup/bootstrap.sh
   ```

## Development Workflow

After setup, use these commands for daily development:

```bash
# Check environment health
just health-check

# Format code
just fmt

# Run linting
just lint

# Run tests
just test

# Build all projects
just build

# Run security audit
just audit

# Update tools
just update-tools
```

## Environment Variables

The setup scripts respect these environment variables:

- `RUST_VERSION` - Override Rust version
- `BUCK2_VERSION` - Override Buck2 version
- `SKIP_TOOLS` - Skip tool installation
- `SKIP_HOOKS` - Skip Git hooks setup

Example:
```bash
RUST_VERSION=1.74.0 bash scripts/setup/bootstrap.sh
```