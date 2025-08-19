# VS Code Workspace Configuration

This directory contains VS Code workspace configuration files that provide IDE integration for the monorepo template.

## Files Overview

### Core Configuration
- **`settings.json`** - Workspace-specific settings for all languages and tools
- **`tasks.json`** - Build, test, and development tasks
- **`launch.json`** - Debug configurations for all supported languages
- **`extensions.json`** - Recommended and unwanted extensions
- **`keybindings.json`** - Custom keyboard shortcuts for development tasks

### Code Snippets
- **`snippets/rust.json`** - Rust-specific code snippets
- **`snippets/python.json`** - Python and Buck2 Python snippets
- **`snippets/typescript.json`** - TypeScript/JavaScript snippets
- **`snippets/go.json`** - Go language snippets
- **`snippets/buck.json`** - Buck2 build system snippets

## Key Features

### Language Support
- **Rust**: Full rust-analyzer integration with clippy, formatting, and debugging
- **TypeScript/JavaScript**: Complete language server support with dprint formatting
- **Python**: Black formatting, flake8 linting, mypy type checking, pytest integration
- **Go**: Full language server with testing and debugging support

### Build System Integration
- **Buck2**: Syntax highlighting for BUCK files, build tasks, and snippets
- **Cargo**: Rust workspace support with nextest integration
- **npm/yarn**: Frontend build and test tasks

### Development Tools
- **Debugging**: Configurations for all languages including LLDB for Rust
- **Testing**: Integrated test runners and coverage reporting
- **Formatting**: Consistent code formatting across all languages
- **Linting**: Language-specific linting and static analysis

### Performance Optimizations
- Excluded build artifacts and cache directories from file watching
- Optimized search settings to ignore generated files
- Language server performance tuning
- Efficient file indexing configuration

## Quick Start

1. **Open Workspace**: Use `monorepo-template.code-workspace` to open the full workspace
2. **Install Extensions**: VS Code will prompt to install recommended extensions
3. **Run Setup**: Use `Ctrl+Shift+P` → "Tasks: Run Task" → "Setup Development Environment"
4. **Health Check**: Run "Health Check" task to verify all tools are working

## Common Tasks

### Build and Test
- `Ctrl+Shift+B` - Build all projects with Buck2
- `Ctrl+Shift+T` - Run all tests
- `Ctrl+Shift+U` - Run Rust tests with nextest
- `Ctrl+Shift+R` - Run Rust check (fast compilation check)

### Code Quality
- `Ctrl+Shift+F` - Format all code
- `Ctrl+Shift+S` - Run security scans
- `Ctrl+Alt+C` - Clean all build artifacts

### Development
- `F5` - Start debugging
- `Ctrl+Shift+D` - Generate documentation
- `Ctrl+Alt+H` - Run health check

## Debugging Setup

### Rust Applications
1. Set breakpoints in your Rust code
2. Select "Debug Rust Binary" or "Debug Web Service" configuration
3. Press F5 to start debugging

### TypeScript/Node.js
1. Ensure your TypeScript is compiled (`npm run build`)
2. Select "Debug TypeScript/Node.js" configuration
3. Press F5 to start debugging

### Python Applications
1. Set breakpoints in Python code
2. Select "Debug Python Application" or "Debug Python Tests"
3. Press F5 to start debugging

### Go Applications
1. Set breakpoints in Go code
2. Select "Debug Go Application" or "Debug Go Tests"
3. Press F5 to start debugging

## Code Snippets Usage

Type the snippet prefix and press Tab to expand:

### Rust Snippets
- `test` - Create a test module with test function
- `atest` - Create an async test function
- `error` - Create an error enum with thiserror
- `builder` - Create a struct with builder pattern
- `handler` - Create a web handler function
- `instrument` - Create an instrumented function with tracing

### Buck2 Snippets
- `rust_binary` - Create a Rust binary rule
- `rust_library` - Create a Rust library rule
- `python_binary` - Create a Python binary rule
- `go_library` - Create a Go library rule

### Testing Snippets
- `testclass` (Python) - Create a pytest test class
- `test` (Go) - Create a Go test function
- `bench` (Go) - Create a Go benchmark function

## Troubleshooting

### Language Server Issues
1. Check that all required tools are installed (`scripts/setup/health-check.sh`)
2. Restart the language server: `Ctrl+Shift+P` → "Developer: Reload Window"
3. Check the Output panel for error messages

### Build Issues
1. Ensure Buck2 is properly installed and configured
2. Run `buck2 clean` to clear build cache
3. Check `.buckconfig` for correct tool paths

### Performance Issues
1. Exclude additional directories in `files.watcherExclude` if needed
2. Disable unused extensions
3. Increase VS Code memory limit if working with large codebases

### Extension Conflicts
The `extensions.json` file includes `unwantedRecommendations` to prevent conflicting extensions. If you experience formatting or language server conflicts, check that conflicting extensions are disabled.

## Customization

### Adding New Languages
1. Add language-specific extensions to `extensions.json`
2. Configure language server settings in `settings.json`
3. Add formatting rules for the new language
4. Create debug configurations in `launch.json`
5. Add build tasks in `tasks.json`
6. Create code snippets in `snippets/`

### Custom Tasks
Add new tasks to `tasks.json` following the existing patterns. Tasks can be:
- Shell commands
- Script executions
- Composite tasks that run multiple commands

### Keyboard Shortcuts
Modify `keybindings.json` to add or change keyboard shortcuts. Use `Ctrl+K Ctrl+S` to open the keyboard shortcuts editor for a visual interface.

## Integration with Development Container

The workspace configuration is automatically applied when using the development container (`.devcontainer/devcontainer.json`). The container includes all necessary tools and extensions for a consistent development experience across different machines.