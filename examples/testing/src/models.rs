//! Data models for testing examples

use serde::{Deserialize, Serialize};
use uuid::Uuid;
use chrono::{DateTime, Utc};
use std::collections::HashMap;

/// User model
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, sqlx::FromRow)]
pub struct User {
    pub id: Uuid,
    pub name: String,
    pub email: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub is_active: bool,
}

/// User creation request
#[derive(Debug, Deserialize)]
pub struct CreateUserRequest {
    pub name: String,
    pub email: String,
}

/// User update request
#[derive(Debug, Deserialize)]
pub struct UpdateUserRequest {
    pub name: Option<String>,
    pub email: Option<String>,
    pub is_active: Option<bool>,
}

/// Product model
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, sqlx::FromRow)]
pub struct Product {
    pub id: Uuid,
    pub name: String,
    pub description: String,
    pub price: sqlx::types::Decimal,
    pub category: String,
    pub in_stock: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// Product creation request
#[derive(Debug, Deserialize)]
pub struct CreateProductRequest {
    pub name: String,
    pub description: String,
    pub price: f64,
    pub category: String,
}

/// Order model
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, sqlx::FromRow)]
pub struct Order {
    pub id: Uuid,
    pub user_id: Uuid,
    pub total: sqlx::types::Decimal,
    pub status: OrderStatus,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// Order status enum
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, sqlx::Type)]
#[sqlx(type_name = "order_status", rename_all = "lowercase")]
pub enum OrderStatus {
    Pending,
    Processing,
    Shipped,
    Delivered,
    Cancelled,
}

/// Order item model
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, sqlx::FromRow)]
pub struct OrderItem {
    pub id: Uuid,
    pub order_id: Uuid,
    pub product_id: Uuid,
    pub quantity: i32,
    pub unit_price: sqlx::types::Decimal,
}

/// Order creation request
#[derive(Debug, Deserialize)]
pub struct CreateOrderRequest {
    pub user_id: Uuid,
    pub items: Vec<CreateOrderItemRequest>,
}

/// Order item creation request
#[derive(Debug, Deserialize)]
pub struct CreateOrderItemRequest {
    pub product_id: Uuid,
    pub quantity: i32,
}

/// Pagination parameters
#[derive(Debug, Deserialize)]
pub struct PaginationParams {
    pub page: Option<u32>,
    pub limit: Option<u32>,
}

impl Default for PaginationParams {
    fn default() -> Self {
        Self {
            page: Some(1),
            limit: Some(20),
        }
    }
}

impl PaginationParams {
    pub fn offset(&self) -> u32 {
        let page = self.page.unwrap_or(1);
        let limit = self.limit.unwrap_or(20);
        (page.saturating_sub(1)) * limit
    }

    pub fn limit(&self) -> u32 {
        self.limit.unwrap_or(20).min(100) // Cap at 100
    }
}

/// Paginated response
#[derive(Debug, Serialize)]
pub struct PaginatedResponse<T> {
    pub data: Vec<T>,
    pub page: u32,
    pub limit: u32,
    pub total: u64,
    pub total_pages: u32,
}

impl<T> PaginatedResponse<T> {
    pub fn new(data: Vec<T>, page: u32, limit: u32, total: u64) -> Self {
        let total_pages = ((total as f64) / (limit as f64)).ceil() as u32;
        
        Self {
            data,
            page,
            limit,
            total,
            total_pages,
        }
    }
}

/// API response wrapper
#[derive(Debug, Serialize)]
pub struct ApiResponse<T> {
    pub success: bool,
    pub data: Option<T>,
    pub error: Option<String>,
    pub timestamp: DateTime<Utc>,
}

impl<T> ApiResponse<T> {
    pub fn success(data: T) -> Self {
        Self {
            success: true,
            data: Some(data),
            error: None,
            timestamp: Utc::now(),
        }
    }

    pub fn error(message: String) -> ApiResponse<()> {
        ApiResponse {
            success: false,
            data: None,
            error: Some(message),
            timestamp: Utc::now(),
        }
    }
}

/// Health check response
#[derive(Debug, Serialize)]
pub struct HealthResponse {
    pub status: String,
    pub timestamp: DateTime<Utc>,
    pub version: String,
    pub checks: HashMap<String, HealthCheck>,
}

#[derive(Debug, Serialize)]
pub struct HealthCheck {
    pub status: String,
    pub response_time_ms: u64,
    pub details: Option<String>,
}

impl HealthResponse {
    pub fn new(version: String) -> Self {
        Self {
            status: "healthy".to_string(),
            timestamp: Utc::now(),
            version,
            checks: HashMap::new(),
        }
    }

    pub fn add_check(&mut self, name: String, check: HealthCheck) {
        self.checks.insert(name, check);
        
        // Update overall status based on checks
        if self.checks.values().any(|c| c.status != "healthy") {
            self.status = "unhealthy".to_string();
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_pagination_params_default() {
        let params = PaginationParams::default();
        assert_eq!(params.page, Some(1));
        assert_eq!(params.limit, Some(20));
        assert_eq!(params.offset(), 0);
        assert_eq!(params.limit(), 20);
    }

    #[test]
    fn test_pagination_params_offset() {
        let params = PaginationParams {
            page: Some(3),
            limit: Some(10),
        };
        assert_eq!(params.offset(), 20);
        assert_eq!(params.limit(), 10);
    }

    #[test]
    fn test_pagination_params_limit_cap() {
        let params = PaginationParams {
            page: Some(1),
            limit: Some(200),
        };
        assert_eq!(params.limit(), 100); // Should be capped at 100
    }

    #[test]
    fn test_paginated_response() {
        let data = vec![1, 2, 3];
        let response = PaginatedResponse::new(data, 1, 10, 25);
        
        assert_eq!(response.page, 1);
        assert_eq!(response.limit, 10);
        assert_eq!(response.total, 25);
        assert_eq!(response.total_pages, 3);
    }

    #[test]
    fn test_api_response_success() {
        let response = ApiResponse::success("test data");
        assert!(response.success);
        assert_eq!(response.data, Some("test data"));
        assert!(response.error.is_none());
    }

    #[test]
    fn test_api_response_error() {
        let response = ApiResponse::<()>::error("test error".to_string());
        assert!(!response.success);
        assert!(response.data.is_none());
        assert_eq!(response.error, Some("test error".to_string()));
    }

    #[test]
    fn test_health_response() {
        let mut health = HealthResponse::new("1.0.0".to_string());
        assert_eq!(health.status, "healthy");
        
        health.add_check("database".to_string(), HealthCheck {
            status: "healthy".to_string(),
            response_time_ms: 10,
            details: None,
        });
        assert_eq!(health.status, "healthy");
        
        health.add_check("redis".to_string(), HealthCheck {
            status: "unhealthy".to_string(),
            response_time_ms: 5000,
            details: Some("Connection timeout".to_string()),
        });
        assert_eq!(health.status, "unhealthy");
    }
}