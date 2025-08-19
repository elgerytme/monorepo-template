# Template Management Scripts

This directory contains scripts for managing the monorepo template lifecycle.

## Scripts Overview

### Template Initialization
- **`init-template.sh`** / **`init-template.ps1`** - Initialize a new project from the template
- **`validate-template.sh`** / **`validate-template.ps1`** - Validate template structure and configuration

### Template Updates
- **`update-template.sh`** / **`update-template.ps1`** - Update an existing project to latest template version

### Template Distribution
- **`package-template.sh`** / **`package-template.ps1`** - Package template for distribution

## Usage Examples

### Initialize New Project

```bash
# Linux/macOS
./scripts/template/init-template.sh --name my-project --org my-company --languages rust,typescript

# Windows PowerShell
.\scripts\template\init-template.ps1 -Name my-project -Organization my-company -Languages rust,typescript
```

### Validate Template

```bash
# Linux/macOS
./scripts/template/validate-template.sh

# Windows PowerShell
.\scripts\template\validate-template.ps1
```

### Update Existing Project

```bash
# Linux/macOS
./scripts/template/update-template.sh --version 1.2.0

# Windows PowerShell
.\scripts\template\update-template.ps1 -Version 1.2.0
```

### Package Template

```bash
# Linux/macOS
./scripts/template/package-template.sh --version 1.0.0 --format both

# Windows PowerShell
.\scripts\template\package-template.ps1 -Version 1.0.0 -Format both
```

## Template Versioning

The template uses semantic versioning (semver) with the following conventions:

- **Major version** (X.0.0): Breaking changes that require migration
- **Minor version** (0.X.0): New features, backward compatible
- **Patch version** (0.0.X): Bug fixes, backward compatible

Version information is stored in:
- `VERSION` file in repository root
- `.template-version` file in initialized projects
- Git tags (e.g., `v1.0.0`)

## Template Metadata

The `.template-metadata.json` file contains:
- Template information and requirements
- Supported languages and features
- Customization options
- Documentation links
- Example projects

## File Permissions

On Unix-like systems, make scripts executable:

```bash
chmod +x scripts/template/*.sh
```

On Windows, execution policy may need to be set:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Integration with CI/CD

These scripts can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
- name: Package Template
  run: ./scripts/template/package-template.sh --version ${{ github.ref_name }}

- name: Validate Template
  run: ./scripts/template/validate-template.sh
```

## Troubleshooting

### Common Issues

1. **Permission denied**: Make scripts executable or adjust execution policy
2. **Command not found**: Ensure required tools (git, tar, zip) are installed
3. **Version mismatch**: Check VERSION file and git tags are synchronized

### Getting Help

- Run any script with `--help` or `-h` for usage information
- Check the validation script output for configuration issues
- Review the migration guide in `docs/migration/MIGRATION_GUIDE.md`