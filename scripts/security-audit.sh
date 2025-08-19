#!/bin/bash
# Security audit script using cargo-audit

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$REPO_ROOT/config/audit.toml"

echo "Running security audit with cargo-audit..."

# Check if cargo-audit is installed
if ! command -v cargo-audit &> /dev/null; then
    echo "cargo-audit not found. Installing..."
    cargo install cargo-audit --features=fix
fi

# Update advisory database
echo "Updating advisory database..."
cargo audit --config "$CONFIG_FILE" --db-update

# Run audit on all Rust projects
echo "Running security audit..."
find "$REPO_ROOT" -name "Cargo.toml" -not -path "*/target/*" | while read -r cargo_file; do
    project_dir="$(dirname "$cargo_file")"
    echo "Auditing project: $project_dir"
    
    cd "$project_dir"
    cargo audit --config "$CONFIG_FILE" --json > "${project_dir}/audit-report.json" || {
        echo "Security vulnerabilities found in $project_dir"
        cargo audit --config "$CONFIG_FILE"
        exit 1
    }
done

echo "Security audit completed successfully!"