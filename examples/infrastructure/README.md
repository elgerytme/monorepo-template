# Example Infrastructure as Code

A comprehensive infrastructure-as-code example demonstrating modern DevOps practices with security scanning, monitoring, and deployment automation.

## Overview

This example provides a complete infrastructure setup including:

- **Terraform**: AWS infrastructure provisioning
- **Docker**: Containerized application deployment
- **Kubernetes**: Container orchestration manifests
- **Security Scanning**: Automated security analysis
- **Monitoring**: Observability and metrics collection

## Architecture

### AWS Infrastructure (Terraform)

The Terraform configuration creates a production-ready AWS environment:

- **VPC**: Multi-AZ setup with public/private subnets
- **ECS**: Fargate-based container service
- **ALB**: Application Load Balancer with SSL termination
- **RDS**: PostgreSQL database with encryption
- **S3**: Secure asset storage with versioning
- **CloudWatch**: Comprehensive monitoring and alerting

### Container Platform (Docker)

- **Multi-stage builds**: Optimized Rust application containers
- **Security**: Non-root user, minimal attack surface
- **Health checks**: Application and dependency monitoring
- **Compose**: Local development environment

### Kubernetes Deployment

- **Security**: Pod security policies, network policies
- **Scalability**: Horizontal pod autoscaling
- **Observability**: Prometheus metrics integration
- **Resource management**: Quotas and limits

## Getting Started

### Prerequisites

```bash
# Install required tools
brew install terraform docker kubectl
pip3 install checkov
curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
```

### Local Development

```bash
# Start local environment
cd examples/infrastructure/docker
docker-compose up -d

# Check services
docker-compose ps
curl http://localhost:3000/health
```

### AWS Deployment

```bash
# Initialize Terraform
cd examples/infrastructure/terraform
terraform init

# Plan deployment
terraform plan -var-file="environments/dev.tfvars"

# Apply infrastructure
terraform apply -var-file="environments/dev.tfvars"
```

### Kubernetes Deployment

```bash
# Apply manifests
kubectl apply -f examples/infrastructure/kubernetes/

# Check deployment
kubectl get pods -n example-app
kubectl get services -n example-app
```

## Security Scanning

The infrastructure includes comprehensive security scanning:

### Automated Scanning

```bash
# Run all security scans
cd examples/infrastructure/security-scanning
./scan.sh

# View results
cat results/security-summary.md
```

### Scanning Tools

- **tfsec**: Terraform security analysis
- **checkov**: Multi-format security scanning
- **terrascan**: Infrastructure security policies
- **Docker Scout**: Container vulnerability scanning

### Security Features

- **Encryption**: Data at rest and in transit
- **Network Security**: VPC, security groups, network policies
- **Access Control**: IAM roles, service accounts
- **Monitoring**: Security event logging and alerting
- **Compliance**: Industry standard security practices

## Monitoring and Observability

### Metrics Collection

- **Prometheus**: Metrics scraping and storage
- **Grafana**: Visualization and dashboards
- **CloudWatch**: AWS native monitoring
- **Application metrics**: Custom business metrics

### Logging

- **Structured logging**: JSON format with correlation IDs
- **Centralized collection**: CloudWatch Logs, ELK stack
- **Log retention**: Configurable retention policies
- **Security logging**: Audit trails and access logs

### Alerting

- **CloudWatch Alarms**: Infrastructure alerts
- **Prometheus AlertManager**: Application alerts
- **SNS Integration**: Multi-channel notifications
- **Escalation policies**: Tiered alert handling

## CI/CD Integration

### GitHub Actions

```yaml
# Example workflow integration
- name: Security Scan
  run: |
    cd examples/infrastructure/security-scanning
    ./scan.sh
    
- name: Deploy Infrastructure
  run: |
    cd examples/infrastructure/terraform
    terraform apply -auto-approve
```

### Buck2 Integration

```bash
# Build and validate
buck2 build //examples/infrastructure:terraform-validate
buck2 run //examples/infrastructure:security-scan

# Deploy
buck2 run //examples/infrastructure:deploy
```

## Environment Configuration

### Development

- **Resources**: Minimal sizing for cost optimization
- **Security**: Relaxed policies for development speed
- **Monitoring**: Basic metrics and logging
- **Backup**: Short retention periods

### Staging

- **Resources**: Production-like sizing
- **Security**: Production security policies
- **Monitoring**: Full observability stack
- **Backup**: Extended retention for testing

### Production

- **Resources**: Auto-scaling with performance optimization
- **Security**: Maximum security hardening
- **Monitoring**: Comprehensive alerting and dashboards
- **Backup**: Long-term retention and disaster recovery

## Best Practices Demonstrated

### Infrastructure as Code

- **Version Control**: All infrastructure in Git
- **Modular Design**: Reusable Terraform modules
- **State Management**: Remote state with locking
- **Documentation**: Comprehensive inline documentation

### Security

- **Least Privilege**: Minimal required permissions
- **Defense in Depth**: Multiple security layers
- **Encryption**: End-to-end data protection
- **Audit Logging**: Complete activity tracking

### Reliability

- **High Availability**: Multi-AZ deployment
- **Disaster Recovery**: Automated backup and restore
- **Health Checks**: Comprehensive service monitoring
- **Graceful Degradation**: Fault-tolerant design

### Performance

- **Auto Scaling**: Dynamic resource allocation
- **Caching**: Multi-layer caching strategy
- **CDN**: Global content distribution
- **Database Optimization**: Query and index optimization

## Troubleshooting

### Common Issues

1. **Terraform State Lock**: Use `terraform force-unlock`
2. **Docker Build Failures**: Check Dockerfile and dependencies
3. **Kubernetes Deployment**: Verify resource quotas and limits
4. **Security Scan Failures**: Review and address findings

### Debugging

```bash
# Terraform debugging
export TF_LOG=DEBUG
terraform plan

# Docker debugging
docker logs <container-id>
docker exec -it <container-id> /bin/sh

# Kubernetes debugging
kubectl describe pod <pod-name> -n example-app
kubectl logs <pod-name> -n example-app
```

## Contributing

When adding new infrastructure components:

1. **Security First**: Run security scans before committing
2. **Documentation**: Update README and inline comments
3. **Testing**: Validate in development environment
4. **Monitoring**: Add appropriate metrics and alerts
5. **Backup**: Ensure data protection strategies

## Cost Optimization

- **Resource Tagging**: Comprehensive cost allocation
- **Auto Scaling**: Dynamic resource adjustment
- **Reserved Instances**: Long-term cost savings
- **Spot Instances**: Cost-effective compute for non-critical workloads
- **Storage Lifecycle**: Automated data archiving