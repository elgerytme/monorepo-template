# Testing Framework Examples

This directory contains comprehensive examples demonstrating the testing framework capabilities for the monorepo template. It showcases best practices for unit testing, integration testing, performance testing, and security testing using Rust-based tools.

## Overview

The testing framework provides:

- **Unit Testing**: Enhanced assertions, property-based testing, and snapshot testing
- **Integration Testing**: Testcontainers for database/service testing, HTTP client utilities
- **Performance Testing**: Benchmarking, load testing, and memory usage tracking
- **Security Testing**: Vulnerability scanning, secret detection, and compliance checking

## Project Structure

```
examples/testing/
├── src/
│   ├── lib.rs              # Main library with common types
│   ├── models.rs           # Data models and DTOs
│   ├── services.rs         # Business logic services
│   ├── handlers.rs         # HTTP request handlers
│   ├── database.rs         # Database layer and repositories
│   └── bin/
│       └── web_service.rs  # Web service binary
├── tests/
│   └── integration_tests.rs # Integration test suite
├── benches/
│   └── api_benchmarks.rs   # Performance benchmarks
├── Cargo.toml              # Dependencies and configuration
├── BUCK                    # Buck2 build configuration
└── README.md               # This file
```

## Quick Start

### Prerequisites

- Rust toolchain (1.70+)
- Buck2 build system
- Docker (for integration tests)
- PostgreSQL (for database tests)

### Running Tests

#### All Tests
```bash
# Using the test runner script
./scripts/testing/run-tests.sh --type all

# Or using Buck2 directly
buck2 test //examples/testing:...
```

#### Unit Tests Only
```bash
cargo nextest run --workspace --exclude integration-tests
```

#### Integration Tests
```bash
buck2 test //examples/testing:integration-tests
```

#### Performance Benchmarks
```bash
cargo bench --workspace
```

#### Security Tests
```bash
cargo audit
cargo clippy --all-targets --all-features -- -W clippy::security
```

## Testing Framework Features

### Unit Testing

The framework provides enhanced assertion macros and utilities:

```rust
use testing_framework::{
    assertions::enhanced::*,
    fixtures::TestUser,
    TestResult,
};

#[tokio::test]
async fn test_user_creation() -> TestResult {
    let user = TestUser::fake();
    
    // Enhanced assertions
    assert_approx_eq!(user.score, 85.0, 5.0);
    assert_matches_regex!(&user.email, r"^[^@]+@[^@]+\.[^@]+$");
    
    Ok(())
}
```

### Integration Testing

Testcontainers integration for realistic testing:

```rust
use testing_framework::integration::{TestEnvironment, database::*};

#[tokio::test]
async fn test_database_integration() -> TestResult {
    let mut env = TestEnvironment::new();
    let (host, port) = env.start_postgres("test_db").await?;
    
    let database_url = format!("postgres://postgres:postgres@{}:{}/postgres", host, port);
    let pool = setup_test_database(&database_url).await?;
    
    // Your integration test logic here
    
    Ok(())
}
```

### Performance Testing

Comprehensive benchmarking and load testing:

```rust
use testing_framework::performance::{benchmark_async, load::*};

#[tokio::test]
async fn test_api_performance() -> TestResult {
    let metrics = benchmark_async("api_call", 100, || async {
        // Your API call here
        Ok(())
    }).await?;
    
    assert!(metrics.throughput.unwrap() > 50.0); // 50 ops/sec minimum
    
    Ok(())
}
```

### Security Testing

Automated security scanning:

```rust
use testing_framework::security::{SecurityTester, SecurityConfig};

#[tokio::test]
async fn test_security_compliance() -> TestResult {
    let config = SecurityConfig::default();
    let tester = SecurityTester::new(config);
    
    let results = tester.run_all_scans(Path::new(".")).await?;
    
    // Check for critical vulnerabilities
    assert!(!tester.should_fail_build(&results));
    
    Ok(())
}
```

## Example Application

The example web service demonstrates:

- RESTful API with CRUD operations
- Database integration with PostgreSQL
- Error handling and validation
- Structured logging and tracing
- Health check endpoints

### API Endpoints

- `GET /health` - Health check
- `POST /users` - Create user
- `GET /users/:id` - Get user by ID
- `PUT /users/:id` - Update user
- `DELETE /users/:id` - Delete user
- `GET /users` - List users (paginated)
- `POST /products` - Create product
- `GET /products/:id` - Get product by ID
- `POST /orders` - Create order
- `GET /orders/:id` - Get order by ID

### Running the Web Service

```bash
# Build the service
buck2 build //examples/testing:web-service

# Run with default configuration
buck2 run //examples/testing:web-service

# Or using cargo
cargo run --bin web-service
```

The service will start on `http://localhost:3000` by default.

## Test Configuration

### Nextest Configuration

The project uses nextest for enhanced test running with configuration in `config/nextest.toml`:

- Parallel test execution
- Retry on failure
- Test grouping (unit, integration, security)
- JUnit XML output for CI
- Coverage collection support

### Environment Variables

- `RUST_LOG` - Logging level (debug, info, warn, error)
- `DATABASE_URL` - PostgreSQL connection string
- `REDIS_URL` - Redis connection string
- `RUST_BACKTRACE` - Enable backtraces (0, 1, full)

## CI/CD Integration

The testing framework integrates with GitHub Actions:

- **Unit Tests**: Fast feedback on code changes
- **Integration Tests**: Full system testing with services
- **Performance Tests**: Benchmark regression detection
- **Security Tests**: Vulnerability and compliance scanning
- **Coverage**: Code coverage reporting with Codecov

See `.github/workflows/testing.yml` for the complete CI configuration.

## Best Practices

### Test Organization

1. **Unit Tests**: Test individual functions and methods in isolation
2. **Integration Tests**: Test component interactions and external dependencies
3. **Performance Tests**: Validate performance requirements and detect regressions
4. **Security Tests**: Ensure security policies and scan for vulnerabilities

### Test Data Management

- Use the `fixtures` module for consistent test data generation
- Leverage `fake` crate for realistic random data
- Clean up test data after each test
- Use transactions for database tests when possible

### Assertion Patterns

- Use specific assertions that provide clear error messages
- Test both success and failure scenarios
- Validate edge cases and boundary conditions
- Use property-based testing for complex logic

### Performance Testing

- Set realistic performance baselines
- Test under various load conditions
- Monitor memory usage and resource consumption
- Use profiling tools to identify bottlenecks

### Security Testing

- Scan dependencies regularly for vulnerabilities
- Test input validation and sanitization
- Verify authentication and authorization
- Check for common security issues (SQL injection, XSS, etc.)

## Troubleshooting

### Common Issues

1. **Database Connection Failures**
   - Ensure PostgreSQL is running and accessible
   - Check connection string format
   - Verify database permissions

2. **Test Container Issues**
   - Ensure Docker is running
   - Check available ports
   - Verify container image availability

3. **Performance Test Variability**
   - Run tests multiple times for consistency
   - Consider system load during testing
   - Use appropriate sample sizes

4. **Security Scan False Positives**
   - Review and whitelist known safe issues
   - Update security databases regularly
   - Configure appropriate severity thresholds

### Debug Mode

Enable debug logging for detailed test output:

```bash
RUST_LOG=debug cargo nextest run
```

### Test Isolation

If tests interfere with each other:

- Use unique test data for each test
- Clean up resources in test teardown
- Consider running tests sequentially for debugging

## Contributing

When adding new tests:

1. Follow the existing test structure and naming conventions
2. Add appropriate documentation and comments
3. Ensure tests are deterministic and isolated
4. Update this README if adding new testing patterns
5. Run the full test suite before submitting changes

## Resources

- [Nextest Documentation](https://nexte.st/)
- [Testcontainers Rust](https://docs.rs/testcontainers/)
- [Criterion Benchmarking](https://docs.rs/criterion/)
- [Proptest Property Testing](https://docs.rs/proptest/)
- [Buck2 Testing Guide](https://buck2.build/docs/users/testing/)