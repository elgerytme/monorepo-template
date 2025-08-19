# Build System Maintenance

## Overview

This runbook covers routine maintenance procedures for the Buck2 build system, including cache management, performance optimization, and troubleshooting common issues.

## Prerequisites

- Access to the monorepo
- Buck2 CLI installed and configured
- Administrative access to build infrastructure
- Understanding of Buck2 concepts (targets, actions, cache)

## Daily Maintenance

### Morning Health Check

**Frequency**: Daily at 9:00 AM

1. **Check build system status**
   ```bash
   buck2 status
   ```

2. **Verify daemon is running**
   ```bash
   ps aux | grep buck2
   ```

3. **Check cache hit rates**
   ```bash
   buck2 log cache-hit-rate --last-24h
   ```

4. **Review overnight build failures**
   ```bash
   buck2 log what-failed --since="24 hours ago"
   ```

5. **Check disk space**
   ```bash
   df -h .buck-cache/
   du -sh .buck-cache/
   ```

**Expected Results**:
- Daemon running normally
- Cache hit rate > 70%
- Disk usage < 80% of allocated space
- No critical build failures

### Cache Maintenance

**Frequency**: Daily

1. **Clean old cache entries**
   ```bash
   # Remove cache entries older than 7 days
   find .buck-cache -type f -mtime +7 -delete
   ```

2. **Verify cache integrity**
   ```bash
   buck2 cache verify
   ```

3. **Check cache statistics**
   ```bash
   buck2 cache stats
   ```

4. **Optimize cache if needed**
   ```bash
   # If cache hit rate < 60%
   buck2 cache optimize
   ```

## Weekly Maintenance

### Performance Analysis

**Frequency**: Weekly on Mondays

1. **Generate performance report**
   ```bash
   buck2 log performance-report --last-week > weekly-performance.txt
   ```

2. **Identify slow targets**
   ```bash
   buck2 log what-ran --format=json --last-week | \
     jq '.[] | select(.duration > 30) | {target: .target, duration: .duration}' | \
     sort -k2 -nr > slow-targets.json
   ```

3. **Check build parallelism**
   ```bash
   buck2 log parallelism-stats --last-week
   ```

4. **Review resource usage**
   ```bash
   buck2 log resource-usage --last-week
   ```

### Dependency Analysis

1. **Check for circular dependencies**
   ```bash
   buck2 query "allpaths(//..., //...)" --output-format=dot | \
     dot -Tpng -o dependency-graph.png
   ```

2. **Identify large dependency chains**
   ```bash
   buck2 query "deps(//...)" --output-format=json | \
     jq '.[] | length' | sort -nr | head -20
   ```

3. **Find unused dependencies**
   ```bash
   buck2 audit unused-deps //...
   ```

## Monthly Maintenance

### System Optimization

**Frequency**: First Monday of each month

1. **Update Buck2 to latest version**
   ```bash
   # Check current version
   buck2 --version
   
   # Update Buck2
   curl -L https://github.com/facebook/buck2/releases/latest/download/buck2-x86_64-unknown-linux-gnu.zst | \
     zstd -d -o /usr/local/bin/buck2
   chmod +x /usr/local/bin/buck2
   
   # Verify update
   buck2 --version
   ```

2. **Clean and rebuild cache**
   ```bash
   # Backup important cache data
   cp -r .buck-cache .buck-cache.backup
   
   # Clean cache
   buck2 clean
   rm -rf .buck-cache
   
   # Rebuild critical targets
   buck2 build //apps/... //libs/...
   ```

3. **Update build rules**
   ```bash
   # Check for rule updates
   git log --oneline --since="1 month ago" config/build_rules/
   
   # Test rule changes
   buck2 build //examples/... --verbose
   ```

### Configuration Review

1. **Review .buckconfig settings**
   ```bash
   # Check for deprecated settings
   buck2 config validate
   
   # Review performance settings
   grep -E "(threads|cache|parallel)" .buckconfig
   ```

2. **Update platform configurations**
   ```bash
   # Verify platform detection
   buck2 query "//config/platforms:detector"
   
   # Test cross-platform builds
   buck2 build //... --target-platforms=//config/platforms:linux-x86_64
   ```

## Troubleshooting Procedures

### Build Daemon Issues

**Symptoms**: Builds hanging, daemon not responding

1. **Check daemon status**
   ```bash
   buck2 status --verbose
   ```

2. **Kill and restart daemon**
   ```bash
   buck2 kill
   sleep 5
   buck2 status  # This will start a new daemon
   ```

3. **Check daemon logs**
   ```bash
   buck2 log show --daemon
   ```

4. **If daemon won't start**
   ```bash
   # Remove daemon state
   rm -rf ~/.buck2/daemon/
   
   # Start fresh daemon
   buck2 status
   ```

### Cache Corruption

**Symptoms**: Inconsistent build results, cache verification failures

1. **Verify cache integrity**
   ```bash
   buck2 cache verify --verbose
   ```

2. **Identify corrupted entries**
   ```bash
   buck2 cache verify --repair --dry-run
   ```

3. **Repair cache**
   ```bash
   buck2 cache verify --repair
   ```

4. **If repair fails, clean cache**
   ```bash
   buck2 clean
   rm -rf .buck-cache
   ```

### Performance Degradation

**Symptoms**: Builds taking longer than usual

1. **Check system resources**
   ```bash
   top -p $(pgrep buck2)
   iostat -x 1 5
   ```

2. **Analyze build bottlenecks**
   ```bash
   buck2 build //... --profile
   buck2 log critical-path --last-build
   ```

3. **Check cache hit rates**
   ```bash
   buck2 log cache-hit-rate --last-build
   ```

4. **Optimize build parallelism**
   ```bash
   # Adjust thread count in .buckconfig
   [build]
   threads = 8  # Adjust based on CPU cores
   ```

### Disk Space Issues

**Symptoms**: Build failures due to insufficient disk space

1. **Check disk usage**
   ```bash
   df -h
   du -sh .buck-cache/
   ```

2. **Clean old cache entries**
   ```bash
   # Remove entries older than 3 days
   find .buck-cache -type f -mtime +3 -delete
   ```

3. **Clean build outputs**
   ```bash
   buck2 clean
   ```

4. **Archive old logs**
   ```bash
   # Compress old log files
   find ~/.buck2/logs -name "*.log" -mtime +7 -exec gzip {} \;
   ```

## Emergency Procedures

### Complete Build System Failure

**Severity**: Critical

1. **Immediate Response**
   ```bash
   # Check if it's a daemon issue
   buck2 kill
   buck2 status
   
   # Try simple build
   buck2 build //examples/shared-library:validation
   ```

2. **If daemon won't start**
   ```bash
   # Remove all Buck2 state
   rm -rf ~/.buck2/
   rm -rf .buck-cache/
   
   # Restart from clean state
   buck2 status
   ```

3. **If builds still fail**
   ```bash
   # Check Buck2 installation
   which buck2
   buck2 --version
   
   # Reinstall Buck2 if needed
   curl -L https://github.com/facebook/buck2/releases/latest/download/buck2-x86_64-unknown-linux-gnu.zst | \
     zstd -d -o /usr/local/bin/buck2
   chmod +x /usr/local/bin/buck2
   ```

4. **Escalation**
   - If issue persists > 30 minutes, escalate to build team
   - Create incident in monitoring system
   - Notify development teams of build system outage

### Remote Cache Failure

**Symptoms**: All builds showing cache misses

1. **Check remote cache connectivity**
   ```bash
   curl -I https://cache.company.com/health
   ```

2. **Disable remote cache temporarily**
   ```bash
   # Edit .buckconfig
   [cache]
   mode = local_only
   ```

3. **Test local builds**
   ```bash
   buck2 build //examples/...
   ```

4. **Re-enable when remote cache is restored**
   ```bash
   # Edit .buckconfig
   [cache]
   mode = readwrite
   ```

## Monitoring and Alerts

### Key Metrics

- **Build Success Rate**: Should be > 95%
- **Cache Hit Rate**: Should be > 70%
- **Average Build Time**: Track trends
- **Daemon Uptime**: Should be > 99%

### Alert Conditions

- Build failure rate > 10% in 1 hour
- Cache hit rate < 50% for 30 minutes
- Daemon restarts > 3 in 1 hour
- Disk usage > 90%

### Dashboard Links

- [Build System Dashboard](https://monitoring.company.com/buck2)
- [Cache Performance](https://monitoring.company.com/cache)
- [Build Metrics](https://monitoring.company.com/builds)

## Verification

After maintenance procedures:

1. **Test basic functionality**
   ```bash
   buck2 build //examples/...
   buck2 test //examples/...
   ```

2. **Verify cache is working**
   ```bash
   buck2 build //examples/shared-library:validation
   buck2 build //examples/shared-library:validation  # Should be cached
   ```

3. **Check performance**
   ```bash
   time buck2 build //...
   ```

## Rollback Procedures

If maintenance causes issues:

1. **Restore Buck2 version**
   ```bash
   # If you backed up the old version
   cp /usr/local/bin/buck2.backup /usr/local/bin/buck2
   ```

2. **Restore cache**
   ```bash
   # If you backed up cache
   rm -rf .buck-cache
   mv .buck-cache.backup .buck-cache
   ```

3. **Restore configuration**
   ```bash
   git checkout HEAD~1 -- .buckconfig config/
   ```

## References

- [Buck2 Documentation](https://buck2.build/)
- [Build System Architecture](../architecture/build-system.md)
- [Performance Troubleshooting](./troubleshooting/performance-issues.md)
- [Cache Management Guide](./maintenance/cache-management.md)