# Rust Development Tooling Configuration

This directory contains configuration files for Rust-based development tooling used throughout the monorepo.

## Configuration Files

### `rust-toolchain.toml`
Specifies the Rust toolchain version and components:
- Pinned to Rust 1.75.0 for consistency
- Includes rustfmt, clippy, rust-src, and rust-analyzer
- Supports multiple target platforms

### `rustfmt.toml`
Code formatting configuration:
- 100 character line width
- 4-space indentation
- Comprehensive formatting rules for consistency
- Import organization and grouping

### `clippy.toml`
Linting configuration:
- Cognitive complexity threshold: 30
- Cyclomatic complexity threshold: 7
- Performance and security lint rules
- Documentation requirements

### `audit.toml`
Security scanning configuration:
- Vulnerability severity threshold: low
- License compliance checking
- Allowed and denied licenses
- Multi-platform support

### `rust-tools.toml`
Integration configuration that ties all tools together:
- Pre-commit hook commands
- CI/CD pipeline checks
- Tool command references

## Usage

### Format Code
```bash
cargo fmt --config-path config/rustfmt.toml
```

### Run Linting
```bash
cargo clippy --config-path config/clippy.toml --all-targets --all-features -- -D warnings
```

### Security Audit
```bash
# Unix/Linux/macOS
./scripts/security-audit.sh

# Windows PowerShell
.\scripts\security-audit.ps1
```

### All Checks (Pre-commit)
```bash
cargo fmt --check --config-path config/rustfmt.toml
cargo clippy --config-path config/clippy.toml --all-targets --all-features -- -D warnings
cargo audit --config config/audit.toml
```

## Integration with Buck2

These configurations are designed to work with Buck2 build rules. The Buck2 configuration will automatically use these files when building Rust projects.

## Requirements Satisfied

This configuration satisfies the following requirements:
- **2.2**: Prioritizes Rust-based tooling with comprehensive configuration
- **4.1**: Implements security scanning with cargo-audit
- **6.1**: Enforces code quality standards through formatting and linting
- **6.2**: Provides consistent formatting using Rust-based formatters