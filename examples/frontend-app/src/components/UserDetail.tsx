import React from 'react'
import { useQuery } from '@tanstack/react-query'
import { useParams, Link } from 'react-router-dom'
import { userApi } from '../services/api'

export const UserDetail: React.FC = () => {
  const { id } = useParams<{ id: string }>()

  const {
    data: user,
    isLoading,
    error,
    refetch,
  } = useQuery({
    queryKey: ['user', id],
    queryFn: () => userApi.getUser(id!),
    enabled: !!id,
  })

  if (isLoading) {
    return <div className="loading">Loading user details...</div>
  }

  if (error) {
    return (
      <div className="error">
        <p>Error loading user: {error instanceof Error ? error.message : 'Unknown error'}</p>
        <button onClick={() => refetch()}>Retry</button>
        <Link to="/users" className="btn btn-secondary">
          Back to Users
        </Link>
      </div>
    )
  }

  if (!user) {
    return (
      <div className="not-found">
        <p>User not found</p>
        <Link to="/users" className="btn btn-secondary">
          Back to Users
        </Link>
      </div>
    )
  }

  return (
    <div className="user-detail">
      <div className="user-detail-header">
        <Link to="/users" className="btn btn-secondary">
          ← Back to Users
        </Link>
        <h2>User Details</h2>
      </div>

      <div className="user-detail-card">
        <div className="user-info">
          <div className="info-group">
            <label>ID</label>
            <span className="user-id">{user.id}</span>
          </div>

          <div className="info-group">
            <label>Name</label>
            <span className="user-name">{user.name}</span>
          </div>

          <div className="info-group">
            <label>Email</label>
            <span className="user-email">{user.email}</span>
          </div>

          <div className="info-group">
            <label>Created</label>
            <span className="user-created">
              {new Date(user.created_at).toLocaleString()}
            </span>
          </div>
        </div>

        <div className="user-actions">
          <button className="btn btn-primary" disabled>
            Edit User (Coming Soon)
          </button>
          <button className="btn btn-danger" disabled>
            Delete User (Coming Soon)
          </button>
        </div>
      </div>
    </div>
  )
}