# Monorepo Template

A comprehensive monorepo template following industry best practices used by companies like Google and Meta, built with Buck2 and Rust-based tooling.

## Repository Structure

```
monorepo/
├── .buckconfig          # Buck2 configuration
├── .buckroot           # Buck2 root marker  
├── BUCK                # Root build file
├── apps/               # Application services
├── libs/               # Shared libraries
├── tools/              # Development and build tools
├── infra/              # Infrastructure as code
├── docs/               # Documentation
├── scripts/            # Automation scripts
├── config/             # Configuration files
│   ├── platforms/      # Platform detection config
│   ├── cpu/           # CPU architecture definitions
│   ├── os/            # Operating system definitions
│   └── rust-toolchain.toml # Rust toolchain configuration
└── README.md          # This file
```

## Getting Started

This template provides a complete foundation for large-scale software development with:

- **Buck2 Build System**: Fast, reliable builds with incremental compilation
- **Platform Detection**: Automatic platform detection for cross-platform builds
- **Rust-First Tooling**: Prioritizes Rust-based tools throughout the stack
- **Industry Standards**: Follows conventions from Google and Meta

## Build System

The repository uses Buck2 as the primary build system with:

- Automatic platform detection (Linux x86_64, macOS ARM64, Windows x86_64)
- Incremental builds and caching enabled
- Rust toolchain integration with clippy and rustfmt
- Cross-language dependency support

## Quick Start

### Using the Template

1. **Initialize a new project**:
   ```bash
   # Linux/macOS
   ./scripts/template/init-template.sh --name my-project --org my-company
   
   # Windows PowerShell
   .\scripts\template\init-template.ps1 -Name my-project -Organization my-company
   ```

2. **Set up development environment**:
   ```bash
   cd my-project
   ./scripts/setup/bootstrap.sh  # or bootstrap.ps1 on Windows
   ```

3. **Validate the setup**:
   ```bash
   ./scripts/template/validate-template.sh  # or validate-template.ps1
   ```

### Template Management

- **Update existing project**: Use `update-template.sh/ps1` to get latest template changes
- **Package template**: Use `package-template.sh/ps1` to create distributable packages
- **Migrate existing project**: See `docs/migration/MIGRATION_GUIDE.md`

## Features

- ✅ **Buck2 Build System** - Fast, reliable builds with incremental compilation
- ✅ **Rust-Based Tooling** - ripgrep, fd, clippy, rustfmt, and more
- ✅ **Multi-Language Support** - Rust, TypeScript, Python, Go
- ✅ **CI/CD Pipelines** - GitHub Actions workflows
- ✅ **Development Containers** - VS Code dev containers
- ✅ **Security Scanning** - Automated vulnerability detection
- ✅ **Observability** - Monitoring, logging, and tracing
- ✅ **Documentation** - Comprehensive guides and examples

## Next Steps

1. Add your applications to the `apps/` directory
2. Create shared libraries in the `libs/` directory  
3. Customize CI/CD pipelines for your needs
4. Review security policies and quality gates

For detailed implementation guidance, see the documentation in the `docs/` directory.