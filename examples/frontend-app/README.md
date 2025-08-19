# Example Frontend Application

A demonstration React + TypeScript frontend application showcasing integration with Rust-based tooling and the example web service.

## Features

- React 18 with TypeScript
- React Query for data fetching and caching
- React Router for navigation
- Responsive design with CSS Grid/Flexbox
- Real-time health monitoring
- Form validation and error handling
- Pagination support

## Tech Stack

- **Framework**: React 18 + TypeScript
- **Build Tool**: Vite
- **Data Fetching**: TanStack Query (React Query)
- **Routing**: React Router
- **Testing**: Vitest + Testing Library
- **Formatting**: dprint (Rust-based)
- **Linting**: ESLint with TypeScript support

## Getting Started

```bash
# Install dependencies
npm install

# Start development server
npm run dev

# Build for production
npm run build

# Run tests
npm test

# Format code (using dprint)
npm run format

# Type check
npm run type-check
```

## Using Buck2

```bash
# Build the application
buck2 build //examples/frontend-app:frontend-app

# Run tests
buck2 test //examples/frontend-app:frontend-app-test
```

## Environment Variables

Create a `.env` file in the project root:

```env
VITE_API_URL=http://localhost:3000
```

## Project Structure

```
src/
├── components/          # React components
│   ├── UserList.tsx    # User listing with pagination
│   ├── CreateUser.tsx  # User creation form
│   ├── UserDetail.tsx  # User detail view
│   ├── Navigation.tsx  # Navigation component
│   └── HealthCheck.tsx # API health monitoring
├── services/           # API services
│   └── api.ts         # Axios-based API client
├── types/             # TypeScript type definitions
│   └── user.ts        # User-related types
├── App.tsx            # Main application component
├── App.css            # Application styles
├── main.tsx           # Application entry point
└── index.css          # Global styles
```

## Features Demonstrated

### Rust Tooling Integration
- **dprint**: Multi-language formatting (replaces Prettier)
- **Buck2**: Build system integration
- **Type Safety**: Full TypeScript coverage

### Modern React Patterns
- **Hooks**: useState, useQuery, useMutation
- **Error Boundaries**: Graceful error handling
- **Suspense**: Loading states
- **Performance**: Query caching and optimization

### API Integration
- **RESTful API**: Full CRUD operations
- **Error Handling**: Network and validation errors
- **Loading States**: User feedback during operations
- **Health Monitoring**: Real-time API status

## Development Workflow

1. **Code Formatting**: Automatic formatting with dprint
2. **Type Checking**: Continuous TypeScript validation
3. **Testing**: Unit and integration tests with Vitest
4. **Linting**: ESLint with TypeScript rules
5. **Build**: Optimized production builds with Vite

## Integration with Backend

This frontend is designed to work with the example Rust web service:

- **User Management**: Create, read, list users
- **Health Monitoring**: Real-time API status
- **Error Handling**: Graceful degradation when API is unavailable
- **Metrics**: Client-side performance tracking