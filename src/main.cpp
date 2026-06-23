#include <SDL3/SDL.h>
#include <bgfx/bgfx.h>
#include <iostream>
#include <stdexcept>
import heck;

int main([[maybe_unused]] int argc, [[maybe_unused]] char *argv[]) {
  try {
    Sigma sigma = Sigma::skid("heck", 800, 600);
    Amogus amogus = Amogus::rizzing(
        sigma.getWindow(), 800, 600, bgfx::RendererType::Vulkan);

    bool gooning = true;
    while (gooning) {
      SDL_Event event;
      while (SDL_PollEvent(&event)) {
        if (event.type == SDL_EVENT_QUIT) {
          gooning = false;
        }
        if (event.type == SDL_EVENT_KEY_DOWN) {
          if (event.key.key == SDLK_ESCAPE) {
            gooning = false;
          }
        }
        if (event.type == SDL_EVENT_WINDOW_RESIZED) {
          amogus.resize(event.window.data1, event.window.data2);
        }
      }
      amogus.frame();
    }

    return 0;
  } catch (const std::exception &e) {
    std::cerr << "E666: " << e.what() << std::endl;
    return 1;
  }
}
