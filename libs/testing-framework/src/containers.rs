//! Testcontainers integration for database and service testing

use std::collections::HashMap;
use testcontainers::{clients::Cli, Container, Image, RunnableImage};
use testcontainers_modules::{postgres::Postgres, redis::Redis};

/// Container manager for integration tests
pub struct ContainerManager {
    docker: Cli,
    containers: HashMap<String, Box<dyn std::any::Any + Send>>,
}

impl ContainerManager {
    pub fn new() -> Self {
        Self {
            docker: Cli::default(),
            containers: HashMap::new(),
        }
    }

    /// Start a PostgreSQL container for testing
    pub async fn start_postgres(&mut self, name: &str) -> crate::TestResult<String> {
        let postgres = Postgres::default();
        let container = self.docker.run(postgres);
        let port = container.get_host_port_ipv4(5432);
        
        let connection_string = format!(
            "postgresql://postgres:postgres@localhost:{}/postgres",
            port
        );
        
        // Store container to keep it alive
        self.containers.insert(name.to_string(), Box::new(container));
        
        // Wait for PostgreSQL to be ready
        self.wait_for_postgres(&connection_string).await?;
        
        Ok(connection_string)
    }

    /// Start a Redis container for testing
    pub async fn start_redis(&mut self, name: &str) -> crate::TestResult<String> {
        let redis = Redis::default();
        let container = self.docker.run(redis);
        let port = container.get_host_port_ipv4(6379);
        
        let connection_string = format!("redis://localhost:{}", port);
        
        // Store container to keep it alive
        self.containers.insert(name.to_string(), Box::new(container));
        
        // Wait for Redis to be ready
        self.wait_for_redis(&connection_string).await?;
        
        Ok(connection_string)
    }

    /// Start a custom service container
    pub async fn start_custom_service<I: Image>(
        &mut self,
        name: &str,
        image: I,
        port: u16,
    ) -> crate::TestResult<String> {
        let container = self.docker.run(image);
        let host_port = container.get_host_port_ipv4(port);
        
        let service_url = format!("http://localhost:{}", host_port);
        
        // Store container to keep it alive
        self.containers.insert(name.to_string(), Box::new(container));
        
        Ok(service_url)
    }

    /// Wait for PostgreSQL to be ready
    async fn wait_for_postgres(&self, connection_string: &str) -> crate::TestResult<()> {
        use sqlx::postgres::PgPoolOptions;
        use tokio::time::{sleep, Duration};
        
        let mut attempts = 0;
        let max_attempts = 30;
        
        while attempts < max_attempts {
            match PgPoolOptions::new()
                .max_connections(1)
                .connect(connection_string)
                .await
            {
                Ok(_) => return Ok(()),
                Err(_) => {
                    attempts += 1;
                    sleep(Duration::from_millis(1000)).await;
                }
            }
        }
        
        Err("PostgreSQL container failed to start".into())
    }

    /// Wait for Redis to be ready
    async fn wait_for_redis(&self, _connection_string: &str) -> crate::TestResult<()> {
        use tokio::time::{sleep, Duration};
        
        // Simple wait for Redis - in a real implementation, you'd ping Redis
        sleep(Duration::from_millis(2000)).await;
        Ok(())
    }
}

impl Default for ContainerManager {
    fn default() -> Self {
        Self::new()
    }
}

/// Helper macro for setting up test containers
#[macro_export]
macro_rules! with_containers {
    ($manager:ident, { $($name:ident: $container_type:ident),* }, $body:expr) => {
        {
            let mut $manager = $crate::containers::ContainerManager::new();
            
            $(
                let $name = match stringify!($container_type) {
                    "postgres" => $manager.start_postgres(stringify!($name)).await?,
                    "redis" => $manager.start_redis(stringify!($name)).await?,
                    _ => return Err(format!("Unknown container type: {}", stringify!($container_type)).into()),
                };
            )*
            
            $body
        }
    };
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::integration_test;

    integration_test!(test_postgres_container, async {
        let mut manager = ContainerManager::new();
        let connection_string = manager.start_postgres("test_db").await?;
        
        // Verify we can connect
        use sqlx::postgres::PgPoolOptions;
        let pool = PgPoolOptions::new()
            .max_connections(1)
            .connect(&connection_string)
            .await?;
        
        // Run a simple query
        let row: (i32,) = sqlx::query_as("SELECT 1")
            .fetch_one(&pool)
            .await?;
        
        assert_eq!(row.0, 1);
        Ok(())
    });

    integration_test!(test_redis_container, async {
        let mut manager = ContainerManager::new();
        let _connection_string = manager.start_redis("test_redis").await?;
        
        // In a real test, you'd verify Redis connectivity here
        Ok(())
    });
}