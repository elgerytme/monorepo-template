# Monorepo Development Container
FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV RUST_VERSION=1.75.0
ENV NODE_VERSION=20
ENV GO_VERSION=1.21.5
ENV PYTHON_VERSION=3.11

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    wget \
    git \
    pkg-config \
    libssl-dev \
    libffi-dev \
    libsqlite3-dev \
    zstd \
    unzip \
    jq \
    tree \
    htop \
    vim \
    nano \
    && rm -rf /var/lib/apt/lists/*

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain ${RUST_VERSION}
ENV PATH="/root/.cargo/bin:${PATH}"

# Install Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y nodejs

# Install Python
RUN apt-get update && apt-get install -y \
    python${PYTHON_VERSION} \
    python${PYTHON_VERSION}-dev \
    python${PYTHON_VERSION}-venv \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install Go
RUN wget https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz \
    && tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz \
    && rm go${GO_VERSION}.linux-amd64.tar.gz
ENV PATH="/usr/local/go/bin:${PATH}"

# Install Buck2
RUN BUCK2_VERSION=$(curl -s https://api.github.com/repos/facebook/buck2/releases/latest | jq -r .tag_name) \
    && curl -L -o buck2.zst "https://github.com/facebook/buck2/releases/download/${BUCK2_VERSION}/buck2-x86_64-unknown-linux-gnu.zst" \
    && zstd -d buck2.zst \
    && chmod +x buck2 \
    && mv buck2 /usr/local/bin/

# Install Rust-based development tools
RUN cargo install \
    ripgrep \
    fd-find \
    bat \
    exa \
    tokei \
    hyperfine \
    watchexec-cli \
    typos-cli \
    dprint \
    just \
    cargo-nextest \
    cargo-audit \
    cargo-deny

# Install additional development tools
RUN npm install -g \
    typescript \
    @typescript-eslint/parser \
    @typescript-eslint/eslint-plugin \
    prettier \
    eslint

# Install Python development tools
RUN pip3 install \
    black \
    flake8 \
    mypy \
    pytest \
    poetry

# Create cache directories
RUN mkdir -p /home/vscode/.cache /home/vscode/.cargo \
    && chown -R vscode:vscode /home/vscode/.cache /home/vscode/.cargo

# Switch to vscode user
USER vscode

# Set up shell aliases and environment
RUN echo 'alias ll="exa -la"' >> ~/.bashrc \
    && echo 'alias cat="bat"' >> ~/.bashrc \
    && echo 'alias find="fd"' >> ~/.bashrc \
    && echo 'alias grep="rg"' >> ~/.bashrc \
    && echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc

# Set working directory
WORKDIR /workspace

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD buck2 --version && rustc --version && node --version || exit 1