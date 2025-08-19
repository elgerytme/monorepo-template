# API Documentation

This directory contains automatically generated API documentation for all services and libraries in the monorepo.

## Documentation Generation

API documentation is automatically generated from code comments and maintained through our CI/CD pipeline.

### Rust APIs

Rust API documentation is generated using `cargo doc` with enhanced configuration:

```bash
# Generate documentation for all Rust crates
cargo doc --workspace --no-deps --document-private-items

# Generate with examples and tests
cargo doc --workspace --no-deps --document-private-items --examples

# Open documentation in browser
cargo doc --workspace --no-deps --open
```

### TypeScript APIs

TypeScript API documentation is generated using `typedoc`:

```bash
# Generate TypeScript documentation
npx typedoc --out docs/api/typescript src/

# Generate with custom theme
npx typedoc --out docs/api/typescript --theme minimal src/
```

### OpenAPI Specifications

REST API documentation follows OpenAPI 3.0 specification:

```yaml
# Example OpenAPI spec structure
openapi: 3.0.0
info:
  title: Service API
  version: 1.0.0
  description: Service API documentation
paths:
  /api/v1/users:
    get:
      summary: List users
      responses:
        '200':
          description: Successful response
```

## Documentation Structure

```
docs/api/
├── rust/                    # Rust crate documentation
│   ├── observability/       # libs/observability docs
│   ├── shared-library/      # libs/shared-library docs
│   └── web-service/         # apps/web-service docs
├── typescript/              # TypeScript API docs
│   └── frontend-app/        # apps/frontend-app docs
├── openapi/                 # OpenAPI specifications
│   ├── web-service.yaml     # Web service API spec
│   └── api-gateway.yaml     # API gateway spec
└── generated/               # Auto-generated docs
    ├── index.html           # Main documentation index
    └── search-index.json    # Search index
```

## Automated Generation

Documentation is automatically generated and updated through:

### GitHub Actions Workflow

```yaml
# .github/workflows/docs.yml
name: Generate Documentation

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  generate-docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Rust
        uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
          
      - name: Generate Rust docs
        run: |
          cargo doc --workspace --no-deps --document-private-items
          
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          
      - name: Generate TypeScript docs
        run: |
          npm install -g typedoc
          npx typedoc --out docs/api/typescript apps/frontend-app/src/
          
      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v3
        if: github.ref == 'refs/heads/main'
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./target/doc
```

### Buck2 Integration

Documentation generation is integrated into the build system:

```python
# Documentation build rules
def rust_doc(
    name,
    crate,
    deps = [],
    **kwargs
):
    """Generate Rust documentation."""
    native.genrule(
        name = name,
        srcs = [crate + ":lib"],
        cmd = "cargo doc --no-deps --document-private-items --target-dir $OUT",
        out = "doc",
        deps = deps,
        **kwargs
    )

def api_docs(
    name,
    services = [],
    **kwargs
):
    """Generate comprehensive API documentation."""
    
    # Generate Rust docs
    rust_docs = []
    for service in services:
        rust_doc(
            name = service + "_docs",
            crate = service,
        )
        rust_docs.append(":" + service + "_docs")
    
    # Combine all documentation
    native.genrule(
        name = name,
        srcs = rust_docs,
        cmd = "python3 scripts/docs/combine-docs.py $(SRCS) --output $OUT",
        out = "api-docs",
        **kwargs
    )
```

## Documentation Standards

### Code Comments

#### Rust Documentation

```rust
/// Represents a user in the system.
/// 
/// Users have unique identifiers and can be associated with multiple
/// organizations. This struct provides methods for user management
/// and validation.
/// 
/// # Examples
/// 
/// ```rust
/// use shared_library::User;
/// 
/// let user = User::new("john_doe", "john@example.com");
/// assert!(user.validate().is_ok());
/// ```
/// 
/// # Errors
/// 
/// Returns `ValidationError` if the email format is invalid.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct User {
    /// Unique identifier for the user
    pub id: String,
    /// User's email address (must be valid format)
    pub email: String,
    /// Optional display name
    pub display_name: Option<String>,
}

impl User {
    /// Creates a new user with the given ID and email.
    /// 
    /// # Arguments
    /// 
    /// * `id` - Unique identifier for the user
    /// * `email` - Valid email address
    /// 
    /// # Examples
    /// 
    /// ```rust
    /// let user = User::new("user123", "user@example.com");
    /// ```
    pub fn new(id: impl Into<String>, email: impl Into<String>) -> Self {
        Self {
            id: id.into(),
            email: email.into(),
            display_name: None,
        }
    }
}
```

#### TypeScript Documentation

```typescript
/**
 * Represents a user in the system.
 * 
 * Users have unique identifiers and can be associated with multiple
 * organizations. This interface provides the structure for user data.
 * 
 * @example
 * ```typescript
 * const user: User = {
 *   id: "user123",
 *   email: "user@example.com",
 *   displayName: "John Doe"
 * };
 * ```
 */
export interface User {
  /** Unique identifier for the user */
  id: string;
  
  /** User's email address (must be valid format) */
  email: string;
  
  /** Optional display name */
  displayName?: string;
}

/**
 * Creates a new user with validation.
 * 
 * @param userData - The user data to create
 * @returns Promise resolving to the created user
 * @throws {ValidationError} When email format is invalid
 * 
 * @example
 * ```typescript
 * const user = await createUser({
 *   id: "user123",
 *   email: "user@example.com"
 * });
 * ```
 */
export async function createUser(userData: Partial<User>): Promise<User> {
  // Implementation
}
```

### OpenAPI Documentation

```yaml
# Complete OpenAPI specification example
openapi: 3.0.0
info:
  title: User Management API
  version: 1.0.0
  description: |
    API for managing users in the system.
    
    This API provides endpoints for creating, reading, updating,
    and deleting users, with comprehensive validation and error handling.
  contact:
    name: API Support
    email: api-support@company.com
  license:
    name: MIT
    url: https://opensource.org/licenses/MIT

servers:
  - url: https://api.company.com/v1
    description: Production server
  - url: https://staging-api.company.com/v1
    description: Staging server

paths:
  /users:
    get:
      summary: List users
      description: |
        Retrieve a paginated list of users.
        
        Supports filtering by email domain and sorting by creation date.
      parameters:
        - name: page
          in: query
          description: Page number (1-based)
          schema:
            type: integer
            minimum: 1
            default: 1
        - name: limit
          in: query
          description: Number of users per page
          schema:
            type: integer
            minimum: 1
            maximum: 100
            default: 20
      responses:
        '200':
          description: Successful response
          content:
            application/json:
              schema:
                type: object
                properties:
                  users:
                    type: array
                    items:
                      $ref: '#/components/schemas/User'
                  pagination:
                    $ref: '#/components/schemas/Pagination'
        '400':
          $ref: '#/components/responses/BadRequest'
        '500':
          $ref: '#/components/responses/InternalError'

components:
  schemas:
    User:
      type: object
      required:
        - id
        - email
      properties:
        id:
          type: string
          description: Unique identifier for the user
          example: "user123"
        email:
          type: string
          format: email
          description: User's email address
          example: "user@example.com"
        displayName:
          type: string
          description: Optional display name
          example: "John Doe"
        createdAt:
          type: string
          format: date-time
          description: When the user was created
          example: "2024-01-15T10:30:00Z"
```

## Documentation Maintenance

### Automated Checks

Documentation quality is enforced through automated checks:

```bash
# Check for missing documentation
cargo doc --workspace --no-deps 2>&1 | grep -i "missing"

# Validate OpenAPI specs
swagger-codegen validate -i docs/api/openapi/web-service.yaml

# Check documentation links
markdown-link-check docs/**/*.md

# Spell check documentation
typos docs/
```

### Documentation Linting

```yaml
# .github/workflows/docs-lint.yml
name: Documentation Linting

on: [push, pull_request]

jobs:
  lint-docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Lint Markdown
        uses: DavidAnson/markdownlint-cli2-action@v9
        with:
          globs: 'docs/**/*.md'
          
      - name: Check spelling
        uses: crate-ci/typos@master
        with:
          files: docs/
          
      - name: Validate OpenAPI
        run: |
          npm install -g swagger-cli
          swagger-cli validate docs/api/openapi/*.yaml
```

### Update Process

1. **Code Changes**: Documentation updates automatically when code changes
2. **Manual Updates**: Use pull requests for manual documentation changes
3. **Review Process**: All documentation changes require review
4. **Deployment**: Approved changes are automatically deployed

## Search and Navigation

### Search Functionality

Documentation includes full-text search powered by a search index:

```javascript
// Search index generation
const searchIndex = {
  documents: [
    {
      id: "user-struct",
      title: "User Struct",
      content: "Represents a user in the system...",
      url: "/rust/shared_library/struct.User.html"
    }
  ],
  index: {
    // Lunr.js search index
  }
};
```

### Navigation Structure

```html
<!-- Documentation navigation -->
<nav class="docs-nav">
  <ul>
    <li><a href="#rust-apis">Rust APIs</a>
      <ul>
        <li><a href="#observability">Observability</a></li>
        <li><a href="#shared-library">Shared Library</a></li>
      </ul>
    </li>
    <li><a href="#typescript-apis">TypeScript APIs</a></li>
    <li><a href="#rest-apis">REST APIs</a></li>
  </ul>
</nav>
```

## Deployment

Documentation is deployed to multiple locations:

### GitHub Pages
- **URL**: https://company.github.io/monorepo/
- **Update**: Automatic on main branch changes
- **Content**: Complete API documentation

### Internal Documentation Site
- **URL**: https://docs.company.com/api/
- **Update**: Automatic deployment pipeline
- **Content**: Internal APIs and guides

### Developer Portal
- **URL**: https://developers.company.com/
- **Update**: Manual deployment for public APIs
- **Content**: Public API documentation only

## References

- [Rust Documentation Guidelines](https://doc.rust-lang.org/rustdoc/how-to-write-documentation.html)
- [TypeScript Documentation](https://typedoc.org/)
- [OpenAPI Specification](https://swagger.io/specification/)
- [Documentation Best Practices](https://documentation.divio.com/)