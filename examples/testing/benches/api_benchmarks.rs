//! Performance benchmarks for the testing examples API

use criterion::{black_box, criterion_group, criterion_main, Criterion, BenchmarkId, Throughput};
use testing_framework::{
    performance::{benchmark_async, load::*},
    integration::{TestEnvironment, http::TestClient},
    fixtures::TestUser,
};
use testing_examples::{
    models::{CreateUserRequest, CreateProductRequest},
    AppConfig, AppState, handlers::*,
    database::run_migrations,
};
use axum::{Router, routing::{get, post}};
use std::time::Duration;
use tokio::runtime::Runtime;

/// Benchmark user creation endpoint
fn bench_create_user(c: &mut Criterion) {
    let rt = Runtime::new().unwrap();
    
    // Setup test environment
    let (app, _cleanup) = rt.block_on(async {
        let mut test_env = TestEnvironment::new();
        let (host, port) = test_env.start_postgres("bench_db").await.unwrap();
        
        let database_url = format!("postgres://postgres:postgres@{}:{}/postgres", host, port);
        let pool = testing_framework::database::setup_test_database(&database_url).await.unwrap();
        run_migrations(&pool).await.unwrap();
        
        let config = AppConfig {
            database_url,
            port: 0, // Let the system assign a port
            ..Default::default()
        };
        
        let state = AppState {
            config,
            db_pool: pool,
        };
        
        let app = Router::new()
            .route("/users", post(create_user))
            .with_state(state);
        
        (app, test_env)
    });

    let mut group = c.benchmark_group("api_endpoints");
    group.throughput(Throughput::Elements(1));
    
    group.bench_function("create_user", |b| {
        b.to_async(&rt).iter(|| async {
            let test_user = TestUser::fake();
            let request = CreateUserRequest {
                name: test_user.name,
                email: test_user.email,
            };
            
            let response = app
                .clone()
                .oneshot(
                    axum::http::Request::builder()
                        .uri("/users")
                        .method("POST")
                        .header("content-type", "application/json")
                        .body(axum::body::Body::from(
                            serde_json::to_string(&request).unwrap()
                        ))
                        .unwrap(),
                )
                .await
                .unwrap();
            
            black_box(response)
        });
    });
    
    group.finish();
}

/// Benchmark database operations
fn bench_database_operations(c: &mut Criterion) {
    let rt = Runtime::new().unwrap();
    
    let (user_service, _cleanup) = rt.block_on(async {
        let mut test_env = TestEnvironment::new();
        let (host, port) = test_env.start_postgres("bench_db").await.unwrap();
        
        let database_url = format!("postgres://postgres:postgres@{}:{}/postgres", host, port);
        let pool = testing_framework::database::setup_test_database(&database_url).await.unwrap();
        run_migrations(&pool).await.unwrap();
        
        let user_repo = std::sync::Arc::new(
            testing_examples::database::PostgresRepository::new(pool)
        );
        let user_service = testing_examples::services::UserService::new(user_repo);
        
        (user_service, test_env)
    });

    let mut group = c.benchmark_group("database_operations");
    group.throughput(Throughput::Elements(1));
    
    group.bench_function("user_crud", |b| {
        b.to_async(&rt).iter(|| async {
            let test_user = TestUser::fake();
            let request = CreateUserRequest {
                name: test_user.name,
                email: test_user.email,
            };
            
            // Create user
            let created_user = user_service.create_user(request).await.unwrap();
            
            // Read user
            let _read_user = user_service.get_user(created_user.id).await.unwrap();
            
            // Delete user
            user_service.delete_user(created_user.id).await.unwrap();
            
            black_box(created_user)
        });
    });
    
    group.finish();
}

/// Benchmark serialization performance
fn bench_serialization(c: &mut Criterion) {
    let test_user = TestUser::fake();
    
    let mut group = c.benchmark_group("serialization");
    group.throughput(Throughput::Elements(1));
    
    group.bench_function("json_serialize", |b| {
        b.iter(|| {
            let json = serde_json::to_string(&test_user).unwrap();
            black_box(json)
        });
    });
    
    group.bench_function("json_deserialize", |b| {
        let json = serde_json::to_string(&test_user).unwrap();
        b.iter(|| {
            let user: TestUser = serde_json::from_str(&json).unwrap();
            black_box(user)
        });
    });
    
    group.finish();
}

/// Load test example
fn bench_load_test(c: &mut Criterion) {
    let rt = Runtime::new().unwrap();
    
    c.bench_function("load_test_example", |b| {
        b.to_async(&rt).iter(|| async {
            let config = LoadTestConfig {
                concurrent_users: 5,
                duration: Duration::from_millis(100),
                ramp_up_time: Duration::from_millis(10),
                requests_per_second: Some(50.0),
            };
            
            let results = run_load_test(config, || async {
                // Simulate some work
                tokio::time::sleep(Duration::from_millis(1)).await;
                Ok(())
            }).await.unwrap();
            
            black_box(results)
        });
    });
}

/// Memory usage benchmark
fn bench_memory_usage(c: &mut Criterion) {
    let rt = Runtime::new().unwrap();
    
    c.bench_function("memory_usage", |b| {
        b.to_async(&rt).iter(|| async {
            use testing_framework::performance::memory::track_memory_usage;
            
            let (result, memory_used) = track_memory_usage(|| async {
                // Create a bunch of test data
                let users: Vec<TestUser> = (0..1000).map(|_| TestUser::fake()).collect();
                Ok(users.len())
            }).await.unwrap();
            
            black_box((result, memory_used))
        });
    });
}

/// Async benchmark example
fn bench_async_operations(c: &mut Criterion) {
    let rt = Runtime::new().unwrap();
    
    c.bench_function("async_benchmark_example", |b| {
        b.to_async(&rt).iter(|| async {
            let result = benchmark_async(
                "test_operation",
                10,
                || async {
                    tokio::time::sleep(Duration::from_millis(1)).await;
                    Ok(42)
                }
            ).await.unwrap();
            
            black_box(result)
        });
    });
}

criterion_group!(
    benches,
    bench_create_user,
    bench_database_operations,
    bench_serialization,
    bench_load_test,
    bench_memory_usage,
    bench_async_operations
);

criterion_main!(benches);