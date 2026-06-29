#include <iostream>
#include <stdexcept>
#include <filesystem>
#include <chrono>
#include <cstdio>
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

    lua.ExecuteFile("scripts/main.lua");

    auto lastFpsTime = std::chrono::steady_clock::now();
    int frames = 0;

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

      frames++;
      auto now = std::chrono::steady_clock::now();
      if (now - lastFpsTime >= std::chrono::seconds(1)) {
        printf("FPS: %d\n", frames);
        frames = 0;
        lastFpsTime = now;
      }
    }

    return 0;
  } catch (const std::exception &e) {
    std::cerr << "E666: " << e.what() << "\n";
    return 1;
  }
}
