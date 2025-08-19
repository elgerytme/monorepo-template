# Rust-based tooling integration for Buck2 build rules
# Provides common Rust tools for formatting, linting, and other development tasks

def rust_formatter(
    name,
    srcs,
    formatter,
    config = None,
    args = [],
    **kwargs
):
    """
    Run Rust-based formatters on source files.
    
    Args:
        name: Target name
        srcs: Source files to format
        formatter: Formatter tool (dprint, rustfmt, etc.)
        config: Configuration file for the formatter
        args: Additional arguments for the formatter
    """
    
    cmd_parts = [formatter]
    
    if config:
        if formatter == "dprint":
            cmd_parts.extend(["--config", "$(location " + config + ")"])
        elif formatter == "rustfmt":
            cmd_parts.extend(["--config-path", "$(location " + config + ")"])
        elif formatter == "ruff":
            cmd_parts.extend(["--config", "$(location " + config + ")"])
    
    cmd_parts.extend(args)
    cmd_parts.append("$SRCS")
    
    native.genrule(
        name = name,
        srcs = srcs + ([config] if config else []),
        cmd = " ".join(cmd_parts) + " && touch $(OUT)",
        out = name + ".done",
        **kwargs
    )

def rust_linter(
    name,
    srcs,
    linter,
    config = None,
    args = [],
    **kwargs
):
    """
    Run Rust-based linters on source files.
    
    Args:
        name: Target name
        srcs: Source files to lint
        linter: Linter tool (clippy, ruff, etc.)
        config: Configuration file for the linter
        args: Additional arguments for the linter
    """
    
    cmd_parts = [linter]
    
    if config:
        if linter == "clippy":
            # Clippy uses rustc-style config
            cmd_parts.extend(["--", "--config-path", "$(location " + config + ")"])
        elif linter == "ruff":
            cmd_parts.extend(["--config", "$(location " + config + ")"])
        elif linter == "eslint_rs":
            cmd_parts.extend(["--config", "$(location " + config + ")"])
    
    cmd_parts.extend(args)
    cmd_parts.append("$SRCS")
    
    native.genrule(
        name = name,
        srcs = srcs + ([config] if config else []),
        cmd = " ".join(cmd_parts) + " > $(OUT)",
        out = name + "_results.json",
        **kwargs
    )

def rust_security_scanner(
    name,
    srcs,
    scanner = "cargo-audit",
    **kwargs
):
    """
    Run security scanning using Rust-based tools.
    """
    
    if scanner == "cargo-audit":
        cmd = "cargo audit --json > $(OUT)"
    else:
        cmd = scanner + " $SRCS > $(OUT)"
    
    native.genrule(
        name = name,
        srcs = srcs,
        cmd = cmd,
        out = name + "_security.json",
        **kwargs
    )

def rust_benchmark(
    name,
    srcs,
    benchmarker = "hyperfine",
    command,
    **kwargs
):
    """
    Run benchmarks using Rust-based benchmarking tools.
    """
    
    if benchmarker == "hyperfine":
        cmd = "hyperfine --export-json $(OUT) '" + command + "'"
    else:
        cmd = benchmarker + " " + command + " > $(OUT)"
    
    native.genrule(
        name = name,
        srcs = srcs,
        cmd = cmd,
        out = name + "_benchmark.json",
        **kwargs
    )

def rust_code_stats(
    name,
    srcs,
    **kwargs
):
    """
    Generate code statistics using tokei (Rust-based tool).
    """
    
    native.genrule(
        name = name,
        srcs = srcs,
        cmd = "tokei --output json $SRCS > $(OUT)",
        out = name + "_stats.json",
        **kwargs
    )

def rust_spell_check(
    name,
    srcs,
    config = "//config:typos.toml",
    **kwargs
):
    """
    Run spell checking using typos (Rust-based spell checker).
    """
    
    native.genrule(
        name = name,
        srcs = srcs + [config],
        cmd = "typos --config $(location " + config + ") $SRCS",
        out = name + "_typos.out",
        **kwargs
    )

def cross_language_deps(
    name,
    rust_targets = [],
    go_targets = [],
    python_targets = [],
    typescript_targets = [],
    **kwargs
):
    """
    Create cross-language dependency bridges.
    Enables different language projects to depend on each other.
    """
    
    # Generate FFI bindings for Rust libraries
    ffi_targets = []
    for rust_target in rust_targets:
        ffi_name = name + "_" + rust_target.replace(":", "_").replace("//", "") + "_ffi"
        
        native.genrule(
            name = ffi_name,
            srcs = [rust_target],
            cmd = "cbindgen --config $(location //config:cbindgen.toml) --output $(OUT) $(location " + rust_target + ")",
            out = ffi_name + ".h",
        )
        ffi_targets.append(":" + ffi_name)
    
    # Create a filegroup with all cross-language dependencies
    native.filegroup(
        name = name,
        srcs = ffi_targets,
        **kwargs
    )