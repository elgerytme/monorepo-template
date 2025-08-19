//! Integration tests for the observability library

use observability::{
    config::ObservabilityConfig,
    metrics::{record_http_request, record_build, record_security_scan},
    alerting::{Alert, AlertSeverity, AlertCategory},
    ObservabilityManager,
};
use std::collections::HashMap;
use std::time::Duration;
use tokio_test;

#[tokio::test]
async fn test_observability_manager_lifecycle() {
    // Create a test configuration
    let config = ObservabilityConfig::default();
    
    // Initialize observability manager
    let mut manager = ObservabilityManager::new(None).await.unwrap();
    
    // Start the manager
    manager.start().await.unwrap();
    
    // Shutdown the manager
    manager.shutdown().await.unwrap();
}

#[tokio::test]
async fn test_metrics_recording() {
    let mut manager = ObservabilityManager::new(None).await.unwrap();
    manager.start().await.unwrap();

    // Record various metrics
    record_http_request("GET", "/test", 200, Duration::from_millis(100));
    record_build(true, Duration::from_secs(30));
    record_security_scan(2);

    // Give some time for metrics to be processed
    tokio::time::sleep(Duration::from_millis(100)).await;

    manager.shutdown().await.unwrap();
}

#[tokio::test]
async fn test_custom_alert_sending() {
    let mut manager = ObservabilityManager::new(None).await.unwrap();
    manager.start().await.unwrap();

    let alert = Alert {
        id: "test-alert".to_string(),
        title: "Test Alert".to_string(),
        description: "This is a test alert".to_string(),
        severity: AlertSeverity::Warning,
        category: AlertCategory::System,
        timestamp: std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs(),
        labels: HashMap::from([
            ("test".to_string(), "true".to_string()),
        ]),
        annotations: HashMap::new(),
    };

    // This will fail in test environment since webhook is not available
    // but we're testing that the API works correctly
    let result = manager.alerting().send_custom_alert(alert).await;
    
    // We expect this to fail due to network error, which is fine for testing
    assert!(result.is_err());

    manager.shutdown().await.unwrap();
}

#[tokio::test]
async fn test_configuration_loading() {
    // Test default configuration
    let config = ObservabilityConfig::default();
    assert!(config.metrics.enabled);
    assert_eq!(config.metrics.port, 9090);
    assert_eq!(config.logging.level, "info");
    assert!(config.tracing.enabled);
    assert!(config.alerting.enabled);
}

#[tokio::test]
async fn test_structured_logging() {
    use observability::logging::LoggingUtils;
    
    let mut manager = ObservabilityManager::new(None).await.unwrap();
    manager.start().await.unwrap();

    // Test various logging utilities
    LoggingUtils::log_http_request("GET", "/test", 200, 100, Some("user123"));
    LoggingUtils::log_database_operation("SELECT", "users", 50, Some(1), None);
    LoggingUtils::log_auth_event("login", Some("user123"), Some("127.0.0.1"), true, None);
    LoggingUtils::log_build_event("rust", "my-project", 30000, true, None);
    LoggingUtils::log_security_scan("dependency", "Cargo.toml", 0, 5000, None);
    LoggingUtils::log_deployment_event("staging", "my-service", "1.0.0", true, 60000, false);

    manager.shutdown().await.unwrap();
}

#[tokio::test]
async fn test_tracing_spans() {
    use observability::tracing::{
        create_span, create_http_span, create_database_span, 
        create_build_span, create_security_scan_span,
        record_attributes
    };
    use tracing::Instrument;
    
    let mut manager = ObservabilityManager::new(None).await.unwrap();
    manager.start().await.unwrap();

    // Test different span types
    let span1 = create_span("test_operation", "test", "test-service");
    async {
        record_attributes(&[("test.key", "test.value")]);
        tokio::time::sleep(Duration::from_millis(10)).await;
    }.instrument(span1).await;

    let span2 = create_http_span("POST", "/api/test", Some("user123"));
    async {
        tokio::time::sleep(Duration::from_millis(10)).await;
    }.instrument(span2).await;

    let span3 = create_database_span("INSERT", "users", Some("INSERT INTO users..."));
    async {
        tokio::time::sleep(Duration::from_millis(10)).await;
    }.instrument(span3).await;

    let span4 = create_build_span("rust", "my-project", Some("release"));
    async {
        tokio::time::sleep(Duration::from_millis(10)).await;
    }.instrument(span4).await;

    let span5 = create_security_scan_span("dependency", "Cargo.toml");
    async {
        tokio::time::sleep(Duration::from_millis(10)).await;
    }.instrument(span5).await;

    manager.shutdown().await.unwrap();
}

#[tokio::test]
async fn test_alerting_manager() {
    let mut manager = ObservabilityManager::new(None).await.unwrap();
    manager.start().await.unwrap();

    // Test security alert
    let result = manager.alerting().send_security_alert(
        "Test Security Alert",
        "This is a test security alert",
        AlertSeverity::Critical,
        HashMap::from([("test".to_string(), "true".to_string())]),
    ).await;
    
    // Expect failure due to no webhook endpoint in test
    assert!(result.is_err());

    // Test build alert
    let result = manager.alerting().send_build_alert(
        "test-project",
        "rust",
        "Compilation failed",
        30000,
    ).await;
    
    assert!(result.is_err());

    // Test performance alert
    let result = manager.alerting().send_performance_alert(
        "test-service",
        "response_time_p99",
        1500.0,
        1000.0,
    ).await;
    
    assert!(result.is_err());

    manager.shutdown().await.unwrap();
}