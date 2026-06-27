#pragma once
#include <SDL3/SDL.h>
#include <SDL3/SDL_properties.h>
#include <algorithm>
#include <bgfx/bgfx.h>
#include <bx/math.h>
#include <bx/allocator.h>
#include <bx/error.h>
#include <bimg/decode.h>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <memory>
#include <stdexcept>
#include <string>
#include <string_view>
#include <array>
#include <algorithm>
#include <optional>
#include <vector>
#include "tsfont_wrapper.hpp"
#include "shaders/vs_text.bin.h"
#include "shaders/fs_text.bin.h"
#include "shaders/vs_rect.bin.h"
#include "shaders/fs_rect.bin.h"
#include "shaders/vs_image.bin.h"
#include "shaders/fs_image.bin.h"

inline bgfx::TextureHandle loadTexture(const char *path) {
    FILE *fp = std::fopen(path, "rb");
    if (!fp) return BGFX_INVALID_HANDLE;
    std::fseek(fp, 0, SEEK_END);
    long sz = std::ftell(fp);
    if (sz <= 0) { std::fclose(fp); return BGFX_INVALID_HANDLE; }
    auto buf = std::make_unique<uint8_t[]>(sz);
    std::fseek(fp, 0, SEEK_SET);
    if (std::fread(buf.get(), 1, sz, fp) != (size_t)sz) {
        std::fclose(fp); return BGFX_INVALID_HANDLE;
    }
    std::fclose(fp);

    // Try bimg (DDS, KTX, PVR3)
    bimg::ImageContainer img;
    bx::Error err;
    if (bimg::imageParse(img, buf.get(), (uint32_t)sz, &err)) {
        if (img.m_format != bimg::TextureFormat::RGBA8) {
            bx::DefaultAllocator alloc;
            auto *conv = bimg::imageConvert(&alloc, bimg::TextureFormat::RGBA8, img);
            if (conv) {
                bimg::imageFree(&img);
                auto mem = bgfx::copy(conv->m_data, conv->m_size);
                auto tex = bgfx::createTexture2D(
                    conv->m_width, conv->m_height, false, 1,
                    bgfx::TextureFormat::RGBA8, 0, mem);
                bimg::imageFree(conv);
                return tex;
            }
        }
        auto mem = bgfx::copy(img.m_data, img.m_size);
        auto tex = bgfx::createTexture2D(
            img.m_width, img.m_height, false, 1,
            bgfx::TextureFormat::RGBA8, 0, mem);
        bimg::imageFree(&img);
        return tex;
    }

    // Fallback: TGA (uncompressed true-color)
    if (sz < 18) return BGFX_INVALID_HANDLE;
    uint8_t idLen = buf[0];
    uint8_t cmapType = buf[1];
    uint8_t imgType = buf[2];
    if (cmapType != 0 || (imgType != 2 && imgType != 3)) return BGFX_INVALID_HANDLE;
    uint16_t w = (uint16_t)buf[12] | (uint16_t)buf[13] << 8;
    uint16_t h = (uint16_t)buf[14] | (uint16_t)buf[15] << 8;
    uint8_t bpp = buf[16];
    if (w == 0 || h == 0 || (bpp != 24 && bpp != 32)) return BGFX_INVALID_HANDLE;
    uint8_t desc = buf[17];
    bool topLeft = (desc & 0x20) != 0;

    uint32_t dataOff = 18 + idLen;
    uint32_t pixelBytes = (uint32_t)w * h * (bpp / 8);
    if (dataOff + pixelBytes > (uint32_t)sz) return BGFX_INVALID_HANDLE;

    auto rgba = std::make_unique<uint8_t[]>((uint32_t)w * h * 4);
    for (uint32_t y = 0; y < h; y++) {
        uint32_t srcY = topLeft ? y : (h - 1 - y);
        for (uint32_t x = 0; x < w; x++) {
            uint32_t si = dataOff + (srcY * w + x) * (bpp / 8);
            uint32_t di = (y * w + x) * 4;
            rgba[di + 2] = buf[si + 0]; // B → R
            rgba[di + 1] = buf[si + 1]; // G
            rgba[di + 0] = buf[si + 2]; // R → B
            rgba[di + 3] = (bpp == 32) ? buf[si + 3] : 255;
        }
    }

    auto mem = bgfx::copy(rgba.get(), (uint32_t)w * h * 4);
    return bgfx::createTexture2D(w, h, false, 1,
        bgfx::TextureFormat::RGBA8, 0, mem);
}

struct Kino {
    uint16_t id;
    bgfx::FrameBufferHandle fb;
    uint32_t clearFlags;
    uint32_t clearColor;
    uint16_t viewW = 0, viewH = 0;
    bool dirty = true;
    float ortho[16];
    bool useOrtho = false;

    void setViewport(uint16_t w, uint16_t h);
    void setOrtho(float left, float right, float bottom, float top);
    void begin();
};

struct DrawCmd {
    bgfx::TransientVertexBuffer tvb;
    bgfx::TransientIndexBuffer  tib;
    bgfx::ProgramHandle         program;
    bgfx::UniformHandle         texUniform;
    bgfx::TextureHandle         tex;
    uint64_t                    state;
};

class JohnPork {
    std::vector<DrawCmd> cmds;
public:
    void push(const DrawCmd &cmd) { cmds.push_back(cmd); }
    void flush(uint16_t viewId) {
        for (auto &cmd : cmds) {
            bgfx::setVertexBuffer(0, &cmd.tvb);
            bgfx::setIndexBuffer(&cmd.tib);
            if (bgfx::isValid(cmd.tex)) bgfx::setTexture(0, cmd.texUniform, cmd.tex);
            bgfx::setState(cmd.state);
            bgfx::submit(viewId, cmd.program);
        }
        cmds.clear();
    }
    void clear() { cmds.clear(); }
};

class Hell_Machina;

class TsFontHandler {
public:
  TsFontHandler() = default;
  ~TsFontHandler() { destroy(); }

  TsFontHandler(const TsFontHandler &) = delete;
  TsFontHandler &operator=(const TsFontHandler &) = delete;
  TsFontHandler(TsFontHandler &&other) noexcept : font(other.font) { other.font = nullptr; }
  TsFontHandler &operator=(TsFontHandler &&other) noexcept {
    if (this != &other) { destroy(); font = other.font; other.font = nullptr; }
    return *this;
  }

  bool load(const unsigned char *data, unsigned long len, float pixel_size) {
    destroy(); font = font_load(data, len, pixel_size); return font != nullptr;
  }

  bool loadFromFile(const char *path, float pixel_size) {
    FILE *fp = std::fopen(path, "rb");
    if (!fp) return false;
    std::fseek(fp, 0, SEEK_END);
    long sz = std::ftell(fp);
    if (sz <= 0) { std::fclose(fp); return false; }
    auto buf = std::make_unique<unsigned char[]>(sz);
    std::fseek(fp, 0, SEEK_SET);
    if (std::fread(buf.get(), 1, sz, fp) != (size_t)sz) { std::fclose(fp); return false; }
    std::fclose(fp);
    return load(buf.get(), sz, pixel_size);
  }

  void destroy() { if (font) { font_free(font); font = nullptr; } }

  float measureText(const char *utf8, unsigned long len) const {
    return font ? cock_measure(font, utf8, len) : 0.0f;
  }

  struct GlyphRun {
    std::vector<GlyphInfo> infos;
    std::vector<unsigned char> bitmap;
    int count = 0;
  };

  GlyphRun rasterize(const char *utf8, unsigned long len, int max_glyphs = 256) {
    GlyphRun result;
    if (!font || !utf8 || len == 0) return result;
    result.infos.resize(max_glyphs);
    unsigned char *bitmap_ptr = nullptr;
    unsigned long bitmap_size = 0;
    int n = font_fill_glyphs(font, utf8, len, result.infos.data(), max_glyphs,
                             &bitmap_ptr, &bitmap_size);
    if (n > 0) {
      result.count = n;
      result.infos.resize(n);
      if (bitmap_ptr && bitmap_size > 0)
        result.bitmap.assign(bitmap_ptr, bitmap_ptr + bitmap_size);
      free_bitmap_buffer(bitmap_ptr);
    } else {
      result.infos.clear();
    }
    return result;
  }

  bool isValid() const { return font != nullptr; }

private:
  void *font = nullptr;
};

class TextGooner;

class RectGooner {
    bgfx::ProgramHandle program;
    bgfx::VertexLayout layout;
public:
    bool init() {
        bgfx::ShaderHandle vsh = bgfx::createShader(bgfx::makeRef(vs_rect, sizeof(vs_rect)));
        bgfx::ShaderHandle fsh = bgfx::createShader(bgfx::makeRef(fs_rect, sizeof(fs_rect)));
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

class ImageGooner {
    bgfx::ProgramHandle program;
    bgfx::UniformHandle s_tex;
    bgfx::VertexLayout layout;
public:
    bool init() {
        bgfx::ShaderHandle vsh = bgfx::createShader(bgfx::makeRef(vs_image, sizeof(vs_image)));
        bgfx::ShaderHandle fsh = bgfx::createShader(bgfx::makeRef(fs_image, sizeof(fs_image)));
        program = bgfx::createProgram(vsh, fsh, true);

        s_tex = bgfx::createUniform("s_tex", bgfx::UniformType::Sampler);

        layout.begin()
            .add(bgfx::Attrib::Position,  2, bgfx::AttribType::Float)
            .add(bgfx::Attrib::TexCoord0, 2, bgfx::AttribType::Float)
            .add(bgfx::Attrib::Color0,    4, bgfx::AttribType::Uint8, true)
            .end();
        return true;
    }

    bgfx::ProgramHandle getProgram() const { return program; }
    bgfx::UniformHandle getSampler() const { return s_tex; }
    const bgfx::VertexLayout& getLayout() const { return layout; }

    void destroy() {
        if (bgfx::isValid(program)) bgfx::destroy(program);
        if (bgfx::isValid(s_tex))   bgfx::destroy(s_tex);
    }
};

class Skibidi {
public:
  Skibidi(std::string_view type, uint32_t zindex) : zindex(zindex), type(type) {}
  virtual ~Skibidi() {}
  virtual void Build() = 0;
  virtual void collect(JohnPork &pork) = 0;
  uint32_t zindex;
  bool visible = true;
protected:
  std::string type;
};

class TextGooner {
public:
  static constexpr uint32_t ATLAS_SIZE = 512;
  static constexpr int PADDING = 2;

  struct GlyphData {
    float u0, v0, u1, v1;
    float advance_x;
    float bearing_x, bearing_y;
    float width, height;
    bool loaded = false;
  };

  TextGooner() = default;
  ~TextGooner() { destroy(); }

  TextGooner(const TextGooner &) = delete;
  TextGooner &operator=(const TextGooner &) = delete;

  bool init(const char *fontPath, float pixelSize) {
    if (!fontHandler.loadFromFile(fontPath, pixelSize)) return false;

    std::string allChars;
    for (int c = 32; c < 128; c++) allChars += (char)c;

    auto run = fontHandler.rasterize(allChars.c_str(), allChars.size(), 128);
    if (run.count <= 0) return false;

    std::vector<uint8_t> atlasData(ATLAS_SIZE * ATLAS_SIZE, 0);
    int curX = PADDING;
    int curY = PADDING;
    int rowH = 0;

    for (int i = 0; i < run.count; i++) {
      auto &info = run.infos[i];
      int gw = info.bm_width;
      int gh = info.bm_rows;

      if (curX + gw + PADDING > (int)ATLAS_SIZE) {
        curX = PADDING;
        curY += rowH + PADDING;
        rowH = 0;
      }

      for (int row = 0; row < gh && curY + row < (int)ATLAS_SIZE; row++)
        std::memcpy(&atlasData[(curY + row) * ATLAS_SIZE + curX],
                     &run.bitmap[info.bm_offset + row * info.bm_pitch], gw);

      int c = info.codepoint;
      if (c >= 0 && c < 256) {
        auto &g = glyphs[c];
        g.u0 = (float)curX / ATLAS_SIZE;
        g.v0 = (float)curY / ATLAS_SIZE;
        g.u1 = (float)(curX + gw) / ATLAS_SIZE;
        g.v1 = (float)(curY + gh) / ATLAS_SIZE;
        g.advance_x  = info.adv_x;
        g.bearing_x  = info.br_x;
        g.bearing_y  = info.br_y;
        g.width  = (float)gw;
        g.height = (float)gh;
        g.loaded = true;
      }

      curX += gw + PADDING;
      if (gh > rowH) rowH = gh;
    }

    const bgfx::Memory *mem = bgfx::copy(atlasData.data(), ATLAS_SIZE * ATLAS_SIZE);
    atlas = bgfx::createTexture2D(ATLAS_SIZE, ATLAS_SIZE, false, 1,
      bgfx::TextureFormat::R8, 0, mem);

    bgfx::ShaderHandle vsh = bgfx::createShader(bgfx::makeRef(vs_text, sizeof(vs_text)));
    bgfx::ShaderHandle fsh = bgfx::createShader(bgfx::makeRef(fs_text, sizeof(fs_text)));
    program = bgfx::createProgram(vsh, fsh, true);

    s_tex = bgfx::createUniform("s_tex", bgfx::UniformType::Sampler);

    layout.begin()
      .add(bgfx::Attrib::Position,  2, bgfx::AttribType::Float)
      .add(bgfx::Attrib::TexCoord0, 2, bgfx::AttribType::Float)
      .add(bgfx::Attrib::Color0,    4, bgfx::AttribType::Uint8, true)
      .end();

    return true;
  }

  const bgfx::VertexLayout& getLayout() const { return layout; }
  const GlyphData* getGlyphs() const { return glyphs.data(); }
  bgfx::TextureHandle getAtlas() const { return atlas; }
  bgfx::ProgramHandle getProgram() const { return program; }
  bgfx::UniformHandle getSampler() const { return s_tex; }

  void destroy() {
    if (bgfx::isValid(atlas))   bgfx::destroy(atlas);
    if (bgfx::isValid(program)) bgfx::destroy(program);
    if (bgfx::isValid(s_tex))   bgfx::destroy(s_tex);
    fontHandler.destroy();
  }

private:
  TsFontHandler fontHandler;
  bgfx::TextureHandle atlas  = BGFX_INVALID_HANDLE;
  bgfx::ProgramHandle program = BGFX_INVALID_HANDLE;
  bgfx::UniformHandle s_tex   = BGFX_INVALID_HANDLE;
  bgfx::VertexLayout layout;
  std::array<GlyphData, 256> glyphs{};
};

class Text : public Skibidi {
public:
  Text(TextGooner &gooner, std::string_view text, float x, float y, uint32_t color, uint32_t zindex)
  : Skibidi("text", zindex), gooner(gooner), text(text), x(x), y(y), color(color) {}
  void Build() override {}

  void collect(JohnPork &pork) override {
    if (!visible || text.empty()) return;

    struct Vertex { float x, y, u, v; uint32_t color; };

    auto *glyphs = gooner.getGlyphs();
    auto &layout = gooner.getLayout();

    int len = (int)text.size();
    int quads = 0;
    for (int i = 0; i < len; i++) {
      unsigned char c = (unsigned char)text[i];
      if (c >= 32 && c < 128 && glyphs[c].loaded) quads++;
    }
    if (quads == 0) return;

    bgfx::TransientVertexBuffer tvb;
    bgfx::TransientIndexBuffer tib;
    if (!bgfx::allocTransientBuffers(&tvb, layout, quads * 4, &tib, quads * 6))
      return;

    auto *vert = (Vertex *)tvb.data;
    float penX = x;

    for (int i = 0; i < len; i++) {
      unsigned char c = (unsigned char)text[i];
      if (c < 32 || c >= 128 || !glyphs[c].loaded) continue;

      auto &g = glyphs[c];
      float x0 = penX + g.bearing_x;
      float y0 = y - g.bearing_y;
      float x1 = x0 + g.width;
      float y1 = y0 + g.height;

      vert[0] = {x0, y0, g.u0, g.v0, color};
      vert[1] = {x1, y0, g.u1, g.v0, color};
      vert[2] = {x1, y1, g.u1, g.v1, color};
      vert[3] = {x0, y1, g.u0, g.v1, color};
      vert += 4;
      penX += g.advance_x;
    }

    auto *idx = (uint16_t *)tib.data;
    for (int i = 0; i < quads; i++) {
      uint16_t base = (uint16_t)(i * 4);
      idx[0] = base;     idx[1] = base + 2; idx[2] = base + 1;
      idx[3] = base;     idx[4] = base + 3; idx[5] = base + 2;
      idx += 6;
    }

    DrawCmd cmd;
    cmd.tvb = tvb;
    cmd.tib = tib;
    cmd.program = gooner.getProgram();
    cmd.texUniform = gooner.getSampler();
    cmd.tex = gooner.getAtlas();
    cmd.state = BGFX_STATE_WRITE_RGB | BGFX_STATE_WRITE_A | BGFX_STATE_BLEND_ALPHA;
    pork.push(cmd);
  }

private:
  TextGooner &gooner;
  std::string text;
  float x, y;
  uint32_t color;
};

class Rectangle : public Skibidi {
    RectGooner &gooner;
    float x, y, w, h;
    uint32_t color;
public:
    Rectangle(RectGooner &gooner, float x, float y, float w, float h, uint32_t color, uint32_t zindex)
    : Skibidi("rect", zindex), gooner(gooner), x(x), y(y), w(w), h(h), color(color) {}

    void Build() override {}

    void collect(JohnPork &pork) override {
        struct Vertex { float x, y; uint32_t color; };

        bgfx::TransientVertexBuffer tvb;
        bgfx::TransientIndexBuffer tib;
        if (!bgfx::allocTransientBuffers(&tvb, gooner.getLayout(), 4, &tib, 6))
            return;

        auto *vert = (Vertex *)tvb.data;
        vert[0] = {x,     y,      color};
        vert[1] = {x + w, y,      color};
        vert[2] = {x + w, y + h,  color};
        vert[3] = {x,     y + h,  color};

        auto *idx = (uint16_t *)tib.data;
        idx[0] = 0; idx[1] = 1; idx[2] = 2;
        idx[3] = 0; idx[4] = 2; idx[5] = 3;

        DrawCmd cmd;
        cmd.tvb = tvb;
        cmd.tib = tib;
        cmd.program = gooner.getProgram();
        cmd.texUniform = BGFX_INVALID_HANDLE;
        cmd.tex = BGFX_INVALID_HANDLE;
        cmd.state = BGFX_STATE_WRITE_RGB | BGFX_STATE_WRITE_A | BGFX_STATE_BLEND_ALPHA;
        pork.push(cmd);
    }
};

class Image : public Skibidi {
    ImageGooner &gooner;
    bgfx::TextureHandle tex;
    float x, y, w, h;
    uint32_t color;
public:
    Image(ImageGooner &gooner, bgfx::TextureHandle tex, float x, float y, float w, float h, uint32_t color, uint32_t zindex)
    : Skibidi("image", zindex), gooner(gooner), tex(tex), x(x), y(y), w(w), h(h), color(color) {}

    void Build() override {}

    void collect(JohnPork &pork) override {
        struct Vertex { float x, y, u, v; uint32_t color; };

        bgfx::TransientVertexBuffer tvb;
        bgfx::TransientIndexBuffer tib;
        if (!bgfx::allocTransientBuffers(&tvb, gooner.getLayout(), 4, &tib, 6))
            return;

        auto *vert = (Vertex *)tvb.data;
        vert[0] = {x,     y,      0, 0, color};
        vert[1] = {x + w, y,      1, 0, color};
        vert[2] = {x + w, y + h,  1, 1, color};
        vert[3] = {x,     y + h,  0, 1, color};

        auto *idx = (uint16_t *)tib.data;
        idx[0] = 0; idx[1] = 1; idx[2] = 2;
        idx[3] = 0; idx[4] = 2; idx[5] = 3;

        DrawCmd cmd;
        cmd.tvb = tvb;
        cmd.tib = tib;
        cmd.program = gooner.getProgram();
        cmd.texUniform = gooner.getSampler();
        cmd.tex = tex;
        cmd.state = BGFX_STATE_WRITE_RGB | BGFX_STATE_WRITE_A | BGFX_STATE_BLEND_ALPHA;
        pork.push(cmd);
    }
};

struct Layer {
  std::string name;
  bool visible = true;
  std::vector<std::unique_ptr<Skibidi>> items;

  template<typename T, typename... Args>
  requires std::derived_from<T, Skibidi>
  T* add(Args&&... args) {
    auto obj = std::make_unique<T>(std::forward<Args>(args)...);
    T* raw = obj.get();
    raw->Build();
    items.push_back(std::move(obj));
    return raw;
  }

  void collect(JohnPork &pork) {
    if (!visible) return;
    std::sort(items.begin(), items.end(), [](auto &a, auto &b) { return a->zindex < b->zindex; });
    for (auto &item : items)
      if (item->visible)
        item->collect(pork);
  }
};

class Sigma {
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

  static Sigma skid(std::string_view title, int x, int y) {
    if (!SDL_Init(SDL_INIT_VIDEO))
      throw std::runtime_error(std::string("SDL_Init: ") + SDL_GetError());

    SDL_Window *buzz = SDL_CreateWindow(title.data(), x, y, 0);
    if (!buzz) {
      SDL_Quit();
      throw std::runtime_error("SDL_CreateWindow: " + std::string(SDL_GetError()));
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

class Amogus {
private:
  SDL_Window *buzz = nullptr;
  int x, y;
  bgfx::RendererType::Enum goonerType;

  Amogus(SDL_Window* buzz, int x, int y, bgfx::RendererType::Enum goonerType)
  : buzz(buzz), x(x), y(y), goonerType(goonerType) {}
public:
  ~Amogus() {if (buzz) bgfx::shutdown();}

  static Amogus rizzing(SDL_Window *buzz, int w, int h, bgfx::RendererType::Enum goonerType) {
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
          throw std::runtime_error("no wayland or x11 props");
        }
      }

      bgfx::Init init;
      init.type = goonerType;
      init.resolution.width = w;
      init.resolution.height = h;
      init.resolution.reset = BGFX_RESET_VSYNC;
      init.platformData = pld;

      if (!bgfx::init(init))
        throw std::runtime_error("bgfx::init edged");

      bgfx::setViewClear(0, BGFX_CLEAR_COLOR | BGFX_CLEAR_DEPTH, 0x000000ff, 1.0f, 0);
      bgfx::setViewRect(0, 0, 0, w, h);

      return Amogus(buzz, w, h, goonerType);
  }

  void frame() {bgfx::touch(0); bgfx::frame();}
  void resize(int w, int h) {
    bgfx::reset(w, h, BGFX_RESET_VSYNC);
    bgfx::setViewRect(0, 0, 0, (uint16_t)w, (uint16_t)h);
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

class Hell_Machina {
    std::optional<Sigma> sigma;
    std::optional<Amogus> amogus;
    Kino scenePass;
    Kino uiPass;
    TextGooner textGooner;
    RectGooner rectGooner;
    ImageGooner imageGooner;
    std::vector<Layer> sceneLayers;
    std::vector<Layer> uiLayers;
public:
    Hell_Machina() = default;

    void init(const char *title, int w, int h, bgfx::RendererType::Enum renderer);
    void frame();
    void resize(int w, int h);

    Layer& addSceneLayer(const char *name);
    Layer& addUILayer(const char *name);
    TextGooner& getTextGooner() { return textGooner; }
    RectGooner& getRectGooner() { return rectGooner; }
    ImageGooner& getImageGooner() { return imageGooner; }
};
