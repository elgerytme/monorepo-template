//! Configuration management for observability components

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use anyhow::Result;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ObservabilityConfig {
    pub metrics: MetricsConfig,
    pub logging: LoggingConfig,
    pub tracing: TracingConfig,
    pub alerting: AlertingConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MetricsConfig {
    pub enabled: bool,
    pub port: u16,
    pub path: String,
    pub collection_interval: String,
    pub exporters: ExportersConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExportersConfig {
    pub prometheus: PrometheusConfig,
    pub jaeger: JaegerConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PrometheusConfig {
    pub enabled: bool,
    pub port: u16,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JaegerConfig {
    pub enabled: bool,
    pub endpoint: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LoggingConfig {
    pub level: String,
    pub format: String,
    pub output: String,
    pub tracing: TracingLoggingConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TracingLoggingConfig {
    pub enabled: bool,
    pub service_name: String,
    pub sample_rate: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TracingConfig {
    pub enabled: bool,
    pub endpoint: String,
    pub protocol: String,
    pub resource: ResourceConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ResourceConfig {
    pub service_name: String,
    pub service_version: String,
    pub deployment_environment: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AlertingConfig {
    pub enabled: bool,
    pub webhook_url: String,
    pub thresholds: ThresholdsConfig,
    pub security: SecurityAlertingConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ThresholdsConfig {
    pub cpu_usage: f64,
    pub memory_usage: f64,
    pub disk_usage: f64,
    pub error_rate: f64,
    pub response_time_p99: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SecurityAlertingConfig {
    pub failed_auth_threshold: u32,
    pub suspicious_activity_threshold: u32,
    pub vulnerability_scan_failures: bool,
}

impl ObservabilityConfig {
    /// Load configuration from file or use defaults
    pub fn load(config_path: Option<&str>) -> Result<Self> {
        let mut settings = config::Config::builder();

        // Add default configuration
        settings = settings.add_source(config::File::from_str(
            include_str!("../../../config/observability.toml"),
            config::FileFormat::Toml,
        ));

        // Override with custom config if provided
        if let Some(path) = config_path {
            settings = settings.add_source(config::File::with_name(path));
        }

        // Override with environment variables
        settings = settings.add_source(
            config::Environment::with_prefix("OBSERVABILITY")
                .separator("_")
                .try_parsing(true),
        );

        let config = settings.build()?.try_deserialize()?;
        Ok(config)
    }

    /// Get default configuration
    pub fn default() -> Self {
        Self {
            metrics: MetricsConfig {
                enabled: true,
                port: 9090,
                path: "/metrics".to_string(),
                collection_interval: "15s".to_string(),
                exporters: ExportersConfig {
                    prometheus: PrometheusConfig {
                        enabled: true,
                        port: 9090,
                    },
                    jaeger: JaegerConfig {
                        enabled: true,
                        endpoint: "http://localhost:14268/api/traces".to_string(),
                    },
                },
            },
            logging: LoggingConfig {
                level: "info".to_string(),
                format: "json".to_string(),
                output: "stdout".to_string(),
                tracing: TracingLoggingConfig {
                    enabled: true,
                    service_name: "monorepo-service".to_string(),
                    sample_rate: 1.0,
                },
            },
            tracing: TracingConfig {
                enabled: true,
                endpoint: "http://localhost:4317".to_string(),
                protocol: "grpc".to_string(),
                resource: ResourceConfig {
                    service_name: "monorepo-template".to_string(),
                    service_version: "1.0.0".to_string(),
                    deployment_environment: "development".to_string(),
                },
            },
            alerting: AlertingConfig {
                enabled: true,
                webhook_url: "http://localhost:9093/api/v1/alerts".to_string(),
                thresholds: ThresholdsConfig {
                    cpu_usage: 80.0,
                    memory_usage: 85.0,
                    disk_usage: 90.0,
                    error_rate: 5.0,
                    response_time_p99: 1000,
                },
                security: SecurityAlertingConfig {
                    failed_auth_threshold: 10,
                    suspicious_activity_threshold: 5,
                    vulnerability_scan_failures: true,
                },
            },
        }
    }
}