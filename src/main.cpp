#include <iostream>
#include <stdexcept>
#include <filesystem>
#include "heck.hpp"
#include "ligma/ligma.hpp"
#include "ligma/bind.hpp"

int main([[maybe_unused]] int argc, [[maybe_unused]] char *argv[]) {
    LigmaEngine lua;

    if (!lua.Init()) {
        std::cerr << "Lua fuckup" << "\n";
        return 1;
    }

  try {
    Hell_Machina engine;
    engine.init("heck", 1280, 720, bgfx::RendererType::Vulkan);

    ligma_bind(lua.get_state(), engine);

    std::string scriptPath = "scripts/sscreen.lua";
    if (std::filesystem::exists(scriptPath)) {
        std::cout << "exec " << scriptPath << "\n";
        lua.ExecuteFile(scriptPath);
    } else {
        std::cout << "no " << scriptPath << ", using C++ fallback\n";
        auto tex = loadTexture("test.png");
        if (!bgfx::isValid(tex))
            throw std::runtime_error("failed to load test.png");
        auto &uiLayer = engine.addUILayer("ui");
        uiLayer.add<Text>(engine.getTextGooner(), "Hello, world!", 50, 50, 0xffffffff, 0);
        uiLayer.add<Rectangle>(engine.getRectGooner(), 50, 50, 150, 30, 0xff0000ff, 0);
        uiLayer.add<Image>(engine.getImageGooner(), tex, 200, 200, 48, 48, 0xffffffff, 0);
    }

    while (engine.gooning) {
      SDL_Event event;
      while (SDL_PollEvent(&event)) {
        if (event.type == SDL_EVENT_QUIT or (
            event.type == SDL_EVENT_KEY_DOWN and
            event.key.key == SDLK_ESCAPE)) {
          engine.gooning = false;
        }
        if (event.type == SDL_EVENT_WINDOW_RESIZED) {
          engine.resize(event.window.data1, event.window.data2);
        }
        engine.handleEvent(event);
      }

      engine.frame();
    }

    return 0;
  } catch (const std::exception &e) {
    std::cerr << "E666: " << e.what() << "\n";
    return 1;
  }
}
