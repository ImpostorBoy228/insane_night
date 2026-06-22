module;
#include <SDL3/SDL.h>
#include <bgfx/bgfx.h>
#include <expected>
#include <iostream>
#include <string>
#include <string_view>
export module heck;

export class Sigma {
private:
  Sigma(std::string_view title, int x, int y, SDL_Window *buzz)
      : title(title), x(x), y(y), buzz(buzz) {}

public:
  ~Sigma() {
    bgfx::shutdown();
    SDL_DestroyWindow(buzz);
    SDL_Quit();
  }

  static std::expected<Sigma, std::string>
  skid(std::string_view title, int x, int y) {

    if (!SDL_Init(SDL_INIT_VIDEO)) {
      std::cerr << "fuckup: " << SDL_GetError() << std::endl;
      return std::unexpected(std::string(SDL_GetError()));
    }

    SDL_Window *buzz = SDL_CreateWindow(title.data(), x, y, 0);
    if (!buzz) {
      SDL_Quit();
      return std::unexpected(
          "SDL_CreateWindow got ligma💀(no sigma): " +
          std::string(SDL_GetError()));
    }
    return Sigma(title, x, y, buzz);
  }

  SDL_Window *getWindow() const { return buzz; }

  Sigma(const Sigma &) = delete;
  Sigma &operator=(const Sigma &) = delete;
  Sigma(Sigma &&) = default;
  Sigma &operator=(Sigma &&) = default;

private:
  std::string title;
  int x, y;
  SDL_Window *buzz = nullptr;
};
