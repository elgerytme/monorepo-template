# Example Shared Library

A demonstration Rust library with cross-language bindings, showcasing how to create a shared library that can be used from multiple programming languages.

## Features

- Core Rust library with user management functionality
- C-compatible FFI interface
- Python bindings using pybind11
- Node.js bindings using N-API
- Comprehensive validation and error handling
- JSON serialization support
- Thread-safe operations

## Architecture

The library is structured in layers:

1. **Core Rust Library** (`src/lib.rs`, `src/user.rs`, `src/validation.rs`)
   - Pure Rust implementation with type safety
   - Comprehensive error handling
   - JSON serialization support

2. **C FFI Layer** (`src/lib.rs` - C exports)
   - C-compatible interface for cross-language interop
   - Memory management utilities
   - Error code mapping

3. **Language Bindings**
   - **Python**: Using pybind11 for seamless integration
   - **Node.js**: Using N-API for native performance

## Building

### Rust Library

```bash
# Build the library
cargo build --release

# Run tests
cargo test

# Generate C headers
cargo build  # Headers generated in target/include/
```

### Using Buck2

```bash
# Build the library
buck2 build //examples/shared-library:shared-library

# Run tests
buck2 test //examples/shared-library:shared-library-test
```

### Python Bindings

```bash
cd bindings/python
pip install -e .
```

### Node.js Bindings

```bash
cd bindings/node
npm install
npm run build
```

## Usage Examples

### Rust

```rust
use example_shared_library::{UserManager, User};

let mut manager = UserManager::new();
let user = manager.create_user("John Doe", "john@example.com")?;
println!("Created user: {}", user.name);
```

### C

```c
#include "example_shared_library.h"

int main() {
    library_init();
    
    CUser user;
    ErrorCode result = create_user("John Doe", "john@example.com", &user);
    
    if (result == Success) {
        printf("Created user: %s\n", user.name);
        free_user(&user);
    }
    
    library_cleanup();
    return 0;
}
```

### Python

```python
import example_shared_py

manager = example_shared_py.UserManager()
user = manager.create_user("John Doe", "john@example.com")
print(f"Created user: {user.name}")
```

### Node.js

```javascript
const { UserManager } = require('example-shared-library-node');

const manager = new UserManager();
const user = manager.createUser("John Doe", "john@example.com");
console.log(`Created user: ${user.name}`);
```

## API Reference

### Core Types

- **User**: Represents a user with ID, name, email, and creation timestamp
- **UserManager**: Manages user creation, retrieval, and validation
- **Validator**: Handles input validation for names and emails

### Operations

- `create_user(name, email)`: Create a new user with validation
- `get_user(id)`: Retrieve a user by ID
- `get_user_by_email(email)`: Find a user by email address
- `list_users()`: Get all users sorted by creation date
- `update_user(id, name?, email?)`: Update user information
- `delete_user(id)`: Remove a user
- `user_count()`: Get total number of users

### Error Handling

The library provides comprehensive error handling:

- **ValidationError**: Input validation failures
- **NotFound**: Resource not found
- **AlreadyExists**: Duplicate resource creation
- **JsonError**: Serialization/deserialization errors
- **InternalError**: Internal library errors

## Cross-Language Features

### Memory Management
- Automatic memory management in Rust
- Safe C FFI with explicit cleanup functions
- RAII patterns in C++ bindings
- Garbage collection integration in Python/Node.js

### Type Safety
- Strong typing in Rust core
- Type-safe bindings for all target languages
- Validation at language boundaries
- Consistent error handling across languages

### Performance
- Zero-copy operations where possible
- Minimal overhead for FFI calls
- Efficient serialization with serde
- Native performance in all target languages

## Testing

Each language binding includes comprehensive tests:

```bash
# Rust tests
cargo test

# Python tests
cd bindings/python && python -m pytest

# Node.js tests
cd bindings/node && npm test
```

## Integration Examples

This shared library demonstrates several important patterns:

1. **Cross-Language Data Sharing**: Consistent user data model across languages
2. **Error Propagation**: Proper error handling from Rust to target languages
3. **Memory Safety**: Safe memory management across language boundaries
4. **Performance**: Native performance with minimal FFI overhead
5. **Type Safety**: Strong typing maintained across all interfaces