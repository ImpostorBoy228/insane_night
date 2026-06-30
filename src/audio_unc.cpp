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

    engine.deinit();
    initialized = false;
}

void AudioEngine::setGlobalVolume(float volume) {
    if (!initialized) {
        return;
    }

    engine.setGlobalVolume(std::clamp(volume, 0.0f, 1.0f));
}
