//! Testing examples demonstrating comprehensive testing patterns

pub mod models;
pub mod services;
pub mod handlers;
pub mod database;

use serde::{Deserialize, Serialize};
use uuid::Uuid;
use chrono::{DateTime, Utc};

/// Application configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppConfig {
    pub database_url: String,
    pub redis_url: String,
    pub port: u16,
    pub log_level: String,
}

impl Default for AppConfig {
    fn default() -> Self {
        Self {
            database_url: "postgres://test:test@localhost:5432/test_db".to_string(),
            redis_url: "redis://localhost:6379".to_string(),
            port: 3000,
            log_level: "info".to_string(),
        }
    }
}

/// Application state
#[derive(Clone)]
pub struct AppState {
    pub config: AppConfig,
    pub db_pool: sqlx::PgPool,
}

/// Common error type for the application
#[derive(Debug, thiserror::Error)]
pub enum AppError {
    #[error("Database error: {0}")]
    Database(#[from] sqlx::Error),
    
    #[error("Serialization error: {0}")]
    Serialization(#[from] serde_json::Error),
    
    #[error("Not found: {0}")]
    NotFound(String),
    
    #[error("Validation error: {0}")]
    Validation(String),
    
    #[error("Internal server error: {0}")]
    Internal(String),
}

impl axum::response::IntoResponse for AppError {
    fn into_response(self) -> axum::response::Response {
        use axum::http::StatusCode;
        use axum::Json;
        
        let (status, message) = match self {
            AppError::NotFound(msg) => (StatusCode::NOT_FOUND, msg),
            AppError::Validation(msg) => (StatusCode::BAD_REQUEST, msg),
            AppError::Database(_) => (StatusCode::INTERNAL_SERVER_ERROR, "Database error".to_string()),
            AppError::Serialization(_) => (StatusCode::INTERNAL_SERVER_ERROR, "Serialization error".to_string()),
            AppError::Internal(msg) => (StatusCode::INTERNAL_SERVER_ERROR, msg),
        };
        
        let body = serde_json::json!({
            "error": message
        });
        
        (status, Json(body)).into_response()
    }
}

pub type Result<T> = std::result::Result<T, AppError>;