#pragma once
#include <functional>
#include "ligma.hpp"
#include "../heck.hpp"

inline void ligma_bind(sol::state& L, Hell_Machina& engine) {
    L.new_usertype<bgfx::TextureHandle>("TextureHandle",
        "idx", &bgfx::TextureHandle::idx
    );

    L.new_usertype<Layer>("Layer",
        "addText",      &Layer::addText,
        "addRectangle", &Layer::addRectangle,
        "addImage",     &Layer::addImage,
        "addClickable", [](Layer& self, float x, float y, float w, float h, sol::function cb) {
            self.addClickable(x, y, w, h, [cb]() { cb(); });
        }
    );

    L.new_usertype<Rectangle>("Rect",
        "onClick",   [](Rectangle& self, sol::function cb) { self.onClick = [cb]() { cb(); }; },
        "setHitbox", &Skibidi::setHitbox
    );
    L.new_usertype<Image>("Img",
        "onClick",   [](Image& self, sol::function cb) { self.onClick = [cb]() { cb(); }; },
        "setHitbox", &Skibidi::setHitbox
    );
    L.new_usertype<Text>("Txt",
        "onClick",   [](Text& self, sol::function cb) { self.onClick = [cb]() { cb(); }; },
        "setHitbox", &Skibidi::setHitbox
    );

    L.new_usertype<TextGooner>("TextGooner");
    L.new_usertype<RectGooner>("RectGooner");
    L.new_usertype<ImageGooner>("ImageGooner");

    L.set_function("loadTexture", loadTexture);

    // engine-bound helpers
    L.set_function("addUILayer",    [&](const char* n) -> Layer& { return engine.addUILayer(n); });
    L.set_function("addSceneLayer", [&](const char* n) -> Layer& { return engine.addSceneLayer(n); });
    L.set_function("getTextGooner", [&]() -> TextGooner& { return engine.getTextGooner(); });
    L.set_function("getRectGooner", [&]() -> RectGooner& { return engine.getRectGooner(); });
    L.set_function("getImageGooner",[&]() -> ImageGooner& { return engine.getImageGooner(); });
}
