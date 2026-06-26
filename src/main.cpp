#include <iostream>
#include <stdexcept>
#include "heck.hpp"

int main([[maybe_unused]] int argc, [[maybe_unused]] char *argv[]) {
  try {
    Hell_Machina engine;
    engine.init("heck", 800, 600, bgfx::RendererType::Vulkan);

    auto &uiLayer = engine.addUILayer("ui");
    uiLayer.add<Text>(engine.getTextGooner(), "Hello, world!", 50, 50, 0xffffffff, 0);
    uiLayer.buildAll();

    bool gooning = true;
    while (gooning) {
      SDL_Event event;
      while (SDL_PollEvent(&event)) {
        if (event.type == SDL_EVENT_QUIT or (
            event.type == SDL_EVENT_KEY_DOWN and
            event.key.key == SDLK_ESCAPE)) {
          gooning = false;
        }
        if (event.type == SDL_EVENT_WINDOW_RESIZED) {
          engine.resize(event.window.data1, event.window.data2);
        }
      }

      engine.frame();
    }

    return 0;
  } catch (const std::exception &e) {
    std::cerr << "E666: " << e.what() << std::endl;
    return 1;
  }
}
