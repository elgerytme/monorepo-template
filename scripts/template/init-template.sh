#!/bin/bash

# Monorepo Template Initialization Script
# This script initializes a new project from the monorepo template with customization options

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
PROJECT_NAME=""
ORGANIZATION=""
LANGUAGES=()
ENABLE_FRONTEND=false
ENABLE_BACKEND=true
ENABLE_INFRA=true
TARGET_DIR=""
TEMPLATE_VERSION="latest"

# Print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Initialize a new monorepo project from the template.

OPTIONS:
    -n, --name NAME           Project name (required)
    -o, --org ORGANIZATION    Organization name (required)
    -l, --languages LANGS     Comma-separated list of languages (rust,typescript,python,go)
    -f, --frontend            Enable frontend application template
    -b, --no-backend          Disable backend services template
    -i, --no-infra            Disable infrastructure template
    -d, --dir DIRECTORY       Target directory (default: PROJECT_NAME)
    -v, --version VERSION     Template version (default: latest)
    -h, --help                Show this help message

EXAMPLES:
    $0 --name my-project --org mycompany --languages rust,typescript
    $0 -n api-service -o acme -l rust,go --no-frontend
    $0 --name full-stack --org startup --languages rust,typescript,python --frontend

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--name)
                PROJECT_NAME="$2"
                shift 2
                ;;
            -o|--org)
                ORGANIZATION="$2"
                shift 2
                ;;
            -l|--languages)
                IFS=',' read -ra LANGUAGES <<< "$2"
                shift 2
                ;;
            -f|--frontend)
                ENABLE_FRONTEND=true
                shift
                ;;
            -b|--no-backend)
                ENABLE_BACKEND=false
                shift
                ;;
            -i|--no-infra)
                ENABLE_INFRA=false
                shift
                ;;
            -d|--dir)
                TARGET_DIR="$2"
                shift 2
                ;;
            -v|--version)
                TEMPLATE_VERSION="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Validate required arguments
validate_args() {
    if [[ -z "$PROJECT_NAME" ]]; then
        print_error "Project name is required. Use --name or -n"
        exit 1
    fi

    if [[ -z "$ORGANIZATION" ]]; then
        print_error "Organization name is required. Use --org or -o"
        exit 1
    fi

    # Validate project name format
    if [[ ! "$PROJECT_NAME" =~ ^[a-z][a-z0-9-]*[a-z0-9]$ ]]; then
        print_error "Project name must be lowercase, start with a letter, and contain only letters, numbers, and hyphens"
        exit 1
    fi

    # Set default target directory
    if [[ -z "$TARGET_DIR" ]]; then
        TARGET_DIR="$PROJECT_NAME"
    fi

    # Validate languages
    local valid_languages=("rust" "typescript" "python" "go")
    for lang in "${LANGUAGES[@]}"; do
        if [[ ! " ${valid_languages[*]} " =~ " ${lang} " ]]; then
            print_error "Invalid language: $lang. Supported: ${valid_languages[*]}"
            exit 1
        fi
    done

    # Default to Rust if no languages specified
    if [[ ${#LANGUAGES[@]} -eq 0 ]]; then
        LANGUAGES=("rust")
        print_info "No languages specified, defaulting to Rust"
    fi
}

# Interactive mode for missing arguments
interactive_setup() {
    if [[ -z "$PROJECT_NAME" ]]; then
        read -p "Enter project name: " PROJECT_NAME
    fi

    if [[ -z "$ORGANIZATION" ]]; then
        read -p "Enter organization name: " ORGANIZATION
    fi

    if [[ ${#LANGUAGES[@]} -eq 0 ]]; then
        echo "Select languages (comma-separated):"
        echo "  1. rust"
        echo "  2. typescript" 
        echo "  3. python"
        echo "  4. go"
        read -p "Languages [rust]: " lang_input
        if [[ -n "$lang_input" ]]; then
            IFS=',' read -ra LANGUAGES <<< "$lang_input"
        else
            LANGUAGES=("rust")
        fi
    fi

    read -p "Enable frontend template? [y/N]: " frontend_choice
    if [[ "$frontend_choice" =~ ^[Yy]$ ]]; then
        ENABLE_FRONTEND=true
    fi
}

# Copy template files
copy_template() {
    local template_dir="$(dirname "$(dirname "$(realpath "$0")")")"
    
    print_info "Copying template files to $TARGET_DIR..."
    
    if [[ -d "$TARGET_DIR" ]]; then
        print_error "Directory $TARGET_DIR already exists"
        exit 1
    fi

    # Create target directory
    mkdir -p "$TARGET_DIR"
    
    # Copy core template files
    cp -r "$template_dir"/{.buckconfig,.buckroot,BUCK,justfile} "$TARGET_DIR/" 2>/dev/null || true
    cp -r "$template_dir"/{config,scripts,docs} "$TARGET_DIR/"
    cp -r "$template_dir"/.github "$TARGET_DIR/"
    cp -r "$template_dir"/.devcontainer "$TARGET_DIR/"
    
    # Copy base directories
    mkdir -p "$TARGET_DIR"/{apps,libs,tools,infra,examples,releases,signatures,artifacts}
    
    # Copy .gitkeep files
    find "$template_dir" -name ".gitkeep" -exec cp --parents {} "$TARGET_DIR/" \;
}

# Customize template based on options
customize_template() {
    print_info "Customizing template for project: $PROJECT_NAME"
    
    cd "$TARGET_DIR"
    
    # Update project metadata
    sed -i "s/monorepo-template/$PROJECT_NAME/g" README.md 2>/dev/null || true
    sed -i "s/ORGANIZATION_NAME/$ORGANIZATION/g" README.md 2>/dev/null || true
    
    # Update workspace configuration
    if [[ -f "monorepo-template.code-workspace" ]]; then
        mv "monorepo-template.code-workspace" "$PROJECT_NAME.code-workspace"
        sed -i "s/monorepo-template/$PROJECT_NAME/g" "$PROJECT_NAME.code-workspace"
    fi
    
    # Update Buck2 configuration
    sed -i "s/monorepo-template/$PROJECT_NAME/g" .buckconfig 2>/dev/null || true
    
    # Create language-specific examples
    for lang in "${LANGUAGES[@]}"; do
        case $lang in
            rust)
                create_rust_example
                ;;
            typescript)
                create_typescript_example
                ;;
            python)
                create_python_example
                ;;
            go)
                create_go_example
                ;;
        esac
    done
    
    # Handle frontend/backend options
    if [[ "$ENABLE_FRONTEND" == true ]]; then
        create_frontend_app
    fi
    
    if [[ "$ENABLE_BACKEND" == false ]]; then
        rm -rf examples/web-service 2>/dev/null || true
    fi
    
    if [[ "$ENABLE_INFRA" == false ]]; then
        rm -rf infra examples/infrastructure 2>/dev/null || true
    fi
}

# Create Rust example project
create_rust_example() {
    print_info "Creating Rust example project..."
    
    if [[ ! -d "examples/web-service" ]]; then
        mkdir -p examples/web-service/src
        
        cat > examples/web-service/Cargo.toml << EOF
[package]
name = "${PROJECT_NAME}-web-service"
version = "0.1.0"
edition = "2021"

[dependencies]
tokio = { version = "1.0", features = ["full"] }
axum = "0.7"
serde = { version = "1.0", features = ["derive"] }
tracing = "0.1"
tracing-subscriber = "0.3"

[dev-dependencies]
tower = { version = "0.4", features = ["util"] }
hyper = { version = "1.0", features = ["full"] }
EOF

        cat > examples/web-service/src/main.rs << 'EOF'
use axum::{response::Json, routing::get, Router};
use serde::Serialize;
use std::net::SocketAddr;
use tracing::info;

#[derive(Serialize)]
struct HealthResponse {
    status: String,
    service: String,
}

async fn health() -> Json<HealthResponse> {
    Json(HealthResponse {
        status: "healthy".to_string(),
        service: env!("CARGO_PKG_NAME").to_string(),
    })
}

#[tokio::main]
async fn main() {
    tracing_subscriber::init();

    let app = Router::new().route("/health", get(health));

    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));
    info!("Server listening on {}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
EOF
    fi
}

# Create TypeScript example project
create_typescript_example() {
    print_info "Creating TypeScript example project..."
    
    if [[ ! -d "examples/frontend-app" ]]; then
        mkdir -p examples/frontend-app/src
        
        cat > examples/frontend-app/package.json << EOF
{
  "name": "${PROJECT_NAME}-frontend",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview",
    "test": "vitest",
    "lint": "eslint src --ext ts,tsx --report-unused-disable-directives --max-warnings 0"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0",
    "@typescript-eslint/eslint-plugin": "^6.0.0",
    "@typescript-eslint/parser": "^6.0.0",
    "@vitejs/plugin-react": "^4.0.0",
    "eslint": "^8.45.0",
    "eslint-plugin-react-hooks": "^4.6.0",
    "eslint-plugin-react-refresh": "^0.4.3",
    "typescript": "^5.0.2",
    "vite": "^4.4.5",
    "vitest": "^0.34.0"
  }
}
EOF
    fi
}

# Create Python example project
create_python_example() {
    print_info "Creating Python example project..."
    
    mkdir -p examples/python-service
    
    cat > examples/python-service/pyproject.toml << EOF
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "${PROJECT_NAME}-python-service"
version = "0.1.0"
description = "Python service example"
dependencies = [
    "fastapi>=0.100.0",
    "uvicorn[standard]>=0.23.0",
    "pydantic>=2.0.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.0.0",
    "pytest-asyncio>=0.21.0",
    "httpx>=0.24.0",
    "ruff>=0.0.280",
    "mypy>=1.5.0",
]
EOF
}

# Create Go example project
create_go_example() {
    print_info "Creating Go example project..."
    
    mkdir -p examples/go-service
    
    cat > examples/go-service/go.mod << EOF
module github.com/${ORGANIZATION}/${PROJECT_NAME}/examples/go-service

go 1.21

require (
    github.com/gin-gonic/gin v1.9.1
    github.com/stretchr/testify v1.8.4
)
EOF
}

# Create frontend application
create_frontend_app() {
    print_info "Setting up frontend application..."
    
    if [[ " ${LANGUAGES[*]} " =~ " typescript " ]]; then
        create_typescript_example
    else
        print_warning "Frontend requested but TypeScript not in language list. Adding TypeScript example."
        create_typescript_example
    fi
}

# Initialize git repository
init_git() {
    print_info "Initializing git repository..."
    
    cd "$TARGET_DIR"
    
    if [[ ! -d ".git" ]]; then
        git init
        git add .
        git commit -m "Initial commit from monorepo template v$TEMPLATE_VERSION"
        
        print_success "Git repository initialized with initial commit"
    fi
}

# Run post-initialization setup
post_init_setup() {
    print_info "Running post-initialization setup..."
    
    cd "$TARGET_DIR"
    
    # Make scripts executable
    find scripts -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    
    # Run bootstrap script if it exists
    if [[ -f "scripts/setup/bootstrap.sh" ]]; then
        print_info "Running bootstrap script..."
        ./scripts/setup/bootstrap.sh || print_warning "Bootstrap script failed, you may need to run it manually"
    fi
}

# Main execution
main() {
    print_info "Monorepo Template Initialization"
    print_info "================================"
    
    parse_args "$@"
    
    # If no arguments provided, run interactive mode
    if [[ $# -eq 0 ]]; then
        interactive_setup
    fi
    
    validate_args
    
    print_info "Configuration:"
    print_info "  Project: $PROJECT_NAME"
    print_info "  Organization: $ORGANIZATION"
    print_info "  Languages: ${LANGUAGES[*]}"
    print_info "  Frontend: $ENABLE_FRONTEND"
    print_info "  Backend: $ENABLE_BACKEND"
    print_info "  Infrastructure: $ENABLE_INFRA"
    print_info "  Target Directory: $TARGET_DIR"
    print_info "  Template Version: $TEMPLATE_VERSION"
    
    copy_template
    customize_template
    init_git
    post_init_setup
    
    print_success "Template initialization complete!"
    print_info "Next steps:"
    print_info "  1. cd $TARGET_DIR"
    print_info "  2. Review and customize the generated files"
    print_info "  3. Run './scripts/setup/bootstrap.sh' if not already run"
    print_info "  4. Start developing!"
}

# Run main function with all arguments
main "$@"