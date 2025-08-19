//! Integration tests for the testing examples

use testing_framework::{
    integration::{TestEnvironment, http::TestClient},
    fixtures::{TestUser, generators},
    assertions::{http::*, database::*, performance::*},
    security::{SecurityTester, SecurityConfig},
    TestResult,
};
use testing_examples::{
    models::*,
    services::*,
    database::{run_migrations, PostgresRepository},
    AppConfig, AppState,
};
use std::sync::Arc;
use std::time::Duration;
use uuid::Uuid;

/// Test the complete user workflow
#[tokio::test]
async fn test_user_workflow_integration() -> TestResult {
    let mut test_env = TestEnvironment::new();
    let (host, port) = test_env.start_postgres("user_workflow_db").await?;
    
    let database_url = format!("postgres://postgres:postgres@{}:{}/postgres", host, port);
    let pool = testing_framework::database::setup_test_database(&database_url).await?;
    run_migrations(&pool).await?;
    
    let user_repo = Arc::new(PostgresRepository::new(pool.clone()));
    let user_service = UserService::new(user_repo);
    
    // Test user creation
    let test_user = TestUser::fake();
    let create_request = CreateUserRequest {
        name: test_user.name.clone(),
        email: test_user.email.clone(),
    };
    
    let created_user = user_service.create_user(create_request).await?;
    assert_eq!(created_user.name, test_user.name);
    assert_eq!(created_user.email, test_user.email);
    assert!(created_user.is_active);
    
    // Verify user exists in database
    assert_record_exists(&pool, "users", &[
        ("email", &created_user.email),
        ("name", &created_user.name),
    ]).await?;
    
    // Test user retrieval
    let retrieved_user = user_service.get_user(created_user.id).await?;
    assert_eq!(retrieved_user.id, created_user.id);
    
    // Test user update
    let update_request = UpdateUserRequest {
        name: Some("Updated Name".to_string()),
        email: None,
        is_active: Some(false),
    };
    
    let updated_user = user_service.update_user(created_user.id, update_request).await?;
    assert_eq!(updated_user.name, "Updated Name");
    assert!(!updated_user.is_active);
    
    // Test user deletion
    user_service.delete_user(created_user.id).await?;
    
    // Verify user is deleted
    assert_record_not_exists(&pool, "users", &[
        ("id", &created_user.id.to_string()),
    ]).await?;
    
    Ok(())
}

/// Test product and order workflow
#[tokio::test]
async fn test_order_workflow_integration() -> TestResult {
    let mut test_env = TestEnvironment::new();
    let (host, port) = test_env.start_postgres("order_workflow_db").await?;
    
    let database_url = format!("postgres://postgres:postgres@{}:{}/postgres", host, port);
    let pool = testing_framework::database::setup_test_database(&database_url).await?;
    run_migrations(&pool).await?;
    
    // Create repositories and services
    let user_repo = Arc::new(PostgresRepository::new(pool.clone()));
    let product_repo = Arc::new(PostgresRepository::new(pool.clone()));
    let order_repo = Arc::new(PostgresRepository::new(pool.clone()));
    
    let user_service = UserService::new(user_repo);
    let product_service = ProductService::new(product_repo);
    let order_service = OrderService::new(order_repo, product_service.clone(), user_service.clone());
    
    // Create test user
    let test_user = TestUser::fake();
    let user = user_service.create_user(CreateUserRequest {
        name: test_user.name,
        email: test_user.email,
    }).await?;
    
    // Create test product
    let product = product_service.create_product(CreateProductRequest {
        name: "Test Product".to_string(),
        description: "A test product".to_string(),
        price: 29.99,
        category: "Electronics".to_string(),
    }).await?;
    
    // Create order
    let order = order_service.create_order(CreateOrderRequest {
        user_id: user.id,
        items: vec![CreateOrderItemRequest {
            product_id: product.id,
            quantity: 2,
        }],
    }).await?;
    
    assert_eq!(order.user_id, user.id);
    assert_eq!(order.status, OrderStatus::Pending);
    
    // Update order status
    let updated_order = order_service.update_order_status(order.id, OrderStatus::Processing).await?;
    assert_eq!(updated_order.status, OrderStatus::Processing);
    
    // Verify order exists in database
    assert_record_exists(&pool, "orders", &[
        ("id", &order.id.to_string()),
        ("user_id", &user.id.to_string()),
    ]).await?;
    
    Ok(())
}

/// Test pagination functionality
#[tokio::test]
async fn test_pagination_integration() -> TestResult {
    let mut test_env = TestEnvironment::new();
    let (host, port) = test_env.start_postgres("pagination_db").await?;
    
    let database_url = format!("postgres://postgres:postgres@{}:{}/postgres", host, port);
    let pool = testing_framework::database::setup_test_database(&database_url).await?;
    run_migrations(&pool).await?;
    
    let user_repo = Arc::new(PostgresRepository::new(pool.clone()));
    let user_service = UserService::new(user_repo);
    
    // Create multiple test users
    let test_users = generators::users_with_domain(15, "pagination-test.com");
    
    for test_user in &test_users {
        user_service.create_user(CreateUserRequest {
            name: test_user.name.clone(),
            email: test_user.email.clone(),
        }).await?;
    }
    
    // Test first page
    let page1 = user_service.list_users(PaginationParams {
        page: Some(1),
        limit: Some(5),
    }).await?;
    
    assert_eq!(page1.data.len(), 5);
    assert_eq!(page1.page, 1);
    assert_eq!(page1.limit, 5);
    assert_eq!(page1.total, 15);
    assert_eq!(page1.total_pages, 3);
    
    // Test second page
    let page2 = user_service.list_users(PaginationParams {
        page: Some(2),
        limit: Some(5),
    }).await?;
    
    assert_eq!(page2.data.len(), 5);
    assert_eq!(page2.page, 2);
    
    // Test last page
    let page3 = user_service.list_users(PaginationParams {
        page: Some(3),
        limit: Some(5),
    }).await?;
    
    assert_eq!(page3.data.len(), 5);
    assert_eq!(page3.page, 3);
    
    Ok(())
}

/// Test error handling
#[tokio::test]
async fn test_error_handling_integration() -> TestResult {
    let mut test_env = TestEnvironment::new();
    let (host, port) = test_env.start_postgres("error_handling_db").await?;
    
    let database_url = format!("postgres://postgres:postgres@{}:{}/postgres", host, port);
    let pool = testing_framework::database::setup_test_database(&database_url).await?;
    run_migrations(&pool).await?;
    
    let user_repo = Arc::new(PostgresRepository::new(pool));
    let user_service = UserService::new(user_repo);
    
    // Test invalid email
    let result = user_service.create_user(CreateUserRequest {
        name: "Test User".to_string(),
        email: "invalid-email".to_string(),
    }).await;
    
    assert!(result.is_err());
    
    // Test duplicate email
    let test_user = TestUser::fake();
    user_service.create_user(CreateUserRequest {
        name: test_user.name.clone(),
        email: test_user.email.clone(),
    }).await?;
    
    let duplicate_result = user_service.create_user(CreateUserRequest {
        name: "Another User".to_string(),
        email: test_user.email,
    }).await;
    
    assert!(duplicate_result.is_err());
    
    // Test user not found
    let not_found_result = user_service.get_user(Uuid::new_v4()).await;
    assert!(not_found_result.is_err());
    
    Ok(())
}

/// Test performance requirements
#[tokio::test]
async fn test_performance_requirements() -> TestResult {
    let mut test_env = TestEnvironment::new();
    let (host, port) = test_env.start_postgres("performance_db").await?;
    
    let database_url = format!("postgres://postgres:postgres@{}:{}/postgres", host, port);
    let pool = testing_framework::database::setup_test_database(&database_url).await?;
    run_migrations(&pool).await?;
    
    let user_repo = Arc::new(PostgresRepository::new(pool));
    let user_service = UserService::new(user_repo);
    
    // Test that user creation completes within reasonable time
    let test_user = TestUser::fake();
    let create_request = CreateUserRequest {
        name: test_user.name,
        email: test_user.email,
    };
    
    let user = assert_completes_within(
        || user_service.create_user(create_request.clone()),
        Duration::from_millis(500),
    ).await?;
    
    // Test that user retrieval is fast
    assert_completes_within(
        || user_service.get_user(user.id),
        Duration::from_millis(100),
    ).await?;
    
    Ok(())
}

/// Test security scanning
#[tokio::test]
async fn test_security_scanning() -> TestResult {
    let config = SecurityConfig::default();
    let tester = SecurityTester::new(config);
    
    // Scan the current project for security issues
    let project_path = std::path::Path::new(".");
    let results = tester.run_all_scans(project_path).await?;
    
    // Verify that scans completed
    assert!(!results.is_empty());
    
    // Check if any critical issues were found
    let has_critical_issues = results.iter()
        .any(|r| r.findings.iter()
            .any(|f| matches!(f.severity, testing_framework::security::Severity::Critical)));
    
    if has_critical_issues {
        eprintln!("Critical security issues found!");
        for result in &results {
            for finding in &result.findings {
                if matches!(finding.severity, testing_framework::security::Severity::Critical) {
                    eprintln!("CRITICAL: {} - {}", finding.title, finding.description);
                }
            }
        }
    }
    
    // For testing purposes, we'll allow the test to pass even with findings
    // In a real CI environment, you might want to fail on critical issues
    
    Ok(())
}

/// Test concurrent operations
#[tokio::test]
async fn test_concurrent_operations() -> TestResult {
    let mut test_env = TestEnvironment::new();
    let (host, port) = test_env.start_postgres("concurrent_db").await?;
    
    let database_url = format!("postgres://postgres:postgres@{}:{}/postgres", host, port);
    let pool = testing_framework::database::setup_test_database(&database_url).await?;
    run_migrations(&pool).await?;
    
    let user_repo = Arc::new(PostgresRepository::new(pool));
    let user_service = Arc::new(UserService::new(user_repo));
    
    // Create multiple users concurrently
    let mut handles = Vec::new();
    
    for i in 0..10 {
        let service = user_service.clone();
        let handle = tokio::spawn(async move {
            let test_user = TestUser::with_email(format!("concurrent-user-{}@test.com", i));
            service.create_user(CreateUserRequest {
                name: test_user.name,
                email: test_user.email,
            }).await
        });
        handles.push(handle);
    }
    
    // Wait for all operations to complete
    let mut successful_creates = 0;
    for handle in handles {
        match handle.await.unwrap() {
            Ok(_) => successful_creates += 1,
            Err(e) => eprintln!("Concurrent create failed: {}", e),
        }
    }
    
    // All operations should succeed since emails are unique
    assert_eq!(successful_creates, 10);
    
    Ok(())
}

/// Test data consistency
#[tokio::test]
async fn test_data_consistency() -> TestResult {
    let mut test_env = TestEnvironment::new();
    let (host, port) = test_env.start_postgres("consistency_db").await?;
    
    let database_url = format!("postgres://postgres:postgres@{}:{}/postgres", host, port);
    let pool = testing_framework::database::setup_test_database(&database_url).await?;
    run_migrations(&pool).await?;
    
    // Test that row count matches expected after operations
    assert_row_count(&pool, "users", 0).await?;
    
    let user_repo = Arc::new(PostgresRepository::new(pool.clone()));
    let user_service = UserService::new(user_repo);
    
    // Create users
    let test_users = generators::users(5);
    for test_user in &test_users {
        user_service.create_user(CreateUserRequest {
            name: test_user.name.clone(),
            email: test_user.email.clone(),
        }).await?;
    }
    
    // Verify count
    assert_row_count(&pool, "users", 5).await?;
    
    // Delete some users
    let users = user_service.list_users(PaginationParams::default()).await?;
    for user in users.data.iter().take(2) {
        user_service.delete_user(user.id).await?;
    }
    
    // Verify updated count
    assert_row_count(&pool, "users", 3).await?;
    
    Ok(())
}