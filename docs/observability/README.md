# Observability Infrastructure

This document describes the comprehensive observability infrastructure implemented in the monorepo template, including metrics collection, structured logging, distributed tracing, and automated alerting.

## Overview

The observability system is built around Rust-based tools and follows industry best practices for monitoring, logging, and tracing in large-scale distributed systems. It provides:

- **Standardized Metrics Collection** with Prometheus and Rust-based exporters
- **Structured Logging** with tracing integration using the `tracing` ecosystem
- **Distributed Tracing** with OpenTelemetry for request correlation across services
- **Automated Alerting** for system health and security events

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Application   │    │   Observability │    │   Monitoring    │
│   Services      │───▶│   Library       │───▶│   Stack         │
│                 │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                       │
                                ▼                       ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │   Metrics       │    │   Prometheus    │
                       │   Logging       │    │   Grafana       │
                       │   Tracing       │    │   Jaeger        │
                       │   Alerting      │    │   Alertmanager  │
                       └─────────────────┘    └─────────────────┘
```

## Components

### 1. Observability Library (`libs/observability`)

The core observability library provides a unified interface for all observability concerns:

- **Metrics Collection**: Prometheus metrics with standardized naming and labels
- **Structured Logging**: JSON-formatted logs with tracing correlation
- **Distributed Tracing**: OpenTelemetry integration with automatic span creation
- **Alerting**: Configurable thresholds and webhook notifications

### 2. Configuration

Observability is configured through `config/observability.toml`:

```toml
[metrics]
enabled = true
port = 9090
collection_interval = "15s"

[logging]
level = "info"
format = "json"

[tracing]
enabled = true
endpoint = "http://localhost:4317"
sample_rate = 1.0

[alerting]
enabled = true
webhook_url = "http://localhost:9093/api/v1/alerts"
```

### 3. Monitoring Stack

The monitoring infrastructure includes:

- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **Jaeger**: Distributed tracing visualization
- **Alertmanager**: Alert routing and notification

## Quick Start

### 1. Setup Monitoring Infrastructure

```bash
# Create monitoring configuration
./scripts/monitoring/setup-monitoring.sh --setup

# Start monitoring stack
./scripts/monitoring/setup-monitoring.sh --start
```

### 2. Integrate Observability in Your Application

```rust
use observability::{ObservabilityManager, metrics, tracing};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Initialize observability
    let mut observability = ObservabilityManager::new(None).await?;
    observability.start().await?;

    // Your application code here
    
    // Shutdown observability
    observability.shutdown().await?;
    Ok(())
}
```

### 3. Add Metrics and Tracing

```rust
use observability::{
    metrics::{record_http_request, record_feature_usage},
    tracing::{create_http_span, record_attributes},
};

// Record HTTP request metrics
let start = Instant::now();
let span = create_http_span("GET", "/api/users", Some("user123"));

async move {
    // Your request handling logic
    
    let duration = start.elapsed();
    record_http_request("GET", "/api/users", 200, duration);
    record_feature_usage("user_lookup");
}
.instrument(span)
.await
```

## Metrics

### Standard Metrics

The system automatically collects these standard metrics:

#### System Metrics
- `system_cpu_usage_percent`: CPU usage percentage
- `system_memory_usage_bytes`: Memory usage in bytes
- `system_disk_usage_percent`: Disk usage percentage
- `system_uptime_seconds`: System uptime

#### Application Metrics
- `http_requests_total`: Total HTTP requests
- `http_request_duration_seconds`: HTTP request duration histogram
- `http_errors_total`: Total HTTP errors
- `active_connections`: Number of active connections

#### Build Metrics
- `build_total`: Total builds
- `build_failures_total`: Total build failures
- `build_duration_seconds`: Build duration histogram

#### Security Metrics
- `security_scan_total`: Total security scans
- `security_vulnerabilities_found`: Security vulnerabilities found
- `auth_failures_total`: Authentication failures

### Custom Metrics

Add custom metrics using the metrics API:

```rust
use metrics::{counter, gauge, histogram};

// Counter
counter!("feature_usage_total", "feature" => "user_registration").increment(1);

// Gauge
gauge!("queue_size").set(42.0);

// Histogram
histogram!("operation_duration_seconds").record(0.5);
```

## Logging

### Structured Logging

All logs are structured using the `tracing` ecosystem:

```rust
use tracing::{info, warn, error};

// Basic logging
info!("User logged in successfully");

// Structured logging with fields
info!(
    user_id = "user123",
    ip_address = "192.168.1.1",
    duration_ms = 150,
    "User authentication completed"
);

// Error logging with context
error!(
    error = %err,
    operation = "database_query",
    table = "users",
    "Database operation failed"
);
```

### Log Categories

Use structured logging utilities for common patterns:

```rust
use observability::logging::LoggingUtils;

// HTTP request logging
LoggingUtils::log_http_request("GET", "/api/users", 200, 150, Some("user123"));

// Database operation logging
LoggingUtils::log_database_operation("SELECT", "users", 50, Some(1), None);

// Authentication event logging
LoggingUtils::log_auth_event("login", Some("user123"), Some("192.168.1.1"), true, None);

// Security scan logging
LoggingUtils::log_security_scan("dependency", "package.json", 2, 5000, Some("2 high, 0 critical"));
```

## Distributed Tracing

### Automatic Tracing

The system automatically creates traces for:
- HTTP requests
- Database operations
- Build processes
- Security scans

### Manual Tracing

Create custom spans for important operations:

```rust
use observability::tracing::{create_span, record_attributes, record_error};

let span = create_span("user_registration", "business_logic", "user-service");

async move {
    // Add custom attributes
    record_attributes(&[
        ("user.email", "user@example.com"),
        ("user.plan", "premium"),
    ]);

    match register_user().await {
        Ok(user) => {
            record_attributes(&[("user.id", &user.id.to_string())]);
        }
        Err(err) => {
            record_error(&err);
            return Err(err);
        }
    }
}
.instrument(span)
.await
```

### Context Propagation

Trace context is automatically propagated across service boundaries:

```rust
use observability::tracing::context;

// Extract context from HTTP headers
let context = context::extract_from_headers(&headers);

// Inject context into outgoing HTTP headers
let mut headers = HashMap::new();
context::inject_into_headers(&mut headers);
```

## Alerting

### Automatic Alerts

The system automatically monitors and alerts on:

- **System Health**: CPU, memory, and disk usage thresholds
- **Application Performance**: Error rates and response times
- **Security Events**: Authentication failures and vulnerability scans
- **Build Failures**: Failed builds and deployments

### Custom Alerts

Send custom alerts programmatically:

```rust
use observability::alerting::{Alert, AlertSeverity, AlertCategory};

let alert = Alert {
    id: "custom-alert-123".to_string(),
    title: "Custom Business Alert".to_string(),
    description: "Something important happened".to_string(),
    severity: AlertSeverity::Warning,
    category: AlertCategory::Business,
    timestamp: SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs(),
    labels: HashMap::from([
        ("service".to_string(), "user-service".to_string()),
        ("environment".to_string(), "production".to_string()),
    ]),
    annotations: HashMap::from([
        ("runbook".to_string(), "https://docs.company.com/runbooks/custom".to_string()),
    ]),
};

observability.alerting().send_custom_alert(alert).await?;
```

### Alert Configuration

Configure alert thresholds in `config/observability.toml`:

```toml
[alerting.thresholds]
cpu_usage = 80.0
memory_usage = 85.0
disk_usage = 90.0
error_rate = 5.0
response_time_p99 = 1000

[alerting.security]
failed_auth_threshold = 10
suspicious_activity_threshold = 5
vulnerability_scan_failures = true
```

## Dashboards

### Access Monitoring Tools

After starting the monitoring stack:

- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (admin/admin)
- **Jaeger**: http://localhost:16686
- **Alertmanager**: http://localhost:9093

### Pre-built Dashboards

The system includes pre-configured Grafana dashboards for:

- System overview (CPU, memory, disk)
- Application performance (requests, errors, latency)
- Security metrics (auth failures, vulnerabilities)
- Build and deployment metrics

## Best Practices

### 1. Metric Naming

Follow Prometheus naming conventions:
- Use snake_case for metric names
- Include units in metric names (`_seconds`, `_bytes`, `_total`)
- Use consistent label names across metrics

### 2. Log Levels

Use appropriate log levels:
- `ERROR`: System errors that require immediate attention
- `WARN`: Potential issues that should be investigated
- `INFO`: General operational information
- `DEBUG`: Detailed information for troubleshooting

### 3. Trace Sampling

Configure appropriate sampling rates:
- Development: 100% sampling for complete visibility
- Staging: 50-100% sampling for testing
- Production: 1-10% sampling to reduce overhead

### 4. Alert Fatigue

Avoid alert fatigue by:
- Setting appropriate thresholds
- Using alert grouping and inhibition rules
- Implementing escalation policies
- Regular review and tuning of alerts

## Troubleshooting

### Common Issues

1. **Metrics not appearing in Prometheus**
   - Check that your application is exposing metrics on the configured port
   - Verify Prometheus scrape configuration
   - Check network connectivity

2. **Traces not appearing in Jaeger**
   - Verify OpenTelemetry endpoint configuration
   - Check that tracing is enabled in your application
   - Verify Jaeger collector is running

3. **Alerts not firing**
   - Check alert rule syntax in Prometheus
   - Verify alertmanager configuration
   - Check webhook endpoint availability

### Debug Commands

```bash
# Check monitoring stack status
./scripts/monitoring/setup-monitoring.sh --status

# View Prometheus targets
curl http://localhost:9090/api/v1/targets

# Test alertmanager webhook
curl -X POST http://localhost:9093/api/v1/alerts \
  -H "Content-Type: application/json" \
  -d '[{"labels":{"alertname":"test"}}]'
```

## Performance Considerations

### Metrics Collection

- Use appropriate collection intervals (15-60 seconds)
- Avoid high-cardinality labels
- Use histograms for timing metrics
- Consider metric retention policies

### Logging

- Use structured logging for better searchability
- Implement log rotation and retention
- Consider log sampling for high-volume applications
- Use appropriate log levels to control volume

### Tracing

- Use sampling to reduce overhead in production
- Avoid tracing high-frequency operations
- Consider trace retention policies
- Monitor trace collection performance

## Security

### Metrics Security

- Avoid exposing sensitive data in metric labels
- Secure metrics endpoints with authentication
- Use HTTPS for metrics collection
- Implement network-level access controls

### Log Security

- Avoid logging sensitive data (passwords, tokens, PII)
- Implement log encryption at rest
- Secure log transport with TLS
- Implement access controls for log data

### Trace Security

- Avoid including sensitive data in trace attributes
- Secure trace collection endpoints
- Implement trace data retention policies
- Use encryption for trace data transport

## Migration Guide

### From Existing Monitoring

1. **Assess Current Setup**: Document existing metrics, logs, and traces
2. **Plan Migration**: Create migration timeline and rollback plan
3. **Parallel Deployment**: Run new system alongside existing one
4. **Gradual Migration**: Migrate services incrementally
5. **Validation**: Verify data consistency and completeness
6. **Cutover**: Switch to new system and decommission old one

### Integration Checklist

- [ ] Observability library integrated
- [ ] Configuration files created
- [ ] Monitoring stack deployed
- [ ] Dashboards configured
- [ ] Alerts configured and tested
- [ ] Documentation updated
- [ ] Team training completed