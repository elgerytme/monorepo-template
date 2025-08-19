#include <pybind11/pybind11.h>
#include <pybind11/stl.h>
#include <pybind11/chrono.h>
#include <memory>
#include <string>
#include <vector>

extern "C" {
    #include "example_shared_library.h"
}

namespace py = pybind11;

class PyUser {
public:
    std::string id;
    std::string name;
    std::string email;
    std::string created_at;

    PyUser(const std::string& id, const std::string& name, 
           const std::string& email, const std::string& created_at)
        : id(id), name(name), email(email), created_at(created_at) {}
};

class PyUserManager {
private:
    bool initialized;

public:
    PyUserManager() : initialized(false) {
        if (library_init() == ErrorCode::Success) {
            initialized = true;
        } else {
            throw std::runtime_error("Failed to initialize library");
        }
    }

    ~PyUserManager() {
        if (initialized) {
            library_cleanup();
        }
    }

    PyUser create_user(const std::string& name, const std::string& email) {
        if (!initialized) {
            throw std::runtime_error("Library not initialized");
        }

        CUser c_user;
        ErrorCode result = ::create_user(name.c_str(), email.c_str(), &c_user);
        
        if (result != ErrorCode::Success) {
            std::string error_msg = get_error_message(result);
            throw std::runtime_error("Failed to create user: " + error_msg);
        }

        PyUser user(
            std::string(c_user.id),
            std::string(c_user.name),
            std::string(c_user.email),
            std::string(c_user.created_at)
        );

        free_user(&c_user);
        return user;
    }

    PyUser get_user(const std::string& id) {
        if (!initialized) {
            throw std::runtime_error("Library not initialized");
        }

        CUser c_user;
        ErrorCode result = ::get_user(id.c_str(), &c_user);
        
        if (result == ErrorCode::NotFound) {
            throw py::key_error("User not found");
        } else if (result != ErrorCode::Success) {
            std::string error_msg = get_error_message(result);
            throw std::runtime_error("Failed to get user: " + error_msg);
        }

        PyUser user(
            std::string(c_user.id),
            std::string(c_user.name),
            std::string(c_user.email),
            std::string(c_user.created_at)
        );

        free_user(&c_user);
        return user;
    }

    int get_user_count() {
        if (!initialized) {
            throw std::runtime_error("Library not initialized");
        }
        return ::get_user_count();
    }
};

PYBIND11_MODULE(example_shared_py, m) {
    m.doc() = "Python bindings for example shared library";

    py::class_<PyUser>(m, "User")
        .def(py::init<const std::string&, const std::string&, 
                     const std::string&, const std::string&>())
        .def_readwrite("id", &PyUser::id)
        .def_readwrite("name", &PyUser::name)
        .def_readwrite("email", &PyUser::email)
        .def_readwrite("created_at", &PyUser::created_at)
        .def("__repr__", [](const PyUser& u) {
            return "<User id='" + u.id + "' name='" + u.name + "' email='" + u.email + "'>";
        });

    py::class_<PyUserManager>(m, "UserManager")
        .def(py::init<>())
        .def("create_user", &PyUserManager::create_user,
             "Create a new user with the given name and email")
        .def("get_user", &PyUserManager::get_user,
             "Get a user by ID")
        .def("get_user_count", &PyUserManager::get_user_count,
             "Get the total number of users");

    py::enum_<ErrorCode>(m, "ErrorCode")
        .value("Success", ErrorCode::Success)
        .value("InvalidInput", ErrorCode::InvalidInput)
        .value("ValidationError", ErrorCode::ValidationError)
        .value("NotFound", ErrorCode::NotFound)
        .value("AlreadyExists", ErrorCode::AlreadyExists)
        .value("InternalError", ErrorCode::InternalError);
}