//! Database layer and repository pattern for testing examples

use crate::{models::*, Result, AppError};
use async_trait::async_trait;
use sqlx::PgPool;
use uuid::Uuid;
use std::marker::PhantomData;

/// Generic repository trait
#[async_trait]
pub trait Repository<T>: Send + Sync {
    async fn create(&self, entity: &T) -> Result<()>;
    async fn find_by_id(&self, id: Uuid) -> Result<Option<T>>;
    async fn find_by_field(&self, field: &str, value: &str) -> Result<Option<T>>;
    async fn find_all_paginated(&self, offset: u32, limit: u32) -> Result<Vec<T>>;
    async fn update(&self, entity: &T) -> Result<()>;
    async fn delete(&self, id: Uuid) -> Result<()>;
    async fn count(&self) -> Result<u64>;
}

/// PostgreSQL repository implementation
pub struct PostgresRepository<T> {
    pool: PgPool,
    _phantom: PhantomData<T>,
}

impl<T> PostgresRepository<T> {
    pub fn new(pool: PgPool) -> Self {
        Self {
            pool,
            _phantom: PhantomData,
        }
    }
}

#[async_trait]
impl Repository<User> for PostgresRepository<User> {
    async fn create(&self, user: &User) -> Result<()> {
        sqlx::query!(
            r#"
            INSERT INTO users (id, name, email, created_at, updated_at, is_active)
            VALUES ($1, $2, $3, $4, $5, $6)
            "#,
            user.id,
            user.name,
            user.email,
            user.created_at,
            user.updated_at,
            user.is_active
        )
        .execute(&self.pool)
        .await?;
        
        Ok(())
    }

    async fn find_by_id(&self, id: Uuid) -> Result<Option<User>> {
        let user = sqlx::query_as!(
            User,
            "SELECT id, name, email, created_at, updated_at, is_active FROM users WHERE id = $1",
            id
        )
        .fetch_optional(&self.pool)
        .await?;
        
        Ok(user)
    }

    async fn find_by_field(&self, field: &str, value: &str) -> Result<Option<User>> {
        match field {
            "email" => {
                let user = sqlx::query_as!(
                    User,
                    "SELECT id, name, email, created_at, updated_at, is_active FROM users WHERE email = $1",
                    value
                )
                .fetch_optional(&self.pool)
                .await?;
                
                Ok(user)
            }
            _ => Err(AppError::Internal(format!("Unsupported field: {}", field))),
        }
    }

    async fn find_all_paginated(&self, offset: u32, limit: u32) -> Result<Vec<User>> {
        let users = sqlx::query_as!(
            User,
            "SELECT id, name, email, created_at, updated_at, is_active FROM users ORDER BY created_at DESC LIMIT $1 OFFSET $2",
            limit as i64,
            offset as i64
        )
        .fetch_all(&self.pool)
        .await?;
        
        Ok(users)
    }

    async fn update(&self, user: &User) -> Result<()> {
        sqlx::query!(
            r#"
            UPDATE users 
            SET name = $2, email = $3, updated_at = $4, is_active = $5
            WHERE id = $1
            "#,
            user.id,
            user.name,
            user.email,
            user.updated_at,
            user.is_active
        )
        .execute(&self.pool)
        .await?;
        
        Ok(())
    }

    async fn delete(&self, id: Uuid) -> Result<()> {
        sqlx::query!("DELETE FROM users WHERE id = $1", id)
            .execute(&self.pool)
            .await?;
        
        Ok(())
    }

    async fn count(&self) -> Result<u64> {
        let count = sqlx::query!("SELECT COUNT(*) as count FROM users")
            .fetch_one(&self.pool)
            .await?;
        
        Ok(count.count.unwrap_or(0) as u64)
    }
}

#[async_trait]
impl Repository<Product> for PostgresRepository<Product> {
    async fn create(&self, product: &Product) -> Result<()> {
        sqlx::query!(
            r#"
            INSERT INTO products (id, name, description, price, category, in_stock, created_at, updated_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            "#,
            product.id,
            product.name,
            product.description,
            product.price,
            product.category,
            product.in_stock,
            product.created_at,
            product.updated_at
        )
        .execute(&self.pool)
        .await?;
        
        Ok(())
    }

    async fn find_by_id(&self, id: Uuid) -> Result<Option<Product>> {
        let product = sqlx::query_as!(
            Product,
            "SELECT id, name, description, price, category, in_stock, created_at, updated_at FROM products WHERE id = $1",
            id
        )
        .fetch_optional(&self.pool)
        .await?;
        
        Ok(product)
    }

    async fn find_by_field(&self, field: &str, value: &str) -> Result<Option<Product>> {
        match field {
            "category" => {
                let product = sqlx::query_as!(
                    Product,
                    "SELECT id, name, description, price, category, in_stock, created_at, updated_at FROM products WHERE category = $1 LIMIT 1",
                    value
                )
                .fetch_optional(&self.pool)
                .await?;
                
                Ok(product)
            }
            _ => Err(AppError::Internal(format!("Unsupported field: {}", field))),
        }
    }

    async fn find_all_paginated(&self, offset: u32, limit: u32) -> Result<Vec<Product>> {
        let products = sqlx::query_as!(
            Product,
            "SELECT id, name, description, price, category, in_stock, created_at, updated_at FROM products ORDER BY created_at DESC LIMIT $1 OFFSET $2",
            limit as i64,
            offset as i64
        )
        .fetch_all(&self.pool)
        .await?;
        
        Ok(products)
    }

    async fn update(&self, product: &Product) -> Result<()> {
        sqlx::query!(
            r#"
            UPDATE products 
            SET name = $2, description = $3, price = $4, category = $5, in_stock = $6, updated_at = $7
            WHERE id = $1
            "#,
            product.id,
            product.name,
            product.description,
            product.price,
            product.category,
            product.in_stock,
            product.updated_at
        )
        .execute(&self.pool)
        .await?;
        
        Ok(())
    }

    async fn delete(&self, id: Uuid) -> Result<()> {
        sqlx::query!("DELETE FROM products WHERE id = $1", id)
            .execute(&self.pool)
            .await?;
        
        Ok(())
    }

    async fn count(&self) -> Result<u64> {
        let count = sqlx::query!("SELECT COUNT(*) as count FROM products")
            .fetch_one(&self.pool)
            .await?;
        
        Ok(count.count.unwrap_or(0) as u64)
    }
}

#[async_trait]
impl Repository<Order> for PostgresRepository<Order> {
    async fn create(&self, order: &Order) -> Result<()> {
        sqlx::query!(
            r#"
            INSERT INTO orders (id, user_id, total, status, created_at, updated_at)
            VALUES ($1, $2, $3, $4, $5, $6)
            "#,
            order.id,
            order.user_id,
            order.total,
            order.status as OrderStatus,
            order.created_at,
            order.updated_at
        )
        .execute(&self.pool)
        .await?;
        
        Ok(())
    }

    async fn find_by_id(&self, id: Uuid) -> Result<Option<Order>> {
        let order = sqlx::query_as!(
            Order,
            r#"SELECT id, user_id, total, status as "status: OrderStatus", created_at, updated_at FROM orders WHERE id = $1"#,
            id
        )
        .fetch_optional(&self.pool)
        .await?;
        
        Ok(order)
    }

    async fn find_by_field(&self, field: &str, value: &str) -> Result<Option<Order>> {
        match field {
            "user_id" => {
                let user_id = Uuid::parse_str(value)
                    .map_err(|_| AppError::Validation("Invalid UUID format".to_string()))?;
                
                let order = sqlx::query_as!(
                    Order,
                    r#"SELECT id, user_id, total, status as "status: OrderStatus", created_at, updated_at FROM orders WHERE user_id = $1 LIMIT 1"#,
                    user_id
                )
                .fetch_optional(&self.pool)
                .await?;
                
                Ok(order)
            }
            _ => Err(AppError::Internal(format!("Unsupported field: {}", field))),
        }
    }

    async fn find_all_paginated(&self, offset: u32, limit: u32) -> Result<Vec<Order>> {
        let orders = sqlx::query_as!(
            Order,
            r#"SELECT id, user_id, total, status as "status: OrderStatus", created_at, updated_at FROM orders ORDER BY created_at DESC LIMIT $1 OFFSET $2"#,
            limit as i64,
            offset as i64
        )
        .fetch_all(&self.pool)
        .await?;
        
        Ok(orders)
    }

    async fn update(&self, order: &Order) -> Result<()> {
        sqlx::query!(
            r#"
            UPDATE orders 
            SET user_id = $2, total = $3, status = $4, updated_at = $5
            WHERE id = $1
            "#,
            order.id,
            order.user_id,
            order.total,
            order.status as OrderStatus,
            order.updated_at
        )
        .execute(&self.pool)
        .await?;
        
        Ok(())
    }

    async fn delete(&self, id: Uuid) -> Result<()> {
        sqlx::query!("DELETE FROM orders WHERE id = $1", id)
            .execute(&self.pool)
            .await?;
        
        Ok(())
    }

    async fn count(&self) -> Result<u64> {
        let count = sqlx::query!("SELECT COUNT(*) as count FROM orders")
            .fetch_one(&self.pool)
            .await?;
        
        Ok(count.count.unwrap_or(0) as u64)
    }
}

/// Database migration utilities
pub async fn run_migrations(pool: &PgPool) -> Result<()> {
    // Create users table
    sqlx::query!(
        r#"
        CREATE TABLE IF NOT EXISTS users (
            id UUID PRIMARY KEY,
            name VARCHAR NOT NULL,
            email VARCHAR UNIQUE NOT NULL,
            created_at TIMESTAMPTZ NOT NULL,
            updated_at TIMESTAMPTZ NOT NULL,
            is_active BOOLEAN NOT NULL DEFAULT true
        )
        "#
    )
    .execute(pool)
    .await?;

    // Create products table
    sqlx::query!(
        r#"
        CREATE TABLE IF NOT EXISTS products (
            id UUID PRIMARY KEY,
            name VARCHAR NOT NULL,
            description TEXT NOT NULL,
            price DECIMAL(10,2) NOT NULL,
            category VARCHAR NOT NULL,
            in_stock BOOLEAN NOT NULL DEFAULT true,
            created_at TIMESTAMPTZ NOT NULL,
            updated_at TIMESTAMPTZ NOT NULL
        )
        "#
    )
    .execute(pool)
    .await?;

    // Create order status enum
    sqlx::query!(
        r#"
        DO $$ BEGIN
            CREATE TYPE order_status AS ENUM ('pending', 'processing', 'shipped', 'delivered', 'cancelled');
        EXCEPTION
            WHEN duplicate_object THEN null;
        END $$;
        "#
    )
    .execute(pool)
    .await?;

    // Create orders table
    sqlx::query!(
        r#"
        CREATE TABLE IF NOT EXISTS orders (
            id UUID PRIMARY KEY,
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            total DECIMAL(10,2) NOT NULL,
            status order_status NOT NULL DEFAULT 'pending',
            created_at TIMESTAMPTZ NOT NULL,
            updated_at TIMESTAMPTZ NOT NULL
        )
        "#
    )
    .execute(pool)
    .await?;

    // Create order_items table
    sqlx::query!(
        r#"
        CREATE TABLE IF NOT EXISTS order_items (
            id UUID PRIMARY KEY,
            order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
            product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
            quantity INTEGER NOT NULL,
            unit_price DECIMAL(10,2) NOT NULL
        )
        "#
    )
    .execute(pool)
    .await?;

    Ok(())
}

/// Mock repository for testing
#[cfg(test)]
pub struct MockRepository<T> {
    _phantom: PhantomData<T>,
    pub expect_create: mockall::Mock,
    pub expect_find_by_id: mockall::Mock,
    pub expect_find_by_field: mockall::Mock,
    pub expect_find_all_paginated: mockall::Mock,
    pub expect_update: mockall::Mock,
    pub expect_delete: mockall::Mock,
    pub expect_count: mockall::Mock,
}

#[cfg(test)]
impl<T> MockRepository<T> {
    pub fn new() -> Self {
        Self {
            _phantom: PhantomData,
            expect_create: mockall::Mock::new(),
            expect_find_by_id: mockall::Mock::new(),
            expect_find_by_field: mockall::Mock::new(),
            expect_find_all_paginated: mockall::Mock::new(),
            expect_update: mockall::Mock::new(),
            expect_delete: mockall::Mock::new(),
            expect_count: mockall::Mock::new(),
        }
    }
}

// Add required dependencies
use async_trait;

#[cfg(test)]
use mockall;

#[cfg(test)]
mod tests {
    use super::*;
    use testing_framework::integration::TestEnvironment;
    use testing_framework::database::setup_test_database;

    #[tokio::test]
    async fn test_postgres_repository_user_crud() {
        let mut test_env = TestEnvironment::new();
        let (host, port) = test_env.start_postgres("test_db").await.unwrap();
        
        let database_url = format!("postgres://postgres:postgres@{}:{}/postgres", host, port);
        let pool = setup_test_database(&database_url).await.unwrap();
        
        // Run migrations
        run_migrations(&pool).await.unwrap();
        
        let repo = PostgresRepository::<User>::new(pool);
        
        // Test create
        let user = User {
            id: Uuid::new_v4(),
            name: "Test User".to_string(),
            email: "test@example.com".to_string(),
            created_at: Utc::now(),
            updated_at: Utc::now(),
            is_active: true,
        };
        
        repo.create(&user).await.unwrap();
        
        // Test find by id
        let found_user = repo.find_by_id(user.id).await.unwrap();
        assert!(found_user.is_some());
        assert_eq!(found_user.unwrap().email, user.email);
        
        // Test find by field
        let found_by_email = repo.find_by_field("email", &user.email).await.unwrap();
        assert!(found_by_email.is_some());
        
        // Test count
        let count = repo.count().await.unwrap();
        assert_eq!(count, 1);
        
        // Test delete
        repo.delete(user.id).await.unwrap();
        let deleted_user = repo.find_by_id(user.id).await.unwrap();
        assert!(deleted_user.is_none());
    }
}