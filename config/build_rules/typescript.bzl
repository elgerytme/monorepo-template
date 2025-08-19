# Buck2 build rules for TypeScript/JavaScript with Rust tooling integration
# Prioritizes Rust-based tools for formatting, linting, and building

load("//config/build_rules:rust_tools.bzl", "rust_formatter", "rust_linter")

def typescript_library(
    name,
    srcs,
    deps = [],
    tsconfig = "//config:tsconfig.json",
    visibility = ["PUBLIC"],
    **kwargs
):
    """
    Build a TypeScript library with Rust-based tooling integration.
    
    Args:
        name: Target name
        srcs: TypeScript source files
        deps: Dependencies (other TS targets, npm packages)
        tsconfig: TypeScript configuration file
        visibility: Target visibility
    """
    
    # Format check using dprint (Rust-based formatter)
    rust_formatter(
        name = name + "_format_check",
        srcs = srcs,
        formatter = "dprint",
        config = "//config:dprint.json",
    )
    
    # Lint using a Rust-based linter where possible
    rust_linter(
        name = name + "_lint",
        srcs = srcs,
        linter = "eslint_rs",  # Rust-based ESLint alternative
        config = "//config:.eslintrc.json",
    )
    
    native.typescript_library(
        name = name,
        srcs = srcs,
        deps = deps + [
            name + "_format_check",
            name + "_lint",
        ],
        tsconfig = tsconfig,
        visibility = visibility,
        **kwargs
    )

def typescript_binary(
    name,
    entry_point,
    deps = [],
    tsconfig = "//config:tsconfig.json",
    bundler = "esbuild",  # Fast Rust-based bundler alternative
    visibility = ["PUBLIC"],
    **kwargs
):
    """
    Build a TypeScript binary/application with Rust tooling.
    """
    
    # Use esbuild (Go-based but very fast) or swc (Rust-based) for bundling
    native.typescript_binary(
        name = name,
        entry_point = entry_point,
        deps = deps,
        tsconfig = tsconfig,
        bundler = bundler,
        visibility = visibility,
        **kwargs
    )

def typescript_test(
    name,
    srcs,
    deps = [],
    test_runner = "vitest",  # Modern test runner with Rust-based tools
    tsconfig = "//config:tsconfig.test.json",
    **kwargs
):
    """
    Build TypeScript tests with modern tooling.
    """
    
    native.typescript_test(
        name = name,
        srcs = srcs,
        deps = deps + [
            "//tools/testing:vitest_config",
        ],
        test_runner = test_runner,
        tsconfig = tsconfig,
        **kwargs
    )

def react_application(
    name,
    entry_point,
    deps = [],
    public_dir = "public",
    **kwargs
):
    """
    Build a React application with optimized Rust-based tooling.
    """
    
    typescript_binary(
        name = name,
        entry_point = entry_point,
        deps = deps + [
            "//libs/frontend:react_common",
        ],
        bundler = "vite",  # Uses esbuild internally (Go) and swc (Rust)
        **kwargs
    )

def node_service(
    name,
    entry_point,
    deps = [],
    runtime = "node",
    **kwargs
):
    """
    Build a Node.js service with TypeScript and Rust tooling.
    """
    
    typescript_binary(
        name = name,
        entry_point = entry_point,
        deps = deps + [
            "//libs/backend:node_common",
            "//libs/common:observability_js",
        ],
        runtime = runtime,
        **kwargs
    )