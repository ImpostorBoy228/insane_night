#pragma once
// NOLINTBEGIN(readability-identifier-length,bugprone-narrowing-conversions,performance-noexcept-move-constructor)
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
#include <functional>
#include <chrono>
#include <cstring>
#include <deque>
#include <limits>
#include <memory>
#include <stdexcept>
#include <string>
#include <string_view>

#include <algorithm>
#include <cmath>
#include <optional>
#include <vector>
#include <unordered_map>
#include <unordered_set>
#include "tsfont_wrapper.hpp"
#include "audio_unc.hpp"
#include "stb_image.h"
#include "shaders/vs_text.bin.h"
#include "shaders/fs_text.bin.h"
#include "shaders/vs_rect.bin.h"
#include "shaders/fs_rect.bin.h"
#include "shaders/vs_image.bin.h"
#include "shaders/fs_image.bin.h"

//static bool fuckCpp = true;

inline bgfx::TextureHandle loadTextureUncached(const char *path) {
    int w, h, n;
    stbi_uc *data = stbi_load(path, &w, &h, &n, STBI_rgb_alpha);
    if (data) {
        auto mem = bgfx::copy(data, (uint32_t)(w * h * 4));
        stbi_image_free(data);
        return bgfx::createTexture2D((uint16_t)w, (uint16_t)h, false, 1,
            bgfx::TextureFormat::RGBA8, 0, mem);
    }

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
    return BGFX_INVALID_HANDLE;
}

struct StringViewHash {
    using is_transparent = void;

    size_t operator()(std::string_view value) const noexcept {
        return std::hash<std::string_view>{}(value);
    }

    size_t operator()(const char *value) const noexcept {
        return value ? (*this)(std::string_view(value)) : 0u;
    }
};

struct StringViewEqual {
    using is_transparent = void;

    bool operator()(std::string_view lhs, std::string_view rhs) const noexcept {
        return lhs == rhs;
    }

    bool operator()(const char *lhs, std::string_view rhs) const noexcept {
        return lhs != nullptr && std::string_view(lhs) == rhs;
    }

    bool operator()(std::string_view lhs, const char *rhs) const noexcept {
        return rhs != nullptr && lhs == std::string_view(rhs);
    }
};

struct CachedTexture {
    bgfx::TextureHandle handle;
    int width = 0;
    int height = 0;
};

class CacheMan {
    std::deque<std::string> texturePaths;
    std::unordered_map<std::string_view, CachedTexture, StringViewHash, StringViewEqual> textures;
public:
    CacheMan() = default;
    ~CacheMan() { destroy(); }

    CacheMan(const CacheMan &) = delete;
    CacheMan &operator=(const CacheMan &) = delete;
    CacheMan(CacheMan &&) = delete;
    CacheMan &operator=(CacheMan &&) = delete;

    bgfx::TextureHandle loadTexture(const char *path, int *outW = nullptr, int *outH = nullptr) {
        if (!path || *path == '\0') return BGFX_INVALID_HANDLE;

        auto it = textures.find(std::string_view(path));
        if (it != textures.end() && bgfx::isValid(it->second.handle)) {
            if (outW) *outW = it->second.width;
            if (outH) *outH = it->second.height;
            return it->second.handle;
        }

        bgfx::TextureHandle tex = loadTextureUncached(path);
        if (bgfx::isValid(tex)) {
            texturePaths.emplace_back(path);
            std::string_view key = texturePaths.back();
            CachedTexture ct;
            ct.handle = tex;

            int w, h, n;
            stbi_uc *data = stbi_load(path, &w, &h, &n, STBI_rgb_alpha);
            if (data) {
                ct.width = w;
                ct.height = h;
                stbi_image_free(data);
            }

            textures.emplace(key, ct);
            if (outW) *outW = ct.width;
            if (outH) *outH = ct.height;
        }
        return tex;
    }

    int getWidth(const char *path) {
        if (!path) return 0;
        auto it = textures.find(std::string_view(path));
        if (it != textures.end()) return it->second.width;
        loadTexture(path, nullptr, nullptr);
        it = textures.find(std::string_view(path));
        return it != textures.end() ? it->second.width : 0;
    }

    int getHeight(const char *path) {
        if (!path) return 0;
        auto it = textures.find(std::string_view(path));
        if (it != textures.end()) return it->second.height;
        loadTexture(path, nullptr, nullptr);
        it = textures.find(std::string_view(path));
        return it != textures.end() ? it->second.height : 0;
    }

    void destroy() {
        for (auto &[path, ct] : textures) {
            (void)path;
            if (bgfx::isValid(ct.handle)) {
                bgfx::destroy(ct.handle);
            }
        }
        textures.clear();
        texturePaths.clear();
    }
};

struct Kino {
    uint16_t id;
    bgfx::FrameBufferHandle fb;
    uint32_t clearFlags;
    uint32_t clearColor;
    uint16_t viewX = 0, viewY = 0, viewW = 0, viewH = 0;
    bool dirty = true;
    float ortho[16];
    bool useOrtho = false;

    void setViewport(uint16_t w, uint16_t h);
    void setViewport(uint16_t x, uint16_t y, uint16_t w, uint16_t h);
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
    uint32_t                    samplerFlags = BGFX_SAMPLER_NONE;
};

class JohnPork {
    std::vector<DrawCmd> cmds;
public:
    void reserve(size_t count) {
        if (cmds.capacity() < count) cmds.reserve(count);
    }

    void push(const DrawCmd &cmd) { cmds.push_back(cmd); }
    void flush(uint16_t viewId) {
        for (auto &cmd : cmds) {
            bgfx::setVertexBuffer(0, &cmd.tvb);
            bgfx::setIndexBuffer(&cmd.tib);
            if (bgfx::isValid(cmd.tex)) bgfx::setTexture(0, cmd.texUniform, cmd.tex, cmd.samplerFlags);
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
  TsFontHandler(TsFontHandler &&other) noexcept
      : font(other.font), fontBytes(std::move(other.fontBytes)) {
    other.font = nullptr;
  }
  TsFontHandler &operator=(TsFontHandler &&other) noexcept {
    if (this != &other) {
      destroy();
      font = other.font;
      fontBytes = std::move(other.fontBytes);
      other.font = nullptr;
    }
    return *this;
  }

  bool load(const unsigned char *data, unsigned long len, float pixel_size) {
    destroy();
    if (!data || len == 0) return false;
    fontBytes.assign(data, data + len);
    font = font_load(fontBytes.data(), fontBytes.size(), pixel_size);
    if (!font) {
      fontBytes.clear();
      return false;
    }
    return true;
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
    return load(buf.get(), static_cast<unsigned long>(sz), pixel_size);
  }

  void destroy() {
    if (font) {
      font_free(font);
      font = nullptr;
    }
    fontBytes.clear();
  }

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
  std::vector<unsigned char> fontBytes;
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
  Skibidi(std::string_view type, int32_t zindex) : zindex(zindex), type(type) {}
  virtual ~Skibidi() {}
  virtual void Build() = 0;
  virtual void collect(JohnPork &pork) = 0;
  virtual void onResize([[maybe_unused]] int pw, [[maybe_unused]] int ph) {}

  int32_t zindex;
  bool visible = true;

  std::function<void()> onClick;
  float hitX = 0, hitY = 0, hitW = 0, hitH = 0;

  void setHitbox(float x, float y, float w, float h) {
    hitX = x; hitY = y; hitW = w; hitH = h;
  }
  bool hitTest(float mx, float my) const {
    return mx >= hitX && mx < hitX + hitW && my >= hitY && my < hitY + hitH;
  }

  bool hasFrac = false;
  float frx = 0, fry = 0, frw = 0, frh = 0;
  void setFrac(float rx, float ry, float rw, float rh) {
    hasFrac = true;
    frx = rx; fry = ry; frw = rw; frh = rh;
  }
protected:
  std::string type;
};

inline uint32_t decodeUtf8Codepoint(const char *&ptr, const char *end) {
  if (ptr >= end) return 0;

  const unsigned char *s = reinterpret_cast<const unsigned char *>(ptr);
  const unsigned char *finish = reinterpret_cast<const unsigned char *>(end);

  if ((s[0] & 0x80u) == 0) {
    ptr += 1;
    return s[0];
  }
  if ((s[0] & 0xE0u) == 0xC0u && s + 1 < finish) {
    uint32_t cp = ((s[0] & 0x1Fu) << 6) | (s[1] & 0x3Fu);
    ptr += 2;
    return cp;
  }
  if ((s[0] & 0xF0u) == 0xE0u && s + 2 < finish) {
    uint32_t cp = ((s[0] & 0x0Fu) << 12) | ((s[1] & 0x3Fu) << 6) | (s[2] & 0x3Fu);
    ptr += 3;
    return cp;
  }
  if ((s[0] & 0xF8u) == 0xF0u && s + 3 < finish) {
    uint32_t cp = ((s[0] & 0x07u) << 18) | ((s[1] & 0x3Fu) << 12) |
                  ((s[2] & 0x3Fu) << 6) | (s[3] & 0x3Fu);
    ptr += 4;
    return cp;
  }

  ptr += 1;
  return 0xFFFD;
}

inline void appendUtf8Codepoint(std::string &out, uint32_t codepoint) {
  if (codepoint <= 0x7Fu) {
    out.push_back(static_cast<char>(codepoint));
  } else if (codepoint <= 0x7FFu) {
    out.push_back(static_cast<char>(0xC0u | (codepoint >> 6)));
    out.push_back(static_cast<char>(0x80u | (codepoint & 0x3Fu)));
  } else if (codepoint <= 0xFFFFu) {
    out.push_back(static_cast<char>(0xE0u | (codepoint >> 12)));
    out.push_back(static_cast<char>(0x80u | ((codepoint >> 6) & 0x3Fu)));
    out.push_back(static_cast<char>(0x80u | (codepoint & 0x3Fu)));
  } else {
    out.push_back(static_cast<char>(0xF0u | (codepoint >> 18)));
    out.push_back(static_cast<char>(0x80u | ((codepoint >> 12) & 0x3Fu)));
    out.push_back(static_cast<char>(0x80u | ((codepoint >> 6) & 0x3Fu)));
    out.push_back(static_cast<char>(0x80u | (codepoint & 0x3Fu)));
  }
}

class TextGooner {
public:
  static constexpr uint32_t INITIAL_ATLAS_SIZE = 512;
  static constexpr uint32_t MAX_ATLAS_SIZE = 2048;
  static constexpr int PADDING = 2;
  float maxBearingY = 0;
  float pixelSize = 0.0f;

  struct GlyphData {
    uint16_t atlasX = 0;
    uint16_t atlasY = 0;
    float u0 = 0.0f, v0 = 0.0f, u1 = 0.0f, v1 = 0.0f;
    float advance_x = 0.0f;
    float bearing_x = 0.0f, bearing_y = 0.0f;
    float width = 0.0f, height = 0.0f;
    bool loaded = false;
  };

  TextGooner() = default;
  ~TextGooner() { destroy(); }

  TextGooner(const TextGooner &) = delete;
  TextGooner &operator=(const TextGooner &) = delete;

  bool init(const char *fontPath, float pixelSizeValue) {
    destroy();
    atlas = BGFX_INVALID_HANDLE;
    program = BGFX_INVALID_HANDLE;
    s_tex = BGFX_INVALID_HANDLE;
    atlasSize = INITIAL_ATLAS_SIZE;
    atlasCursorX = PADDING;
    atlasCursorY = PADDING;
    atlasRowH = 0;
    atlasRevision = 0;
    maxBearingY = 0;
    pixelSize = pixelSizeValue;
    glyphs.clear();
    packedGlyphs.clear();
    atlasPixels.clear();

    if (!fontHandler.loadFromFile(fontPath, pixelSizeValue)) return false;

    bgfx::ShaderHandle vsh = bgfx::createShader(bgfx::makeRef(vs_text, sizeof(vs_text)));
    bgfx::ShaderHandle fsh = bgfx::createShader(bgfx::makeRef(fs_text, sizeof(fs_text)));
    program = bgfx::createProgram(vsh, fsh, true);

    s_tex = bgfx::createUniform("s_tex", bgfx::UniformType::Sampler);

    layout.begin()
      .add(bgfx::Attrib::Position,  2, bgfx::AttribType::Float)
      .add(bgfx::Attrib::TexCoord0, 2, bgfx::AttribType::Float)
      .add(bgfx::Attrib::Color0,    4, bgfx::AttribType::Uint8, true)
      .end();

    return createAtlas(INITIAL_ATLAS_SIZE);
  }

  bool ensureGlyphs(std::string_view text) {
    if (!fontHandler.isValid()) return false;

    std::vector<uint32_t> missing;
    std::unordered_set<uint32_t> seen;
    const char *ptr = text.data();
    const char *end = ptr + text.size();
    while (ptr < end) {
      uint32_t codepoint = decodeUtf8Codepoint(ptr, end);
      if (codepoint == '\n' || codepoint == '\r') continue;
      if (seen.insert(codepoint).second && glyphs.find(codepoint) == glyphs.end()) {
        missing.push_back(codepoint);
      }
    }

    if (missing.empty()) return true;
    return appendGlyphs(missing);
  }

  const bgfx::VertexLayout& getLayout() const { return layout; }
  const GlyphData* getGlyph(uint32_t codepoint) const {
    auto it = glyphs.find(codepoint);
    return it == glyphs.end() ? nullptr : &it->second;
  }
  float measureText(std::string_view text) const {
    return fontHandler.measureText(text.data(), static_cast<unsigned long>(text.size()));
  }
  float getLineHeight() const {
    if (pixelSize > 0.0f) return pixelSize * 1.35f;
    if (maxBearingY > 0.0f) return maxBearingY * 1.35f;
    return 24.0f;
  }
  float getTextMaxBearingY(std::string_view text) const {
    float textMaxBearingY = 0.0f;
    const char *ptr = text.data();
    const char *end = ptr + text.size();
    while (ptr < end) {
      uint32_t codepoint = decodeUtf8Codepoint(ptr, end);
      if (codepoint == '\n' || codepoint == '\r') continue;
      const auto *glyph = getGlyph(codepoint);
      if (glyph && glyph->loaded && glyph->bearing_y > textMaxBearingY) {
        textMaxBearingY = glyph->bearing_y;
      }
    }
    return textMaxBearingY;
  }
  bgfx::TextureHandle getAtlas() const { return atlas; }
  bgfx::ProgramHandle getProgram() const { return program; }
  bgfx::UniformHandle getSampler() const { return s_tex; }
  uint64_t getAtlasRevision() const { return atlasRevision; }

  void destroy() {
    if (bgfx::isValid(atlas)) bgfx::destroy(atlas);
    if (bgfx::isValid(program)) bgfx::destroy(program);
    if (bgfx::isValid(s_tex)) bgfx::destroy(s_tex);
    atlas = BGFX_INVALID_HANDLE;
    program = BGFX_INVALID_HANDLE;
    s_tex = BGFX_INVALID_HANDLE;
    fontHandler.destroy();
    glyphs.clear();
    packedGlyphs.clear();
    atlasPixels.clear();
    atlasSize = INITIAL_ATLAS_SIZE;
    atlasCursorX = PADDING;
    atlasCursorY = PADDING;
    atlasRowH = 0;
    atlasRevision = 0;
    maxBearingY = 0;
    pixelSize = 0.0f;
  }
  float getMaxBearingY() const { return maxBearingY; }

private:
  void updateGlyphUvs() {
    if (atlasSize == 0) return;

    const float invAtlasSize = 1.0f / static_cast<float>(atlasSize);
    for (auto &[codepoint, glyph] : glyphs) {
      (void)codepoint;
      if (!glyph.loaded || glyph.width <= 0.0f || glyph.height <= 0.0f) {
        glyph.u0 = 0.0f;
        glyph.v0 = 0.0f;
        glyph.u1 = 0.0f;
        glyph.v1 = 0.0f;
        continue;
      }

      glyph.u0 = static_cast<float>(glyph.atlasX) * invAtlasSize;
      glyph.v0 = static_cast<float>(glyph.atlasY) * invAtlasSize;
      glyph.u1 = static_cast<float>(glyph.atlasX + static_cast<uint16_t>(glyph.width)) * invAtlasSize;
      glyph.v1 = static_cast<float>(glyph.atlasY + static_cast<uint16_t>(glyph.height)) * invAtlasSize;
    }
  }

  bool uploadFullAtlas() {
    if (!bgfx::isValid(atlas) || atlasPixels.empty()) return false;

    const bgfx::Memory *mem = bgfx::copy(atlasPixels.data(), static_cast<uint32_t>(atlasPixels.size()));
    bgfx::updateTexture2D(atlas, 0, 0, 0, 0, static_cast<uint16_t>(atlasSize),
                          static_cast<uint16_t>(atlasSize), mem, static_cast<uint16_t>(atlasSize));
    return true;
  }

  bool uploadAtlasRegion(uint32_t minX, uint32_t minY, uint32_t maxX, uint32_t maxY) {
    if (!bgfx::isValid(atlas) || minX >= maxX || minY >= maxY) return true;

    const uint32_t width = maxX - minX;
    const uint32_t height = maxY - minY;
    std::vector<uint8_t> region(width * height);
    for (uint32_t row = 0; row < height; ++row) {
      std::memcpy(region.data() + row * width,
                  atlasPixels.data() + (minY + row) * atlasSize + minX,
                  width);
    }

    const bgfx::Memory *mem = bgfx::copy(region.data(), static_cast<uint32_t>(region.size()));
    bgfx::updateTexture2D(atlas, 0, 0, static_cast<uint16_t>(minX), static_cast<uint16_t>(minY),
                          static_cast<uint16_t>(width), static_cast<uint16_t>(height),
                          mem, static_cast<uint16_t>(width));
    return true;
  }

  bool recreateAtlasTexture(uint32_t newSize) {
    bgfx::TextureHandle newAtlas = bgfx::createTexture2D(
        static_cast<uint16_t>(newSize), static_cast<uint16_t>(newSize), false, 1,
        bgfx::TextureFormat::R8);
    if (!bgfx::isValid(newAtlas)) return false;

    if (bgfx::isValid(atlas)) bgfx::destroy(atlas);
    atlas = newAtlas;
    atlasSize = newSize;
    updateGlyphUvs();
    ++atlasRevision;
    return uploadFullAtlas();
  }

  bool createAtlas(uint32_t size) {
    atlasPixels.assign(size * size, 0);
    atlasCursorX = PADDING;
    atlasCursorY = PADDING;
    atlasRowH = 0;
    return recreateAtlasTexture(size);
  }

  bool growAtlasToFit(int glyphWidth, int glyphHeight) {
    uint32_t newSize = atlasSize;
    while (true) {
      if (newSize >= MAX_ATLAS_SIZE) return false;
      newSize = std::min(newSize * 2, MAX_ATLAS_SIZE);

      int testY = atlasCursorY;
      if (atlasCursorX + glyphWidth + PADDING > static_cast<int>(newSize)) {
        testY += atlasRowH + PADDING;
      }
      if (testY + glyphHeight + PADDING <= static_cast<int>(newSize)) break;
    }

    std::vector<uint8_t> newPixels(newSize * newSize, 0);
    for (uint32_t row = 0; row < atlasSize; ++row) {
      std::memcpy(newPixels.data() + row * newSize,
                  atlasPixels.data() + row * atlasSize,
                  atlasSize);
    }

    atlasPixels.swap(newPixels);
    return recreateAtlasTexture(newSize);
  }

  bool ensureSpace(int glyphWidth, int glyphHeight) {
    if (glyphWidth <= 0 || glyphHeight <= 0) return true;

    while (true) {
      if (atlasCursorX + glyphWidth + PADDING > static_cast<int>(atlasSize)) {
        atlasCursorX = PADDING;
        atlasCursorY += atlasRowH + PADDING;
        atlasRowH = 0;
      }

      if (atlasCursorY + glyphHeight + PADDING <= static_cast<int>(atlasSize)) {
        return true;
      }

      if (!growAtlasToFit(glyphWidth, glyphHeight)) return false;
    }
  }

  bool appendGlyphs(const std::vector<uint32_t> &requestedGlyphs) {
    std::vector<uint32_t> uniqueGlyphs;
    uniqueGlyphs.reserve(requestedGlyphs.size());
    std::unordered_set<uint32_t> seen;
    for (uint32_t codepoint : requestedGlyphs) {
      if (glyphs.find(codepoint) != glyphs.end()) continue;
      if (seen.insert(codepoint).second) uniqueGlyphs.push_back(codepoint);
    }
    if (uniqueGlyphs.empty()) return true;

    std::string utf8;
    utf8.reserve(uniqueGlyphs.size() * 4);
    for (uint32_t codepoint : uniqueGlyphs) appendUtf8Codepoint(utf8, codepoint);

    TsFontHandler::GlyphRun run = fontHandler.rasterize(
        utf8.c_str(), static_cast<unsigned long>(utf8.size()), static_cast<int>(uniqueGlyphs.size()));
    if (run.count <= 0) return false;

    uint32_t dirtyMinX = atlasSize;
    uint32_t dirtyMinY = atlasSize;
    uint32_t dirtyMaxX = 0;
    uint32_t dirtyMaxY = 0;
    bool hasDirtyPixels = false;

    for (int i = 0; i < run.count; ++i) {
      const auto &info = run.infos[i];
      GlyphData glyph;
      glyph.advance_x = info.adv_x;
      glyph.bearing_x = info.br_x;
      glyph.bearing_y = info.br_y;
      glyph.width = static_cast<float>(info.bm_width);
      glyph.height = static_cast<float>(info.bm_rows);
      glyph.loaded = true;

      if (info.br_y > maxBearingY) maxBearingY = info.br_y;

      if (info.bm_width > 0 && info.bm_rows > 0) {
        if (!ensureSpace(info.bm_width, info.bm_rows)) return false;

        glyph.atlasX = static_cast<uint16_t>(atlasCursorX);
        glyph.atlasY = static_cast<uint16_t>(atlasCursorY);

        for (int row = 0; row < info.bm_rows; ++row) {
          std::memcpy(atlasPixels.data() + (atlasCursorY + row) * atlasSize + atlasCursorX,
                      run.bitmap.data() + info.bm_offset + row * info.bm_pitch,
                      static_cast<size_t>(info.bm_width));
        }

        dirtyMinX = std::min(dirtyMinX, static_cast<uint32_t>(glyph.atlasX));
        dirtyMinY = std::min(dirtyMinY, static_cast<uint32_t>(glyph.atlasY));
        dirtyMaxX = std::max(dirtyMaxX, static_cast<uint32_t>(glyph.atlasX) + static_cast<uint32_t>(info.bm_width));
        dirtyMaxY = std::max(dirtyMaxY, static_cast<uint32_t>(glyph.atlasY) + static_cast<uint32_t>(info.bm_rows));
        hasDirtyPixels = true;

        atlasCursorX += info.bm_width + PADDING;
        atlasRowH = std::max(atlasRowH, info.bm_rows);
      }

      glyphs[info.codepoint] = glyph;
      packedGlyphs.push_back(info.codepoint);
    }

    updateGlyphUvs();
    if (hasDirtyPixels) {
      return uploadAtlasRegion(dirtyMinX, dirtyMinY, dirtyMaxX, dirtyMaxY);
    }
    return true;
  }

  TsFontHandler fontHandler;
  bgfx::TextureHandle atlas = BGFX_INVALID_HANDLE;
  bgfx::ProgramHandle program = BGFX_INVALID_HANDLE;
  bgfx::UniformHandle s_tex = BGFX_INVALID_HANDLE;
  bgfx::VertexLayout layout;
  std::unordered_map<uint32_t, GlyphData> glyphs;
  std::vector<uint32_t> packedGlyphs;
  std::vector<uint8_t> atlasPixels;
  uint32_t atlasSize = INITIAL_ATLAS_SIZE;
  int atlasCursorX = PADDING;
  int atlasCursorY = PADDING;
  int atlasRowH = 0;
  uint64_t atlasRevision = 0;
};

class Text : public Skibidi {
public:
  struct Vertex {
    float x, y, u, v;
    uint32_t color;
  };

  Text(TextGooner &gooner, std::string_view text, float x, float y, uint32_t color, int32_t zindex)
  : Skibidi("text", zindex), gooner(gooner), text(text), x(x), y(y), color(color) {}
    void Build() override {}

    void onResize(int pw, int ph) override {
        if (hasFrac) {
          x = frx * pw;
          y = fry * ph;
          geometryDirty = true;
        }
    }

    void collect(JohnPork &pork) override {
        if (!visible || text.empty()) return;

        if (!glyphsReady) {
          if (!gooner.ensureGlyphs(text)) return;
          glyphsReady = true;
          geometryDirty = true;
        }

        if (cachedAtlasRevision != gooner.getAtlasRevision() || cachedBaselineBias != baselineBias) {
          geometryDirty = true;
        }

        if (geometryDirty && !rebuildGeometry()) return;
        if (cachedVertices.empty() || cachedIndices.empty()) return;

        bgfx::TransientVertexBuffer tvb;
        bgfx::TransientIndexBuffer tib;
        auto &layout = gooner.getLayout();
        if (!bgfx::allocTransientBuffers(&tvb, layout, static_cast<uint32_t>(cachedVertices.size()),
                                         &tib, static_cast<uint32_t>(cachedIndices.size()))) {
          return;
        }

        std::memcpy(tvb.data, cachedVertices.data(), cachedVertices.size() * sizeof(Vertex));
        std::memcpy(tib.data, cachedIndices.data(), cachedIndices.size() * sizeof(uint16_t));

        DrawCmd cmd;
        cmd.tvb = tvb;
        cmd.tib = tib;
        cmd.program = gooner.getProgram();
        cmd.texUniform = gooner.getSampler();
        cmd.tex = gooner.getAtlas();
        cmd.samplerFlags = BGFX_SAMPLER_POINT;
        cmd.state = BGFX_STATE_WRITE_RGB | BGFX_STATE_WRITE_A | BGFX_STATE_BLEND_ALPHA;
        pork.push(cmd);
  }

private:
  bool rebuildGeometry() {
    cachedVertices.clear();
    cachedIndices.clear();

    float renderBaselineBias = baselineBias;
    if (renderBaselineBias == 0.0f) {
      renderBaselineBias = gooner.getTextMaxBearingY(text);
    }

    const float lineHeight = gooner.getLineHeight();
    const char *ptr = text.data();
    const char *end = ptr + text.size();
    float penX = x;
    float penY = y;

    cachedVertices.reserve(text.size() * 4);
    cachedIndices.reserve(text.size() * 6);

    while (ptr < end) {
      uint32_t codepoint = decodeUtf8Codepoint(ptr, end);
      if (codepoint == '\r') continue;
      if (codepoint == '\n') {
        penX = x;
        penY += lineHeight;
        continue;
      }

      const auto *glyph = gooner.getGlyph(codepoint);
      if (!glyph || !glyph->loaded) continue;

      const uint16_t base = static_cast<uint16_t>(cachedVertices.size());
      float x0 = floorf(penX + glyph->bearing_x + 0.5f);
      float y0 = floorf(penY + renderBaselineBias - glyph->bearing_y + 0.5f);
      float x1 = x0 + glyph->width;
      float y1 = y0 + glyph->height;

      cachedVertices.push_back({x0, y0, glyph->u0, glyph->v0, color});
      cachedVertices.push_back({x1, y0, glyph->u1, glyph->v0, color});
      cachedVertices.push_back({x1, y1, glyph->u1, glyph->v1, color});
      cachedVertices.push_back({x0, y1, glyph->u0, glyph->v1, color});

      cachedIndices.push_back(base);
      cachedIndices.push_back(base + 2);
      cachedIndices.push_back(base + 1);
      cachedIndices.push_back(base);
      cachedIndices.push_back(base + 3);
      cachedIndices.push_back(base + 2);

      penX += glyph->advance_x;
    }

    cachedAtlasRevision = gooner.getAtlasRevision();
    cachedBaselineBias = baselineBias;
    geometryDirty = false;
    return true;
  }

  TextGooner &gooner;
  std::string text;
  float x, y;
  uint32_t color;
  std::vector<Vertex> cachedVertices;
  std::vector<uint16_t> cachedIndices;
  uint64_t cachedAtlasRevision = std::numeric_limits<uint64_t>::max();
  float cachedBaselineBias = std::numeric_limits<float>::quiet_NaN();
  bool geometryDirty = true;
  bool glyphsReady = false;

public:
  float baselineBias = 0;
};

class Rectangle : public Skibidi {
    RectGooner &gooner;
    float x, y, w, h;
    uint32_t color;
public:
    Rectangle(RectGooner &gooner, float x, float y, float w, float h, uint32_t color, int32_t zindex)
    : Skibidi("rect", zindex), gooner(gooner), x(x), y(y), w(w), h(h), color(color) {
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
    Image(ImageGooner &gooner, bgfx::TextureHandle tex, float x, float y, float w, float h, uint32_t color, int32_t zindex)
    : Skibidi("image", zindex), gooner(gooner), tex(tex), x(x), y(y), w(w), h(h), color(color) {
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

struct Clickable {
    float x = 0, y = 0, w = 0, h = 0;
    std::function<void()> onClick;
    bool hasFrac = false;
    float frx = 0, fry = 0, frw = 0, frh = 0;
    void setFrac(float rx, float ry, float rw, float rh) {
        hasFrac = true;
        frx = rx; fry = ry;
        frw = rw > 0 ? rw : 1.0f;
        frh = rh > 0 ? rh : 1.0f;
    }
    void updateFrac(int pw, int ph) {
        if (hasFrac) {
            x = frx * pw; y = fry * ph;
            w = frw * pw; h = frh * ph;
        }
    }
};

struct Layer {
  std::string name;
  bool visible = true;
  std::vector<std::unique_ptr<Skibidi>> items;
  std::vector<Clickable> clickables;
  bool sortDirty = false;

  void clear() {
    items.clear();
    clickables.clear();
    sortDirty = false;
  }

  void ensureSorted() {
    if (!sortDirty) return;
    std::sort(items.begin(), items.end(), [](auto &a, auto &b) { return a->zindex < b->zindex; });
    sortDirty = false;
  }

  template<typename T, typename... Args>
  requires std::derived_from<T, Skibidi>
  T* add(Args&&... args) {
    auto obj = std::make_unique<T>(std::forward<Args>(args)...);
    T* raw = obj.get();
    raw->Build();
    items.push_back(std::move(obj));
    sortDirty = true;
    return raw;
  }

    Text* addText(TextGooner& gooner, const char* text, float x, float y, uint32_t color, int32_t zindex) {
        return add<Text>(gooner, std::string_view(text), x, y, color, zindex);
    }
    Rectangle* addRectangle(RectGooner& gooner, float x, float y, float w, float h, uint32_t color, int32_t zindex) {
        return add<Rectangle>(gooner, x, y, w, h, color, zindex);
    }
    Image* addImage(ImageGooner& gooner, bgfx::TextureHandle tex, float x, float y, float w, float h, uint32_t color, int32_t zindex) {
        return add<Image>(gooner, tex, x, y, w, h, color, zindex);
    }

    void addClickable(float x, float y, float w, float h, std::function<void()> cb) {
        Clickable c;
        c.x = x; c.y = y; c.w = w; c.h = h;
        c.onClick = std::move(cb);
        clickables.push_back(std::move(c));
    }

    void addClickableF(float rx, float ry, float rw, float rh, int pw, int ph, std::function<void()> cb) {
        Clickable c;
        c.setFrac(rx, ry, rw, rh);
        c.updateFrac(pw, ph);
        c.onClick = std::move(cb);
        clickables.push_back(std::move(c));
    }

  void onResize(int pw, int ph) {
    for (auto &item : items) item->onResize(pw, ph);
    for (auto &c : clickables) c.updateFrac(pw, ph);
  }

  void collect(JohnPork &pork) {
    if (!visible) return;
    ensureSorted();
    for (auto &item : items)
      if (item->visible)
        item->collect(pork);
  }

  bool pickClickHandler(const SDL_Event &ev, std::function<void()> &callback) {
    if (!visible) return false;
    if (ev.type != SDL_EVENT_MOUSE_BUTTON_DOWN || ev.button.button != SDL_BUTTON_LEFT) {
      return false;
    }

    float mx = ev.button.x;
    float my = ev.button.y;

    ensureSorted();
    for (int i = (int)items.size() - 1; i >= 0; --i) {
      auto &item = items[i];
      if (item->visible && item->onClick && item->hitTest(mx, my)) {
        callback = item->onClick;
        return true;
      }
    }

    for (int i = (int)clickables.size() - 1; i >= 0; --i) {
      auto &c = clickables[i];
      if (mx >= c.x && mx < c.x + c.w && my >= c.y && my < c.y + c.h) {
        callback = c.onClick;
        return static_cast<bool>(callback);
      }
    }

    return false;
  }

  bool handleEvent(const SDL_Event &ev) {
    std::function<void()> callback;
    if (!pickClickHandler(ev, callback)) return false;
    callback();
    return true;
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
    SDL_SetHint(SDL_HINT_TIMER_RESOLUTION, "1");
    if (!SDL_Init(SDL_INIT_VIDEO))
      throw std::runtime_error(std::string("SDL_Init: ") + SDL_GetError());

    SDL_SetHint(SDL_HINT_VIDEO_SYNC_WINDOW_OPERATIONS, "1");

    SDL_Window *buzz = SDL_CreateWindow(title.data(), x, y, SDL_WINDOW_RESIZABLE);
    if (!buzz) {
      SDL_Quit();
      throw std::runtime_error("SDL_CreateWindow: " + std::string(SDL_GetError()));
    }
    return Sigma(title, x, y, buzz);
  }

  SDL_Window *getWindow() const { return buzz; }

  bool setFullscreen(bool on) {
    if (fullscreen == on) return true;
    if (!SDL_SetWindowFullscreen(buzz, on)) return false;
    fullscreen = on;
    return true;
  }
  bool isFullscreen() const { return fullscreen; }

  Sigma(const Sigma &) = delete;
  Sigma &operator=(const Sigma &) = delete;
  Sigma(Sigma&& other)
  : title(std::move(other.title)), x(other.x), y(other.y) {
    buzz = other.buzz;
    fullscreen = other.fullscreen;
    other.buzz = nullptr;
  }
  Sigma &operator=(Sigma &&) = default;

private:
  std::string title;
  int x, y;
  bool fullscreen = false;
  SDL_Window *buzz = nullptr;
};

class Amogus {
private:
  SDL_Window *buzz = nullptr;
  int x, y;
  bgfx::RendererType::Enum goonerType;
  uint32_t resetFlags = BGFX_RESET_VSYNC;

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
    bgfx::reset(w, h, resetFlags);
    bgfx::setViewRect(0, 0, 0, (uint16_t)w, (uint16_t)h);
    x = w;
    y = h;
  }

  void setVsync(bool on) {
    uint32_t newResetFlags = on ? (resetFlags | BGFX_RESET_VSYNC)
                                : (resetFlags & ~BGFX_RESET_VSYNC);
    if (newResetFlags == resetFlags) return;
    resetFlags = newResetFlags;
    bgfx::reset(x, y, resetFlags);
    bgfx::setViewRect(0, 0, 0, (uint16_t)x, (uint16_t)y);
  }

  Amogus(const Amogus&) = delete;
  Amogus& operator=(const Amogus&) = delete;

  Amogus(Amogus&& other) noexcept
  : buzz(other.buzz), x(other.x), y(other.y), goonerType(other.goonerType), resetFlags(other.resetFlags) {
      other.buzz = nullptr;
  }

  Amogus& operator=(Amogus&& other) noexcept {
    if (this != &other) {
      buzz = other.buzz;
      x = other.x;
      y = other.y;
      goonerType = other.goonerType;
      resetFlags = other.resetFlags;
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
    std::unordered_map<std::string, std::unique_ptr<TextGooner>> textGooners;
    RectGooner rectGooner;
    ImageGooner imageGooner;
    CacheMan cacheMan;
    AudioEngine audioEngine;
    JohnPork pork;
    std::vector<Layer> sceneLayers;
    std::vector<Layer> uiLayers;

    static std::string makeTextGoonerKey(const char *path, int size) {
        return std::string(path ? path : "") + '\n' + std::to_string(size);
    }

public:
    int width = 1280, height = 720;
    bool gooning = true;
    int frameLimit = 0;
    std::chrono::steady_clock::time_point lastFullscreenChange{};
    bool pendingFullscreenChange = false;
    bool pendingFullscreenValue = false;

    Hell_Machina() = default;

    void init(const char *title, int w, int h, bgfx::RendererType::Enum renderer);
    void frame();
    void resize(int w, int h);
    bool handleEvent(const SDL_Event &ev);
    void setFullscreen(bool on);
    void setVsync(bool on);
    void setVolume(float volume);
    void setFrameLimit(int limit);
    void stopSound(uint32_t soundId);
    AudioEngine& getAudioEngine() { return audioEngine; }

    Layer& addSceneLayer(const char *name);
    Layer& addUILayer(const char *name);
    Layer* getSceneLayer(const char *name) {
        for (auto &l : sceneLayers) if (l.name == name) return &l;
        return nullptr;
    }
    Layer* getUILayer(const char *name) {
        for (auto &l : uiLayers) if (l.name == name) return &l;
        return nullptr;
    }
    TextGooner& getTextGooner() { return textGooner; }
    TextGooner& getTextGooner(const char *path, int size) {
        if (!path || *path == '\0' || size <= 0) {
            return textGooner;
        }

        auto key = makeTextGoonerKey(path, size);
        auto it = textGooners.find(key);
        if (it != textGooners.end()) {
            return *it->second;
        }

        auto gooner = std::make_unique<TextGooner>();
        if (!gooner->init(path, (float)size)) {
            throw std::runtime_error(std::string("Failed to load font: ") + path);
        }

        TextGooner &ref = *gooner;
        textGooners.emplace(std::move(key), std::move(gooner));
        return ref;
    }
    void setFont(const char *path, int size) {
        textGooner.init(path, (float)size);
    }
    bgfx::TextureHandle loadTexture(const char *path) {
        return cacheMan.loadTexture(path);
    }
    int getImageWidth(const char *path) { return cacheMan.getWidth(path); }
    int getImageHeight(const char *path) { return cacheMan.getHeight(path); }
    RectGooner& getRectGooner() { return rectGooner; }
    ImageGooner& getImageGooner() { return imageGooner; }
};
// NOLINTEND(readability-identifier-length,bugprone-narrowing-conversions,performance-noexcept-move-constructor)
