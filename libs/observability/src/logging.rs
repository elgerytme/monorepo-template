//! Structured logging configuration with tracing integration
//! 
//! This module provides structured logging using the tracing ecosystem,
//! with JSON formatting and integration with distributed tracing.

use crate::config::ObservabilityConfig;
use anyhow::Result;
use std::sync::Arc;
use tracing_subscriber::{
    fmt::{self, format::JsonFields},
    layer::SubscriberExt,
    util::SubscriberInitExt,
    EnvFilter, Layer,
};

/// Logging manager that configures structured logging with tracing integration
pub struct LoggingManager {
    config: Arc<ObservabilityConfig>,
}

impl LoggingManager {
    /// Create a new logging manager
    pub fn new(config: Arc<ObservabilityConfig>) -> Result<Self> {
        Ok(Self { config })
    }

    /// Initialize the logging system
    pub fn initialize(&self) -> Result<()> {
        let log_level = &self.config.logging.level;
        let log_format = &self.config.logging.format;

        // Create environment filter
        let env_filter = EnvFilter::try_from_default_env()
            .or_else(|_| EnvFilter::try_new(log_level))?;

        // Build the subscriber based on format preference
        match log_format.as_str() {
            "json" => {
                let fmt_layer = fmt::layer()
                    .json()
                    .with_current_span(true)
                    .with_span_list(true)
                    .with_target(true)
                    .with_thread_ids(true)
                    .with_thread_names(true)
                    .with_file(true)
                    .with_line_number(true);

                tracing_subscriber::registry()
                    .with(env_filter)
                    .with(fmt_layer)
                    .init();
            }
            "pretty" => {
                let fmt_layer = fmt::layer()
                    .pretty()
                    .with_current_span(true)
                    .with_span_list(true)
                    .with_target(true)
                    .with_thread_ids(true)
                    .with_thread_names(true)
                    .with_file(true)
                    .with_line_number(true);

                tracing_subscriber::registry()
                    .with(env_filter)
                    .with(fmt_layer)
                    .init();
            }
            _ => {
                // Default to compact format
                let fmt_layer = fmt::layer()
                    .compact()
                    .with_current_span(true)
                    .with_target(true)
                    .with_thread_ids(true)
                    .with_file(true)
                    .with_line_number(true);

                tracing_subscriber::registry()
                    .with(env_filter)
                    .with(fmt_layer)
                    .init();
            }
        }

        tracing::info!(
            service_name = %self.config.logging.tracing.service_name,
            log_level = %log_level,
            log_format = %log_format,
            "Structured logging initialized"
        );

        Ok(())
    }
}

/// Structured logging macros and utilities

/// Log a security event with structured data
#[macro_export]
macro_rules! log_security_event {
    ($level:ident, $event_type:expr, $($field:tt)*) => {
        tracing::$level!(
            event_type = $event_type,
            category = "security",
            $($field)*
        );
    };
}

/// Log a performance event with structured data
#[macro_export]
macro_rules! log_performance_event {
    ($level:ident, $operation:expr, $duration_ms:expr, $($field:tt)*) => {
        tracing::$level!(
            operation = $operation,
            duration_ms = $duration_ms,
            category = "performance",
            $($field)*
        );
    };
}

/// Log a business event with structured data
#[macro_export]
macro_rules! log_business_event {
    ($level:ident, $event:expr, $($field:tt)*) => {
        tracing::$level!(
            event = $event,
            category = "business",
            $($field)*
        );
    };
}

/// Structured logging utilities
pub struct LoggingUtils;

impl LoggingUtils {
    /// Log HTTP request with structured data
    pub fn log_http_request(
        method: &str,
        path: &str,
        status_code: u16,
        duration_ms: u64,
        user_id: Option<&str>,
    ) {
        tracing::info!(
            http.method = method,
            http.path = path,
            http.status_code = status_code,
            http.duration_ms = duration_ms,
            user.id = user_id,
            category = "http",
            "HTTP request processed"
        );
    }

    /// Log database operation with structured data
    pub fn log_database_operation(
        operation: &str,
        table: &str,
        duration_ms: u64,
        rows_affected: Option<u64>,
        error: Option<&str>,
    ) {
        if let Some(err) = error {
            tracing::error!(
                db.operation = operation,
                db.table = table,
                db.duration_ms = duration_ms,
                db.error = err,
                category = "database",
                "Database operation failed"
            );
        } else {
            tracing::info!(
                db.operation = operation,
                db.table = table,
                db.duration_ms = duration_ms,
                db.rows_affected = rows_affected,
                category = "database",
                "Database operation completed"
            );
        }
    }

    /// Log authentication event
    pub fn log_auth_event(
        event_type: &str,
        user_id: Option<&str>,
        ip_address: Option<&str>,
        success: bool,
        reason: Option<&str>,
    ) {
        let level = if success {
            tracing::Level::INFO
        } else {
            tracing::Level::WARN
        };

        tracing::event!(
            level,
            auth.event_type = event_type,
            auth.user_id = user_id,
            auth.ip_address = ip_address,
            auth.success = success,
            auth.reason = reason,
            category = "authentication",
            "Authentication event"
        );
    }

    /// Log build event
    pub fn log_build_event(
        build_type: &str,
        project: &str,
        duration_ms: u64,
        success: bool,
        error: Option<&str>,
    ) {
        if success {
            tracing::info!(
                build.type = build_type,
                build.project = project,
                build.duration_ms = duration_ms,
                build.success = success,
                category = "build",
                "Build completed successfully"
            );
        } else {
            tracing::error!(
                build.type = build_type,
                build.project = project,
                build.duration_ms = duration_ms,
                build.success = success,
                build.error = error,
                category = "build",
                "Build failed"
            );
        }
    }

    /// Log security scan event
    pub fn log_security_scan(
        scan_type: &str,
        target: &str,
        vulnerabilities_found: u64,
        duration_ms: u64,
        severity_breakdown: Option<&str>,
    ) {
        if vulnerabilities_found > 0 {
            tracing::warn!(
                security.scan_type = scan_type,
                security.target = target,
                security.vulnerabilities_found = vulnerabilities_found,
                security.duration_ms = duration_ms,
                security.severity_breakdown = severity_breakdown,
                category = "security",
                "Security vulnerabilities found"
            );
        } else {
            tracing::info!(
                security.scan_type = scan_type,
                security.target = target,
                security.vulnerabilities_found = vulnerabilities_found,
                security.duration_ms = duration_ms,
                category = "security",
                "Security scan completed - no vulnerabilities found"
            );
        }
    }

    /// Log deployment event
    pub fn log_deployment_event(
        environment: &str,
        service: &str,
        version: &str,
        success: bool,
        duration_ms: u64,
        rollback: bool,
    ) {
        let level = if success {
            tracing::Level::INFO
        } else {
            tracing::Level::ERROR
        };

        tracing::event!(
            level,
            deploy.environment = environment,
            deploy.service = service,
            deploy.version = version,
            deploy.success = success,
            deploy.duration_ms = duration_ms,
            deploy.rollback = rollback,
            category = "deployment",
            "Deployment event"
        );
    }
}