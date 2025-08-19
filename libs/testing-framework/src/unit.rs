//! Unit testing utilities and patterns

use crate::{TestResult, TestConfig};
use std::time::Duration;
use tokio::time::timeout;

/// Enhanced test runner with timeout and retry capabilities
pub async fn run_test_with_config<F, Fut>(
    test_fn: F,
    config: TestConfig,
) -> TestResult
where
    F: Fn() -> Fut + Send + Sync,
    Fut: std::future::Future<Output = TestResult> + Send,
{
    let mut attempts = 0;
    let max_attempts = config.retry_count + 1;

    while attempts < max_attempts {
        attempts += 1;

        let result = timeout(
            Duration::from_secs(config.timeout_seconds),
            test_fn(),
        ).await;

        match result {
            Ok(Ok(())) => return Ok(()),
            Ok(Err(e)) if attempts < max_attempts => {
                eprintln!("Test attempt {} failed: {}", attempts, e);
                continue;
            }
            Ok(Err(e)) => return Err(e),
            Err(_) => {
                let timeout_err = format!(
                    "Test timed out after {} seconds (attempt {}/{})",
                    config.timeout_seconds, attempts, max_attempts
                );
                if attempts < max_attempts {
                    eprintln!("{}", timeout_err);
                    continue;
                }
                return Err(timeout_err.into());
            }
        }
    }

    unreachable!()
}

/// Macro for creating parameterized tests
#[macro_export]
macro_rules! parameterized_test {
    ($test_name:ident, $test_cases:expr, $test_fn:expr) => {
        #[tokio::test]
        async fn $test_name() {
            for (i, case) in $test_cases.iter().enumerate() {
                let result = $test_fn(case).await;
                if let Err(e) = result {
                    panic!("Test case {} failed: {}", i, e);
                }
            }
        }
    };
}

/// Property-based testing utilities
pub mod property {
    use proptest::prelude::*;
    use crate::TestResult;

    /// Run a property-based test with custom configuration
    pub fn test_property<T, F>(
        strategy: impl Strategy<Value = T>,
        test_fn: F,
    ) -> TestResult
    where
        F: Fn(T) -> TestResult,
        T: std::fmt::Debug,
    {
        let config = ProptestConfig {
            cases: 1000,
            max_shrink_iters: 10000,
            ..ProptestConfig::default()
        };

        proptest!(config, |(value in strategy)| {
            test_fn(value)?;
        });

        Ok(())
    }
}

/// Snapshot testing utilities
pub mod snapshot {
    use serde::Serialize;
    use std::path::Path;

    /// Compare a serializable value against a snapshot file
    pub fn assert_snapshot<T: Serialize>(
        snapshot_name: &str,
        value: &T,
    ) -> crate::TestResult {
        let serialized = serde_json::to_string_pretty(value)?;
        let snapshot_path = format!("tests/snapshots/{}.json", snapshot_name);
        
        if Path::new(&snapshot_path).exists() {
            let expected = std::fs::read_to_string(&snapshot_path)?;
            if serialized != expected {
                return Err(format!(
                    "Snapshot mismatch for '{}'\nExpected:\n{}\nActual:\n{}",
                    snapshot_name, expected, serialized
                ).into());
            }
        } else {
            // Create snapshot directory if it doesn't exist
            std::fs::create_dir_all("tests/snapshots")?;
            std::fs::write(&snapshot_path, &serialized)?;
            println!("Created new snapshot: {}", snapshot_path);
        }

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_run_with_config_success() {
        let config = TestConfig::default();
        let result = run_test_with_config(|| async { Ok(()) }, config).await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn test_run_with_config_retry() {
        let config = TestConfig {
            retry_count: 2,
            ..TestConfig::default()
        };
        
        let mut attempt_count = std::sync::Arc::new(std::sync::atomic::AtomicU32::new(0));
        let attempt_count_clone = attempt_count.clone();
        
        let result = run_test_with_config(move || {
            let count = attempt_count_clone.clone();
            async move {
                let current = count.fetch_add(1, std::sync::atomic::Ordering::SeqCst);
                if current < 1 {
                    Err("Simulated failure".into())
                } else {
                    Ok(())
                }
            }
        }, config).await;
        
        assert!(result.is_ok());
        assert_eq!(attempt_count.load(std::sync::atomic::Ordering::SeqCst), 2);
    }
}