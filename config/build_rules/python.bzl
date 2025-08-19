# Buck2 build rules for Python projects with Rust-based linting and tooling
# Integrates Rust-based tools for enhanced performance and consistency

load("//config/build_rules:rust_tools.bzl", "rust_formatter", "rust_linter")

def python_library(
    name,
    srcs,
    deps = [],
    base_module = "",
    visibility = ["PUBLIC"],
    **kwargs
):
    """
    Build a Python library with Rust-based tooling integration.
    
    Args:
        name: Target name
        srcs: Python source files
        deps: Dependencies (other Python targets, pip packages)
        base_module: Base module path
        visibility: Target visibility
    """
    
    # Format using ruff (Rust-based Python formatter/linter)
    rust_formatter(
        name = name + "_format",
        srcs = srcs,
        formatter = "ruff",
        config = "//config:ruff.toml",
        args = ["format", "--check"],
    )
    
    # Lint using ruff (extremely fast Rust-based Python linter)
    rust_linter(
        name = name + "_lint",
        srcs = srcs,
        linter = "ruff",
        config = "//config:ruff.toml",
        args = ["check"],
    )
    
    # Type checking with mypy (still Python-based, but integrated)
    native.genrule(
        name = name + "_typecheck",
        srcs = srcs,
        cmd = "mypy --config-file $(location //config:mypy.ini) $SRCS",
        out = name + "_typecheck.out",
    )
    
    native.python_library(
        name = name,
        srcs = srcs,
        deps = deps + [
            name + "_format",
            name + "_lint",
            name + "_typecheck",
        ],
        base_module = base_module,
        visibility = visibility,
        **kwargs
    )

def python_binary(
    name,
    main,
    deps = [],
    visibility = ["PUBLIC"],
    **kwargs
):
    """
    Build a Python binary with comprehensive tooling checks.
    """
    
    native.python_binary(
        name = name,
        main = main,
        deps = deps + [
            "//libs/python:common_logging",
            "//libs/python:metrics",
        ],
        visibility = visibility,
        **kwargs
    )

def python_test(
    name,
    srcs,
    deps = [],
    test_runner = "pytest",
    **kwargs
):
    """
    Build Python tests with pytest and coverage reporting.
    """
    
    # Security scanning with bandit (Python security linter)
    native.genrule(
        name = name + "_security_scan",
        srcs = srcs,
        cmd = "bandit -r $SRCS -f json -o $(OUT)",
        out = name + "_security.json",
    )
    
    native.python_test(
        name = name,
        srcs = srcs,
        deps = deps + [
            "//tools/testing:pytest_config",
            name + "_security_scan",
        ],
        test_runner = test_runner,
        **kwargs
    )

def python_wheel(
    name,
    srcs,
    deps = [],
    setup_py = "setup.py",
    **kwargs
):
    """
    Build a Python wheel package with metadata validation.
    """
    
    # Validate package metadata
    native.genrule(
        name = name + "_validate",
        srcs = [setup_py] + srcs,
        cmd = "python -m build --check-build-dependencies $(location " + setup_py + ")",
        out = name + "_validation.out",
    )
    
    native.python_wheel(
        name = name,
        srcs = srcs,
        deps = deps + [name + "_validate"],
        setup_py = setup_py,
        **kwargs
    )

def fastapi_service(
    name,
    main,
    deps = [],
    **kwargs
):
    """
    Build a FastAPI service with standard observability and security.
    """
    
    python_binary(
        name = name,
        main = main,
        deps = deps + [
            "//libs/python:fastapi_common",
            "//libs/python:auth_middleware",
            "//libs/python:observability",
        ],
        **kwargs
    )

def django_application(
    name,
    settings_module,
    deps = [],
    **kwargs
):
    """
    Build a Django application with standard configuration.
    """
    
    python_binary(
        name = name,
        main = "manage.py",
        deps = deps + [
            "//libs/python:django_common",
            "//libs/python:django_security",
        ],
        env = {
            "DJANGO_SETTINGS_MODULE": settings_module,
        },
        **kwargs
    )