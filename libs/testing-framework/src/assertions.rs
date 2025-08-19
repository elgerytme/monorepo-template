//! Enhanced assertion utilities for comprehensive testing

use crate::TestResult;
use serde::Serialize;
use std::fmt::Debug;
use std::time::Duration;

/// Enhanced assertion macros and utilities
pub mod enhanced {
    /// Assert that a value is within a tolerance range
    #[macro_export]
    macro_rules! assert_approx_eq {
        ($left:expr, $right:expr, $tolerance:expr) => {
            let diff = ($left - $right).abs();
            if diff > $tolerance {
                panic!(
                    "assertion failed: `(left ≈ right)`\n  left: `{:?}`,\n right: `{:?}`,\n tolerance: `{:?}`,\n difference: `{:?}`",
                    $left, $right, $tolerance, diff
                );
            }
        };
    }

    /// Assert that a duration is within expected bounds
    #[macro_export]
    macro_rules! assert_duration_between {
        ($duration:expr, $min:expr, $max:expr) => {
            if $duration < $min || $duration > $max {
                panic!(
                    "assertion failed: duration not in range\n  duration: `{:?}`,\n  min: `{:?}`,\n  max: `{:?}`",
                    $duration, $min, $max
                );
            }
        };
    }

    /// Assert that a collection contains all expected items
    #[macro_export]
    macro_rules! assert_contains_all {
        ($collection:expr, $expected:expr) => {
            for item in $expected {
                if !$collection.contains(&item) {
                    panic!(
                        "assertion failed: collection does not contain expected item\n  item: `{:?}`,\n  collection: `{:?}`",
                        item, $collection
                    );
                }
            }
        };
    }

    /// Assert that a string matches a regex pattern
    #[macro_export]
    macro_rules! assert_matches_regex {
        ($text:expr, $pattern:expr) => {
            let regex = regex::Regex::new($pattern).expect("Invalid regex pattern");
            if !regex.is_match($text) {
                panic!(
                    "assertion failed: text does not match regex\n  text: `{:?}`,\n  pattern: `{:?}`",
                    $text, $pattern
                );
            }
        };
    }
}

/// HTTP response assertions
pub mod http {
    use super::*;
    use reqwest::Response;
    use serde_json::Value;

    /// Assert HTTP response status
    pub async fn assert_status(response: &Response, expected_status: u16) -> TestResult {
        let actual_status = response.status().as_u16();
        if actual_status != expected_status {
            return Err(format!(
                "Expected status {}, got {}",
                expected_status, actual_status
            ).into());
        }
        Ok(())
    }

    /// Assert HTTP response contains header
    pub async fn assert_header_exists(response: &Response, header_name: &str) -> TestResult {
        if !response.headers().contains_key(header_name) {
            return Err(format!("Expected header '{}' not found", header_name).into());
        }
        Ok(())
    }

    /// Assert HTTP response header value
    pub async fn assert_header_value(
        response: &Response,
        header_name: &str,
        expected_value: &str,
    ) -> TestResult {
        let header_value = response
            .headers()
            .get(header_name)
            .ok_or_else(|| format!("Header '{}' not found", header_name))?
            .to_str()
            .map_err(|_| format!("Header '{}' contains invalid UTF-8", header_name))?;

        if header_value != expected_value {
            return Err(format!(
                "Expected header '{}' to be '{}', got '{}'",
                header_name, expected_value, header_value
            ).into());
        }
        Ok(())
    }

    /// Assert JSON response structure
    pub async fn assert_json_structure(
        response: Response,
        expected_keys: &[&str],
    ) -> TestResult<Value> {
        let json: Value = response.json().await?;
        
        if let Value::Object(obj) = &json {
            for key in expected_keys {
                if !obj.contains_key(*key) {
                    return Err(format!("Expected JSON key '{}' not found", key).into());
                }
            }
        } else {
            return Err("Response is not a JSON object".into());
        }
        
        Ok(json)
    }

    /// Assert JSON response value
    pub async fn assert_json_value(
        response: Response,
        json_path: &str,
        expected_value: &Value,
    ) -> TestResult {
        let json: Value = response.json().await?;
        let actual_value = json_path_value(&json, json_path)?;
        
        if actual_value != *expected_value {
            return Err(format!(
                "Expected JSON path '{}' to be '{:?}', got '{:?}'",
                json_path, expected_value, actual_value
            ).into());
        }
        
        Ok(())
    }

    /// Simple JSON path extraction (supports dot notation)
    fn json_path_value(json: &Value, path: &str) -> TestResult<Value> {
        let parts: Vec<&str> = path.split('.').collect();
        let mut current = json;
        
        for part in parts {
            match current {
                Value::Object(obj) => {
                    current = obj.get(part)
                        .ok_or_else(|| format!("JSON path '{}' not found", part))?;
                }
                Value::Array(arr) => {
                    let index: usize = part.parse()
                        .map_err(|_| format!("Invalid array index '{}'", part))?;
                    current = arr.get(index)
                        .ok_or_else(|| format!("Array index '{}' out of bounds", index))?;
                }
                _ => return Err(format!("Cannot navigate path '{}' in non-object/array", part).into()),
            }
        }
        
        Ok(current.clone())
    }
}

/// Database assertions
pub mod database {
    use super::*;
    use sqlx::{PgPool, Row};

    /// Assert that a table has expected row count
    pub async fn assert_row_count(
        pool: &PgPool,
        table_name: &str,
        expected_count: i64,
    ) -> TestResult {
        let row = sqlx::query(&format!("SELECT COUNT(*) as count FROM {}", table_name))
            .fetch_one(pool)
            .await?;
        
        let actual_count: i64 = row.get("count");
        
        if actual_count != expected_count {
            return Err(format!(
                "Expected {} rows in table '{}', got {}",
                expected_count, table_name, actual_count
            ).into());
        }
        
        Ok(())
    }

    /// Assert that a record exists with specific conditions
    pub async fn assert_record_exists(
        pool: &PgPool,
        table_name: &str,
        conditions: &[(&str, &str)],
    ) -> TestResult {
        let mut query = format!("SELECT COUNT(*) as count FROM {} WHERE", table_name);
        let mut first = true;
        
        for (column, _) in conditions {
            if !first {
                query.push_str(" AND");
            }
            query.push_str(&format!(" {} = $", column));
            first = false;
        }
        
        // This is a simplified version - in production, use proper parameter binding
        let count_query = format!(
            "SELECT COUNT(*) as count FROM {} WHERE {}",
            table_name,
            conditions
                .iter()
                .enumerate()
                .map(|(i, (col, val))| format!("{} = '{}'", col, val))
                .collect::<Vec<_>>()
                .join(" AND ")
        );
        
        let row = sqlx::query(&count_query).fetch_one(pool).await?;
        let count: i64 = row.get("count");
        
        if count == 0 {
            return Err(format!(
                "No records found in table '{}' matching conditions: {:?}",
                table_name, conditions
            ).into());
        }
        
        Ok(())
    }

    /// Assert that a record does not exist
    pub async fn assert_record_not_exists(
        pool: &PgPool,
        table_name: &str,
        conditions: &[(&str, &str)],
    ) -> TestResult {
        match assert_record_exists(pool, table_name, conditions).await {
            Ok(_) => Err(format!(
                "Record unexpectedly found in table '{}' matching conditions: {:?}",
                table_name, conditions
            ).into()),
            Err(_) => Ok(()),
        }
    }
}

/// Performance assertions
pub mod performance {
    use super::*;
    use std::time::Instant;

    /// Assert that an operation completes within a time limit
    pub async fn assert_completes_within<F, Fut, T>(
        operation: F,
        time_limit: Duration,
    ) -> TestResult<T>
    where
        F: FnOnce() -> Fut,
        Fut: std::future::Future<Output = TestResult<T>>,
    {
        let start = Instant::now();
        let result = operation().await?;
        let elapsed = start.elapsed();
        
        if elapsed > time_limit {
            return Err(format!(
                "Operation took {:?}, expected to complete within {:?}",
                elapsed, time_limit
            ).into());
        }
        
        Ok(result)
    }

    /// Assert that throughput meets minimum requirements
    pub fn assert_throughput(
        operations: usize,
        duration: Duration,
        min_ops_per_second: f64,
    ) -> TestResult {
        let actual_ops_per_second = operations as f64 / duration.as_secs_f64();
        
        if actual_ops_per_second < min_ops_per_second {
            return Err(format!(
                "Throughput {} ops/sec is below minimum {} ops/sec",
                actual_ops_per_second, min_ops_per_second
            ).into());
        }
        
        Ok(())
    }

    /// Assert that memory usage is within limits
    pub fn assert_memory_usage(actual_bytes: usize, max_bytes: usize) -> TestResult {
        if actual_bytes > max_bytes {
            return Err(format!(
                "Memory usage {} bytes exceeds limit {} bytes",
                actual_bytes, max_bytes
            ).into());
        }
        
        Ok(())
    }
}

/// File system assertions
pub mod filesystem {
    use super::*;
    use std::path::Path;
    use std::fs;

    /// Assert that a file exists
    pub fn assert_file_exists(path: &Path) -> TestResult {
        if !path.exists() {
            return Err(format!("File does not exist: {}", path.display()).into());
        }
        
        if !path.is_file() {
            return Err(format!("Path is not a file: {}", path.display()).into());
        }
        
        Ok(())
    }

    /// Assert that a directory exists
    pub fn assert_dir_exists(path: &Path) -> TestResult {
        if !path.exists() {
            return Err(format!("Directory does not exist: {}", path.display()).into());
        }
        
        if !path.is_dir() {
            return Err(format!("Path is not a directory: {}", path.display()).into());
        }
        
        Ok(())
    }

    /// Assert file content matches expected
    pub fn assert_file_content(path: &Path, expected_content: &str) -> TestResult {
        assert_file_exists(path)?;
        
        let actual_content = fs::read_to_string(path)?;
        
        if actual_content != expected_content {
            return Err(format!(
                "File content mismatch in {}\nExpected:\n{}\nActual:\n{}",
                path.display(),
                expected_content,
                actual_content
            ).into());
        }
        
        Ok(())
    }

    /// Assert file contains substring
    pub fn assert_file_contains(path: &Path, substring: &str) -> TestResult {
        assert_file_exists(path)?;
        
        let content = fs::read_to_string(path)?;
        
        if !content.contains(substring) {
            return Err(format!(
                "File {} does not contain expected substring: '{}'",
                path.display(),
                substring
            ).into());
        }
        
        Ok(())
    }
}

/// Serialization assertions
pub mod serialization {
    use super::*;
    use serde_json;

    /// Assert that an object can be serialized and deserialized
    pub fn assert_roundtrip_serialization<T>(value: &T) -> TestResult
    where
        T: Serialize + for<'de> serde::Deserialize<'de> + PartialEq + Debug,
    {
        let serialized = serde_json::to_string(value)?;
        let deserialized: T = serde_json::from_str(&serialized)?;
        
        if *value != deserialized {
            return Err(format!(
                "Roundtrip serialization failed\nOriginal: {:?}\nDeserialized: {:?}",
                value, deserialized
            ).into());
        }
        
        Ok(())
    }

    /// Assert JSON schema compliance (simplified)
    pub fn assert_json_schema(json: &serde_json::Value, required_fields: &[&str]) -> TestResult {
        if let serde_json::Value::Object(obj) = json {
            for field in required_fields {
                if !obj.contains_key(*field) {
                    return Err(format!("Required field '{}' missing from JSON", field).into());
                }
            }
        } else {
            return Err("JSON is not an object".into());
        }
        
        Ok(())
    }
}

// Add regex dependency
use regex;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_approx_eq_macro() {
        assert_approx_eq!(1.0, 1.1, 0.2);
    }

    #[test]
    #[should_panic]
    fn test_approx_eq_macro_fails() {
        assert_approx_eq!(1.0, 2.0, 0.5);
    }

    #[test]
    fn test_duration_between_macro() {
        let duration = Duration::from_millis(500);
        assert_duration_between!(duration, Duration::from_millis(400), Duration::from_millis(600));
    }

    #[test]
    fn test_contains_all_macro() {
        let collection = vec![1, 2, 3, 4, 5];
        let expected = vec![2, 4];
        assert_contains_all!(collection, expected);
    }

    #[test]
    fn test_regex_match_macro() {
        assert_matches_regex!("test@example.com", r"^[^@]+@[^@]+\.[^@]+$");
    }

    #[tokio::test]
    async fn test_performance_assertions() {
        let result = performance::assert_completes_within(
            || async { 
                tokio::time::sleep(Duration::from_millis(10)).await;
                Ok(42)
            },
            Duration::from_millis(100),
        ).await;
        
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), 42);
    }

    #[test]
    fn test_throughput_assertion() {
        let result = performance::assert_throughput(
            100,
            Duration::from_secs(1),
            50.0,
        );
        assert!(result.is_ok());
    }

    #[test]
    fn test_serialization_roundtrip() {
        use serde::{Deserialize, Serialize};
        
        #[derive(Serialize, Deserialize, PartialEq, Debug)]
        struct TestStruct {
            name: String,
            value: i32,
        }
        
        let test_obj = TestStruct {
            name: "test".to_string(),
            value: 42,
        };
        
        let result = serialization::assert_roundtrip_serialization(&test_obj);
        assert!(result.is_ok());
    }
}