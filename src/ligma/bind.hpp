#pragma once
#include "ligma.hpp"
#include "../heck.hpp"

inline void ligma_bind(sol::state& L, Hell_Machina& engine) {
    L.new_usertype<bgfx::TextureHandle>("TextureHandle");

    L.new_usertype<Layer>("Layer",
        "addText",      &Layer::addText,
        "addRectangle", &Layer::addRectangle,
        "addImage",     &Layer::addImage
    );

    L.new_usertype<Hell_Machina>("Hell_Machina",
        "addUILayer",    &Hell_Machina::addUILayer,
        "addSceneLayer", &Hell_Machina::addSceneLayer,
        "getUILayer",    &Hell_Machina::getUILayer,
        "getSceneLayer", &Hell_Machina::getSceneLayer,
        "getTextGooner", &Hell_Machina::getTextGooner,
        "getRectGooner", &Hell_Machina::getRectGooner,
        "getImageGooner",&Hell_Machina::getImageGooner
    );

    L.new_usertype<TextGooner>("TextGooner");
    L.new_usertype<RectGooner>("RectGooner");
    L.new_usertype<ImageGooner>("ImageGooner");

    L.set_function("loadTexture", loadTexture);

    L.set("engine", &engine);
}
