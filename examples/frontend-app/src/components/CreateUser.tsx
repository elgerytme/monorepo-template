import React, { useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useNavigate } from 'react-router-dom'
import { userApi } from '../services/api'
import type { CreateUserRequest } from '../types/user'

export const CreateUser: React.FC = () => {
  const [formData, setFormData] = useState<CreateUserRequest>({
    name: '',
    email: '',
  })
  const [errors, setErrors] = useState<Partial<CreateUserRequest>>({})

  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const createUserMutation = useMutation({
    mutationFn: userApi.createUser,
    onSuccess: (newUser) => {
      // Invalidate and refetch users list
      queryClient.invalidateQueries({ queryKey: ['users'] })
      // Navigate to the new user's detail page
      navigate(`/users/${newUser.id}`)
    },
    onError: (error) => {
      console.error('Failed to create user:', error)
    },
  })

  const validateForm = (): boolean => {
    const newErrors: Partial<CreateUserRequest> = {}

    if (!formData.name.trim()) {
      newErrors.name = 'Name is required'
    }

    if (!formData.email.trim()) {
      newErrors.email = 'Email is required'
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.email)) {
      newErrors.email = 'Please enter a valid email address'
    }

    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()

    if (!validateForm()) {
      return
    }

    createUserMutation.mutate(formData)
  }

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target
    setFormData(prev => ({ ...prev, [name]: value }))
    
    // Clear error when user starts typing
    if (errors[name as keyof CreateUserRequest]) {
      setErrors(prev => ({ ...prev, [name]: undefined }))
    }
  }

  return (
    <div className="create-user">
      <h2>Create New User</h2>

      <form onSubmit={handleSubmit} className="user-form">
        <div className="form-group">
          <label htmlFor="name">Name</label>
          <input
            type="text"
            id="name"
            name="name"
            value={formData.name}
            onChange={handleInputChange}
            className={errors.name ? 'error' : ''}
            placeholder="Enter user's name"
          />
          {errors.name && <span className="error-message">{errors.name}</span>}
        </div>

        <div className="form-group">
          <label htmlFor="email">Email</label>
          <input
            type="email"
            id="email"
            name="email"
            value={formData.email}
            onChange={handleInputChange}
            className={errors.email ? 'error' : ''}
            placeholder="Enter user's email"
          />
          {errors.email && <span className="error-message">{errors.email}</span>}
        </div>

        {createUserMutation.error && (
          <div className="error-message">
            Failed to create user. Please try again.
          </div>
        )}

        <div className="form-actions">
          <button
            type="button"
            onClick={() => navigate('/users')}
            className="btn btn-secondary"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={createUserMutation.isPending}
            className="btn btn-primary"
          >
            {createUserMutation.isPending ? 'Creating...' : 'Create User'}
          </button>
        </div>
      </form>
    </div>
  )
}