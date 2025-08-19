# ADR-001: Build System Selection: Buck2 vs Bazel

## Status

Accepted

## Context

The monorepo template requires a build system capable of handling large-scale, multi-language projects with fast, reliable, and hermetic builds. The primary candidates are Buck2 (Meta's build system) and Bazel (Google's build system), both designed for monorepo environments.

Key requirements:
- Fast incremental builds
- Multi-language support (Rust, TypeScript, Python, Go)
- Hermetic and reproducible builds
- Remote caching and execution
- Active development and community support
- Integration with existing tooling

## Decision

We have chosen **Buck2** as the primary build system for the monorepo template.

## Consequences

### Positive

- **Performance**: Buck2 is written in Rust, providing excellent performance for build graph analysis and execution
- **Modern Architecture**: Clean separation between analysis and execution phases
- **Rust Integration**: Native Rust support with excellent tooling integration
- **Incremental Builds**: Advanced incremental build capabilities with fine-grained dependency tracking
- **Remote Execution**: Built-in support for remote execution and caching
- **Starlark**: Uses Starlark (Python-like) for build file syntax, making it accessible to developers
- **Active Development**: Actively developed by Meta with regular releases

### Negative

- **Ecosystem Maturity**: Smaller ecosystem compared to Bazel
- **Learning Curve**: Requires team training on Buck2 concepts and build file syntax
- **Documentation**: Less extensive documentation compared to Bazel
- **Third-party Rules**: Fewer community-contributed rules available
- **Migration Path**: Limited tooling for migrating from other build systems

### Neutral

- **Vendor Lock-in**: Some dependency on Meta's continued development, though it's open source
- **Community Size**: Smaller but growing community compared to Bazel

## Alternatives Considered

### Bazel

**Pros:**
- Mature ecosystem with extensive rule sets
- Large community and extensive documentation
- Proven at scale (used by Google, Uber, etc.)
- Rich third-party integrations
- Established migration tooling

**Cons:**
- Written in Java, potentially slower than Buck2
- More complex configuration and setup
- Steeper learning curve for advanced features
- Less optimal Rust integration
- Larger resource footprint

### Cargo Workspaces

**Pros:**
- Native Rust tooling
- Simple setup and configuration
- Excellent IDE integration
- Familiar to Rust developers

**Cons:**
- Rust-only, doesn't support multi-language projects
- Limited scalability for very large codebases
- No remote execution capabilities
- Basic caching compared to Buck2/Bazel

### Make/CMake

**Pros:**
- Universal availability
- Simple mental model
- Extensive ecosystem support

**Cons:**
- Poor scalability for large projects
- No built-in dependency management
- Limited incremental build capabilities
- No remote execution support
- Difficult to maintain for complex projects

### Nx/Rush (JavaScript-focused)

**Pros:**
- Excellent JavaScript/TypeScript support
- Good developer experience
- Built-in caching and task orchestration

**Cons:**
- Primarily focused on JavaScript ecosystem
- Limited multi-language support
- Not designed for systems programming languages
- Less suitable for infrastructure code

## Implementation Plan

1. **Phase 1**: Set up basic Buck2 configuration with Rust support
2. **Phase 2**: Add TypeScript, Python, and Go language rules
3. **Phase 3**: Configure remote caching and execution
4. **Phase 4**: Integrate with CI/CD pipeline
5. **Phase 5**: Add advanced features (code coverage, profiling)

## Success Metrics

- Build time reduction of >50% compared to baseline
- Cache hit rate >80% for incremental builds
- Developer onboarding time <2 hours for build system
- Zero build reproducibility issues in CI

## References

- [Buck2 Documentation](https://buck2.build/)
- [Bazel Documentation](https://bazel.build/)
- [Meta's Buck2 Announcement](https://engineering.fb.com/2023/04/06/open-source/buck2-open-source-large-scale-build-system/)
- [Build System Performance Comparison](https://blog.replit.com/nix-vs-docker)
- [Monorepo Build System Survey](https://monorepo.tools/#build-systems)