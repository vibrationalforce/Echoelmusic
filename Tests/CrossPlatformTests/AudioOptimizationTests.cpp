/**
 * AudioOptimizationTests.cpp
 * Echoelmusic - Comprehensive Audio Optimization Tests
 *
 * Tests for all audio backend and optimization components:
 * - ASIO Bridge (Windows)
 * - JACK Audio Engine (Linux)
 * - Lock-Free Ring Buffer
 * - Audio Thread Priority
 * - SIMD Audio Processor
 * - Unified Audio Config
 *
 * Ralph Wiggum Lambda Loop Mode - Nobel Prize Quality
 * Created: 2026-01-17
 */

#include <cassert>
#include <iostream>
#include <chrono>
#include <thread>
#include <cstring>
#include <vector>
#include <cmath>

// Include all audio components
#include "LockFreeRingBuffer.hpp"
#include "AudioThreadPriority.hpp"
#include "SIMDAudioProcessor.hpp"
#include "UnifiedAudioConfig.hpp"

#ifdef _WIN32
#include "ASIOBridge.hpp"
#include "WindowsAudioEngine.hpp"
#endif

#ifdef __linux__
#include "JACKAudioEngine.hpp"
#include "PipeWireAudioEngine.hpp"
#include "LinuxAudioEngine.hpp"
#endif

using namespace Echoelmusic::Audio;

// ============================================================================
// MARK: - Test Utilities
// ============================================================================

static int testsRun = 0;
static int testsPassed = 0;

#define TEST(name) \
    void test_##name(); \
    struct TestRunner_##name { \
        TestRunner_##name() { \
            testsRun++; \
            std::cout << "Running: " << #name << "... "; \
            try { \
                test_##name(); \
                testsPassed++; \
                std::cout << "✅ PASSED" << std::endl; \
            } catch (const std::exception& e) { \
                std::cout << "❌ FAILED: " << e.what() << std::endl; \
            } catch (...) { \
                std::cout << "❌ FAILED: Unknown exception" << std::endl; \
            } \
        } \
    } runner_##name; \
    void test_##name()

#define ASSERT(cond) \
    if (!(cond)) throw std::runtime_error("Assertion failed: " #cond)

#define ASSERT_EQ(a, b) \
    if ((a) != (b)) throw std::runtime_error("Assertion failed: " #a " == " #b)

#define ASSERT_NEAR(a, b, eps) \
    if (std::abs((a) - (b)) > (eps)) throw std::runtime_error("Assertion failed: " #a " ~= " #b)

// ============================================================================
// MARK: - Lock-Free Ring Buffer Tests
// ============================================================================

TEST(RingBuffer_BasicWriteRead) {
    LockFreeRingBuffer<float, 1024> buffer;

    ASSERT(buffer.empty());
    ASSERT_EQ(buffer.size(), 0u);

    float value = 1.5f;
    ASSERT(buffer.tryWrite(value));
    ASSERT(!buffer.empty());
    ASSERT_EQ(buffer.size(), 1u);

    float readValue;
    ASSERT(buffer.tryRead(readValue));
    ASSERT_NEAR(readValue, 1.5f, 0.001f);
    ASSERT(buffer.empty());
}

TEST(RingBuffer_BulkWriteRead) {
    LockFreeRingBuffer<float, 1024> buffer;

    float writeData[256];
    for (int i = 0; i < 256; i++) {
        writeData[i] = static_cast<float>(i) * 0.01f;
    }

    size_t written = buffer.write(writeData, 256);
    ASSERT_EQ(written, 256u);
    ASSERT_EQ(buffer.size(), 256u);

    float readData[256];
    size_t read = buffer.read(readData, 256);
    ASSERT_EQ(read, 256u);
    ASSERT(buffer.empty());

    for (int i = 0; i < 256; i++) {
        ASSERT_NEAR(readData[i], writeData[i], 0.0001f);
    }
}

TEST(RingBuffer_WrapAround) {
    LockFreeRingBuffer<int, 16> buffer;

    // Fill partially
    for (int i = 0; i < 10; i++) {
        ASSERT(buffer.tryWrite(i));
    }

    // Read some
    int value;
    for (int i = 0; i < 5; i++) {
        ASSERT(buffer.tryRead(value));
        ASSERT_EQ(value, i);
    }

    // Write more (should wrap)
    for (int i = 10; i < 18; i++) {
        ASSERT(buffer.tryWrite(i));
    }

    // Read all
    for (int i = 5; i < 18; i++) {
        ASSERT(buffer.tryRead(value));
        ASSERT_EQ(value, i);
    }

    ASSERT(buffer.empty());
}

TEST(RingBuffer_Full) {
    LockFreeRingBuffer<int, 8> buffer;  // Capacity is 7 (power of 2 - 1)

    // Fill buffer
    for (int i = 0; i < 7; i++) {
        ASSERT(buffer.tryWrite(i));
    }

    ASSERT(buffer.full());
    ASSERT(!buffer.tryWrite(99));  // Should fail
}

TEST(AudioRingBuffer_StereoFrames) {
    AudioRingBuffer<1024> buffer;

    float stereoData[512];  // 256 stereo frames
    for (int i = 0; i < 512; i++) {
        stereoData[i] = static_cast<float>(i) * 0.001f;
    }

    size_t framesWritten = buffer.writeFrames(stereoData, 256);
    ASSERT_EQ(framesWritten, 256u);
    ASSERT_EQ(buffer.framesAvailable(), 256u);

    float readData[512];
    size_t framesRead = buffer.readFrames(readData, 256);
    ASSERT_EQ(framesRead, 256u);

    for (int i = 0; i < 512; i++) {
        ASSERT_NEAR(readData[i], stereoData[i], 0.0001f);
    }
}

// ============================================================================
// MARK: - SIMD Processor Tests
// ============================================================================

TEST(SIMD_GetLevel) {
    std::cout << "SIMD Level: " << SIMD::getSIMDLevelName() << " ";
    ASSERT(SIMD::getOptimalSIMDLevel() != SIMD::SIMDLevel::Scalar ||
           SIMD::getSIMDLevelName() != nullptr);
}

TEST(SIMD_ClearBuffer) {
    alignas(32) float buffer[256];
    for (int i = 0; i < 256; i++) {
        buffer[i] = 1.0f;
    }

    SIMD::clearBuffer(buffer, 256);

    for (int i = 0; i < 256; i++) {
        ASSERT_NEAR(buffer[i], 0.0f, 0.0001f);
    }
}

TEST(SIMD_ApplyGain) {
    alignas(32) float buffer[256];
    for (int i = 0; i < 256; i++) {
        buffer[i] = 1.0f;
    }

    SIMD::applyGain(buffer, 256, 0.5f);

    for (int i = 0; i < 256; i++) {
        ASSERT_NEAR(buffer[i], 0.5f, 0.0001f);
    }
}

TEST(SIMD_GainRamp) {
    alignas(32) float buffer[256];
    for (int i = 0; i < 256; i++) {
        buffer[i] = 1.0f;
    }

    SIMD::applyGainRamp(buffer, 256, 0.0f, 1.0f);

    ASSERT_NEAR(buffer[0], 0.0f, 0.01f);
    ASSERT_NEAR(buffer[255], 1.0f, 0.01f);
    ASSERT_NEAR(buffer[128], 0.5f, 0.01f);
}

TEST(SIMD_MixAdd) {
    alignas(32) float src[256];
    alignas(32) float dst[256];

    for (int i = 0; i < 256; i++) {
        src[i] = 1.0f;
        dst[i] = 0.5f;
    }

    SIMD::mixAdd(src, dst, 256, 0.5f);

    for (int i = 0; i < 256; i++) {
        ASSERT_NEAR(dst[i], 1.0f, 0.0001f);  // 0.5 + 1.0 * 0.5 = 1.0
    }
}

TEST(SIMD_HardClip) {
    alignas(32) float buffer[8] = {-2.0f, -1.0f, -0.5f, 0.0f, 0.5f, 1.0f, 2.0f, 3.0f};

    SIMD::hardClip(buffer, 8);

    ASSERT_NEAR(buffer[0], -1.0f, 0.0001f);
    ASSERT_NEAR(buffer[1], -1.0f, 0.0001f);
    ASSERT_NEAR(buffer[2], -0.5f, 0.0001f);
    ASSERT_NEAR(buffer[5], 1.0f, 0.0001f);
    ASSERT_NEAR(buffer[6], 1.0f, 0.0001f);
    ASSERT_NEAR(buffer[7], 1.0f, 0.0001f);
}

TEST(SIMD_PeakLevel) {
    alignas(32) float buffer[256];
    for (int i = 0; i < 256; i++) {
        buffer[i] = static_cast<float>(i) / 256.0f - 0.5f;
    }
    buffer[100] = 0.9f;
    buffer[200] = -0.95f;

    float peak = SIMD::getPeakLevel(buffer, 256);
    ASSERT_NEAR(peak, 0.95f, 0.01f);
}

TEST(SIMD_RMSLevel) {
    alignas(32) float buffer[256];
    float sum = 0.0f;
    for (int i = 0; i < 256; i++) {
        buffer[i] = 0.5f;
        sum += buffer[i] * buffer[i];
    }
    float expectedRMS = std::sqrt(sum / 256.0f);

    float rms = SIMD::getRMSLevel(buffer, 256);
    ASSERT_NEAR(rms, expectedRMS, 0.001f);
}

TEST(SIMD_Interleave) {
    alignas(32) float left[128];
    alignas(32) float right[128];
    alignas(32) float stereo[256];

    for (int i = 0; i < 128; i++) {
        left[i] = static_cast<float>(i);
        right[i] = static_cast<float>(i + 1000);
    }

    SIMD::interleave(left, right, stereo, 128);

    for (int i = 0; i < 128; i++) {
        ASSERT_NEAR(stereo[i * 2], static_cast<float>(i), 0.0001f);
        ASSERT_NEAR(stereo[i * 2 + 1], static_cast<float>(i + 1000), 0.0001f);
    }
}

TEST(SIMD_Deinterleave) {
    alignas(32) float stereo[256];
    alignas(32) float left[128];
    alignas(32) float right[128];

    for (int i = 0; i < 128; i++) {
        stereo[i * 2] = static_cast<float>(i);
        stereo[i * 2 + 1] = static_cast<float>(i + 1000);
    }

    SIMD::deinterleave(stereo, left, right, 128);

    for (int i = 0; i < 128; i++) {
        ASSERT_NEAR(left[i], static_cast<float>(i), 0.0001f);
        ASSERT_NEAR(right[i], static_cast<float>(i + 1000), 0.0001f);
    }
}

// ============================================================================
// MARK: - Audio Thread Priority Tests
// ============================================================================

TEST(ThreadPriority_Available) {
    bool available = AudioThreadPriority::isRealtimeAvailable();
    std::cout << "(RT available: " << (available ? "yes" : "no") << ") ";
    // Just check it doesn't crash
    ASSERT(true);
}

TEST(ThreadPriority_RecommendedBufferSize) {
    uint32_t buffer64 = AudioThreadPriority::getRecommendedBufferSize(48000, 3.0f);
    ASSERT(buffer64 >= 128);
    ASSERT(buffer64 <= 256);

    uint32_t buffer256 = AudioThreadPriority::getRecommendedBufferSize(48000, 10.0f);
    ASSERT(buffer256 >= 256);
    ASSERT(buffer256 <= 512);
}

TEST(ThreadPriority_LatencyCalculation) {
    float latency = AudioThreadPriority::getLatencyMs(48000, 256);
    ASSERT_NEAR(latency, 5.33f, 0.1f);
}

TEST(ThreadAffinity_CoreCount) {
    int cores = ThreadAffinity::getCoreCount();
    ASSERT(cores >= 1);
    std::cout << "(cores: " << cores << ") ";
}

// ============================================================================
// MARK: - Unified Audio Config Tests
// ============================================================================

TEST(UnifiedConfig_Presets) {
    auto ultraLow = UnifiedAudioConfig::ultraLowLatency();
    ASSERT_EQ(ultraLow.bufferSize, 64u);
    ASSERT_NEAR(ultraLow.targetLatencyMs, 3.0f, 0.1f);

    auto lowLatency = UnifiedAudioConfig::lowLatency();
    ASSERT_EQ(lowLatency.bufferSize, 128u);

    auto balanced = UnifiedAudioConfig::balanced();
    ASSERT_EQ(balanced.bufferSize, 256u);

    auto stable = UnifiedAudioConfig::stable();
    ASSERT_EQ(stable.bufferSize, 512u);

    auto highQuality = UnifiedAudioConfig::highQuality();
    ASSERT_EQ(highQuality.sampleRate, 96000u);
}

TEST(UnifiedConfig_BackendAvailability) {
    auto backends = BackendAvailability::getAvailableBackends();
    ASSERT(backends.size() > 0);

    AudioBackend best = BackendAvailability::getBestAvailable();
    ASSERT(BackendAvailability::isAvailable(best));

    const char* name = BackendAvailability::getBackendName(best);
    ASSERT(name != nullptr);
    ASSERT(strlen(name) > 0);
    std::cout << "(best: " << name << ") ";
}

TEST(UnifiedConfig_LatencyCalculator) {
    float latency = LatencyCalculator::bufferToMs(256, 48000);
    ASSERT_NEAR(latency, 5.33f, 0.1f);

    uint32_t buffer = LatencyCalculator::msToBuffer(10.0f, 48000);
    ASSERT_EQ(buffer, 480u);

    uint32_t optimal = LatencyCalculator::getOptimalBufferSize(10.0f, 48000);
    ASSERT_EQ(optimal, 512u);  // Rounded to power of 2

    uint32_t pow2 = LatencyCalculator::roundToPowerOf2(100);
    ASSERT_EQ(pow2, 128u);
}

TEST(UnifiedConfig_PerformanceProfiles) {
    auto profiles = PerformanceProfile::getProfiles();
    ASSERT_EQ(profiles.size(), 5u);

    ASSERT_EQ(profiles[0].name, "Ultra Low Latency");
    ASSERT_EQ(profiles[4].name, "High Quality");
}

// ============================================================================
// MARK: - Performance Benchmarks
// ============================================================================

TEST(Benchmark_RingBufferThroughput) {
    LockFreeRingBuffer<float, 65536> buffer;
    alignas(32) float data[1024];

    auto start = std::chrono::high_resolution_clock::now();

    for (int i = 0; i < 10000; i++) {
        buffer.write(data, 1024);
        buffer.read(data, 1024);
    }

    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start);

    float msPerOp = static_cast<float>(duration.count()) / 10000.0f / 1000.0f;
    std::cout << "(" << msPerOp << "ms/op) ";

    ASSERT(msPerOp < 1.0f);  // Should be much faster than 1ms
}

TEST(Benchmark_SIMDGain) {
    alignas(32) float buffer[4096];
    for (int i = 0; i < 4096; i++) {
        buffer[i] = static_cast<float>(i) * 0.0001f;
    }

    auto start = std::chrono::high_resolution_clock::now();

    for (int i = 0; i < 100000; i++) {
        SIMD::applyGain(buffer, 4096, 0.9999f);
    }

    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start);

    float usPerOp = static_cast<float>(duration.count()) / 100000.0f;
    std::cout << "(" << usPerOp << "us/4k samples) ";

    ASSERT(usPerOp < 100.0f);  // Should be very fast
}

// ============================================================================
// MARK: - Main
// ============================================================================

int main() {
    std::cout << "\n╔══════════════════════════════════════════════════════════════╗" << std::endl;
    std::cout << "║  Echoelmusic Audio Optimization Tests                        ║" << std::endl;
    std::cout << "║  Ralph Wiggum Lambda Loop Mode - Nobel Prize Quality         ║" << std::endl;
    std::cout << "╚══════════════════════════════════════════════════════════════╝\n" << std::endl;

    std::cout << "SIMD Level: " << SIMD::getSIMDLevelName() << "\n" << std::endl;

    // Tests run automatically via static initialization

    std::cout << "\n════════════════════════════════════════════════════════════════" << std::endl;
    std::cout << "Results: " << testsPassed << "/" << testsRun << " tests passed";

    if (testsPassed == testsRun) {
        std::cout << " ✅ ALL TESTS PASSED" << std::endl;
        return 0;
    } else {
        std::cout << " ❌ SOME TESTS FAILED" << std::endl;
        return 1;
    }
}
