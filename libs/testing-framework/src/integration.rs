//! Integration testing framework with testcontainers

#[cfg(feature = "integration")]
use testcontainers::{clients::Cli, Container, Docker, Image};
#[cfg(feature = "integration")]
use testcontainers_modules::{postgres::Postgres, redis::Redis};
use crate::TestResult;
use std::collections::HashMap;
use tokio::time::{sleep, Duration};

/// Integration test environment manager
pub struct TestEnvironment {
    #[cfg(feature = "integration")]
    docker: Cli,
    containers: HashMap<String, ContainerInfo>,
}

struct ContainerInfo {
    #[cfg(feature = "integration")]
    container: Container<'static, dyn Image>,
    host: String,
    port: u16,
}

impl TestEnvironment {
    pub fn new() -> Self {
        Self {
            #[cfg(feature = "integration")]
            docker: Cli::default(),
            containers: HashMap::new(),
        }
    }

    /// Start a PostgreSQL container for testing
    #[cfg(feature = "integration")]
    pub async fn start_postgres(&mut self, name: &str) -> TestResult<(String, u16)> {
        let postgres = Postgres::default();
        let container = self.docker.run(postgres);
        let host = "localhost".to_string();
        let port = container.get_host_port_ipv4(5432);

        // Wait for PostgreSQL to be ready
        self.wait_for_postgres(&host, port).await?;

        self.containers.insert(name.to_string(), ContainerInfo {
            container,
            host: host.clone(),
            port,
        });

        Ok((host, port))
    }

    /// Start a Redis container for testing
    #[cfg(feature = "integration")]
    pub async fn start_redis(&mut self, name: &str) -> TestResult<(String, u16)> {
        let redis = Redis::default();
        let container = self.docker.run(redis);
        let host = "localhost".to_string();
        let port = container.get_host_port_ipv4(6379);

        // Wait for Redis to be ready
        self.wait_for_redis(&host, port).await?;

        self.containers.insert(name.to_string(), ContainerInfo {
            container,
            host: host.clone(),
            port,
        });

        Ok((host, port))
    }

    /// Get connection details for a named container
    pub fn get_container(&self, name: &str) -> Option<(String, u16)> {
        self.containers.get(name).map(|info| (info.host.clone(), info.port))
    }

    /// Wait for PostgreSQL to be ready
    async fn wait_for_postgres(&self, host: &str, port: u16) -> TestResult {
        use sqlx::postgres::PgPoolOptions;
        
        let database_url = format!("postgres://postgres:postgres@{}:{}/postgres", host, port);
        let mut attempts = 0;
        const MAX_ATTEMPTS: u32 = 30;

        while attempts < MAX_ATTEMPTS {
            match PgPoolOptions::new()
                .max_connections(1)
                .connect(&database_url)
                .await
            {
                Ok(_) => return Ok(()),
                Err(_) => {
                    attempts += 1;
                    sleep(Duration::from_secs(1)).await;
                }
            }
        }

        Err(format!("PostgreSQL not ready after {} attempts", MAX_ATTEMPTS).into())
    }

    /// Wait for Redis to be ready
    async fn wait_for_redis(&self, host: &str, port: u16) -> TestResult {
        use std::net::TcpStream;
        use std::time::Duration as StdDuration;

        let mut attempts = 0;
        const MAX_ATTEMPTS: u32 = 30;

        while attempts < MAX_ATTEMPTS {
            match TcpStream::connect_timeout(
                &format!("{}:{}", host, port).parse().unwrap(),
                StdDuration::from_secs(1),
            ) {
                Ok(_) => return Ok(()),
                Err(_) => {
                    attempts += 1;
                    sleep(Duration::from_secs(1)).await;
                }
            }
        }

        Err(format!("Redis not ready after {} attempts", MAX_ATTEMPTS).into())
    }
}

/// Database test utilities
pub mod database {
    use super::*;
    use sqlx::{PgPool, Row};

    /// Create a test database with migrations
    pub async fn setup_test_database(database_url: &str) -> TestResult<PgPool> {
        let pool = sqlx::postgres::PgPoolOptions::new()
            .max_connections(5)
            .connect(database_url)
            .await?;

        // Run basic schema setup
        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS test_users (
                id SERIAL PRIMARY KEY,
                name VARCHAR NOT NULL,
                email VARCHAR UNIQUE NOT NULL,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
            )
            "#,
        )
        .execute(&pool)
        .await?;

        Ok(pool)
    }

    /// Clean up test data
    pub async fn cleanup_test_database(pool: &PgPool) -> TestResult {
        sqlx::query("TRUNCATE TABLE test_users CASCADE")
            .execute(pool)
            .await?;
        Ok(())
    }

    /// Insert test user
    pub async fn insert_test_user(
        pool: &PgPool,
        name: &str,
        email: &str,
    ) -> TestResult<i32> {
        let row = sqlx::query("INSERT INTO test_users (name, email) VALUES ($1, $2) RETURNING id")
            .bind(name)
            .bind(email)
            .fetch_one(pool)
            .await?;

        Ok(row.get("id"))
    }
}

/// HTTP service testing utilities
pub mod http {
    use super::*;
    use reqwest::Client;
    use serde_json::Value;
    use std::time::Duration;

    /// HTTP test client with retry capabilities
    pub struct TestClient {
        client: Client,
        base_url: String,
        timeout: Duration,
    }

    impl TestClient {
        pub fn new(base_url: String) -> Self {
            Self {
                client: Client::new(),
                base_url,
                timeout: Duration::from_secs(30),
            }
        }

        pub async fn get(&self, path: &str) -> TestResult<reqwest::Response> {
            let url = format!("{}{}", self.base_url, path);
            let response = self.client
                .get(&url)
                .timeout(self.timeout)
                .send()
                .await?;
            Ok(response)
        }

        pub async fn post_json(&self, path: &str, body: &Value) -> TestResult<reqwest::Response> {
            let url = format!("{}{}", self.base_url, path);
            let response = self.client
                .post(&url)
                .json(body)
                .timeout(self.timeout)
                .send()
                .await?;
            Ok(response)
        }

        /// Wait for service to be healthy
        pub async fn wait_for_health(&self, health_path: &str) -> TestResult {
            let mut attempts = 0;
            const MAX_ATTEMPTS: u32 = 30;

            while attempts < MAX_ATTEMPTS {
                match self.get(health_path).await {
                    Ok(response) if response.status().is_success() => return Ok(()),
                    _ => {
                        attempts += 1;
                        sleep(Duration::from_secs(1)).await;
                    }
                }
            }

            Err(format!("Service not healthy after {} attempts", MAX_ATTEMPTS).into())
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_environment_creation() {
        let env = TestEnvironment::new();
        assert!(env.containers.is_empty());
    }

    #[cfg(feature = "integration")]
    #[tokio::test]
    async fn test_postgres_container() {
        let mut env = TestEnvironment::new();
        let result = env.start_postgres("test_db").await;
        assert!(result.is_ok());
        
        let (host, port) = result.unwrap();
        assert_eq!(host, "localhost");
        assert!(port > 0);
    }
}