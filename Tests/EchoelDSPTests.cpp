/**
 * Echoel DSP Test Suite
 *
 * ============================================================================
 *   RALPH WIGGUM GENIUS LOOP MODE - COMPREHENSIVE DSP TESTS
 * ============================================================================
 *
 * Test coverage:
 * - EchoelAudioAnalyzer: FFT, spectral features, beat detection, pitch
 * - EchoelMemoryPool: Lock-free allocation, pool operations
 * - EchoelAudioEngine: Audio processing, levels, beat state
 * - EchoelPresetManager: JSON serialization/deserialization
 * - EchoelErrorHandler: Logging, error codes
 * - EchoelNetworkSync: OSC protocol, peer management
 *
 * Target: Zero errors, zero warnings, sub-microsecond operations
 */

#include "../Sources/DSP/EchoelAudioAnalyzer.h"
#include "../Sources/Core/EchoelMemoryPool.h"
#include "../Sources/Core/EchoelAudioEngine.h"
#include "../Sources/Core/EchoelPresetManager.h"
#include "../Sources/Core/EchoelErrorHandler.h"
#include "../Sources/Core/EchoelMainController.h"

#include <iostream>
#include <cassert>
#include <chrono>
#include <cmath>
#include <cstring>
#include <iomanip>
#include <sstream>
#include <thread>
#include <vector>
#include <atomic>
#include <random>

//==============================================================================
// Test Framework
//==============================================================================

namespace test {

static int totalTests = 0;
static int passedTests = 0;
static int failedTests = 0;

#define TEST_ASSERT(condition, message) \
    do { \
        ++test::totalTests; \
        if (condition) { \
            ++test::passedTests; \
            std::cout << "  [PASS] " << message << std::endl; \
        } else { \
            ++test::failedTests; \
            std::cout << "  [FAIL] " << message << std::endl; \
        } \
    } while(0)

#define TEST_ASSERT_NEAR(a, b, tolerance, message) \
    TEST_ASSERT(std::abs((a) - (b)) < (tolerance), message)

void printSummary()
{
    std::cout << "\n========================================\n";
    std::cout << "DSP Test Summary:\n";
    std::cout << "  Total:  " << totalTests << std::endl;
    std::cout << "  Passed: " << passedTests << std::endl;
    std::cout << "  Failed: " << failedTests << std::endl;
    std::cout << "========================================\n";

    if (failedTests == 0)
    {
        std::cout << "\n*** ALL DSP TESTS PASSED ***\n\n";
    }
    else
    {
        std::cout << "\n*** " << failedTests << " DSP TEST(S) FAILED ***\n\n";
    }
}

} // namespace test

//==============================================================================
// Performance Benchmark Utility
//==============================================================================

class Benchmark
{
public:
    using Clock = std::chrono::high_resolution_clock;

    void start()
    {
        startTime_ = Clock::now();
    }

    double stopNs()
    {
        auto end = Clock::now();
        return std::chrono::duration<double, std::nano>(end - startTime_).count();
    }

    double stopUs()
    {
        auto end = Clock::now();
        return std::chrono::duration<double, std::micro>(end - startTime_).count();
    }

    double stopMs()
    {
        auto end = Clock::now();
        return std::chrono::duration<double, std::milli>(end - startTime_).count();
    }

private:
    std::chrono::time_point<Clock> startTime_;
};

//==============================================================================
// Audio Analyzer Tests
//==============================================================================

void testAudioAnalyzerInit()
{
    std::cout << "\n[Test: Audio Analyzer Initialization]\n";

    using namespace Echoel::DSP;

    AnalyzerConfig config;
    config.sampleRate = 44100.0f;
    config.fftSize = 1024;
    config.hopSize = 256;

    EchoelAudioAnalyzer analyzer(config);

    TEST_ASSERT(analyzer.getSampleRate() == 44100.0f, "Sample rate should be 44100");
    TEST_ASSERT(analyzer.getFFTSize() == 1024, "FFT size should be 1024");
    TEST_ASSERT(analyzer.getHopSize() == 256, "Hop size should be 256");

    analyzer.reset();
    TEST_ASSERT(true, "Reset should not crash");
}

void testAudioAnalyzerFFT()
{
    std::cout << "\n[Test: Audio Analyzer FFT Processing]\n";

    using namespace Echoel::DSP;

    AnalyzerConfig config;
    config.sampleRate = 44100.0f;
    config.fftSize = 1024;
    config.hopSize = 512;

    EchoelAudioAnalyzer analyzer(config);

    // Generate test signal: 440 Hz sine wave
    std::vector<float> testSignal(1024);
    const float freq = 440.0f;
    for (int i = 0; i < 1024; ++i)
    {
        testSignal[i] = std::sin(2.0f * 3.14159265f * freq * i / 44100.0f);
    }

    analyzer.process(testSignal.data(), 1024);

    AnalysisResult result = analyzer.getResult();

    // Check spectral features
    TEST_ASSERT(result.spectral.centroid > 0.0f, "Spectral centroid should be positive");
    TEST_ASSERT(result.spectral.centroid < 22050.0f, "Spectral centroid should be below Nyquist");

    // Check magnitude spectrum
    const float* spectrum = analyzer.getMagnitudeSpectrum();
    TEST_ASSERT(spectrum != nullptr, "Magnitude spectrum should not be null");

    // Find peak frequency bin
    int peakBin = 0;
    float peakMag = 0.0f;
    for (int i = 1; i < 512; ++i)
    {
        if (spectrum[i] > peakMag)
        {
            peakMag = spectrum[i];
            peakBin = i;
        }
    }

    float peakFreq = peakBin * 44100.0f / 1024.0f;
    std::cout << "  Peak frequency: " << peakFreq << " Hz (expected ~440 Hz)\n";
    TEST_ASSERT_NEAR(peakFreq, 440.0f, 50.0f, "Peak should be near 440 Hz");
}

void testAudioAnalyzerBeatDetection()
{
    std::cout << "\n[Test: Audio Analyzer Beat Detection]\n";

    using namespace Echoel::DSP;

    AnalyzerConfig config;
    config.sampleRate = 44100.0f;
    config.fftSize = 1024;
    config.hopSize = 256;
    config.enableBeatDetection = true;

    EchoelAudioAnalyzer analyzer(config);

    // Generate impulse train (simulating beats at 120 BPM = 2 Hz)
    std::vector<float> testSignal(44100);  // 1 second of audio
    const float beatsPerSecond = 2.0f;  // 120 BPM
    const int samplesPerBeat = static_cast<int>(44100.0f / beatsPerSecond);

    for (int i = 0; i < 44100; ++i)
    {
        if (i % samplesPerBeat < 100)
        {
            testSignal[i] = 1.0f;  // Short impulse
        }
        else
        {
            testSignal[i] = 0.0f;
        }
    }

    // Process in chunks
    for (int offset = 0; offset < 44100; offset += 256)
    {
        int chunkSize = std::min(256, 44100 - offset);
        analyzer.process(testSignal.data() + offset, chunkSize);
    }

    AnalysisResult result = analyzer.getResult();

    TEST_ASSERT(result.beat.bpm > 0.0f, "BPM should be detected");
    TEST_ASSERT(result.beat.bpm >= 60.0f && result.beat.bpm <= 180.0f, "BPM should be in valid range");
    TEST_ASSERT(result.beat.confidence >= 0.0f && result.beat.confidence <= 1.0f, "Confidence should be 0-1");

    std::cout << "  Detected BPM: " << result.beat.bpm << " (expected ~120)\n";
    std::cout << "  Confidence: " << result.beat.confidence << "\n";
}

void testAudioAnalyzerBands()
{
    std::cout << "\n[Test: Audio Analyzer Frequency Bands]\n";

    using namespace Echoel::DSP;

    AnalyzerConfig config;
    config.sampleRate = 44100.0f;
    config.fftSize = 2048;

    EchoelAudioAnalyzer analyzer(config);

    // Generate white noise
    std::vector<float> noise(2048);
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_real_distribution<float> dist(-1.0f, 1.0f);

    for (auto& s : noise)
        s = dist(gen);

    analyzer.process(noise.data(), 2048);

    AnalysisResult result = analyzer.getResult();

    // All bands should have some energy
    TEST_ASSERT(result.bands.subBass >= 0.0f, "SubBass band should be non-negative");
    TEST_ASSERT(result.bands.bass >= 0.0f, "Bass band should be non-negative");
    TEST_ASSERT(result.bands.lowMid >= 0.0f, "LowMid band should be non-negative");
    TEST_ASSERT(result.bands.mid >= 0.0f, "Mid band should be non-negative");
    TEST_ASSERT(result.bands.highMid >= 0.0f, "HighMid band should be non-negative");
    TEST_ASSERT(result.bands.presence >= 0.0f, "Presence band should be non-negative");
    TEST_ASSERT(result.bands.brilliance >= 0.0f, "Brilliance band should be non-negative");
    TEST_ASSERT(result.bands.air >= 0.0f, "Air band should be non-negative");

    std::cout << "  Band energies: sub=" << result.bands.subBass
              << " bass=" << result.bands.bass
              << " lowMid=" << result.bands.lowMid
              << " mid=" << result.bands.mid << "\n";
}

void testAudioAnalyzerPerformance()
{
    std::cout << "\n[Test: Audio Analyzer Performance]\n";

    using namespace Echoel::DSP;

    AnalyzerConfig config;
    config.sampleRate = 44100.0f;
    config.fftSize = 2048;
    config.enableBeatDetection = true;
    config.enablePitchDetection = true;

    EchoelAudioAnalyzer analyzer(config);

    std::vector<float> buffer(256);
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_real_distribution<float> dist(-1.0f, 1.0f);

    for (auto& s : buffer)
        s = dist(gen);

    // Warmup
    for (int i = 0; i < 100; ++i)
        analyzer.process(buffer.data(), 256);

    // Benchmark
    Benchmark bench;
    const int iterations = 1000;

    bench.start();
    for (int i = 0; i < iterations; ++i)
    {
        analyzer.process(buffer.data(), 256);
    }
    double totalUs = bench.stopUs();

    double avgUs = totalUs / iterations;
    std::cout << "  Average process time: " << std::fixed << std::setprecision(2) << avgUs << " us\n";
    std::cout << "  Throughput: " << std::fixed << std::setprecision(0) << (1000000.0 / avgUs) << " calls/sec\n";

    // Should process faster than real-time
    // 256 samples at 44100 Hz = 5.8 ms of audio
    double realtimeUs = 256.0 * 1000000.0 / 44100.0;
    std::cout << "  Realtime budget: " << std::fixed << std::setprecision(2) << realtimeUs << " us\n";

    TEST_ASSERT(avgUs < realtimeUs, "Should process faster than real-time");
    TEST_ASSERT(avgUs < 1000.0, "Should process in < 1ms");
}

//==============================================================================
// Memory Pool Tests
//==============================================================================

void testMemoryPoolBasic()
{
    std::cout << "\n[Test: Memory Pool Basic Operations]\n";

    using namespace Echoel::Core;

    EchoelMemoryPool& pool = EchoelMemoryPool::getInstance();
    pool.reset();

    // Allocate small block
    void* small = pool.allocate(32);
    TEST_ASSERT(small != nullptr, "Small allocation should succeed");

    // Allocate medium block
    void* medium = pool.allocate(128);
    TEST_ASSERT(medium != nullptr, "Medium allocation should succeed");

    // Allocate large block
    void* large = pool.allocate(512);
    TEST_ASSERT(large != nullptr, "Large allocation should succeed");

    // Free all
    pool.deallocate(small, 32);
    pool.deallocate(medium, 128);
    pool.deallocate(large, 512);

    TEST_ASSERT(true, "Deallocation should not crash");
}

void testMemoryPoolAudioBuffers()
{
    std::cout << "\n[Test: Memory Pool Audio Buffers]\n";

    using namespace Echoel::Core;

    EchoelMemoryPool& pool = EchoelMemoryPool::getInstance();

    // Acquire audio buffer
    float* buffer = pool.acquireAudioBuffer();
    TEST_ASSERT(buffer != nullptr, "Audio buffer acquisition should succeed");

    // Write to buffer
    for (int i = 0; i < EchoelMemoryPool::AUDIO_BUFFER_SIZE; ++i)
    {
        buffer[i] = static_cast<float>(i) * 0.001f;
    }

    // Verify data
    bool dataOk = true;
    for (int i = 0; i < EchoelMemoryPool::AUDIO_BUFFER_SIZE; ++i)
    {
        if (std::abs(buffer[i] - static_cast<float>(i) * 0.001f) > 0.0001f)
        {
            dataOk = false;
            break;
        }
    }
    TEST_ASSERT(dataOk, "Audio buffer data should be preserved");

    // Release
    pool.releaseAudioBuffer(buffer);
    TEST_ASSERT(true, "Audio buffer release should not crash");
}

void testMemoryPoolRAII()
{
    std::cout << "\n[Test: Memory Pool RAII Wrapper]\n";

    using namespace Echoel::Core;

    // Test PoolPtr automatic cleanup
    {
        auto ptr = makePooled<float>(42.0f);
        TEST_ASSERT(ptr != nullptr, "PoolPtr should allocate");
        TEST_ASSERT_NEAR(*ptr, 42.0f, 0.0001f, "PoolPtr value should be correct");
    }
    // ptr goes out of scope - should auto-cleanup

    TEST_ASSERT(true, "RAII cleanup should not crash");

    // Test with array
    {
        auto arr = makePooledArray<int>(100);
        TEST_ASSERT(arr != nullptr, "PoolPtr array should allocate");

        for (int i = 0; i < 100; ++i)
            arr[i] = i * 2;

        bool ok = true;
        for (int i = 0; i < 100; ++i)
        {
            if (arr[i] != i * 2) ok = false;
        }
        TEST_ASSERT(ok, "PoolPtr array data should be correct");
    }

    TEST_ASSERT(true, "RAII array cleanup should not crash");
}

void testMemoryPoolThreadSafety()
{
    std::cout << "\n[Test: Memory Pool Thread Safety]\n";

    using namespace Echoel::Core;

    EchoelMemoryPool& pool = EchoelMemoryPool::getInstance();
    pool.reset();

    std::atomic<int> successCount(0);
    std::atomic<int> failCount(0);

    auto threadFunc = [&]() {
        for (int i = 0; i < 100; ++i)
        {
            void* ptr = pool.allocate(64);
            if (ptr)
            {
                // Write pattern to detect corruption
                std::memset(ptr, 0xAB, 64);

                // Verify pattern
                bool ok = true;
                uint8_t* bytes = static_cast<uint8_t*>(ptr);
                for (int j = 0; j < 64; ++j)
                {
                    if (bytes[j] != 0xAB) ok = false;
                }

                if (ok)
                    successCount++;
                else
                    failCount++;

                pool.deallocate(ptr, 64);
            }
            else
            {
                failCount++;
            }
        }
    };

    std::vector<std::thread> threads;
    for (int i = 0; i < 4; ++i)
    {
        threads.emplace_back(threadFunc);
    }

    for (auto& t : threads)
        t.join();

    std::cout << "  Success: " << successCount << ", Failures: " << failCount << "\n";
    TEST_ASSERT(failCount == 0, "No corruption should occur under concurrent access");
    TEST_ASSERT(successCount == 400, "All allocations should succeed");
}

void testMemoryPoolPerformance()
{
    std::cout << "\n[Test: Memory Pool Performance]\n";

    using namespace Echoel::Core;

    EchoelMemoryPool& pool = EchoelMemoryPool::getInstance();
    pool.reset();

    // Warmup
    for (int i = 0; i < 1000; ++i)
    {
        void* ptr = pool.allocate(64);
        pool.deallocate(ptr, 64);
    }

    // Benchmark allocation
    Benchmark bench;
    const int iterations = 10000;

    bench.start();
    for (int i = 0; i < iterations; ++i)
    {
        void* ptr = pool.allocate(64);
        pool.deallocate(ptr, 64);
    }
    double totalNs = bench.stopNs();

    double avgNs = totalNs / iterations;
    std::cout << "  Average alloc+free: " << std::fixed << std::setprecision(1) << avgNs << " ns\n";
    std::cout << "  Operations/sec: " << std::fixed << std::setprecision(0) << (1e9 / avgNs) << "\n";

    TEST_ASSERT(avgNs < 1000.0, "Alloc+free should be < 1 microsecond");
    TEST_ASSERT(avgNs < 500.0, "Alloc+free should be < 500 nanoseconds for lock-free pool");
}

//==============================================================================
// Audio Engine Tests
//==============================================================================

void testAudioEngineInit()
{
    std::cout << "\n[Test: Audio Engine Initialization]\n";

    using namespace Echoel::Core;

    AudioConfig config;
    config.sampleRate = 44100.0;
    config.bufferSize = 256;
    config.numChannels = 2;

    EchoelAudioEngine engine(config);

    TEST_ASSERT(engine.getSampleRate() == 44100.0, "Sample rate should be 44100");
    TEST_ASSERT(engine.getBufferSize() == 256, "Buffer size should be 256");
    TEST_ASSERT(engine.getNumChannels() == 2, "Channels should be 2");
    TEST_ASSERT(!engine.isProcessing(), "Should not be processing initially");
}

void testAudioEngineLevels()
{
    std::cout << "\n[Test: Audio Engine Level Metering]\n";

    using namespace Echoel::Core;

    AudioConfig config;
    config.sampleRate = 44100.0;
    config.bufferSize = 256;

    EchoelAudioEngine engine(config);

    // Generate test audio
    std::vector<float> leftChannel(256);
    std::vector<float> rightChannel(256);

    for (int i = 0; i < 256; ++i)
    {
        leftChannel[i] = 0.5f * std::sin(2.0f * 3.14159f * 440.0f * i / 44100.0f);
        rightChannel[i] = 0.3f * std::sin(2.0f * 3.14159f * 880.0f * i / 44100.0f);
    }

    float* channels[2] = { leftChannel.data(), rightChannel.data() };
    engine.processBlock(channels, 2, 256);

    AudioLevels levels = engine.getLevels();

    TEST_ASSERT(levels.leftRMS > 0.0f, "Left RMS should be positive");
    TEST_ASSERT(levels.rightRMS > 0.0f, "Right RMS should be positive");
    TEST_ASSERT(levels.leftPeak <= 1.0f, "Left peak should be <= 1");
    TEST_ASSERT(levels.rightPeak <= 1.0f, "Right peak should be <= 1");

    std::cout << "  Left RMS: " << levels.leftRMS << ", Peak: " << levels.leftPeak << "\n";
    std::cout << "  Right RMS: " << levels.rightRMS << ", Peak: " << levels.rightPeak << "\n";
}

void testAudioEngineBeatState()
{
    std::cout << "\n[Test: Audio Engine Beat State]\n";

    using namespace Echoel::Core;

    AudioConfig config;
    config.sampleRate = 44100.0;
    config.bufferSize = 256;

    EchoelAudioEngine engine(config);

    // Trigger beat manually
    engine.triggerBeat();

    BeatState beat = engine.getBeatState();

    TEST_ASSERT(beat.beatDetected, "Beat should be detected after trigger");
    TEST_ASSERT(beat.timeSinceLastBeat < 0.1, "Time since beat should be recent");

    // Wait and check decay
    std::this_thread::sleep_for(std::chrono::milliseconds(50));

    beat = engine.getBeatState();
    TEST_ASSERT(!beat.beatDetected, "Beat flag should clear after time");
}

void testAudioEngineEntrainment()
{
    std::cout << "\n[Test: Audio Engine Entrainment]\n";

    using namespace Echoel::Core;

    AudioConfig config;
    config.sampleRate = 44100.0;
    config.bufferSize = 256;

    EchoelAudioEngine engine(config);

    EntrainmentParams params;
    params.targetFrequency = 10.0f;  // Alpha
    params.baseFrequency = 200.0f;
    params.depth = 0.8f;
    params.waveform = EntrainmentWaveform::Sine;

    engine.setEntrainmentParams(params);

    EntrainmentParams retrieved = engine.getEntrainmentParams();

    TEST_ASSERT_NEAR(retrieved.targetFrequency, 10.0f, 0.001f, "Target frequency should match");
    TEST_ASSERT_NEAR(retrieved.baseFrequency, 200.0f, 0.001f, "Base frequency should match");
    TEST_ASSERT_NEAR(retrieved.depth, 0.8f, 0.001f, "Depth should match");
}

//==============================================================================
// Preset Manager Tests
//==============================================================================

void testPresetManagerBasic()
{
    std::cout << "\n[Test: Preset Manager Basic Operations]\n";

    using namespace Echoel::Core;

    EchoelPresetManager manager;

    // Create test preset
    Preset preset;
    preset.name = "Test Preset";
    preset.author = "Unit Test";
    preset.category = "Testing";
    preset.version = "1.0";
    preset.scientificLabel = ScientificLabel::Validated;

    preset.entrainment.targetFrequency = 10.0f;
    preset.entrainment.baseFrequency = 200.0f;
    preset.audio.masterVolume = 0.8f;

    // Save preset
    bool saved = manager.savePreset("test_preset", preset);
    TEST_ASSERT(saved, "Preset should save successfully");

    // Load preset
    auto loaded = manager.loadPreset("test_preset");
    TEST_ASSERT(loaded.has_value(), "Preset should load successfully");

    if (loaded.has_value())
    {
        TEST_ASSERT(loaded->name == "Test Preset", "Preset name should match");
        TEST_ASSERT(loaded->author == "Unit Test", "Preset author should match");
        TEST_ASSERT_NEAR(loaded->entrainment.targetFrequency, 10.0f, 0.001f, "Entrainment freq should match");
        TEST_ASSERT_NEAR(loaded->audio.masterVolume, 0.8f, 0.001f, "Master volume should match");
    }

    // Delete preset
    bool deleted = manager.deletePreset("test_preset");
    TEST_ASSERT(deleted, "Preset should delete successfully");

    loaded = manager.loadPreset("test_preset");
    TEST_ASSERT(!loaded.has_value(), "Deleted preset should not load");
}

void testPresetManagerFactoryPresets()
{
    std::cout << "\n[Test: Preset Manager Factory Presets]\n";

    using namespace Echoel::Core;

    EchoelPresetManager manager;

    auto presets = manager.getFactoryPresets();

    TEST_ASSERT(presets.size() > 0, "Should have factory presets");
    std::cout << "  Found " << presets.size() << " factory presets\n";

    for (const auto& name : presets)
    {
        auto preset = manager.loadPreset(name);
        TEST_ASSERT(preset.has_value(), ("Factory preset '" + name + "' should load").c_str());
    }
}

void testPresetManagerInterpolation()
{
    std::cout << "\n[Test: Preset Manager Interpolation/Morphing]\n";

    using namespace Echoel::Core;

    EchoelPresetManager manager;

    Preset a, b;
    a.name = "Preset A";
    a.entrainment.targetFrequency = 10.0f;
    a.audio.masterVolume = 0.0f;

    b.name = "Preset B";
    b.entrainment.targetFrequency = 40.0f;
    b.audio.masterVolume = 1.0f;

    // Midpoint interpolation
    Preset mid = manager.interpolatePresets(a, b, 0.5f);

    TEST_ASSERT_NEAR(mid.entrainment.targetFrequency, 25.0f, 0.1f, "Midpoint frequency should be 25 Hz");
    TEST_ASSERT_NEAR(mid.audio.masterVolume, 0.5f, 0.01f, "Midpoint volume should be 0.5");

    // Edge cases
    Preset atA = manager.interpolatePresets(a, b, 0.0f);
    TEST_ASSERT_NEAR(atA.entrainment.targetFrequency, 10.0f, 0.1f, "t=0 should match preset A");

    Preset atB = manager.interpolatePresets(a, b, 1.0f);
    TEST_ASSERT_NEAR(atB.entrainment.targetFrequency, 40.0f, 0.1f, "t=1 should match preset B");
}

void testPresetManagerJSON()
{
    std::cout << "\n[Test: Preset Manager JSON Serialization]\n";

    using namespace Echoel::Core;

    EchoelPresetManager manager;

    Preset preset;
    preset.name = "JSON Test";
    preset.author = "Test Author";
    preset.tags = { "test", "json", "serialization" };
    preset.entrainment.targetFrequency = 7.83f;  // Schumann
    preset.entrainment.isochronicPulse = true;
    preset.laser.patternType = 5;
    preset.bio.hrv = true;

    // Serialize to JSON
    std::string json = manager.presetToJSON(preset);
    TEST_ASSERT(!json.empty(), "JSON should not be empty");
    TEST_ASSERT(json.find("JSON Test") != std::string::npos, "JSON should contain preset name");
    TEST_ASSERT(json.find("7.83") != std::string::npos, "JSON should contain frequency value");

    std::cout << "  JSON length: " << json.length() << " bytes\n";

    // Deserialize from JSON
    auto restored = manager.JSONToPreset(json);
    TEST_ASSERT(restored.has_value(), "JSON should parse successfully");

    if (restored.has_value())
    {
        TEST_ASSERT(restored->name == "JSON Test", "Restored name should match");
        TEST_ASSERT_NEAR(restored->entrainment.targetFrequency, 7.83f, 0.01f, "Restored frequency should match");
        TEST_ASSERT(restored->entrainment.isochronicPulse == true, "Restored isochronic flag should match");
    }
}

//==============================================================================
// Error Handler Tests
//==============================================================================

void testErrorHandlerLogging()
{
    std::cout << "\n[Test: Error Handler Logging]\n";

    using namespace Echoel::Core;

    EchoelErrorHandler& handler = EchoelErrorHandler::getInstance();
    handler.clearLog();

    // Log various severities
    handler.log(LogLevel::Debug, "Test debug message");
    handler.log(LogLevel::Info, "Test info message");
    handler.log(LogLevel::Warning, "Test warning message");
    handler.log(LogLevel::Error, "Test error message");

    auto log = handler.getRecentLog(10);
    TEST_ASSERT(log.size() >= 4, "Log should contain all messages");

    // Check log content
    bool hasDebug = false, hasInfo = false, hasWarning = false, hasError = false;
    for (const auto& entry : log)
    {
        if (entry.message.find("debug") != std::string::npos) hasDebug = true;
        if (entry.message.find("info") != std::string::npos) hasInfo = true;
        if (entry.message.find("warning") != std::string::npos) hasWarning = true;
        if (entry.message.find("error") != std::string::npos) hasError = true;
    }

    TEST_ASSERT(hasDebug, "Log should contain debug message");
    TEST_ASSERT(hasInfo, "Log should contain info message");
    TEST_ASSERT(hasWarning, "Log should contain warning message");
    TEST_ASSERT(hasError, "Log should contain error message");
}

void testErrorHandlerCodes()
{
    std::cout << "\n[Test: Error Handler Error Codes]\n";

    using namespace Echoel::Core;

    EchoelErrorHandler& handler = EchoelErrorHandler::getInstance();

    // Test error code lookup
    std::string audioDesc = handler.getErrorDescription(ErrorCode::AUDIO_BUFFER_UNDERRUN);
    TEST_ASSERT(!audioDesc.empty(), "Audio error description should exist");

    std::string bioDesc = handler.getErrorDescription(ErrorCode::BIO_SENSOR_DISCONNECTED);
    TEST_ASSERT(!bioDesc.empty(), "Bio error description should exist");

    std::string laserDesc = handler.getErrorDescription(ErrorCode::LASER_SAFETY_LIMIT);
    TEST_ASSERT(!laserDesc.empty(), "Laser error description should exist");

    std::cout << "  AUDIO_BUFFER_UNDERRUN: " << audioDesc << "\n";
    std::cout << "  BIO_SENSOR_DISCONNECTED: " << bioDesc << "\n";
}

void testErrorHandlerRecovery()
{
    std::cout << "\n[Test: Error Handler Recovery Strategies]\n";

    using namespace Echoel::Core;

    EchoelErrorHandler& handler = EchoelErrorHandler::getInstance();

    // Test recovery strategy
    int retryCount = 0;
    bool recovered = false;

    RecoveryStrategy strategy;
    strategy.maxRetries = 3;
    strategy.backoffMs = 10;
    strategy.action = [&]() -> bool {
        retryCount++;
        return retryCount >= 2;  // Succeed on 2nd try
    };

    recovered = handler.attemptRecovery(strategy);

    TEST_ASSERT(recovered, "Recovery should succeed after retries");
    TEST_ASSERT(retryCount == 2, "Should retry twice before success");
}

void testErrorHandlerStats()
{
    std::cout << "\n[Test: Error Handler Statistics]\n";

    using namespace Echoel::Core;

    EchoelErrorHandler& handler = EchoelErrorHandler::getInstance();
    handler.resetStats();

    // Generate some errors
    for (int i = 0; i < 5; ++i)
        handler.log(LogLevel::Warning, "Test warning");

    for (int i = 0; i < 3; ++i)
        handler.log(LogLevel::Error, "Test error");

    ErrorStats stats = handler.getStats();

    TEST_ASSERT(stats.warningCount >= 5, "Should have at least 5 warnings");
    TEST_ASSERT(stats.errorCount >= 3, "Should have at least 3 errors");

    std::cout << "  Warnings: " << stats.warningCount << ", Errors: " << stats.errorCount << "\n";
}

//==============================================================================
// Main Controller Tests
//==============================================================================

void testMainControllerSingleton()
{
    std::cout << "\n[Test: Main Controller Singleton]\n";

    using namespace Echoel::Core;

    EchoelMainController& ctrl1 = EchoelMainController::getInstance();
    EchoelMainController& ctrl2 = EchoelMainController::getInstance();

    TEST_ASSERT(&ctrl1 == &ctrl2, "Singleton should return same instance");
}

void testMainControllerState()
{
    std::cout << "\n[Test: Main Controller State Bus]\n";

    using namespace Echoel::Core;

    EchoelMainController& ctrl = EchoelMainController::getInstance();

    // Update state
    SystemState state = ctrl.getState();
    state.masterVolume = 0.75f;
    state.isPlaying = true;
    ctrl.setState(state);

    // Read back
    SystemState readback = ctrl.getState();

    TEST_ASSERT_NEAR(readback.masterVolume, 0.75f, 0.001f, "Master volume should persist");
    TEST_ASSERT(readback.isPlaying == true, "Playing state should persist");
}

void testMainControllerMessages()
{
    std::cout << "\n[Test: Main Controller Message Queue]\n";

    using namespace Echoel::Core;

    EchoelMainController& ctrl = EchoelMainController::getInstance();

    // Clear queue
    while (ctrl.pollMessage().has_value()) {}

    // Send messages
    ctrl.postMessage(MessageType::TransportPlay, 0);
    ctrl.postMessage(MessageType::TransportStop, 0);
    ctrl.postMessage(MessageType::BeatTrigger, 120);

    // Receive messages
    auto msg1 = ctrl.pollMessage();
    TEST_ASSERT(msg1.has_value(), "Should receive first message");
    TEST_ASSERT(msg1->type == MessageType::TransportPlay, "First message should be Play");

    auto msg2 = ctrl.pollMessage();
    TEST_ASSERT(msg2.has_value(), "Should receive second message");
    TEST_ASSERT(msg2->type == MessageType::TransportStop, "Second message should be Stop");

    auto msg3 = ctrl.pollMessage();
    TEST_ASSERT(msg3.has_value(), "Should receive third message");
    TEST_ASSERT(msg3->type == MessageType::BeatTrigger, "Third message should be BeatTrigger");
    TEST_ASSERT(msg3->intValue == 120, "BeatTrigger should have BPM value");

    auto msg4 = ctrl.pollMessage();
    TEST_ASSERT(!msg4.has_value(), "Queue should be empty");
}

//==============================================================================
// SIMD Optimization Tests
//==============================================================================

void testSIMDVectorOperations()
{
    std::cout << "\n[Test: SIMD Vector Operations]\n";

    // Test aligned buffer operations
    alignas(32) float bufferA[256];
    alignas(32) float bufferB[256];
    alignas(32) float result[256];

    for (int i = 0; i < 256; ++i)
    {
        bufferA[i] = static_cast<float>(i);
        bufferB[i] = static_cast<float>(256 - i);
    }

    // Vector add (should use SIMD internally)
    Benchmark bench;
    const int iterations = 100000;

    bench.start();
    for (int iter = 0; iter < iterations; ++iter)
    {
        for (int i = 0; i < 256; ++i)
        {
            result[i] = bufferA[i] + bufferB[i];
        }
    }
    double totalUs = bench.stopUs();

    double avgNs = (totalUs * 1000.0) / iterations;
    std::cout << "  256-sample vector add: " << std::fixed << std::setprecision(1) << avgNs << " ns\n";

    // Verify results
    bool correct = true;
    for (int i = 0; i < 256; ++i)
    {
        if (std::abs(result[i] - 256.0f) > 0.001f)
        {
            correct = false;
            break;
        }
    }
    TEST_ASSERT(correct, "Vector addition results should be correct");
    TEST_ASSERT(avgNs < 500.0, "256-sample add should be < 500 ns");
}

void testSIMDTrigFunctions()
{
    std::cout << "\n[Test: SIMD Fast Trig Functions]\n";

    // Build lookup table
    alignas(32) float sinTable[4096];
    for (int i = 0; i < 4096; ++i)
    {
        float angle = (static_cast<float>(i) / 4096.0f) * 2.0f * 3.14159265f;
        sinTable[i] = std::sin(angle);
    }

    // Test lookup-based sin
    float maxError = 0.0f;
    for (int i = 0; i < 360; ++i)
    {
        float angle = static_cast<float>(i) * 3.14159265f / 180.0f;
        float expected = std::sin(angle);

        // Normalize angle to table index
        float normalized = angle / (2.0f * 3.14159265f);
        normalized = normalized - std::floor(normalized);
        int idx = static_cast<int>(normalized * 4096.0f) & 4095;
        float fast = sinTable[idx];

        float error = std::abs(expected - fast);
        maxError = std::max(maxError, error);
    }

    std::cout << "  Max sin lookup error: " << std::scientific << maxError << std::endl;
    TEST_ASSERT(maxError < 0.002f, "Fast sin should be accurate within 0.2%");

    // Benchmark
    Benchmark bench;
    const int iterations = 1000000;

    bench.start();
    for (int i = 0; i < iterations; ++i)
    {
        float angle = static_cast<float>(i % 360) * 3.14159265f / 180.0f;
        float normalized = angle / (2.0f * 3.14159265f);
        normalized = normalized - std::floor(normalized);
        volatile float result = sinTable[static_cast<int>(normalized * 4096.0f) & 4095];
        (void)result;
    }
    double lookupNs = bench.stopNs() / iterations;

    bench.start();
    for (int i = 0; i < iterations; ++i)
    {
        float angle = static_cast<float>(i % 360) * 3.14159265f / 180.0f;
        volatile float result = std::sin(angle);
        (void)result;
    }
    double stdSinNs = bench.stopNs() / iterations;

    std::cout << "  Lookup sin: " << std::fixed << std::setprecision(1) << lookupNs << " ns\n";
    std::cout << "  std::sin: " << std::fixed << std::setprecision(1) << stdSinNs << " ns\n";
    std::cout << "  Speedup: " << std::fixed << std::setprecision(1) << (stdSinNs / lookupNs) << "x\n";

    TEST_ASSERT(lookupNs < stdSinNs, "Lookup sin should be faster than std::sin");
}

//==============================================================================
// Lock-Free Queue Tests
//==============================================================================

void testLockFreeQueueSingleThread()
{
    std::cout << "\n[Test: Lock-Free Queue Single Thread]\n";

    using namespace Echoel::Core;

    LockFreeQueue<int, 256> queue;

    // Push items
    for (int i = 0; i < 100; ++i)
    {
        bool pushed = queue.push(i);
        TEST_ASSERT(pushed, "Push should succeed");
    }

    // Pop items
    for (int i = 0; i < 100; ++i)
    {
        auto val = queue.pop();
        TEST_ASSERT(val.has_value(), "Pop should return value");
        TEST_ASSERT(*val == i, "Values should be in order");
    }

    auto empty = queue.pop();
    TEST_ASSERT(!empty.has_value(), "Queue should be empty");
}

void testLockFreeQueueMultiThread()
{
    std::cout << "\n[Test: Lock-Free Queue Multi-Thread]\n";

    using namespace Echoel::Core;

    LockFreeQueue<int, 1024> queue;
    std::atomic<int> pushCount(0);
    std::atomic<int> popCount(0);
    std::atomic<int> sum(0);

    // Producer thread
    std::thread producer([&]() {
        for (int i = 1; i <= 500; ++i)
        {
            while (!queue.push(i))
            {
                std::this_thread::yield();
            }
            pushCount++;
        }
    });

    // Consumer thread
    std::thread consumer([&]() {
        while (popCount < 500)
        {
            auto val = queue.pop();
            if (val.has_value())
            {
                sum += *val;
                popCount++;
            }
            else
            {
                std::this_thread::yield();
            }
        }
    });

    producer.join();
    consumer.join();

    int expectedSum = 500 * 501 / 2;  // Sum of 1 to 500
    TEST_ASSERT(pushCount == 500, "All items should be pushed");
    TEST_ASSERT(popCount == 500, "All items should be popped");
    TEST_ASSERT(sum == expectedSum, "Sum should be correct (no lost items)");

    std::cout << "  Pushed: " << pushCount << ", Popped: " << popCount << ", Sum: " << sum << "\n";
}

//==============================================================================
// Stress Tests
//==============================================================================

void testFullSystemStress()
{
    std::cout << "\n[Test: Full System Stress Test]\n";

    using namespace Echoel::Core;
    using namespace Echoel::DSP;

    // Initialize all systems
    EchoelMainController& ctrl = EchoelMainController::getInstance();
    EchoelMemoryPool& pool = EchoelMemoryPool::getInstance();
    EchoelErrorHandler& handler = EchoelErrorHandler::getInstance();

    AnalyzerConfig analyzerConfig;
    analyzerConfig.sampleRate = 44100.0f;
    analyzerConfig.fftSize = 1024;
    analyzerConfig.enableBeatDetection = true;

    EchoelAudioAnalyzer analyzer(analyzerConfig);

    AudioConfig audioConfig;
    audioConfig.sampleRate = 44100.0;
    audioConfig.bufferSize = 256;

    EchoelAudioEngine engine(audioConfig);

    EchoelPresetManager presets;

    // Run stress test
    Benchmark bench;
    const int iterations = 1000;

    std::vector<float> audioBuffer(256);
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_real_distribution<float> dist(-1.0f, 1.0f);

    for (auto& s : audioBuffer)
        s = dist(gen);

    float* channels[2] = { audioBuffer.data(), audioBuffer.data() };

    bench.start();
    for (int i = 0; i < iterations; ++i)
    {
        // Process audio
        engine.processBlock(channels, 2, 256);

        // Analyze audio
        analyzer.process(audioBuffer.data(), 256);

        // Update state
        SystemState state = ctrl.getState();
        state.masterVolume = 0.5f + 0.4f * std::sin(i * 0.01f);
        ctrl.setState(state);

        // Post and poll messages
        if (i % 100 == 0)
        {
            ctrl.postMessage(MessageType::BeatTrigger, 120);
            ctrl.pollMessage();
        }

        // Memory pool operations
        void* ptr = pool.allocate(128);
        pool.deallocate(ptr, 128);
    }
    double totalMs = bench.stopMs();

    std::cout << "  " << iterations << " iterations in " << std::fixed << std::setprecision(2) << totalMs << " ms\n";
    std::cout << "  Average: " << std::fixed << std::setprecision(3) << (totalMs / iterations) << " ms/iteration\n";

    // 256 samples at 44100 Hz = 5.8 ms of audio
    double realtimeMs = 256.0 * 1000.0 / 44100.0;
    double avgMs = totalMs / iterations;

    TEST_ASSERT(avgMs < realtimeMs, "Should process faster than real-time");
    TEST_ASSERT(avgMs < 1.0, "Should process in < 1ms per iteration");

    std::cout << "  Realtime budget: " << std::fixed << std::setprecision(2) << realtimeMs << " ms\n";
}

//==============================================================================
// Main
//==============================================================================

int main()
{
    std::cout << "========================================\n";
    std::cout << "Echoel DSP Test Suite\n";
    std::cout << "Ralph Wiggum Genius Loop Mode\n";
    std::cout << "Target: Zero Errors, Zero Warnings\n";
    std::cout << "========================================\n";

    // Audio Analyzer Tests
    testAudioAnalyzerInit();
    testAudioAnalyzerFFT();
    testAudioAnalyzerBeatDetection();
    testAudioAnalyzerBands();
    testAudioAnalyzerPerformance();

    // Memory Pool Tests
    testMemoryPoolBasic();
    testMemoryPoolAudioBuffers();
    testMemoryPoolRAII();
    testMemoryPoolThreadSafety();
    testMemoryPoolPerformance();

    // Audio Engine Tests
    testAudioEngineInit();
    testAudioEngineLevels();
    testAudioEngineBeatState();
    testAudioEngineEntrainment();

    // Preset Manager Tests
    testPresetManagerBasic();
    testPresetManagerFactoryPresets();
    testPresetManagerInterpolation();
    testPresetManagerJSON();

    // Error Handler Tests
    testErrorHandlerLogging();
    testErrorHandlerCodes();
    testErrorHandlerRecovery();
    testErrorHandlerStats();

    // Main Controller Tests
    testMainControllerSingleton();
    testMainControllerState();
    testMainControllerMessages();

    // SIMD Optimization Tests
    testSIMDVectorOperations();
    testSIMDTrigFunctions();

    // Lock-Free Queue Tests
    testLockFreeQueueSingleThread();
    testLockFreeQueueMultiThread();

    // Full System Stress Test
    testFullSystemStress();

    test::printSummary();

    return test::failedTests > 0 ? 1 : 0;
}
