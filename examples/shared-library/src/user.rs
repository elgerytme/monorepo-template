use crate::{LibraryError, LibraryResult, Validator};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct User {
    pub id: Uuid,
    pub name: String,
    pub email: String,
    pub created_at: DateTime<Utc>,
}

impl User {
    pub fn new(name: String, email: String) -> LibraryResult<Self> {
        let validator = Validator::new();
        
        validator.validate_name(&name)?;
        validator.validate_email(&email)?;

        Ok(User {
            id: Uuid::new_v4(),
            name: name.trim().to_string(),
            email: email.trim().to_lowercase(),
            created_at: Utc::now(),
        })
    }

    pub fn to_json(&self) -> LibraryResult<String> {
        serde_json::to_string(self).map_err(LibraryError::from)
    }

    pub fn from_json(json: &str) -> LibraryResult<Self> {
        serde_json::from_str(json).map_err(LibraryError::from)
    }
}

#[derive(Debug)]
pub struct UserManager {
    users: HashMap<Uuid, User>,
}

impl UserManager {
    pub fn new() -> Self {
        Self {
            users: HashMap::new(),
        }
    }

    pub fn create_user(&mut self, name: &str, email: &str) -> LibraryResult<User> {
        // Check for duplicate email
        if self.users.values().any(|u| u.email == email.trim().to_lowercase()) {
            return Err(LibraryError::AlreadyExists(format!(
                "User with email '{}' already exists",
                email
            )));
        }

        let user = User::new(name.to_string(), email.to_string())?;
        self.users.insert(user.id, user.clone());
        Ok(user)
    }

    pub fn get_user(&self, id: &Uuid) -> Option<&User> {
        self.users.get(id)
    }

    pub fn get_user_by_email(&self, email: &str) -> Option<&User> {
        let email_lower = email.trim().to_lowercase();
        self.users.values().find(|u| u.email == email_lower)
    }

    pub fn list_users(&self) -> Vec<&User> {
        let mut users: Vec<&User> = self.users.values().collect();
        users.sort_by(|a, b| b.created_at.cmp(&a.created_at));
        users
    }

    pub fn update_user(&mut self, id: &Uuid, name: Option<&str>, email: Option<&str>) -> LibraryResult<&User> {
        let user = self.users.get_mut(id)
            .ok_or_else(|| LibraryError::NotFound(format!("User with ID '{}' not found", id)))?;

        let validator = Validator::new();

        if let Some(new_name) = name {
            validator.validate_name(new_name)?;
            user.name = new_name.trim().to_string();
        }

        if let Some(new_email) = email {
            validator.validate_email(new_email)?;
            let new_email_lower = new_email.trim().to_lowercase();
            
            // Check for duplicate email (excluding current user)
            if self.users.values().any(|u| u.id != *id && u.email == new_email_lower) {
                return Err(LibraryError::AlreadyExists(format!(
                    "User with email '{}' already exists",
                    new_email
                )));
            }
            
            user.email = new_email_lower;
        }

        Ok(user)
    }

    pub fn delete_user(&mut self, id: &Uuid) -> LibraryResult<User> {
        self.users.remove(id)
            .ok_or_else(|| LibraryError::NotFound(format!("User with ID '{}' not found", id)))
    }

    pub fn user_count(&self) -> usize {
        self.users.len()
    }

    pub fn clear(&mut self) {
        self.users.clear();
    }
}

impl Default for UserManager {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_user_creation() {
        let user = User::new("John Doe".to_string(), "john@example.com".to_string()).unwrap();
        assert_eq!(user.name, "John Doe");
        assert_eq!(user.email, "john@example.com");
        assert!(!user.id.is_nil());
    }

    #[test]
    fn test_user_validation() {
        assert!(User::new("".to_string(), "john@example.com".to_string()).is_err());
        assert!(User::new("John Doe".to_string(), "invalid-email".to_string()).is_err());
    }

    #[test]
    fn test_user_manager() {
        let mut manager = UserManager::new();
        
        let user = manager.create_user("John Doe", "john@example.com").unwrap();
        assert_eq!(manager.user_count(), 1);
        
        let retrieved = manager.get_user(&user.id).unwrap();
        assert_eq!(retrieved.name, "John Doe");
        
        // Test duplicate email
        assert!(manager.create_user("Jane Doe", "john@example.com").is_err());
    }

    #[test]
    fn test_json_serialization() {
        let user = User::new("John Doe".to_string(), "john@example.com".to_string()).unwrap();
        let json = user.to_json().unwrap();
        let deserialized = User::from_json(&json).unwrap();
        
        assert_eq!(user.id, deserialized.id);
        assert_eq!(user.name, deserialized.name);
        assert_eq!(user.email, deserialized.email);
    }
}