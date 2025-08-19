//! HTTP handlers for testing examples

use crate::{models::*, services::*, AppState, Result};
use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    response::Json,
};
use uuid::Uuid;

/// Health check handler
pub async fn health_check() -> Json<HealthResponse> {
    let mut health = HealthResponse::new("1.0.0".to_string());
    
    // Add basic health checks
    health.add_check("api".to_string(), HealthCheck {
        status: "healthy".to_string(),
        response_time_ms: 1,
        details: None,
    });
    
    Json(health)
}

/// Create user handler
pub async fn create_user(
    State(state): State<AppState>,
    Json(request): Json<CreateUserRequest>,
) -> Result<(StatusCode, Json<ApiResponse<User>>)> {
    let user_repo = std::sync::Arc::new(crate::database::PostgresRepository::new(state.db_pool));
    let user_service = UserService::new(user_repo);
    
    let user = user_service.create_user(request).await?;
    
    Ok((StatusCode::CREATED, Json(ApiResponse::success(user))))
}

/// Get user handler
pub async fn get_user(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<Json<ApiResponse<User>>> {
    let user_repo = std::sync::Arc::new(crate::database::PostgresRepository::new(state.db_pool));
    let user_service = UserService::new(user_repo);
    
    let user = user_service.get_user(id).await?;
    
    Ok(Json(ApiResponse::success(user)))
}

/// Update user handler
pub async fn update_user(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    Json(request): Json<UpdateUserRequest>,
) -> Result<Json<ApiResponse<User>>> {
    let user_repo = std::sync::Arc::new(crate::database::PostgresRepository::new(state.db_pool));
    let user_service = UserService::new(user_repo);
    
    let user = user_service.update_user(id, request).await?;
    
    Ok(Json(ApiResponse::success(user)))
}

/// Delete user handler
pub async fn delete_user(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<StatusCode> {
    let user_repo = std::sync::Arc::new(crate::database::PostgresRepository::new(state.db_pool));
    let user_service = UserService::new(user_repo);
    
    user_service.delete_user(id).await?;
    
    Ok(StatusCode::NO_CONTENT)
}

/// List users handler
pub async fn list_users(
    State(state): State<AppState>,
    Query(params): Query<PaginationParams>,
) -> Result<Json<ApiResponse<PaginatedResponse<User>>>> {
    let user_repo = std::sync::Arc::new(crate::database::PostgresRepository::new(state.db_pool));
    let user_service = UserService::new(user_repo);
    
    let users = user_service.list_users(params).await?;
    
    Ok(Json(ApiResponse::success(users)))
}

/// Create product handler
pub async fn create_product(
    State(state): State<AppState>,
    Json(request): Json<CreateProductRequest>,
) -> Result<(StatusCode, Json<ApiResponse<Product>>)> {
    let product_repo = std::sync::Arc::new(crate::database::PostgresRepository::new(state.db_pool));
    let product_service = ProductService::new(product_repo);
    
    let product = product_service.create_product(request).await?;
    
    Ok((StatusCode::CREATED, Json(ApiResponse::success(product))))
}

/// Get product handler
pub async fn get_product(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<Json<ApiResponse<Product>>> {
    let product_repo = std::sync::Arc::new(crate::database::PostgresRepository::new(state.db_pool));
    let product_service = ProductService::new(product_repo);
    
    let product = product_service.get_product(id).await?;
    
    Ok(Json(ApiResponse::success(product)))
}

/// Create order handler
pub async fn create_order(
    State(state): State<AppState>,
    Json(request): Json<CreateOrderRequest>,
) -> Result<(StatusCode, Json<ApiResponse<Order>>)> {
    let order_repo = std::sync::Arc::new(crate::database::PostgresRepository::new(state.db_pool.clone()));
    let product_repo = std::sync::Arc::new(crate::database::PostgresRepository::new(state.db_pool.clone()));
    let user_repo = std::sync::Arc::new(crate::database::PostgresRepository::new(state.db_pool));
    
    let product_service = ProductService::new(product_repo);
    let user_service = UserService::new(user_repo);
    let order_service = OrderService::new(order_repo, product_service, user_service);
    
    let order = order_service.create_order(request).await?;
    
    Ok((StatusCode::CREATED, Json(ApiResponse::success(order))))
}

/// Get order handler
pub async fn get_order(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<Json<ApiResponse<Order>>> {
    let order_repo = std::sync::Arc::new(crate::database::PostgresRepository::new(state.db_pool.clone()));
    let product_repo = std::sync::Arc::new(crate::database::PostgresRepository::new(state.db_pool.clone()));
    let user_repo = std::sync::Arc::new(crate::database::PostgresRepository::new(state.db_pool));
    
    let product_service = ProductService::new(product_repo);
    let user_service = UserService::new(user_repo);
    let order_service = OrderService::new(order_repo, product_service, user_service);
    
    let order = order_service.get_order(id).await?;
    
    Ok(Json(ApiResponse::success(order)))
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::{
        body::Body,
        http::{Request, StatusCode},
        Router,
    };
    use tower::ServiceExt;
    use testing_framework::{
        integration::{TestEnvironment, http::TestClient},
        fixtures::TestUser,
        assertions::http::*,
    };

    fn create_test_app(state: AppState) -> Router {
        Router::new()
            .route("/health", axum::routing::get(health_check))
            .route("/users", axum::routing::post(create_user))
            .route("/users/:id", axum::routing::get(get_user))
            .route("/users/:id", axum::routing::put(update_user))
            .route("/users/:id", axum::routing::delete(delete_user))
            .route("/users", axum::routing::get(list_users))
            .route("/products", axum::routing::post(create_product))
            .route("/products/:id", axum::routing::get(get_product))
            .route("/orders", axum::routing::post(create_order))
            .route("/orders/:id", axum::routing::get(get_order))
            .with_state(state)
    }

    #[tokio::test]
    async fn test_health_check() {
        let config = crate::AppConfig::default();
        let pool = sqlx::PgPool::connect(&config.database_url).await.unwrap();
        let state = AppState {
            config,
            db_pool: pool,
        };
        
        let app = create_test_app(state);
        
        let response = app
            .oneshot(Request::builder().uri("/health").body(Body::empty()).unwrap())
            .await
            .unwrap();
        
        assert_eq!(response.status(), StatusCode::OK);
    }

    #[tokio::test]
    async fn test_create_user_integration() {
        let mut test_env = TestEnvironment::new();
        let (host, port) = test_env.start_postgres("test_db").await.unwrap();
        
        let database_url = format!("postgres://postgres:postgres@{}:{}/postgres", host, port);
        let pool = testing_framework::database::setup_test_database(&database_url).await.unwrap();
        crate::database::run_migrations(&pool).await.unwrap();
        
        let config = crate::AppConfig {
            database_url,
            ..Default::default()
        };
        
        let state = AppState {
            config,
            db_pool: pool,
        };
        
        let app = create_test_app(state);
        
        let test_user = TestUser::fake();
        let create_request = CreateUserRequest {
            name: test_user.name.clone(),
            email: test_user.email.clone(),
        };
        
        let response = app
            .oneshot(
                Request::builder()
                    .uri("/users")
                    .method("POST")
                    .header("content-type", "application/json")
                    .body(Body::from(serde_json::to_string(&create_request).unwrap()))
                    .unwrap(),
            )
            .await
            .unwrap();
        
        assert_eq!(response.status(), StatusCode::CREATED);
        
        let body = axum::body::to_bytes(response.into_body(), usize::MAX).await.unwrap();
        let api_response: ApiResponse<User> = serde_json::from_slice(&body).unwrap();
        
        assert!(api_response.success);
        assert!(api_response.data.is_some());
        
        let created_user = api_response.data.unwrap();
        assert_eq!(created_user.name, test_user.name);
        assert_eq!(created_user.email, test_user.email);
    }

    #[tokio::test]
    async fn test_create_user_validation_error() {
        let config = crate::AppConfig::default();
        let pool = sqlx::PgPool::connect(&config.database_url).await.unwrap();
        let state = AppState {
            config,
            db_pool: pool,
        };
        
        let app = create_test_app(state);
        
        let invalid_request = CreateUserRequest {
            name: "Test User".to_string(),
            email: "invalid-email".to_string(), // Invalid email format
        };
        
        let response = app
            .oneshot(
                Request::builder()
                    .uri("/users")
                    .method("POST")
                    .header("content-type", "application/json")
                    .body(Body::from(serde_json::to_string(&invalid_request).unwrap()))
                    .unwrap(),
            )
            .await
            .unwrap();
        
        assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    }
}