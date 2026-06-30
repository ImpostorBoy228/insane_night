#include <iostream>
#include <chrono>
#include <cstdio>
#include <thread>
#include "heck.hpp"
#include "ligma/ligma.hpp"
#include "ligma/bind.hpp"
// TODO: lazy rendering
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
      auto frameStart = std::chrono::steady_clock::now();

      SDL_Event event;
      while (SDL_PollEvent(&event)) {
        if (event.type == SDL_EVENT_QUIT or (
            event.type == SDL_EVENT_KEY_DOWN and
            event.key.key == SDLK_ESCAPE)) {
          engine.gooning = false;
        }
        if (event.type == SDL_EVENT_KEY_DOWN) {
            sol::protected_function onKeyDown = lua.get_state()["onKeyDown"];
            if (onKeyDown.valid()) onKeyDown(event.key.key);
        }

        if (event.type == SDL_EVENT_WINDOW_RESIZED ||
            event.type == SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED) {
          engine.resize(event.window.data1, event.window.data2);

          sol::protected_function onResize = lua.get_state()["onResize"];
          if (onResize.valid()) {
            sol::protected_function_result result = onResize(engine.width, engine.height);
            if (!result.valid()) {
              sol::error error = result;
              std::cerr << "Lua resize callback error: " << error.what() << '\n';
            }
          }
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

      if (engine.frameLimit > 0) {
        const auto targetFrameTime = std::chrono::nanoseconds(1000000000LL / engine.frameLimit);
        const auto frameDeadline = frameStart + targetFrameTime;
        auto currentTime = std::chrono::steady_clock::now();

        constexpr auto coarseSleepGuard = std::chrono::milliseconds(2);
        if (currentTime + coarseSleepGuard < frameDeadline) {
          const auto sleepTime = std::chrono::duration_cast<std::chrono::nanoseconds>(
              frameDeadline - currentTime - coarseSleepGuard);
          SDL_DelayNS(static_cast<Uint64>(sleepTime.count()));
        }

        while ((currentTime = std::chrono::steady_clock::now()) < frameDeadline) {
          std::this_thread::yield();
        }
      }
    }

    return 0;
  } catch (const std::exception &e) {
    std::cerr << "E666: " << e.what() << "\n";
    return 1;
  }
}
