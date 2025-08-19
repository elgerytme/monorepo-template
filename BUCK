load("@prelude//platforms:defs.bzl", "execution_platform")

# Default execution platform with automatic detection
execution_platform(
    name = "default",
    cpu_configuration = select({
        "config//os:linux": "config//cpu:x86_64",
        "config//os:macos": "config//cpu:arm64", 
        "config//os:windows": "config//cpu:x86_64",
    }),
    os_configuration = select({
        "config//os:linux": "config//os:linux",
        "config//os:macos": "config//os:macos",
        "config//os:windows": "config//os:windows", 
    }),
)

# Alias for the default platform
alias(
    name = "platform",
    actual = ":default",
)