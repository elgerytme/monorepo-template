# Migration Guide: Adopting the Monorepo Template

This guide helps you migrate existing projects to use the monorepo template structure and tooling.

## Overview

The migration process involves:
1. **Assessment** - Evaluating your current project structure
2. **Planning** - Creating a migration strategy
3. **Structure Migration** - Reorganizing code and files
4. **Tooling Migration** - Adopting Buck2 and Rust-based tools
5. **CI/CD Migration** - Updating build and deployment pipelines
6. **Validation** - Ensuring everything works correctly

## Pre-Migration Assessment

### Current Project Analysis

Before starting the migration, analyze your current project:

```bash
# Run the assessment script
./scripts/migration/assess-project.sh /path/to/your/project

# Or use PowerShell on Windows
.\scripts\migration\assess-project.ps1 -ProjectPath "C:\path\to\your\project"
```

### Compatibility Check

Check if your project is compatible with the template:

- **Languages**: Rust, TypeScript, Python, Go are fully supported
- **Build Systems**: Can migrate from Maven, Gradle, npm, pip, go mod
- **CI/CD**: GitHub Actions preferred, but can adapt others
- **Dependencies**: Review for Buck2 compatibility

## Migration Strategies

### Strategy 1: Gradual Migration (Recommended)

Migrate components incrementally while maintaining existing functionality.

**Timeline**: 2-4 weeks
**Risk**: Low
**Effort**: Medium

**Steps**:
1. Set up template structure alongside existing code
2. Migrate one component at a time
3. Update CI/CD incrementally
4. Remove old structure when complete

### Strategy 2: Complete Migration

Migrate everything at once in a dedicated effort.

**Timeline**: 1-2 weeks
**Risk**: Medium
**Effort**: High

**Steps**:
1. Create feature branch
2. Migrate all components simultaneously
3. Update all tooling and CI/CD
4. Test thoroughly before merging

### Strategy 3: Hybrid Approach

Keep existing structure but adopt template tooling and practices.

**Timeline**: 1-3 weeks
**Risk**: Low
**Effort**: Low-Medium

**Steps**:
1. Adopt Rust-based tooling
2. Implement template CI/CD patterns
3. Gradually reorganize structure
4. Optional: Full structure migration later

## Step-by-Step Migration

### Step 1: Initialize Template Structure

```bash
# Create new directory structure
mkdir -p {apps,libs,tools,infra,docs,scripts,config,examples}
mkdir -p {releases,signatures,artifacts}

# Copy template configuration files
cp /path/to/template/.buckconfig .
cp /path/to/template/.buckroot .
cp /path/to/template/BUCK .
cp -r /path/to/template/config .
cp -r /path/to/template/scripts .
cp -r /path/to/template/.github .
cp -r /path/to/template/.devcontainer .
```

### Step 2: Migrate Code Structure

#### For Web Services

```bash
# Move existing service code
mkdir -p apps/your-service
mv src apps/your-service/
mv Cargo.toml apps/your-service/

# Create Buck2 build file
cat > apps/your-service/BUCK << 'EOF'
load("@prelude//rust:defs.bzl", "rust_binary", "rust_library")

rust_binary(
    name = "your-service",
    srcs = glob(["src/**/*.rs"]),
    deps = [
        # Add dependencies here
    ],
)
EOF
```

#### For Libraries

```bash
# Move library code
mkdir -p libs/your-library
mv lib-src libs/your-library/src
mv lib-Cargo.toml libs/your-library/Cargo.toml

# Create Buck2 build file
cat > libs/your-library/BUCK << 'EOF'
load("@prelude//rust:defs.bzl", "rust_library")

rust_library(
    name = "your-library",
    srcs = glob(["src/**/*.rs"]),
    visibility = ["PUBLIC"],
)
EOF
```

#### For Frontend Applications

```bash
# Move frontend code
mkdir -p apps/frontend
mv frontend-src apps/frontend/src
mv package.json apps/frontend/

# Create Buck2 build file
cat > apps/frontend/BUCK << 'EOF'
load("@prelude//js:defs.bzl", "js_bundle")

js_bundle(
    name = "frontend",
    entry_point = "src/index.ts",
    deps = [
        # Add dependencies here
    ],
)
EOF
```

### Step 3: Update Build Configuration

#### Migrate from Cargo Workspace

```toml
# Old Cargo.toml workspace
[workspace]
members = [
    "service1",
    "service2", 
    "shared-lib"
]

# New structure: Individual Cargo.toml files in each component
# apps/service1/Cargo.toml
# apps/service2/Cargo.toml
# libs/shared-lib/Cargo.toml
```

#### Migrate from npm Workspaces

```json
// Old package.json
{
  "workspaces": [
    "packages/*",
    "apps/*"
  ]
}

// New structure: Individual package.json files
// apps/frontend/package.json
// libs/ui-components/package.json
```

### Step 4: Update Dependencies

#### Rust Dependencies

```bash
# Update Cargo.toml files to use local path dependencies
[dependencies]
shared-lib = { path = "../../libs/shared-lib" }

# Or use Buck2 dependencies
deps = [
    "//libs/shared-lib:shared-lib",
]
```

#### TypeScript Dependencies

```json
{
  "dependencies": {
    "@company/shared-types": "file:../../libs/shared-types"
  }
}
```

### Step 5: Migrate CI/CD

#### From GitHub Actions

```yaml
# Update existing .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    
    # Replace with Buck2 build
    - name: Setup Buck2
      run: |
        curl -L https://github.com/facebook/buck2/releases/latest/download/buck2-x86_64-unknown-linux-gnu.zst | zstd -d > buck2
        chmod +x buck2
        sudo mv buck2 /usr/local/bin/
    
    - name: Build with Buck2
      run: buck2 build //...
    
    - name: Test with Buck2
      run: buck2 test //...
```

#### From Jenkins

```groovy
// Update Jenkinsfile
pipeline {
    agent any
    
    stages {
        stage('Setup') {
            steps {
                // Install Buck2 and Rust tooling
                sh './scripts/setup/bootstrap.sh'
            }
        }
        
        stage('Build') {
            steps {
                sh 'buck2 build //...'
            }
        }
        
        stage('Test') {
            steps {
                sh 'buck2 test //...'
            }
        }
    }
}
```

### Step 6: Update Development Environment

#### VS Code Configuration

```json
// .vscode/settings.json
{
    "rust-analyzer.linkedProjects": [
        "apps/service1/Cargo.toml",
        "apps/service2/Cargo.toml",
        "libs/shared-lib/Cargo.toml"
    ],
    "files.watcherExclude": {
        "**/buck-out/**": true
    }
}
```

#### Development Container

```json
// .devcontainer/devcontainer.json
{
    "name": "Monorepo Development",
    "build": {
        "dockerfile": "Dockerfile"
    },
    "features": {
        "ghcr.io/devcontainers/features/rust:1": {},
        "ghcr.io/devcontainers/features/node:1": {}
    },
    "postCreateCommand": "./scripts/setup/bootstrap.sh"
}
```

## Language-Specific Migration

### Rust Projects

```bash
# 1. Update Cargo.toml for Buck2 compatibility
# 2. Move to appropriate directory (apps/ or libs/)
# 3. Create BUCK file
# 4. Update import paths if needed

# Example BUCK file for Rust binary
load("@prelude//rust:defs.bzl", "rust_binary")

rust_binary(
    name = "my-service",
    srcs = glob(["src/**/*.rs"]),
    deps = [
        "//libs/common:common",
    ],
)
```

### TypeScript Projects

```bash
# 1. Update package.json
# 2. Configure TypeScript paths
# 3. Create BUCK file for bundling
# 4. Update import statements

# Example BUCK file for TypeScript
load("@prelude//js:defs.bzl", "js_bundle")

js_bundle(
    name = "frontend",
    entry_point = "src/index.ts",
    deps = [
        "//libs/ui-components:ui-components",
    ],
)
```

### Python Projects

```bash
# 1. Update pyproject.toml or setup.py
# 2. Create BUCK file
# 3. Update import paths

# Example BUCK file for Python
load("@prelude//python:defs.bzl", "python_binary")

python_binary(
    name = "my-script",
    main = "src/main.py",
    deps = [
        "//libs/python-utils:python-utils",
    ],
)
```

### Go Projects

```bash
# 1. Update go.mod
# 2. Create BUCK file
# 3. Update import paths

# Example BUCK file for Go
load("@prelude//go:defs.bzl", "go_binary")

go_binary(
    name = "my-service",
    srcs = glob(["**/*.go"]),
    deps = [
        "//libs/go-common:go-common",
    ],
)
```

## Common Migration Issues

### Issue 1: Dependency Resolution

**Problem**: Dependencies not resolving correctly after migration.

**Solution**:
```bash
# Check Buck2 dependency graph
buck2 query "deps(//apps/your-app:your-app)"

# Update BUCK files with correct paths
deps = [
    "//libs/shared:shared",  # Correct path
]
```

### Issue 2: Build Failures

**Problem**: Buck2 builds failing with unclear errors.

**Solution**:
```bash
# Clean build cache
buck2 clean

# Build with verbose output
buck2 build //... --verbose

# Check individual targets
buck2 build //apps/your-app:your-app
```

### Issue 3: Test Failures

**Problem**: Tests failing after migration.

**Solution**:
```bash
# Run tests with detailed output
buck2 test //... --test-output all

# Check test configuration in BUCK files
rust_test(
    name = "tests",
    srcs = glob(["tests/**/*.rs"]),
    deps = [
        ":your-lib",
    ],
)
```

### Issue 4: CI/CD Pipeline Issues

**Problem**: CI/CD failing after migration.

**Solution**:
```yaml
# Ensure Buck2 is properly installed
- name: Install Buck2
  run: |
    curl -L https://github.com/facebook/buck2/releases/latest/download/buck2-x86_64-unknown-linux-gnu.zst | zstd -d > buck2
    chmod +x buck2
    sudo mv buck2 /usr/local/bin/

# Use correct build commands
- name: Build
  run: buck2 build //...
```

## Validation and Testing

### Post-Migration Checklist

- [ ] All code compiles successfully with Buck2
- [ ] All tests pass
- [ ] CI/CD pipeline works
- [ ] Development environment setup works
- [ ] Documentation is updated
- [ ] Team is trained on new tooling

### Validation Commands

```bash
# Validate template structure
./scripts/template/validate-template.sh

# Build everything
buck2 build //...

# Run all tests
buck2 test //...

# Check code quality
./scripts/ci/validate.sh

# Security audit
./scripts/security/audit.sh
```

## Rollback Plan

If migration fails, you can rollback:

### Immediate Rollback

```bash
# Switch back to previous branch
git checkout main

# Or revert migration commit
git revert <migration-commit-hash>
```

### Partial Rollback

```bash
# Keep template structure but revert to old build system
git checkout HEAD~1 -- .buckconfig BUCK
git checkout HEAD~1 -- .github/workflows/

# Commit partial rollback
git commit -m "Partial rollback: revert build system changes"
```

## Getting Help

### Resources

- **Template Documentation**: `docs/`
- **Architecture Decisions**: `docs/architecture/`
- **Troubleshooting**: `docs/runbooks/`
- **Community**: GitHub Discussions

### Support Channels

1. **Internal Documentation**: Check `docs/` directory
2. **GitHub Issues**: Report bugs and request features
3. **Team Chat**: Ask questions in development channels
4. **Office Hours**: Weekly migration support sessions

### Migration Assistance

For complex migrations, consider:

- **Pair Programming**: Work with template maintainers
- **Code Review**: Get migration plan reviewed
- **Pilot Project**: Start with smaller project first
- **Training Sessions**: Team training on new tooling

## Best Practices

### During Migration

1. **Incremental Changes**: Migrate one component at a time
2. **Frequent Testing**: Test after each migration step
3. **Documentation**: Document decisions and changes
4. **Team Communication**: Keep team informed of progress
5. **Backup Strategy**: Maintain ability to rollback

### After Migration

1. **Monitor Performance**: Watch build times and CI/CD performance
2. **Gather Feedback**: Collect team feedback on new tooling
3. **Continuous Improvement**: Iterate on template based on usage
4. **Knowledge Sharing**: Share learnings with other teams
5. **Template Updates**: Keep template updated with latest practices

## Timeline Examples

### Small Project (1-2 services)
- **Week 1**: Assessment and planning
- **Week 2**: Structure migration and testing
- **Week 3**: CI/CD migration and validation

### Medium Project (3-10 services)
- **Week 1**: Assessment and planning
- **Week 2-3**: Incremental component migration
- **Week 4**: CI/CD migration and integration testing
- **Week 5**: Validation and team training

### Large Project (10+ services)
- **Week 1-2**: Assessment and detailed planning
- **Week 3-6**: Incremental migration by team/domain
- **Week 7-8**: CI/CD migration and integration
- **Week 9-10**: Validation, optimization, and training

Remember: These are estimates. Actual timeline depends on project complexity, team size, and existing technical debt.