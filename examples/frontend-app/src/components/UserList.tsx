import React, { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import { userApi } from '../services/api'
import type { User } from '../types/user'

export const UserList: React.FC = () => {
  const [page, setPage] = useState(0)
  const limit = 10

  const {
    data: users,
    isLoading,
    error,
    refetch,
  } = useQuery({
    queryKey: ['users', page],
    queryFn: () => userApi.getUsers(limit, page * limit),
  })

  if (isLoading) {
    return <div className="loading">Loading users...</div>
  }

  if (error) {
    return (
      <div className="error">
        <p>Error loading users: {error instanceof Error ? error.message : 'Unknown error'}</p>
        <button onClick={() => refetch()}>Retry</button>
      </div>
    )
  }

  return (
    <div className="user-list">
      <div className="user-list-header">
        <h2>Users</h2>
        <Link to="/users/create" className="btn btn-primary">
          Create User
        </Link>
      </div>

      {users && users.length > 0 ? (
        <>
          <div className="user-grid">
            {users.map((user: User) => (
              <div key={user.id} className="user-card">
                <h3>{user.name}</h3>
                <p className="user-email">{user.email}</p>
                <p className="user-date">
                  Created: {new Date(user.created_at).toLocaleDateString()}
                </p>
                <Link to={`/users/${user.id}`} className="btn btn-secondary">
                  View Details
                </Link>
              </div>
            ))}
          </div>

          <div className="pagination">
            <button
              onClick={() => setPage(Math.max(0, page - 1))}
              disabled={page === 0}
              className="btn btn-secondary"
            >
              Previous
            </button>
            <span className="page-info">Page {page + 1}</span>
            <button
              onClick={() => setPage(page + 1)}
              disabled={!users || users.length < limit}
              className="btn btn-secondary"
            >
              Next
            </button>
          </div>
        </>
      ) : (
        <div className="empty-state">
          <p>No users found.</p>
          <Link to="/users/create" className="btn btn-primary">
            Create the first user
          </Link>
        </div>
      )}
    </div>
  )
}