# GitHub Actions Workflows

This directory contains the comprehensive CI/CD pipeline workflows for the monorepo template.

## Workflows Overview

### 1. CI Pipeline (`ci.yml`)
**Triggers:** Push to main/develop, Pull requests
**Purpose:** Core continuous integration with code validation, testing, and building

**Jobs:**
- **validate**: Code formatting, linting, type checking with Rust-based tools
- **test**: Automated testing with parallel execution across Rust versions
- **security**: Security scanning with cargo-audit, cargo-deny, and secret detection
- **build**: Multi-platform artifact building with Buck2

**Key Features:**
- Rust toolchain with clippy and rustfmt
- Buck2 build system integration
- Parallel testing with nextest
- Multi-platform builds (Linux, Windows, macOS)
- Comprehensive caching for performance

### 2. Deployment Pipeline (`deploy.yml`)
**Triggers:** Push to main, Tags, Manual dispatch
**Purpose:** Automated deployment with canary releases and rollback capability

**Jobs:**
- **pre-deploy**: Version determination and final validation
- **package**: Build and package deployment artifacts with signing
- **deploy-staging**: Staging environment deployment with smoke tests
- **deploy-canary**: Canary deployment with configurable traffic percentage
- **deploy-production**: Full production rollout with health checks
- **rollback**: Automatic rollback on deployment failures

**Key Features:**
- Canary deployment strategy
- Artifact signing with cosign
- Environment-specific deployments
- Automated rollback on failure
- Release creation for tagged versions

### 3. Security Scanning (`security.yml`)
**Triggers:** Push, Pull requests, Daily schedule, Manual dispatch
**Purpose:** Comprehensive security scanning and policy enforcement

**Jobs:**
- **dependency-scan**: Vulnerability scanning with cargo-audit and cargo-deny
- **static-analysis**: Code analysis with clippy and cargo-geiger
- **secret-scan**: Secret detection with TruffleHog and gitleaks
- **container-scan**: Container security with Trivy and Hadolint
- **infrastructure-scan**: IaC security with Checkov and kube-score
- **license-scan**: License compliance checking
- **policy-enforcement**: Security policy validation and reporting

**Key Features:**
- Rust-based security tools prioritized
- SARIF format for security findings
- Daily automated scans
- Policy enforcement with failure conditions
- Comprehensive security reporting

### 4. Performance Testing (`performance.yml`)
**Triggers:** Push to main, Pull requests, Weekly schedule, Manual dispatch
**Purpose:** Performance monitoring and regression detection

**Jobs:**
- **benchmark**: Criterion benchmarks and build performance testing
- **load-test**: HTTP load testing with Rust-based tools (oha, drill)
- **memory-profile**: Memory usage analysis with valgrind
- **regression-check**: Performance regression detection for PRs
- **resource-monitor**: Resource usage monitoring during builds

**Key Features:**
- Rust-based performance tools (hyperfine, oha)
- Automated regression detection
- PR comments with performance results
- Resource usage monitoring
- Code metrics analysis with tokei

## Configuration Requirements

### Secrets
The workflows require the following GitHub secrets:

- `GITHUB_TOKEN`: Automatically provided by GitHub
- Additional secrets may be needed for:
  - Container registry access
  - Deployment environments
  - Signing keys for artifacts
  - Monitoring system integration

### Environments
Configure the following GitHub environments:

- `staging`: Staging deployment environment
- `production-canary`: Canary deployment environment  
- `production`: Production deployment environment

### Branch Protection
Recommended branch protection rules for `main`:

- Require status checks to pass before merging
- Require branches to be up to date before merging
- Required status checks:
  - `Code Validation`
  - `Automated Testing`
  - `Security Scanning`
  - `Performance Regression Check` (for PRs)

## Customization

### Environment Variables
Key environment variables used across workflows:

- `CARGO_TERM_COLOR=always`: Colored Cargo output
- `RUST_BACKTRACE=1`: Detailed error backtraces
- Custom variables can be added per workflow needs

### Tool Versions
Tools are installed using latest versions by default. Pin specific versions by modifying:

- Rust toolchain version in `dtolnay/rust-toolchain@stable`
- Buck2 version in download URLs
- Cargo tool versions in `cargo install` commands

### Deployment Customization
Modify deployment jobs to match your infrastructure:

- Replace placeholder deployment commands with actual ones
- Configure environment URLs and health check endpoints
- Adjust canary deployment percentages and monitoring duration
- Set up proper artifact signing and verification

### Security Policy Customization
Adjust security policies in `security.yml`:

- Modify vulnerability thresholds in policy enforcement
- Add/remove security scanning tools based on needs
- Configure license compliance rules
- Set up integration with security management systems

## Monitoring and Observability

All workflows include:

- Artifact uploads for results and reports
- Status reporting and notifications
- Integration with GitHub's security tab (SARIF uploads)
- Performance metrics collection and comparison

## Best Practices

1. **Caching**: All workflows use appropriate caching for Rust dependencies
2. **Parallelization**: Jobs run in parallel where possible for speed
3. **Fail Fast**: Critical security issues block deployments
4. **Observability**: Comprehensive logging and artifact collection
5. **Rollback**: Automated rollback capabilities for failed deployments
6. **Security First**: Security scanning integrated into all stages