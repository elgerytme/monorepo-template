//! Business logic services for testing examples

use crate::{models::*, database::Repository, Result, AppError};
use uuid::Uuid;
use chrono::Utc;
use std::sync::Arc;

/// User service
#[derive(Clone)]
pub struct UserService {
    repository: Arc<dyn Repository<User>>,
}

impl UserService {
    pub fn new(repository: Arc<dyn Repository<User>>) -> Self {
        Self { repository }
    }

    /// Create a new user
    pub async fn create_user(&self, request: CreateUserRequest) -> Result<User> {
        // Validate email format
        if !self.is_valid_email(&request.email) {
            return Err(AppError::Validation("Invalid email format".to_string()));
        }

        // Check if email already exists
        if self.repository.find_by_field("email", &request.email).await?.is_some() {
            return Err(AppError::Validation("Email already exists".to_string()));
        }

        let user = User {
            id: Uuid::new_v4(),
            name: request.name,
            email: request.email,
            created_at: Utc::now(),
            updated_at: Utc::now(),
            is_active: true,
        };

        self.repository.create(&user).await?;
        Ok(user)
    }

    /// Get user by ID
    pub async fn get_user(&self, id: Uuid) -> Result<User> {
        self.repository
            .find_by_id(id)
            .await?
            .ok_or_else(|| AppError::NotFound(format!("User with id {} not found", id)))
    }

    /// Update user
    pub async fn update_user(&self, id: Uuid, request: UpdateUserRequest) -> Result<User> {
        let mut user = self.get_user(id).await?;

        if let Some(name) = request.name {
            user.name = name;
        }

        if let Some(email) = request.email {
            if !self.is_valid_email(&email) {
                return Err(AppError::Validation("Invalid email format".to_string()));
            }
            
            // Check if new email already exists (excluding current user)
            if let Some(existing_user) = self.repository.find_by_field("email", &email).await? {
                if existing_user.id != id {
                    return Err(AppError::Validation("Email already exists".to_string()));
                }
            }
            
            user.email = email;
        }

        if let Some(is_active) = request.is_active {
            user.is_active = is_active;
        }

        user.updated_at = Utc::now();
        self.repository.update(&user).await?;
        Ok(user)
    }

    /// Delete user
    pub async fn delete_user(&self, id: Uuid) -> Result<()> {
        let _user = self.get_user(id).await?; // Ensure user exists
        self.repository.delete(id).await?;
        Ok(())
    }

    /// List users with pagination
    pub async fn list_users(&self, params: PaginationParams) -> Result<PaginatedResponse<User>> {
        let offset = params.offset();
        let limit = params.limit();
        
        let users = self.repository.find_all_paginated(offset, limit).await?;
        let total = self.repository.count().await?;
        
        Ok(PaginatedResponse::new(
            users,
            params.page.unwrap_or(1),
            limit,
            total,
        ))
    }

    /// Validate email format
    fn is_valid_email(&self, email: &str) -> bool {
        email.contains('@') && email.contains('.') && email.len() > 5
    }
}

/// Product service
#[derive(Clone)]
pub struct ProductService {
    repository: Arc<dyn Repository<Product>>,
}

impl ProductService {
    pub fn new(repository: Arc<dyn Repository<Product>>) -> Self {
        Self { repository }
    }

    /// Create a new product
    pub async fn create_product(&self, request: CreateProductRequest) -> Result<Product> {
        if request.price <= 0.0 {
            return Err(AppError::Validation("Price must be positive".to_string()));
        }

        let product = Product {
            id: Uuid::new_v4(),
            name: request.name,
            description: request.description,
            price: sqlx::types::Decimal::from_f64_retain(request.price)
                .ok_or_else(|| AppError::Validation("Invalid price format".to_string()))?,
            category: request.category,
            in_stock: true,
            created_at: Utc::now(),
            updated_at: Utc::now(),
        };

        self.repository.create(&product).await?;
        Ok(product)
    }

    /// Get product by ID
    pub async fn get_product(&self, id: Uuid) -> Result<Product> {
        self.repository
            .find_by_id(id)
            .await?
            .ok_or_else(|| AppError::NotFound(format!("Product with id {} not found", id)))
    }

    /// List products by category
    pub async fn list_products_by_category(&self, category: &str) -> Result<Vec<Product>> {
        self.repository.find_by_field("category", category).await
            .map(|opt| opt.map(|p| vec![p]).unwrap_or_default())
    }

    /// Update product stock status
    pub async fn update_stock_status(&self, id: Uuid, in_stock: bool) -> Result<Product> {
        let mut product = self.get_product(id).await?;
        product.in_stock = in_stock;
        product.updated_at = Utc::now();
        
        self.repository.update(&product).await?;
        Ok(product)
    }
}

/// Order service
#[derive(Clone)]
pub struct OrderService {
    order_repository: Arc<dyn Repository<Order>>,
    product_service: ProductService,
    user_service: UserService,
}

impl OrderService {
    pub fn new(
        order_repository: Arc<dyn Repository<Order>>,
        product_service: ProductService,
        user_service: UserService,
    ) -> Self {
        Self {
            order_repository,
            product_service,
            user_service,
        }
    }

    /// Create a new order
    pub async fn create_order(&self, request: CreateOrderRequest) -> Result<Order> {
        // Validate user exists
        let _user = self.user_service.get_user(request.user_id).await?;

        if request.items.is_empty() {
            return Err(AppError::Validation("Order must have at least one item".to_string()));
        }

        // Validate products and calculate total
        let mut total = sqlx::types::Decimal::new(0, 0);
        
        for item in &request.items {
            let product = self.product_service.get_product(item.product_id).await?;
            
            if !product.in_stock {
                return Err(AppError::Validation(
                    format!("Product {} is out of stock", product.name)
                ));
            }

            if item.quantity <= 0 {
                return Err(AppError::Validation("Item quantity must be positive".to_string()));
            }

            let item_total = product.price * sqlx::types::Decimal::new(item.quantity as i64, 0);
            total += item_total;
        }

        let order = Order {
            id: Uuid::new_v4(),
            user_id: request.user_id,
            total,
            status: OrderStatus::Pending,
            created_at: Utc::now(),
            updated_at: Utc::now(),
        };

        self.order_repository.create(&order).await?;
        Ok(order)
    }

    /// Get order by ID
    pub async fn get_order(&self, id: Uuid) -> Result<Order> {
        self.order_repository
            .find_by_id(id)
            .await?
            .ok_or_else(|| AppError::NotFound(format!("Order with id {} not found", id)))
    }

    /// Update order status
    pub async fn update_order_status(&self, id: Uuid, status: OrderStatus) -> Result<Order> {
        let mut order = self.get_order(id).await?;
        
        // Validate status transition
        if !self.is_valid_status_transition(&order.status, &status) {
            return Err(AppError::Validation(
                format!("Invalid status transition from {:?} to {:?}", order.status, status)
            ));
        }

        order.status = status;
        order.updated_at = Utc::now();
        
        self.order_repository.update(&order).await?;
        Ok(order)
    }

    /// Get orders for user
    pub async fn get_user_orders(&self, user_id: Uuid) -> Result<Vec<Order>> {
        // This is a simplified implementation - in a real app, you'd have a proper query
        self.order_repository.find_by_field("user_id", &user_id.to_string()).await
            .map(|opt| opt.map(|o| vec![o]).unwrap_or_default())
    }

    /// Validate status transition
    fn is_valid_status_transition(&self, current: &OrderStatus, new: &OrderStatus) -> bool {
        use OrderStatus::*;
        
        match (current, new) {
            (Pending, Processing) => true,
            (Processing, Shipped) => true,
            (Shipped, Delivered) => true,
            (Pending, Cancelled) => true,
            (Processing, Cancelled) => true,
            (current, new) if current == new => true, // Allow same status
            _ => false,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::database::MockRepository;
    use std::collections::HashMap;
    use tokio;

    #[tokio::test]
    async fn test_user_service_create_user() {
        let mut mock_repo = MockRepository::new();
        mock_repo.expect_find_by_field()
            .returning(|_, _| Ok(None)); // Email doesn't exist
        mock_repo.expect_create()
            .returning(|_| Ok(()));

        let service = UserService::new(Arc::new(mock_repo));
        
        let request = CreateUserRequest {
            name: "John Doe".to_string(),
            email: "john@example.com".to_string(),
        };

        let result = service.create_user(request).await;
        assert!(result.is_ok());
        
        let user = result.unwrap();
        assert_eq!(user.name, "John Doe");
        assert_eq!(user.email, "john@example.com");
        assert!(user.is_active);
    }

    #[tokio::test]
    async fn test_user_service_invalid_email() {
        let mock_repo = MockRepository::new();
        let service = UserService::new(Arc::new(mock_repo));
        
        let request = CreateUserRequest {
            name: "John Doe".to_string(),
            email: "invalid-email".to_string(),
        };

        let result = service.create_user(request).await;
        assert!(result.is_err());
        
        match result.unwrap_err() {
            AppError::Validation(msg) => assert_eq!(msg, "Invalid email format"),
            _ => panic!("Expected validation error"),
        }
    }

    #[tokio::test]
    async fn test_user_service_duplicate_email() {
        let mut mock_repo = MockRepository::new();
        
        // Mock existing user with same email
        let existing_user = User {
            id: Uuid::new_v4(),
            name: "Existing User".to_string(),
            email: "john@example.com".to_string(),
            created_at: Utc::now(),
            updated_at: Utc::now(),
            is_active: true,
        };
        
        mock_repo.expect_find_by_field()
            .returning(move |_, _| Ok(Some(existing_user.clone())));

        let service = UserService::new(Arc::new(mock_repo));
        
        let request = CreateUserRequest {
            name: "John Doe".to_string(),
            email: "john@example.com".to_string(),
        };

        let result = service.create_user(request).await;
        assert!(result.is_err());
        
        match result.unwrap_err() {
            AppError::Validation(msg) => assert_eq!(msg, "Email already exists"),
            _ => panic!("Expected validation error"),
        }
    }

    #[tokio::test]
    async fn test_product_service_create_product() {
        let mut mock_repo = MockRepository::new();
        mock_repo.expect_create()
            .returning(|_| Ok(()));

        let service = ProductService::new(Arc::new(mock_repo));
        
        let request = CreateProductRequest {
            name: "Test Product".to_string(),
            description: "A test product".to_string(),
            price: 29.99,
            category: "Electronics".to_string(),
        };

        let result = service.create_product(request).await;
        assert!(result.is_ok());
        
        let product = result.unwrap();
        assert_eq!(product.name, "Test Product");
        assert!(product.in_stock);
    }

    #[tokio::test]
    async fn test_product_service_invalid_price() {
        let mock_repo = MockRepository::new();
        let service = ProductService::new(Arc::new(mock_repo));
        
        let request = CreateProductRequest {
            name: "Test Product".to_string(),
            description: "A test product".to_string(),
            price: -10.0,
            category: "Electronics".to_string(),
        };

        let result = service.create_product(request).await;
        assert!(result.is_err());
        
        match result.unwrap_err() {
            AppError::Validation(msg) => assert_eq!(msg, "Price must be positive"),
            _ => panic!("Expected validation error"),
        }
    }

    #[tokio::test]
    async fn test_order_service_empty_items() {
        let order_repo = Arc::new(MockRepository::new());
        let product_repo = Arc::new(MockRepository::new());
        let user_repo = Arc::new(MockRepository::new());
        
        let product_service = ProductService::new(product_repo);
        let user_service = UserService::new(user_repo);
        let order_service = OrderService::new(order_repo, product_service, user_service);
        
        let request = CreateOrderRequest {
            user_id: Uuid::new_v4(),
            items: vec![],
        };

        let result = order_service.create_order(request).await;
        assert!(result.is_err());
        
        match result.unwrap_err() {
            AppError::Validation(msg) => assert_eq!(msg, "Order must have at least one item"),
            _ => panic!("Expected validation error"),
        }
    }
}