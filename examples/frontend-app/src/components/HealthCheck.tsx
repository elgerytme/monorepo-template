import React from 'react'
import { useQuery } from '@tanstack/react-query'
import { userApi } from '../services/api'

export const HealthCheck: React.FC = () => {
  const { data: health, isError } = useQuery({
    queryKey: ['health'],
    queryFn: userApi.getHealth,
    refetchInterval: 30000, // Check every 30 seconds
    retry: 1,
  })

  const statusClass = isError ? 'status-error' : 'status-healthy'

  return (
    <div className={`health-check ${statusClass}`}>
      <span className="status-indicator">●</span>
      <span className="status-text">
        {isError ? 'API Offline' : health?.status || 'Checking...'}
      </span>
      {health && (
        <span className="service-info">
          {health.service} v{health.version}
        </span>
      )}
    </div>
  )
}