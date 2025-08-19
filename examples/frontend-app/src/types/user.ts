export interface User {
  id: string
  name: string
  email: string
  created_at: string
}

export interface CreateUserRequest {
  name: string
  email: string
}

export interface HealthStatus {
  status: string
  timestamp: string
  service: string
  version: string
}