# Code Quality Enforcement System

This directory contains the comprehensive code quality enforcement system for the monorepo template. The system implements automated quality gates, pre-commit hooks, backward compatibility checking, and code review assistance using Rust-based tooling wherever possible.

## Overview

The code quality enforcement system ensures that all code meets company standards before merging by implementing:

- **Pre-commit hooks** with Rust-based formatters and linters
- **Quality gate validation** with comprehensive checks
- **Automated code review assistance** for consistent feedback
- **Backward compatibility checking** to prevent breaking changes

## Components

### Pre-commit Hooks (`.pre-commit-config.yaml`)

Automatically runs quality checks on every commit:

- **Rust formatting** with `rustfmt`
- **Rust linting** with `clippy`
- **Multi-language formatting** with `dprint` (Rust-based)
- **Security scanning** with `cargo-audit`
- **Spell checking** with `typos` (Rust-based)
- **Buck2 build validation**
- **Documentation validation**
- **Backward compatibility checks**

### Quality Gates (`quality-gates.sh` / `quality-gates.ps1`)

Comprehensive validation script that checks:

- Code formatting compliance
- Linting rules adherence
- Security vulnerabilities
- Test coverage and execution
- Documentation generation
- Build system validation

### Backward Compatibility Checker (`compatibility-check.sh` / `compatibility-check.ps1`)

Prevents breaking changes by analyzing:

- Rust API changes with `cargo-semver-checks`
- TypeScript/JavaScript export removals
- Database schema breaking changes
- API contract modifications
- Configuration key removals
- Dependency version compatibility

### Documentation Validator (`doc-validation.sh` / `doc-validation.ps1`)

Ensures proper documentation by checking:

- Rust doc comments on public items
- TypeScript/JavaScript JSDoc comments
- README file updates
- API documentation completeness
- Changelog maintenance
- Inline code comments

### Code Review Assistant (`code-review-assistant.sh` / `code-review-assistant.ps1`)

Provides automated feedback on:

- Code complexity analysis
- Security vulnerability detection
- Performance optimization suggestions
- Code style and best practices
- Test coverage assessment
- Documentation completeness
- Dependency management

## Setup

### Automatic Setup

Run the setup script to install and configure everything:

```bash
# Linux/macOS
./scripts/quality/setup-quality-enforcement.sh

# Windows
powershell -File scripts/quality/setup-quality-enforcement.ps1
```

### Manual Setup

1. **Install pre-commit**:
   ```bash
   pip install pre-commit
   pre-commit install
   pre-commit install --hook-type pre-push
   ```

2. **Install Rust-based tools**:
   ```bash
   cargo install dprint typos-cli cargo-audit cargo-nextest tokei ripgrep fd-find bat hyperfine watchexec-cli cargo-deny cargo-semver-checks
   ```

3. **Make scripts executable** (Linux/macOS):
   ```bash
   chmod +x scripts/quality/*.sh
   ```

## Usage

### Running Quality Checks

```bash
# Run all pre-commit hooks
pre-commit run --all-files

# Run quality gates
./scripts/quality/quality-gates.sh

# Check backward compatibility
./scripts/quality/compatibility-check.sh

# Validate documentation
./scripts/quality/doc-validation.sh

# Get automated code review
./scripts/quality/code-review-assistant.sh
```

### Windows Usage

```powershell
# Run quality gates
powershell -File scripts/quality/quality-gates.ps1

# Check backward compatibility
powershell -File scripts/quality/compatibility-check.ps1

# Validate documentation
powershell -File scripts/quality/doc-validation.ps1

# Get automated code review
powershell -File scripts/quality/code-review-assistant.ps1
```

## Configuration Files

### `dprint.json`
Multi-language formatter configuration for TypeScript, JSON, Markdown, and TOML files.

### `_typos.toml`
Spell checker configuration with project-specific word exceptions.

### `deny.toml`
Cargo dependency policy enforcement configuration.

### `.pre-commit-config.yaml`
Pre-commit hooks configuration with all quality checks.

## Integration with CI/CD

The quality enforcement system integrates with GitHub Actions workflows:

```yaml
- name: Run Quality Gates
  run: |
    if [[ "$RUNNER_OS" == "Windows" ]]; then
      powershell -File scripts/quality/quality-gates.ps1
    else
      ./scripts/quality/quality-gates.sh
    fi

- name: Check Backward Compatibility
  run: |
    if [[ "$RUNNER_OS" == "Windows" ]]; then
      powershell -File scripts/quality/compatibility-check.ps1
    else
      ./scripts/quality/compatibility-check.sh
    fi
```

## Quality Standards

### Code Formatting
- **Rust**: `rustfmt` with default settings
- **TypeScript/JavaScript**: `dprint` with 120 character line width
- **JSON/YAML/TOML**: `dprint` with consistent formatting
- **Markdown**: `dprint` with maintained text wrapping

### Linting Rules
- **Rust**: `clippy` with warnings as errors
- **Security**: `cargo-audit` for vulnerability scanning
- **Spelling**: `typos` for spell checking across all files

### Documentation Requirements
- All public Rust APIs must have doc comments
- Exported TypeScript/JavaScript functions need JSDoc
- API changes require documentation updates
- Complex logic needs inline comments

### Backward Compatibility
- No removal of public APIs without deprecation
- Database migrations must be backward compatible
- Configuration changes must be additive
- API contracts must maintain compatibility

## Troubleshooting

### Common Issues

1. **Pre-commit hooks failing**:
   - Run `pre-commit run --all-files` to see specific issues
   - Fix formatting with `cargo fmt` and `dprint fmt`
   - Address linting issues shown by `clippy`

2. **Quality gates failing**:
   - Check individual tool outputs for specific errors
   - Ensure all required tools are installed
   - Review test failures and fix failing tests

3. **Compatibility checks failing**:
   - Review the specific breaking changes identified
   - Use deprecation warnings instead of removing APIs
   - Make database changes backward compatible

4. **Tool installation issues**:
   - Ensure Rust toolchain is properly installed
   - Check network connectivity for cargo installs
   - Use `--force` flag to reinstall tools if needed

### Getting Help

- Check tool-specific documentation for detailed configuration
- Review the automated code review output for suggestions
- Consult the design document for architectural decisions
- Run setup script with verbose output for debugging

## Maintenance

### Updating Tools

```bash
# Update all Rust tools
cargo install-update -a

# Update pre-commit hooks
pre-commit autoupdate
```

### Adding New Checks

1. Add new hooks to `.pre-commit-config.yaml`
2. Update quality gates script with new validations
3. Document new requirements in this README
4. Test changes thoroughly before committing

### Customizing for Your Project

1. Modify configuration files to match your standards
2. Add project-specific words to `_typos.toml`
3. Adjust quality thresholds in scripts
4. Update documentation requirements as needed