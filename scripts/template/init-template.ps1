# Monorepo Template Initialization Script (PowerShell)
# This script initializes a new project from the monorepo template with customization options

param(
    [Parameter(Mandatory=$false)]
    [Alias("n")]
    [string]$Name,
    
    [Parameter(Mandatory=$false)]
    [Alias("o")]
    [string]$Organization,
    
    [Parameter(Mandatory=$false)]
    [Alias("l")]
    [string]$Languages,
    
    [Parameter(Mandatory=$false)]
    [Alias("f")]
    [switch]$Frontend,
    
    [Parameter(Mandatory=$false)]
    [Alias("b")]
    [switch]$NoBackend,
    
    [Parameter(Mandatory=$false)]
    [Alias("i")]
    [switch]$NoInfra,
    
    [Parameter(Mandatory=$false)]
    [Alias("d")]
    [string]$Directory,
    
    [Parameter(Mandatory=$false)]
    [Alias("v")]
    [string]$Version = "latest",
    
    [Parameter(Mandatory=$false)]
    [Alias("h")]
    [switch]$Help
)

# Colors for output
$Red = "Red"
$Green = "Green"
$Yellow = "Yellow"
$Blue = "Blue"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor $Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor $Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor $Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $Red
}

function Show-Usage {
    @"
Usage: .\init-template.ps1 [OPTIONS]

Initialize a new monorepo project from the template.

OPTIONS:
    -Name, -n NAME           Project name (required)
    -Organization, -o ORG    Organization name (required)
    -Languages, -l LANGS     Comma-separated list of languages (rust,typescript,python,go)
    -Frontend, -f            Enable frontend application template
    -NoBackend, -b           Disable backend services template
    -NoInfra, -i             Disable infrastructure template
    -Directory, -d DIR       Target directory (default: PROJECT_NAME)
    -Version, -v VERSION     Template version (default: latest)
    -Help, -h                Show this help message

EXAMPLES:
    .\init-template.ps1 -Name my-project -Organization mycompany -Languages rust,typescript
    .\init-template.ps1 -n api-service -o acme -l rust,go -NoFrontend
    .\init-template.ps1 -Name full-stack -Organization startup -Languages rust,typescript,python -Frontend

"@
}

function Test-ProjectName {
    param([string]$ProjectName)
    
    if ([string]::IsNullOrEmpty($ProjectName)) {
        return $false
    }
    
    # Check if name matches pattern: lowercase, starts with letter, contains only letters, numbers, hyphens
    return $ProjectName -match "^[a-z][a-z0-9-]*[a-z0-9]$"
}

function Get-InteractiveInput {
    if ([string]::IsNullOrEmpty($Name)) {
        $Name = Read-Host "Enter project name"
    }
    
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = Read-Host "Enter organization name"
    }
    
    if ([string]::IsNullOrEmpty($Languages)) {
        Write-Host "Select languages (comma-separated):"
        Write-Host "  1. rust"
        Write-Host "  2. typescript"
        Write-Host "  3. python"
        Write-Host "  4. go"
        $langInput = Read-Host "Languages [rust]"
        if ([string]::IsNullOrEmpty($langInput)) {
            $Languages = "rust"
        } else {
            $Languages = $langInput
        }
    }
    
    $frontendChoice = Read-Host "Enable frontend template? [y/N]"
    if ($frontendChoice -match "^[Yy]$") {
        $Frontend = $true
    }
}

function Copy-TemplateFiles {
    param([string]$TargetDir)
    
    Write-Info "Copying template files to $TargetDir..."
    
    if (Test-Path $TargetDir) {
        Write-Error "Directory $TargetDir already exists"
        exit 1
    }
    
    # Create target directory
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    
    $templateDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    
    # Copy core template files
    $coreFiles = @(".buckconfig", ".buckroot", "BUCK", "justfile")
    foreach ($file in $coreFiles) {
        $sourcePath = Join-Path $templateDir $file
        if (Test-Path $sourcePath) {
            Copy-Item $sourcePath $TargetDir -Force
        }
    }
    
    # Copy directories
    $directories = @("config", "scripts", "docs", ".github", ".devcontainer")
    foreach ($dir in $directories) {
        $sourcePath = Join-Path $templateDir $dir
        if (Test-Path $sourcePath) {
            Copy-Item $sourcePath $TargetDir -Recurse -Force
        }
    }
    
    # Create base directories
    $baseDirs = @("apps", "libs", "tools", "infra", "examples", "releases", "signatures", "artifacts")
    foreach ($dir in $baseDirs) {
        New-Item -ItemType Directory -Path (Join-Path $TargetDir $dir) -Force | Out-Null
    }
    
    # Copy .gitkeep files
    Get-ChildItem -Path $templateDir -Name ".gitkeep" -Recurse | ForEach-Object {
        $relativePath = $_.FullName.Substring($templateDir.Length + 1)
        $targetPath = Join-Path $TargetDir $relativePath
        $targetParent = Split-Path -Parent $targetPath
        if (!(Test-Path $targetParent)) {
            New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
        }
        Copy-Item $_.FullName $targetPath -Force
    }
}

function Update-TemplateContent {
    param(
        [string]$TargetDir,
        [string]$ProjectName,
        [string]$OrganizationName,
        [string[]]$LanguageList
    )
    
    Write-Info "Customizing template for project: $ProjectName"
    
    Push-Location $TargetDir
    
    try {
        # Update README if it exists
        $readmePath = "README.md"
        if (Test-Path $readmePath) {
            $content = Get-Content $readmePath -Raw
            $content = $content -replace "monorepo-template", $ProjectName
            $content = $content -replace "ORGANIZATION_NAME", $OrganizationName
            Set-Content $readmePath $content
        }
        
        # Update workspace configuration
        $workspacePath = "monorepo-template.code-workspace"
        if (Test-Path $workspacePath) {
            $newWorkspacePath = "$ProjectName.code-workspace"
            $content = Get-Content $workspacePath -Raw
            $content = $content -replace "monorepo-template", $ProjectName
            Set-Content $newWorkspacePath $content
            Remove-Item $workspacePath
        }
        
        # Update Buck2 configuration
        $buckConfigPath = ".buckconfig"
        if (Test-Path $buckConfigPath) {
            $content = Get-Content $buckConfigPath -Raw
            $content = $content -replace "monorepo-template", $ProjectName
            Set-Content $buckConfigPath $content
        }
        
        # Create language-specific examples
        foreach ($lang in $LanguageList) {
            switch ($lang) {
                "rust" { New-RustExample -ProjectName $ProjectName }
                "typescript" { New-TypeScriptExample -ProjectName $ProjectName }
                "python" { New-PythonExample -ProjectName $ProjectName }
                "go" { New-GoExample -ProjectName $ProjectName -Organization $OrganizationName }
            }
        }
        
        # Handle frontend/backend options
        if ($Frontend) {
            if ($LanguageList -notcontains "typescript") {
                Write-Warning "Frontend requested but TypeScript not in language list. Adding TypeScript example."
                New-TypeScriptExample -ProjectName $ProjectName
            }
        }
        
        if ($NoBackend) {
            $webServicePath = "examples/web-service"
            if (Test-Path $webServicePath) {
                Remove-Item $webServicePath -Recurse -Force
            }
        }
        
        if ($NoInfra) {
            $infraPaths = @("infra", "examples/infrastructure")
            foreach ($path in $infraPaths) {
                if (Test-Path $path) {
                    Remove-Item $path -Recurse -Force
                }
            }
        }
    }
    finally {
        Pop-Location
    }
}

function New-RustExample {
    param([string]$ProjectName)
    
    Write-Info "Creating Rust example project..."
    
    $examplePath = "examples/web-service"
    if (!(Test-Path $examplePath)) {
        New-Item -ItemType Directory -Path "$examplePath/src" -Force | Out-Null
        
        $cargoToml = @"
[package]
name = "$ProjectName-web-service"
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
"@
        Set-Content "$examplePath/Cargo.toml" $cargoToml
        
        $mainRs = @'
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
'@
        Set-Content "$examplePath/src/main.rs" $mainRs
    }
}

function New-TypeScriptExample {
    param([string]$ProjectName)
    
    Write-Info "Creating TypeScript example project..."
    
    $examplePath = "examples/frontend-app"
    if (!(Test-Path $examplePath)) {
        New-Item -ItemType Directory -Path "$examplePath/src" -Force | Out-Null
        
        $packageJson = @"
{
  "name": "$ProjectName-frontend",
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
"@
        Set-Content "$examplePath/package.json" $packageJson
    }
}

function New-PythonExample {
    param([string]$ProjectName)
    
    Write-Info "Creating Python example project..."
    
    $examplePath = "examples/python-service"
    New-Item -ItemType Directory -Path $examplePath -Force | Out-Null
    
    $pyprojectToml = @"
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "$ProjectName-python-service"
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
"@
    Set-Content "$examplePath/pyproject.toml" $pyprojectToml
}

function New-GoExample {
    param([string]$ProjectName, [string]$Organization)
    
    Write-Info "Creating Go example project..."
    
    $examplePath = "examples/go-service"
    New-Item -ItemType Directory -Path $examplePath -Force | Out-Null
    
    $goMod = @"
module github.com/$Organization/$ProjectName/examples/go-service

go 1.21

require (
    github.com/gin-gonic/gin v1.9.1
    github.com/stretchr/testify v1.8.4
)
"@
    Set-Content "$examplePath/go.mod" $goMod
}

function Initialize-GitRepository {
    param([string]$TargetDir, [string]$TemplateVersion)
    
    Write-Info "Initializing git repository..."
    
    Push-Location $TargetDir
    
    try {
        if (!(Test-Path ".git")) {
            git init
            git add .
            git commit -m "Initial commit from monorepo template v$TemplateVersion"
            
            Write-Success "Git repository initialized with initial commit"
        }
    }
    finally {
        Pop-Location
    }
}

function Invoke-PostInitSetup {
    param([string]$TargetDir)
    
    Write-Info "Running post-initialization setup..."
    
    Push-Location $TargetDir
    
    try {
        # Run bootstrap script if it exists
        $bootstrapScript = "scripts/setup/bootstrap.ps1"
        if (Test-Path $bootstrapScript) {
            Write-Info "Running bootstrap script..."
            try {
                & ".\$bootstrapScript"
            }
            catch {
                Write-Warning "Bootstrap script failed, you may need to run it manually"
            }
        }
        elseif (Test-Path "scripts/setup/bootstrap.sh") {
            Write-Info "Found bash bootstrap script. Run it manually: ./scripts/setup/bootstrap.sh"
        }
    }
    finally {
        Pop-Location
    }
}

# Main execution
function Main {
    Write-Info "Monorepo Template Initialization"
    Write-Info "================================"
    
    if ($Help) {
        Show-Usage
        exit 0
    }
    
    # Interactive mode if no required parameters
    if ([string]::IsNullOrEmpty($Name) -or [string]::IsNullOrEmpty($Organization)) {
        Get-InteractiveInput
    }
    
    # Validate required arguments
    if ([string]::IsNullOrEmpty($Name)) {
        Write-Error "Project name is required. Use -Name or -n"
        exit 1
    }
    
    if ([string]::IsNullOrEmpty($Organization)) {
        Write-Error "Organization name is required. Use -Organization or -o"
        exit 1
    }
    
    # Validate project name format
    if (!(Test-ProjectName $Name)) {
        Write-Error "Project name must be lowercase, start with a letter, and contain only letters, numbers, and hyphens"
        exit 1
    }
    
    # Set default target directory
    if ([string]::IsNullOrEmpty($Directory)) {
        $Directory = $Name
    }
    
    # Parse languages
    $languageList = @("rust")  # Default
    if (![string]::IsNullOrEmpty($Languages)) {
        $languageList = $Languages -split ","
        $validLanguages = @("rust", "typescript", "python", "go")
        foreach ($lang in $languageList) {
            if ($lang -notin $validLanguages) {
                Write-Error "Invalid language: $lang. Supported: $($validLanguages -join ', ')"
                exit 1
            }
        }
    }
    
    Write-Info "Configuration:"
    Write-Info "  Project: $Name"
    Write-Info "  Organization: $Organization"
    Write-Info "  Languages: $($languageList -join ', ')"
    Write-Info "  Frontend: $Frontend"
    Write-Info "  Backend: $(!$NoBackend)"
    Write-Info "  Infrastructure: $(!$NoInfra)"
    Write-Info "  Target Directory: $Directory"
    Write-Info "  Template Version: $Version"
    
    Copy-TemplateFiles -TargetDir $Directory
    Update-TemplateContent -TargetDir $Directory -ProjectName $Name -OrganizationName $Organization -LanguageList $languageList
    Initialize-GitRepository -TargetDir $Directory -TemplateVersion $Version
    Invoke-PostInitSetup -TargetDir $Directory
    
    Write-Success "Template initialization complete!"
    Write-Info "Next steps:"
    Write-Info "  1. cd $Directory"
    Write-Info "  2. Review and customize the generated files"
    Write-Info "  3. Run '.\scripts\setup\bootstrap.ps1' if not already run"
    Write-Info "  4. Start developing!"
}

# Run main function
Main