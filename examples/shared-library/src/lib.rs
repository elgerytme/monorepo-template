use serde::{Deserialize, Serialize};
use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int};
use uuid::Uuid;

pub mod error;
pub mod user;
pub mod validation;

pub use error::{LibraryError, LibraryResult};
pub use user::{User, UserManager};
pub use validation::Validator;

/// C-compatible error codes
#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub enum ErrorCode {
    Success = 0,
    InvalidInput = 1,
    ValidationError = 2,
    NotFound = 3,
    AlreadyExists = 4,
    InternalError = 5,
}

/// C-compatible user structure
#[repr(C)]
#[derive(Debug)]
pub struct CUser {
    pub id: *mut c_char,
    pub name: *mut c_char,
    pub email: *mut c_char,
    pub created_at: *mut c_char,
}

impl CUser {
    fn from_user(user: &User) -> LibraryResult<Self> {
        Ok(CUser {
            id: CString::new(user.id.to_string())?.into_raw(),
            name: CString::new(user.name.clone())?.into_raw(),
            email: CString::new(user.email.clone())?.into_raw(),
            created_at: CString::new(user.created_at.to_rfc3339())?.into_raw(),
        })
    }

    unsafe fn free(&mut self) {
        if !self.id.is_null() {
            let _ = CString::from_raw(self.id);
            self.id = std::ptr::null_mut();
        }
        if !self.name.is_null() {
            let _ = CString::from_raw(self.name);
            self.name = std::ptr::null_mut();
        }
        if !self.email.is_null() {
            let _ = CString::from_raw(self.email);
            self.email = std::ptr::null_mut();
        }
        if !self.created_at.is_null() {
            let _ = CString::from_raw(self.created_at);
            self.created_at = std::ptr::null_mut();
        }
    }
}

/// Global user manager instance
static mut USER_MANAGER: Option<UserManager> = None;
static mut MANAGER_INITIALIZED: bool = false;

/// Initialize the library
#[no_mangle]
pub extern "C" fn library_init() -> ErrorCode {
    unsafe {
        if !MANAGER_INITIALIZED {
            USER_MANAGER = Some(UserManager::new());
            MANAGER_INITIALIZED = true;
        }
    }
    ErrorCode::Success
}

/// Create a new user
#[no_mangle]
pub extern "C" fn create_user(
    name: *const c_char,
    email: *const c_char,
    user_out: *mut CUser,
) -> ErrorCode {
    if name.is_null() || email.is_null() || user_out.is_null() {
        return ErrorCode::InvalidInput;
    }

    let name_str = match unsafe { CStr::from_ptr(name) }.to_str() {
        Ok(s) => s,
        Err(_) => return ErrorCode::InvalidInput,
    };

    let email_str = match unsafe { CStr::from_ptr(email) }.to_str() {
        Ok(s) => s,
        Err(_) => return ErrorCode::InvalidInput,
    };

    unsafe {
        if let Some(ref mut manager) = USER_MANAGER {
            match manager.create_user(name_str, email_str) {
                Ok(user) => {
                    match CUser::from_user(&user) {
                        Ok(c_user) => {
                            *user_out = c_user;
                            ErrorCode::Success
                        }
                        Err(_) => ErrorCode::InternalError,
                    }
                }
                Err(LibraryError::ValidationError(_)) => ErrorCode::ValidationError,
                Err(LibraryError::AlreadyExists(_)) => ErrorCode::AlreadyExists,
                Err(_) => ErrorCode::InternalError,
            }
        } else {
            ErrorCode::InternalError
        }
    }
}

/// Get user by ID
#[no_mangle]
pub extern "C" fn get_user(id: *const c_char, user_out: *mut CUser) -> ErrorCode {
    if id.is_null() || user_out.is_null() {
        return ErrorCode::InvalidInput;
    }

    let id_str = match unsafe { CStr::from_ptr(id) }.to_str() {
        Ok(s) => s,
        Err(_) => return ErrorCode::InvalidInput,
    };

    let uuid = match Uuid::parse_str(id_str) {
        Ok(u) => u,
        Err(_) => return ErrorCode::InvalidInput,
    };

    unsafe {
        if let Some(ref manager) = USER_MANAGER {
            match manager.get_user(&uuid) {
                Some(user) => {
                    match CUser::from_user(&user) {
                        Ok(c_user) => {
                            *user_out = c_user;
                            ErrorCode::Success
                        }
                        Err(_) => ErrorCode::InternalError,
                    }
                }
                None => ErrorCode::NotFound,
            }
        } else {
            ErrorCode::InternalError
        }
    }
}

/// Get user count
#[no_mangle]
pub extern "C" fn get_user_count() -> c_int {
    unsafe {
        if let Some(ref manager) = USER_MANAGER {
            manager.user_count() as c_int
        } else {
            -1
        }
    }
}

/// Free a CUser structure
#[no_mangle]
pub extern "C" fn free_user(user: *mut CUser) {
    if !user.is_null() {
        unsafe {
            (*user).free();
        }
    }
}

/// Get error message for error code
#[no_mangle]
pub extern "C" fn get_error_message(code: ErrorCode) -> *const c_char {
    let message = match code {
        ErrorCode::Success => "Success",
        ErrorCode::InvalidInput => "Invalid input provided",
        ErrorCode::ValidationError => "Validation failed",
        ErrorCode::NotFound => "Resource not found",
        ErrorCode::AlreadyExists => "Resource already exists",
        ErrorCode::InternalError => "Internal error occurred",
    };

    message.as_ptr() as *const c_char
}

/// Cleanup library resources
#[no_mangle]
pub extern "C" fn library_cleanup() {
    unsafe {
        USER_MANAGER = None;
        MANAGER_INITIALIZED = false;
    }
}