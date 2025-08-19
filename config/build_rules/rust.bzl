# Buck2 build rules for Rust projects
# Provides comprehensive Rust build support with proper dependency handling

def rust_binary(
    name,
    srcs,
    deps = [],
    features = [],
    edition = "2021",
    rustc_flags = [],
    env = {},
    visibility = ["PUBLIC"],
    **kwargs
):
    """
    Build a Rust binary with enhanced dependency handling and tooling integration.
    
    Args:
        name: Target name
        srcs: Source files (typically main.rs or lib.rs)
        deps: Dependencies (other Rust targets, external crates)
        features: Cargo features to enable
        edition: Rust edition (default: 2021)
        rustc_flags: Additional compiler flags
        env: Environment variables for build
        visibility: Target visibility
    """
    
    # Enhanced rustc flags with security and performance optimizations
    enhanced_flags = [
        "--cap-lints=warn",
        "-D", "warnings",
        "-D", "clippy::all",
        "-D", "clippy::pedantic",
        "-A", "clippy::module_name_repetitions",
    ] + rustc_flags
    
    native.rust_binary(
        name = name,
        srcs = srcs,
        deps = deps + [
            "//libs/common:logging",  # Standard logging integration
            "//libs/common:metrics",  # Metrics collection
        ],
        features = features,
        edition = edition,
        rustc_flags = enhanced_flags,
        env = env,
        visibility = visibility,
        **kwargs
    )

def rust_library(
    name,
    srcs,
    deps = [],
    features = [],
    edition = "2021",
    rustc_flags = [],
    proc_macro = False,
    visibility = ["PUBLIC"],
    **kwargs
):
    """
    Build a Rust library with comprehensive dependency management.
    """
    
    enhanced_flags = [
        "--cap-lints=warn",
        "-D", "warnings",
        "-D", "clippy::all",
        "-D", "clippy::pedantic",
        "-A", "clippy::module_name_repetitions",
    ] + rustc_flags
    
    native.rust_library(
        name = name,
        srcs = srcs,
        deps = deps,
        features = features,
        edition = edition,
        rustc_flags = enhanced_flags,
        proc_macro = proc_macro,
        visibility = visibility,
        **kwargs
    )

def rust_test(
    name,
    srcs,
    deps = [],
    features = [],
    edition = "2021",
    rustc_flags = [],
    env = {},
    visibility = ["PUBLIC"],
    **kwargs
):
    """
    Build Rust tests with nextest integration and enhanced reporting.
    """
    
    test_flags = [
        "--cap-lints=warn",
        "--cfg", "test",
    ] + rustc_flags
    
    native.rust_test(
        name = name,
        srcs = srcs,
        deps = deps + [
            "//tools/testing:test_utils",
        ],
        features = features,
        edition = edition,
        rustc_flags = test_flags,
        env = env,
        visibility = visibility,
        **kwargs
    )

def rust_benchmark(
    name,
    srcs,
    deps = [],
    features = [],
    edition = "2021",
    rustc_flags = [],
    **kwargs
):
    """
    Build Rust benchmarks with criterion integration.
    """
    
    rust_binary(
        name = name,
        srcs = srcs,
        deps = deps + [
            "//tools/benchmarking:criterion_utils",
        ],
        features = features + ["criterion"],
        edition = edition,
        rustc_flags = rustc_flags,
        **kwargs
    )