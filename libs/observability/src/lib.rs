//! Observability library providing standardized metrics, logging, and tracing
//! 
//! This library implements the observability infrastructure for the monorepo template,
//! providing Rust-based exporters, structured logging with tracing integration,
//! distributed tracing with OpenTelemetry, and automated alerting.

pub mod metrics;
pub mod logging;
pub mod tracing;
pub mod alerting;
pub mod config;

use anyhow::Result;
use std::sync::Arc;

/// Main observability manager that coordinates all observability components
pub struct ObservabilityManager {
    config: Arc<config::ObservabilityConfig>,
    metrics: metrics::MetricsCollector,
    logging: logging::LoggingManager,
    tracing: tracing::TracingManager,
    alerting: alerting::AlertingManager,
}

impl ObservabilityManager {
    /// Initialize the observability manager with configuration
    pub async fn new(config_path: Option<&str>) -> Result<Self> {
        let config = Arc::new(config::ObservabilityConfig::load(config_path)?);
        
        let metrics = metrics::MetricsCollector::new(config.clone()).await?;
        let logging = logging::LoggingManager::new(config.clone())?;
        let tracing = tracing::TracingManager::new(config.clone()).await?;
        let alerting = alerting::AlertingManager::new(config.clone()).await?;

        Ok(Self {
            config,
            metrics,
            logging,
            tracing,
            alerting,
        })
    }

    /// Start all observability components
    pub async fn start(&mut self) -> Result<()> {
        tracing::info!("Starting observability manager");

        self.logging.initialize()?;
        self.tracing.initialize().await?;
        self.metrics.start().await?;
        self.alerting.start().await?;

        tracing::info!("Observability manager started successfully");
        Ok(())
    }

    /// Shutdown all observability components gracefully
    pub async fn shutdown(&mut self) -> Result<()> {
        tracing::info!("Shutting down observability manager");

        self.alerting.shutdown().await?;
        self.metrics.shutdown().await?;
        self.tracing.shutdown().await?;

        tracing::info!("Observability manager shutdown complete");
        Ok(())
    }

    /// Get metrics collector reference
    pub fn metrics(&self) -> &metrics::MetricsCollector {
        &self.metrics
    }

    /// Get alerting manager reference
    pub fn alerting(&self) -> &alerting::AlertingManager {
        &self.alerting
    }
}

/// Initialize global observability with default configuration
pub async fn init() -> Result<ObservabilityManager> {
    ObservabilityManager::new(Some("config/observability.toml")).await
}

/// Initialize observability with custom configuration
pub async fn init_with_config(config_path: &str) -> Result<ObservabilityManager> {
    ObservabilityManager::new(Some(config_path)).await
}