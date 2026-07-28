# Insane Night — Developer Documentation

> Real documentation for real developers. Last updated: 28 Jul 2026.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Architecture](#2-architecture)
3. [Engine Initialization & Main Loop](#3-engine-initialization--main-loop)
4. [Gooner System: Adding New Renderers](#4-gooner-system-adding-new-renderers)
5. [Skibidi System: Adding New UI Elements](#5-skibidi-system-adding-new-ui-elements)
6. [Layer System](#6-layer-system)
7. [Texture & Resource Management](#7-texture--resource-management)
8. [Audio System](#8-audio-system)
9. [Lua Bindings Reference](#9-lua-bindings-reference)
10. [Lua Scene Development](#10-lua-scene-development)
11. [Visual Novel System](#11-visual-novel-system)
12. [Settings & Save System](#12-settings--save-system)
13. [Build System & Asset Pipeline](#13-build-system--asset-pipeline)
14. [Best Practices & Patterns](#14-best-practices--patterns)

---

## 1. Project Overview

**Insane Night** is a 2D visual novel engine written in C++23 with Lua 5.4 scripting. It renders via bgfx (OpenGL), uses SDL3 for windowing/input, SoLoud for audio, and FreeType2 via tsfont for font rendering.

```
Language    C++23, Lua 5.4, GLSL shaders
Build       CMake 3.20+ + Ninja, GCC 16.1.1 / Clang
Rendering   bgfx (OpenGL) + bimg + stb_image
Windowing   SDL3 (pre-release 3.4.0)
Audio       SoLoud 20200207 (miniaudio backend)
Fonts       tsfont (FreeType2 wrapper) + FreeType2
Scripting   sol2 (C++→Lua binding)
JSON        nlohmann/json (C++) + rxi/json.lua (Lua)
```

### Source Layout

```
src/
├── main.cpp                  Entry point, game loop
├── heck.hpp                  Monolithic engine header (1506 lines)
├── heck.cpp                  Engine implementation + STB_IMAGE_IMPLEMENTATION
├── audio_unc.hpp/cpp         SoLoud audio wrapper
├── tsfont_wrapper.hpp        C++ wrapper for tsfont C API
├── ligma/
│   ├── ligma.hpp/cpp          LigmaEngine — sol2 Lua state wrapper
│   └── bind.hpp              Lua binding registration (all C++→Lua glue)
└── shaders/                  bgfx shader sources + compiled .bin.h
scripts/
├── main.lua                  Entry point, scene manager, key routing
├── sscreen.lua               Main menu scene ("menu")
├── game.lua                  Visual novel scene ("gay")
├── settings.lua              Settings scene
├── script.json               Dialogue tree (JSON nodes)
├── settings.json             Persisted settings
├── state.json                Saved game state
└── libs/json.lua             Pure Lua JSON encoder/decoder
assets/
├── *.png / *.jpg / *.mp3 / *.ttf   Game assets
external/                     Submodules + prebuilt libs
```

---

## 2. Architecture

The engine uses a **two-layer architecture**:

```
┌──────────────────────────────────────────────────┐
│                    Lua Layer                      │
│  Scene management, UI layout, dialogue logic      │
│  game.lua, sscreen.lua, settings.lua              │
│                                                    │
│  Calls C++ functions via sol2 bindings:            │
│  addUILayer, addTextF, loadTexture, etc.           │
└──────────────┬───────────────────────────────────┘
               │ sol2 bindings (bind.hpp)
               ▼
┌──────────────────────────────────────────────────┐
│                   C++ Engine                      │
│  hell_machina (Hell_Machina)                      │
│    ├── Sigma (SDL window)                         │
│    ├── Amogus (bgfx context)                      │
│    ├── CacheMan (texture cache)                   │
│    ├── TextGooner (font atlas + glyph rendering)  │
│    ├── RectGooner (rectangle shader)              │
│    ├── ImageGooner (image shader)                 │
│    ├── AudioEngine (SoLoud audio)                 │
│    ├── JohnPork (batch renderer)                  │
│    ├── sceneLayers / uiLayers (Layer deques)      │
│    └── Kino scenePass + uiPass (render passes)    │
└──────────────────────────────────────────────────┘
```

### Key Design Decisions

- **C++ renders, Lua decides**: All rendering primitives are C++. All layout, logic, and flow control is Lua.
- **No immediate mode**: Elements are created via `Layer::add<T>()`, stored, and rendered each frame through `collect(JohnPork&)`.
- **Batch rendering**: All draw calls in a frame are batched by shader/texture/state via `JohnPork`, then flushed with transient vertex buffers.
- **Two render passes**: scene layers (game world) render first, UI layers overlay on top.
- **Z-sorting**: Items within a layer are sorted by `zindex` ascending (lower = behind).

---

## 3. Engine Initialization & Main Loop

### Startup Sequence (main.cpp)

```
1. LigmaEngine.Init()           — open sol2, load Lua libs
2. Hell_Machina.Init()         — create window, bgfx, shaders, audio
3. preloadTextures("assets")   — async decode via std::async
4. preloadSounds("assets")     — load all audio files
5. ligma_bind(lua, engine)      — register 19 functions + 8 usertypes in Lua
6. ExecuteFile("main.lua")     — boot Lua, which loads sub-scenes
7. Game loop (while gooning)
```

### Game Loop (main.cpp:35-119)

```
while (engine.gooning):
  1. Calculate dt = frameStart - prevFrame
  2. SDL_PollEvent → dispatch:
     - SDL_EVENT_QUIT / CLOSE_REQUESTED → gooning = false
     - SDL_EVENT_KEY_DOWN (ESC → exit, else → lua.onKeyDown(key))
     - SDL_EVENT_WINDOW_RESIZED → engine.resize() + lua.onResize()
     - FOCUS / MINIMIZE / RESTORE → windowActive tracking
  3. engine.handleEvent(event)  — hit-test clicks on all layers
  4. if windowActive:
       engine.update(dt)        — update all Skibidi (reveal anims etc.)
       engine.frame()           — render scene + UI passes
     else:
       SDL_DelayNS(50ms)        — idle when minimized
  5. lua.onFrame(dt)            — Lua per-frame callback
  6. Frame limiter (if frameLimit > 0):
       coarse SDL_DelayNS + spin-wait std::this_thread::yield
```

### Hell_Machina::frame() rendering flow (heck.cpp:73-99)

```
1. Handle pending fullscreen change (debounced 500ms)
2. pork.clear() + pork.reserve() — prepare batch renderer
3. scenePass.begin() → for each sceneLayer: collect(pork) → pork.flush(scenePass.id)
4. uiPass.begin()   → for each uiLayer:    collect(pork) → pork.flush(uiPass.id)
5. bgfx::frame()
```

---

## 4. Gooner System: Adding New Renderers

A "Gooner" is an engine component that owns a bgfx shader program, a vertex layout definition, and optionally a sampler uniform. Gooners are the rendering backends that Skibidi elements use.

### Existing Gooners

| Gooner | Shaders | Vertex Format | Used By | Purpose |
|--------|---------|---------------|---------|---------|
| `RectGooner` | `vs_rect` + `fs_rect` | Position(vec2) + Color0(u8vec4) = 12 bytes | `Rectangle` | Solid-color filled rectangles |
| `ImageGooner` | `vs_image` + `fs_image` | Position(vec2) + TexCoord0(vec2) + Color0(u8vec4) = 20 bytes | `Image` | Textured images |
| `TextGooner` | `vs_text` + `fs_text` | Position(vec2) + TexCoord0(vec2) + Color0(u8vec4) = 20 bytes | `Text` | Font atlas + glyph rendering |

### How to Create a New Gooner

Let's say you want a `RoundedRectGooner` that renders rounded rectangles with a custom shader.

**Step 1: Write shaders** in `src/shaders/`:

```
src/shaders/vs_rounded.sc     — vertex shader
src/shaders/fs_rounded.sc     — fragment shader
```

**Step 2: Compile shaders** — run `make shaders` to generate `.bin.h` files.

**Step 3: Create the Gooner class** in `heck.hpp`:

```cpp
class RoundedRectGooner {
    bgfx::ProgramHandle program;
    bgfx::VertexLayout layout;
public:
    bool init() {
        bgfx::ShaderHandle vsh = bgfx::createShader(
            bgfx::makeRef(vs_rounded, sizeof(vs_rounded)));
        bgfx::ShaderHandle fsh = bgfx::createShader(
            bgfx::makeRef(fs_rounded, sizeof(fs_rounded)));
        program = bgfx::createProgram(vsh, fsh, true);

        layout.begin()
            .add(bgfx::Attrib::Position, 2, bgfx::AttribType::Float)
            .add(bgfx::Attrib::Color0,   4, bgfx::AttribType::Uint8, true)
            .end();
        return true;
    }

    bgfx::ProgramHandle getProgram() const { return program; }
    const bgfx::VertexLayout& getLayout() const { return layout; }

    void destroy() {
        if (bgfx::isValid(program)) bgfx::destroy(program);
    }
};
```

**Step 4: Add to Hell_Machina** (heck.hpp ~line 1425):

```cpp
class Hell_Machina {
    // ... existing members ...
    RoundedRectGooner roundedGooner;
public:
    // ... in init():
    roundedGooner.init();
    // Add getter:
    RoundedRectGooner& getRoundedRectGooner() { return roundedGooner; }
};
```

**Step 5: Register in Lua bindings** (bind.hpp):

```cpp
luaState.new_usertype<RoundedRectGooner>("RoundedRectGooner");
luaState.set_function("getRoundedRectGooner",
    [&]() -> RoundedRectGooner& { return engine.getRoundedRectGooner(); });
```

**Step 6: Use from Lua:**

```lua
local rr = getRoundedRectGooner()
layer:addRoundedRect(rr, 0.1, 0.1, 0.3, 0.3, 0xffffffff, 5)
```

---

## 5. Skibidi System: Adding New UI Elements

`Skibidi` is the abstract base class for all renderable/clickable UI elements.

### Skibidi Interface (heck.hpp:460-490)

```cpp
class Skibidi {
public:
    Skibidi(string_view type, int32_t zindex);
    virtual ~Skibidi();
    virtual void Build() = 0;                        // One-time setup after construction
    virtual void collect(JohnPork& pork) = 0;        // Emit geometry each frame
    virtual void onResize(int pw, int ph) {}         // Window resize notification
    virtual void update(float dt) {}                 // Per-frame update

    int32_t zindex;                                  // Sort order (lower = behind)
    bool visible = true;                             // Visibility toggle

    std::function<void()> onClick;                   // Click callback
    float hitX = 0, hitY = 0, hitW = 0, hitH = 0;   // Hitbox in screen coords

    void setHitbox(float x, float y, float w, float h);
    bool hitTest(float mx, float my) const;

    bool hasFrac = false;                            // Fractional positioning
    float frx, fry, frw, frh;
    void setFrac(float rx, float ry, float rw, float rh);
};
```

### How to Create a New Skibidi Subclass

Let's create a `RoundedRect` element that uses our hypothetical `RoundedRectGooner`.

```cpp
class RoundedRect : public Skibidi {
    RoundedRectGooner &gooner;
    float x, y, w, h;
    uint32_t color;
    float radius;
public:
    RoundedRect(RoundedRectGooner &gooner,
                float x, float y, float w, float h,
                uint32_t color, float radius, int32_t zindex)
        : Skibidi("roundedrect", zindex)
        , gooner(gooner), x(x), y(y), w(w), h(h)
        , color(color), radius(radius)
    {
        setHitbox(x, y, w, h);
    }

    void Build() override {}

    void onResize(int pw, int ph) override {
        if (hasFrac) {
            x = frx * pw; y = fry * ph;
            w = frw * pw; h = frh * ph;
            setHitbox(x, y, w, h);
        }
    }

    void collect(JohnPork &pork) override {
        struct Vertex { float x, y; uint32_t color; };
        Vertex verts[4] = {
            {x,     y,      color},
            {x + w, y,      color},
            {x + w, y + h,  color},
            {x,     y + h,  color},
        };
        uint16_t idxs[6] = {0, 1, 2, 0, 2, 3};

        BatchKey key;
        key.program    = gooner.getProgram();
        key.texUniform = BGFX_INVALID_HANDLE;
        key.tex        = BGFX_INVALID_HANDLE;
        key.layout     = &gooner.getLayout();
        key.state      = BGFX_STATE_WRITE_RGB | BGFX_STATE_WRITE_A | BGFX_STATE_BLEND_ALPHA;

        pork.pushGeometry(key, verts, 4, sizeof(Vertex), idxs, 6);
    }
};
```

### Add Convenience Method to Layer (heck.hpp ~1189)

```cpp
RoundedRect* addRoundedRect(RoundedRectGooner& gooner,
    float x, float y, float w, float h,
    uint32_t color, float radius, int32_t zindex)
{
    return add<RoundedRect>(gooner, x, y, w, h, color, radius, zindex);
}
```

### Register in Lua Bindings (bind.hpp)

```cpp
luaState.new_usertype<RoundedRect>("RoundedRect",
    "onClick",   [&](RoundedRect& self, const sol::protected_function& cb) {
        self.onClick = bind_click_callback(cb);
    },
    "setHitbox", &Skibidi::setHitbox
);

// In Layer usertype:
"addRoundedRect", [](Layer& self, RoundedRectGooner& g,
    float x, float y, float w, float h,
    uint32_t color, float radius, int32_t z)
{
    return self.addRoundedRect(g, x, y, w, h, color, radius, z);
},
```

### Internal Workings

**Z-sorting**: Items are sorted ascending by `zindex` via `std::sort` in `ensureSorted()`, called lazily before `collect()` and `pickClickHandler()`. Lower zindex renders first (behind).

**Hit testing** (`pickClickHandler`):
1. Only triggers on `SDL_EVENT_MOUSE_BUTTON_DOWN` + `SDL_BUTTON_LEFT`
2. Iterates items in **reverse** z-order (topmost first)
3. For each visible item with non-null `onClick`, calls `hitTest(mx, my)`
4. Falls through to `Clickable` list if no Skibidi matches

**Fractional positioning** (`setFrac`):
- Stores relative coordinates (0.0–1.0 range)
- `onResize` multiplies by window dimensions to compute absolute pixel positions
- Used by all `add*F` Lua methods for responsive layouts

---

## 6. Layer System

Layers are containers for Skibidi elements and Clickable zones. They are organized into two deques in Hell_Machina:

- **Scene layers** (`sceneLayers`): rendered first (behind)
- **UI layers** (`uiLayers`): rendered second (overlay)

### Layer API (heck.hpp:1156-1262)

```cpp
class Layer {
    std::vector<std::unique_ptr<Skibidi>> items;
    std::vector<Clickable> clickables;
public:
    void clear();                                      // Remove all items + clickables
    void ensureSorted();                               // Sort items by zindex

    // Template method — create any Skibidi subclass
    template<typename T, typename... Args>
    requires std::derived_from<T, Skibidi>
    T* add(Args&&... args);

    // Convenience wrappers
    Text* addText(TextGooner&, const char*, float x, float y, uint32_t color, int32_t z);
    Rectangle* addRectangle(RectGooner&, float x, float y, float w, float h, uint32_t color, int32_t z);
    Image* addImage(ImageGooner&, bgfx::TextureHandle, float x, float y, float w, float h, uint32_t color, int32_t z);

    // Invisible clickable zones (no visual element)
    void addClickable(float x, float y, float w, float h, std::function<void()> cb);
    void addClickableF(float rx, float ry, float rw, float rh, int pw, int ph, std::function<void()> cb);

    // Window resize propagation
    void onResize(int pw, int ph);

    // Collect all visible items' geometry into JohnPork
    void collect(JohnPork& pork);

    // Event handling
    bool pickClickHandler(const SDL_Event& ev, std::function<void()>& callback);
    bool handleEvent(const SDL_Event& ev);
    void update(float dt);
};
```

### Common Layer Patterns

**Creating layers from Lua:**
```lua
local ui = addUILayer("my_layer")    -- creates UI layer (on top)
local sc = addSceneLayer("my_scene") -- creates scene layer (behind)
```

**Getting existing layers:**
```lua
local ui = getUILayer("my_layer")    -- returns nil if not found
local sc = getSceneLayer("my_scene")
```

**Layer lifecycle in scene switching** (main.lua):
```lua
function switchTo(name)
    currentSceneName = name
    if currentScene then currentScene.visible = false end

    local layerName = "scene_" .. name
    local ui = getUILayer(layerName)
    if not ui then ui = addUILayer(layerName) end

    ui:clear()
    ui.visible = true
    currentScene = ui

    local fn = scenes[name]
    if fn then fn(ui) end
end
```

### Clickable Zones vs Skibidi.onClick

- **Skibidi.onClick**: Set on individual Text/Rectangle/Image elements. The element's `hitTest()` uses its stored `hitX, hitY, hitW, hitH`.
- **Clickable zones**: Invisible rectangular areas stored separately in `clickables` vector. Tested after all Skibidi items.

Both are checked in reverse z-order / insertion order.

---

## 7. Texture & Resource Management

### CacheMan (heck.hpp:104-211)

Central texture cache. Loads images via stb_image (fast path) or bimg (fallback for uncommon formats).

```cpp
class CacheMan {
    bgfx::TextureHandle loadTexture(const char* path, int* outW=nullptr, int* outH=nullptr);
    int getWidth(const char* path);
    int getHeight(const char* path);
    void preloadTextures(const std::string& dir);
    void destroy();
};
```

**Load behavior:**
1. Check `textures` map by path string — return cached handle if valid
2. Miss: call `loadTextureUncached(path)`:
   - Try `stbi_load` (fast RGBA8 path)
   - Fallback to `bimg::imageParse` + `bimg::imageConvert` to RGBA8
3. On success: create `bgfx::Texture2D` with `bgfx::TextureFormat::RGBA8`, cache it
4. On failure: return `BGFX_INVALID_HANDLE` (idx == 65535)

**Preload:** Uses `std::async` to decode images in parallel, then uploads to GPU serially on the main thread.

**From Lua:**
```lua
local tex = loadTexture("assets/background.png")
if tex.idx ~= 65535 then
    -- texture loaded successfully
end
local w = getImageWidth("assets/background.png")
local h = getImageHeight("assets/background.png")
```

### Batching with JohnPork (heck.hpp:238-305)

`JohnPork` collects geometry from all Skibidi elements and batches draw calls by matching `BatchKey` fields:

```cpp
struct BatchKey {
    bgfx::ProgramHandle         program;
    bgfx::UniformHandle         texUniform;
    bgfx::TextureHandle         tex;
    const bgfx::VertexLayout   *layout;
    uint64_t                    state;
    uint32_t                    samplerFlags;
};
```

Batches are matched by all 6 fields (exact match). Different textures → different batches. For efficient rendering, try to share textures when possible.

---

## 8. Audio System

### AudioEngine API (audio_unc.hpp/cpp)

```cpp
class AudioEngine {
    bool init();
    void deinit();
    void setGlobalVolume(float volume);          // clamped [0, 1]
    uint32_t playSound(string_view path, bool singleInstance = true);
    void stopSound(uint32_t soundId);
    void stopAllSounds();
    void preloadSounds(const string& dir);
};
```

**From Lua:**
```lua
local audio = getAudioEngine()
audio:setVolume(0.5)
local id = audio:playSound("assets/pablo_.mp3", true)  -- single instance
audio:stopSound(id)
audio:stopAllSounds()
```

**Sound cache:** Sounds are loaded into `unordered_map<string, unique_ptr<SoLoud::Wav>>` on first access and cached. `preloadSounds("assets")` loads all .mp3/.wav/.ogg files recursively.

---

## 9. Lua Bindings Reference

### Global Functions

| Lua Name | C++ Signature | Description |
|---|---|---|
| `loadTexture(path)` | `(string) → TextureHandle` | Load/cache texture. `idx=65535` = invalid |
| `getImageWidth(path)` | `(string) → int` | Cached texture width |
| `getImageHeight(path)` | `(string) → int` | Cached texture height |
| `getAudioEngine()` | `() → AudioEngine&` | Audio controller |
| `setFullscreen(bool)` | `(bool)` | Toggle fullscreen |
| `setVsync(bool)` | `(bool)` | Toggle vsync |
| `setVolume(float)` | `(float)` | Master volume 0.0–1.0 |
| `setFrameLimit(int)` | `(int)` | FPS limit (-1=VSync, 0=unlimited, 30/60/120) |
| `addUILayer(name)` | `(string) → Layer&` | Create new UI layer |
| `addSceneLayer(name)` | `(string) → Layer&` | Create new scene layer |
| `getUILayer(name)` | `(string) → Layer& or nil` | Get existing UI layer |
| `getSceneLayer(name)` | `(string) → Layer& or nil` | Get existing scene layer |
| `getTextGooner()` | `() → TextGooner&` | Default font gooner |
| `getTextGooner(path, size)` | `(string, int) → TextGooner&` | Font gooner by path+size |
| `getRectGooner()` | `() → RectGooner&` | Rect renderer |
| `getImageGooner()` | `() → ImageGooner&` | Image renderer |
| `setFont(path, size)` | `(string, int)` | Reinit default font |
| `getScreenWidth()` | `() → int` | Window width in pixels |
| `getScreenHeight()` | `() → int` | Window height in pixels |
| `fuckOff()` | `()` | Exit game loop |

### TextureHandle

```lua
tex.idx  -- uint16: 65535 = BGFX_INVALID_HANDLE
```

### Layer Methods

```lua
-- Absolute pixel positioning:
layer:addText(gooner, text, x, y, color, zIndex)          → Txt
layer:addRectangle(gooner, x, y, w, h, color, zIndex)     → Rect
layer:addImage(gooner, texture, x, y, w, h, color, zIndex) → Img
layer:addClickable(x, y, w, h, callback)                   → nil

-- Fractional positioning (0.0–1.0 relative to screen):
layer:addTextF(gooner, text, rx, ry, color, zIndex)        → Txt
layer:addRectF(gooner, rx, ry, rw, rh, color, zIndex)      → Rect
layer:addImageF(gooner, texture, rx, ry, rw, rh, color, zIndex) → Img
layer:addClickableF(rx, ry, rw, rh, callback)              → nil

-- Layer control:
layer:clear()                      -- remove all elements
layer.visible = true / false        -- show/hide layer
```

**Color format:** `0xAABBGGRR` (ABGR, not RGBA).

### Element Types

**Rect (Rectangle)**
```lua
rect:onClick(function() ... end)    -- set click handler
rect:setHitbox(x, y, w, h)         -- override hit-test area
```

**Img (Image)**
```lua
img:onClick(function() ... end)
img:setHitbox(x, y, w, h)
```

**Txt (Text)**
```lua
txt:onClick(function() ... end)
txt:setHitbox(x, y, w, h)
txt:reveal(speed)                  -- start typewriter reveal (glyphs/sec)
txt:showAll()                      -- show all text immediately
txt:isRevealing()                  → boolean
txt:setRevealCount(n)              -- manually set visible glyph count
```

### TextGooner

```lua
gooner:measureText(text)           → float (pixel width)
gooner:getLineHeight()             → float (pixel line height)
```

### AudioEngine

```lua
audio:playSound(path, singleInstance?)  → uint32 (handle or 0 on fail)
audio:stopSound(handle)
audio:stopAllSounds()
audio:setVolume(0.0–1.0)
```

### Lua Callbacks (called from C++)

```lua
function onKeyDown(key)     -- SDL keycode on any key press
function onResize(w, h)     -- window resize event
function onFrame(dt)        -- every frame after rendering (dt in seconds)
```

---

## 10. Lua Scene Development

### Creating a New Scene

**Step 1: Create a Lua file** (e.g., `scripts/credits.lua`):

```lua
---@diagnostic disable: undefined-global, undefined-field
local g = {
    text = getTextGooner(),
    rect = getRectGooner(),
}

register("credits", function(ui)
    setFont("assets/HackRegular-gX84.ttf", 24)

    -- Background
    local bg = loadTexture("assets/background.png")
    if bg.idx ~= 65535 then
        ui:addImageF(getImageGooner(), bg, 0, 0, 1, 1, 0xffffffff, -1)
    end

    -- Title
    local title = ui:addTextF(g.text, "Credits", 0.4, 0.2, 0xffffffff, 1)

    -- Back button
    local btn = ui:addRectF(g.rect, 0.35, 0.7, 0.3, 0.07, 0xffffffff, 0)
    ui:addTextF(g.text, "Back", 0.4, 0.71, 0xff000000, 1)
    btn:onClick(function()
        switchTo("menu")
    end)
end)
```

**Step 2: Load the scene** in `scripts/main.lua`:

```lua
dofile("scripts/credits.lua")
```

**Step 3: Switch to it** from anywhere:

```lua
switchTo("credits")
```

### Scene Lifecycle

1. `register("name", fn)` — stores the render function
2. `switchTo("name")` — hides current layer, gets/creates `UILayer("scene_name")`, clears it, calls `fn(ui)`
3. On each frame, the layer's items are rendered (collected into JohnPork)
4. On window resize, `onResize` propagates to all items (fractional positions recomputed)
5. `switchTo` another scene to hide this one

### Responsive Layout Patterns

**Fractional positioning** (recommended):
```lua
-- Position and size as fractions of screen dimensions
ui:addRectF(g.rect, 0.5 - 0.2, 0.3, 0.4, 0.07, 0xffffffff, 0)
ui:addTextF(g.text, "Hello", 0.5 - 0.2, 0.29, 0xff000000, 1)
```

**Pixel positioning** (fixed size, not responsive):
```lua
ui:addRectangle(g.rect, 100, 200, 400, 50, 0xffffffff, 0)
ui:addText(g.text, "Hello", 110, 195, 0xff000000, 1)
```

### Click Handling

```lua
-- Element-based click
local btn = ui:addRectF(g.rect, 0.3, 0.3, 0.4, 0.07, 0xffffffff, 0)
btn:onClick(function()
    print("Button clicked!")
end)

-- Invisible clickable zone
ui:addClickableF(0, 0, 0.5, 1, function()
    print("Left half of screen clicked")
end)
```

### Animation with onFrame

```lua
local timer = 0
local myElement = nil

function onFrame(dt)
    if not myElement then return end
    timer = timer + dt
    -- Animate every frame (requires re-rendering)
end
```

---

## 11. Visual Novel System

The VN engine in `game.lua` processes dialogue nodes from `script.json`.

### Dialogue Node Format (script.json)

```json
{
  "start": "node_id",
  "nodes": {
    "node_id": {
      "text": "Dialogue text. Can be very long — word wrapping is automatic.",
      "next": "next_node_id",
      "bg": "assets/background.png",
      "speaker": "Character Name",
      "character": "assets/sprite.png",
      "character_place": "right|left|mid",
      "sound": "assets/audio.mp3",
      "qu": "Question text for choices?",
      "choices": ["Answer 1", "Answer 2"]
    }
  }
}
```

**Fields:**
- `text` — dialogue text. Supports `\n` for explicit line breaks.
- `next` — ID of next node. Omit to end the game (dead end).
- `bg` — background image path. Persists until changed.
- `speaker` — name shown in the speaker badge.
- `character` — character sprite path. Use "" to clear.
- `character_place` — sprite position: `"right"` (default), `"left"`, `"mid"`.
- `sound` — background music/ambient. `""` stops sound. Persists until changed.
- `qu` — question text. If present, shows choice buttons instead of "next" button.
- `choices` — array of choice labels. Required if `qu` is set.

### Dialogue Configuration

Edit `dialogueCfg` in `game.lua` to customize layout:

```lua
local dialogueCfg = {
    -- Dialogue panel at bottom of screen
    Kawasaki = { x = 0, y = 0.7, w = 1, h = 0.3 },
    -- Text wrapping area (right = right edge)
    Cago = { x = 0.05, y = 0.75, right = 0.95, bottom = 1 },
    -- Speaker name badge
    Krico = {
        x = 0.07, y = 0.65, h = 0.05,
        maxWidth = 0.5,
        paddingPx = 36,
        textInset = 0.014,
        textY = 0.65 + (0.05 / 3)
    },
}
```

### Text Rendering Pipeline

```
node.text → splitExplicitLines() → split by \n
  → wrapText() → greedy word-wrap using gooner:measureText()
  → paginateLines() → split into pages by available height
  → render current page as Text element with reveal(40)
```

### Choice System

When `node.qu` is set, `finger(node, qu)` creates an overlay layer ("choice") with:
- Full-screen dark overlay (z=-11)
- Question text
- Clickable choice buttons

Each choice records `{node=currentNode, choice=text}` in `vn.currentChoices`, then advances to `node.next`.

---

## 12. Settings & Save System

### Persistent Settings (settings.lua)

**Settings file:** `scripts/settings.json`

```json
{"fullscreen": false, "volume": 1.0, "framelimit": -1}
```

**API:**
```lua
loadSettings()       — reads settings.json → populates Settings table
saveSettings()       — writes Settings table → settings.json
applySettings()      — applies Settings to engine (fullscreen, vsync, volume)
```

**Settings table** (global):
```lua
Settings = {
    fullscreen = false,
    volume = 1.0,       -- 0.0 to 1.0
    framelimit = -1,    -- -1=VSync, 0=Unlimited, 30, 60, 120
}
```

### Save/Load System (game.lua)

**Save file:** `scripts/state.json`

```json
{"node": "5", "choices": [{"node": "4", "choice": "9"}]}
```

**API:**
```lua
ssave()     — saves current node + choice history (F3)
sload()     — loads state, rebuilds vn state, re-renders (F2)
```

**Save flow:**
1. Captures `vn.currentNode` and `vn.currentChoices`
2. Writes JSON to `scripts/state.json`
3. Shows "Saving..." notification for ~1s

**Load flow:**
1. Reads and parses `scripts/state.json`
2. Restores `vn.currentNode`, `vn.currentChoices`
3. Walks chain from start node to currentNode, accumulating bg/character/sound state
4. Calls `renderGame(currentUI)`

**Auto-load at game start:**
`initSload()` is called when entering the "gay" scene. If a save exists, it loads it. Otherwise, `ginit()` starts fresh.

---

## 13. Build System & Asset Pipeline

### Build Commands

```bash
make dev          # Debug build (-O0 -g)
make release      # Release build (-O3 -flto)
make shaders      # Compile shaders (.sc → .bin.h)
make clean        # Remove build artifacts
```

### Adding New Shaders

1. Create `src/shaders/vs_yours.sc` and `src/shaders/fs_yours.sc`
2. Run `make shaders` — compiles to `src/shaders/vs_yours.bin.h` and `fs_yours.bin.h`
3. `#include` the `.bin.h` files in your Gooner class
4. Reference with `bgfx::makeRef(vs_yours, sizeof(vs_yours))`

### Shader Format

bgfx shaders use the `.sc` format with `varying.def.sc` defining inter-stage varyings:

```
// varying.def.sc
vec3 v_color0  : COLOR0  = vec3(0.0, 0.0, 0.0, 0.0);
vec2 v_texcoord0 : TEXCOORD0 = vec2(0.0, 0.0);
```

### Adding New Assets

Place `.png`, `.jpg`, `.mp3`, `.ttf` files in `assets/`. They will be picked up by `preloadTextures("assets")` and `preloadSounds("assets")` at startup.

To add a new font, call from Lua:
```lua
local myFont = getTextGooner("assets/MyFont.ttf", 24)
```

Or set as default:
```lua
setFont("assets/MyFont.ttf", 24)
```

### Dependencies

| Library | Source | Type |
|---------|--------|------|
| bgfx | submodule (external/bgfx) + prebuilt libbgfx.a | STATIC IMPORTED |
| bimg | submodule (external/bimg) + prebuilt libbimg.a | STATIC IMPORTED |
| bx | submodule (external/bx) + prebuilt libbx.a | STATIC IMPORTED |
| SDL3 | submodule (external/SDL), built by CI | system/pkg-config |
| sol2 | submodule (external/sol2) | header-only |
| nlohmann/json | submodule (external/json) | header-only |
| tsfont | submodule (external/tsfont) | OBJECT library |
| Lua 5.4.8 | external/lua-5.4.8 (downloaded by CI) | STATIC |
| SoLoud | external/soloud20200207 (downloaded by CI) | STATIC |
| stb_image.h | external/stb_image.h | single-header |
| FreeType2 | system package | shared/static |

---

## 14. Best Practices & Patterns

### Adding a New Skibidi Element (Checklist)

1. Create Gooner class (if new shader is needed)
2. Add to Hell_Machina (member + getter)
3. Create Skibidi subclass
4. Add convenience method to Layer
5. Register usertype in ligma_bind
6. Add Layer method to Layer usertype
7. Add global getter function to ligma_bind

### Lua Scene Template

```lua
---@diagnostic disable: undefined-global, undefined-field
local g = {
    text = getTextGooner(),
    rect = getRectGooner(),
    image = getImageGooner(),
    audio = getAudioEngine(),
}

register("my_scene", function(ui)
    setFont("assets/HackRegular-gX84.ttf", 24)

    -- Background
    local bg = loadTexture("assets/background.png")
    if bg.idx ~= 65535 then
        ui:addImageF(g.image, bg, 0, 0, 1, 1, 0xffffffff, -1)
    end

    -- UI elements using fractional coordinates
    local btn = ui:addRectF(g.rect, 0.3, 0.3, 0.4, 0.07, 0xffffffff, 0)
    ui:addTextF(g.text, "Click Me", 0.35, 0.31, 0xff000000, 1)
    btn:onClick(function()
        print("Clicked!")
    end)
end)
```

### Font Management

- Default font is loaded with `setFont(path, size)`. Call this once per scene entry.
- Additional fonts can be loaded via `getTextGooner(path, size)` — they are cached.
- Use `TextGooner:measureText(text)` for word wrapping calculations.
- Line height = `pixelSize * 1.35`.

### Color Format

All colors are `uint32` in **ABGR** format: `0xAABBGGRR`.

```lua
0xffffffff    -- white
0xff000000    -- black
0xff101014    -- dark panel background
0xdd101014    -- semi-transparent dark panel (dd = 221 alpha)
0x00000000    -- fully transparent (invisible hitbox)
```

### Performance Considerations

- Minimize layer clears (`:clear()`) — they destroy all elements and force recreation
- Batch similar elements together (same texture, same shader)
- Preload assets at game start rather than loading during gameplay
- Font glyph atlases grow dynamically (512→2048 max); first render of new text may be slow
- Frame limiter uses busy-wait — set a reasonable limit (60 or 120) to avoid CPU waste

### Debugging

Lua errors are caught and printed to stderr:
- `"Lua click callback fuckup: ..."` — error in click handler
- `"Lua resize callback error: ..."` — error in onResize
- `"Lua onFrame error: ..."` — error in onFrame
- `"runtime e scripts/x.lua: ..."` — Lua runtime error

Built-in profiler in game.lua:
```lua
prof.start()
-- ... code ...
prof.mark("label")
-- ... more code ...
prof.flush()  -- prints deltas > 0.1ms
```
