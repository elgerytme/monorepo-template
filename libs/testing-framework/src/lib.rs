//! Comprehensive testing framework for the monorepo
//! 
//! This crate provides utilities and patterns for:
//! - Unit testing with advanced assertions
//! - Integration testing with testcontainers
//! - Performance testing with benchmarking
//! - Security testing automation

pub mod unit;
pub mod integration;
pub mod performance;
pub mod security;
pub mod fixtures;
pub mod assertions;

// Re-export commonly used testing utilities
pub use tokio_test;
pub use proptest;
pub use fake;
pub use wiremock;

#[cfg(feature = "integration")]
pub use testcontainers;

#[cfg(feature = "performance")]
pub use criterion;

/// Common test result type
pub type TestResult<T = ()> = Result<T, Box<dyn std::error::Error + Send + Sync>>;

/// Test configuration for different environments
#[derive(Debug, Clone)]
pub struct TestConfig {
    pub environment: TestEnvironment,
    pub timeout_seconds: u64,
    pub retry_count: u32,
    pub parallel_execution: bool,
}

#[derive(Debug, Clone, PartialEq)]
pub enum TestEnvironment {
    Unit,
    Integration,
    Performance,
    Security,
    CI,
}

impl Default for TestConfig {
    fn default() -> Self {
        Self {
            environment: TestEnvironment::Unit,
            timeout_seconds: 30,
            retry_count: 1,
            parallel_execution: true,
        }
    }
}

impl TestConfig {
    pub fn ci() -> Self {
        Self {
            environment: TestEnvironment::CI,
            timeout_seconds: 120,
            retry_count: 2,
            parallel_execution: true,
        }
    }

    pub fn integration() -> Self {
        Self {
            environment: TestEnvironment::Integration,
            timeout_seconds: 60,
            retry_count: 1,
            parallel_execution: false,
        }
    }

    pub fn performance() -> Self {
        Self {
            environment: TestEnvironment::Performance,
            timeout_seconds: 300,
            retry_count: 0,
            parallel_execution: false,
        }
    }
}