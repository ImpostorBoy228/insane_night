#pragma once
#include <functional>
#include <iostream>
#include <string_view>
#include <sol/sol.hpp>
#include "../heck.hpp"

inline void ligma_bind(sol::state& luaState, Hell_Machina& engine) {
    auto report_lua_error = [](std::string_view prefix, const sol::error& error) {
        std::cerr << prefix << error.what() << '\n';
    };

    auto bind_click_callback = [report_lua_error](const sol::protected_function& callback) {
        return [callback, report_lua_error]() {
            sol::protected_function_result result = callback();
            if (!result.valid()) {
                sol::error error = result;
                report_lua_error("Lua click callback fuckup: ", error);
            }
        };
    };

    auto set_text_baseline = [](Text* element, TextGooner& textGooner, const char* textValue) {
        if (!element) {
            return;
        }

        std::string_view text = textValue ? std::string_view(textValue) : std::string_view();
        if (!text.empty() && textGooner.ensureGlyphs(text)) {
            element->baselineBias = textGooner.getTextMaxBearingY(text);
        }
    };

    auto safe_text = [](const char* textValue) -> const char* {
        return textValue ? textValue : "";
    };
    luaState.new_usertype<bgfx::TextureHandle>("TextureHandle",
        "idx", &bgfx::TextureHandle::idx
    );

    luaState.new_usertype<Layer>("Layer",
        "addText", [&](Layer& self, TextGooner& textGooner, const char* textValue, float posX, float posY, uint32_t colorValue, int32_t zIndex) {
            auto* element = self.addText(textGooner, safe_text(textValue), posX, posY, colorValue, zIndex);
            set_text_baseline(element, textGooner, textValue);
            return element;
        },
        "addRectangle", &Layer::addRectangle,
        "addImage",     &Layer::addImage,
        "addClickable", [&](Layer& self, float posX, float posY, float width, float height, const sol::protected_function& callback) {
            self.addClickable(posX, posY, width, height, bind_click_callback(callback));
        },
        "addClickableF", [&](Layer& self, float relX, float relY, float relWidth, float relHeight, const sol::protected_function& callback) {
            self.addClickableF(relX, relY, relWidth, relHeight, engine.width, engine.height, bind_click_callback(callback));
        },
        "addTextF", [&](Layer& self, TextGooner& textGooner, const char* textValue, float relX, float relY, uint32_t colorValue, int32_t zIndex) {
            const float screenWidth = static_cast<float>(engine.width);
            const float screenHeight = static_cast<float>(engine.height);
            auto* element = self.addText(textGooner, safe_text(textValue), relX * screenWidth, relY * screenHeight, colorValue, zIndex);
            set_text_baseline(element, textGooner, textValue);
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
        "onClick",   [&](Rectangle& self, const sol::protected_function& callback) {
            self.onClick = bind_click_callback(callback);
        },
        "setHitbox", &Skibidi::setHitbox
    );
    luaState.new_usertype<Image>("Img",
        "onClick",   [&](Image& self, const sol::protected_function& callback) {
            self.onClick = bind_click_callback(callback);
        },
        "setHitbox", &Skibidi::setHitbox
    );
    luaState.new_usertype<Text>("Txt",
        "onClick",   [&](Text& self, const sol::protected_function& callback) {
            self.onClick = bind_click_callback(callback);
        },
        "setHitbox", &Skibidi::setHitbox
    );

    luaState.new_usertype<TextGooner>("TextGooner",
        "measureText", [](TextGooner& self, const char* textValue) {
            std::string_view text = textValue ? std::string_view(textValue) : std::string_view();
            return self.measureText(text);
        },
        "getLineHeight", &TextGooner::getLineHeight
    );
    luaState.new_usertype<RectGooner>("RectGooner");
    luaState.new_usertype<ImageGooner>("ImageGooner");
    luaState.new_usertype<AudioEngine>("AudioEngine",
        "playSound", [](AudioEngine& self, const char* pathValue, const sol::object& singleInstanceValue) {
            const bool singleInstance = singleInstanceValue.is<bool>() ? singleInstanceValue.as<bool>() : true;
            std::string_view path = pathValue ? std::string_view(pathValue) : std::string_view();
            return self.playSound(path, singleInstance);
        },
        "stopSound", &AudioEngine::stopSound,
        "stopAllSounds", &AudioEngine::stopAllSounds,
        "setVolume", &AudioEngine::setGlobalVolume
    );


    luaState.set_function("getAudioEngine", [&]() -> AudioEngine& { return engine.getAudioEngine(); });

    luaState.set_function("loadTexture", [&](const char* path) { return engine.loadTexture(path); });
    luaState.set_function("setFullscreen", [&](bool enabled) { engine.setFullscreen(enabled); });
    luaState.set_function("setVsync", [&](bool enabled) { engine.setVsync(enabled); });
    luaState.set_function("setVolume", [&](float volume) { engine.setVolume(volume); });
    luaState.set_function("setFrameLimit", [&](int limit) { engine.setFrameLimit(limit); });

    // engine-bound helpers
    luaState.set_function("addUILayer",    [&](const char* layerName) -> Layer& { return engine.addUILayer(layerName); });
    luaState.set_function("addSceneLayer", [&](const char* layerName) -> Layer& { return engine.addSceneLayer(layerName); });
    luaState.set_function("getUILayer",    [&](const char* layerName) -> Layer* { return engine.getUILayer(layerName); });
    luaState.set_function("getSceneLayer", [&](const char* layerName) -> Layer* { return engine.getSceneLayer(layerName); });
    luaState.set_function("getTextGooner", sol::overload(
        [&]() -> TextGooner& { return engine.getTextGooner(); },
        [&](const char* path, int size) -> TextGooner& { return engine.getTextGooner(path, size); }
    ));
    luaState.set_function("getRectGooner", [&]() -> RectGooner& { return engine.getRectGooner(); });
    luaState.set_function("getImageGooner", [&]() -> ImageGooner& { return engine.getImageGooner(); });
    luaState.set_function("setFont", [&](const char* path, int size) { engine.setFont(path, size); });
    luaState.set_function("getScreenWidth", [&]() { return engine.width; });
    luaState.set_function("getScreenHeight", [&]() { return engine.height; });
    luaState.set_function("fuckOff", [&]() { engine.gooning = false; });
}
