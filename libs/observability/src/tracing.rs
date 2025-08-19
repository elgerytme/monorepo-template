//! Distributed tracing with OpenTelemetry
//! 
//! This module provides distributed tracing capabilities using OpenTelemetry
//! with support for multiple exporters and correlation across services.

use crate::config::ObservabilityConfig;
use anyhow::Result;
use opentelemetry::{
    global,
    sdk::{
        trace::{self, Sampler},
        Resource,
    },
    KeyValue,
};
use opentelemetry_otlp::WithExportConfig;
use std::sync::Arc;
use tracing_opentelemetry::OpenTelemetryLayer;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

/// Tracing manager that configures distributed tracing with OpenTelemetry
pub struct TracingManager {
    config: Arc<ObservabilityConfig>,
}

impl TracingManager {
    /// Create a new tracing manager
    pub async fn new(config: Arc<ObservabilityConfig>) -> Result<Self> {
        Ok(Self { config })
    }

    /// Initialize distributed tracing
    pub async fn initialize(&self) -> Result<()> {
        if !self.config.tracing.enabled {
            tracing::info!("Distributed tracing disabled");
            return Ok(());
        }

        // Create resource with service information
        let resource = Resource::new(vec![
            KeyValue::new("service.name", self.config.tracing.resource.service_name.clone()),
            KeyValue::new("service.version", self.config.tracing.resource.service_version.clone()),
            KeyValue::new("deployment.environment", self.config.tracing.resource.deployment_environment.clone()),
        ]);

        // Configure tracer based on protocol
        let tracer = match self.config.tracing.protocol.as_str() {
            "grpc" => {
                opentelemetry_otlp::new_pipeline()
                    .tracing()
                    .with_exporter(
                        opentelemetry_otlp::new_exporter()
                            .tonic()
                            .with_endpoint(&self.config.tracing.endpoint),
                    )
                    .with_trace_config(
                        trace::config()
                            .with_sampler(Sampler::TraceIdRatioBased(
                                self.config.logging.tracing.sample_rate,
                            ))
                            .with_resource(resource),
                    )
                    .install_batch(opentelemetry::runtime::Tokio)?
            }
            "http" => {
                opentelemetry_otlp::new_pipeline()
                    .tracing()
                    .with_exporter(
                        opentelemetry_otlp::new_exporter()
                            .http()
                            .with_endpoint(&self.config.tracing.endpoint),
                    )
                    .with_trace_config(
                        trace::config()
                            .with_sampler(Sampler::TraceIdRatioBased(
                                self.config.logging.tracing.sample_rate,
                            ))
                            .with_resource(resource),
                    )
                    .install_batch(opentelemetry::runtime::Tokio)?
            }
            _ => {
                return Err(anyhow::anyhow!(
                    "Unsupported tracing protocol: {}",
                    self.config.tracing.protocol
                ));
            }
        };

        // Set global tracer
        global::set_tracer_provider(tracer.provider().unwrap());

        tracing::info!(
            service_name = %self.config.tracing.resource.service_name,
            endpoint = %self.config.tracing.endpoint,
            protocol = %self.config.tracing.protocol,
            sample_rate = %self.config.logging.tracing.sample_rate,
            "Distributed tracing initialized"
        );

        Ok(())
    }

    /// Shutdown tracing gracefully
    pub async fn shutdown(&self) -> Result<()> {
        if self.config.tracing.enabled {
            global::shutdown_tracer_provider();
            tracing::info!("Distributed tracing shutdown complete");
        }
        Ok(())
    }
}

/// Tracing utilities and convenience functions

/// Create a new span with common attributes
pub fn create_span(name: &str, operation: &str, service: &str) -> tracing::Span {
    tracing::info_span!(
        name,
        otel.name = name,
        operation = operation,
        service.name = service,
        trace_id = tracing::field::Empty,
        span_id = tracing::field::Empty,
    )
}

/// Create an HTTP request span
pub fn create_http_span(method: &str, path: &str, user_id: Option<&str>) -> tracing::Span {
    tracing::info_span!(
        "http_request",
        otel.name = "http_request",
        http.method = method,
        http.route = path,
        http.scheme = "https",
        user.id = user_id,
        trace_id = tracing::field::Empty,
        span_id = tracing::field::Empty,
    )
}

/// Create a database operation span
pub fn create_database_span(operation: &str, table: &str, query: Option<&str>) -> tracing::Span {
    tracing::info_span!(
        "database_operation",
        otel.name = "database_operation",
        db.operation = operation,
        db.table = table,
        db.statement = query,
        trace_id = tracing::field::Empty,
        span_id = tracing::field::Empty,
    )
}

/// Create a build operation span
pub fn create_build_span(build_type: &str, project: &str, target: Option<&str>) -> tracing::Span {
    tracing::info_span!(
        "build_operation",
        otel.name = "build_operation",
        build.type = build_type,
        build.project = project,
        build.target = target,
        trace_id = tracing::field::Empty,
        span_id = tracing::field::Empty,
    )
}

/// Create a security scan span
pub fn create_security_scan_span(scan_type: &str, target: &str) -> tracing::Span {
    tracing::info_span!(
        "security_scan",
        otel.name = "security_scan",
        security.scan_type = scan_type,
        security.target = target,
        trace_id = tracing::field::Empty,
        span_id = tracing::field::Empty,
    )
}

/// Add error information to current span
pub fn record_error(error: &dyn std::error::Error) {
    let span = tracing::Span::current();
    span.record("error", true);
    span.record("error.message", &error.to_string());
    span.record("error.type", &std::any::type_name_of_val(error));
}

/// Add custom attributes to current span
pub fn record_attributes(attributes: &[(&str, &str)]) {
    let span = tracing::Span::current();
    for (key, value) in attributes {
        span.record(key, value);
    }
}

/// Macro for creating instrumented functions
#[macro_export]
macro_rules! instrument_function {
    ($func:ident, $operation:expr, $service:expr) => {
        #[tracing::instrument(
            name = stringify!($func),
            fields(
                otel.name = stringify!($func),
                operation = $operation,
                service.name = $service,
            ),
            skip_all
        )]
    };
}

/// Macro for creating instrumented async functions
#[macro_export]
macro_rules! instrument_async_function {
    ($func:ident, $operation:expr, $service:expr) => {
        #[tracing::instrument(
            name = stringify!($func),
            fields(
                otel.name = stringify!($func),
                operation = $operation,
                service.name = $service,
            ),
            skip_all
        )]
    };
}

/// Context propagation utilities
pub mod context {
    use opentelemetry::{global, propagation::Extractor, Context};
    use std::collections::HashMap;

    /// Extract tracing context from HTTP headers
    pub fn extract_from_headers(headers: &HashMap<String, String>) -> Context {
        let extractor = HeaderExtractor(headers);
        global::get_text_map_propagator(|propagator| propagator.extract(&extractor))
    }

    /// Inject tracing context into HTTP headers
    pub fn inject_into_headers(headers: &mut HashMap<String, String>) {
        let context = Context::current();
        let mut injector = HeaderInjector(headers);
        global::get_text_map_propagator(|propagator| propagator.inject_context(&context, &mut injector));
    }

    struct HeaderExtractor<'a>(&'a HashMap<String, String>);

    impl<'a> Extractor for HeaderExtractor<'a> {
        fn get(&self, key: &str) -> Option<&str> {
            self.0.get(key).map(|v| v.as_str())
        }

        fn keys(&self) -> Vec<&str> {
            self.0.keys().map(|k| k.as_str()).collect()
        }
    }

    struct HeaderInjector<'a>(&'a mut HashMap<String, String>);

    impl<'a> opentelemetry::propagation::Injector for HeaderInjector<'a> {
        fn set(&mut self, key: &str, value: String) {
            self.0.insert(key.to_string(), value);
        }
    }
}