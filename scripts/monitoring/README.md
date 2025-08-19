# Monitoring and Metrics Dashboard System

This directory contains the complete monitoring and metrics dashboard system for the monorepo template. The system provides comprehensive visibility into system health, build/deployment metrics, security compliance, and developer productivity.

## Overview

The monitoring system consists of four main dashboard categories:

1. **System Health Monitoring** - Infrastructure and system metrics
2. **Build & Deployment Metrics** - CI/CD pipeline performance and reliability
3. **Security & Compliance** - Vulnerability tracking and compliance reporting
4. **Developer Productivity** - Team performance and code quality metrics

## Architecture

```
monitoring/
├── dashboards/                    # Grafana dashboard configurations
│   ├── system-health.json
│   ├── build-deployment-metrics.json
│   ├── security-compliance.json
│   └── developer-productivity.json
├── dashboard-setup.sh/.ps1        # Dashboard deployment scripts
├── collect-metrics.sh/.ps1        # Metrics collection scripts
└── README.md                      # This file

infra/monitoring/
├── docker-compose.yml             # Monitoring stack deployment
├── prometheus/
│   └── prometheus.yml             # Prometheus configuration
└── grafana/
    └── provisioning/              # Grafana auto-provisioning
        ├── dashboards/
        └── datasources/

config/monitoring/
└── metrics-config.toml            # Metrics collection configuration
```

## Quick Start

### 1. Deploy Monitoring Stack

```bash
# Linux/macOS
./scripts/monitoring/dashboard-setup.sh

# Windows
.\scripts\monitoring\dashboard-setup.ps1
```

This will:
- Deploy Prometheus, Grafana, and Node Exporter using Docker Compose
- Configure data sources and dashboard provisioning
- Start the monitoring stack on default ports

### 2. Start Metrics Collection

```bash
# Linux/macOS
./scripts/monitoring/collect-metrics.sh --serve

# Windows
.\scripts\monitoring\collect-metrics.ps1 -Serve
```

This will:
- Collect metrics from various sources (Git, builds, security tools, system)
- Export metrics in Prometheus format
- Start an HTTP server to serve metrics

### 3. Access Dashboards

- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090
- **Metrics Endpoint**: http://localhost:8080

## Dashboard Details

### System Health Monitoring

**Purpose**: Monitor infrastructure health and system performance

**Key Metrics**:
- CPU, Memory, and Disk usage
- Network I/O and system load
- Service uptime and availability
- Resource utilization trends

**Alerts**:
- CPU usage > 90%
- Memory usage > 95%
- Disk usage > 95%
- Service downtime

**Refresh**: 30 seconds

### Build & Deployment Metrics

**Purpose**: Track CI/CD pipeline performance and reliability

**Key Metrics**:
- Build success rate and duration
- Deployment frequency and success rate
- Test coverage and failure rates
- Lead time and recovery time
- Rollback frequency

**Alerts**:
- Build failure rate > 10%
- Deployment failures
- Test coverage drops below threshold

**Refresh**: 1 minute

### Security & Compliance

**Purpose**: Monitor security posture and compliance status

**Key Metrics**:
- Vulnerability counts by severity
- Security scan results and success rates
- Compliance score and policy violations
- Secret detection events
- Container security scan results
- Mean time to remediation

**Alerts**:
- Critical vulnerabilities detected
- Compliance score drops below 95%
- Security policy violations

**Refresh**: 5 minutes

### Developer Productivity

**Purpose**: Track team performance and code quality

**Key Metrics**:
- Commit frequency and pull request metrics
- Code review time and cycle time
- Lines of code changed and complexity
- Test execution time and coverage
- Documentation coverage
- Rework rate and knowledge sharing

**Features**:
- Personal data anonymization
- Team-level aggregations
- Trend analysis over time

**Refresh**: 5 minutes

## Configuration

### Metrics Collection

Edit `config/monitoring/metrics-config.toml` to customize:

```toml
[general]
enabled = true
collection_interval = "15s"
retention_period = "30d"

[system_health]
enabled = true
alert_thresholds = { cpu = 90, memory = 95, disk = 95 }

[security_compliance]
enabled = true
alert_on_critical = true
compliance_standards = ["SOC2", "ISO27001", "PCI-DSS"]

[developer_productivity]
enabled = true
anonymize_personal_data = true
```

### Dashboard Customization

Dashboard JSON files in `infra/monitoring/dashboards/` can be modified to:
- Add new panels and metrics
- Adjust thresholds and colors
- Customize time ranges and refresh rates
- Add new visualizations

### Alerting Rules

Configure alerts in `infra/monitoring/prometheus/rules/`:

```yaml
groups:
  - name: system_health
    rules:
      - alert: HighCPUUsage
        expr: cpu_usage_percent > 90
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage detected"
```

## Metrics Sources

### Git Metrics
- Commit frequency and authorship
- Pull request lifecycle metrics
- Code change statistics
- Branch and merge patterns

### Build System Metrics
- Buck2 build performance
- GitHub Actions workflow results
- Test execution and coverage
- Artifact generation

### Security Tool Integration
- `cargo audit` vulnerability scanning
- Secret detection in git history
- Container security scanning
- Policy compliance checking

### System Metrics
- CPU, memory, disk, and network usage
- Process and service monitoring
- Resource utilization trends
- Performance bottlenecks

## Extending the System

### Adding New Metrics

1. **Define the metric** in `config/monitoring/metrics-config.toml`
2. **Collect the data** in `collect-metrics.sh/.ps1`
3. **Create dashboard panels** in the appropriate JSON file
4. **Set up alerts** if needed

### Custom Exporters

Create custom metrics exporters for specific tools:

```rust
// Example Rust metrics exporter
use prometheus::{Encoder, TextEncoder, Counter, register_counter};

fn export_custom_metrics() {
    let counter = register_counter!("custom_metric_total", "Custom metric description").unwrap();
    counter.inc();
    
    let encoder = TextEncoder::new();
    let metric_families = prometheus::gather();
    encoder.encode(&metric_families, &mut std::io::stdout()).unwrap();
}
```

### Integration with External Systems

The monitoring system can integrate with:
- **Slack/Teams** for alert notifications
- **PagerDuty** for incident management
- **JIRA** for tracking remediation tasks
- **External APM tools** for application monitoring

## Troubleshooting

### Common Issues

**Dashboards not loading**:
- Check Grafana logs: `docker logs grafana`
- Verify Prometheus connectivity
- Ensure dashboard JSON is valid

**Metrics not appearing**:
- Check metrics collection script output
- Verify Prometheus scrape configuration
- Check metrics server is running

**High resource usage**:
- Adjust collection intervals
- Reduce retention periods
- Optimize dashboard queries

### Performance Optimization

- Use recording rules for complex queries
- Implement metric sampling for high-cardinality data
- Set appropriate retention policies
- Use dashboard query caching

## Security Considerations

- **Access Control**: Configure Grafana authentication and authorization
- **Data Privacy**: Anonymize personal data in productivity metrics
- **Network Security**: Use HTTPS and secure network configurations
- **Audit Logging**: Enable audit logs for dashboard access and changes

## Maintenance

### Regular Tasks

- **Update dashboards** with new metrics and visualizations
- **Review alert thresholds** and adjust based on baseline changes
- **Clean up old metrics data** according to retention policies
- **Update monitoring stack** components for security patches

### Backup and Recovery

- **Dashboard configurations**: Version control JSON files
- **Metrics data**: Configure Prometheus remote storage
- **Configuration files**: Include in repository backups

## Support

For issues and questions:
1. Check the troubleshooting section above
2. Review logs from monitoring components
3. Consult the Grafana and Prometheus documentation
4. Create an issue in the repository

## Contributing

To contribute improvements:
1. Test changes in a development environment
2. Update documentation for new features
3. Follow the existing code and configuration patterns
4. Submit pull requests with clear descriptions