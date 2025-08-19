# Developer Onboarding Guide

Welcome to the monorepo! This guide will help you get up and running quickly with our development environment and workflows.

## Quick Start (5 minutes)

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd monorepo
   ```

2. **Run the bootstrap script**
   ```bash
   # On Unix/Linux/macOS
   ./scripts/setup/bootstrap.sh
   
   # On Windows
   .\scripts\setup\bootstrap.ps1
   ```

3. **Verify your setup**
   ```bash
   ./scripts/setup/health-check.sh
   ```

4. **Build everything**
   ```bash
   buck2 build //...
   ```

That's it! You should now have a fully functional development environment.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Development Environment Setup](#development-environment-setup)
- [Understanding the Codebase](#understanding-the-codebase)
- [Development Workflow](#development-workflow)
- [Testing](#testing)
- [Code Quality](#code-quality)
- [Troubleshooting](#troubleshooting)
- [Getting Help](#getting-help)

## Prerequisites

### Required Software

The bootstrap script will install most tools automatically, but you need:

- **Git** (2.30+)
- **Docker** (20.10+) - for development containers
- **VS Code** (recommended) - with our workspace configuration

### System Requirements

- **OS**: Linux, macOS, or Windows 10/11
- **RAM**: 8GB minimum, 16GB recommended
- **Disk**: 10GB free space
- **Network**: Reliable internet for initial setup

## Development Environment Setup

### Option 1: Development Container (Recommended)

The easiest way to get started is using our pre-configured development container:

1. **Install VS Code and Dev Containers extension**
2. **Open the repository in VS Code**
3. **Click "Reopen in Container" when prompted**

The container includes:
- Buck2 build system
- Rust toolchain with all tools
- Pre-configured environment
- All development dependencies

### Option 2: Local Setup

If you prefer local development:

1. **Run the bootstrap script**
   ```bash
   ./scripts/setup/bootstrap.sh
   ```

2. **Source the environment**
   ```bash
   source ~/.bashrc  # or restart your terminal
   ```

3. **Verify installation**
   ```bash
   ./scripts/setup/health-check.sh
   ```

### What Gets Installed

The bootstrap script installs:

#### Core Tools
- **Buck2** - Build system
- **Rust toolchain** - Latest stable Rust
- **just** - Command runner
- **Git hooks** - Pre-commit quality checks

#### Rust-based Development Tools
- **ripgrep** (rg) - Fast text search
- **fd** - Fast file finding
- **bat** - Enhanced file viewer
- **exa** - Modern ls replacement
- **hyperfine** - Benchmarking tool
- **tokei** - Code statistics
- **dprint** - Multi-language formatter
- **typos** - Spell checker

#### Language-Specific Tools
- **Node.js** + **npm** - For TypeScript projects
- **Python** + **pip** - For Python projects
- **Go** - For Go projects

## Understanding the Codebase

### Repository Structure

```
monorepo/
├── apps/           # Application services
│   ├── web-service/     # Example Rust web service
│   └── frontend-app/    # Example TypeScript frontend
├── libs/           # Shared libraries
│   ├── observability/   # Monitoring and logging
│   └── shared-library/  # Cross-language utilities
├── tools/          # Development tools
├── infra/          # Infrastructure as code
├── docs/           # Documentation
├── scripts/        # Automation scripts
├── config/         # Configuration files
└── examples/       # Example implementations
```

### Key Concepts

#### Buck2 Build System
- **Targets**: Buildable units (libraries, binaries, tests)
- **BUCK files**: Define build targets and dependencies
- **Incremental builds**: Only rebuilds what changed
- **Remote caching**: Shares build artifacts across team

#### Rust-First Tooling
- Most development tools are Rust-based for performance
- Consistent behavior across platforms
- Modern features and better UX

#### Quality Gates
- Automated formatting and linting
- Security scanning on every commit
- Comprehensive testing requirements
- Documentation standards

## Development Workflow

### Daily Workflow

1. **Start your day**
   ```bash
   git pull origin main
   buck2 build //...  # Ensure everything builds
   ```

2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes**
   - Edit code using your preferred editor
   - Run tests frequently: `buck2 test //path/to:tests`
   - Check formatting: `just format-check`

4. **Before committing**
   ```bash
   just quality-check  # Runs all quality checks
   ```

5. **Commit and push**
   ```bash
   git add .
   git commit -m "feat: add new feature"
   git push origin feature/your-feature-name
   ```

6. **Create pull request**
   - Use the PR template
   - Ensure CI passes
   - Request reviews

### Common Commands

```bash
# Build everything
buck2 build //...

# Build specific target
buck2 build //apps/web-service:main

# Run tests
buck2 test //...

# Run specific tests
buck2 test //libs/observability:tests

# Format code
just format

# Check code quality
just quality-check

# Run security checks
just security-check

# Start development server
just dev

# Clean build cache
buck2 clean
```

### Using Just (Command Runner)

We use `just` instead of `make` for common tasks:

```bash
# See all available commands
just --list

# Common commands
just build          # Build everything
just test           # Run all tests
just format         # Format all code
just lint           # Run linters
just security       # Security checks
just docs           # Generate documentation
just dev            # Start development environment
```

## Testing

### Test Types

#### Unit Tests
```bash
# Run all unit tests
buck2 test //... --test-type=unit

# Run tests for specific component
buck2 test //libs/observability:unit_tests
```

#### Integration Tests
```bash
# Run integration tests
buck2 test //... --test-type=integration

# Run with test containers
just test-integration
```

#### End-to-End Tests
```bash
# Run E2E tests
just test-e2e
```

### Test Configuration

Tests use **nextest** for better performance and reporting:

```bash
# Run tests with nextest directly
cargo nextest run

# Generate test report
cargo nextest run --profile ci --junit-path test-results.xml
```

### Writing Tests

#### Rust Tests
```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_example() {
        assert_eq!(2 + 2, 4);
    }
}
```

#### TypeScript Tests
```typescript
import { describe, it, expect } from '@jest/globals';

describe('Example', () => {
    it('should work', () => {
        expect(2 + 2).toBe(4);
    });
});
```

## Code Quality

### Formatting

Code is automatically formatted using:
- **rustfmt** for Rust code
- **dprint** for TypeScript, JSON, YAML, Markdown

```bash
# Format all code
just format

# Check formatting without changes
just format-check
```

### Linting

Linting is enforced using:
- **clippy** for Rust
- **ESLint** for TypeScript
- **ruff** for Python

```bash
# Run all linters
just lint

# Fix auto-fixable issues
just lint-fix
```

### Pre-commit Hooks

Pre-commit hooks automatically run:
- Code formatting
- Linting
- Security checks
- Spell checking

If hooks fail, the commit is blocked. Fix issues and try again.

### Security

Security scanning includes:
- **cargo-audit** for Rust dependencies
- **npm audit** for Node.js dependencies
- **Secret detection** for accidentally committed secrets
- **Container scanning** for Docker images

```bash
# Run security checks
just security-check

# Update security database
cargo audit --update
```

## Troubleshooting

### Common Issues

#### Build Failures

**Problem**: Buck2 build fails with dependency errors
```bash
# Solution: Clean and rebuild
buck2 clean
buck2 build //...
```

**Problem**: Rust compilation errors
```bash
# Solution: Update Rust toolchain
rustup update
```

#### Tool Installation Issues

**Problem**: Bootstrap script fails
```bash
# Solution: Run with verbose output
bash -x ./scripts/setup/bootstrap.sh
```

**Problem**: Missing tools after installation
```bash
# Solution: Reload shell environment
source ~/.bashrc
# or restart terminal
```

#### Performance Issues

**Problem**: Slow builds
```bash
# Solution: Check Buck2 daemon status
buck2 status

# Restart daemon if needed
buck2 kill
```

**Problem**: High memory usage
```bash
# Solution: Limit Buck2 parallelism
buck2 build //... --num-threads=4
```

### Getting Logs

```bash
# Buck2 logs
buck2 log show

# Detailed build logs
buck2 build //... --verbose 2

# System logs
journalctl -u buck2  # Linux
tail -f /var/log/system.log  # macOS
```

### Health Checks

```bash
# Run comprehensive health check
./scripts/setup/health-check.sh

# Check specific components
buck2 --version
rustc --version
node --version
```

## Getting Help

### Documentation
- [Architecture Documentation](../architecture/README.md)
- [Build System Guide](../architecture/build-system.md)
- [Operational Runbooks](../runbooks/README.md)

### Team Resources
- **Slack**: #monorepo-support
- **Wiki**: [Internal Wiki Link]
- **Office Hours**: Tuesdays 2-3 PM PST

### External Resources
- [Buck2 Documentation](https://buck2.build/)
- [Rust Book](https://doc.rust-lang.org/book/)
- [TypeScript Handbook](https://www.typescriptlang.org/docs/)

### Reporting Issues

1. **Check existing issues** in the repository
2. **Search documentation** and runbooks
3. **Ask in Slack** for quick questions
4. **Create GitHub issue** for bugs or feature requests

Use this template for issues:
```markdown
## Problem Description
[Describe the issue]

## Steps to Reproduce
1. [Step 1]
2. [Step 2]

## Expected Behavior
[What should happen]

## Actual Behavior
[What actually happens]

## Environment
- OS: [Your OS]
- Buck2 version: [Run `buck2 --version`]
- Rust version: [Run `rustc --version`]
```

## Next Steps

Now that you're set up:

1. **Explore the examples** in the `examples/` directory
2. **Read the architecture documentation** to understand the system design
3. **Try building and running** the example applications
4. **Make a small change** and go through the full development workflow
5. **Join the team chat** and introduce yourself

Welcome to the team! 🎉