import React from 'react'
import { Routes, Route } from 'react-router-dom'
import { UserList } from './components/UserList'
import { CreateUser } from './components/CreateUser'
import { UserDetail } from './components/UserDetail'
import { Navigation } from './components/Navigation'
import { HealthCheck } from './components/HealthCheck'
import './App.css'

function App() {
  return (
    <div className="app">
      <header className="app-header">
        <h1>Example Frontend App</h1>
        <Navigation />
        <HealthCheck />
      </header>
      
      <main className="app-main">
        <Routes>
          <Route path="/" element={<UserList />} />
          <Route path="/users" element={<UserList />} />
          <Route path="/users/create" element={<CreateUser />} />
          <Route path="/users/:id" element={<UserDetail />} />
        </Routes>
      </main>
      
      <footer className="app-footer">
        <p>Built with React + TypeScript + Rust tooling</p>
      </footer>
    </div>
  )
}

export default App