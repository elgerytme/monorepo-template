# Documentation Generation Script (PowerShell)
# Generates comprehensive documentation for the monorepo

param(
    [switch]$CleanOnly,
    [switch]$SkipValidation,
    [switch]$Help
)

# Configuration
$DocsDir = "docs"
$OutputDir = "target/docs"
$RustDocDir = "$OutputDir/rust"
$TsDocDir = "$OutputDir/typescript"
$ApiDocDir = "$OutputDir/api"

# Colors for output
$Colors = @{
    Red = "Red"
    Green = "Green"
    Yellow = "Yellow"
    Blue = "Blue"
    White = "White"
}

# Logging functions
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor $Colors.Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor $Colors.Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor $Colors.Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $Colors.Red
}

# Show help
function Show-Help {
    Write-Host "Usage: .\generate-docs.ps1 [OPTIONS]"
    Write-Host "Options:"
    Write-Host "  -CleanOnly        Only clean documentation directories"
    Write-Host "  -SkipValidation   Skip documentation validation"
    Write-Host "  -Help            Show this help message"
}

# Check if required tools are installed
function Test-Dependencies {
    Write-Info "Checking dependencies..."
    
    $missingDeps = @()
    
    # Check for Rust tools
    if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
        $missingDeps += "cargo"
    }
    
    if (-not (Get-Command rustdoc -ErrorAction SilentlyContinue)) {
        $missingDeps += "rustdoc"
    }
    
    # Check for Node.js tools
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        $missingDeps += "node"
    }
    
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        $missingDeps += "npm"
    }
    
    # Check for documentation tools
    if (-not (Get-Command typedoc -ErrorAction SilentlyContinue)) {
        Write-Warning "typedoc not found, installing..."
        npm install -g typedoc
    }
    
    if (-not (Get-Command swagger-codegen -ErrorAction SilentlyContinue)) {
        Write-Warning "swagger-codegen not found, installing..."
        npm install -g swagger-codegen-cli
    }
    
    if ($missingDeps.Count -gt 0) {
        Write-Error "Missing dependencies: $($missingDeps -join ', ')"
        Write-Error "Please install the missing dependencies and try again."
        exit 1
    }
    
    Write-Success "All dependencies are available"
}

# Clean previous documentation
function Clear-Documentation {
    Write-Info "Cleaning previous documentation..."
    
    if (Test-Path $OutputDir) {
        Remove-Item -Path $OutputDir -Recurse -Force
    }
    
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    New-Item -ItemType Directory -Path $RustDocDir -Force | Out-Null
    New-Item -ItemType Directory -Path $TsDocDir -Force | Out-Null
    New-Item -ItemType Directory -Path $ApiDocDir -Force | Out-Null
    
    Write-Success "Cleaned documentation directories"
}

# Generate Rust documentation
function New-RustDocs {
    Write-Info "Generating Rust documentation..."
    
    # Set environment variable for custom header
    $env:RUSTDOCFLAGS = "--html-in-header docs/api/rust-doc-header.html"
    
    # Generate documentation for all workspace crates
    $result = cargo doc --workspace --no-deps --document-private-items --target-dir $OutputDir --examples
    
    if ($LASTEXITCODE -eq 0) {
        # Copy generated docs to the right location
        if (Test-Path "$OutputDir/doc") {
            Copy-Item -Path "$OutputDir/doc/*" -Destination $RustDocDir -Recurse -Force
            Write-Success "Rust documentation generated successfully"
        } else {
            Write-Error "Failed to generate Rust documentation"
            return $false
        }
    } else {
        Write-Error "Cargo doc command failed"
        return $false
    }
    
    return $true
}

# Generate TypeScript documentation
function New-TypeScriptDocs {
    Write-Info "Generating TypeScript documentation..."
    
    # Find TypeScript projects
    $tsProjects = Get-ChildItem -Path "apps", "libs" -Recurse -Name "tsconfig.json" -ErrorAction SilentlyContinue | 
                  ForEach-Object { Split-Path $_ -Parent }
    
    if ($tsProjects.Count -eq 0) {
        Write-Warning "No TypeScript projects found"
        return $true
    }
    
    foreach ($project in $tsProjects) {
        $projectName = Split-Path $project -Leaf
        $outputPath = "$TsDocDir/$projectName"
        
        Write-Info "Generating docs for TypeScript project: $projectName"
        
        if ((Test-Path "$project/src/index.ts") -or (Test-Path "$project/src")) {
            $readmePath = "$project/README.md"
            $readmeArg = if (Test-Path $readmePath) { "--readme `"$readmePath`"" } else { "" }
            
            $cmd = "typedoc --out `"$outputPath`" --theme minimal $readmeArg --name `"$projectName`" --excludePrivate --excludeProtected --hideGenerator `"$project/src`""
            Invoke-Expression $cmd
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Generated TypeScript docs for $projectName"
            } else {
                Write-Warning "Failed to generate TypeScript docs for $projectName"
            }
        } else {
            Write-Warning "No TypeScript source found in $project"
        }
    }
    
    return $true
}

# Generate OpenAPI documentation
function New-OpenApiDocs {
    Write-Info "Generating OpenAPI documentation..."
    
    # Find OpenAPI specifications
    $openApiSpecs = @()
    if (Test-Path "docs/api/openapi") {
        $openApiSpecs = Get-ChildItem -Path "docs/api/openapi" -Filter "*.yaml" -ErrorAction SilentlyContinue
        $openApiSpecs += Get-ChildItem -Path "docs/api/openapi" -Filter "*.yml" -ErrorAction SilentlyContinue
    }
    
    if ($openApiSpecs.Count -eq 0) {
        Write-Warning "No OpenAPI specifications found"
        return $true
    }
    
    foreach ($spec in $openApiSpecs) {
        $specName = [System.IO.Path]::GetFileNameWithoutExtension($spec.Name)
        $outputPath = "$ApiDocDir/$specName"
        
        Write-Info "Generating OpenAPI docs for: $specName"
        
        # Validate the specification first
        $validateResult = swagger-codegen validate -i $spec.FullName
        if ($LASTEXITCODE -eq 0) {
            # Generate HTML documentation
            swagger-codegen generate -i $spec.FullName -l html2 -o $outputPath
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Generated OpenAPI docs for $specName"
            } else {
                Write-Error "Failed to generate OpenAPI docs for $specName"
            }
        } else {
            Write-Error "Invalid OpenAPI specification: $($spec.FullName)"
        }
    }
    
    return $true
}

# Generate documentation index
function New-DocumentationIndex {
    Write-Info "Generating documentation index..."
    
    $indexFile = "$OutputDir/index.html"
    
    $indexContent = @'
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
'@

    # Add Rust documentation links
    if (Test-Path $RustDocDir) {
        $rustCrates = Get-ChildItem -Path $RustDocDir -Directory
        foreach ($crate in $rustCrates) {
            if (Test-Path "$($crate.FullName)/index.html") {
                $crateName = $crate.Name
                $indexContent += @"
            <a href="rust/$crateName/index.html" class="link">
                <strong>$crateName</strong>
                <div class="description">Rust crate documentation</div>
            </a>
"@
            }
        }
    }

    $indexContent += @'
        </div>
    </div>

    <div class="section">
        <h2>📘 TypeScript APIs</h2>
        <p>Documentation for TypeScript projects and libraries</p>
        <div class="links">
'@

    # Add TypeScript documentation links
    if (Test-Path $TsDocDir) {
        $tsProjects = Get-ChildItem -Path $TsDocDir -Directory
        foreach ($project in $tsProjects) {
            if (Test-Path "$($project.FullName)/index.html") {
                $projectName = $project.Name
                $indexContent += @"
            <a href="typescript/$projectName/index.html" class="link">
                <strong>$projectName</strong>
                <div class="description">TypeScript project documentation</div>
            </a>
"@
            }
        }
    }

    $indexContent += @'
        </div>
    </div>

    <div class="section">
        <h2>🌐 REST APIs</h2>
        <p>OpenAPI specifications and REST API documentation</p>
        <div class="links">
'@

    # Add OpenAPI documentation links
    if (Test-Path $ApiDocDir) {
        $apiProjects = Get-ChildItem -Path $ApiDocDir -Directory
        foreach ($api in $apiProjects) {
            if (Test-Path "$($api.FullName)/index.html") {
                $apiName = $api.Name
                $indexContent += @"
            <a href="api/$apiName/index.html" class="link">
                <strong>$apiName</strong>
                <div class="description">REST API documentation</div>
            </a>
"@
            }
        }
    }

    $indexContent += @'
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
'@

    Set-Content -Path $indexFile -Value $indexContent -Encoding UTF8
    Write-Success "Generated documentation index"
}

# Generate search index
function New-SearchIndex {
    Write-Info "Generating search index..."
    
    $searchIndexFile = "$OutputDir/search-index.json"
    
    $searchIndex = @{
        documents = @()
        index = @{
            version = "1.0.0"
            fields = @("title", "content")
            ref = "id"
        }
    } | ConvertTo-Json -Depth 3
    
    Set-Content -Path $searchIndexFile -Value $searchIndex -Encoding UTF8
    Write-Success "Generated search index"
}

# Copy static assets
function Copy-Assets {
    Write-Info "Copying static assets..."
    
    # Copy CSS and JavaScript files if they exist
    if (Test-Path "docs/assets") {
        Copy-Item -Path "docs/assets" -Destination $OutputDir -Recurse -Force
        Write-Success "Copied static assets"
    }
    
    # Copy any additional documentation files
    if (Test-Path "docs/README.md") {
        Copy-Item -Path "docs/README.md" -Destination $OutputDir -Force
    }
}

# Validate generated documentation
function Test-Documentation {
    Write-Info "Validating generated documentation..."
    
    $errors = 0
    
    # Check if main index exists
    if (-not (Test-Path "$OutputDir/index.html")) {
        Write-Error "Main index.html not found"
        $errors++
    }
    
    # Check if documentation was generated for expected projects
    $expectedRustCrates = @("observability", "shared_library")
    foreach ($crate in $expectedRustCrates) {
        if (-not (Test-Path "$RustDocDir/$crate")) {
            Write-Warning "Missing Rust documentation for: $crate"
        }
    }
    
    if ($errors -eq 0) {
        Write-Success "Documentation validation passed"
        return $true
    } else {
        Write-Error "Documentation validation failed with $errors errors"
        return $false
    }
}

# Main function
function Main {
    if ($Help) {
        Show-Help
        return
    }
    
    Write-Info "Starting documentation generation..."
    
    # Check dependencies
    Test-Dependencies
    
    # Clean previous documentation
    Clear-Documentation
    
    if ($CleanOnly) {
        Write-Success "Documentation directories cleaned"
        return
    }
    
    # Generate documentation
    $success = $true
    $success = $success -and (New-RustDocs)
    $success = $success -and (New-TypeScriptDocs)
    $success = $success -and (New-OpenApiDocs)
    
    if (-not $success) {
        Write-Error "Documentation generation failed"
        exit 1
    }
    
    # Generate index and search
    New-DocumentationIndex
    New-SearchIndex
    
    # Copy assets
    Copy-Assets
    
    # Validate documentation
    if (-not $SkipValidation) {
        if (-not (Test-Documentation)) {
            exit 1
        }
    }
    
    Write-Success "Documentation generation completed successfully!"
    Write-Info "Documentation available at: $OutputDir/index.html"
    
    # Open documentation in browser if available
    if (Get-Command start -ErrorAction SilentlyContinue) {
        start "$OutputDir/index.html"
    }
}

# Run main function
Main