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
  SDL_Window *buzz = sigma.getWindow();

  bgfx::PlatformData pld;
  pld.nwh = nullptr;
  pld.ndt = nullptr;
  pld.context = nullptr;
  pld.backBuffer = nullptr;
  pld.backBufferDS = nullptr;
  pld.type = bgfx::NativeWindowHandleType::Wayland;

  SDL_PropertiesID props = SDL_GetWindowProperties(buzz);
  void *wl_display = SDL_GetPointerProperty(
      props, SDL_PROP_WINDOW_WAYLAND_DISPLAY_POINTER, nullptr);
  void *wl_surface = SDL_GetPointerProperty(
      props, SDL_PROP_WINDOW_WAYLAND_SURFACE_POINTER, nullptr);
  if (wl_display && wl_surface) {
    pld.ndt = wl_display;
    pld.nwh = wl_surface;
  } else {
    std::cerr << "E666: no props" << std::endl;
    SDL_DestroyWindow(buzz);
    SDL_Quit();
    return 1;
  }

  bgfx::Init init;
  init.type = bgfx::RendererType::Vulkan;
  init.resolution.width = 800;
  init.resolution.height = 600;
  init.resolution.reset = BGFX_RESET_VSYNC;
  init.platformData = pld;

  if (!bgfx::init(init)) {
    std::cerr << "E228: bgfx::init failed" << std::endl;
    SDL_DestroyWindow(buzz);
    SDL_Quit();
    return 1;
  }

  bgfx::setViewClear(0, BGFX_CLEAR_COLOR | BGFX_CLEAR_DEPTH,
      0x303030ff, 1.0f, 0);
  bgfx::setViewRect(0, 0, 0, 800, 600);

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
        bgfx::setViewRect(0, 0, 0, event.window.data1, event.window.data2);
      }
    }
    bgfx::touch(0);
    bgfx::frame();
  }

  bgfx::shutdown();
  SDL_DestroyWindow(buzz);
  SDL_Quit();

  return 0;
}
