//! Web service binary for testing examples

use testing_examples::{AppConfig, AppState, handlers::*, database::run_migrations};
use axum::{
    routing::{get, post, put, delete},
    Router,
};
use tower_http::{cors::CorsLayer, trace::TraceLayer};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};
use std::net::SocketAddr;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize tracing
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "testing_examples=debug,tower_http=debug".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    // Load configuration
    let config = AppConfig::default();
    
    // Connect to database
    let db_pool = sqlx::postgres::PgPoolOptions::new()
        .max_connections(10)
        .connect(&config.database_url)
        .await?;

    // Run migrations
    run_migrations(&db_pool).await?;

    // Create application state
    let state = AppState {
        config: config.clone(),
        db_pool,
    };

    // Build application router
    let app = Router::new()
        // Health check
        .route("/health", get(health_check))
        
        // User routes
        .route("/users", post(create_user))
        .route("/users", get(list_users))
        .route("/users/:id", get(get_user))
        .route("/users/:id", put(update_user))
        .route("/users/:id", delete(delete_user))
        
        // Product routes
        .route("/products", post(create_product))
        .route("/products/:id", get(get_product))
        
        // Order routes
        .route("/orders", post(create_order))
        .route("/orders/:id", get(get_order))
        
        // Add middleware
        .layer(CorsLayer::permissive())
        .layer(TraceLayer::new_for_http())
        
        // Add state
        .with_state(state);

    // Start server
    let addr = SocketAddr::from(([0, 0, 0, 0], config.port));
    tracing::info!("Starting server on {}", addr);
    
    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}