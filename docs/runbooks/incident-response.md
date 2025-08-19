# Incident Response Runbook

## Overview

This runbook provides step-by-step procedures for responding to production incidents, from initial detection through resolution and post-incident review.

## Incident Severity Levels

### Severity 1 (Critical)
- **Impact**: Complete service outage, data loss, security breach
- **Response Time**: 15 minutes
- **Escalation**: Immediate to on-call manager
- **Communication**: Every 30 minutes

### Severity 2 (High)
- **Impact**: Partial outage, significant performance degradation
- **Response Time**: 1 hour
- **Escalation**: 2 hours to team lead
- **Communication**: Every hour

### Severity 3 (Medium)
- **Impact**: Minor feature issues, non-critical service degradation
- **Response Time**: 4 hours
- **Escalation**: Next business day
- **Communication**: Every 4 hours

### Severity 4 (Low)
- **Impact**: Cosmetic issues, minor inconveniences
- **Response Time**: Next business day
- **Escalation**: Weekly review
- **Communication**: Daily updates

## Initial Response (First 15 Minutes)

### 1. Acknowledge the Incident

```bash
# Acknowledge in monitoring system
curl -X POST "https://monitoring.company.com/api/incidents/{id}/acknowledge" \
  -H "Authorization: Bearer $API_TOKEN"

# Join incident channel
# Slack: #incident-{incident-id}
```

### 2. Assess Severity

**Questions to ask:**
- Is the service completely down?
- How many users are affected?
- Is data at risk?
- Is this a security incident?

**Quick health checks:**
```bash
# Check service status
curl -I https://api.company.com/health

# Check build system
buck2 status

# Check CI/CD pipeline
gh workflow list --repo company/monorepo

# Check monitoring dashboards
open https://monitoring.company.com/overview
```

### 3. Initial Communication

**For Severity 1-2 incidents:**

1. **Create incident channel**
   ```
   /incident create "Brief description of issue"
   ```

2. **Post initial status**
   ```
   🚨 INCIDENT DETECTED
   Severity: [1-4]
   Impact: [Description]
   Started: [Time]
   Investigating: @oncall-engineer
   ```

3. **Update status page**
   ```bash
   # Update external status page
   curl -X POST "https://api.statuspage.io/v1/incidents" \
     -H "Authorization: OAuth $STATUS_TOKEN" \
     -d '{"incident": {"name": "Service Degradation", "status": "investigating"}}'
   ```

## Investigation Phase

### 4. Gather Information

**System health checks:**
```bash
# Check recent deployments
git log --oneline --since="2 hours ago"

# Check recent changes
buck2 log what-changed --since="2 hours ago"

# Check error rates
curl "https://monitoring.company.com/api/metrics/error_rate?range=2h"

# Check resource usage
kubectl top nodes
kubectl top pods
```

**Log analysis:**
```bash
# Check application logs
kubectl logs -l app=web-service --since=2h

# Check build system logs
buck2 log show --since="2 hours ago" --level=error

# Check CI/CD logs
gh run list --repo company/monorepo --status=failure
```

### 5. Form Hypothesis

**Common incident patterns:**
- Recent deployment caused regression
- Infrastructure failure (database, cache, network)
- Third-party service outage
- Resource exhaustion (CPU, memory, disk)
- Security incident or attack

**Document hypothesis:**
```
Current hypothesis: [Description]
Evidence: [What supports this theory]
Next steps: [How to test/verify]
```

### 6. Test and Validate

**For deployment-related issues:**
```bash
# Check recent deployments
kubectl rollout history deployment/web-service

# Compare with last known good version
git diff HEAD~5 HEAD

# Check deployment metrics
kubectl describe deployment web-service
```

**For infrastructure issues:**
```bash
# Check database connectivity
psql -h db.company.com -U app -c "SELECT 1;"

# Check cache status
redis-cli -h cache.company.com ping

# Check network connectivity
curl -I https://external-api.com/health
```

## Mitigation Phase

### 7. Implement Immediate Fix

**For deployment issues:**
```bash
# Rollback to previous version
kubectl rollout undo deployment/web-service

# Or use automated rollback
./scripts/release/rollback-manager.sh --service=web-service --version=previous
```

**For infrastructure issues:**
```bash
# Scale up resources
kubectl scale deployment web-service --replicas=10

# Restart services
kubectl rollout restart deployment/web-service

# Enable maintenance mode
kubectl apply -f k8s/maintenance-mode.yaml
```

**For build system issues:**
```bash
# Restart Buck2 daemon
buck2 kill
buck2 status

# Clear cache if corrupted
buck2 clean
rm -rf .buck-cache

# Disable problematic features temporarily
# Edit .buckconfig to disable remote cache
```

### 8. Verify Fix

**Health checks:**
```bash
# Check service health
curl https://api.company.com/health

# Check error rates
curl "https://monitoring.company.com/api/metrics/error_rate?range=15m"

# Check user-facing functionality
./scripts/monitoring/smoke-tests.sh
```

**Monitor for 15-30 minutes:**
- Error rates return to normal
- Response times improve
- User reports decrease
- Monitoring alerts clear

## Communication During Incident

### 9. Regular Updates

**Update frequency:**
- Severity 1: Every 30 minutes
- Severity 2: Every hour
- Severity 3: Every 4 hours

**Update template:**
```
🔄 INCIDENT UPDATE - [Time]
Status: [Investigating/Identified/Monitoring/Resolved]
Impact: [Current impact description]
Actions taken: [What we've done]
Next steps: [What we're doing next]
ETA: [Estimated resolution time]
```

### 10. Stakeholder Communication

**Internal stakeholders:**
- Engineering teams
- Product managers
- Customer support
- Executive team (for Severity 1-2)

**External communication:**
- Status page updates
- Customer notifications (if needed)
- Social media (for major outages)

## Resolution Phase

### 11. Confirm Resolution

**Verification checklist:**
- [ ] All monitoring alerts cleared
- [ ] Error rates back to normal
- [ ] Response times acceptable
- [ ] User reports stopped
- [ ] Smoke tests passing
- [ ] No new related issues

### 12. Final Communication

```
✅ INCIDENT RESOLVED - [Time]
Duration: [Total incident time]
Root cause: [Brief description]
Resolution: [What fixed it]
Follow-up: [Post-incident review scheduled]
```

**Update status page:**
```bash
curl -X PATCH "https://api.statuspage.io/v1/incidents/{id}" \
  -H "Authorization: OAuth $STATUS_TOKEN" \
  -d '{"incident": {"status": "resolved"}}'
```

## Post-Incident Activities

### 13. Immediate Cleanup

```bash
# Remove temporary fixes
kubectl delete -f k8s/maintenance-mode.yaml

# Clean up monitoring
# Remove temporary alerts or dashboards

# Update documentation
# Note any new procedures discovered
```

### 14. Schedule Post-Incident Review

**Within 24-48 hours:**
- Schedule PIR meeting with all involved parties
- Gather timeline and artifacts
- Prepare incident report template

**PIR agenda:**
- Timeline review
- Root cause analysis
- What went well
- What could be improved
- Action items

## Escalation Procedures

### When to Escalate

**Immediate escalation (Severity 1):**
- Service completely down > 15 minutes
- Data loss or corruption
- Security breach suspected
- Unable to contact primary on-call

**Escalation chain:**
1. Primary on-call engineer
2. Secondary on-call engineer
3. Team lead
4. Engineering manager
5. VP of Engineering

### How to Escalate

```bash
# PagerDuty escalation
curl -X POST "https://api.pagerduty.com/incidents/{id}/escalate" \
  -H "Authorization: Token token=$PD_TOKEN"

# Slack escalation
/escalate @manager "Brief description of issue and why escalating"

# Phone escalation (for critical issues)
# Use emergency contact list
```

## Tools and Resources

### Monitoring and Alerting
- **Primary**: https://monitoring.company.com
- **Status Page**: https://status.company.com
- **PagerDuty**: https://company.pagerduty.com

### Communication
- **Slack**: #incidents, #engineering
- **Email**: incidents@company.com
- **Phone**: Emergency contact list

### Technical Tools
```bash
# Kubernetes
kubectl get pods --all-namespaces
kubectl describe pod <pod-name>
kubectl logs <pod-name>

# Buck2
buck2 status
buck2 log show
buck2 build //...

# Git
git log --oneline --since="2 hours ago"
git diff HEAD~5 HEAD

# Monitoring
curl https://monitoring.company.com/api/health
```

### Runbooks
- [Build System Maintenance](./build-system-maintenance.md)
- [Rollback Procedures](./rollback-procedures.md)
- [Security Incident Response](./security-incident-response.md)
- [Performance Issues](./troubleshooting/performance-issues.md)

## Common Incident Scenarios

### Deployment Failure
1. Check recent deployments
2. Review deployment logs
3. Rollback if necessary
4. Investigate root cause

### Database Issues
1. Check database connectivity
2. Review database logs
3. Check resource usage
4. Scale or restart if needed

### Build System Failure
1. Check Buck2 daemon status
2. Review build logs
3. Clear cache if corrupted
4. Restart daemon

### Security Incident
1. Follow security incident runbook
2. Isolate affected systems
3. Preserve evidence
4. Notify security team immediately

## Incident Report Template

```markdown
# Incident Report: [Title]

## Summary
- **Date**: [Date]
- **Duration**: [Start time - End time]
- **Severity**: [1-4]
- **Impact**: [Description of impact]

## Timeline
- [Time]: Incident detected
- [Time]: Investigation started
- [Time]: Root cause identified
- [Time]: Fix implemented
- [Time]: Incident resolved

## Root Cause
[Detailed explanation of what caused the incident]

## Resolution
[What was done to resolve the incident]

## Lessons Learned
### What went well
- [List positive aspects]

### What could be improved
- [List areas for improvement]

## Action Items
- [ ] [Action item 1] - Owner: [Name] - Due: [Date]
- [ ] [Action item 2] - Owner: [Name] - Due: [Date]
```

## References

- [Incident Management Policy](https://wiki.company.com/incident-management)
- [On-Call Procedures](https://wiki.company.com/on-call)
- [Emergency Contacts](https://wiki.company.com/emergency-contacts)
- [Monitoring Runbooks](./performance-monitoring.md)