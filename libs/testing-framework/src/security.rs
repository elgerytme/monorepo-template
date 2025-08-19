//! Security testing automation and utilities

use crate::TestResult;
use std::process::Command;
use std::path::Path;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Security scan types
#[derive(Debug, Clone, PartialEq)]
pub enum ScanType {
    Dependencies,
    StaticAnalysis,
    Secrets,
    Container,
    License,
}

/// Security vulnerability severity levels
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum Severity {
    Critical,
    High,
    Medium,
    Low,
    Info,
}

/// Security finding
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SecurityFinding {
    pub id: String,
    pub title: String,
    pub description: String,
    pub severity: Severity,
    pub scan_type: String,
    pub file_path: Option<String>,
    pub line_number: Option<u32>,
    pub remediation: Option<String>,
}

/// Security scan results
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SecurityScanResults {
    pub scan_type: String,
    pub findings: Vec<SecurityFinding>,
    pub scan_duration_ms: u64,
    pub scanned_files: usize,
}

/// Security test runner
pub struct SecurityTester {
    config: SecurityConfig,
}

#[derive(Debug, Clone)]
pub struct SecurityConfig {
    pub fail_on_high: bool,
    pub fail_on_medium: bool,
    pub allowed_licenses: Vec<String>,
    pub ignore_advisories: Vec<String>,
    pub max_scan_time_seconds: u64,
}

impl Default for SecurityConfig {
    fn default() -> Self {
        Self {
            fail_on_high: true,
            fail_on_medium: false,
            allowed_licenses: vec![
                "MIT".to_string(),
                "Apache-2.0".to_string(),
                "BSD-3-Clause".to_string(),
                "ISC".to_string(),
            ],
            ignore_advisories: vec![],
            max_scan_time_seconds: 300,
        }
    }
}

impl SecurityTester {
    pub fn new(config: SecurityConfig) -> Self {
        Self { config }
    }

    /// Run all security scans
    pub async fn run_all_scans(&self, project_path: &Path) -> TestResult<Vec<SecurityScanResults>> {
        let mut results = Vec::new();

        // Dependency vulnerability scan
        if let Ok(dep_results) = self.scan_dependencies(project_path).await {
            results.push(dep_results);
        }

        // Static analysis scan
        if let Ok(static_results) = self.scan_static_analysis(project_path).await {
            results.push(static_results);
        }

        // Secret detection scan
        if let Ok(secret_results) = self.scan_secrets(project_path).await {
            results.push(secret_results);
        }

        // License compliance scan
        if let Ok(license_results) = self.scan_licenses(project_path).await {
            results.push(license_results);
        }

        Ok(results)
    }

    /// Scan for dependency vulnerabilities using cargo-audit
    pub async fn scan_dependencies(&self, project_path: &Path) -> TestResult<SecurityScanResults> {
        let start_time = std::time::Instant::now();
        
        let output = Command::new("cargo")
            .args(&["audit", "--json", "--quiet"])
            .current_dir(project_path)
            .output()?;

        let scan_duration = start_time.elapsed().as_millis() as u64;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(format!("cargo-audit failed: {}", stderr).into());
        }

        let stdout = String::from_utf8_lossy(&output.stdout);
        let findings = self.parse_audit_output(&stdout)?;

        Ok(SecurityScanResults {
            scan_type: "dependencies".to_string(),
            findings,
            scan_duration_ms: scan_duration,
            scanned_files: 1, // Cargo.toml
        })
    }

    /// Scan for static analysis issues using clippy
    pub async fn scan_static_analysis(&self, project_path: &Path) -> TestResult<SecurityScanResults> {
        let start_time = std::time::Instant::now();
        
        let output = Command::new("cargo")
            .args(&[
                "clippy",
                "--all-targets",
                "--all-features",
                "--message-format=json",
                "--",
                "-W", "clippy::all",
                "-W", "clippy::pedantic",
                "-W", "clippy::security",
            ])
            .current_dir(project_path)
            .output()?;

        let scan_duration = start_time.elapsed().as_millis() as u64;
        let stdout = String::from_utf8_lossy(&output.stdout);
        let findings = self.parse_clippy_output(&stdout)?;

        // Count Rust files
        let scanned_files = self.count_rust_files(project_path)?;

        Ok(SecurityScanResults {
            scan_type: "static_analysis".to_string(),
            findings,
            scan_duration_ms: scan_duration,
            scanned_files,
        })
    }

    /// Scan for secrets using a simple pattern-based approach
    pub async fn scan_secrets(&self, project_path: &Path) -> TestResult<SecurityScanResults> {
        let start_time = std::time::Instant::now();
        
        // Define secret patterns
        let secret_patterns = vec![
            (r"(?i)password\s*=\s*['\"][^'\"]{8,}['\"]", "Hardcoded password"),
            (r"(?i)api[_-]?key\s*=\s*['\"][^'\"]{16,}['\"]", "API key"),
            (r"(?i)secret[_-]?key\s*=\s*['\"][^'\"]{16,}['\"]", "Secret key"),
            (r"(?i)token\s*=\s*['\"][^'\"]{16,}['\"]", "Authentication token"),
            (r"-----BEGIN [A-Z ]+-----", "Private key"),
        ];

        let mut findings = Vec::new();
        let mut scanned_files = 0;

        // Scan source files
        for entry in walkdir::WalkDir::new(project_path)
            .into_iter()
            .filter_map(|e| e.ok())
            .filter(|e| e.file_type().is_file())
        {
            let path = entry.path();
            if let Some(ext) = path.extension() {
                if matches!(ext.to_str(), Some("rs") | Some("toml") | Some("json") | Some("yaml") | Some("yml")) {
                    if let Ok(content) = std::fs::read_to_string(path) {
                        scanned_files += 1;
                        findings.extend(self.scan_file_for_secrets(path, &content, &secret_patterns)?);
                    }
                }
            }
        }

        let scan_duration = start_time.elapsed().as_millis() as u64;

        Ok(SecurityScanResults {
            scan_type: "secrets".to_string(),
            findings,
            scan_duration_ms: scan_duration,
            scanned_files,
        })
    }

    /// Scan for license compliance
    pub async fn scan_licenses(&self, project_path: &Path) -> TestResult<SecurityScanResults> {
        let start_time = std::time::Instant::now();
        
        let output = Command::new("cargo")
            .args(&["tree", "--format", "{p} {l}"])
            .current_dir(project_path)
            .output()?;

        let scan_duration = start_time.elapsed().as_millis() as u64;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(format!("cargo tree failed: {}", stderr).into());
        }

        let stdout = String::from_utf8_lossy(&output.stdout);
        let findings = self.parse_license_output(&stdout)?;

        Ok(SecurityScanResults {
            scan_type: "licenses".to_string(),
            findings,
            scan_duration_ms: scan_duration,
            scanned_files: 1, // Cargo.toml
        })
    }

    /// Parse cargo-audit JSON output
    fn parse_audit_output(&self, output: &str) -> TestResult<Vec<SecurityFinding>> {
        let mut findings = Vec::new();
        
        for line in output.lines() {
            if line.trim().is_empty() {
                continue;
            }
            
            // Simple JSON parsing for audit output
            if line.contains("\"type\":\"warning\"") && line.contains("\"kind\":\"yanked\"") {
                // Skip yanked crate warnings for now
                continue;
            }
            
            if line.contains("\"advisory\"") {
                // This is a simplified parser - in production, use proper JSON parsing
                let finding = SecurityFinding {
                    id: "AUDIT-001".to_string(),
                    title: "Dependency vulnerability detected".to_string(),
                    description: "A security vulnerability was found in a dependency".to_string(),
                    severity: Severity::High,
                    scan_type: "dependencies".to_string(),
                    file_path: Some("Cargo.toml".to_string()),
                    line_number: None,
                    remediation: Some("Update the affected dependency to a secure version".to_string()),
                };
                findings.push(finding);
            }
        }

        Ok(findings)
    }

    /// Parse clippy JSON output for security-related warnings
    fn parse_clippy_output(&self, output: &str) -> TestResult<Vec<SecurityFinding>> {
        let mut findings = Vec::new();
        
        for line in output.lines() {
            if line.trim().is_empty() {
                continue;
            }
            
            // Look for security-related clippy warnings
            if line.contains("clippy::") && (
                line.contains("security") || 
                line.contains("panic") ||
                line.contains("unwrap") ||
                line.contains("expect")
            ) {
                let finding = SecurityFinding {
                    id: "CLIPPY-SEC-001".to_string(),
                    title: "Potential security issue detected".to_string(),
                    description: "Clippy detected a potential security-related issue".to_string(),
                    severity: Severity::Medium,
                    scan_type: "static_analysis".to_string(),
                    file_path: None,
                    line_number: None,
                    remediation: Some("Review and fix the clippy warning".to_string()),
                };
                findings.push(finding);
            }
        }

        Ok(findings)
    }

    /// Scan a single file for secret patterns
    fn scan_file_for_secrets(
        &self,
        file_path: &Path,
        content: &str,
        patterns: &[(&str, &str)],
    ) -> TestResult<Vec<SecurityFinding>> {
        let mut findings = Vec::new();
        
        for (line_num, line) in content.lines().enumerate() {
            for (pattern, description) in patterns {
                if regex::Regex::new(pattern)?.is_match(line) {
                    let finding = SecurityFinding {
                        id: format!("SECRET-{:03}", findings.len() + 1),
                        title: format!("Potential secret detected: {}", description),
                        description: format!("Pattern '{}' matched in file", description),
                        severity: Severity::High,
                        scan_type: "secrets".to_string(),
                        file_path: Some(file_path.to_string_lossy().to_string()),
                        line_number: Some(line_num as u32 + 1),
                        remediation: Some("Remove hardcoded secrets and use environment variables or secure storage".to_string()),
                    };
                    findings.push(finding);
                }
            }
        }

        Ok(findings)
    }

    /// Parse license output and check for compliance
    fn parse_license_output(&self, output: &str) -> TestResult<Vec<SecurityFinding>> {
        let mut findings = Vec::new();
        
        for line in output.lines() {
            if let Some(license_start) = line.rfind('(') {
                if let Some(license_end) = line.rfind(')') {
                    let license = &line[license_start + 1..license_end];
                    
                    if !license.is_empty() && 
                       !self.config.allowed_licenses.contains(&license.to_string()) &&
                       license != "file" // Skip file-based licenses for now
                    {
                        let finding = SecurityFinding {
                            id: format!("LICENSE-{:03}", findings.len() + 1),
                            title: format!("Non-compliant license: {}", license),
                            description: format!("Dependency uses license '{}' which is not in the allowed list", license),
                            severity: Severity::Medium,
                            scan_type: "licenses".to_string(),
                            file_path: Some("Cargo.toml".to_string()),
                            line_number: None,
                            remediation: Some("Review license compatibility or add to allowed licenses list".to_string()),
                        };
                        findings.push(finding);
                    }
                }
            }
        }

        Ok(findings)
    }

    /// Count Rust source files
    fn count_rust_files(&self, project_path: &Path) -> TestResult<usize> {
        let mut count = 0;
        for entry in walkdir::WalkDir::new(project_path)
            .into_iter()
            .filter_map(|e| e.ok())
            .filter(|e| e.file_type().is_file())
        {
            if let Some(ext) = entry.path().extension() {
                if ext == "rs" {
                    count += 1;
                }
            }
        }
        Ok(count)
    }

    /// Check if scan results should fail the build
    pub fn should_fail_build(&self, results: &[SecurityScanResults]) -> bool {
        for result in results {
            for finding in &result.findings {
                match finding.severity {
                    Severity::Critical => return true,
                    Severity::High if self.config.fail_on_high => return true,
                    Severity::Medium if self.config.fail_on_medium => return true,
                    _ => continue,
                }
            }
        }
        false
    }
}

/// Security test utilities
pub mod utils {
    use super::*;

    /// Generate a security report in JSON format
    pub fn generate_security_report(results: &[SecurityScanResults]) -> TestResult<String> {
        let report = serde_json::to_string_pretty(results)?;
        Ok(report)
    }

    /// Generate a security report in markdown format
    pub fn generate_markdown_report(results: &[SecurityScanResults]) -> String {
        let mut report = String::new();
        report.push_str("# Security Scan Report\n\n");

        for result in results {
            report.push_str(&format!("## {} Scan\n\n", result.scan_type));
            report.push_str(&format!("- **Duration**: {}ms\n", result.scan_duration_ms));
            report.push_str(&format!("- **Files Scanned**: {}\n", result.scanned_files));
            report.push_str(&format!("- **Findings**: {}\n\n", result.findings.len()));

            if !result.findings.is_empty() {
                report.push_str("### Findings\n\n");
                for finding in &result.findings {
                    report.push_str(&format!("#### {} ({:?})\n\n", finding.title, finding.severity));
                    report.push_str(&format!("{}\n\n", finding.description));
                    
                    if let Some(file_path) = &finding.file_path {
                        report.push_str(&format!("**File**: {}", file_path));
                        if let Some(line_num) = finding.line_number {
                            report.push_str(&format!(" (line {})", line_num));
                        }
                        report.push_str("\n\n");
                    }
                    
                    if let Some(remediation) = &finding.remediation {
                        report.push_str(&format!("**Remediation**: {}\n\n", remediation));
                    }
                }
            }
        }

        report
    }
}

// Add required dependencies for the security module
use walkdir;
use regex;

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::TempDir;

    #[tokio::test]
    async fn test_security_tester_creation() {
        let config = SecurityConfig::default();
        let tester = SecurityTester::new(config);
        assert!(tester.config.fail_on_high);
    }

    #[tokio::test]
    async fn test_secret_detection() {
        let temp_dir = TempDir::new().unwrap();
        let test_file = temp_dir.path().join("test.rs");
        
        fs::write(&test_file, r#"
            const API_KEY: &str = "sk-1234567890abcdef1234567890abcdef";
            const PASSWORD: &str = "supersecretpassword123";
        "#).unwrap();

        let tester = SecurityTester::new(SecurityConfig::default());
        let results = tester.scan_secrets(temp_dir.path()).await.unwrap();
        
        assert!(!results.findings.is_empty());
        assert!(results.findings.iter().any(|f| f.title.contains("API key")));
    }

    #[test]
    fn test_should_fail_build() {
        let config = SecurityConfig::default();
        let tester = SecurityTester::new(config);
        
        let results = vec![SecurityScanResults {
            scan_type: "test".to_string(),
            findings: vec![SecurityFinding {
                id: "TEST-001".to_string(),
                title: "Test finding".to_string(),
                description: "Test description".to_string(),
                severity: Severity::High,
                scan_type: "test".to_string(),
                file_path: None,
                line_number: None,
                remediation: None,
            }],
            scan_duration_ms: 100,
            scanned_files: 1,
        }];
        
        assert!(tester.should_fail_build(&results));
    }
}