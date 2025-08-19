# Monorepo Development Commands
# Use 'just <command>' to run these tasks

# Default recipe - show available commands
default:
    @just --list

# Setup development environment
setup:
    @echo "Setting up development environment..."
    @bash scripts/setup/bootstrap.sh

# Run health check
health-check mode="full":
    @echo "Running health check ({{mode}} mode)..."
    @bash scripts/setup/health-check.sh {{mode}}

# Update development tools
update-tools:
    @echo "Updating development tools..."
    @bash scripts/setup/install-tools.sh update

# Format all code
fmt:
    @echo "Formatting code..."
    @dprint fmt
    @cargo fmt --all

# Lint all code
lint:
    @echo "Linting code..."
    @cargo clippy --all-targets --all-features -- -D warnings
    @typos

# Run security audit
audit:
    @echo "Running security audit..."
    @cargo audit
    @cargo deny check

# Run all tests
test:
    @echo "Running tests..."
    @cargo nextest run --all-features

# Build all projects
build:
    @echo "Building all projects..."
    @buck2 build //...

# Clean build artifacts
clean:
    @echo "Cleaning build artifacts..."
    @buck2 clean
    @cargo clean

# Run pre-commit checks
pre-commit:
    @echo "Running pre-commit checks..."
    @just fmt
    @just lint
    @just audit
    @just test

# Generate project documentation
docs:
    @echo "Generating documentation..."
    @cargo doc --all-features --no-deps

# Show project statistics
stats:
    @echo "Project statistics:"
    @tokei

# Watch for changes and run tests
watch:
    @echo "Watching for changes..."
    @watchexec -e rs,toml,md just test

# Benchmark performance
bench:
    @echo "Running benchmarks..."
    @cargo bench

# Check for outdated dependencies
outdated:
    @echo "Checking for outdated dependencies..."
    @cargo outdated