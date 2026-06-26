#include <iostream>
#include <stdexcept>
#include "heck.h"

int main([[maybe_unused]] int argc, [[maybe_unused]] char *argv[]) {
  try {
    Sigma sigma = Sigma::skid("heck", 800, 600);
    Amogus amogus = Amogus::rizzing(
        sigma.getWindow(), 800, 600, bgfx::RendererType::Vulkan);

    TextGooner textGooner;
    textGooner.init("/usr/share/fonts/TTF/DejaVuSans.ttf", 32);

    UIman ui;
    ui.AddElement<Text>("Hello, world!", 50, 50, 32, 0xffffffff, 0);
    ui.BuildAll();

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
          amogus.resize(event.window.data1, event.window.data2);
        }
      }

      textGooner.beginFrame(800, 600);
      ui.Draw(textGooner);
      textGooner.endFrame();
      amogus.frame();
    }

    return 0;
  } catch (const std::exception &e) {
    std::cerr << "E666: " << e.what() << std::endl;
    return 1;
  }
}
