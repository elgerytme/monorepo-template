//! Example web service demonstrating observability integration
//! 
//! This service shows how to integrate the observability library
//! with a web application, including metrics, logging, and tracing.

use axum::{
    extract::Path,
    http::StatusCode,
    response::Json,
    routing::{get, post},
    Router,
};
use observability::{
    metrics::{record_http_request, record_feature_usage},
    tracing::{create_http_span, record_attributes},
    ObservabilityManager,
};
use serde::{Deserialize, Serialize};
use std::time::{Duration, Instant};
use tower_http::trace::TraceLayer;
use tracing::Instrument;

#[derive(clap::Parser)]
struct Args {
    #[arg(long, default_value = "3000")]
    port: u16,
    
    #[arg(long, default_value = "config/observability.toml")]
    config: String,
}

#[derive(Serialize, Deserialize)]
struct User {
    id: u32,
    name: String,
    email: String,
}

#[derive(Serialize, Deserialize)]
struct CreateUserRequest {
    name: String,
    email: String,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let args = clap::Parser::parse();

    // Initialize observability
    let mut observability = ObservabilityManager::new(Some(&args.config)).await?;
    observability.start().await?;

    tracing::info!("Starting web service with observability");

    // Build the application router
    let app = Router::new()
        .route("/", get(health_check))
        .route("/users/:id", get(get_user))
        .route("/users", post(create_user))
        .route("/metrics", get(metrics_endpoint))
        .layer(TraceLayer::new_for_http());

    // Start the server
    let listener = tokio::net::TcpListener::bind(format!("0.0.0.0:{}", args.port)).await?;
    
    tracing::info!(port = args.port, "Web service started");

    // Graceful shutdown handling
    let server = axum::serve(listener, app);
    
    tokio::select! {
        result = server => {
            if let Err(e) = result {
                tracing::error!(error = %e, "Server error");
            }
        }
        _ = tokio::signal::ctrl_c() => {
            tracing::info!("Shutdown signal received");
        }
    }

    // Shutdown observability
    observability.shutdown().await?;
    
    Ok(())
}

/// Health check endpoint
async fn health_check() -> Json<serde_json::Value> {
    let start = Instant::now();
    
    // Create a span for this operation
    let span = create_http_span("GET", "/", None);
    
    async move {
        record_feature_usage("health_check");
        
        let response = serde_json::json!({
            "status": "healthy",
            "timestamp": chrono::Utc::now().to_rfc3339(),
            "service": "observability-web-service",
            "version": "0.1.0"
        });

        // Record metrics
        let duration = start.elapsed();
        record_http_request("GET", "/", 200, duration);

        tracing::info!(
            duration_ms = duration.as_millis(),
            "Health check completed"
        );

        Json(response)
    }
    .instrument(span)
    .await
}

/// Get user by ID
async fn get_user(Path(user_id): Path<u32>) -> Result<Json<User>, StatusCode> {
    let start = Instant::now();
    
    // Create a span for this operation
    let span = create_http_span("GET", "/users/:id", None);
    
    async move {
        record_attributes(&[("user.id", &user_id.to_string())]);
        record_feature_usage("get_user");

        // Simulate database lookup
        tokio::time::sleep(Duration::from_millis(50)).await;

        let user = User {
            id: user_id,
            name: format!("User {}", user_id),
            email: format!("user{}@example.com", user_id),
        };

        // Record metrics
        let duration = start.elapsed();
        record_http_request("GET", "/users/:id", 200, duration);

        tracing::info!(
            user_id = user_id,
            duration_ms = duration.as_millis(),
            "User retrieved successfully"
        );

        Ok(Json(user))
    }
    .instrument(span)
    .await
}

/// Create a new user
async fn create_user(Json(request): Json<CreateUserRequest>) -> Result<Json<User>, StatusCode> {
    let start = Instant::now();
    
    // Create a span for this operation
    let span = create_http_span("POST", "/users", None);
    
    async move {
        record_attributes(&[
            ("user.name", &request.name),
            ("user.email", &request.email),
        ]);
        record_feature_usage("create_user");

        // Simulate user creation
        tokio::time::sleep(Duration::from_millis(100)).await;

        let user = User {
            id: rand::random::<u32>() % 10000,
            name: request.name,
            email: request.email,
        };

        // Record metrics
        let duration = start.elapsed();
        record_http_request("POST", "/users", 201, duration);

        tracing::info!(
            user_id = user.id,
            duration_ms = duration.as_millis(),
            "User created successfully"
        );

        Ok(Json(user))
    }
    .instrument(span)
    .await
}

/// Metrics endpoint (returns Prometheus metrics)
async fn metrics_endpoint() -> String {
    // In a real implementation, this would return the actual Prometheus metrics
    // For now, return a simple response
    "# Metrics endpoint - see :9090/metrics for actual Prometheus metrics\n".to_string()
}