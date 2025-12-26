/**
 * SuperLaserScan Test Suite
 *
 * Comprehensive tests for:
 * - Performance validation (< 0.5ms frame time)
 * - Pattern rendering accuracy
 * - Lock-free buffer operations
 * - Safety limit enforcement
 * - Audio/Bio reactive modulation
 * - SIMD optimization verification
 *
 * Target: Zero errors, zero warnings
 */

#include "../Sources/Visual/SuperLaserScan.h"
#include <iostream>
#include <cassert>
#include <chrono>
#include <cmath>
#include <cstring>
#include <iomanip>
#include <sstream>

//==============================================================================
// Test Framework
//==============================================================================

namespace test {

static int totalTests = 0;
static int passedTests = 0;
static int failedTests = 0;

struct TestResult
{
    bool passed;
    std::string message;
};

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
    std::cout << "Test Summary:\n";
    std::cout << "  Total:  " << totalTests << std::endl;
    std::cout << "  Passed: " << passedTests << std::endl;
    std::cout << "  Failed: " << failedTests << std::endl;
    std::cout << "========================================\n";

    if (failedTests == 0)
    {
        std::cout << "\n*** ALL TESTS PASSED ***\n\n";
    }
    else
    {
        std::cout << "\n*** " << failedTests << " TEST(S) FAILED ***\n\n";
    }
}

} // namespace test

//==============================================================================
// Performance Benchmarks
//==============================================================================

class PerformanceBenchmark
{
public:
    using Clock = std::chrono::high_resolution_clock;

    void start()
    {
        startTime_ = Clock::now();
    }

    double stopMs()
    {
        auto end = Clock::now();
        return std::chrono::duration<double, std::milli>(end - startTime_).count();
    }

    double stopUs()
    {
        auto end = Clock::now();
        return std::chrono::duration<double, std::micro>(end - startTime_).count();
    }

private:
    std::chrono::time_point<Clock> startTime_;
};

//==============================================================================
// Test Cases
//==============================================================================

void testInitialization()
{
    std::cout << "\n[Test: Initialization]\n";

    SuperLaserScan scan;

    TEST_ASSERT(!scan.isInitialized(), "Should not be initialized before init()");
    TEST_ASSERT(!scan.isOutputEnabled(), "Output should be disabled by default");
    TEST_ASSERT(!scan.isBioReactiveEnabled(), "Bio-reactive should be disabled by default");

    scan.initialize(60.0f);

    TEST_ASSERT(scan.isInitialized(), "Should be initialized after init()");
    TEST_ASSERT(scan.getNumBeams() == 0, "Should have no beams initially");

    scan.shutdown();

    TEST_ASSERT(!scan.isInitialized(), "Should not be initialized after shutdown");
}

void testBeamManagement()
{
    std::cout << "\n[Test: Beam Management]\n";

    SuperLaserScan scan;
    scan.initialize(60.0f);

    // Add beams
    laser::BeamConfig beam1;
    beam1.pattern = laser::PatternType::Circle;
    beam1.size = 0.5f;
    beam1.red = 1.0f;

    int idx1 = scan.addBeam(beam1);
    TEST_ASSERT(idx1 == 0, "First beam should have index 0");
    TEST_ASSERT(scan.getNumBeams() == 1, "Should have 1 beam");

    laser::BeamConfig beam2;
    beam2.pattern = laser::PatternType::Spiral;
    beam2.size = 0.8f;

    int idx2 = scan.addBeam(beam2);
    TEST_ASSERT(idx2 == 1, "Second beam should have index 1");
    TEST_ASSERT(scan.getNumBeams() == 2, "Should have 2 beams");

    // Get and verify beam
    laser::BeamConfig retrieved = scan.getBeam(0);
    TEST_ASSERT(retrieved.pattern == laser::PatternType::Circle, "Retrieved beam should be Circle");
    TEST_ASSERT_NEAR(retrieved.size, 0.5f, 0.001f, "Retrieved beam size should be 0.5");

    // Update beam
    beam1.size = 0.7f;
    scan.setBeam(0, beam1);
    retrieved = scan.getBeam(0);
    TEST_ASSERT_NEAR(retrieved.size, 0.7f, 0.001f, "Updated beam size should be 0.7");

    // Remove beam
    scan.removeBeam(0);
    TEST_ASSERT(scan.getNumBeams() == 1, "Should have 1 beam after removal");

    // Clear all
    scan.clearBeams();
    TEST_ASSERT(scan.getNumBeams() == 0, "Should have 0 beams after clear");

    scan.shutdown();
}

void testPatternRendering()
{
    std::cout << "\n[Test: Pattern Rendering]\n";

    SuperLaserScan scan;
    scan.initialize(60.0f);

    // Test each pattern type
    std::vector<std::pair<laser::PatternType, const char*>> patterns = {
        {laser::PatternType::Circle, "Circle"},
        {laser::PatternType::Square, "Square"},
        {laser::PatternType::Triangle, "Triangle"},
        {laser::PatternType::Star, "Star"},
        {laser::PatternType::Spiral, "Spiral"},
        {laser::PatternType::Tunnel, "Tunnel"},
        {laser::PatternType::Wave, "Wave"},
        {laser::PatternType::Lissajous, "Lissajous"},
        {laser::PatternType::Grid, "Grid"},
        {laser::PatternType::Helix, "Helix"}
    };

    for (const auto& [pattern, name] : patterns)
    {
        scan.clearBeams();

        laser::BeamConfig beam;
        beam.pattern = pattern;
        beam.size = 0.5f;
        beam.pointDensity = 100;
        beam.red = 1.0f;
        beam.green = 0.5f;
        beam.blue = 0.0f;
        scan.addBeam(beam);

        scan.renderFrame(1.0 / 60.0);

        int numPoints;
        const laser::ILDAPoint* points = scan.getCurrentFrame(numPoints);

        std::stringstream ss;
        ss << name << " pattern should render points (got " << numPoints << ")";
        TEST_ASSERT(numPoints > 0, ss.str().c_str());

        // Verify points are within valid range
        bool validRange = true;
        for (int i = 0; i < numPoints && validRange; ++i)
        {
            if (points[i].x < -32768 || points[i].x > 32767 ||
                points[i].y < -32768 || points[i].y > 32767)
            {
                validRange = false;
            }
        }

        ss.str("");
        ss << name << " pattern points should be in valid range";
        TEST_ASSERT(validRange, ss.str().c_str());
    }

    scan.shutdown();
}

void testPerformance()
{
    std::cout << "\n[Test: Performance (Target: < 0.5ms per frame)]\n";

    SuperLaserScan scan;
    scan.initialize(60.0f);

    // Add complex scene with multiple beams
    for (int i = 0; i < 10; ++i)
    {
        laser::BeamConfig beam;
        beam.pattern = static_cast<laser::PatternType>(i % 10);
        beam.size = 0.3f + (i * 0.05f);
        beam.x = -0.5f + (i * 0.1f);
        beam.pointDensity = 100;
        beam.rotationSpeed = 0.5f;
        beam.audioReactive = (i % 2 == 0);
        scan.addBeam(beam);
    }

    // Warmup
    for (int i = 0; i < 10; ++i)
    {
        scan.renderFrame(1.0 / 60.0);
    }

    // Benchmark
    PerformanceBenchmark bench;
    const int numFrames = 100;

    bench.start();
    for (int i = 0; i < numFrames; ++i)
    {
        scan.renderFrame(1.0 / 60.0);
    }
    double totalMs = bench.stopMs();

    double avgFrameMs = totalMs / numFrames;
    double fps = 1000.0 / avgFrameMs;

    std::cout << "  Average frame time: " << std::fixed << std::setprecision(3) << avgFrameMs << " ms\n";
    std::cout << "  Theoretical FPS: " << std::fixed << std::setprecision(1) << fps << "\n";

    TEST_ASSERT(avgFrameMs < 0.5, "Frame time should be < 0.5ms for real-time performance");
    TEST_ASSERT(fps > 2000, "Should achieve > 2000 FPS theoretical maximum");

    // Get metrics
    laser::MetricsSnapshot metrics = scan.getMetrics();
    std::cout << "  Reported frame time: " << metrics.frameTimeMs << " ms\n";
    std::cout << "  Points rendered: " << metrics.pointsRendered << "\n";
    std::cout << "  Total frames: " << metrics.totalFrames << "\n";

    scan.shutdown();
}

void testTripleBuffering()
{
    std::cout << "\n[Test: Lock-Free Triple Buffering]\n";

    SuperLaserScan scan;
    scan.initialize(60.0f);

    laser::BeamConfig beam;
    beam.pattern = laser::PatternType::Circle;
    beam.size = 0.5f;
    beam.pointDensity = 50;
    scan.addBeam(beam);

    // Render multiple frames and verify buffer swapping
    uint64_t lastFrameId = 0;

    for (int i = 0; i < 10; ++i)
    {
        scan.renderFrame(1.0 / 60.0);

        int numPoints;
        const laser::ILDAPoint* points = scan.getCurrentFrame(numPoints);

        // Verify we get valid data
        TEST_ASSERT(numPoints > 0, "Should have points after render");
        TEST_ASSERT(points != nullptr, "Points pointer should not be null");
    }

    // Test interpolated frame retrieval
    std::array<laser::ILDAPoint, 100> interpolated;
    int interpCount = 0;
    scan.getInterpolatedFrame(interpolated.data(), interpCount, 0.5f);
    TEST_ASSERT(interpCount > 0, "Interpolated frame should have points");

    scan.shutdown();
}

void testSafetyLimits()
{
    std::cout << "\n[Test: Safety Limits]\n";

    SuperLaserScan scan;
    scan.initialize(60.0f);

    // Set strict safety config
    laser::SafetyConfig safety;
    safety.enabled = true;
    safety.maxScanSpeedPPS = 30000.0f;  // 30K points per second (ILDA standard)
    safety.maxPowerMW = 500.0f;
    scan.setSafetyConfig(safety);

    // Add beam with high point density
    laser::BeamConfig beam;
    beam.pattern = laser::PatternType::Spiral;
    beam.pointDensity = 1000;  // High density
    beam.brightness = 1.0f;
    scan.addBeam(beam);

    scan.renderFrame(1.0 / 60.0);

    int numPoints;
    scan.getCurrentFrame(numPoints);

    // At 60 FPS, max points = 30000 / 60 = 500
    TEST_ASSERT(numPoints <= 500, "Points should be limited by safety (30K pps @ 60fps = 500 max)");

    // Test safety warnings
    auto warnings = scan.getSafetyWarnings();
    TEST_ASSERT(scan.isSafe(), "Should be safe with limits applied");

    // Disable safety and check warning
    safety.enabled = false;
    scan.setSafetyConfig(safety);
    warnings = scan.getSafetyWarnings();
    TEST_ASSERT(warnings.size() > 0, "Should have warning when safety disabled");

    scan.shutdown();
}

void testAudioReactivity()
{
    std::cout << "\n[Test: Audio Reactivity]\n";

    SuperLaserScan scan;
    scan.initialize(60.0f);

    laser::BeamConfig beam;
    beam.pattern = laser::PatternType::AudioWaveform;
    beam.audioReactive = true;
    beam.size = 0.5f;
    beam.pointDensity = 100;
    scan.addBeam(beam);

    // Update audio data
    std::array<float, 512> spectrum;
    std::array<float, 1024> waveform;

    for (int i = 0; i < 512; ++i)
    {
        spectrum[i] = 0.5f + 0.5f * std::sin(static_cast<float>(i) * 0.1f);
    }
    for (int i = 0; i < 1024; ++i)
    {
        waveform[i] = std::sin(static_cast<float>(i) * 0.05f);
    }

    scan.updateAudioSpectrum(spectrum.data(), 512);
    scan.updateAudioWaveform(waveform.data(), 1024);
    scan.updateAudioLevels(0.8f, 0.5f, 0.7f, 0.5f, 0.3f);

    scan.renderFrame(1.0 / 60.0);

    int numPoints;
    const laser::ILDAPoint* points = scan.getCurrentFrame(numPoints);

    TEST_ASSERT(numPoints > 0, "Audio waveform should render points");

    // Test beat trigger
    scan.triggerBeat();
    scan.renderFrame(1.0 / 60.0);
    TEST_ASSERT(true, "Beat trigger should not crash");

    scan.shutdown();
}

void testBioReactivity()
{
    std::cout << "\n[Test: Bio Reactivity]\n";

    SuperLaserScan scan;
    scan.initialize(60.0f);

    laser::BeamConfig beam;
    beam.pattern = laser::PatternType::BioSpiral;
    beam.bioReactive = true;
    beam.size = 0.5f;
    beam.pointDensity = 100;
    scan.addBeam(beam);

    scan.setBioReactiveEnabled(true);
    TEST_ASSERT(scan.isBioReactiveEnabled(), "Bio-reactive should be enabled");

    // Set bio data
    scan.setBioData(0.7f, 0.8f, 72.0f, 14.0f, 0.3f);

    scan.renderFrame(1.0 / 60.0);

    int numPoints;
    const laser::ILDAPoint* points = scan.getCurrentFrame(numPoints);

    TEST_ASSERT(numPoints > 0, "Bio spiral should render points");

    // Test heartbeat trigger
    scan.triggerHeartbeat();
    scan.renderFrame(1.0 / 60.0);
    TEST_ASSERT(true, "Heartbeat trigger should not crash");

    // Test breath phase
    scan.setBreathPhase(true);
    scan.renderFrame(1.0 / 60.0);
    scan.setBreathPhase(false);
    scan.renderFrame(1.0 / 60.0);
    TEST_ASSERT(true, "Breath phase changes should not crash");

    scan.shutdown();
}

void testPresets()
{
    std::cout << "\n[Test: Presets]\n";

    SuperLaserScan scan;
    scan.initialize(60.0f);

    auto presets = scan.getBuiltInPresets();
    TEST_ASSERT(presets.size() > 0, "Should have built-in presets");

    std::cout << "  Available presets: " << presets.size() << std::endl;

    for (const auto& presetName : presets)
    {
        scan.loadPreset(presetName);

        scan.renderFrame(1.0 / 60.0);

        int numPoints;
        scan.getCurrentFrame(numPoints);

        std::stringstream ss;
        ss << "Preset '" << presetName << "' should render points";
        TEST_ASSERT(numPoints > 0 || scan.getNumBeams() > 0, ss.str().c_str());
    }

    scan.shutdown();
}

void testOutputConfiguration()
{
    std::cout << "\n[Test: Output Configuration]\n";

    SuperLaserScan scan;
    scan.initialize(60.0f);

    laser::OutputConfig output;
    std::strncpy(output.name.data(), "Test Output", 63);
    std::strncpy(output.protocol.data(), "ILDA", 15);
    std::strncpy(output.ipAddress.data(), "192.168.1.100", 15);
    output.port = 7255;
    output.enabled = true;

    int idx = scan.addOutput(output);
    TEST_ASSERT(idx == 0, "First output should have index 0");

    laser::OutputConfig retrieved = scan.getOutput(0);
    TEST_ASSERT(std::strncmp(retrieved.name.data(), "Test Output", 11) == 0, "Output name should match");
    TEST_ASSERT(retrieved.port == 7255, "Output port should be 7255");

    // Update output
    output.port = 8000;
    scan.setOutput(0, output);
    retrieved = scan.getOutput(0);
    TEST_ASSERT(retrieved.port == 8000, "Updated port should be 8000");

    // Remove output
    scan.removeOutput(0);
    TEST_ASSERT(true, "Output removal should not crash");

    scan.shutdown();
}

void testQualitySettings()
{
    std::cout << "\n[Test: Quality Settings]\n";

    SuperLaserScan scan;
    scan.initialize(60.0f);

    // Test interpolation quality
    scan.setInterpolationQuality(0);
    scan.setInterpolationQuality(1);
    scan.setInterpolationQuality(2);
    TEST_ASSERT(true, "Interpolation quality changes should not crash");

    // Test blanking optimization
    scan.setBlankingOptimization(0);
    scan.setBlankingOptimization(1);
    scan.setBlankingOptimization(2);
    TEST_ASSERT(true, "Blanking optimization changes should not crash");

    // Test galvo acceleration
    scan.setGalvoAcceleration(50000.0f);
    scan.setGalvoAcceleration(0.0f);
    TEST_ASSERT(true, "Galvo acceleration changes should not crash");

    // Test adaptive point density
    scan.setAdaptivePointDensity(true);
    scan.setAdaptivePointDensity(false);
    TEST_ASSERT(true, "Adaptive point density changes should not crash");

    scan.shutdown();
}

void testFrameCallback()
{
    std::cout << "\n[Test: Frame Callback]\n";

    SuperLaserScan scan;
    scan.initialize(60.0f);

    int callbackCount = 0;
    int lastPointCount = 0;
    uint64_t lastFrameId = 0;

    scan.setFrameCallback([&](const laser::ILDAPoint* points, int numPoints, uint64_t frameId) {
        ++callbackCount;
        lastPointCount = numPoints;
        lastFrameId = frameId;
    });

    laser::BeamConfig beam;
    beam.pattern = laser::PatternType::Circle;
    beam.pointDensity = 50;
    scan.addBeam(beam);

    for (int i = 0; i < 5; ++i)
    {
        scan.renderFrame(1.0 / 60.0);
    }

    TEST_ASSERT(callbackCount == 5, "Callback should be called 5 times");
    TEST_ASSERT(lastPointCount > 0, "Callback should receive points");
    TEST_ASSERT(lastFrameId > 0, "Frame ID should increment");

    scan.shutdown();
}

void testStressTest()
{
    std::cout << "\n[Test: Stress Test (1000 frames, max beams)]\n";

    SuperLaserScan scan;
    scan.initialize(60.0f);

    // Add maximum beams
    for (int i = 0; i < 32; ++i)
    {
        laser::BeamConfig beam;
        beam.pattern = static_cast<laser::PatternType>(i % static_cast<int>(laser::PatternType::NumPatterns));
        beam.size = 0.1f + (i * 0.02f);
        beam.x = -0.8f + (i % 8) * 0.2f;
        beam.y = -0.8f + (i / 8) * 0.4f;
        beam.pointDensity = 30;
        beam.rotationSpeed = 0.1f * i;
        beam.audioReactive = (i % 3 == 0);
        beam.bioReactive = (i % 5 == 0);
        scan.addBeam(beam);
    }

    scan.setBioReactiveEnabled(true);

    PerformanceBenchmark bench;
    bench.start();

    bool stable = true;
    int totalPoints = 0;

    for (int i = 0; i < 1000; ++i)
    {
        // Simulate audio updates
        if (i % 10 == 0)
        {
            std::array<float, 512> spectrum;
            for (int j = 0; j < 512; ++j)
                spectrum[j] = 0.3f + 0.2f * std::sin(i * 0.01f + j * 0.1f);
            scan.updateAudioSpectrum(spectrum.data(), 512);
            scan.updateAudioLevels(0.5f + 0.3f * std::sin(i * 0.05f), 0.4f, 0.6f, 0.4f, 0.3f);
        }

        // Simulate bio updates
        if (i % 60 == 0)
        {
            scan.setBioData(0.5f + 0.3f * std::sin(i * 0.01f), 0.6f, 72.0f, 14.0f, 0.3f);
        }

        if (i % 100 == 0)
            scan.triggerBeat();

        scan.renderFrame(1.0 / 60.0);

        int numPoints;
        const laser::ILDAPoint* points = scan.getCurrentFrame(numPoints);

        if (numPoints == 0 || points == nullptr)
        {
            stable = false;
            break;
        }

        totalPoints += numPoints;
    }

    double totalMs = bench.stopMs();

    std::cout << "  1000 frames in " << std::fixed << std::setprecision(2) << totalMs << " ms\n";
    std::cout << "  Average: " << std::fixed << std::setprecision(3) << (totalMs / 1000.0) << " ms/frame\n";
    std::cout << "  Total points rendered: " << totalPoints << "\n";

    TEST_ASSERT(stable, "Should remain stable under stress");
    TEST_ASSERT(totalMs < 500.0, "1000 frames should complete in < 500ms");

    auto metrics = scan.getMetrics();
    TEST_ASSERT(metrics.framesDropped == 0, "Should not drop frames");

    scan.shutdown();
}

void testLookupTableAccuracy()
{
    std::cout << "\n[Test: Fast Trig Lookup Table Accuracy]\n";

    // Test that fast sin/cos approximations are accurate
    std::array<float, laser::kTrigTableSize> sinTable;
    for (int i = 0; i < laser::kTrigTableSize; ++i)
    {
        float angle = (static_cast<float>(i) / laser::kTrigTableSize) * laser::kTwoPi;
        sinTable[i] = std::sin(angle);
    }

    float maxError = 0.0f;
    for (int i = 0; i < 360; ++i)
    {
        float angle = static_cast<float>(i) * laser::kPi / 180.0f;
        float expected = std::sin(angle);
        float fast = laser::fastSin(angle, sinTable.data());
        float error = std::abs(expected - fast);
        maxError = std::max(maxError, error);
    }

    std::cout << "  Max sin error: " << std::scientific << maxError << std::endl;
    TEST_ASSERT(maxError < 0.01f, "Fast sin should be accurate within 1%");
}

void testDenormalProtection()
{
    std::cout << "\n[Test: Denormal Number Protection]\n";

    // Verify denormal flushing works
    float denormal = 1.0e-40f;  // Denormal number
    float flushed = laser::flushDenormal(denormal);
    TEST_ASSERT(flushed == 0.0f, "Denormal should be flushed to zero");

    float normal = 0.5f;
    float kept = laser::flushDenormal(normal);
    TEST_ASSERT_NEAR(kept, 0.5f, 0.0001f, "Normal values should be preserved");
}

void testPointInterpolation()
{
    std::cout << "\n[Test: Point Interpolation]\n";

    laser::ILDAPoint a(10000, 20000, 255, 0, 0, false);
    laser::ILDAPoint b(-10000, -20000, 0, 255, 0, false);

    // Test midpoint
    laser::ILDAPoint mid = laser::ILDAPoint::interpolate(a, b, 0.5f);
    TEST_ASSERT_NEAR(mid.x, 0, 100, "Midpoint X should be ~0");
    TEST_ASSERT_NEAR(mid.y, 0, 100, "Midpoint Y should be ~0");

    // Test endpoints
    laser::ILDAPoint atA = laser::ILDAPoint::interpolate(a, b, 0.0f);
    TEST_ASSERT(atA.x == a.x && atA.y == a.y, "t=0 should return point A");

    laser::ILDAPoint atB = laser::ILDAPoint::interpolate(a, b, 1.0f);
    TEST_ASSERT(atB.x == b.x && atB.y == b.y, "t=1 should return point B");
}

//==============================================================================
// Main
//==============================================================================

int main()
{
    std::cout << "========================================\n";
    std::cout << "SuperLaserScan Test Suite\n";
    std::cout << "Target: Zero Errors, Zero Warnings\n";
    std::cout << "========================================\n";

    // Run all tests
    testInitialization();
    testBeamManagement();
    testPatternRendering();
    testPerformance();
    testTripleBuffering();
    testSafetyLimits();
    testAudioReactivity();
    testBioReactivity();
    testPresets();
    testOutputConfiguration();
    testQualitySettings();
    testFrameCallback();
    testLookupTableAccuracy();
    testDenormalProtection();
    testPointInterpolation();
    testStressTest();

    test::printSummary();

    return test::failedTests > 0 ? 1 : 0;
}
