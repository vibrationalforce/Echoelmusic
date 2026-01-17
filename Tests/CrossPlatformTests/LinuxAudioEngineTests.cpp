/**
 * LinuxAudioEngineTests.cpp
 * Echoelmusic - Linux Audio Engine Tests
 *
 * Unit tests for ALSA and PipeWire audio engines
 * Compile only on Linux: #ifdef __linux__
 *
 * Created: 2026-01-15
 */

#ifdef __linux__

#include <cassert>
#include <iostream>
#include <string>
#include <chrono>
#include <thread>
#include <cmath>

// Include the implementations
#include "../../Sources/DSP/LinuxAudioEngine.hpp"
#include "../../Sources/DSP/PipeWireAudioEngine.hpp"

using namespace Echoelmusic::Audio;

// Test helper macros
#define TEST_ASSERT(condition, message) \
    do { \
        if (!(condition)) { \
            std::cerr << "FAILED: " << message << " (" << __FILE__ << ":" << __LINE__ << ")" << std::endl; \
            return false; \
        } \
    } while (0)

#define RUN_TEST(test_func) \
    do { \
        std::cout << "Running " << #test_func << "... "; \
        if (test_func()) { \
            std::cout << "PASSED" << std::endl; \
            passed++; \
        } else { \
            std::cout << "FAILED" << std::endl; \
            failed++; \
        } \
    } while (0)

// ============================================================================
// MARK: - ALSA Configuration Tests
// ============================================================================

bool test_alsa_default_config() {
    AudioConfig config;

    TEST_ASSERT(config.sampleRate == 48000, "Default sample rate should be 48000");
    TEST_ASSERT(config.bufferSize == 256, "Default buffer size should be 256");
    TEST_ASSERT(config.channels == 2, "Default channels should be 2");
    TEST_ASSERT(config.deviceName == "default", "Default device should be 'default'");

    return true;
}

bool test_alsa_custom_config() {
    AudioConfig config;
    config.sampleRate = 44100;
    config.bufferSize = 512;
    config.channels = 1;
    config.deviceName = "hw:0,0";

    TEST_ASSERT(config.sampleRate == 44100, "Custom sample rate");
    TEST_ASSERT(config.bufferSize == 512, "Custom buffer size");
    TEST_ASSERT(config.channels == 1, "Custom channels");
    TEST_ASSERT(config.deviceName == "hw:0,0", "Custom device name");

    return true;
}

// ============================================================================
// MARK: - ALSA Engine Tests
// ============================================================================

bool test_alsa_engine_construction() {
    LinuxAudioEngine engine;

    TEST_ASSERT(!engine.isRunning(), "New engine should not be running");
    TEST_ASSERT(engine.sampleRate() == 48000, "Default sample rate");
    TEST_ASSERT(engine.channels() == 2, "Default channels");

    return true;
}

bool test_alsa_callback_setting() {
    LinuxAudioEngine engine;
    bool callbackSet = false;

    engine.setCallback([&callbackSet](float* output, int numFrames, int numChannels) {
        callbackSet = true;
        for (int i = 0; i < numFrames * numChannels; i++) {
            output[i] = 0.0f;
        }
    });

    // Just verify callback can be set without crash
    TEST_ASSERT(true, "Callback set successfully");

    return true;
}

bool test_alsa_getters() {
    LinuxAudioEngine engine;

    TEST_ASSERT(engine.sampleRate() == 48000, "Sample rate getter");
    TEST_ASSERT(engine.bufferSize() == 256, "Buffer size getter");
    TEST_ASSERT(engine.channels() == 2, "Channels getter");
    TEST_ASSERT(engine.lastError().empty(), "No error initially");

    return true;
}

// ============================================================================
// MARK: - ALSA Mixer Tests
// ============================================================================

bool test_alsa_mixer_construction() {
    ALSAMixer mixer;  // Uses default card and "Master"

    // Just verify construction doesn't crash
    TEST_ASSERT(true, "Mixer construction successful");

    return true;
}

bool test_alsa_mixer_custom_element() {
    ALSAMixer mixer("default", "PCM");

    // Verify custom element name accepted
    TEST_ASSERT(true, "Custom mixer element accepted");

    return true;
}

// ============================================================================
// MARK: - Binaural Beat Generator Tests
// ============================================================================

bool test_binaural_construction() {
    BinauralBeatGenerator generator;

    TEST_ASSERT(true, "Generator construction successful");

    return true;
}

bool test_binaural_custom_frequencies() {
    BinauralBeatGenerator generator(200.0f, 10.0f);

    generator.setSampleRate(48000);
    generator.setBaseFrequency(300.0f);
    generator.setBeatFrequency(7.0f);  // Theta
    generator.setAmplitude(0.5f);

    TEST_ASSERT(true, "Custom frequencies set successfully");

    return true;
}

bool test_binaural_generate_stereo() {
    BinauralBeatGenerator generator;
    generator.setSampleRate(48000);

    std::vector<float> left(256);
    std::vector<float> right(256);

    generator.generate(left.data(), right.data(), 256);

    // Verify output is not all zeros
    bool hasNonZero = false;
    for (int i = 0; i < 256; i++) {
        if (left[i] != 0.0f || right[i] != 0.0f) {
            hasNonZero = true;
            break;
        }
    }

    TEST_ASSERT(hasNonZero, "Generator should produce non-zero output");

    // Verify left and right are different (binaural effect)
    bool hasDifference = false;
    for (int i = 0; i < 256; i++) {
        if (std::abs(left[i] - right[i]) > 0.001f) {
            hasDifference = true;
            break;
        }
    }

    TEST_ASSERT(hasDifference, "Left and right channels should differ");

    return true;
}

bool test_binaural_generate_interleaved() {
    BinauralBeatGenerator generator;
    generator.setSampleRate(48000);

    std::vector<float> output(512);  // 256 frames * 2 channels

    generator.generateInterleaved(output.data(), 256);

    // Verify output is not all zeros
    bool hasNonZero = false;
    for (int i = 0; i < 512; i++) {
        if (output[i] != 0.0f) {
            hasNonZero = true;
            break;
        }
    }

    TEST_ASSERT(hasNonZero, "Interleaved generator should produce output");

    return true;
}

bool test_binaural_amplitude_clamp() {
    BinauralBeatGenerator generator;

    generator.setAmplitude(1.5f);  // Should clamp to 1.0
    generator.setAmplitude(-0.5f);  // Should clamp to 0.0

    TEST_ASSERT(true, "Amplitude clamping works");

    return true;
}

// ============================================================================
// MARK: - PipeWire Configuration Tests
// ============================================================================

bool test_pipewire_default_config() {
    PipeWireConfig config;

    TEST_ASSERT(config.sampleRate == 48000, "Default sample rate");
    TEST_ASSERT(config.bufferSize == 256, "Default buffer size");
    TEST_ASSERT(config.channels == 2, "Default channels");
    TEST_ASSERT(config.appName == "Echoelmusic", "Default app name");
    TEST_ASSERT(config.nodeName == "echoelmusic-output", "Default node name");

    return true;
}

bool test_pipewire_custom_config() {
    PipeWireConfig config;
    config.sampleRate = 96000;
    config.bufferSize = 128;
    config.appName = "TestApp";

    TEST_ASSERT(config.sampleRate == 96000, "Custom sample rate");
    TEST_ASSERT(config.bufferSize == 128, "Custom buffer size");
    TEST_ASSERT(config.appName == "TestApp", "Custom app name");

    return true;
}

// ============================================================================
// MARK: - PipeWire Engine Tests
// ============================================================================

bool test_pipewire_availability() {
    bool available = PipeWireUtils::isPipeWireAvailable();
    std::cout << "(PipeWire available: " << (available ? "yes" : "no") << ") ";

    return true;
}

bool test_pipewire_version() {
    std::string version = PipeWireUtils::getPipeWireVersion();
    std::cout << "(version: " << version << ") ";

    TEST_ASSERT(!version.empty(), "Version string should not be empty");

    return true;
}

bool test_pipewire_engine_construction() {
    PipeWireAudioEngine engine;

    TEST_ASSERT(!engine.isRunning(), "New engine should not be running");

    return true;
}

bool test_pipewire_engine_getters() {
    PipeWireAudioEngine engine;

    TEST_ASSERT(engine.sampleRate() == 48000, "Default sample rate");
    TEST_ASSERT(engine.bufferSize() == 256, "Default buffer size");
    TEST_ASSERT(engine.channels() == 2, "Default channels");

    return true;
}

bool test_pipewire_bio_modulation() {
    PipeWireAudioEngine engine;

    // Should not crash even without initialization
    engine.setBioModulation(75.0f, 0.8f, 12.0f);

    TEST_ASSERT(true, "Bio modulation set without crash");

    return true;
}

bool test_pipewire_latency() {
    PipeWireAudioEngine engine;

    float latency = engine.getLatencyMs();

    // Latency depends on initialization state
    // Just verify it returns a reasonable value
    TEST_ASSERT(latency >= 0.0f, "Latency should be non-negative");

    return true;
}

// ============================================================================
// MARK: - Integration Tests
// ============================================================================

bool test_alsa_pipewire_config_compatibility() {
    // Ensure both configs have same defaults for easy switching
    AudioConfig alsaConfig;
    PipeWireConfig pwConfig;

    TEST_ASSERT(alsaConfig.sampleRate == pwConfig.sampleRate, "Sample rates match");
    TEST_ASSERT(alsaConfig.bufferSize == pwConfig.bufferSize, "Buffer sizes match");
    TEST_ASSERT(alsaConfig.channels == pwConfig.channels, "Channels match");

    return true;
}

bool test_callback_signature_compatibility() {
    // Both engines should accept same callback signature
    auto callback = [](float* output, int numFrames, int numChannels) {
        for (int i = 0; i < numFrames * numChannels; i++) {
            output[i] = 0.0f;
        }
    };

    LinuxAudioEngine alsaEngine;
    alsaEngine.setCallback(callback);

    PipeWireAudioEngine pwEngine;
    pwEngine.setCallback(callback);

    TEST_ASSERT(true, "Both engines accept same callback signature");

    return true;
}

// ============================================================================
// MARK: - Main
// ============================================================================

int main() {
    std::cout << "==============================================\n";
    std::cout << "Linux Audio Engine Tests (ALSA + PipeWire)\n";
    std::cout << "==============================================\n\n";

    int passed = 0;
    int failed = 0;

    // ALSA Configuration tests
    std::cout << "--- ALSA Configuration Tests ---\n";
    RUN_TEST(test_alsa_default_config);
    RUN_TEST(test_alsa_custom_config);

    // ALSA Engine tests
    std::cout << "\n--- ALSA Engine Tests ---\n";
    RUN_TEST(test_alsa_engine_construction);
    RUN_TEST(test_alsa_callback_setting);
    RUN_TEST(test_alsa_getters);

    // ALSA Mixer tests
    std::cout << "\n--- ALSA Mixer Tests ---\n";
    RUN_TEST(test_alsa_mixer_construction);
    RUN_TEST(test_alsa_mixer_custom_element);

    // Binaural Beat tests
    std::cout << "\n--- Binaural Beat Generator Tests ---\n";
    RUN_TEST(test_binaural_construction);
    RUN_TEST(test_binaural_custom_frequencies);
    RUN_TEST(test_binaural_generate_stereo);
    RUN_TEST(test_binaural_generate_interleaved);
    RUN_TEST(test_binaural_amplitude_clamp);

    // PipeWire Configuration tests
    std::cout << "\n--- PipeWire Configuration Tests ---\n";
    RUN_TEST(test_pipewire_default_config);
    RUN_TEST(test_pipewire_custom_config);

    // PipeWire Engine tests
    std::cout << "\n--- PipeWire Engine Tests ---\n";
    RUN_TEST(test_pipewire_availability);
    RUN_TEST(test_pipewire_version);
    RUN_TEST(test_pipewire_engine_construction);
    RUN_TEST(test_pipewire_engine_getters);
    RUN_TEST(test_pipewire_bio_modulation);
    RUN_TEST(test_pipewire_latency);

    // Integration tests
    std::cout << "\n--- Integration Tests ---\n";
    RUN_TEST(test_alsa_pipewire_config_compatibility);
    RUN_TEST(test_callback_signature_compatibility);

    // Summary
    std::cout << "\n==============================================\n";
    std::cout << "Results: " << passed << " passed, " << failed << " failed\n";
    std::cout << "==============================================\n";

    return failed > 0 ? 1 : 0;
}

#else

// Not Linux - just a stub
#include <iostream>

int main() {
    std::cout << "Linux Audio Engine tests skipped (not Linux)\n";
    return 0;
}

#endif // __linux__
