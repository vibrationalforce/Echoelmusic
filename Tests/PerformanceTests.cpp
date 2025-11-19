#include <JuceHeader.h>
#include "../Sources/Core/EchoelMasterSystem.h"
#include <chrono>
#include <cassert>

/**
 * ECHOELMUSIC PERFORMANCE & QUALITY ASSURANCE TESTS
 *
 * These tests verify that the system meets professional production standards:
 * - Latency: < 5ms ALWAYS
 * - CPU: < 30% at full project
 * - RAM: < 500MB base
 * - Crashes: 0 in 24h
 * - Startup: < 3 seconds
 *
 * Run with: ./build/PerformanceTests
 */

class PerformanceTests
{
public:
    //==============================================================================
    // Test Runner
    //==============================================================================

    static int runAllTests()
    {
        std::cout << "\n";
        std::cout << "========================================\n";
        std::cout << "  ECHOELMUSIC PERFORMANCE TESTS\n";
        std::cout << "========================================\n";
        std::cout << "\n";

        int passed = 0;
        int failed = 0;

        // Test 1: Initialization Time
        if (testInitializationTime())
        {
            std::cout << "✅ TEST 1: Initialization time < 3s\n";
            passed++;
        }
        else
        {
            std::cout << "❌ TEST 1: Initialization time >= 3s\n";
            failed++;
        }

        // Test 2: Audio Latency
        if (testAudioLatency())
        {
            std::cout << "✅ TEST 2: Audio latency < 5ms\n";
            passed++;
        }
        else
        {
            std::cout << "❌ TEST 2: Audio latency >= 5ms\n";
            failed++;
        }

        // Test 3: CPU Usage
        if (testCPUUsage())
        {
            std::cout << "✅ TEST 3: CPU usage < 30%\n";
            passed++;
        }
        else
        {
            std::cout << "❌ TEST 3: CPU usage >= 30%\n";
            failed++;
        }

        // Test 4: RAM Usage
        if (testRAMUsage())
        {
            std::cout << "✅ TEST 4: RAM usage < 500MB\n";
            passed++;
        }
        else
        {
            std::cout << "❌ TEST 4: RAM usage >= 500MB\n";
            failed++;
        }

        // Test 5: Module Integration
        if (testModuleIntegration())
        {
            std::cout << "✅ TEST 5: Module integration working\n";
            passed++;
        }
        else
        {
            std::cout << "❌ TEST 5: Module integration failed\n";
            failed++;
        }

        // Test 6: Cross-Module Features
        if (testCrossModuleFeatures())
        {
            std::cout << "✅ TEST 6: Cross-module features working\n";
            passed++;
        }
        else
        {
            std::cout << "❌ TEST 6: Cross-module features failed\n";
            failed++;
        }

        // Test 7: Error Handling
        if (testErrorHandling())
        {
            std::cout << "✅ TEST 7: Error handling robust\n";
            passed++;
        }
        else
        {
            std::cout << "❌ TEST 7: Error handling failed\n";
            failed++;
        }

        // Test 8: Realtime Safety
        if (testRealtimeSafety())
        {
            std::cout << "✅ TEST 8: Realtime-safe processing\n";
            passed++;
        }
        else
        {
            std::cout << "❌ TEST 8: Not realtime-safe\n";
            failed++;
        }

        // Summary
        std::cout << "\n";
        std::cout << "========================================\n";
        std::cout << "  RESULTS\n";
        std::cout << "========================================\n";
        std::cout << "Passed: " << passed << "\n";
        std::cout << "Failed: " << failed << "\n";
        std::cout << "Total:  " << (passed + failed) << "\n";
        std::cout << "\n";

        if (failed == 0)
        {
            std::cout << "✅ ALL TESTS PASSED - PRODUCTION READY!\n";
        }
        else
        {
            std::cout << "❌ SOME TESTS FAILED - NOT PRODUCTION READY\n";
        }

        std::cout << "========================================\n";
        std::cout << "\n";

        return (failed == 0) ? 0 : 1;
    }

private:
    //==============================================================================
    // Individual Tests
    //==============================================================================

    static bool testInitializationTime()
    {
        auto start = std::chrono::high_resolution_clock::now();

        EchoelMasterSystem master;
        auto result = master.initialize();

        auto end = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

        std::cout << "  Initialization time: " << duration.count() << " ms\n";

        master.shutdown();

        return (result == EchoelErrorCode::Success && duration.count() < 3000);
    }

    static bool testAudioLatency()
    {
        EchoelMasterSystem master;
        master.initialize();

        double latency = master.getAudioLatencyMs();
        std::cout << "  Audio latency: " << latency << " ms\n";

        master.shutdown();

        return (latency < 5.0);
    }

    static bool testCPUUsage()
    {
        EchoelMasterSystem master;
        master.initialize();

        // Run for a bit to get stable CPU measurement
        juce::Thread::sleep(1000);

        float cpuUsage = master.getCPUUsage();
        std::cout << "  CPU usage: " << cpuUsage << " %\n";

        master.shutdown();

        return (cpuUsage < 30.0f);
    }

    static bool testRAMUsage()
    {
        EchoelMasterSystem master;
        master.initialize();

        size_t ramUsage = master.getRAMUsageMB();
        std::cout << "  RAM usage: " << ramUsage << " MB\n";

        master.shutdown();

        return (ramUsage < 500);
    }

    static bool testModuleIntegration()
    {
        EchoelMasterSystem master;
        auto result = master.initialize();

        if (result != EchoelErrorCode::Success)
            return false;

        // Test module access
        try
        {
            auto& studio = master.getStudio();
            auto& biometric = master.getBiometric();
            auto& spatial = master.getSpatial();
            auto& live = master.getLive();
            auto& ai = master.getAI();

            // All modules accessible
            (void)studio;
            (void)biometric;
            (void)spatial;
            (void)live;
            (void)ai;

            master.shutdown();
            return true;
        }
        catch (...)
        {
            master.shutdown();
            return false;
        }
    }

    static bool testCrossModuleFeatures()
    {
        EchoelMasterSystem master;
        master.initialize();

        // Enable cross-module features
        master.enableBioReactiveMix(true);
        master.enableSpatialVisualization(true);
        master.enableLivePerformance(true);
        master.enableAIAssist(true);

        // Verify they're enabled
        bool allEnabled = (master.isBioReactiveMixEnabled() &&
                          master.isSpatialVisualizationEnabled() &&
                          master.isLivePerformanceEnabled() &&
                          master.isAIAssistEnabled());

        master.shutdown();

        return allEnabled;
    }

    static bool testErrorHandling()
    {
        EchoelMasterSystem master;

        // Test initialization
        auto result = master.initialize();
        if (result != EchoelErrorCode::Success)
        {
            std::cout << "  Error: " << master.getErrorMessage() << "\n";
            return false;
        }

        // Test double initialization (should be safe)
        result = master.initialize();
        if (result != EchoelErrorCode::Success)
        {
            master.shutdown();
            return false;
        }

        // Test shutdown
        master.shutdown();

        // Test double shutdown (should be safe)
        master.shutdown();

        return true;
    }

    static bool testRealtimeSafety()
    {
        EchoelMasterSystem master;
        master.initialize();

        // Ensure realtime performance
        master.ensureRealtimePerformance();

        // Check if realtime-safe
        juce::Thread::sleep(500);  // Let it settle

        bool isRealtimeSafe = master.isRealtimeSafe();
        std::cout << "  Realtime safe: " << (isRealtimeSafe ? "YES" : "NO") << "\n";

        master.shutdown();

        return isRealtimeSafe;
    }
};

//==============================================================================
// Stress Tests (24h stability test)
//==============================================================================

class StressTests
{
public:
    static void run24HourStressTest()
    {
        std::cout << "\n";
        std::cout << "========================================\n";
        std::cout << "  24-HOUR STRESS TEST\n";
        std::cout << "========================================\n";
        std::cout << "\n";
        std::cout << "Starting... (this will take 24 hours)\n";
        std::cout << "\n";

        EchoelMasterSystem master;
        master.initialize();

        int crashes = 0;
        const int totalSeconds = 24 * 60 * 60;  // 24 hours
        int elapsed = 0;

        while (elapsed < totalSeconds)
        {
            // Check if still alive
            if (!master.isInitialized())
            {
                std::cout << "❌ CRASH detected at " << (elapsed / 3600) << " hours\n";
                crashes++;

                // Try to restart
                master.shutdown();
                auto result = master.initialize();

                if (result != EchoelErrorCode::Success)
                {
                    std::cout << "❌ Failed to restart - aborting test\n";
                    break;
                }
            }

            // Log progress every hour
            if (elapsed % 3600 == 0)
            {
                int hours = elapsed / 3600;
                auto stats = master.getStats();
                std::cout << "Hour " << hours << ": ";
                std::cout << "CPU: " << stats.cpuUsagePercent << "%, ";
                std::cout << "RAM: " << stats.ramUsageMB << " MB, ";
                std::cout << "Crashes: " << crashes << "\n";
            }

            juce::Thread::sleep(1000);  // Sleep 1 second
            elapsed++;
        }

        master.shutdown();

        std::cout << "\n";
        std::cout << "========================================\n";
        std::cout << "  24-HOUR TEST COMPLETE\n";
        std::cout << "========================================\n";
        std::cout << "Total crashes: " << crashes << "\n";
        std::cout << (crashes == 0 ? "✅ STABLE" : "❌ UNSTABLE") << "\n";
        std::cout << "========================================\n";
        std::cout << "\n";
    }
};

//==============================================================================
// Main
//==============================================================================

int main(int argc, char* argv[])
{
    juce::ScopedJuceInitialiser_GUI juceInit;

    if (argc > 1 && std::string(argv[1]) == "--stress-test")
    {
        StressTests::run24HourStressTest();
        return 0;
    }

    return PerformanceTests::runAllTests();
}
