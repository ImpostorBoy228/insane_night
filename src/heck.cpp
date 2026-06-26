#include "heck.hpp"

void Kino::setViewport(uint16_t w, uint16_t h) {
    viewW = w; viewH = h;
    dirty = true;
}

void Kino::setOrtho(float left, float right, float bottom, float top) {
    bx::mtxOrtho(ortho, left, right, bottom, top, 0.0f, 1.0f, 0.0f, false);
    useOrtho = true;
    dirty = true;
}

void Kino::begin() {
    if (dirty) {
        bgfx::setViewFrameBuffer(id, fb);
        dirty = false;
    }
    bgfx::setViewRect(id, 0, 0, viewW, viewH);
    bgfx::setViewClear(id, clearFlags, clearColor, 1.0f, 0);
    bgfx::touch(id);
    if (useOrtho)
        bgfx::setViewTransform(id, NULL, ortho);
}

Layer& Hell_Machina::addSceneLayer(const char *name) {
    return sceneLayers.emplace_back(Layer{name, true, {}});
}

Layer& Hell_Machina::addUILayer(const char *name) {
    return uiLayers.emplace_back(Layer{name, true, {}});
}

void Hell_Machina::init(const char *title, int w, int h, bgfx::RendererType::Enum renderer) {
    sigma.emplace(Sigma::skid(title, w, h));
    amogus.emplace(Amogus::rizzing(sigma->getWindow(), w, h, renderer));

    scenePass.id = 0;
    scenePass.fb = BGFX_INVALID_HANDLE;
    scenePass.clearFlags = BGFX_CLEAR_COLOR | BGFX_CLEAR_DEPTH;
    scenePass.clearColor = 0x000000ff;
    scenePass.setViewport((uint16_t)w, (uint16_t)h);

    uiPass.id = 1;
    uiPass.fb = BGFX_INVALID_HANDLE;
    uiPass.clearFlags = BGFX_CLEAR_NONE;
    uiPass.clearColor = 0;
    uiPass.setViewport((uint16_t)w, (uint16_t)h);
    uiPass.setOrtho(0, (float)w, (float)h, 0);

    textGooner.init("/usr/share/fonts/TTF/DejaVuSans.ttf", 32);
    rectGooner.init();
}

void Hell_Machina::frame() {
    JohnPork pork;

    scenePass.begin();
    for (auto &layer : sceneLayers) layer.collect(pork);
    pork.flush(scenePass.id);

    uiPass.begin();
    for (auto &layer : uiLayers) layer.collect(pork);
    pork.flush(uiPass.id);

    bgfx::frame();
}

void Hell_Machina::resize(int w, int h) {
    amogus->resize(w, h);
    scenePass.setViewport((uint16_t)w, (uint16_t)h);
    uiPass.setViewport((uint16_t)w, (uint16_t)h);
    uiPass.setOrtho(0, (float)w, (float)h, 0);
}
