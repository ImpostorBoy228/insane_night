#pragma once

#include <cstdint>
#include <soloud.h>
#include <soloud_wav.h>
#include <soloud_wavstream.h>

#include <memory>
#include <string>
#include <string_view>
#include <unordered_map>

class AudioEngine {
public:
    AudioEngine() = default;
    ~AudioEngine();

    AudioEngine(const AudioEngine&) = delete;
    AudioEngine& operator=(const AudioEngine&) = delete;

    bool init();
    void deinit();
    void setGlobalVolume(float volume);

    uint32_t playSound(std::string_view path, bool singleInstance = true);
    void stopSound(uint32_t soundId);
    void stopAllSounds();
    void preloadSounds(const std::string &dir);

private:
    SoLoud::Wav* getOrLoadSound(std::string_view path);
    SoLoud::WavStream* getOrLoadStream(std::string_view path);
    static bool isStreamedFile(std::string_view path);

    SoLoud::Soloud engine;
    std::unordered_map<std::string, std::unique_ptr<SoLoud::Wav>> sounds;
    std::unordered_map<std::string, std::unique_ptr<SoLoud::WavStream>> streams;
    bool initialized = false;
};
