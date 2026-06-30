#include "audio_unc.hpp"

#include <algorithm>

AudioEngine::~AudioEngine() {
    deinit();
}

bool AudioEngine::init() {
    if (initialized) {
        return true;
    }

    const auto result = engine.init(SoLoud::Soloud::CLIP_ROUNDOFF, SoLoud::Soloud::MINIAUDIO);
    if (result != SoLoud::SO_NO_ERROR) {
        return false;
    }

    initialized = true;
    return true;
}

void AudioEngine::deinit() {
    if (!initialized) {
        return;
    }

    stopAllSounds();
    engine.deinit();
    sounds.clear();
    initialized = false;
}

void AudioEngine::setGlobalVolume(float volume) {
    if (!initialized) {
        return;
    }

    engine.setGlobalVolume(std::clamp(volume, 0.0f, 1.0f));
}

SoLoud::Wav* AudioEngine::getOrLoadSound(std::string_view path) {
    if (!initialized || path.empty()) {
        return nullptr;
    }

    const std::string key(path);
    auto it = sounds.find(key);
    if (it != sounds.end()) {
        return it->second.get();
    }

    auto sound = std::make_unique<SoLoud::Wav>();
    if (sound->load(key.c_str()) != SoLoud::SO_NO_ERROR) {
        return nullptr;
    }

    sound->setSingleInstance(true);
    auto* raw = sound.get();
    sounds.emplace(key, std::move(sound));
    return raw;
}

uint32_t AudioEngine::playSound(std::string_view path, bool singleInstance) {
    if (!initialized || path.empty()) {
        return 0;
    }

    SoLoud::Wav* sound = getOrLoadSound(path);
    if (!sound) {
        return 0;
    }

    sound->setSingleInstance(singleInstance);

    const SoLoud::handle handle = engine.play(*sound);
    if (!engine.isValidVoiceHandle(handle)) {
        return 0;
    }

    return static_cast<uint32_t>(handle);
}

void AudioEngine::stopSound(uint32_t soundId) {
    if (!initialized || soundId == 0) {
        return;
    }

    const auto handle = static_cast<SoLoud::handle>(soundId);
    if (engine.isValidVoiceHandle(handle)) {
        engine.stop(handle);
    }
}

void AudioEngine::stopAllSounds() {
    if (!initialized) {
        return;
    }

    engine.stopAll();
}
