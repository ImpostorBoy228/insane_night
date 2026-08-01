#include "audio_unc.hpp"
#include <algorithm>
#include <filesystem>

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
    streams.clear();
    initialized = false;
}

void AudioEngine::setGlobalVolume(float volume) {
    if (!initialized) {
        return;
    }

    engine.setGlobalVolume(std::clamp(volume, 0.0f, 1.0f));
}

void AudioEngine::preloadSounds(const std::string &dir) {
    if (!initialized) return;
    static constexpr const char *exts[] = {".mp3", ".wav", ".ogg"};
    int loaded = 0;
    if (!std::filesystem::exists(dir)) return;
    for (auto &entry : std::filesystem::recursive_directory_iterator(dir)) {
        if (!entry.is_regular_file()) continue;
        auto ext = entry.path().extension().string();
        for (auto *e : exts) {
            if (ext != e) continue;
            if (isStreamedFile(entry.path().string())) {
                if (getOrLoadStream(entry.path().string())) loaded++;
            } else {
                if (getOrLoadSound(entry.path().string())) loaded++;
            }
            break;
        }
    }
    printf("preloaded %d sounds from %s\n", loaded, dir.c_str());
}

bool AudioEngine::isStreamedFile(std::string_view path) {
    size_t dot = path.rfind('.');
    if (dot == std::string_view::npos) return false;
    return path.substr(dot) == ".mp3";
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

SoLoud::WavStream* AudioEngine::getOrLoadStream(std::string_view path) {
    if (!initialized || path.empty()) {
        return nullptr;
    }

    const std::string key(path);
    auto it = streams.find(key);
    if (it != streams.end()) {
        return it->second.get();
    }

    auto stream = std::make_unique<SoLoud::WavStream>();
    if (stream->load(key.c_str()) != SoLoud::SO_NO_ERROR) {
        return nullptr;
    }

    stream->setSingleInstance(true);
    auto* raw = stream.get();
    streams.emplace(key, std::move(stream));
    return raw;
}

uint32_t AudioEngine::playSound(std::string_view path, bool singleInstance) {
    if (!initialized || path.empty()) {
        return 0;
    }

    SoLoud::AudioSource* source = nullptr;
    if (isStreamedFile(path)) {
        source = getOrLoadStream(path);
    } else {
        source = getOrLoadSound(path);
    }
    if (!source) {
        return 0;
    }

    source->setSingleInstance(singleInstance);

    const SoLoud::handle handle = engine.play(*source);
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
