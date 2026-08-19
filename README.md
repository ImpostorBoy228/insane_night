## insane_night - new gen visual novel engine
### Core stuff
- based on bgfx(potentially crossplatform)
- uses C++26 + cmake + ninja 
- lua integration for game logic
- son for main script instead of JSON
### Docs
1. sceclude.md - my sceclude according to deepseek and my commits
2. RAM_ANALYSIS.md - RAM usage audit(for stupid ones)
3. DOCS.md - actual docs for core cpp and lua 
4. AI_SHIT_DONT_READ.md - early ai generaged file. multiplicously updated 
5. bugreport19_08.md - bug report in tier list format
### How to start out 
> prepare your assets and modify script.son. if you need some advanced features like cut scenes, code it.
### dependencies
1. compiler with C++26 support (GCC 16+ / Clang)
2. cmake 3.20+ and ninja
3. freetype2 (dev headers)
4. sdl3 (dev + pkg-config, pre-release 3.4.0)
5. bgfx/bimg/bx submodules with prebuilt static libs in external/lib/
6. tsfont, sol2, nlohmann/json, son, gen_alpha_dictionary (submodules)
7. lua 5.4.8 and soloud 20200207 — bundled, not submodules, fetch them yourself
8. stb_image.h (single header)

### build & run
> make dev   # debug build
> make release
> make tests
> ./insane_night
