//! Test fixtures and data generation utilities

use fake::{Fake, Faker};
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use chrono::{DateTime, Utc};
use std::collections::HashMap;

/// Test user fixture
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct TestUser {
    pub id: Uuid,
    pub name: String,
    pub email: String,
    pub created_at: DateTime<Utc>,
    pub is_active: bool,
    pub metadata: HashMap<String, String>,
}

impl TestUser {
    /// Create a new test user with random data
    pub fn fake() -> Self {
        use fake::faker::internet::en::*;
        use fake::faker::name::en::*;
        
        Self {
            id: Uuid::new_v4(),
            name: Name().fake(),
            email: SafeEmail().fake(),
            created_at: Utc::now(),
            is_active: true,
            metadata: HashMap::new(),
        }
    }

    /// Create a test user with specific email
    pub fn with_email(email: impl Into<String>) -> Self {
        Self {
            email: email.into(),
            ..Self::fake()
        }
    }

    /// Create an inactive test user
    pub fn inactive() -> Self {
        Self {
            is_active: false,
            ..Self::fake()
        }
    }
}

/// Test product fixture
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct TestProduct {
    pub id: Uuid,
    pub name: String,
    pub description: String,
    pub price: f64,
    pub category: String,
    pub in_stock: bool,
    pub created_at: DateTime<Utc>,
}

impl TestProduct {
    pub fn fake() -> Self {
        use fake::faker::commerce::en::*;
        
        Self {
            id: Uuid::new_v4(),
            name: ProductName().fake(),
            description: ProductAdjective().fake(),
            price: (1.0..1000.0).fake(),
            category: ProductCategory().fake(),
            in_stock: true,
            created_at: Utc::now(),
        }
    }

    pub fn out_of_stock() -> Self {
        Self {
            in_stock: false,
            ..Self::fake()
        }
    }

    pub fn with_price(price: f64) -> Self {
        Self {
            price,
            ..Self::fake()
        }
    }
}

/// Test order fixture
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct TestOrder {
    pub id: Uuid,
    pub user_id: Uuid,
    pub items: Vec<OrderItem>,
    pub total: f64,
    pub status: OrderStatus,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct OrderItem {
    pub product_id: Uuid,
    pub quantity: u32,
    pub unit_price: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum OrderStatus {
    Pending,
    Processing,
    Shipped,
    Delivered,
    Cancelled,
}

impl TestOrder {
    pub fn fake() -> Self {
        let items: Vec<OrderItem> = (1..=3)
            .map(|_| OrderItem {
                product_id: Uuid::new_v4(),
                quantity: (1..=5).fake(),
                unit_price: (10.0..100.0).fake(),
            })
            .collect();

        let total = items.iter().map(|item| item.unit_price * item.quantity as f64).sum();

        Self {
            id: Uuid::new_v4(),
            user_id: Uuid::new_v4(),
            items,
            total,
            status: OrderStatus::Pending,
            created_at: Utc::now(),
        }
    }

    pub fn with_status(status: OrderStatus) -> Self {
        Self {
            status,
            ..Self::fake()
        }
    }

    pub fn for_user(user_id: Uuid) -> Self {
        Self {
            user_id,
            ..Self::fake()
        }
    }
}

/// Database fixtures for integration tests
pub mod database {
    use super::*;
    use sqlx::PgPool;
    use crate::TestResult;

    /// Insert test users into database
    pub async fn insert_test_users(pool: &PgPool, count: usize) -> TestResult<Vec<TestUser>> {
        let mut users = Vec::new();
        
        for _ in 0..count {
            let user = TestUser::fake();
            
            sqlx::query!(
                "INSERT INTO test_users (id, name, email, created_at, is_active) VALUES ($1, $2, $3, $4, $5)",
                user.id,
                user.name,
                user.email,
                user.created_at,
                user.is_active
            )
            .execute(pool)
            .await?;
            
            users.push(user);
        }
        
        Ok(users)
    }

    /// Clean up test data
    pub async fn cleanup_test_data(pool: &PgPool) -> TestResult {
        sqlx::query!("DELETE FROM test_users WHERE email LIKE '%@example.%'")
            .execute(pool)
            .await?;
        Ok(())
    }
}

/// HTTP fixtures for API testing
pub mod http {
    use super::*;
    use serde_json::Value;
    use std::collections::HashMap;

    /// Create test HTTP request body
    pub fn create_user_request() -> Value {
        let user = TestUser::fake();
        serde_json::json!({
            "name": user.name,
            "email": user.email,
            "is_active": user.is_active
        })
    }

    /// Create test HTTP headers
    pub fn auth_headers(token: &str) -> HashMap<String, String> {
        let mut headers = HashMap::new();
        headers.insert("Authorization".to_string(), format!("Bearer {}", token));
        headers.insert("Content-Type".to_string(), "application/json".to_string());
        headers
    }

    /// Create test JWT token (for testing only)
    pub fn fake_jwt_token() -> String {
        use fake::faker::lorem::en::*;
        format!("eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.{}.{}", 
                base64::encode(Word().fake::<String>()),
                base64::encode(Word().fake::<String>()))
    }
}

/// File system fixtures
pub mod filesystem {
    use std::fs;
    use std::path::{Path, PathBuf};
    use tempfile::TempDir;
    use crate::TestResult;

    /// Create a temporary directory with test files
    pub fn create_test_workspace() -> TestResult<TempDir> {
        let temp_dir = TempDir::new()?;
        
        // Create directory structure
        fs::create_dir_all(temp_dir.path().join("src"))?;
        fs::create_dir_all(temp_dir.path().join("tests"))?;
        fs::create_dir_all(temp_dir.path().join("docs"))?;
        
        // Create test files
        fs::write(
            temp_dir.path().join("Cargo.toml"),
            r#"[package]
name = "test-project"
version = "0.1.0"
edition = "2021"

[dependencies]
serde = "1.0"
"#,
        )?;
        
        fs::write(
            temp_dir.path().join("src/lib.rs"),
            r#"//! Test library
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_add() {
        assert_eq!(add(2, 2), 4);
    }
}
"#,
        )?;
        
        fs::write(
            temp_dir.path().join("README.md"),
            "# Test Project\n\nThis is a test project for testing purposes.\n",
        )?;
        
        Ok(temp_dir)
    }

    /// Create test configuration files
    pub fn create_config_files(base_path: &Path) -> TestResult {
        let config_dir = base_path.join("config");
        fs::create_dir_all(&config_dir)?;
        
        // Create test configuration
        fs::write(
            config_dir.join("test.toml"),
            r#"[database]
url = "postgres://test:test@localhost:5432/test_db"

[redis]
url = "redis://localhost:6379"

[logging]
level = "debug"
"#,
        )?;
        
        Ok(())
    }
}

/// Mock data generators
pub mod generators {
    use super::*;
    use std::ops::Range;

    /// Generate a list of test users
    pub fn users(count: usize) -> Vec<TestUser> {
        (0..count).map(|_| TestUser::fake()).collect()
    }

    /// Generate test users with specific email domains
    pub fn users_with_domain(count: usize, domain: &str) -> Vec<TestUser> {
        use fake::faker::name::en::*;
        
        (0..count)
            .map(|i| TestUser {
                email: format!("user{}@{}", i, domain),
                ..TestUser::fake()
            })
            .collect()
    }

    /// Generate test products in price range
    pub fn products_in_price_range(count: usize, price_range: Range<f64>) -> Vec<TestProduct> {
        (0..count)
            .map(|_| TestProduct {
                price: (price_range.start..price_range.end).fake(),
                ..TestProduct::fake()
            })
            .collect()
    }

    /// Generate test orders for specific users
    pub fn orders_for_users(users: &[TestUser]) -> Vec<TestOrder> {
        users
            .iter()
            .map(|user| TestOrder::for_user(user.id))
            .collect()
    }
}

// Add base64 dependency for JWT token generation
use base64;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_fake_user_generation() {
        let user = TestUser::fake();
        assert!(!user.name.is_empty());
        assert!(user.email.contains('@'));
        assert!(user.is_active);
    }

    #[test]
    fn test_fake_product_generation() {
        let product = TestProduct::fake();
        assert!(!product.name.is_empty());
        assert!(product.price > 0.0);
        assert!(product.in_stock);
    }

    #[test]
    fn test_fake_order_generation() {
        let order = TestOrder::fake();
        assert!(!order.items.is_empty());
        assert!(order.total > 0.0);
        assert_eq!(order.status, OrderStatus::Pending);
    }

    #[test]
    fn test_generators() {
        let users = generators::users(5);
        assert_eq!(users.len(), 5);
        
        let domain_users = generators::users_with_domain(3, "test.com");
        assert_eq!(domain_users.len(), 3);
        assert!(domain_users.iter().all(|u| u.email.ends_with("@test.com")));
    }

    #[test]
    fn test_filesystem_fixtures() {
        let workspace = filesystem::create_test_workspace().unwrap();
        assert!(workspace.path().join("Cargo.toml").exists());
        assert!(workspace.path().join("src/lib.rs").exists());
        assert!(workspace.path().join("README.md").exists());
    }
}