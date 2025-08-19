use std::ffi::NulError;
use thiserror::Error;

pub type LibraryResult<T> = Result<T, LibraryError>;

#[derive(Error, Debug)]
pub enum LibraryError {
    #[error("Validation error: {0}")]
    ValidationError(String),

    #[error("Resource not found: {0}")]
    NotFound(String),

    #[error("Resource already exists: {0}")]
    AlreadyExists(String),

    #[error("JSON serialization error: {0}")]
    JsonError(#[from] serde_json::Error),

    #[error("String conversion error: {0}")]
    StringError(#[from] NulError),

    #[error("Internal error: {0}")]
    InternalError(String),
}

impl LibraryError {
    pub fn validation(msg: impl Into<String>) -> Self {
        Self::ValidationError(msg.into())
    }

    pub fn not_found(msg: impl Into<String>) -> Self {
        Self::NotFound(msg.into())
    }

    pub fn already_exists(msg: impl Into<String>) -> Self {
        Self::AlreadyExists(msg.into())
    }

    pub fn internal(msg: impl Into<String>) -> Self {
        Self::InternalError(msg.into())
    }
}