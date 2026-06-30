#pragma once

#include <soloud.h>

class AudioEngine {
public:
    AudioEngine() = default;
    ~AudioEngine();

    AudioEngine(const AudioEngine&) = delete;
    AudioEngine& operator=(const AudioEngine&) = delete;

    bool init();
    void deinit();
    void setGlobalVolume(float volume);

private:
    SoLoud::Soloud engine;
    bool initialized = false;
};
