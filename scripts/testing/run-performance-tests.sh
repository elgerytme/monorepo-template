#!/bin/bash
# Performance testing script with Rust-based benchmarking tools

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
BENCHMARK_DIR="target/criterion"
FLAMEGRAPH_DIR="target/flamegraph"
REPORTS_DIR="target/performance-reports"

echo -e "${GREEN}🚀 Running performance tests and benchmarks${NC}"

# Create output directories
mkdir -p "$BENCHMARK_DIR" "$FLAMEGRAPH_DIR" "$REPORTS_DIR"

# Function to install required tools
install_tools() {
    echo -e "${YELLOW}Installing performance testing tools...${NC}"
    
    # Install criterion for benchmarking
    if ! cargo list | grep -q criterion; then
        cargo install cargo-criterion
    fi
    
    # Install flamegraph for profiling
    if ! command -v flamegraph &> /dev/null; then
        cargo install flamegraph
    fi
    
    # Install hyperfine for command benchmarking
    if ! command -v hyperfine &> /dev/null; then
        echo -e "${YELLOW}Installing hyperfine...${NC}"
        if command -v brew &> /dev/null; then
            brew install hyperfine
        elif command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y hyperfine
        else
            cargo install hyperfine
        fi
    fi
}

# Function to run Criterion benchmarks
run_criterion_benchmarks() {
    echo -e "${GREEN}Running Criterion benchmarks...${NC}"
    
    # Run all benchmarks
    cargo criterion --output-format html
    
    # Generate comparison reports if previous results exist
    if [ -d "$BENCHMARK_DIR" ]; then
        echo -e "${GREEN}Generating benchmark comparison reports...${NC}"
        cargo criterion --output-format html --save-baseline current
    fi
    
    echo -e "${GREEN}Benchmark results available at: $BENCHMARK_DIR/report/index.html${NC}"
}

# Function to run flamegraph profiling
run_flamegraph_profiling() {
    echo -e "${GREEN}Running flamegraph profiling...${NC}"
    
    # Profile specific benchmarks
    CARGO_PROFILE_RELEASE_DEBUG=true cargo flamegraph \
        --bin web-service \
        --output "$FLAMEGRAPH_DIR/web-service.svg" \
        -- --bench
    
    echo -e "${GREEN}Flamegraph generated at: $FLAMEGRAPH_DIR/web-service.svg${NC}"
}

# Function to run load tests
run_load_tests() {
    echo -e "${GREEN}Running load tests...${NC}"
    
    # Start test services if needed
    if [ -f "docker-compose.test.yml" ]; then
        docker-compose -f docker-compose.test.yml up -d
        sleep 10  # Wait for services to start
    fi
    
    # Run load tests using our testing framework
    cargo test --release --test load_tests -- --nocapture
    
    # Cleanup test services
    if [ -f "docker-compose.test.yml" ]; then
        docker-compose -f docker-compose.test.yml down
    fi
}

# Function to run command-line benchmarks
run_command_benchmarks() {
    echo -e "${GREEN}Running command-line benchmarks with hyperfine...${NC}"
    
    # Benchmark build times
    hyperfine \
        --warmup 3 \
        --export-json "$REPORTS_DIR/build-benchmark.json" \
        'cargo build --release'
    
    # Benchmark test execution
    hyperfine \
        --warmup 2 \
        --export-json "$REPORTS_DIR/test-benchmark.json" \
        'cargo test --release'
    
    # Benchmark specific tools
    if [ -f "justfile" ]; then
        hyperfine \
            --warmup 1 \
            --export-json "$REPORTS_DIR/just-benchmark.json" \
            'just check' \
            'just test' \
            'just lint'
    fi
}

# Function to generate performance report
generate_performance_report() {
    echo -e "${GREEN}Generating performance report...${NC}"
    
    cat > "$REPORTS_DIR/performance-summary.md" << EOF
# Performance Test Results

Generated on: $(date)

## Benchmark Results

### Criterion Benchmarks
- HTML Report: [Criterion Report](../criterion/report/index.html)
- Baseline: current

### Flamegraph Profiling
- Web Service: [Flamegraph](../flamegraph/web-service.svg)

### Command Benchmarks
- Build Time: $(jq -r '.results[0].mean' "$REPORTS_DIR/build-benchmark.json" 2>/dev/null || echo "N/A") seconds
- Test Time: $(jq -r '.results[0].mean' "$REPORTS_DIR/test-benchmark.json" 2>/dev/null || echo "N/A") seconds

### Load Test Results
See individual test outputs above.

## Performance Metrics

### Memory Usage
- Peak memory usage during tests: $(ps aux | grep cargo | awk '{sum+=$6} END {print sum/1024 " MB"}' || echo "N/A")

### CPU Usage
- Average CPU usage during benchmarks: Measured by system tools

## Recommendations

1. Monitor benchmark trends over time
2. Set performance regression alerts
3. Profile critical paths regularly
4. Optimize based on flamegraph analysis

EOF

    echo -e "${GREEN}Performance report generated at: $REPORTS_DIR/performance-summary.md${NC}"
}

# Parse command line arguments
INSTALL_TOOLS=false
RUN_BENCHMARKS=true
RUN_PROFILING=false
RUN_LOAD_TESTS=false
RUN_COMMAND_BENCHMARKS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --install-tools)
            INSTALL_TOOLS=true
            shift
            ;;
        --no-benchmarks)
            RUN_BENCHMARKS=false
            shift
            ;;
        --profiling)
            RUN_PROFILING=true
            shift
            ;;
        --load-tests)
            RUN_LOAD_TESTS=true
            shift
            ;;
        --command-benchmarks)
            RUN_COMMAND_BENCHMARKS=true
            shift
            ;;
        --all)
            RUN_PROFILING=true
            RUN_LOAD_TESTS=true
            RUN_COMMAND_BENCHMARKS=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --install-tools        Install required performance testing tools"
            echo "  --no-benchmarks       Skip Criterion benchmarks"
            echo "  --profiling           Run flamegraph profiling"
            echo "  --load-tests          Run load tests"
            echo "  --command-benchmarks  Run command-line benchmarks"
            echo "  --all                 Run all performance tests"
            echo "  -h, --help            Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Install tools if requested
if [ "$INSTALL_TOOLS" = true ]; then
    install_tools
fi

# Run performance tests
if [ "$RUN_BENCHMARKS" = true ]; then
    run_criterion_benchmarks
fi

if [ "$RUN_PROFILING" = true ]; then
    run_flamegraph_profiling
fi

if [ "$RUN_LOAD_TESTS" = true ]; then
    run_load_tests
fi

if [ "$RUN_COMMAND_BENCHMARKS" = true ]; then
    run_command_benchmarks
fi

# Generate final report
generate_performance_report

echo -e "${GREEN}✅ Performance testing completed successfully${NC}"
echo -e "${GREEN}📊 View results at: $REPORTS_DIR/performance-summary.md${NC}"