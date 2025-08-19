import React from 'react'
import { Link, useLocation } from 'react-router-dom'

export const Navigation: React.FC = () => {
  const location = useLocation()

  const isActive = (path: string) => {
    return location.pathname === path || location.pathname.startsWith(path)
  }

  return (
    <nav className="navigation">
      <Link
        to="/users"
        className={`nav-link ${isActive('/users') ? 'active' : ''}`}
      >
        Users
      </Link>
      <Link
        to="/users/create"
        className={`nav-link ${isActive('/users/create') ? 'active' : ''}`}
      >
        Create User
      </Link>
    </nav>
  )
}