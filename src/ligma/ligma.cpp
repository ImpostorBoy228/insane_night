#include "ligma.hpp"
#include <filesystem>
#include <iostream>

bool LigmaEngine::Init() {
    try {
        lua.open_libraries(
            sol::lib::base,
            sol::lib::package,
            sol::lib::string,
            sol::lib::math,
            sol::lib::table,
            sol::lib::io,
            sol::lib::os,
            sol::lib::debug
        );
        return true;
    } catch (const sol::error& e) {
        std::cerr << "Lua einit : " << e.what() << '\n';
        return false;
    }
}

void LigmaEngine::ExecuteFile(const std::string& path) {
    if (!std::filesystem::exists(path)) {
        std::cerr << "nf: " << path << '\n';
        return;
    }
    try {
        lua.script_file(path);
    } catch (const sol::error& e) {
        std::cerr << "runtime e " << path << ": " << e.what() << '\n';
    }
}

void LigmaEngine::ExecuteString(const std::string& code) {
    try {
        lua.script(code);
    } catch (const sol::error& e) {
        std::cerr << "runtime e: " << e.what() << '\n';
    }
}
