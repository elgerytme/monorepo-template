//! Test helper utilities and common functions

use std::time::Duration;
use tokio::time::{sleep, timeout};
use reqwest::Client;
use serde_json::Value;

/// HTTP client helper for API testing
pub struct ApiTestClient {
    client: Client,
    base_url: String,
    default_timeout: Duration,
}

impl ApiTestClient {
    pub fn new(base_url: &str) -> Self {
        Self {
            client: Client::new(),
            base_url: base_url.to_string(),
            default_timeout: Duration::from_secs(30),
        }
    }

    pub fn with_timeout(mut self, timeout_duration: Duration) -> Self {
        self.default_timeout = timeout_duration;
        self
    }

    /// Make a GET request
    pub async fn get(&self, path: &str) -> crate::TestResult<reqwest::Response> {
        let url = format!("{}{}", self.base_url, path);
        let response = timeout(
            self.default_timeout,
            self.client.get(&url).send()
        ).await??;
        Ok(response)
    }

    /// Make a POST request with JSON body
    pub async fn post_json<T: serde::Serialize>(
        &self,
        path: &str,
        body: &T,
    ) -> crate::TestResult<reqwest::Response> {
        let url = format!("{}{}", self.base_url, path);
        let response = timeout(
            self.default_timeout,
            self.client.post(&url).json(body).send()
        ).await??;
        Ok(response)
    }

    /// Make a PUT request with JSON body
    pub async fn put_json<T: serde::Serialize>(
        &self,
        path: &str,
        body: &T,
    ) -> crate::TestResult<reqwest::Response> {
        let url = format!("{}{}", self.base_url, path);
        let response = timeout(
            self.default_timeout,
            self.client.put(&url).json(body).send()
        ).await??;
        Ok(response)
    }

    /// Make a DELETE request
    pub async fn delete(&self, path: &str) -> crate::TestResult<reqwest::Response> {
        let url = format!("{}{}", self.base_url, path);
        let response = timeout(
            self.default_timeout,
            self.client.delete(&url).send()
        ).await??;
        Ok(response)
    }

    /// Wait for service to be healthy
    pub async fn wait_for_health(&self, health_path: &str, max_attempts: u32) -> crate::TestResult<()> {
        for attempt in 1..=max_attempts {
            match self.get(health_path).await {
                Ok(response) if response.status().is_success() => {
                    tracing::info!("Service is healthy after {} attempts", attempt);
                    return Ok(());
                }
                Ok(response) => {
                    tracing::warn!("Health check failed with status: {}", response.status());
                }
                Err(e) => {
                    tracing::warn!("Health check attempt {} failed: {}", attempt, e);
                }
            }
            
            if attempt < max_attempts {
                sleep(Duration::from_secs(2)).await;
            }
        }
        
        Err(format!("Service failed to become healthy after {} attempts", max_attempts).into())
    }
}

/// Database test helper
pub struct DatabaseTestHelper {
    pool: sqlx::PgPool,
}

impl DatabaseTestHelper {
    pub async fn new(database_url: &str) -> crate::TestResult<Self> {
        let pool = sqlx::postgres::PgPoolOptions::new()
            .max_connections(5)
            .connect(database_url)
            .await?;
        
        Ok(Self { pool })
    }

    /// Run database migrations
    pub async fn run_migrations(&self) -> crate::TestResult<()> {
        sqlx::migrate!("./migrations")
            .run(&self.pool)
            .await?;
        Ok(())
    }

    /// Execute a SQL query
    pub async fn execute(&self, query: &str) -> crate::TestResult<sqlx::postgres::PgQueryResult> {
        let result = sqlx::query(query)
            .execute(&self.pool)
            .await?;
        Ok(result)
    }

    /// Fetch a single row
    pub async fn fetch_one(&self, query: &str) -> crate::TestResult<sqlx::postgres::PgRow> {
        let row = sqlx::query(query)
            .fetch_one(&self.pool)
            .await?;
        Ok(row)
    }

    /// Fetch multiple rows
    pub async fn fetch_all(&self, query: &str) -> crate::TestResult<Vec<sqlx::postgres::PgRow>> {
        let rows = sqlx::query(query)
            .fetch_all(&self.pool)
            .await?;
        Ok(rows)
    }

    /// Clean up test data
    pub async fn cleanup(&self) -> crate::TestResult<()> {
        // Clean up in reverse dependency order
        let cleanup_queries = vec![
            "DELETE FROM user_sessions WHERE user_id LIKE 'test-%'",
            "DELETE FROM users WHERE email LIKE '%@example.com'",
            "DELETE FROM test_data",
        ];
        
        for query in cleanup_queries {
            self.execute(query).await.ok(); // Ignore errors for cleanup
        }
        
        Ok(())
    }

    /// Get the database pool for advanced operations
    pub fn pool(&self) -> &sqlx::PgPool {
        &self.pool
    }
}

/// File system test helper
pub struct FileSystemTestHelper {
    temp_dir: tempfile::TempDir,
}

impl FileSystemTestHelper {
    pub fn new() -> crate::TestResult<Self> {
        let temp_dir = tempfile::tempdir()?;
        Ok(Self { temp_dir })
    }

    /// Get the temporary directory path
    pub fn temp_path(&self) -> &std::path::Path {
        self.temp_dir.path()
    }

    /// Create a test file with content
    pub async fn create_file(&self, name: &str, content: &str) -> crate::TestResult<std::path::PathBuf> {
        let file_path = self.temp_path().join(name);
        tokio::fs::write(&file_path, content).await?;
        Ok(file_path)
    }

    /// Create a test directory
    pub async fn create_dir(&self, name: &str) -> crate::TestResult<std::path::PathBuf> {
        let dir_path = self.temp_path().join(name);
        tokio::fs::create_dir_all(&dir_path).await?;
        Ok(dir_path)
    }

    /// Read file content
    pub async fn read_file(&self, name: &str) -> crate::TestResult<String> {
        let file_path = self.temp_path().join(name);
        let content = tokio::fs::read_to_string(file_path).await?;
        Ok(content)
    }

    /// Check if file exists
    pub async fn file_exists(&self, name: &str) -> bool {
        let file_path = self.temp_path().join(name);
        tokio::fs::metadata(file_path).await.is_ok()
    }
}

impl Default for FileSystemTestHelper {
    fn default() -> Self {
        Self::new().expect("Failed to create temporary directory")
    }
}

/// Retry helper for flaky operations
pub async fn retry_async<F, Fut, T, E>(
    mut operation: F,
    max_attempts: u32,
    delay: Duration,
) -> Result<T, E>
where
    F: FnMut() -> Fut,
    Fut: std::future::Future<Output = Result<T, E>>,
    E: std::fmt::Debug,
{
    let mut last_error = None;
    
    for attempt in 1..=max_attempts {
        match operation().await {
            Ok(result) => return Ok(result),
            Err(error) => {
                tracing::warn!("Attempt {} failed: {:?}", attempt, error);
                last_error = Some(error);
                
                if attempt < max_attempts {
                    sleep(delay).await;
                }
            }
        }
    }
    
    Err(last_error.unwrap())
}

/// Assert that a condition becomes true within a timeout
pub async fn assert_eventually<F>(
    mut condition: F,
    timeout_duration: Duration,
    check_interval: Duration,
    message: &str,
) -> crate::TestResult<()>
where
    F: FnMut() -> bool,
{
    let start = std::time::Instant::now();
    
    while start.elapsed() < timeout_duration {
        if condition() {
            return Ok(());
        }
        sleep(check_interval).await;
    }
    
    Err(format!("Condition not met within timeout: {}", message).into())
}

/// Mock HTTP server for testing
pub struct MockHttpServer {
    server: wiremock::MockServer,
}

impl MockHttpServer {
    pub async fn start() -> Self {
        let server = wiremock::MockServer::start().await;
        Self { server }
    }

    pub fn uri(&self) -> String {
        self.server.uri()
    }

    pub async fn mock_get(&self, path: &str, response_body: &str, status: u16) {
        use wiremock::{Mock, ResponseTemplate};
        use wiremock::matchers::{method, path as path_matcher};
        
        Mock::given(method("GET"))
            .and(path_matcher(path))
            .respond_with(ResponseTemplate::new(status).set_body_string(response_body))
            .mount(&self.server)
            .await;
    }

    pub async fn mock_post(&self, path: &str, response_body: &str, status: u16) {
        use wiremock::{Mock, ResponseTemplate};
        use wiremock::matchers::{method, path as path_matcher};
        
        Mock::given(method("POST"))
            .and(path_matcher(path))
            .respond_with(ResponseTemplate::new(status).set_body_string(response_body))
            .mount(&self.server)
            .await;
    }

    pub async fn verify(&self) {
        // Verify all mocks were called as expected
        // This is handled automatically by wiremock
    }
}

/// Test timing utilities
pub struct TestTimer {
    start: std::time::Instant,
}

impl TestTimer {
    pub fn start() -> Self {
        Self {
            start: std::time::Instant::now(),
        }
    }

    pub fn elapsed(&self) -> Duration {
        self.start.elapsed()
    }

    pub fn assert_elapsed_less_than(&self, max_duration: Duration) -> crate::TestResult<()> {
        let elapsed = self.elapsed();
        if elapsed > max_duration {
            return Err(format!(
                "Operation took too long: {:?} > {:?}",
                elapsed, max_duration
            ).into());
        }
        Ok(())
    }

    pub fn assert_elapsed_more_than(&self, min_duration: Duration) -> crate::TestResult<()> {
        let elapsed = self.elapsed();
        if elapsed < min_duration {
            return Err(format!(
                "Operation completed too quickly: {:?} < {:?}",
                elapsed, min_duration
            ).into());
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::integration_test;

    #[test]
    fn test_api_client_creation() {
        let client = ApiTestClient::new("http://localhost:8080");
        assert_eq!(client.base_url, "http://localhost:8080");
    }

    integration_test!(test_file_system_helper, async {
        let fs_helper = FileSystemTestHelper::new()?;
        
        // Create a test file
        let file_path = fs_helper.create_file("test.txt", "Hello, World!").await?;
        assert!(file_path.exists());
        
        // Read the file content
        let content = fs_helper.read_file("test.txt").await?;
        assert_eq!(content, "Hello, World!");
        
        // Check file existence
        assert!(fs_helper.file_exists("test.txt").await);
        assert!(!fs_helper.file_exists("nonexistent.txt").await);
        
        Ok(())
    });

    integration_test!(test_retry_helper, async {
        let mut attempt_count = 0;
        
        let result = retry_async(
            || {
                attempt_count += 1;
                async move {
                    if attempt_count < 3 {
                        Err("Not ready yet")
                    } else {
                        Ok("Success!")
                    }
                }
            },
            5,
            Duration::from_millis(10),
        ).await;
        
        assert_eq!(result, Ok("Success!"));
        assert_eq!(attempt_count, 3);
        
        Ok(())
    });

    integration_test!(test_mock_http_server, async {
        let mock_server = MockHttpServer::start().await;
        
        // Set up a mock endpoint
        mock_server.mock_get("/test", r#"{"message": "Hello, World!"}"#, 200).await;
        
        // Test the mock endpoint
        let client = ApiTestClient::new(&mock_server.uri());
        let response = client.get("/test").await?;
        
        assert_eq!(response.status(), 200);
        let body: Value = response.json().await?;
        assert_eq!(body["message"], "Hello, World!");
        
        Ok(())
    });

    #[test]
    fn test_timer() {
        let timer = TestTimer::start();
        std::thread::sleep(Duration::from_millis(10));
        
        assert!(timer.elapsed() >= Duration::from_millis(10));
        assert!(timer.assert_elapsed_more_than(Duration::from_millis(5)).is_ok());
    }
}