# ADR-002: Rust-First Tooling Strategy

## Status

Accepted

## Context

The monorepo template needs to establish a consistent tooling strategy across all development activities including formatting, linting, searching, file operations, and system utilities. Traditional Unix tools and language-specific tools create inconsistencies in behavior, performance, and maintenance overhead.

The Rust ecosystem has produced high-quality alternatives to many traditional tools that offer:
- Superior performance
- Consistent behavior across platforms
- Modern features and UX
- Active maintenance and development
- Memory safety and reliability

## Decision

We adopt a **Rust-first tooling strategy** where Rust-based tools are preferred over traditional alternatives whenever a suitable option exists.

## Consequences

### Positive

- **Performance**: Rust tools are typically faster than traditional alternatives (e.g., ripgrep vs grep)
- **Consistency**: Uniform behavior across different operating systems
- **Modern Features**: Better UX, colored output, and advanced functionality
- **Reliability**: Memory safety reduces crashes and undefined behavior
- **Maintenance**: Single ecosystem reduces complexity
- **Developer Experience**: Faster feedback loops and better error messages
- **Security**: Memory-safe tools reduce attack surface

### Negative

- **Learning Curve**: Developers need to learn new tool names and options
- **Ecosystem Dependency**: Reliance on Rust ecosystem maturity
- **Installation Overhead**: Additional tools to install and maintain
- **Compatibility**: Some scripts may need updates for new tool interfaces
- **Fallback Complexity**: Need fallback strategies when Rust tools aren't available

## Tool Mapping

### Core System Tools

| Purpose | Rust Tool | Traditional Tool | Rationale |
|---------|-----------|------------------|-----------|
| Text Search | `ripgrep` (rg) | `grep` | 10x faster, better defaults, Unicode support |
| File Finding | `fd` | `find` | Simpler syntax, faster, respects .gitignore |
| File Viewing | `bat` | `cat` | Syntax highlighting, line numbers, git integration |
| Directory Listing | `exa` | `ls` | Better formatting, git status, tree view |
| JSON Processing | `jq` | `jq` | Keep existing (no Rust alternative needed) |
| Process Monitoring | `procs` | `ps` | Better formatting, tree view, search |
| Disk Usage | `dust` | `du` | Visual tree, faster analysis |
| Network Tools | `bandwhich` | `netstat` | Real-time bandwidth usage |

### Development Tools

| Purpose | Rust Tool | Traditional Tool | Rationale |
|---------|-----------|------------------|-----------|
| Code Formatting | `rustfmt` + `dprint` | `prettier`, `black` | Consistent multi-language formatting |
| Linting | `clippy` | `eslint`, `pylint` | Rust-native, excellent error messages |
| Security Scanning | `cargo-audit` | `npm audit` | Comprehensive vulnerability database |
| Benchmarking | `hyperfine` | `time` | Statistical analysis, warmup runs |
| Code Statistics | `tokei` | `cloc` | Faster, more accurate, better output |
| File Watching | `watchexec` | `inotifywait` | Cross-platform, flexible patterns |
| Command Running | `just` | `make` | Modern syntax, better error handling |

### Build and CI Tools

| Purpose | Rust Tool | Traditional Tool | Rationale |
|---------|-----------|------------------|-----------|
| Test Runner | `nextest` | `cargo test` | Parallel execution, better reporting |
| Dependency Analysis | `cargo-deny` | Manual scripts | Policy enforcement, license checking |
| Log Processing | `Vector` | `logstash` | High performance, Rust-native |
| Container Building | `buildah` + Rust | `docker build` | Scriptable, rootless builds |

## Implementation Strategy

### Phase 1: Core Tools (Week 1-2)
- Install and configure ripgrep, fd, bat, exa
- Update documentation and scripts
- Train development team

### Phase 2: Development Tools (Week 3-4)
- Integrate dprint for multi-language formatting
- Set up cargo-audit in CI pipeline
- Configure hyperfine for benchmarking

### Phase 3: Advanced Tools (Week 5-6)
- Deploy Vector for log processing
- Set up nextest for testing
- Configure cargo-deny policies

### Phase 4: Optimization (Week 7-8)
- Performance tuning and configuration
- Custom tool configurations
- Advanced integrations

## Fallback Strategy

When Rust tools are not available or suitable:

1. **Graceful Degradation**: Scripts should detect tool availability and fall back
2. **Documentation**: Clear documentation of alternatives
3. **Container Images**: Ensure all tools are available in CI/dev containers
4. **Installation Scripts**: Automated installation of Rust tools

Example fallback pattern:
```bash
# Prefer ripgrep, fallback to grep
if command -v rg >/dev/null 2>&1; then
    rg "$pattern" "$path"
else
    grep -r "$pattern" "$path"
fi
```

## Configuration Standards

### Tool Configuration Files

- `config/rust-toolchain.toml` - Rust toolchain version
- `config/rustfmt.toml` - Rust formatting rules
- `config/clippy.toml` - Rust linting rules
- `config/dprint.json` - Multi-language formatting
- `config/typos.toml` - Spell checking configuration

### Environment Variables

```bash
# Rust tool preferences
export RIPGREP_CONFIG_PATH="$PWD/config/.ripgreprc"
export BAT_CONFIG_PATH="$PWD/config/bat.conf"
export FD_OPTIONS="--hidden --follow --exclude .git"
```

## Success Metrics

- **Performance**: 50% improvement in common operations (search, build, test)
- **Consistency**: 100% of tools work identically across platforms
- **Adoption**: 90% of developers using Rust tools within 30 days
- **Reliability**: <1% tool-related failures in CI/CD
- **Developer Satisfaction**: >80% positive feedback on tooling changes

## Training and Documentation

### Developer Training
- Tool comparison cheat sheet
- Migration guide for common workflows
- Video tutorials for key tools
- Office hours for questions

### Documentation Updates
- Update all README files with new tool usage
- Modify CI/CD documentation
- Update troubleshooting guides
- Create tool-specific runbooks

## Monitoring and Evaluation

### Performance Monitoring
- Track build times before/after migration
- Monitor CI/CD pipeline performance
- Measure developer productivity metrics

### Feedback Collection
- Weekly surveys during transition period
- Issue tracking for tool-related problems
- Regular retrospectives

### Continuous Improvement
- Monthly tool evaluation
- Version updates and security patches
- New tool evaluation process

## References

- [Rust Tools Overview](https://github.com/rust-unofficial/awesome-rust#command-line)
- [ripgrep Performance Comparison](https://blog.burntsushi.net/ripgrep/)
- [Modern Unix Tools](https://github.com/ibraheemdev/modern-unix)
- [Rust in Production Survey](https://blog.rust-lang.org/2023/08/07/Rust-Survey-2023-Results.html)