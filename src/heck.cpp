module;
#include <SDL3/SDL.h>
#include <SDL3/SDL_properties.h>
#include <bgfx/bgfx.h>
#include <expected>
#include <iostream>
#include <string>
#include <string_view>
export module heck;

//SDL
export class Sigma {
private:
  Sigma(std::string_view title, int x, int y, SDL_Window *buzz)
      : title(title), x(x), y(y), buzz(buzz) {}

public:
  ~Sigma() {
    if (buzz != nullptr) {
      SDL_DestroyWindow(buzz);
      SDL_Quit();
    }
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
  Sigma(Sigma&& other)
  : title(std::move(other.title)), x(other.x), y(other.y), buzz(other.buzz) {
    other.buzz = nullptr;
  }
  Sigma &operator=(Sigma &&) = default;

private:
  std::string title;
  int x, y;
  SDL_Window *buzz = nullptr;
};

//bgfx
export class Amogus {
private:
  SDL_Window *buzz = nullptr;
  int x, y;
  bgfx::RendererType::Enum goonerType;

  Amogus(SDL_Window* buzz, int x, int y, bgfx::RendererType::Enum goonerType)
  : buzz(buzz), x(x), y(y), goonerType(goonerType) {}
public:
  ~Amogus() {if (buzz) bgfx::shutdown();}

  static std::expected<Amogus, std::string>
  rizzing(SDL_Window *buzz, int w, int h, bgfx::RendererType::Enum goonerType) {
      bgfx::PlatformData pld{};
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
        pld.type = bgfx::NativeWindowHandleType::Default;
        void *x11_display = SDL_GetPointerProperty(
            props, SDL_PROP_WINDOW_X11_DISPLAY_POINTER, nullptr);
        void *x11_window = SDL_GetPointerProperty(
            props, SDL_PROP_WINDOW_X11_WINDOW_NUMBER, nullptr);
        if (x11_display && x11_window) {
          pld.ndt = x11_display;
          pld.nwh = x11_window;
        } else {
          return std::unexpected("no wayland or x11 props");
        }
      }

      bgfx::Init init;
      init.type = goonerType;
      init.resolution.width = w;
      init.resolution.height = h;
      init.resolution.reset = BGFX_RESET_VSYNC;
      init.platformData = pld;

      if (!bgfx::init(init)) {
          return std::unexpected("bgfx::init edged");
      }

      bgfx::setViewClear(0, BGFX_CLEAR_COLOR | BGFX_CLEAR_DEPTH, 0x000000ff, 1.0f, 0);
      bgfx::setViewRect(0, 0, 0, w, h);

      return std::expected<Amogus, std::string>(Amogus(buzz, w, h, goonerType));
  }

  void frame() {bgfx::touch(0); bgfx::frame();}
  void resize(int w, int h) {
    bgfx::reset(w, h, BGFX_RESET_VSYNC);
    bgfx::setViewRect(0, 0, 0, w, h);
    x = w;
    y = h;
  }

  Amogus(const Amogus&) = delete;
  Amogus& operator=(const Amogus&) = delete;

  Amogus(Amogus&& other) noexcept
  : buzz(other.buzz), x(other.x), y(other.y), goonerType(other.goonerType) {
      other.buzz = nullptr;
  }

  Amogus& operator=(Amogus&& other) noexcept {
    if (this != &other) {
      buzz = other.buzz;
      x = other.x;
      y = other.y;
      goonerType = other.goonerType;
      other.buzz = nullptr;
    }
    return *this;
  }
};
