# Automated Release Management System

This directory contains a comprehensive automated release management system that provides semantic versioning, release note generation, artifact signing, and automated rollback capabilities.

## Overview

The release management system consists of several interconnected components:

- **Version Manager**: Handles semantic versioning with automatic increment detection
- **Release Notes Generator**: Creates comprehensive release notes from git commits
- **Artifact Signing**: Provides cryptographic signing and verification of release artifacts
- **Rollback Manager**: Enables safe rollback capabilities with health monitoring
- **Release Orchestrator**: Coordinates the entire release process

## Components

### 1. Version Manager (`version-manager.sh/.ps1`)

Manages semantic versioning following semver principles.

**Features:**
- Automatic version increment detection from commit messages
- Support for major, minor, and patch increments
- Git tag creation and management
- Conventional commit parsing

**Usage:**
```bash
# Auto-detect version increment
./version-manager.sh bump

# Specific version increment
./version-manager.sh bump minor

# Show current version
./version-manager.sh current

# Analyze commits for suggested increment
./version-manager.sh analyze
```

### 2. Release Notes Generator (`release-notes-generator.sh/.ps1`)

Generates comprehensive release notes from git commit history.

**Features:**
- Categorizes commits by type (features, fixes, breaking changes, etc.)
- Supports conventional commit format
- Generates markdown-formatted release notes
- Updates CHANGELOG.md automatically
- Includes contributor information

**Usage:**
```bash
# Generate release notes for version
./release-notes-generator.sh generate 1.2.3
```

### 3. Artifact Signing (`artifact-signing.sh/.ps1`)

Provides cryptographic signing and verification of release artifacts.

**Features:**
- GPG signing with automatic key generation
- Cosign signing for container images and archives
- SHA256 checksum generation
- Batch signing of multiple artifacts
- Signature verification

**Usage:**
```bash
# Generate signing keys
./artifact-signing.sh generate-keys

# Sign all artifacts in directory
./artifact-signing.sh sign ./artifacts

# Verify all artifacts
./artifact-signing.sh verify ./artifacts

# Sign specific file
./artifact-signing.sh sign-file app.tar.gz
```

### 4. Rollback Manager (`rollback-manager.sh/.ps1`)

Enables safe rollback capabilities with automated health monitoring.

**Features:**
- Deployment state recording
- Health check monitoring with customizable checks
- Automatic rollback on failure detection
- Multiple rollback types (git, container, database)
- Rollback history tracking

**Usage:**
```bash
# Record deployment
./rollback-manager.sh record 1.2.3

# Monitor deployment health
./rollback-manager.sh monitor 1.2.3 basic,database 300

# Perform rollback
./rollback-manager.sh rollback 1.2.2

# Auto-monitor and rollback on failure
./rollback-manager.sh auto-rollback 1.2.3 basic 300
```

### 5. Release Orchestrator (`release-orchestrator.sh/.ps1`)

Coordinates the entire release process.

**Features:**
- Full release automation
- Configurable release pipeline
- Pre/post-release hooks
- Notification system
- Health monitoring integration

**Usage:**
```bash
# Perform full release
./release-orchestrator.sh release

# Release with specific version increment
./release-orchestrator.sh release minor

# Release without building artifacts
./release-orchestrator.sh release auto --skip-build

# Rollback to previous version
./release-orchestrator.sh rollback

# Show system status
./release-orchestrator.sh status
```

## Configuration

The system uses a JSON configuration file (`.release-config.json`) in the repository root:

```json
{
    "release": {
        "auto_version": true,
        "generate_release_notes": true,
        "sign_artifacts": true,
        "enable_rollback": true,
        "health_checks": ["basic"],
        "health_check_timeout": 300,
        "pre_release_hooks": [],
        "post_release_hooks": [],
        "notification": {
            "enabled": false,
            "webhook_url": "",
            "channels": []
        }
    },
    "artifacts": {
        "build_command": "just build-all",
        "output_directory": "./artifacts",
        "include_patterns": ["*.tar.gz", "*.zip", "*.deb", "*.rpm"],
        "exclude_patterns": ["*.tmp", "*.log"]
    },
    "signing": {
        "gpg_key_id": "",
        "cosign_enabled": true,
        "verify_signatures": true
    },
    "rollback": {
        "enabled": true,
        "auto_rollback": true,
        "rollback_types": ["git", "container"],
        "health_check_retries": 3
    }
}
```

## Environment Variables

### Required for Signing
- `GPG_KEY_ID`: GPG key ID for artifact signing
- `COSIGN_KEY`: Path to Cosign private key (optional)

### Optional
- `RELEASE_WEBHOOK_URL`: Webhook URL for notifications
- `HEALTH_CHECK_ENDPOINT`: Custom health check endpoint

## GitHub Actions Integration

The system includes a comprehensive GitHub Actions workflow (`.github/workflows/release.yml`) that:

1. Analyzes commits to determine if a release is needed
2. Builds and tests the project
3. Performs the automated release
4. Monitors release health
5. Sends notifications

### Workflow Triggers
- Push to main/master branch
- Manual workflow dispatch
- Git tag creation

### Workflow Inputs
- `release_type`: Type of release (auto, major, minor, patch)
- `skip_build`: Skip artifact building
- `force_release`: Force release even if no changes detected

## Security Considerations

### Artifact Signing
- GPG keys should be generated with strong passphrases
- Private keys must never be committed to version control
- Use GitHub Secrets for storing signing keys in CI/CD
- Cosign keys should be stored securely

### Access Control
- Use dedicated service accounts for automated releases
- Limit repository permissions for release tokens
- Enable branch protection rules
- Require signed commits for release branches

## Health Checks

The system supports customizable health checks:

### Built-in Health Check Types
- `basic`: HTTP endpoint health check
- `database`: Database connectivity check (customizable)
- `service`: Service-specific health check (customizable)

### Custom Health Checks
You can extend the health check system by modifying the `perform_health_check` function in `rollback-manager.sh/.ps1`.

## Rollback Strategies

### Git-based Rollback
- Checks out previous version tag
- Stashes uncommitted changes
- Supports both tag and commit rollback

### Container Rollback
- Placeholder for container orchestration rollback
- Customize for your container platform (Docker, Kubernetes, etc.)

### Database Rollback
- Placeholder for database migration rollback
- Customize for your database migration system

## Troubleshooting

### Common Issues

1. **Version bump fails**
   - Check git repository state
   - Ensure proper commit message format
   - Verify git tags are accessible

2. **Artifact signing fails**
   - Verify GPG key is properly configured
   - Check GPG_KEY_ID environment variable
   - Ensure signing tools are installed

3. **Health checks fail**
   - Verify health check endpoints are accessible
   - Check network connectivity
   - Review health check timeout settings

4. **Rollback fails**
   - Ensure previous version exists
   - Check git repository permissions
   - Verify rollback target is valid

### Debugging

Enable verbose logging by setting:
```bash
export DEBUG=1
```

Check log files:
- `.rollback/rollback.log`: Rollback operations
- `.rollback/deployment.log`: Deployment history

## Best Practices

1. **Commit Messages**: Use conventional commit format for automatic version detection
2. **Testing**: Always test releases in staging environment first
3. **Monitoring**: Set up proper health checks for your application
4. **Backup**: Ensure database and configuration backups before releases
5. **Documentation**: Keep release notes and documentation up to date

## Dependencies

### Required Tools
- `git`: Version control operations
- `jq`: JSON processing (Linux/macOS)
- `gpg`: Artifact signing
- `cosign`: Container signing (optional)
- `curl` or `wget`: HTTP health checks

### Optional Tools
- `just`: Command runner (configurable)
- `docker`: Container operations
- `kubectl`: Kubernetes operations

## Contributing

When contributing to the release management system:

1. Test changes in a separate branch
2. Update documentation for new features
3. Add appropriate error handling
4. Follow existing code style
5. Test on both Linux and Windows platforms

## License

This release management system is part of the monorepo template and follows the same license terms as the main project.