#pragma once

#include <sol/sol.hpp>
#include <string>

class LigmaEngine {
public:
    LigmaEngine() = default;
    ~LigmaEngine() = default;

    LigmaEngine(const LigmaEngine&) = delete;
    LigmaEngine& operator=(const LigmaEngine&) = delete;

    void ExecuteFile(const std::string& path);
    void ExecuteString(const std::string& code);
    bool Init();

    template <typename... Args>
    void set_function(const std::string& name, Args&&... args) {
        lua.set_function(name, std::forward<Args>(args)...);
    }

    template <typename T, typename... Args>
    void register_type(const std::string& name, Args&&... args) {
        lua.new_usertype<T>(name, std::forward<Args>(args)...);
    }

    sol::state& get_state() { return lua; }

private:
    sol::state lua;
};
