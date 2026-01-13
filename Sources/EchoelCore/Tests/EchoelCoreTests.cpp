/**
 * EchoelCore Unit Tests
 *
 * Comprehensive tests for all EchoelCore modules using a minimal test framework.
 * No external dependencies required - runs standalone.
 *
 * Build: g++ -std=c++17 -I.. EchoelCoreTests.cpp -o echoelcore_tests && ./echoelcore_tests
 *
 * MIT License - Echoelmusic 2026
 */

#include <iostream>
#include <string>
#include <vector>
#include <cmath>
#include <cassert>
#include <functional>

// Include all EchoelCore modules
#include "../EchoelCore.h"

using namespace EchoelCore;
using namespace EchoelCore::Lambda;
using namespace EchoelCore::MCP;
using namespace EchoelCore::WebXR;
using namespace EchoelCore::Photonic;

//==============================================================================
// Minimal Test Framework
//==============================================================================

struct TestResult {
    std::string name;
    bool passed;
    std::string message;
};

std::vector<TestResult> gTestResults;
int gTestsPassed = 0;
int gTestsFailed = 0;

#define TEST(name) void test_##name()
#define RUN_TEST(name) runTest(#name, test_##name)

#define ASSERT_TRUE(expr) \
    if (!(expr)) { throw std::runtime_error("ASSERT_TRUE failed: " #expr); }

#define ASSERT_FALSE(expr) \
    if (expr) { throw std::runtime_error("ASSERT_FALSE failed: " #expr); }

#define ASSERT_EQ(a, b) \
    if ((a) != (b)) { throw std::runtime_error("ASSERT_EQ failed: " #a " != " #b); }

#define ASSERT_NEAR(a, b, epsilon) \
    if (std::abs((a) - (b)) > (epsilon)) { \
        throw std::runtime_error("ASSERT_NEAR failed: " #a " not near " #b); \
    }

#define ASSERT_GT(a, b) \
    if ((a) <= (b)) { throw std::runtime_error("ASSERT_GT failed: " #a " <= " #b); }

#define ASSERT_LT(a, b) \
    if ((a) >= (b)) { throw std::runtime_error("ASSERT_LT failed: " #a " >= " #b); }

void runTest(const char* name, std::function<void()> testFunc) {
    TestResult result;
    result.name = name;
    try {
        testFunc();
        result.passed = true;
        result.message = "OK";
        gTestsPassed++;
        std::cout << "  ✅ " << name << std::endl;
    } catch (const std::exception& e) {
        result.passed = false;
        result.message = e.what();
        gTestsFailed++;
        std::cout << "  ❌ " << name << " - " << e.what() << std::endl;
    }
    gTestResults.push_back(result);
}

//==============================================================================
// BioState Tests
//==============================================================================

TEST(BioState_DefaultValues) {
    BioState bio;
    ASSERT_NEAR(bio.getHRV(), 0.5f, 0.01f);
    ASSERT_NEAR(bio.getCoherence(), 0.5f, 0.01f);
    ASSERT_NEAR(bio.getHeartRate(), 70.0f, 0.01f);
    ASSERT_NEAR(bio.getBreathPhase(), 0.0f, 0.01f);
}

TEST(BioState_SetAndGet) {
    BioState bio;
    bio.setHRV(0.8f);
    bio.setCoherence(0.9f);
    bio.setHeartRate(80.0f);
    bio.setBreathPhase(0.75f);

    ASSERT_NEAR(bio.getHRV(), 0.8f, 0.01f);
    ASSERT_NEAR(bio.getCoherence(), 0.9f, 0.01f);
    ASSERT_NEAR(bio.getHeartRate(), 80.0f, 0.01f);
    ASSERT_NEAR(bio.getBreathPhase(), 0.75f, 0.01f);
}

TEST(BioState_BreathLFO) {
    BioState bio;
    bio.setBreathPhase(0.0f);
    ASSERT_NEAR(bio.getBreathLFO(), 0.0f, 0.01f);

    bio.setBreathPhase(0.25f);
    ASSERT_NEAR(bio.getBreathLFO(), 1.0f, 0.01f);

    bio.setBreathPhase(0.5f);
    ASSERT_NEAR(bio.getBreathLFO(), 0.0f, 0.01f);

    bio.setBreathPhase(0.75f);
    ASSERT_NEAR(bio.getBreathLFO(), -1.0f, 0.01f);
}

TEST(BioState_DerivedMetrics) {
    BioState bio;
    bio.setHRV(0.8f);
    bio.setCoherence(0.9f);

    float relaxation = bio.getRelaxation();
    ASSERT_GT(relaxation, 0.5f);
    ASSERT_LT(relaxation, 1.0f);

    float arousal = bio.getArousal();
    ASSERT_GT(arousal, 0.0f);
    ASSERT_LT(arousal, 1.0f);
}

TEST(BioState_Update) {
    BioState bio;
    bio.update(0.7f, 0.85f, 75.0f, 0.5f);

    ASSERT_NEAR(bio.getHRV(), 0.7f, 0.01f);
    ASSERT_NEAR(bio.getCoherence(), 0.85f, 0.01f);
    ASSERT_NEAR(bio.getHeartRate(), 75.0f, 0.01f);
    ASSERT_NEAR(bio.getBreathPhase(), 0.5f, 0.01f);
}

//==============================================================================
// SPSCQueue Tests
//==============================================================================

TEST(SPSCQueue_PushPop) {
    SPSCQueue<int, 16> queue;

    ASSERT_TRUE(queue.push(42));
    ASSERT_TRUE(queue.push(123));

    int value;
    ASSERT_TRUE(queue.pop(value));
    ASSERT_EQ(value, 42);

    ASSERT_TRUE(queue.pop(value));
    ASSERT_EQ(value, 123);

    ASSERT_FALSE(queue.pop(value));  // Empty
}

TEST(SPSCQueue_Full) {
    SPSCQueue<int, 4> queue;  // Capacity is actually 4-1=3

    ASSERT_TRUE(queue.push(1));
    ASSERT_TRUE(queue.push(2));
    ASSERT_TRUE(queue.push(3));
    ASSERT_FALSE(queue.push(4));  // Full
}

TEST(SPSCQueue_Empty) {
    SPSCQueue<int, 8> queue;
    int value;
    ASSERT_FALSE(queue.pop(value));
}

TEST(SPSCQueue_WrapAround) {
    SPSCQueue<int, 4> queue;
    int value;

    // Fill and drain multiple times to test wrap-around
    for (int i = 0; i < 10; ++i) {
        ASSERT_TRUE(queue.push(i));
        ASSERT_TRUE(queue.pop(value));
        ASSERT_EQ(value, i);
    }
}

//==============================================================================
// BioMapper Tests
//==============================================================================

TEST(BioMapper_AddMapping) {
    BioMapper mapper;

    bool added = mapper.addMapping(
        1,  // paramId
        BioSource::Coherence,
        MapCurve::Linear,
        0.0f, 1.0f,  // input range
        0.0f, 1.0f,  // output range
        0.5f         // depth
    );

    ASSERT_TRUE(added);
}

TEST(BioMapper_ComputeModulatedValue_Linear) {
    BioMapper mapper;
    mapper.addMapping(1, BioSource::Coherence, MapCurve::Linear, 0, 1, 0, 1, 1.0f);

    BioState bio;
    bio.setCoherence(0.5f);

    float modulated = mapper.computeModulatedValue(1, 0.5f, bio);
    ASSERT_NEAR(modulated, 0.75f, 0.01f);  // 0.5 + 0.5 * 0.5 = 0.75
}

TEST(BioMapper_ComputeModulatedValue_NoMapping) {
    BioMapper mapper;
    BioState bio;

    // No mapping for param 999
    float modulated = mapper.computeModulatedValue(999, 0.5f, bio);
    ASSERT_NEAR(modulated, 0.5f, 0.01f);  // Returns base value unchanged
}

//==============================================================================
// LambdaLoop Tests
//==============================================================================

TEST(LambdaLoop_Initialize) {
    LambdaLoop loop;
    ASSERT_TRUE(loop.initialize());
    ASSERT_EQ(loop.getState(), LambdaState::Active);
}

TEST(LambdaLoop_StartStop) {
    LambdaLoop loop;
    loop.initialize();

    loop.start();
    ASSERT_TRUE(loop.isRunning());

    loop.stop();
    ASSERT_FALSE(loop.isRunning());
}

TEST(LambdaLoop_Tick) {
    LambdaLoop loop;
    loop.initialize();
    loop.start();

    auto stats1 = loop.getStats();
    loop.tick();
    auto stats2 = loop.getStats();

    ASSERT_EQ(stats2.tickCount, stats1.tickCount + 1);
}

TEST(LambdaLoop_BioUpdate) {
    LambdaLoop loop;
    loop.initialize();

    loop.updateBioData(0.8f, 0.9f, 75.0f, 0.5f);

    const BioState& bio = loop.getBioState();
    ASSERT_NEAR(bio.getHRV(), 0.8f, 0.01f);
    ASSERT_NEAR(bio.getCoherence(), 0.9f, 0.01f);
}

TEST(LambdaLoop_LambdaScore) {
    LambdaLoop loop;
    loop.initialize();

    // Set high coherence
    loop.updateBioData(0.9f, 0.95f, 70.0f, 0.5f);

    // Tick a few times to let score stabilize
    for (int i = 0; i < 10; ++i) {
        loop.tick();
    }

    float score = loop.getLambdaScore();
    ASSERT_GT(score, 0.3f);  // Should be elevated
}

TEST(LambdaLoop_StateTransitions) {
    LambdaLoop loop;
    ASSERT_EQ(loop.getState(), LambdaState::Dormant);

    loop.initialize();
    ASSERT_EQ(loop.getState(), LambdaState::Active);

    loop.shutdown();
    ASSERT_EQ(loop.getState(), LambdaState::Dormant);
}

TEST(LambdaLoop_GetStateName) {
    ASSERT_EQ(std::string(LambdaLoop::getStateName(LambdaState::Dormant)), "Dormant");
    ASSERT_EQ(std::string(LambdaLoop::getStateName(LambdaState::Active)), "Active");
    ASSERT_EQ(std::string(LambdaLoop::getStateName(LambdaState::Transcendent)), "Transcendent (λ∞)");
}

//==============================================================================
// MCPBioServer Tests
//==============================================================================

TEST(MCPBioServer_Initialize) {
    BioState bio;
    MCPBioServer server(bio);
    ASSERT_TRUE(server.initialize());
}

TEST(MCPBioServer_HandleMessage_ListResources) {
    BioState bio;
    MCPBioServer server(bio);
    server.initialize();

    std::string response = server.handleMessage(
        R"({"jsonrpc": "2.0", "method": "resources/list", "id": 1})"
    );

    ASSERT_TRUE(response.find("echoelmusic://bio/state") != std::string::npos);
    ASSERT_TRUE(response.find("echoelmusic://bio/hrv") != std::string::npos);
}

TEST(MCPBioServer_HandleMessage_ListTools) {
    BioState bio;
    MCPBioServer server(bio);
    server.initialize();

    std::string response = server.handleMessage(
        R"({"jsonrpc": "2.0", "method": "tools/list", "id": 1})"
    );

    ASSERT_TRUE(response.find("setBioHRV") != std::string::npos);
    ASSERT_TRUE(response.find("getBioState") != std::string::npos);
}

TEST(MCPBioServer_HandleMessage_CallTool) {
    BioState bio;
    MCPBioServer server(bio);
    server.initialize();

    std::string response = server.handleMessage(
        R"({"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "setBioHRV", "arguments": {"value": 0.75}}, "id": 1})"
    );

    ASSERT_TRUE(response.find("\"result\"") != std::string::npos);
    ASSERT_NEAR(bio.getHRV(), 0.75f, 0.01f);
}

TEST(MCPBioServer_HandleMessage_InvalidJson) {
    BioState bio;
    MCPBioServer server(bio);
    server.initialize();

    std::string response = server.handleMessage("not json");
    ASSERT_TRUE(response.find("error") != std::string::npos);
}

//==============================================================================
// WebXRAudioBridge Tests
//==============================================================================

TEST(WebXRAudioBridge_StartSession) {
    BioState bio;
    WebXRAudioBridge bridge(bio);

    ASSERT_FALSE(bridge.isSessionActive());

    bridge.startSession(XRSessionType::Immersive_VR);
    ASSERT_TRUE(bridge.isSessionActive());
    ASSERT_EQ(bridge.getSessionType(), XRSessionType::Immersive_VR);

    bridge.endSession();
    ASSERT_FALSE(bridge.isSessionActive());
}

TEST(WebXRAudioBridge_AddRemoveSource) {
    BioState bio;
    WebXRAudioBridge bridge(bio);

    ASSERT_EQ(bridge.getSourceCount(), 0u);

    SpatialAudioSource source;
    source.position = Vec3(1.0f, 2.0f, 3.0f);
    uint32_t id = bridge.addSource(source);

    ASSERT_GT(id, 0u);
    ASSERT_EQ(bridge.getSourceCount(), 1u);

    ASSERT_TRUE(bridge.removeSource(id));
    ASSERT_EQ(bridge.getSourceCount(), 0u);
}

TEST(WebXRAudioBridge_ProcessAudio) {
    BioState bio;
    WebXRAudioBridge bridge(bio);
    bridge.startSession(XRSessionType::Immersive_VR);

    // Add a source with some audio
    SpatialAudioSource source;
    source.position = Vec3(0.0f, 0.0f, 1.0f);  // In front
    uint32_t id = bridge.addSource(source);

    // Set buffer
    float testBuffer[64];
    for (int i = 0; i < 64; ++i) testBuffer[i] = 0.5f;
    bridge.setSourceBuffer(id, testBuffer, 64);

    // Process
    float outputL[64] = {0};
    float outputR[64] = {0};
    bridge.processAudio(outputL, outputR, 64);

    // Should have some output
    float sumL = 0, sumR = 0;
    for (int i = 0; i < 64; ++i) {
        sumL += std::abs(outputL[i]);
        sumR += std::abs(outputR[i]);
    }
    ASSERT_GT(sumL + sumR, 0.0f);
}

TEST(WebXRAudioBridge_Vec3Operations) {
    Vec3 a(1.0f, 2.0f, 3.0f);
    Vec3 b(4.0f, 5.0f, 6.0f);

    Vec3 sum = a + b;
    ASSERT_NEAR(sum.x, 5.0f, 0.01f);
    ASSERT_NEAR(sum.y, 7.0f, 0.01f);
    ASSERT_NEAR(sum.z, 9.0f, 0.01f);

    Vec3 diff = b - a;
    ASSERT_NEAR(diff.x, 3.0f, 0.01f);

    float len = a.length();
    ASSERT_NEAR(len, 3.7416f, 0.01f);  // sqrt(1+4+9)
}

//==============================================================================
// PhotonicInterconnect Tests
//==============================================================================

TEST(PhotonicInterconnect_Initialize) {
    BioState bio;
    PhotonicInterconnect interconnect(bio);
    ASSERT_TRUE(interconnect.initialize());
    ASSERT_EQ(interconnect.getProcessorType(), ProcessorType::Electronic);
}

TEST(PhotonicInterconnect_CreateChannel) {
    BioState bio;
    PhotonicInterconnect interconnect(bio);
    interconnect.initialize();

    uint32_t ch1 = interconnect.createChannel(1550.0);
    uint32_t ch2 = interconnect.createChannel(1310.0);

    ASSERT_GT(ch1, 0u);
    ASSERT_GT(ch2, 0u);
    ASSERT_NE(ch1, ch2);

    auto state = interconnect.getChannelState(ch1);
    ASSERT_TRUE(state != nullptr);
    ASSERT_NEAR(state->wavelength, 1550.0, 0.01);
}

TEST(PhotonicInterconnect_ProcessBioAudio) {
    BioState bio;
    bio.setCoherence(0.8f);

    PhotonicInterconnect interconnect(bio);
    interconnect.initialize();

    // Create test signal
    float input[64], output[64];
    for (int i = 0; i < 64; ++i) {
        input[i] = std::sin(2.0f * 3.14159f * i / 64.0f);  // 1 cycle sine
    }

    interconnect.processBioAudio(input, output, 64);

    // Output should be filtered (different from input)
    float diff = 0;
    for (int i = 0; i < 64; ++i) {
        diff += std::abs(output[i] - input[i]);
    }
    ASSERT_GT(diff, 0.0f);  // Should be modified
}

TEST(PhotonicInterconnect_ComputeSpectrum) {
    BioState bio;
    PhotonicInterconnect interconnect(bio);
    interconnect.initialize();

    // Create test signal (single frequency)
    float input[64], magnitude[32];
    for (int i = 0; i < 64; ++i) {
        input[i] = std::sin(2.0f * 3.14159f * 4.0f * i / 64.0f);  // 4 cycles
    }

    interconnect.computeSpectrum(input, magnitude, 64);

    // Should have peak around bin 4
    float maxMag = 0;
    int maxBin = 0;
    for (int i = 0; i < 32; ++i) {
        if (magnitude[i] > maxMag) {
            maxMag = magnitude[i];
            maxBin = i;
        }
    }
    ASSERT_EQ(maxBin, 4);
}

TEST(PhotonicInterconnect_Stats) {
    BioState bio;
    bio.setCoherence(0.75f);

    PhotonicInterconnect interconnect(bio);
    interconnect.initialize();
    interconnect.createChannel();

    auto stats = interconnect.getStats();
    ASSERT_EQ(stats.processorType, ProcessorType::Electronic);
    ASSERT_GT(stats.throughputOps, 0.0);
    ASSERT_EQ(stats.activeChannels, 1u);
    ASSERT_NEAR(stats.coherenceLevel, 0.75f, 0.01f);
}

//==============================================================================
// PhotonicTensor Tests
//==============================================================================

TEST(PhotonicTensor_Identity) {
    PhotonicTensor<4, 4> tensor;
    tensor.identity();

    for (size_t i = 0; i < 4; ++i) {
        for (size_t j = 0; j < 4; ++j) {
            float expected = (i == j) ? 1.0f : 0.0f;
            ASSERT_NEAR(tensor.at(i, j), expected, 0.001f);
        }
    }
}

TEST(PhotonicTensor_Multiply) {
    PhotonicTensor<2, 3> tensor;
    tensor.at(0, 0) = 1; tensor.at(0, 1) = 2; tensor.at(0, 2) = 3;
    tensor.at(1, 0) = 4; tensor.at(1, 1) = 5; tensor.at(1, 2) = 6;

    std::array<float, 3> vec = {1, 2, 3};
    auto result = tensor.multiply(vec);

    // [1,2,3] * [1,2,3]^T = 14
    // [4,5,6] * [1,2,3]^T = 32
    ASSERT_NEAR(result[0], 14.0f, 0.01f);
    ASSERT_NEAR(result[1], 32.0f, 0.01f);
}

//==============================================================================
// Performance Tests
//==============================================================================

TEST(Performance_SPSCQueue_Throughput) {
    SPSCQueue<int, 1024> queue;

    auto start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < 100000; ++i) {
        queue.push(i);
        int v;
        queue.pop(v);
    }
    auto end = std::chrono::high_resolution_clock::now();

    auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start);
    double opsPerSec = 200000.0 / (duration.count() / 1000000.0);

    std::cout << "      → SPSCQueue: " << (opsPerSec / 1000000.0) << " M ops/sec" << std::endl;
    ASSERT_GT(opsPerSec, 1000000.0);  // Should be > 1M ops/sec
}

TEST(Performance_LambdaLoop_TickRate) {
    LambdaLoop loop;
    loop.initialize();
    loop.start();

    auto start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < 1000; ++i) {
        loop.tick();
    }
    auto end = std::chrono::high_resolution_clock::now();

    auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start);
    double ticksPerSec = 1000.0 / (duration.count() / 1000000.0);

    std::cout << "      → LambdaLoop: " << ticksPerSec << " ticks/sec" << std::endl;
    ASSERT_GT(ticksPerSec, 10000.0);  // Should handle > 10K ticks/sec (well above 60Hz)
}

//==============================================================================
// Main
//==============================================================================

int main() {
    std::cout << "\n╔══════════════════════════════════════════════════════════════╗" << std::endl;
    std::cout << "║           EchoelCore Unit Tests - Lambda Edition             ║" << std::endl;
    std::cout << "╚══════════════════════════════════════════════════════════════╝\n" << std::endl;

    // BioState Tests
    std::cout << "📊 BioState Tests:" << std::endl;
    RUN_TEST(BioState_DefaultValues);
    RUN_TEST(BioState_SetAndGet);
    RUN_TEST(BioState_BreathLFO);
    RUN_TEST(BioState_DerivedMetrics);
    RUN_TEST(BioState_Update);

    // SPSCQueue Tests
    std::cout << "\n📬 SPSCQueue Tests:" << std::endl;
    RUN_TEST(SPSCQueue_PushPop);
    RUN_TEST(SPSCQueue_Full);
    RUN_TEST(SPSCQueue_Empty);
    RUN_TEST(SPSCQueue_WrapAround);

    // BioMapper Tests
    std::cout << "\n🗺️  BioMapper Tests:" << std::endl;
    RUN_TEST(BioMapper_AddMapping);
    RUN_TEST(BioMapper_ComputeModulatedValue_Linear);
    RUN_TEST(BioMapper_ComputeModulatedValue_NoMapping);

    // LambdaLoop Tests
    std::cout << "\n🔄 LambdaLoop Tests:" << std::endl;
    RUN_TEST(LambdaLoop_Initialize);
    RUN_TEST(LambdaLoop_StartStop);
    RUN_TEST(LambdaLoop_Tick);
    RUN_TEST(LambdaLoop_BioUpdate);
    RUN_TEST(LambdaLoop_LambdaScore);
    RUN_TEST(LambdaLoop_StateTransitions);
    RUN_TEST(LambdaLoop_GetStateName);

    // MCPBioServer Tests
    std::cout << "\n🤖 MCPBioServer Tests:" << std::endl;
    RUN_TEST(MCPBioServer_Initialize);
    RUN_TEST(MCPBioServer_HandleMessage_ListResources);
    RUN_TEST(MCPBioServer_HandleMessage_ListTools);
    RUN_TEST(MCPBioServer_HandleMessage_CallTool);
    RUN_TEST(MCPBioServer_HandleMessage_InvalidJson);

    // WebXRAudioBridge Tests
    std::cout << "\n🥽 WebXRAudioBridge Tests:" << std::endl;
    RUN_TEST(WebXRAudioBridge_StartSession);
    RUN_TEST(WebXRAudioBridge_AddRemoveSource);
    RUN_TEST(WebXRAudioBridge_ProcessAudio);
    RUN_TEST(WebXRAudioBridge_Vec3Operations);

    // PhotonicInterconnect Tests
    std::cout << "\n💡 PhotonicInterconnect Tests:" << std::endl;
    RUN_TEST(PhotonicInterconnect_Initialize);
    RUN_TEST(PhotonicInterconnect_CreateChannel);
    RUN_TEST(PhotonicInterconnect_ProcessBioAudio);
    RUN_TEST(PhotonicInterconnect_ComputeSpectrum);
    RUN_TEST(PhotonicInterconnect_Stats);

    // PhotonicTensor Tests
    std::cout << "\n🧮 PhotonicTensor Tests:" << std::endl;
    RUN_TEST(PhotonicTensor_Identity);
    RUN_TEST(PhotonicTensor_Multiply);

    // Performance Tests
    std::cout << "\n⚡ Performance Tests:" << std::endl;
    RUN_TEST(Performance_SPSCQueue_Throughput);
    RUN_TEST(Performance_LambdaLoop_TickRate);

    // Summary
    std::cout << "\n══════════════════════════════════════════════════════════════" << std::endl;
    std::cout << "Results: " << gTestsPassed << " passed, " << gTestsFailed << " failed" << std::endl;
    std::cout << "══════════════════════════════════════════════════════════════\n" << std::endl;

    return gTestsFailed > 0 ? 1 : 0;
}
