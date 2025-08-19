#!/bin/bash

# Documentation Generation Script
# Generates comprehensive documentation for the monorepo

set -euo pipefail

# Configuration
DOCS_DIR="docs"
OUTPUT_DIR="target/docs"
RUST_DOC_DIR="$OUTPUT_DIR/rust"
TS_DOC_DIR="$OUTPUT_DIR/typescript"
API_DOC_DIR="$OUTPUT_DIR/api"

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

# Check if required tools are installed
check_dependencies() {
    log_info "Checking dependencies..."
    
    local missing_deps=()
    
    # Check for Rust tools
    if ! command -v cargo &> /dev/null; then
        missing_deps+=("cargo")
    fi
    
    if ! command -v rustdoc &> /dev/null; then
        missing_deps+=("rustdoc")
    fi
    
    # Check for Node.js tools
    if ! command -v node &> /dev/null; then
        missing_deps+=("node")
    fi
    
    if ! command -v npm &> /dev/null; then
        missing_deps+=("npm")
    fi
    
    # Check for documentation tools
    if ! command -v typedoc &> /dev/null; then
        log_warning "typedoc not found, installing..."
        npm install -g typedoc
    fi
    
    if ! command -v swagger-codegen &> /dev/null; then
        log_warning "swagger-codegen not found, installing..."
        npm install -g swagger-codegen-cli
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_error "Please install the missing dependencies and try again."
        exit 1
    fi
    
    log_success "All dependencies are available"
}

# Clean previous documentation
clean_docs() {
    log_info "Cleaning previous documentation..."
    
    if [ -d "$OUTPUT_DIR" ]; then
        rm -rf "$OUTPUT_DIR"
    fi
    
    mkdir -p "$OUTPUT_DIR"
    mkdir -p "$RUST_DOC_DIR"
    mkdir -p "$TS_DOC_DIR"
    mkdir -p "$API_DOC_DIR"
    
    log_success "Cleaned documentation directories"
}

# Generate Rust documentation
generate_rust_docs() {
    log_info "Generating Rust documentation..."
    
    # Generate documentation for all workspace crates
    RUSTDOCFLAGS="--html-in-header docs/api/rust-doc-header.html" \
    cargo doc \
        --workspace \
        --no-deps \
        --document-private-items \
        --target-dir "$OUTPUT_DIR" \
        --examples
    
    # Copy generated docs to the right location
    if [ -d "$OUTPUT_DIR/doc" ]; then
        cp -r "$OUTPUT_DIR/doc"/* "$RUST_DOC_DIR/"
        log_success "Rust documentation generated successfully"
    else
        log_error "Failed to generate Rust documentation"
        return 1
    fi
}

# Generate TypeScript documentation
generate_typescript_docs() {
    log_info "Generating TypeScript documentation..."
    
    # Find TypeScript projects
    local ts_projects=($(find apps libs -name "tsconfig.json" -exec dirname {} \;))
    
    if [ ${#ts_projects[@]} -eq 0 ]; then
        log_warning "No TypeScript projects found"
        return 0
    fi
    
    for project in "${ts_projects[@]}"; do
        local project_name=$(basename "$project")
        local output_path="$TS_DOC_DIR/$project_name"
        
        log_info "Generating docs for TypeScript project: $project_name"
        
        if [ -f "$project/src/index.ts" ] || [ -d "$project/src" ]; then
            typedoc \
                --out "$output_path" \
                --theme minimal \
                --readme "$project/README.md" \
                --name "$project_name" \
                --excludePrivate \
                --excludeProtected \
                --hideGenerator \
                "$project/src"
            
            log_success "Generated TypeScript docs for $project_name"
        else
            log_warning "No TypeScript source found in $project"
        fi
    done
}

# Generate OpenAPI documentation
generate_openapi_docs() {
    log_info "Generating OpenAPI documentation..."
    
    # Find OpenAPI specifications
    local openapi_specs=($(find docs/api/openapi -name "*.yaml" -o -name "*.yml" 2>/dev/null || true))
    
    if [ ${#openapi_specs[@]} -eq 0 ]; then
        log_warning "No OpenAPI specifications found"
        return 0
    fi
    
    for spec in "${openapi_specs[@]}"; do
        local spec_name=$(basename "$spec" .yaml)
        spec_name=$(basename "$spec_name" .yml)
        local output_path="$API_DOC_DIR/$spec_name"
        
        log_info "Generating OpenAPI docs for: $spec_name"
        
        # Validate the specification first
        if swagger-codegen validate -i "$spec"; then
            # Generate HTML documentation
            swagger-codegen generate \
                -i "$spec" \
                -l html2 \
                -o "$output_path"
            
            log_success "Generated OpenAPI docs for $spec_name"
        else
            log_error "Invalid OpenAPI specification: $spec"
        fi
    done
}

# Generate documentation index
generate_index() {
    log_info "Generating documentation index..."
    
    local index_file="$OUTPUT_DIR/index.html"
    
    cat > "$index_file" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Monorepo Documentation</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        .header {
            text-align: center;
            margin-bottom: 40px;
            padding-bottom: 20px;
            border-bottom: 2px solid #eee;
        }
        .section {
            margin-bottom: 30px;
            padding: 20px;
            border: 1px solid #ddd;
            border-radius: 8px;
        }
        .section h2 {
            margin-top: 0;
            color: #2c3e50;
        }
        .links {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 15px;
            margin-top: 15px;
        }
        .link {
            display: block;
            padding: 10px 15px;
            background: #f8f9fa;
            border: 1px solid #dee2e6;
            border-radius: 4px;
            text-decoration: none;
            color: #495057;
            transition: all 0.2s;
        }
        .link:hover {
            background: #e9ecef;
            border-color: #adb5bd;
        }
        .description {
            color: #6c757d;
            font-size: 0.9em;
            margin-top: 5px;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>Monorepo Documentation</h1>
        <p>Comprehensive documentation for all services and libraries</p>
    </div>

    <div class="section">
        <h2>🦀 Rust APIs</h2>
        <p>Documentation for Rust crates and libraries</p>
        <div class="links">
EOF

    # Add Rust documentation links
    if [ -d "$RUST_DOC_DIR" ]; then
        for crate_dir in "$RUST_DOC_DIR"/*; do
            if [ -d "$crate_dir" ] && [ -f "$crate_dir/index.html" ]; then
                local crate_name=$(basename "$crate_dir")
                echo "            <a href=\"rust/$crate_name/index.html\" class=\"link\">" >> "$index_file"
                echo "                <strong>$crate_name</strong>" >> "$index_file"
                echo "                <div class=\"description\">Rust crate documentation</div>" >> "$index_file"
                echo "            </a>" >> "$index_file"
            fi
        done
    fi

    cat >> "$index_file" << 'EOF'
        </div>
    </div>

    <div class="section">
        <h2>📘 TypeScript APIs</h2>
        <p>Documentation for TypeScript projects and libraries</p>
        <div class="links">
EOF

    # Add TypeScript documentation links
    if [ -d "$TS_DOC_DIR" ]; then
        for project_dir in "$TS_DOC_DIR"/*; do
            if [ -d "$project_dir" ] && [ -f "$project_dir/index.html" ]; then
                local project_name=$(basename "$project_dir")
                echo "            <a href=\"typescript/$project_name/index.html\" class=\"link\">" >> "$index_file"
                echo "                <strong>$project_name</strong>" >> "$index_file"
                echo "                <div class=\"description\">TypeScript project documentation</div>" >> "$index_file"
                echo "            </a>" >> "$index_file"
            fi
        done
    fi

    cat >> "$index_file" << 'EOF'
        </div>
    </div>

    <div class="section">
        <h2>🌐 REST APIs</h2>
        <p>OpenAPI specifications and REST API documentation</p>
        <div class="links">
EOF

    # Add OpenAPI documentation links
    if [ -d "$API_DOC_DIR" ]; then
        for api_dir in "$API_DOC_DIR"/*; do
            if [ -d "$api_dir" ] && [ -f "$api_dir/index.html" ]; then
                local api_name=$(basename "$api_dir")
                echo "            <a href=\"api/$api_name/index.html\" class=\"link\">" >> "$index_file"
                echo "                <strong>$api_name</strong>" >> "$index_file"
                echo "                <div class=\"description\">REST API documentation</div>" >> "$index_file"
                echo "            </a>" >> "$index_file"
            fi
        done
    fi

    cat >> "$index_file" << 'EOF'
        </div>
    </div>

    <div class="section">
        <h2>📚 Additional Resources</h2>
        <div class="links">
            <a href="../docs/architecture/README.md" class="link">
                <strong>Architecture Documentation</strong>
                <div class="description">System architecture and design decisions</div>
            </a>
            <a href="../docs/onboarding/README.md" class="link">
                <strong>Developer Onboarding</strong>
                <div class="description">Getting started guide for new developers</div>
            </a>
            <a href="../docs/runbooks/README.md" class="link">
                <strong>Operational Runbooks</strong>
                <div class="description">Operational procedures and troubleshooting</div>
            </a>
        </div>
    </div>

    <div class="section">
        <h2>🔍 Search</h2>
        <p>Use your browser's search functionality (Ctrl+F / Cmd+F) to find specific documentation.</p>
    </div>
</body>
</html>
EOF

    log_success "Generated documentation index"
}

# Generate search index
generate_search_index() {
    log_info "Generating search index..."
    
    local search_index_file="$OUTPUT_DIR/search-index.json"
    
    # Create a simple search index
    cat > "$search_index_file" << 'EOF'
{
  "documents": [],
  "index": {
    "version": "1.0.0",
    "fields": ["title", "content"],
    "ref": "id"
  }
}
EOF

    # TODO: Implement proper search index generation
    # This would involve parsing all generated documentation
    # and creating a searchable index
    
    log_success "Generated search index"
}

# Copy static assets
copy_assets() {
    log_info "Copying static assets..."
    
    # Copy CSS and JavaScript files if they exist
    if [ -d "docs/assets" ]; then
        cp -r docs/assets "$OUTPUT_DIR/"
        log_success "Copied static assets"
    fi
    
    # Copy any additional documentation files
    if [ -f "docs/README.md" ]; then
        cp docs/README.md "$OUTPUT_DIR/"
    fi
}

# Validate generated documentation
validate_docs() {
    log_info "Validating generated documentation..."
    
    local errors=0
    
    # Check if main index exists
    if [ ! -f "$OUTPUT_DIR/index.html" ]; then
        log_error "Main index.html not found"
        ((errors++))
    fi
    
    # Check for broken links (basic check)
    if command -v htmlproofer &> /dev/null; then
        if ! htmlproofer "$OUTPUT_DIR" --check-html --disable-external; then
            log_warning "HTML validation found issues"
        fi
    fi
    
    # Check if documentation was generated for expected projects
    local expected_rust_crates=("observability" "shared_library")
    for crate in "${expected_rust_crates[@]}"; do
        if [ ! -d "$RUST_DOC_DIR/$crate" ]; then
            log_warning "Missing Rust documentation for: $crate"
        fi
    done
    
    if [ $errors -eq 0 ]; then
        log_success "Documentation validation passed"
    else
        log_error "Documentation validation failed with $errors errors"
        return 1
    fi
}

# Main function
main() {
    log_info "Starting documentation generation..."
    
    # Parse command line arguments
    local clean_only=false
    local skip_validation=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --clean-only)
                clean_only=true
                shift
                ;;
            --skip-validation)
                skip_validation=true
                shift
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --clean-only      Only clean documentation directories"
                echo "  --skip-validation Skip documentation validation"
                echo "  --help           Show this help message"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Check dependencies
    check_dependencies
    
    # Clean previous documentation
    clean_docs
    
    if [ "$clean_only" = true ]; then
        log_success "Documentation directories cleaned"
        exit 0
    fi
    
    # Generate documentation
    generate_rust_docs
    generate_typescript_docs
    generate_openapi_docs
    
    # Generate index and search
    generate_index
    generate_search_index
    
    # Copy assets
    copy_assets
    
    # Validate documentation
    if [ "$skip_validation" = false ]; then
        validate_docs
    fi
    
    log_success "Documentation generation completed successfully!"
    log_info "Documentation available at: $OUTPUT_DIR/index.html"
    
    # Open documentation in browser if available
    if command -v xdg-open &> /dev/null; then
        xdg-open "$OUTPUT_DIR/index.html"
    elif command -v open &> /dev/null; then
        open "$OUTPUT_DIR/index.html"
    fi
}

# Run main function with all arguments
main "$@"