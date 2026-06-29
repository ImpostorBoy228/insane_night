#pragma once
#include <functional>
#include <iostream>
#include <sol/sol.hpp>
#include "../heck.hpp"

inline void ligma_bind(sol::state& luaState, Hell_Machina& engine) {
    luaState.new_usertype<bgfx::TextureHandle>("TextureHandle",
        "idx", &bgfx::TextureHandle::idx
    );

    luaState.new_usertype<Layer>("Layer",
        "addText",      &Layer::addText,
        "addRectangle", &Layer::addRectangle,
        "addImage",     &Layer::addImage,
        "addClickable", [](Layer& self, float posX, float posY, float width, float height, const sol::function& callback) {
            self.addClickable(posX, posY, width, height, [callback]() {
                try {
                    callback();
                } catch (const sol::error& error) {
                    std::cerr << "Lua click callback error: " << error.what() << '\n';
                }
            });
        },
        "addClickableF", [&](Layer& self, float relX, float relY, float relWidth, float relHeight, const sol::function& callback) {
            self.addClickableF(relX, relY, relWidth, relHeight, engine.width, engine.height, [callback]() {
                try {
                    callback();
                } catch (const sol::error& error) {
                    std::cerr << "Lua click callback error: " << error.what() << '\n';
                }
            });
        },
        "addTextF", [&](Layer& self, TextGooner& textGooner, const char* textValue, float relX, float relY, uint32_t colorValue, int32_t zIndex) {
            const float screenWidth = static_cast<float>(engine.width);
            const float screenHeight = static_cast<float>(engine.height);
            auto* element = self.addText(textGooner, textValue, relX * screenWidth, relY * screenHeight, colorValue, zIndex);
            if (textValue && textGooner.ensureGlyphs(textValue)) {
                element->baselineBias = textGooner.getTextMaxBearingY(textValue);
            }
            element->setFrac(relX, relY, 0.0F, 0.0F);
            return element;
        },
        "addRectF", [&](Layer& self, RectGooner& rectGooner, float relX, float relY, float relWidth, float relHeight, uint32_t colorValue, int32_t zIndex) {
            const float screenWidth = static_cast<float>(engine.width);
            const float screenHeight = static_cast<float>(engine.height);
            auto* element = self.addRectangle(rectGooner, relX * screenWidth, relY * screenHeight, relWidth * screenWidth, relHeight * screenHeight, colorValue, zIndex);
            element->setFrac(relX, relY, relWidth, relHeight);
            return element;
        },
        "addImageF", [&](Layer& self, ImageGooner& imageGooner, bgfx::TextureHandle textureHandle, float relX, float relY, float relWidth, float relHeight, uint32_t colorValue, int32_t zIndex) {
            const float screenWidth = static_cast<float>(engine.width);
            const float screenHeight = static_cast<float>(engine.height);
            auto* element = self.addImage(imageGooner, textureHandle, relX * screenWidth, relY * screenHeight, relWidth * screenWidth, relHeight * screenHeight, colorValue, zIndex);
            element->setFrac(relX, relY, relWidth, relHeight);
            return element;
        },
        "visible", sol::property([](Layer& self) { return self.visible; },
                                 [](Layer& self, bool isVisible) { self.visible = isVisible; }),
        "clear", [](Layer& self) { self.clear(); }
    );

    luaState.new_usertype<Rectangle>("Rect",
        "onClick",   [](Rectangle& self, const sol::function& callback) {
            self.onClick = [callback]() {
                try {
                    callback();
                } catch (const sol::error& error) {
                    std::cerr << "Lua click callback error: " << error.what() << '\n';
                }
            };
        },
        "setHitbox", &Skibidi::setHitbox
    );
    luaState.new_usertype<Image>("Img",
        "onClick",   [](Image& self, const sol::function& callback) {
            self.onClick = [callback]() {
                try {
                    callback();
                } catch (const sol::error& error) {
                    std::cerr << "Lua click callback error: " << error.what() << '\n';
                }
            };
        },
        "setHitbox", &Skibidi::setHitbox
    );
    luaState.new_usertype<Text>("Txt",
        "onClick",   [](Text& self, const sol::function& callback) {
            self.onClick = [callback]() {
                try {
                    callback();
                } catch (const sol::error& error) {
                    std::cerr << "Lua click callback error: " << error.what() << '\n';
                }
            };
        },
        "setHitbox", &Skibidi::setHitbox
    );

    luaState.new_usertype<TextGooner>("TextGooner");
    luaState.new_usertype<RectGooner>("RectGooner");
    luaState.new_usertype<ImageGooner>("ImageGooner");

    luaState.set_function("loadTexture", [&](const char* path) { return engine.loadTexture(path); });
    luaState.set_function("setFullscreen", [&](bool enabled) { engine.setFullscreen(enabled); });
    luaState.set_function("setVsync", [&](bool enabled) { engine.setVsync(enabled); });

    // engine-bound helpers
    luaState.set_function("addUILayer",    [&](const char* layerName) -> Layer& { return engine.addUILayer(layerName); });
    luaState.set_function("addSceneLayer", [&](const char* layerName) -> Layer& { return engine.addSceneLayer(layerName); });
    luaState.set_function("getUILayer",    [&](const char* layerName) -> Layer* { return engine.getUILayer(layerName); });
    luaState.set_function("getSceneLayer", [&](const char* layerName) -> Layer* { return engine.getSceneLayer(layerName); });
    luaState.set_function("getTextGooner", [&]() -> TextGooner& { return engine.getTextGooner(); });
    luaState.set_function("getRectGooner", [&]() -> RectGooner& { return engine.getRectGooner(); });
    luaState.set_function("getImageGooner", [&]() -> ImageGooner& { return engine.getImageGooner(); });
    luaState.set_function("setFont", [&](const char* path, int size) { engine.setFont(path, size); });
    luaState.set_function("fuckOff", [&]() { engine.gooning = false; });
}
