#include <iostream>
#include <chrono>
#include <cstdio>
#include <thread>
#include "heck.hpp"
#include "ligma/ligma.hpp"
#include "ligma/bind.hpp"

int main([[maybe_unused]] int argc, [[maybe_unused]] char *argv[]) {
  try {
    LigmaEngine lua;
    Hell_Machina engine;

    if (!lua.Init()) {
        std::cerr << "Lua fuckup" << "\n";
        return 1;
    }

    engine.init("heck", 1920, 1080, bgfx::RendererType::Count);

    auto s_preload = std::chrono::high_resolution_clock::now();
    engine.preloadTextures("assets");
    engine.preloadSounds("assets");

    ligma_bind(lua.get_state(), engine);
    auto e_preload = std::chrono::high_resolution_clock::now();

    std::cout << "preload: " << std::chrono::duration<double, std::milli>(e_preload - s_preload).count() << " ms\n";

    lua.ExecuteFile("scripts/main.lua");

    auto dt = 0.0f;
    auto prevFrame = std::chrono::steady_clock::now();

    while (engine.gooning) {
      auto frameStart = std::chrono::steady_clock::now();
      dt = std::chrono::duration<float>(frameStart - prevFrame).count();
      prevFrame = frameStart;
      SDL_Event event;
      while (SDL_PollEvent(&event)) {
        switch (event.type) {
        case SDL_EVENT_QUIT:
        case SDL_EVENT_WINDOW_CLOSE_REQUESTED:
          engine.gooning = false;
          break;
        case SDL_EVENT_KEY_DOWN:
          if (event.key.key == SDLK_ESCAPE)
            engine.gooning = false;
          {
            sol::protected_function onKeyDown = lua.get_state()["onKeyDown"];
            if (onKeyDown.valid()) onKeyDown(event.key.key);
          }
          break;
        case SDL_EVENT_WINDOW_FOCUS_GAINED:
          engine.windowActive = true;
          break;
        case SDL_EVENT_WINDOW_FOCUS_LOST:
          engine.windowActive = false;
          break;
        case SDL_EVENT_WINDOW_RESIZED:
        case SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED:
          engine.resize(event.window.data1, event.window.data2);
          {
            sol::protected_function onResize = lua.get_state()["onResize"];
            if (onResize.valid()) {
              sol::protected_function_result result = onResize(engine.width, engine.height);
              if (!result.valid()) {
                sol::error error = result;
                std::cerr << "Lua resize callback error: " << error.what() << '\n';
              }
            }
          }
          break;
        case SDL_EVENT_WINDOW_MINIMIZED:
          engine.windowActive = false;
          break;
        case SDL_EVENT_WINDOW_RESTORED:
        case SDL_EVENT_WINDOW_EXPOSED:
          engine.windowActive = true;
          break;
        }
        engine.handleEvent(event);
      }

      if (engine.windowActive) {
        engine.update(dt);
        engine.frame();
      } else {
        engine.frame();
        SDL_DelayNS(50'000'000);
      }

      {
        sol::protected_function onFrame = lua.get_state()["onFrame"];
        if (onFrame.valid()) {
          sol::protected_function_result result = onFrame(dt);
          if (!result.valid()) {
            sol::error error = result;
            std::cerr << "Lua onFrame error: " << error.what() << '\n';
          }
        }
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
    printf("\n");

    return 0;
  } catch (const std::exception &e) {
    std::cerr << "E666: " << e.what() << "\n";
    return 1;
  }
}
