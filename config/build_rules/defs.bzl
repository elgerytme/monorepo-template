# Main build rules definitions for the monorepo
# Exports all language-specific build rules and cross-language integration

# Rust build rules
load("//config/build_rules:rust.bzl", 
     "rust_binary", "rust_library", "rust_test", "rust_benchmark")

# TypeScript/JavaScript build rules  
load("//config/build_rules:typescript.bzl",
     "typescript_library", "typescript_binary", "typescript_test", 
     "react_application", "node_service")

# Python build rules
load("//config/build_rules:python.bzl",
     "python_library", "python_binary", "python_test", "python_wheel",
     "fastapi_service", "django_application")

# Go build rules
load("//config/build_rules:go.bzl",
     "go_library", "go_binary", "go_test", "go_grpc_service", 
     "go_http_service", "cgo_library", "go_rust_bridge")

# Rust tooling integration
load("//config/build_rules:rust_tools.bzl",
     "rust_formatter", "rust_linter", "rust_security_scanner",
     "rust_benchmark", "rust_code_stats", "rust_spell_check",
     "cross_language_deps")

# Re-export all rules for easy importing
__all__ = [
    # Rust rules
    "rust_binary",
    "rust_library", 
    "rust_test",
    "rust_benchmark",
    
    # TypeScript rules
    "typescript_library",
    "typescript_binary",
    "typescript_test",
    "react_application",
    "node_service",
    
    # Python rules
    "python_library",
    "python_binary",
    "python_test", 
    "python_wheel",
    "fastapi_service",
    "django_application",
    
    # Go rules
    "go_library",
    "go_binary",
    "go_test",
    "go_grpc_service",
    "go_http_service",
    "cgo_library",
    "go_rust_bridge",
    
    # Rust tooling
    "rust_formatter",
    "rust_linter",
    "rust_security_scanner",
    "rust_code_stats",
    "rust_spell_check",
    "cross_language_deps",
]

def monorepo_service(
    name,
    language,
    srcs,
    deps = [],
    **kwargs
):
    """
    Universal service builder that chooses the appropriate language-specific rule.
    
    Args:
        name: Service name
        language: Programming language (rust, typescript, python, go)
        srcs: Source files
        deps: Dependencies
    """
    
    if language == "rust":
        rust_binary(
            name = name,
            srcs = srcs,
            deps = deps + ["//libs/rust:service_common"],
            **kwargs
        )
    elif language == "typescript":
        node_service(
            name = name,
            entry_point = srcs[0],  # Assume first src is entry point
            deps = deps,
            **kwargs
        )
    elif language == "python":
        fastapi_service(
            name = name,
            main = srcs[0],  # Assume first src is main
            deps = deps,
            **kwargs
        )
    elif language == "go":
        go_http_service(
            name = name,
            srcs = srcs,
            deps = deps,
            **kwargs
        )
    else:
        fail("Unsupported language: " + language)

def monorepo_library(
    name,
    language,
    srcs,
    deps = [],
    **kwargs
):
    """
    Universal library builder that chooses the appropriate language-specific rule.
    """
    
    if language == "rust":
        rust_library(
            name = name,
            srcs = srcs,
            deps = deps,
            **kwargs
        )
    elif language == "typescript":
        typescript_library(
            name = name,
            srcs = srcs,
            deps = deps,
            **kwargs
        )
    elif language == "python":
        python_library(
            name = name,
            srcs = srcs,
            deps = deps,
            **kwargs
        )
    elif language == "go":
        go_library(
            name = name,
            srcs = srcs,
            deps = deps,
            **kwargs
        )
    else:
        fail("Unsupported language: " + language)