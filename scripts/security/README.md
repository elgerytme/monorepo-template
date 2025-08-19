# Security Scripts

This directory contains security automation scripts for vulnerability scanning, secret detection, and policy enforcement.

## Scripts

- `vulnerability-scan.sh/ps1` - Dependency vulnerability scanning with cargo-audit
- `secret-detection.sh/ps1` - Secret detection and prevention system
- `container-security.sh/ps1` - Container security scanning integration
- `security-policy.sh/ps1` - Security policy enforcement automation

## Usage

All scripts can be run individually or as part of the CI/CD pipeline. They follow the same pattern:
- Exit code 0 for success
- Exit code 1 for security violations found
- Detailed output with remediation suggestions

## Requirements

- cargo-audit for Rust dependency scanning
- gitleaks for secret detection
- trivy for container scanning
- Custom policy enforcement tools