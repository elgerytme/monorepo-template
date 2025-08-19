use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    response::Json,
    routing::{get, post},
    Router,
};
use metrics::{counter, histogram, gauge};
use serde::{Deserialize, Serialize};
use std::{collections::HashMap, sync::Arc, time::Instant};
use tokio::sync::RwLock;
use tower_http::{cors::CorsLayer, trace::TraceLayer};
use tracing::{info, warn, error, instrument};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
struct User {
    id: Uuid,
    name: String,
    email: String,
    created_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Deserialize)]
struct CreateUserRequest {
    name: String,
    email: String,
}

#[derive(Debug, Deserialize)]
struct UserQuery {
    limit: Option<usize>,
    offset: Option<usize>,
}

type UserStore = Arc<RwLock<HashMap<Uuid, User>>>;

#[derive(Clone)]
struct AppState {
    users: UserStore,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Initialize tracing
    init_tracing()?;
    
    // Initialize metrics
    init_metrics();
    
    info!("Starting example web service");
    
    let state = AppState {
        users: Arc::new(RwLock::new(HashMap::new())),
    };
    
    let app = Router::new()
        .route("/health", get(health_check))
        .route("/metrics", get(metrics_handler))
        .route("/users", get(list_users).post(create_user))
        .route("/users/:id", get(get_user))
        .layer(TraceLayer::new_for_http())
        .layer(CorsLayer::permissive())
        .with_state(state);
    
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await?;
    info!("Server listening on {}", listener.local_addr()?);
    
    axum::serve(listener, app).await?;
    
    Ok(())
}

fn init_tracing() -> anyhow::Result<()> {
    use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};
    
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "example_web_service=debug,tower_http=debug".into()),
        )
        .with(tracing_subscriber::fmt::layer().json())
        .init();
    
    Ok(())
}

fn init_metrics() {
    let recorder = metrics_exporter_prometheus::PrometheusBuilder::new()
        .build_recorder();
    metrics::set_boxed_recorder(Box::new(recorder))
        .expect("Failed to install Prometheus recorder");
}

#[instrument]
async fn health_check() -> Json<serde_json::Value> {
    counter!("health_checks_total").increment(1);
    
    Json(serde_json::json!({
        "status": "healthy",
        "timestamp": chrono::Utc::now(),
        "service": "example-web-service",
        "version": env!("CARGO_PKG_VERSION")
    }))
}

async fn metrics_handler() -> String {
    let recorder = metrics_exporter_prometheus::PrometheusBuilder::new()
        .build_recorder();
    recorder.render()
}

#[instrument(skip(state))]
async fn list_users(
    State(state): State<AppState>,
    Query(params): Query<UserQuery>,
) -> Json<Vec<User>> {
    let start = Instant::now();
    counter!("users_list_requests_total").increment(1);
    
    let users = state.users.read().await;
    let mut user_list: Vec<User> = users.values().cloned().collect();
    
    // Sort by creation time
    user_list.sort_by(|a, b| b.created_at.cmp(&a.created_at));
    
    // Apply pagination
    let offset = params.offset.unwrap_or(0);
    let limit = params.limit.unwrap_or(10).min(100); // Cap at 100
    
    let paginated_users: Vec<User> = user_list
        .into_iter()
        .skip(offset)
        .take(limit)
        .collect();
    
    histogram!("users_list_duration_seconds").record(start.elapsed().as_secs_f64());
    gauge!("users_total_count").set(users.len() as f64);
    
    info!(
        user_count = paginated_users.len(),
        total_users = users.len(),
        "Listed users"
    );
    
    Json(paginated_users)
}

#[instrument(skip(state))]
async fn create_user(
    State(state): State<AppState>,
    Json(payload): Json<CreateUserRequest>,
) -> Result<(StatusCode, Json<User>), StatusCode> {
    let start = Instant::now();
    counter!("users_create_requests_total").increment(1);
    
    // Basic validation
    if payload.name.trim().is_empty() || payload.email.trim().is_empty() {
        counter!("users_create_validation_errors_total").increment(1);
        warn!(name = %payload.name, email = %payload.email, "Invalid user data");
        return Err(StatusCode::BAD_REQUEST);
    }
    
    let user = User {
        id: Uuid::new_v4(),
        name: payload.name.trim().to_string(),
        email: payload.email.trim().to_lowercase(),
        created_at: chrono::Utc::now(),
    };
    
    let mut users = state.users.write().await;
    
    // Check for duplicate email
    if users.values().any(|u| u.email == user.email) {
        counter!("users_create_duplicate_errors_total").increment(1);
        warn!(email = %user.email, "Duplicate email attempted");
        return Err(StatusCode::CONFLICT);
    }
    
    users.insert(user.id, user.clone());
    
    histogram!("users_create_duration_seconds").record(start.elapsed().as_secs_f64());
    gauge!("users_total_count").set(users.len() as f64);
    counter!("users_created_total").increment(1);
    
    info!(
        user_id = %user.id,
        user_name = %user.name,
        user_email = %user.email,
        "Created new user"
    );
    
    Ok((StatusCode::CREATED, Json(user)))
}

#[instrument(skip(state))]
async fn get_user(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<Json<User>, StatusCode> {
    let start = Instant::now();
    counter!("users_get_requests_total").increment(1);
    
    let users = state.users.read().await;
    
    match users.get(&id) {
        Some(user) => {
            histogram!("users_get_duration_seconds").record(start.elapsed().as_secs_f64());
            counter!("users_get_success_total").increment(1);
            
            info!(user_id = %id, "Retrieved user");
            Ok(Json(user.clone()))
        }
        None => {
            counter!("users_get_not_found_total").increment(1);
            warn!(user_id = %id, "User not found");
            Err(StatusCode::NOT_FOUND)
        }
    }
}