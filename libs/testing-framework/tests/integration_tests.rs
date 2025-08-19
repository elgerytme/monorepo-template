//! Integration tests for the testing framework

use testing_framework::*;
use std::time::Duration;

integration_test!(test_complete_integration_workflow, async {
    init_test_logging();
    
    // Test container management
    let mut container_manager = containers::ContainerManager::new();
    let postgres_url = container_manager.start_postgres("test_integration_db").await?;
    
    // Test database helper
    let db_helper = helpers::DatabaseTestHelper::new(&postgres_url).await?;
    
    // Create test schema
    db_helper.execute(r#"
        CREATE TABLE IF NOT EXISTS test_users (
            id UUID PRIMARY KEY,
            email VARCHAR NOT NULL,
            name VARCHAR NOT NULL,
            created_at TIMESTAMP WITH TIME ZONE NOT NULL
        )
    "#).await?;
    
    // Test fixture management
    let mut fixture_manager = fixtures::FixtureManager::new();
    let test_user = fixtures::TestUser::random();
    fixture_manager.add("test_user", &test_user)?;
    
    // Insert test data
    db_helper.execute(&format!(
        "INSERT INTO test_users (id, email, name, created_at) VALUES ('{}', '{}', '{}', '{}')",
        test_user.id, test_user.email, test_user.name, test_user.created_at.format("%Y-%m-%d %H:%M:%S%.3f%z")
    )).await?;
    
    // Verify data was inserted
    let rows = db_helper.fetch_all("SELECT * FROM test_users").await?;
    assert_eq!(rows.len(), 1);
    
    // Test API client with mock server
    let mock_server = helpers::MockHttpServer::start().await;
    mock_server.mock_get("/users", r#"[{"id": "123", "name": "Test User"}]"#, 200).await;
    
    let api_client = helpers::ApiTestClient::new(&mock_server.uri());
    let response = api_client.get("/users").await?;
    assert_eq!(response.status(), 200);
    
    // Test file system operations
    let fs_helper = helpers::FileSystemTestHelper::new()?;
    fs_helper.create_file("test-config.json", r#"{"test": true}"#).await?;
    let content = fs_helper.read_file("test-config.json").await?;
    assert!(content.contains("test"));
    
    // Cleanup
    db_helper.cleanup().await?;
    
    Ok(())
});

integration_test!(test_performance_testing_integration, async {
    let config = performance::PerformanceConfig {
        warmup_time: Duration::from_millis(100),
        measurement_time: Duration::from_millis(200),
        sample_size: 5,
        throughput_elements: Some(100),
    };
    
    let runner = performance::PerformanceRunner::new(config);
    
    // Test async performance measurement
    let duration = runner.benchmark_async("test_async_operation", || async {
        tokio::time::sleep(Duration::from_millis(1)).await;
    }).await;
    
    assert!(duration >= Duration::from_millis(1));
    
    // Test load testing
    let load_tester = performance::LoadTester::new(2, Duration::from_millis(200));
    let result = load_tester.run_load_test(|| async {
        tokio::time::sleep(Duration::from_millis(5)).await;
        Ok(Duration::from_millis(5))
    }).await;
    
    assert!(result.total_requests > 0);
    assert_eq!(result.concurrent_users, 2);
    
    Ok(())
});

integration_test!(test_security_testing_integration, async {
    let config = security::SecurityConfig {
        vulnerability_scanning: true,
        dependency_audit: true,
        secret_detection: true,
        container_scanning: false, // Skip for integration test
        static_analysis: true,
        penetration_testing: false,
    };
    
    let security_tester = security::SecurityTester::new(config);
    let results = security_tester.run_all_tests().await?;
    
    // Verify we got results for each enabled test
    assert!(!results.is_empty());
    
    // Generate security report
    let report = security_tester.generate_report(&results);
    assert!(report.contains("Security Test Report"));
    
    Ok(())
});

integration_test!(test_retry_and_timing_helpers, async {
    // Test retry helper
    let mut attempt_count = 0;
    let result = helpers::retry_async(
        || {
            attempt_count += 1;
            async move {
                if attempt_count < 3 {
                    Err("Not ready")
                } else {
                    Ok("Success")
                }
            }
        },
        5,
        Duration::from_millis(10),
    ).await;
    
    assert_eq!(result, Ok("Success"));
    assert_eq!(attempt_count, 3);
    
    // Test timing utilities
    let timer = helpers::TestTimer::start();
    tokio::time::sleep(Duration::from_millis(50)).await;
    
    timer.assert_elapsed_more_than(Duration::from_millis(40))?;
    timer.assert_elapsed_less_than(Duration::from_millis(100))?;
    
    Ok(())
});

integration_test!(test_eventual_consistency_helper, async {
    let mut counter = 0;
    
    helpers::assert_eventually(
        || {
            counter += 1;
            counter >= 3
        },
        Duration::from_secs(1),
        Duration::from_millis(10),
        "Counter should reach 3",
    ).await?;
    
    assert!(counter >= 3);
    
    Ok(())
});

// Property-based testing example
#[cfg(test)]
mod property_tests {
    use super::*;
    use proptest::prelude::*;
    
    proptest! {
        #[test]
        fn test_user_email_generation(prefix in "[a-zA-Z]{1,10}") {
            let email = fixtures::TestDataGenerator::email(&prefix);
            assert!(email.starts_with(&prefix));
            assert!(email.contains("@example.com"));
        }
        
        #[test]
        fn test_json_payload_generation(size in 1usize..100) {
            let payload = fixtures::TestDataGenerator::json_payload(size);
            if let serde_json::Value::Object(map) = payload {
                assert_eq!(map.len(), size);
            } else {
                panic!("Expected JSON object");
            }
        }
    }
}

// Benchmark tests using criterion
#[cfg(test)]
mod benchmarks {
    use super::*;
    use criterion::{criterion_group, criterion_main, Criterion};
    
    fn benchmark_user_creation(c: &mut Criterion) {
        c.bench_function("create_random_user", |b| {
            b.iter(|| fixtures::TestUser::random())
        });
    }
    
    fn benchmark_json_generation(c: &mut Criterion) {
        c.bench_function("generate_json_payload", |b| {
            b.iter(|| fixtures::TestDataGenerator::json_payload(100))
        });
    }
    
    criterion_group!(benches, benchmark_user_creation, benchmark_json_generation);
    criterion_main!(benches);
}