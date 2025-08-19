use crate::{LibraryError, LibraryResult};
use std::collections::HashSet;

pub struct Validator {
    forbidden_domains: HashSet<String>,
}

impl Validator {
    pub fn new() -> Self {
        let mut forbidden_domains = HashSet::new();
        forbidden_domains.insert("example.org".to_string());
        forbidden_domains.insert("test.invalid".to_string());
        forbidden_domains.insert("localhost".to_string());

        Self { forbidden_domains }
    }

    pub fn validate_name(&self, name: &str) -> LibraryResult<()> {
        let trimmed = name.trim();
        
        if trimmed.is_empty() {
            return Err(LibraryError::ValidationError(
                "Name cannot be empty".to_string()
            ));
        }

        if trimmed.len() < 2 {
            return Err(LibraryError::ValidationError(
                "Name must be at least 2 characters long".to_string()
            ));
        }

        if trimmed.len() > 100 {
            return Err(LibraryError::ValidationError(
                "Name cannot be longer than 100 characters".to_string()
            ));
        }

        // Check for valid characters (letters, spaces, hyphens, apostrophes)
        if !trimmed.chars().all(|c| c.is_alphabetic() || c.is_whitespace() || c == '-' || c == '\'') {
            return Err(LibraryError::ValidationError(
                "Name can only contain letters, spaces, hyphens, and apostrophes".to_string()
            ));
        }

        // Check for consecutive spaces
        if trimmed.contains("  ") {
            return Err(LibraryError::ValidationError(
                "Name cannot contain consecutive spaces".to_string()
            ));
        }

        Ok(())
    }

    pub fn validate_email(&self, email: &str) -> LibraryResult<()> {
        let trimmed = email.trim();
        
        if trimmed.is_empty() {
            return Err(LibraryError::ValidationError(
                "Email cannot be empty".to_string()
            ));
        }

        // Basic email format validation
        if !self.is_valid_email_format(trimmed) {
            return Err(LibraryError::ValidationError(
                "Invalid email format".to_string()
            ));
        }

        // Check email length
        if trimmed.len() > 254 {
            return Err(LibraryError::ValidationError(
                "Email cannot be longer than 254 characters".to_string()
            ));
        }

        // Extract domain and check against forbidden list
        if let Some(domain) = self.extract_domain(trimmed) {
            if self.forbidden_domains.contains(&domain.to_lowercase()) {
                return Err(LibraryError::ValidationError(
                    format!("Email domain '{}' is not allowed", domain)
                ));
            }
        }

        Ok(())
    }

    fn is_valid_email_format(&self, email: &str) -> bool {
        // Simple email validation - in production, use a proper email validation library
        let parts: Vec<&str> = email.split('@').collect();
        if parts.len() != 2 {
            return false;
        }

        let local = parts[0];
        let domain = parts[1];

        // Local part validation
        if local.is_empty() || local.len() > 64 {
            return false;
        }

        // Domain part validation
        if domain.is_empty() || domain.len() > 253 {
            return false;
        }

        // Domain must contain at least one dot
        if !domain.contains('.') {
            return false;
        }

        // Basic character validation
        let valid_local_chars = |c: char| c.is_alphanumeric() || "!#$%&'*+-/=?^_`{|}~.".contains(c);
        let valid_domain_chars = |c: char| c.is_alphanumeric() || c == '.' || c == '-';

        local.chars().all(valid_local_chars) && domain.chars().all(valid_domain_chars)
    }

    fn extract_domain(&self, email: &str) -> Option<&str> {
        email.split('@').nth(1)
    }

    pub fn validate_user_data(&self, name: &str, email: &str) -> LibraryResult<()> {
        self.validate_name(name)?;
        self.validate_email(email)?;
        Ok(())
    }
}

impl Default for Validator {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_name_validation() {
        let validator = Validator::new();

        // Valid names
        assert!(validator.validate_name("John Doe").is_ok());
        assert!(validator.validate_name("Mary-Jane").is_ok());
        assert!(validator.validate_name("O'Connor").is_ok());
        assert!(validator.validate_name("José").is_ok());

        // Invalid names
        assert!(validator.validate_name("").is_err());
        assert!(validator.validate_name("J").is_err());
        assert!(validator.validate_name("John123").is_err());
        assert!(validator.validate_name("John  Doe").is_err()); // consecutive spaces
        assert!(validator.validate_name(&"a".repeat(101)).is_err()); // too long
    }

    #[test]
    fn test_email_validation() {
        let validator = Validator::new();

        // Valid emails
        assert!(validator.validate_email("john@example.com").is_ok());
        assert!(validator.validate_email("user.name@domain.co.uk").is_ok());
        assert!(validator.validate_email("test+tag@gmail.com").is_ok());

        // Invalid emails
        assert!(validator.validate_email("").is_err());
        assert!(validator.validate_email("invalid").is_err());
        assert!(validator.validate_email("@domain.com").is_err());
        assert!(validator.validate_email("user@").is_err());
        assert!(validator.validate_email("user@domain").is_err());
        assert!(validator.validate_email("user@example.org").is_err()); // forbidden domain
    }

    #[test]
    fn test_forbidden_domains() {
        let validator = Validator::new();

        assert!(validator.validate_email("test@example.org").is_err());
        assert!(validator.validate_email("test@test.invalid").is_err());
        assert!(validator.validate_email("test@localhost").is_err());
    }
}