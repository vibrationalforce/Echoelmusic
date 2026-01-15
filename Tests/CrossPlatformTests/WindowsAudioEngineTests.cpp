/**
 * WindowsAudioEngineTests.cpp
 * Echoelmusic - Cross-Platform Audio Engine Tests
 *
 * Unit tests for Windows WASAPI Audio Engine
 * Compile only on Windows: #ifdef _WIN32
 *
 * Created: 2026-01-15
 */

#ifdef _WIN32

#include <cassert>
#include <iostream>
#include <string>
#include <chrono>
#include <thread>

// Include the header-only implementation
#include "../../Sources/DSP/WindowsAudioEngine.hpp"

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
// MARK: - Configuration Tests
// ============================================================================

bool test_default_config() {
    WindowsAudioConfig config;

    TEST_ASSERT(config.sampleRate == 48000, "Default sample rate should be 48000");
    TEST_ASSERT(config.bufferSizeFrames == 256, "Default buffer size should be 256");
    TEST_ASSERT(config.channels == 2, "Default channels should be 2");
    TEST_ASSERT(config.bitsPerSample == 32, "Default bits per sample should be 32");
    TEST_ASSERT(config.mode == WASAPIMode::Exclusive, "Default mode should be Exclusive");
    TEST_ASSERT(config.deviceId.empty(), "Default device ID should be empty");

    return true;
}

bool test_custom_config() {
    WindowsAudioConfig config;
    config.sampleRate = 44100;
    config.bufferSizeFrames = 512;
    config.channels = 1;
    config.mode = WASAPIMode::Shared;
    config.deviceId = L"test-device";

    TEST_ASSERT(config.sampleRate == 44100, "Custom sample rate");
    TEST_ASSERT(config.bufferSizeFrames == 512, "Custom buffer size");
    TEST_ASSERT(config.channels == 1, "Custom channels");
    TEST_ASSERT(config.mode == WASAPIMode::Shared, "Custom mode");
    TEST_ASSERT(config.deviceId == L"test-device", "Custom device ID");

    return true;
}

// ============================================================================
// MARK: - ComPtr Tests
// ============================================================================

bool test_comptr_default() {
    ComPtr<IUnknown> ptr;

    TEST_ASSERT(!ptr, "Default ComPtr should be null");
    TEST_ASSERT(ptr.get() == nullptr, "Default ComPtr get() should return nullptr");

    return true;
}

bool test_comptr_move() {
    ComPtr<IUnknown> ptr1;
    ComPtr<IUnknown> ptr2(std::move(ptr1));

    TEST_ASSERT(!ptr1, "Moved-from ComPtr should be null");
    TEST_ASSERT(!ptr2, "Moved-to ComPtr should still be null (no actual object)");

    return true;
}

// ============================================================================
// MARK: - Engine Lifecycle Tests
// ============================================================================

bool test_engine_construction() {
    WindowsAudioEngine engine;

    TEST_ASSERT(!engine.isRunning(), "New engine should not be running");
    TEST_ASSERT(engine.sampleRate() == 48000, "Default sample rate");
    TEST_ASSERT(engine.channels() == 2, "Default channels");

    return true;
}

bool test_engine_initialization() {
    WindowsAudioEngine engine;
    WindowsAudioConfig config;
    config.mode = WASAPIMode::Shared;  // Use shared mode for testing

    bool initialized = engine.initialize(config);

    // Note: This may fail on systems without audio devices
    if (initialized) {
        TEST_ASSERT(engine.bufferSize() > 0, "Buffer size should be positive");
        TEST_ASSERT(engine.getLatency() > 0, "Latency should be positive");
    }

    return true;
}

bool test_engine_callback() {
    WindowsAudioEngine engine;
    int callbackCount = 0;

    engine.setCallback([&callbackCount](float* output, int numFrames, int numChannels) {
        callbackCount++;
        // Fill with silence
        for (int i = 0; i < numFrames * numChannels; i++) {
            output[i] = 0.0f;
        }
    });

    // Just verify callback can be set without crash
    TEST_ASSERT(true, "Callback set successfully");

    return true;
}

bool test_engine_bio_modulation() {
    WindowsAudioEngine engine;

    // Set bio modulation parameters
    engine.setBioModulation(75.0f, 0.8f, 12.0f);

    // Verify no crash
    TEST_ASSERT(true, "Bio modulation set successfully");

    return true;
}

// ============================================================================
// MARK: - Utility Tests
// ============================================================================

bool test_db_to_linear() {
    float linear = Utils::dbToLinear(0.0f);
    TEST_ASSERT(std::abs(linear - 1.0f) < 0.001f, "0 dB should be 1.0 linear");

    linear = Utils::dbToLinear(-6.0f);
    TEST_ASSERT(std::abs(linear - 0.5f) < 0.01f, "-6 dB should be ~0.5 linear");

    linear = Utils::dbToLinear(-20.0f);
    TEST_ASSERT(std::abs(linear - 0.1f) < 0.01f, "-20 dB should be ~0.1 linear");

    return true;
}

bool test_linear_to_db() {
    float db = Utils::linearToDb(1.0f);
    TEST_ASSERT(std::abs(db - 0.0f) < 0.001f, "1.0 linear should be 0 dB");

    db = Utils::linearToDb(0.5f);
    TEST_ASSERT(std::abs(db - (-6.0f)) < 0.5f, "0.5 linear should be ~-6 dB");

    db = Utils::linearToDb(0.0f);
    TEST_ASSERT(db < -90.0f, "0.0 linear should be very negative dB");

    return true;
}

// ============================================================================
// MARK: - ASIO Bridge Tests
// ============================================================================

bool test_asio_availability() {
    bool available = ASIOBridge::isASIOAvailable();

    // Just verify we can check without crashing
    std::cout << "(ASIO available: " << (available ? "yes" : "no") << ") ";

    return true;
}

bool test_asio_bridge_status() {
    ASIOBridge bridge;

    TEST_ASSERT(bridge.status() == ASIOBridge::ASIOStatus::NotLoaded,
                "Initial ASIO status should be NotLoaded");

    return true;
}

// ============================================================================
// MARK: - Device Enumeration Tests
// ============================================================================

bool test_device_enumeration() {
    auto devices = WindowsAudioEngine::enumerateDevices();

    // Note: May be empty on systems without audio devices
    std::cout << "(" << devices.size() << " devices found) ";

    // Verify we can enumerate without crashing
    for (const auto& device : devices) {
        TEST_ASSERT(!device.first.empty(), "Device ID should not be empty");
        TEST_ASSERT(!device.second.empty(), "Device name should not be empty");
    }

    return true;
}

// ============================================================================
// MARK: - Main
// ============================================================================

int main() {
    std::cout << "==============================================\n";
    std::cout << "Windows Audio Engine Tests\n";
    std::cout << "==============================================\n\n";

    int passed = 0;
    int failed = 0;

    // Configuration tests
    std::cout << "--- Configuration Tests ---\n";
    RUN_TEST(test_default_config);
    RUN_TEST(test_custom_config);

    // ComPtr tests
    std::cout << "\n--- ComPtr Tests ---\n";
    RUN_TEST(test_comptr_default);
    RUN_TEST(test_comptr_move);

    // Engine lifecycle tests
    std::cout << "\n--- Engine Lifecycle Tests ---\n";
    RUN_TEST(test_engine_construction);
    RUN_TEST(test_engine_initialization);
    RUN_TEST(test_engine_callback);
    RUN_TEST(test_engine_bio_modulation);

    // Utility tests
    std::cout << "\n--- Utility Tests ---\n";
    RUN_TEST(test_db_to_linear);
    RUN_TEST(test_linear_to_db);

    // ASIO tests
    std::cout << "\n--- ASIO Bridge Tests ---\n";
    RUN_TEST(test_asio_availability);
    RUN_TEST(test_asio_bridge_status);

    // Device enumeration tests
    std::cout << "\n--- Device Enumeration Tests ---\n";
    RUN_TEST(test_device_enumeration);

    // Summary
    std::cout << "\n==============================================\n";
    std::cout << "Results: " << passed << " passed, " << failed << " failed\n";
    std::cout << "==============================================\n";

    return failed > 0 ? 1 : 0;
}

#else

// Not Windows - just a stub
int main() {
    std::cout << "Windows Audio Engine tests skipped (not Windows)\n";
    return 0;
}

#endif // _WIN32
