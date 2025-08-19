//! Standardized metrics collection with Rust-based exporters
//! 
//! This module provides Prometheus metrics collection and export functionality
//! using Rust-based tools for high performance and reliability.

use crate::config::ObservabilityConfig;
use anyhow::Result;
use metrics::{counter, gauge, histogram, register_counter, register_gauge, register_histogram};
use metrics_exporter_prometheus::PrometheusBuilder;
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::time::interval;

/// Metrics collector that manages all application metrics
pub struct MetricsCollector {
    config: Arc<ObservabilityConfig>,
    start_time: Instant,
}

impl MetricsCollector {
    /// Create a new metrics collector
    pub async fn new(config: Arc<ObservabilityConfig>) -> Result<Self> {
        Ok(Self {
            config,
            start_time: Instant::now(),
        })
    }

    /// Start the metrics collection system
    pub async fn start(&self) -> Result<()> {
        if !self.config.metrics.enabled {
            tracing::info!("Metrics collection disabled");
            return Ok(());
        }

        // Initialize Prometheus exporter
        let builder = PrometheusBuilder::new()
            .with_http_listener(([0, 0, 0, 0], self.config.metrics.port))
            .with_registry_path(&self.config.metrics.path);

        builder.install()?;

        // Register standard metrics
        self.register_standard_metrics();

        // Start metrics collection loop
        self.start_collection_loop().await;

        tracing::info!(
            "Metrics collector started on port {}{}",
            self.config.metrics.port,
            self.config.metrics.path
        );

        Ok(())
    }

    /// Shutdown the metrics collector
    pub async fn shutdown(&self) -> Result<()> {
        tracing::info!("Shutting down metrics collector");
        Ok(())
    }

    /// Register standard application metrics
    fn register_standard_metrics(&self) {
        // System metrics
        register_gauge!("system_cpu_usage_percent", "CPU usage percentage");
        register_gauge!("system_memory_usage_bytes", "Memory usage in bytes");
        register_gauge!("system_disk_usage_percent", "Disk usage percentage");
        register_gauge!("system_uptime_seconds", "System uptime in seconds");

        // Application metrics
        register_counter!("http_requests_total", "Total HTTP requests");
        register_histogram!("http_request_duration_seconds", "HTTP request duration");
        register_counter!("http_errors_total", "Total HTTP errors");
        register_gauge!("active_connections", "Number of active connections");

        // Build metrics
        register_counter!("build_total", "Total builds");
        register_counter!("build_failures_total", "Total build failures");
        register_histogram!("build_duration_seconds", "Build duration");

        // Security metrics
        register_counter!("security_scan_total", "Total security scans");
        register_counter!("security_vulnerabilities_found", "Security vulnerabilities found");
        register_counter!("auth_failures_total", "Authentication failures");

        // Custom business metrics
        register_counter!("feature_usage_total", "Feature usage counter");
        register_histogram!("database_query_duration_seconds", "Database query duration");
        register_gauge!("cache_hit_ratio", "Cache hit ratio");
    }

    /// Start the metrics collection loop
    async fn start_collection_loop(&self) {
        let collection_interval = self.parse_duration(&self.config.metrics.collection_interval)
            .unwrap_or(Duration::from_secs(15));

        let mut interval = interval(collection_interval);

        tokio::spawn(async move {
            loop {
                interval.tick().await;
                Self::collect_system_metrics().await;
            }
        });
    }

    /// Collect system-level metrics
    async fn collect_system_metrics() {
        // Update uptime
        gauge!("system_uptime_seconds", std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs() as f64);

        // Collect CPU usage (simplified - in production use a proper system metrics library)
        if let Ok(cpu_usage) = Self::get_cpu_usage().await {
            gauge!("system_cpu_usage_percent", cpu_usage);
        }

        // Collect memory usage
        if let Ok(memory_usage) = Self::get_memory_usage().await {
            gauge!("system_memory_usage_bytes", memory_usage as f64);
        }

        // Collect disk usage
        if let Ok(disk_usage) = Self::get_disk_usage().await {
            gauge!("system_disk_usage_percent", disk_usage);
        }
    }

    /// Get CPU usage percentage (simplified implementation)
    async fn get_cpu_usage() -> Result<f64> {
        // In a real implementation, use a system metrics library like `sysinfo`
        // This is a placeholder that returns a random value for demonstration
        Ok(rand::random::<f64>() * 100.0)
    }

    /// Get memory usage in bytes
    async fn get_memory_usage() -> Result<u64> {
        // Placeholder implementation
        Ok(1024 * 1024 * 512) // 512 MB
    }

    /// Get disk usage percentage
    async fn get_disk_usage() -> Result<f64> {
        // Placeholder implementation
        Ok(rand::random::<f64>() * 100.0)
    }

    /// Parse duration string
    fn parse_duration(&self, duration_str: &str) -> Result<Duration> {
        let duration_str = duration_str.trim();
        
        if duration_str.ends_with('s') {
            let seconds: u64 = duration_str[..duration_str.len() - 1].parse()?;
            Ok(Duration::from_secs(seconds))
        } else if duration_str.ends_with("ms") {
            let millis: u64 = duration_str[..duration_str.len() - 2].parse()?;
            Ok(Duration::from_millis(millis))
        } else {
            // Default to seconds
            let seconds: u64 = duration_str.parse()?;
            Ok(Duration::from_secs(seconds))
        }
    }
}

/// Convenience functions for recording metrics throughout the application

/// Record HTTP request metrics
pub fn record_http_request(method: &str, path: &str, status_code: u16, duration: Duration) {
    let labels = [
        ("method", method),
        ("path", path),
        ("status_code", &status_code.to_string()),
    ];

    counter!("http_requests_total", &labels).increment(1);
    histogram!("http_request_duration_seconds", &labels).record(duration.as_secs_f64());

    if status_code >= 400 {
        counter!("http_errors_total", &labels).increment(1);
    }
}

/// Record build metrics
pub fn record_build(success: bool, duration: Duration) {
    counter!("build_total").increment(1);
    histogram!("build_duration_seconds").record(duration.as_secs_f64());

    if !success {
        counter!("build_failures_total").increment(1);
    }
}

/// Record security scan results
pub fn record_security_scan(vulnerabilities_found: u64) {
    counter!("security_scan_total").increment(1);
    counter!("security_vulnerabilities_found").increment(vulnerabilities_found);
}

/// Record authentication failure
pub fn record_auth_failure(reason: &str) {
    let labels = [("reason", reason)];
    counter!("auth_failures_total", &labels).increment(1);
}

/// Record database query
pub fn record_database_query(query_type: &str, duration: Duration) {
    let labels = [("query_type", query_type)];
    histogram!("database_query_duration_seconds", &labels).record(duration.as_secs_f64());
}

/// Update cache hit ratio
pub fn update_cache_hit_ratio(ratio: f64) {
    gauge!("cache_hit_ratio").set(ratio);
}

/// Record feature usage
pub fn record_feature_usage(feature_name: &str) {
    let labels = [("feature", feature_name)];
    counter!("feature_usage_total", &labels).increment(1);
}