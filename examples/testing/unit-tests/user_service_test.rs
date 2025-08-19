//! Example unit tests for a user service

use testing_framework::*;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use uuid::Uuid;

// Mock user service for demonstration
#[derive(Debug, Clone)]
pub struct UserService {
    users: HashMap<Uuid, User>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct User {
    pub id: Uuid,
    pub email: String,
    pub name: String,
    pub active: bool,
}

#[derive(Debug, thiserror::Error)]
pub enum UserServiceError {
    #[error("User not found: {0}")]
    NotFound(Uuid),
    #[error("Email already exists: {0}")]
    EmailExists(String),
    #[error("Invalid email format: {0}")]
    InvalidEmail(String),
}

impl UserService {
    pub fn new() -> Self {
        Self {
            users: HashMap::new(),
        }
    }

    pub fn create_user(&mut self, email: String, name: String) -> Result<User, UserServiceError> {
        // Validate email format
        if !email.contains('@') {
            return Err(UserServiceError::InvalidEmail(email));
        }

        // Check if email already exists
        if self.users.values().any(|u| u.email == email) {
            return Err(UserServiceError::EmailExists(email));
        }

        let user = User {
            id: Uuid::new_v4(),
            email,
            name,
            active: true,
        };

        self.users.insert(user.id, user.clone());
        Ok(user)
    }

    pub fn get_user(&self, id: Uuid) -> Result<&User, UserServiceError> {
        self.users.get(&id).ok_or(UserServiceError::NotFound(id))
    }

    pub fn update_user(&mut self, id: Uuid, name: Option<String>, active: Option<bool>) -> Result<User, UserServiceError> {
        let user = self.users.get_mut(&id).ok_or(UserServiceError::NotFound(id))?;
        
        if let Some(name) = name {
            user.name = name;
        }
        
        if let Some(active) = active {
            user.active = active;
        }

        Ok(user.clone())
    }

    pub fn delete_user(&mut self, id: Uuid) -> Result<User, UserServiceError> {
        self.users.remove(&id).ok_or(UserServiceError::NotFound(id))
    }

    pub fn list_active_users(&self) -> Vec<&User> {
        self.users.values().filter(|u| u.active).collect()
    }

    pub fn find_by_email(&self, email: &str) -> Option<&User> {
        self.users.values().find(|u| u.email == email)
    }
}

// Unit tests
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_create_user_success() {
        let mut service = UserService::new();
        let result = service.create_user("test@example.com".to_string(), "Test User".to_string());
        
        assert!(result.is_ok());
        let user = result.unwrap();
        assert_eq!(user.email, "test@example.com");
        assert_eq!(user.name, "Test User");
        assert!(user.active);
    }

    #[test]
    fn test_create_user_invalid_email() {
        let mut service = UserService::new();
        let result = service.create_user("invalid-email".to_string(), "Test User".to_string());
        
        assert!(result.is_err());
        match result.unwrap_err() {
            UserServiceError::InvalidEmail(email) => assert_eq!(email, "invalid-email"),
            _ => panic!("Expected InvalidEmail error"),
        }
    }

    #[test]
    fn test_create_user_duplicate_email() {
        let mut service = UserService::new();
        
        // Create first user
        service.create_user("test@example.com".to_string(), "User 1".to_string()).unwrap();
        
        // Try to create second user with same email
        let result = service.create_user("test@example.com".to_string(), "User 2".to_string());
        
        assert!(result.is_err());
        match result.unwrap_err() {
            UserServiceError::EmailExists(email) => assert_eq!(email, "test@example.com"),
            _ => panic!("Expected EmailExists error"),
        }
    }

    #[test]
    fn test_get_user_success() {
        let mut service = UserService::new();
        let user = service.create_user("test@example.com".to_string(), "Test User".to_string()).unwrap();
        
        let retrieved = service.get_user(user.id).unwrap();
        assert_eq!(retrieved, &user);
    }

    #[test]
    fn test_get_user_not_found() {
        let service = UserService::new();
        let random_id = Uuid::new_v4();
        let result = service.get_user(random_id);
        
        assert!(result.is_err());
        match result.unwrap_err() {
            UserServiceError::NotFound(id) => assert_eq!(id, random_id),
            _ => panic!("Expected NotFound error"),
        }
    }

    #[test]
    fn test_update_user_name() {
        let mut service = UserService::new();
        let user = service.create_user("test@example.com".to_string(), "Old Name".to_string()).unwrap();
        
        let updated = service.update_user(user.id, Some("New Name".to_string()), None).unwrap();
        assert_eq!(updated.name, "New Name");
        assert_eq!(updated.email, "test@example.com"); // Email unchanged
        assert!(updated.active); // Active unchanged
    }

    #[test]
    fn test_update_user_active_status() {
        let mut service = UserService::new();
        let user = service.create_user("test@example.com".to_string(), "Test User".to_string()).unwrap();
        
        let updated = service.update_user(user.id, None, Some(false)).unwrap();
        assert!(!updated.active);
        assert_eq!(updated.name, "Test User"); // Name unchanged
    }

    #[test]
    fn test_delete_user_success() {
        let mut service = UserService::new();
        let user = service.create_user("test@example.com".to_string(), "Test User".to_string()).unwrap();
        
        let deleted = service.delete_user(user.id).unwrap();
        assert_eq!(deleted, user);
        
        // Verify user is actually deleted
        assert!(service.get_user(user.id).is_err());
    }

    #[test]
    fn test_list_active_users() {
        let mut service = UserService::new();
        
        // Create active user
        let active_user = service.create_user("active@example.com".to_string(), "Active User".to_string()).unwrap();
        
        // Create inactive user
        let inactive_user = service.create_user("inactive@example.com".to_string(), "Inactive User".to_string()).unwrap();
        service.update_user(inactive_user.id, None, Some(false)).unwrap();
        
        let active_users = service.list_active_users();
        assert_eq!(active_users.len(), 1);
        assert_eq!(active_users[0].id, active_user.id);
    }

    #[test]
    fn test_find_by_email() {
        let mut service = UserService::new();
        let user = service.create_user("test@example.com".to_string(), "Test User".to_string()).unwrap();
        
        let found = service.find_by_email("test@example.com");
        assert!(found.is_some());
        assert_eq!(found.unwrap(), &user);
        
        let not_found = service.find_by_email("nonexistent@example.com");
        assert!(not_found.is_none());
    }

    // Property-based testing example
    #[cfg(test)]
    mod property_tests {
        use super::*;
        use proptest::prelude::*;

        proptest! {
            #[test]
            fn test_create_user_with_valid_email(
                local in "[a-zA-Z0-9]{1,20}",
                domain in "[a-zA-Z0-9]{1,20}",
                tld in "[a-zA-Z]{2,4}",
                name in "[a-zA-Z ]{1,50}"
            ) {
                let mut service = UserService::new();
                let email = format!("{}@{}.{}", local, domain, tld);
                
                let result = service.create_user(email.clone(), name.clone());
                assert!(result.is_ok());
                
                let user = result.unwrap();
                assert_eq!(user.email, email);
                assert_eq!(user.name, name);
                assert!(user.active);
            }

            #[test]
            fn test_invalid_emails_rejected(invalid_email in "[a-zA-Z0-9]{1,20}") {
                let mut service = UserService::new();
                let result = service.create_user(invalid_email, "Test User".to_string());
                assert!(result.is_err());
            }
        }
    }

    // Benchmark tests
    #[cfg(test)]
    mod benchmarks {
        use super::*;
        use criterion::{criterion_group, criterion_main, Criterion, BenchmarkId};

        fn benchmark_user_operations(c: &mut Criterion) {
            let mut group = c.benchmark_group("user_service");
            
            // Benchmark user creation
            group.bench_function("create_user", |b| {
                b.iter(|| {
                    let mut service = UserService::new();
                    let email = format!("user{}@example.com", rand::random::<u32>());
                    service.create_user(email, "Test User".to_string())
                })
            });
            
            // Benchmark user lookup
            group.bench_function("get_user", |b| {
                let mut service = UserService::new();
                let user = service.create_user("test@example.com".to_string(), "Test User".to_string()).unwrap();
                
                b.iter(|| {
                    service.get_user(user.id)
                })
            });
            
            // Benchmark with different user counts
            for user_count in [10, 100, 1000].iter() {
                group.bench_with_input(
                    BenchmarkId::new("find_by_email", user_count),
                    user_count,
                    |b, &user_count| {
                        let mut service = UserService::new();
                        
                        // Create users
                        for i in 0..user_count {
                            service.create_user(
                                format!("user{}@example.com", i),
                                format!("User {}", i)
                            ).unwrap();
                        }
                        
                        b.iter(|| {
                            service.find_by_email("user50@example.com")
                        })
                    }
                );
            }
            
            group.finish();
        }

        criterion_group!(benches, benchmark_user_operations);
        criterion_main!(benches);
    }
}