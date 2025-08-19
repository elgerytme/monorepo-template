# Buck2 build rules for Go projects with cross-language dependency support
# Integrates with Rust tooling where possible and supports cross-language dependencies

load("//config/build_rules:rust_tools.bzl", "rust_formatter", "rust_linter")

def go_library(
    name,
    srcs,
    deps = [],
    importpath = "",
    visibility = ["PUBLIC"],
    **kwargs
):
    """
    Build a Go library with enhanced tooling and cross-language support.
    
    Args:
        name: Target name
        srcs: Go source files
        deps: Dependencies (other Go targets, external modules)
        importpath: Go import path
        visibility: Target visibility
    """
    
    # Format check using gofmt (standard Go formatter)
    native.genrule(
        name = name + "_format_check",
        srcs = srcs,
        cmd = "gofmt -l $SRCS | tee $(OUT) && test ! -s $(OUT)",
        out = name + "_format.out",
    )
    
    # Lint using golangci-lint with comprehensive rules
    native.genrule(
        name = name + "_lint",
        srcs = srcs,
        cmd = "golangci-lint run --config $(location //config:.golangci.yml) $SRCS",
        out = name + "_lint.out",
    )
    
    # Security scanning using gosec
    native.genrule(
        name = name + "_security_scan",
        srcs = srcs,
        cmd = "gosec -fmt json -out $(OUT) $SRCS",
        out = name + "_security.json",
    )
    
    native.go_library(
        name = name,
        srcs = srcs,
        deps = deps + [
            name + "_format_check",
            name + "_lint",
            name + "_security_scan",
        ],
        importpath = importpath,
        visibility = visibility,
        **kwargs
    )

def go_binary(
    name,
    srcs,
    deps = [],
    visibility = ["PUBLIC"],
    **kwargs
):
    """
    Build a Go binary with standard observability and cross-language integration.
    """
    
    native.go_binary(
        name = name,
        srcs = srcs,
        deps = deps + [
            "//libs/go:common_logging",
            "//libs/go:metrics",
            "//libs/go:tracing",
        ],
        visibility = visibility,
        **kwargs
    )

def go_test(
    name,
    srcs,
    deps = [],
    **kwargs
):
    """
    Build Go tests with coverage reporting and benchmarking.
    """
    
    # Generate test coverage
    native.genrule(
        name = name + "_coverage",
        srcs = srcs,
        cmd = "go test -coverprofile=$(OUT) -covermode=atomic ./...",
        out = name + "_coverage.out",
    )
    
    native.go_test(
        name = name,
        srcs = srcs,
        deps = deps + [
            "//tools/testing:go_test_utils",
            name + "_coverage",
        ],
        **kwargs
    )

def go_grpc_service(
    name,
    srcs,
    proto_deps = [],
    deps = [],
    **kwargs
):
    """
    Build a Go gRPC service with protocol buffer integration.
    """
    
    # Generate gRPC code from proto files
    proto_targets = []
    for proto_dep in proto_deps:
        proto_target = proto_dep + "_go_proto"
        native.go_proto_library(
            name = proto_target,
            proto = proto_dep,
            importpath = "github.com/company/monorepo/proto/" + proto_dep.split(":")[-1],
        )
        proto_targets.append(":" + proto_target)
    
    go_binary(
        name = name,
        srcs = srcs,
        deps = deps + proto_targets + [
            "//libs/go:grpc_server",
            "//libs/go:grpc_middleware",
        ],
        **kwargs
    )

def go_http_service(
    name,
    srcs,
    deps = [],
    **kwargs
):
    """
    Build a Go HTTP service with standard middleware and observability.
    """
    
    go_binary(
        name = name,
        srcs = srcs,
        deps = deps + [
            "//libs/go:http_server",
            "//libs/go:http_middleware",
            "//libs/go:auth",
        ],
        **kwargs
    )

def cgo_library(
    name,
    srcs,
    c_srcs = [],
    hdrs = [],
    deps = [],
    copts = [],
    **kwargs
):
    """
    Build a CGO library that can interface with C/C++ and Rust code.
    Enables cross-language integration with Rust libraries.
    """
    
    native.cgo_library(
        name = name,
        srcs = srcs,
        c_srcs = c_srcs,
        hdrs = hdrs,
        deps = deps,
        copts = copts + [
            "-std=c11",
            "-Wall",
            "-Wextra",
        ],
        **kwargs
    )

def go_rust_bridge(
    name,
    go_srcs,
    rust_lib,
    bridge_header,
    **kwargs
):
    """
    Create a bridge between Go and Rust code using CGO and FFI.
    Enables calling Rust libraries from Go code.
    """
    
    # Build the Rust library as a C-compatible library
    native.genrule(
        name = name + "_rust_cdylib",
        srcs = [rust_lib],
        cmd = "cargo build --release --lib --crate-type cdylib",
        out = "lib" + name + ".so",
    )
    
    cgo_library(
        name = name,
        srcs = go_srcs,
        hdrs = [bridge_header],
        deps = [name + "_rust_cdylib"],
        **kwargs
    )