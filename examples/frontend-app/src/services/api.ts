import axios from 'axios'
import type { User, CreateUserRequest, HealthStatus } from '../types/user'

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:3000'

const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
})

// Request interceptor for logging
api.interceptors.request.use(
  (config) => {
    console.log(`API Request: ${config.method?.toUpperCase()} ${config.url}`)
    return config
  },
  (error) => {
    console.error('API Request Error:', error)
    return Promise.reject(error)
  }
)

// Response interceptor for logging and error handling
api.interceptors.response.use(
  (response) => {
    console.log(`API Response: ${response.status} ${response.config.url}`)
    return response
  },
  (error) => {
    console.error('API Response Error:', error.response?.status, error.message)
    return Promise.reject(error)
  }
)

export const userApi = {
  // Get all users with optional pagination
  getUsers: async (limit?: number, offset?: number): Promise<User[]> => {
    const params = new URLSearchParams()
    if (limit) params.append('limit', limit.toString())
    if (offset) params.append('offset', offset.toString())
    
    const response = await api.get<User[]>(`/users?${params}`)
    return response.data
  },

  // Get user by ID
  getUser: async (id: string): Promise<User> => {
    const response = await api.get<User>(`/users/${id}`)
    return response.data
  },

  // Create new user
  createUser: async (userData: CreateUserRequest): Promise<User> => {
    const response = await api.post<User>('/users', userData)
    return response.data
  },

  // Health check
  getHealth: async (): Promise<HealthStatus> => {
    const response = await api.get<HealthStatus>('/health')
    return response.data
  },
}

export default api