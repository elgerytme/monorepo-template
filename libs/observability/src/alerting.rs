//! Automated alerting system for system health and security
//! 
//! This module provides automated alerting capabilities that monitor
//! system health metrics and security events, sending notifications
//! when thresholds are exceeded.

use crate::config::ObservabilityConfig;
use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tokio::time::interval;

/// Alert severity levels
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum AlertSeverity {
    Critical,
    Warning,
    Info,
}

/// Alert categories
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum AlertCategory {
    System,
    Security,
    Performance,
    Build,
    Business,
}

/// Alert structure
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Alert {
    pub id: String,
    pub title: String,
    pub description: String,
    pub severity: AlertSeverity,
    pub category: AlertCategory,
    pub timestamp: u64,
    pub labels: HashMap<String, String>,
    pub annotations: HashMap<String, String>,
}

/// Alerting manager that monitors metrics and sends alerts
pub struct AlertingManager {
    config: Arc<ObservabilityConfig>,
    client: reqwest::Client,
    alert_history: Vec<Alert>,
}

impl AlertingManager {
    /// Create a new alerting manager
    pub async fn new(config: Arc<ObservabilityConfig>) -> Result<Self> {
        let client = reqwest::Client::builder()
            .timeout(Duration::from_secs(30))
            .build()?;

        Ok(Self {
            config,
            client,
            alert_history: Vec::new(),
        })
    }

    /// Start the alerting system
    pub async fn start(&mut self) -> Result<()> {
        if !self.config.alerting.enabled {
            tracing::info!("Alerting system disabled");
            return Ok(());
        }

        // Start monitoring loops
        self.start_system_monitoring().await;
        self.start_security_monitoring().await;

        tracing::info!(
            webhook_url = %self.config.alerting.webhook_url,
            "Alerting system started"
        );

        Ok(())
    }

    /// Shutdown the alerting system
    pub async fn shutdown(&self) -> Result<()> {
        tracing::info!("Shutting down alerting system");
        Ok(())
    }

    /// Start system health monitoring
    async fn start_system_monitoring(&self) {
        let config = self.config.clone();
        let client = self.client.clone();

        tokio::spawn(async move {
            let mut interval = interval(Duration::from_secs(60)); // Check every minute

            loop {
                interval.tick().await;

                // Monitor CPU usage
                if let Ok(cpu_usage) = Self::get_cpu_usage().await {
                    if cpu_usage > config.alerting.thresholds.cpu_usage {
                        let alert = Alert {
                            id: format!("cpu-high-{}", Self::current_timestamp()),
                            title: "High CPU Usage".to_string(),
                            description: format!("CPU usage is {}%, exceeding threshold of {}%", 
                                cpu_usage, config.alerting.thresholds.cpu_usage),
                            severity: if cpu_usage > 95.0 { AlertSeverity::Critical } else { AlertSeverity::Warning },
                            category: AlertCategory::System,
                            timestamp: Self::current_timestamp(),
                            labels: HashMap::from([
                                ("metric".to_string(), "cpu_usage".to_string()),
                                ("value".to_string(), cpu_usage.to_string()),
                                ("threshold".to_string(), config.alerting.thresholds.cpu_usage.to_string()),
                            ]),
                            annotations: HashMap::from([
                                ("runbook".to_string(), "https://docs.company.com/runbooks/high-cpu".to_string()),
                                ("dashboard".to_string(), "https://grafana.company.com/d/system-overview".to_string()),
                            ]),
                        };

                        if let Err(e) = Self::send_alert(&client, &config.alerting.webhook_url, &alert).await {
                            tracing::error!(error = %e, "Failed to send CPU usage alert");
                        }
                    }
                }

                // Monitor memory usage
                if let Ok(memory_usage) = Self::get_memory_usage().await {
                    let memory_usage_percent = (memory_usage as f64 / (8 * 1024 * 1024 * 1024) as f64) * 100.0; // Assume 8GB total
                    if memory_usage_percent > config.alerting.thresholds.memory_usage {
                        let alert = Alert {
                            id: format!("memory-high-{}", Self::current_timestamp()),
                            title: "High Memory Usage".to_string(),
                            description: format!("Memory usage is {:.1}%, exceeding threshold of {}%", 
                                memory_usage_percent, config.alerting.thresholds.memory_usage),
                            severity: if memory_usage_percent > 95.0 { AlertSeverity::Critical } else { AlertSeverity::Warning },
                            category: AlertCategory::System,
                            timestamp: Self::current_timestamp(),
                            labels: HashMap::from([
                                ("metric".to_string(), "memory_usage".to_string()),
                                ("value".to_string(), memory_usage_percent.to_string()),
                                ("threshold".to_string(), config.alerting.thresholds.memory_usage.to_string()),
                            ]),
                            annotations: HashMap::from([
                                ("runbook".to_string(), "https://docs.company.com/runbooks/high-memory".to_string()),
                            ]),
                        };

                        if let Err(e) = Self::send_alert(&client, &config.alerting.webhook_url, &alert).await {
                            tracing::error!(error = %e, "Failed to send memory usage alert");
                        }
                    }
                }

                // Monitor disk usage
                if let Ok(disk_usage) = Self::get_disk_usage().await {
                    if disk_usage > config.alerting.thresholds.disk_usage {
                        let alert = Alert {
                            id: format!("disk-high-{}", Self::current_timestamp()),
                            title: "High Disk Usage".to_string(),
                            description: format!("Disk usage is {:.1}%, exceeding threshold of {}%", 
                                disk_usage, config.alerting.thresholds.disk_usage),
                            severity: if disk_usage > 95.0 { AlertSeverity::Critical } else { AlertSeverity::Warning },
                            category: AlertCategory::System,
                            timestamp: Self::current_timestamp(),
                            labels: HashMap::from([
                                ("metric".to_string(), "disk_usage".to_string()),
                                ("value".to_string(), disk_usage.to_string()),
                                ("threshold".to_string(), config.alerting.thresholds.disk_usage.to_string()),
                            ]),
                            annotations: HashMap::from([
                                ("runbook".to_string(), "https://docs.company.com/runbooks/high-disk".to_string()),
                            ]),
                        };

                        if let Err(e) = Self::send_alert(&client, &config.alerting.webhook_url, &alert).await {
                            tracing::error!(error = %e, "Failed to send disk usage alert");
                        }
                    }
                }
            }
        });
    }

    /// Start security event monitoring
    async fn start_security_monitoring(&self) {
        let config = self.config.clone();
        let client = self.client.clone();

        tokio::spawn(async move {
            let mut interval = interval(Duration::from_secs(30)); // Check every 30 seconds

            loop {
                interval.tick().await;

                // This would typically monitor security metrics from your metrics system
                // For now, we'll simulate checking for security events
                
                // In a real implementation, you would:
                // 1. Query your metrics system for auth failure counts
                // 2. Check for suspicious activity patterns
                // 3. Monitor vulnerability scan results
                // 4. Check for security policy violations
            }
        });
    }

    /// Send an alert to the configured webhook
    async fn send_alert(client: &reqwest::Client, webhook_url: &str, alert: &Alert) -> Result<()> {
        let response = client
            .post(webhook_url)
            .json(alert)
            .send()
            .await?;

        if response.status().is_success() {
            tracing::info!(
                alert_id = %alert.id,
                severity = ?alert.severity,
                category = ?alert.category,
                "Alert sent successfully"
            );
        } else {
            tracing::error!(
                alert_id = %alert.id,
                status = %response.status(),
                "Failed to send alert"
            );
        }

        Ok(())
    }

    /// Get current timestamp
    fn current_timestamp() -> u64 {
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs()
    }

    /// Get CPU usage (placeholder implementation)
    async fn get_cpu_usage() -> Result<f64> {
        // In a real implementation, use a system metrics library
        Ok(rand::random::<f64>() * 100.0)
    }

    /// Get memory usage (placeholder implementation)
    async fn get_memory_usage() -> Result<u64> {
        // In a real implementation, use a system metrics library
        Ok(1024 * 1024 * 512) // 512 MB
    }

    /// Get disk usage (placeholder implementation)
    async fn get_disk_usage() -> Result<f64> {
        // In a real implementation, use a system metrics library
        Ok(rand::random::<f64>() * 100.0)
    }
}

/// Public API for sending custom alerts
impl AlertingManager {
    /// Send a custom alert
    pub async fn send_custom_alert(&self, alert: Alert) -> Result<()> {
        if !self.config.alerting.enabled {
            return Ok(());
        }

        Self::send_alert(&self.client, &self.config.alerting.webhook_url, &alert).await
    }

    /// Send a security alert
    pub async fn send_security_alert(
        &self,
        title: &str,
        description: &str,
        severity: AlertSeverity,
        labels: HashMap<String, String>,
    ) -> Result<()> {
        let alert = Alert {
            id: format!("security-{}", Self::current_timestamp()),
            title: title.to_string(),
            description: description.to_string(),
            severity,
            category: AlertCategory::Security,
            timestamp: Self::current_timestamp(),
            labels,
            annotations: HashMap::from([
                ("runbook".to_string(), "https://docs.company.com/runbooks/security-incident".to_string()),
                ("escalation".to_string(), "security-team@company.com".to_string()),
            ]),
        };

        self.send_custom_alert(alert).await
    }

    /// Send a build failure alert
    pub async fn send_build_alert(
        &self,
        project: &str,
        build_type: &str,
        error: &str,
        duration_ms: u64,
    ) -> Result<()> {
        let alert = Alert {
            id: format!("build-failure-{}-{}", project, Self::current_timestamp()),
            title: format!("Build Failure: {}", project),
            description: format!("Build failed for project {} ({}): {}", project, build_type, error),
            severity: AlertSeverity::Warning,
            category: AlertCategory::Build,
            timestamp: Self::current_timestamp(),
            labels: HashMap::from([
                ("project".to_string(), project.to_string()),
                ("build_type".to_string(), build_type.to_string()),
                ("duration_ms".to_string(), duration_ms.to_string()),
            ]),
            annotations: HashMap::from([
                ("runbook".to_string(), "https://docs.company.com/runbooks/build-failures".to_string()),
                ("logs".to_string(), format!("https://ci.company.com/builds/{}", project)),
            ]),
        };

        self.send_custom_alert(alert).await
    }

    /// Send a performance degradation alert
    pub async fn send_performance_alert(
        &self,
        service: &str,
        metric: &str,
        current_value: f64,
        threshold: f64,
    ) -> Result<()> {
        let alert = Alert {
            id: format!("performance-{}-{}", service, Self::current_timestamp()),
            title: format!("Performance Degradation: {}", service),
            description: format!("{} for {} is {:.2}, exceeding threshold of {:.2}", 
                metric, service, current_value, threshold),
            severity: if current_value > threshold * 2.0 { AlertSeverity::Critical } else { AlertSeverity::Warning },
            category: AlertCategory::Performance,
            timestamp: Self::current_timestamp(),
            labels: HashMap::from([
                ("service".to_string(), service.to_string()),
                ("metric".to_string(), metric.to_string()),
                ("value".to_string(), current_value.to_string()),
                ("threshold".to_string(), threshold.to_string()),
            ]),
            annotations: HashMap::from([
                ("runbook".to_string(), "https://docs.company.com/runbooks/performance-issues".to_string()),
                ("dashboard".to_string(), format!("https://grafana.company.com/d/{}-overview", service)),
            ]),
        };

        self.send_custom_alert(alert).await
    }
}