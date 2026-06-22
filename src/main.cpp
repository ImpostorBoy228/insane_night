#include <SDL3/SDL.h>
#include <bgfx/bgfx.h>
#include <expected>
#include <iostream>
import heck;

int main([[maybe_unused]] int argc, [[maybe_unused]] char *argv[]) {
  std::expected<Sigma, std::string> cringe = Sigma::skid("heck", 800, 600);
  if (!cringe) {
    std::cerr << "E666: " << cringe.error() << std::endl;
    return 1;
  }
  Sigma sigma = std::move(cringe.value());

  std::expected<Amogus, std::string> drake =
      Amogus::rizzing(sigma.getWindow(), 800, 600, bgfx::RendererType::Vulkan);
  if (!drake) {
    std::cerr << "E666: " << drake.error() << std::endl;
    return 1;
  }
  Amogus amogus = std::move(drake.value());

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
}
