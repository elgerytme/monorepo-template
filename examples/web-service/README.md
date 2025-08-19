# Example Web Service

A demonstration Rust web service showcasing full observability integration with metrics, logging, and tracing.

## Features

- RESTful API for user management
- Comprehensive observability with Prometheus metrics
- Structured JSON logging with tracing
- Health check endpoint
- Input validation and error handling
- CORS support

## API Endpoints

- `GET /health` - Health check
- `GET /metrics` - Prometheus metrics
- `GET /users` - List users (with pagination)
- `POST /users` - Create a new user
- `GET /users/:id` - Get user by ID

## Running the Service

```bash
# Using Buck2
buck2 run //examples/web-service:web-service

# Using Cargo directly
cd examples/web-service
cargo run
```

The service will start on `http://localhost:3000`.

## Example Usage

```bash
# Health check
curl http://localhost:3000/health

# Create a user
curl -X POST http://localhost:3000/users \
  -H "Content-Type: application/json" \
  -d '{"name": "John Doe", "email": "john@example.com"}'

# List users
curl http://localhost:3000/users

# Get specific user
curl http://localhost:3000/users/{user-id}

# View metrics
curl http://localhost:3000/metrics
```

## Observability

The service includes comprehensive observability:

- **Metrics**: Request counts, durations, error rates
- **Logging**: Structured JSON logs with correlation IDs
- **Tracing**: Distributed tracing support with OpenTelemetry
- **Health Checks**: Service health and readiness endpoints

## Configuration

Set the `RUST_LOG` environment variable to control logging levels:

```bash
RUST_LOG=debug cargo run
```