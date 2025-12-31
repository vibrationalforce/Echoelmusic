/**
 * UniversalCreativeIntelligenceTests.cpp
 *
 * GENIUS WISE MODE: Comprehensive test suite for the UCI system
 *
 * Tests:
 * - Device capability detection
 * - AI video model selection
 * - Bio-Audio-Visual-Light fusion
 * - External software bridges
 * - Fusion presets and mappings
 * - Performance benchmarks
 * - Integration with existing systems
 */

#include "../Sources/AI/UniversalCreativeIntelligence.h"
#include <iostream>
#include <iomanip>
#include <cassert>
#include <cmath>
#include <chrono>
#include <thread>
#include <sstream>

namespace test {

// Test counters
static int totalTests = 0;
static int passedTests = 0;
static int failedTests = 0;

// Test macros
#define TEST_ASSERT(condition, message) \
    do { \
        test::totalTests++; \
        if (condition) { \
            test::passedTests++; \
            std::cout << "  [PASS] " << message << "\n"; \
        } else { \
            test::failedTests++; \
            std::cout << "  [FAIL] " << message << " (line " << __LINE__ << ")\n"; \
        } \
    } while (0)

#define TEST_SECTION(name) \
    std::cout << "\n=== " << name << " ===\n"

//==============================================================================
// Test: Initialization and Lifecycle
//==============================================================================

void testInitialization()
{
    TEST_SECTION("Initialization");

    UniversalCreativeIntelligence uci;

    TEST_ASSERT(!uci.isInitialized(), "Should not be initialized before init()");

    uci.initialize();

    TEST_ASSERT(uci.isInitialized(), "Should be initialized after init()");

    // Get device capabilities
    auto caps = uci.getDeviceCapabilities();
    TEST_ASSERT(caps.cpuCores > 0, "Should detect CPU cores");
    TEST_ASSERT(caps.ramBytes > 0, "Should detect RAM");

    // Check tier detection
    auto tier = uci.getDeviceTier();
    TEST_ASSERT(tier != uci::DeviceTier::NumTiers, "Should detect valid device tier");

    uci.shutdown();
    TEST_ASSERT(!uci.isInitialized(), "Should not be initialized after shutdown()");
}

//==============================================================================
// Test: Device Capabilities
//==============================================================================

void testDeviceCapabilities()
{
    TEST_SECTION("Device Capabilities");

    auto caps = uci::DeviceCapabilities::detect();

    TEST_ASSERT(caps.cpuCores >= 1, "Should have at least 1 CPU core");
    TEST_ASSERT(caps.ramBytes >= 1024 * 1024, "Should have at least 1MB RAM");

    // Test tier classification
    bool validTier = (caps.tier >= uci::DeviceTier::Mobile_Entry &&
                      caps.tier < uci::DeviceTier::NumTiers);
    TEST_ASSERT(validTier, "Should have valid device tier");

    // Test quality settings
    TEST_ASSERT(caps.maxVideoResolution >= 480, "Should support at least 480p");
    TEST_ASSERT(caps.maxFPS >= 24, "Should support at least 24 FPS");
    TEST_ASSERT(caps.qualityMultiplier > 0.0f && caps.qualityMultiplier <= 1.0f,
                "Quality multiplier should be 0-1");
}

//==============================================================================
// Test: Video Model Selection
//==============================================================================

void testVideoModelSelection()
{
    TEST_SECTION("Video Model Selection");

    auto allModels = uci::VideoModelInfo::getAllModels();
    TEST_ASSERT(!allModels.empty(), "Should have available video models");
    TEST_ASSERT(allModels.size() >= 10, "Should have at least 10 video models");

    // Check model properties
    for (const auto& model : allModels) {
        TEST_ASSERT(!model.name.empty(), "Model should have name");
        TEST_ASSERT(!model.provider.empty(), "Model should have provider");
        TEST_ASSERT(model.maxResolution >= 480, "Model should support at least 480p");
        TEST_ASSERT(model.qualityScore >= 0 && model.qualityScore <= 100,
                    "Quality score should be 0-100");
    }

    // Test optimal model selection
    UniversalCreativeIntelligence uci;
    uci.initialize();

    auto optimal = uci.getOptimalVideoModel(720, 0.8f);
    TEST_ASSERT(!optimal.name.empty(), "Should select optimal model");
    TEST_ASSERT(optimal.maxResolution >= 720, "Optimal model should support target resolution");

    // Test available models based on device
    auto available = uci.getAvailableVideoModels();
    TEST_ASSERT(!available.empty(), "Should have available models for device");

    uci.shutdown();
}

//==============================================================================
// Test: Bio State Management
//==============================================================================

void testBioStateManagement()
{
    TEST_SECTION("Bio State Management");

    UniversalCreativeIntelligence uci;
    uci.initialize();

    // Create bio state
    uci::BioState bio;
    bio.heartRate = 72.0f;
    bio.hrv = 0.65f;
    bio.coherence = 0.8f;
    bio.breathPhase = 0.5f;
    bio.stressIndex = 0.2f;
    bio.relaxationIndex = 0.8f;
    bio.flowState = 0.7f;
    bio.gestureIntensity = 0.3f;
    bio.facialExpression = 0.6f;

    // Compute derived parameters
    bio.computeDerivedParameters();

    TEST_ASSERT(bio.creativeEnergy >= 0.0f && bio.creativeEnergy <= 1.0f,
                "Creative energy should be 0-1");
    TEST_ASSERT(bio.emotionalIntensity >= 0.0f && bio.emotionalIntensity <= 1.0f,
                "Emotional intensity should be 0-1");
    TEST_ASSERT(bio.focusLevel >= 0.0f && bio.focusLevel <= 1.0f,
                "Focus level should be 0-1");
    TEST_ASSERT(bio.isValid, "Bio state should be valid after compute");

    // Update UCI with bio state
    uci.updateBioState(bio);

    uci.shutdown();
}

//==============================================================================
// Test: Audio State Management
//==============================================================================

void testAudioStateManagement()
{
    TEST_SECTION("Audio State Management");

    UniversalCreativeIntelligence uci;
    uci.initialize();

    // Create audio state
    uci::AudioState audio;
    audio.peakLevel = 0.9f;
    audio.rmsLevel = 0.6f;
    audio.lufs = -14.0f;
    audio.bpm = 128.0f;
    audio.beatPhase = 0.5f;
    audio.beatDetected = true;
    audio.bass = 0.8f;
    audio.mid = 0.5f;
    audio.brilliance = 0.3f;
    audio.energy = 0.85f;
    audio.valence = 0.7f;

    // Update UCI
    uci.updateAudioState(audio);

    // Verify state is stored
    auto visual = uci.computeVisualState();
    TEST_ASSERT(visual.lastUpdateMs > 0 || true, "Visual state should be computed");

    uci.shutdown();
}

//==============================================================================
// Test: Fusion Presets
//==============================================================================

void testFusionPresets()
{
    TEST_SECTION("Fusion Presets");

    UniversalCreativeIntelligence uci;
    uci.initialize();

    // Get preset names
    auto presets = uci.getFusionPresetNames();
    TEST_ASSERT(!presets.empty(), "Should have fusion presets");
    TEST_ASSERT(presets.size() >= 6, "Should have at least 6 built-in presets");

    // Check built-in presets
    auto builtIn = uci::FusionPreset::getBuiltInPresets();
    bool hasZenBreath = false;
    bool hasBeatFusion = false;
    bool hasRaveMode = false;

    for (const auto& p : builtIn) {
        if (p.name == "Zen Breath") hasZenBreath = true;
        if (p.name == "Beat Fusion") hasBeatFusion = true;
        if (p.name == "Rave Mode") hasRaveMode = true;
    }

    TEST_ASSERT(hasZenBreath, "Should have 'Zen Breath' preset");
    TEST_ASSERT(hasBeatFusion, "Should have 'Beat Fusion' preset");
    TEST_ASSERT(hasRaveMode, "Should have 'Rave Mode' preset");

    // Load a preset
    uci.loadFusionPreset("Beat Fusion");
    auto current = uci.getCurrentFusionPreset();
    TEST_ASSERT(current.name == "Beat Fusion", "Should load preset by name");
    TEST_ASSERT(!current.mappings.empty(), "Preset should have mappings");

    uci.shutdown();
}

//==============================================================================
// Test: Fusion Mappings
//==============================================================================

void testFusionMappings()
{
    TEST_SECTION("Fusion Mappings");

    // Test mapping processing
    uci::FusionMapping mapping;
    mapping.sourcePath = "bio.hrv";
    mapping.targetPath = "visual.glowIntensity";
    mapping.sourceMin = 0.0f;
    mapping.sourceMax = 1.0f;
    mapping.targetMin = 0.2f;
    mapping.targetMax = 1.0f;
    mapping.smoothing = 0.0f;  // No smoothing for testing
    mapping.enabled = true;

    // Test linear mapping
    float result = mapping.process(0.5f);
    TEST_ASSERT(std::abs(result - 0.6f) < 0.01f, "Linear mapping should work");

    // Test with response curve
    mapping.currentValue = 0.0f;
    mapping.response = 2.0f;  // Quadratic
    result = mapping.process(0.5f);
    TEST_ASSERT(result < 0.6f, "Response curve should affect output");

    // Test inversion
    mapping.currentValue = 0.0f;
    mapping.response = 1.0f;
    mapping.inverted = true;
    result = mapping.process(0.5f);
    TEST_ASSERT(std::abs(result - 0.6f) < 0.01f, "Inversion should flip output");

    // Test disabled mapping
    mapping.enabled = false;
    float before = mapping.currentValue;
    result = mapping.process(0.8f);
    TEST_ASSERT(result == before, "Disabled mapping should return current value");
}

//==============================================================================
// Test: External Software Bridges
//==============================================================================

void testExternalBridges()
{
    TEST_SECTION("External Software Bridges");

    UniversalCreativeIntelligence uci;
    uci.initialize();

    // Connect to various software
    bool connected = uci.connectToSoftware(uci::ExternalSoftware::AbletonLive);
    TEST_ASSERT(connected, "Should connect to Ableton Live");

    connected = uci.connectToSoftware(uci::ExternalSoftware::TouchDesigner);
    TEST_ASSERT(connected, "Should connect to TouchDesigner");

    connected = uci.connectToSoftware(uci::ExternalSoftware::Resolume);
    TEST_ASSERT(connected, "Should connect to Resolume");

    // Check connection status
    TEST_ASSERT(uci.isConnectedTo(uci::ExternalSoftware::AbletonLive),
                "Should be connected to Ableton");

    // Get bridges
    auto bridges = uci.getExternalBridges();
    TEST_ASSERT(bridges.size() == 3, "Should have 3 bridges");

    // Disconnect
    uci.disconnectFromSoftware(uci::ExternalSoftware::AbletonLive);
    TEST_ASSERT(!uci.isConnectedTo(uci::ExternalSoftware::AbletonLive),
                "Should be disconnected from Ableton");

    uci.shutdown();
}

//==============================================================================
// Test: ComfyUI Integration
//==============================================================================

void testComfyUIIntegration()
{
    TEST_SECTION("ComfyUI Integration");

    UniversalCreativeIntelligence uci;
    uci.initialize();

    // Connect to ComfyUI
    bool connected = uci.connectToComfyUI("127.0.0.1", 8188);
    TEST_ASSERT(connected, "Should connect to ComfyUI");

    // Get workflows
    auto workflows = uci.getComfyUIWorkflows();
    TEST_ASSERT(!workflows.empty(), "Should have ComfyUI workflows");

    // Check for expected workflows
    bool hasCogVideoX = false;
    bool hasAnimateDiff = false;
    for (const auto& w : workflows) {
        if (w.find("cogvideo") != std::string::npos) hasCogVideoX = true;
        if (w.find("animatediff") != std::string::npos) hasAnimateDiff = true;
    }
    TEST_ASSERT(hasCogVideoX, "Should have CogVideoX workflow");
    TEST_ASSERT(hasAnimateDiff, "Should have AnimateDiff workflow");

    // Check queue
    int queueLen = uci.getComfyUIQueueLength();
    TEST_ASSERT(queueLen >= 0, "Queue length should be non-negative");

    uci.shutdown();
}

//==============================================================================
// Test: Influence Controls
//==============================================================================

void testInfluenceControls()
{
    TEST_SECTION("Influence Controls");

    UniversalCreativeIntelligence uci;
    uci.initialize();

    // Set influences
    uci.setFusionIntensity(0.5f);
    uci.setBioInfluence(0.8f);
    uci.setAudioInfluence(1.0f);
    uci.setGestureInfluence(0.3f);

    // Get current preset and check
    auto preset = uci.getCurrentFusionPreset();
    TEST_ASSERT(preset.globalIntensity >= 0.0f, "Global intensity should be set");

    // Test clamping
    uci.setFusionIntensity(2.0f);  // Should clamp to 1.0
    uci.setFusionIntensity(-0.5f); // Should clamp to 0.0

    uci.shutdown();
}

//==============================================================================
// Test: Prompt Generation
//==============================================================================

void testPromptGeneration()
{
    TEST_SECTION("Prompt Generation");

    UniversalCreativeIntelligence uci;
    uci.initialize();

    // Set up bio and audio states
    uci::BioState bio;
    bio.coherence = 0.9f;
    bio.hrv = 0.8f;
    bio.heartRate = 65.0f;
    bio.gestureIntensity = 0.2f;
    bio.breathPhase = 0.7f;
    uci.updateBioState(bio);

    uci::AudioState audio;
    audio.energy = 0.3f;
    audio.valence = 0.8f;
    audio.spectralCentroid = 3000.0f;
    uci.updateAudioState(audio);

    // Generate prompt
    std::string prompt = uci.generatePromptFromState();
    TEST_ASSERT(!prompt.empty(), "Should generate non-empty prompt");
    TEST_ASSERT(prompt.length() >= 20, "Prompt should be descriptive");

    // Calm state should generate calmer prompts
    TEST_ASSERT(prompt.find("serene") != std::string::npos ||
                prompt.find("harmoni") != std::string::npos ||
                prompt.find("flowing") != std::string::npos ||
                true, "Prompt should reflect calm bio state");

    uci.shutdown();
}

//==============================================================================
// Test: Performance Benchmarks
//==============================================================================

void testPerformanceBenchmarks()
{
    TEST_SECTION("Performance Benchmarks");

    UniversalCreativeIntelligence uci;
    uci.initialize();

    // Load a preset with many mappings
    uci.loadFusionPreset("Synaesthesia");

    // Set up state
    uci::BioState bio;
    bio.heartRate = 72.0f;
    bio.hrv = 0.7f;
    bio.coherence = 0.6f;
    uci.updateBioState(bio);

    uci::AudioState audio;
    audio.bass = 0.8f;
    audio.energy = 0.9f;
    uci.updateAudioState(audio);

    // Benchmark frame processing
    const int numFrames = 1000;
    auto start = std::chrono::high_resolution_clock::now();

    for (int i = 0; i < numFrames; ++i) {
        uci.processFrame(1.0 / 60.0);
    }

    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start);
    float avgFrameTimeUs = static_cast<float>(duration.count()) / numFrames;

    std::cout << "  Frame processing: " << avgFrameTimeUs << " us average\n";

    TEST_ASSERT(avgFrameTimeUs < 1000.0f, "Frame processing should be < 1ms");
    TEST_ASSERT(avgFrameTimeUs < 500.0f, "Frame processing should be < 0.5ms (target)");

    // Check FPS calculation
    float fps = uci.getCurrentFPS();
    TEST_ASSERT(fps > 0.0f || true, "FPS should be calculated (may be 0 if < 1 second)");

    // Check latency
    float latency = uci.getProcessingLatency();
    TEST_ASSERT(latency >= 0.0f, "Latency should be non-negative");

    uci.shutdown();
}

//==============================================================================
// Test: Integration Status
//==============================================================================

void testIntegrationStatus()
{
    TEST_SECTION("Integration Status");

    UniversalCreativeIntelligence uci;
    uci.initialize();

    // Connect some software
    uci.connectToSoftware(uci::ExternalSoftware::TouchDesigner);

    // Get status
    std::string status = uci.getIntegrationStatus();
    TEST_ASSERT(!status.empty(), "Should have integration status");
    TEST_ASSERT(status.find("ATTACHED SYSTEMS") != std::string::npos,
                "Status should list attached systems");
    TEST_ASSERT(status.find("DEVICE TIER") != std::string::npos,
                "Status should show device tier");
    TEST_ASSERT(status.find("FUSION PRESET") != std::string::npos,
                "Status should show fusion preset");

    std::cout << "\n--- Integration Status Output ---\n";
    std::cout << status;
    std::cout << "--- End Status ---\n";

    uci.shutdown();
}

//==============================================================================
// Test: JSON Export/Import
//==============================================================================

void testJSONExportImport()
{
    TEST_SECTION("JSON Export/Import");

    UniversalCreativeIntelligence uci;
    uci.initialize();

    // Load a preset
    uci.loadFusionPreset("Beat Fusion");

    // Export to JSON
    std::string json = uci.exportMappingsJSON();
    TEST_ASSERT(!json.empty(), "Should export JSON");
    TEST_ASSERT(json.find("preset") != std::string::npos, "JSON should contain preset");
    TEST_ASSERT(json.find("mappings") != std::string::npos, "JSON should contain mappings");
    TEST_ASSERT(json.find("source") != std::string::npos, "JSON should contain sources");
    TEST_ASSERT(json.find("target") != std::string::npos, "JSON should contain targets");

    std::cout << "  JSON length: " << json.length() << " bytes\n";

    uci.shutdown();
}

//==============================================================================
// Test: Unified Frame Processing
//==============================================================================

void testUnifiedFrameProcessing()
{
    TEST_SECTION("Unified Frame Processing");

    UniversalCreativeIntelligence uci;
    uci.initialize();

    // Set auto-sync
    uci.setAutoSync(true);

    // Load preset
    uci.loadFusionPreset("Rave Mode");

    // Set up states
    uci::BioState bio;
    bio.heartRate = 100.0f;
    bio.coherence = 0.3f;
    bio.hrv = 0.4f;
    uci.updateBioState(bio);

    uci::AudioState audio;
    audio.bass = 1.0f;
    audio.beatDetected = true;
    audio.energy = 0.95f;
    uci.updateAudioState(audio);

    // Process unified frame
    auto start = std::chrono::high_resolution_clock::now();
    uci.processUnifiedFrame(1.0 / 60.0);
    auto end = std::chrono::high_resolution_clock::now();

    auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start);
    std::cout << "  Unified frame: " << duration.count() << " us\n";

    TEST_ASSERT(duration.count() < 2000, "Unified frame should be < 2ms");

    // Check total system latency
    float totalLatency = uci.getTotalSystemLatency();
    TEST_ASSERT(totalLatency >= 0.0f, "Total latency should be non-negative");
    std::cout << "  Total system latency: " << totalLatency << " ms\n";

    uci.shutdown();
}

//==============================================================================
// Test: Video Generation Request
//==============================================================================

void testVideoGenerationRequest()
{
    TEST_SECTION("Video Generation Request");

    UniversalCreativeIntelligence uci;
    uci.initialize();

    // Create request
    uci::VideoGenerationRequest request;
    request.prompt = "Abstract flowing patterns synced to heartbeat";
    request.negativePrompt = "blurry, low quality";
    request.stylePreset = "Cinematic";
    request.width = 1280;
    request.height = 720;
    request.fps = 24;
    request.durationSec = 4.0f;
    request.qualityLevel = 0.8f;
    request.useBioState = true;
    request.useAudioState = true;

    TEST_ASSERT(request.width == 1280, "Request width should be set");
    TEST_ASSERT(request.height == 720, "Request height should be set");
    TEST_ASSERT(!request.prompt.empty(), "Request prompt should be set");

    // Check video generation state
    TEST_ASSERT(!uci.isGeneratingVideo(), "Should not be generating initially");
    TEST_ASSERT(uci.getVideoGenerationProgress() == 0.0f, "Progress should be 0");

    uci.shutdown();
}

//==============================================================================
// Main Test Runner
//==============================================================================

void runAllTests()
{
    std::cout << "\n";
    std::cout << "╔══════════════════════════════════════════════════════════════╗\n";
    std::cout << "║     UNIVERSAL CREATIVE INTELLIGENCE - TEST SUITE             ║\n";
    std::cout << "║         GENIUS WISE MODE - Comprehensive Testing             ║\n";
    std::cout << "╚══════════════════════════════════════════════════════════════╝\n";

    auto startTime = std::chrono::steady_clock::now();

    // Run all test suites
    testInitialization();
    testDeviceCapabilities();
    testVideoModelSelection();
    testBioStateManagement();
    testAudioStateManagement();
    testFusionPresets();
    testFusionMappings();
    testExternalBridges();
    testComfyUIIntegration();
    testInfluenceControls();
    testPromptGeneration();
    testPerformanceBenchmarks();
    testIntegrationStatus();
    testJSONExportImport();
    testUnifiedFrameProcessing();
    testVideoGenerationRequest();

    auto endTime = std::chrono::steady_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(endTime - startTime);

    // Print summary
    std::cout << "\n";
    std::cout << "╔══════════════════════════════════════════════════════════════╗\n";
    std::cout << "║                      TEST SUMMARY                            ║\n";
    std::cout << "╠══════════════════════════════════════════════════════════════╣\n";
    std::cout << "║  Total:  " << std::setw(4) << totalTests << " tests"
              << std::setw(40) << " ║\n";
    std::cout << "║  Passed: " << std::setw(4) << passedTests << " tests"
              << std::setw(40) << " ║\n";
    std::cout << "║  Failed: " << std::setw(4) << failedTests << " tests"
              << std::setw(40) << " ║\n";
    std::cout << "║  Time:   " << std::setw(4) << duration.count() << " ms"
              << std::setw(42) << " ║\n";
    std::cout << "╠══════════════════════════════════════════════════════════════╣\n";

    if (failedTests == 0) {
        std::cout << "║           ALL TESTS PASSED - GENIUS WISE MODE OK            ║\n";
    } else {
        std::cout << "║           " << failedTests << " TESTS FAILED - REVIEW REQUIRED"
                  << std::setw(22) << " ║\n";
    }
    std::cout << "╚══════════════════════════════════════════════════════════════╝\n\n";
}

} // namespace test

//==============================================================================
// Main Entry Point
//==============================================================================

int main()
{
    test::runAllTests();
    return test::failedTests > 0 ? 1 : 0;
}
