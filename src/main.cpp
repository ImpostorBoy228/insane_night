#include <iostream>
#include <stdexcept>
#include "heck.hpp"

int main([[maybe_unused]] int argc, [[maybe_unused]] char *argv[]) {
    if (!fuckCpp) goto naxyi;

  try {
    Hell_Machina engine;
    engine.init("heck", 800, 600, bgfx::RendererType::Vulkan);

    auto tex = loadTexture("test.png");
    if (!bgfx::isValid(tex))
      throw std::runtime_error("failed to load test.tga");

    auto &uiLayer = engine.addUILayer("ui");
    uiLayer.add<Text>(engine.getTextGooner(), "Hello, world!", 50, 50, 0xffffffff, 0);
    uiLayer.add<Rectangle>(engine.getRectGooner(), 50, 50, 150, 30, 0xff0000ff, 0);
    uiLayer.add<Image>(engine.getImageGooner(), tex, 200, 200, 48, 48, 0xffffffff, 0);

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

    if (bgfx::isValid(tex)) bgfx::destroy(tex);
    return 0;
  } catch (const std::exception &e) {
    std::cerr << "E666: " << e.what() << "\n";
    return 1;
  }
naxyi:
  return -1;
}
