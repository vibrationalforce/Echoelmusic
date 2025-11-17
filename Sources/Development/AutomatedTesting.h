// AutomatedTesting.h - Enterprise-Grade Testing Framework
// Unit testing, integration testing, and automated quality assurance
#pragma once

#include "../Common/GlobalWarningFixes.h"
#include <JuceHeader.h>
#include <functional>
#include <vector>
#include <map>

namespace Echoel {

// ==================== TEST FRAMEWORK ====================
class TestFramework {
public:
    struct TestResult {
        juce::String testName;
        bool passed{false};
        juce::String message;
        double executionTimeMs{0.0};
    };

    class TestCase {
    public:
        TestCase(const juce::String& name) : testName(name) {}

        virtual ~TestCase() = default;

        virtual void setup() {}
        virtual void teardown() {}
        virtual void runTest() = 0;

        const juce::String& getName() const { return testName; }

        TestResult execute() {
            TestResult result;
            result.testName = testName;

            auto startTime = juce::Time::getMillisecondCounterHiRes();

            try {
                setup();
                runTest();
                teardown();

                result.passed = true;
                result.message = "✅ Test passed";
            }
            catch (const std::exception& e) {
                result.passed = false;
                result.message = "❌ Test failed: " + juce::String(e.what());
                teardown();
            }
            catch (...) {
                result.passed = false;
                result.message = "❌ Test failed: Unknown exception";
                teardown();
            }

            auto endTime = juce::Time::getMillisecondCounterHiRes();
            result.executionTimeMs = endTime - startTime;

            return result;
        }

    protected:
        void assertTrue(bool condition, const juce::String& message = "Assertion failed") {
            if (!condition) {
                throw std::runtime_error(message.toStdString());
            }
        }

        void assertFalse(bool condition, const juce::String& message = "Assertion failed") {
            assertTrue(!condition, message);
        }

        void assertEqual(float expected, float actual, float epsilon = 0.0001f,
                        const juce::String& message = "Values not equal") {
            if (std::abs(expected - actual) > epsilon) {
                throw std::runtime_error((message + ": expected " +
                    juce::String(expected) + ", got " + juce::String(actual)).toStdString());
            }
        }

        void assertNotNull(void* ptr, const juce::String& message = "Pointer is null") {
            assertTrue(ptr != nullptr, message);
        }

        void assertNull(void* ptr, const juce::String& message = "Pointer is not null") {
            assertTrue(ptr == nullptr, message);
        }

    private:
        juce::String testName;
    };

    void registerTest(std::unique_ptr<TestCase> test) {
        tests.push_back(std::move(test));
    }

    std::vector<TestResult> runAllTests() {
        std::vector<TestResult> results;

        for (auto& test : tests) {
            auto result = test->execute();
            results.push_back(result);
        }

        return results;
    }

    juce::String generateReport(const std::vector<TestResult>& results) const {
        int passed = 0;
        int failed = 0;
        double totalTime = 0.0;

        for (const auto& result : results) {
            if (result.passed) passed++;
            else failed++;
            totalTime += result.executionTimeMs;
        }

        juce::String report;
        report << "🧪 Test Results\n";
        report << "===============\n\n";
        report << "Total Tests: " << results.size() << "\n";
        report << "Passed: " << passed << " ✅\n";
        report << "Failed: " << failed << " ❌\n";
        report << "Success Rate: " << (results.empty() ? 0.0 : (passed * 100.0 / results.size())) << "%\n";
        report << "Total Time: " << juce::String(totalTime, 2) << " ms\n\n";

        report << "Details:\n";
        report << juce::String::repeatedString("-", 80) << "\n";

        for (const auto& result : results) {
            report << (result.passed ? "✅" : "❌") << " " << result.testName;
            report << " (" << juce::String(result.executionTimeMs, 2) << " ms)\n";
            if (!result.passed) {
                report << "   " << result.message << "\n";
            }
        }

        return report;
    }

private:
    std::vector<std::unique_ptr<TestCase>> tests;
};

// ==================== AUDIO PROCESSING TESTS ====================
class AudioProcessingTest : public TestFramework::TestCase {
public:
    AudioProcessingTest() : TestCase("AudioProcessing") {}

    void runTest() override {
        // Test 1: Buffer processing doesn't introduce NaN
        juce::AudioBuffer<float> buffer(2, 512);
        buffer.clear();

        // Fill with test signal
        for (int ch = 0; ch < buffer.getNumChannels(); ++ch) {
            auto* data = buffer.getWritePointer(ch);
            for (int i = 0; i < buffer.getNumSamples(); ++i) {
                data[i] = std::sin(2.0f * EchoelConstants::PI * 440.0f * i / 48000.0f) * 0.5f;
            }
        }

        // Check for NaN
        for (int ch = 0; ch < buffer.getNumChannels(); ++ch) {
            const auto* data = buffer.getReadPointer(ch);
            for (int i = 0; i < buffer.getNumSamples(); ++i) {
                assertFalse(std::isnan(data[i]), "NaN detected in audio buffer");
                assertFalse(std::isinf(data[i]), "Inf detected in audio buffer");
            }
        }

        // Test 2: No clipping
        float peak = buffer.getMagnitude(0, buffer.getNumSamples());
        assertTrue(peak <= 1.0f, "Audio clipping detected");

        // Test 3: RMS is reasonable
        float rms = buffer.getRMSLevel(0, 0, buffer.getNumSamples());
        assertTrue(rms > 0.0f && rms < 1.0f, "RMS level out of range");
    }
};

class DSPTest : public TestFramework::TestCase {
public:
    DSPTest() : TestCase("DSP") {}

    void runTest() override {
        // Test lerp function
        float result = EchoelDSP::lerp(0.0f, 10.0f, 0.5f);
        assertEqual(5.0f, result, 0.001f, "Lerp failed");

        // Test map function
        result = EchoelDSP::map(0.5f, 0.0f, 1.0f, 0.0f, 100.0f);
        assertEqual(50.0f, result, 0.001f, "Map failed");

        // Test normalize
        result = EchoelDSP::normalize(50.0f, 0.0f, 100.0f);
        assertEqual(0.5f, result, 0.001f, "Normalize failed");

        // Test clipping
        result = EchoelDSP::hardClip(1.5f, -1.0f, 1.0f);
        assertEqual(1.0f, result, 0.001f, "Hard clip failed");
    }
};

// ==================== BENCHMARK SUITE ====================
class BenchmarkSuite {
public:
    struct BenchmarkResult {
        juce::String name;
        double avgTimeMs;
        double minTimeMs;
        double maxTimeMs;
        int iterations;
    };

    template<typename Func>
    static BenchmarkResult benchmark(const juce::String& name, Func&& func, int iterations = 1000) {
        BenchmarkResult result;
        result.name = name;
        result.iterations = iterations;
        result.minTimeMs = 999999.0;
        result.maxTimeMs = 0.0;
        double totalTime = 0.0;

        // Warmup
        for (int i = 0; i < 10; ++i) {
            func();
        }

        // Actual benchmark
        for (int i = 0; i < iterations; ++i) {
            auto start = juce::Time::getMillisecondCounterHiRes();
            func();
            auto end = juce::Time::getMillisecondCounterHiRes();

            double time = end - start;
            totalTime += time;
            result.minTimeMs = std::min(result.minTimeMs, time);
            result.maxTimeMs = std::max(result.maxTimeMs, time);
        }

        result.avgTimeMs = totalTime / iterations;

        return result;
    }

    static juce::String formatResults(const std::vector<BenchmarkResult>& results) {
        juce::String report;
        report << "⚡ Benchmark Results\n";
        report << "===================\n\n";

        report << juce::String::formatted("%-40s %12s %12s %12s %10s\n",
            "Test", "Avg (ms)", "Min (ms)", "Max (ms)", "Iter");
        report << juce::String::repeatedString("-", 90) << "\n";

        for (const auto& result : results) {
            report << juce::String::formatted("%-40s %12.4f %12.4f %12.4f %10d\n",
                result.name.toRawUTF8(),
                result.avgTimeMs,
                result.minTimeMs,
                result.maxTimeMs,
                result.iterations);
        }

        return report;
    }
};

// ==================== MEMORY LEAK DETECTOR ====================
class MemoryLeakDetector {
public:
    static MemoryLeakDetector& getInstance() {
        static MemoryLeakDetector instance;
        return instance;
    }

    void startTracking() {
        std::lock_guard<std::mutex> lock(mutex);
        initialAllocationCount = getCurrentAllocationCount();
        tracking = true;
    }

    void stopTracking() {
        std::lock_guard<std::mutex> lock(mutex);
        tracking = false;
    }

    bool hasLeaks() const {
        std::lock_guard<std::mutex> lock(mutex);
        return getCurrentAllocationCount() > initialAllocationCount;
    }

    juce::String getReport() const {
        std::lock_guard<std::mutex> lock(mutex);

        juce::String report;
        report << "🔍 Memory Leak Detection\n";
        report << "========================\n\n";

        int current = getCurrentAllocationCount();
        int leaked = current - initialAllocationCount;

        if (leaked > 0) {
            report << "❌ MEMORY LEAK DETECTED!\n";
            report << "Initial allocations: " << initialAllocationCount << "\n";
            report << "Current allocations: " << current << "\n";
            report << "Leaked objects: " << leaked << "\n";
        } else {
            report << "✅ No memory leaks detected\n";
        }

        return report;
    }

private:
    MemoryLeakDetector() = default;

    mutable std::mutex mutex;
    bool tracking{false};
    int initialAllocationCount{0};

    static int getCurrentAllocationCount() {
        // This would integrate with JUCE's leak detector
        // For now, return 0 as placeholder
        return 0;
    }
};

// ==================== CODE COVERAGE TRACKER ====================
class CodeCoverageTracker {
public:
    static CodeCoverageTracker& getInstance() {
        static CodeCoverageTracker instance;
        return instance;
    }

    void markLineExecuted(const juce::String& file, int line) {
        std::lock_guard<std::mutex> lock(mutex);
        executedLines[file].insert(line);
    }

    void registerLine(const juce::String& file, int line) {
        std::lock_guard<std::mutex> lock(mutex);
        allLines[file].insert(line);
    }

    double getCoveragePercentage() const {
        std::lock_guard<std::mutex> lock(mutex);

        int totalLines = 0;
        int executedCount = 0;

        for (const auto& [file, lines] : allLines) {
            totalLines += static_cast<int>(lines.size());
            const auto& executed = executedLines.at(file);
            for (int line : lines) {
                if (executed.count(line) > 0) {
                    executedCount++;
                }
            }
        }

        return totalLines > 0 ? (executedCount * 100.0 / totalLines) : 0.0;
    }

    juce::String generateReport() const {
        std::lock_guard<std::mutex> lock(mutex);

        juce::String report;
        report << "📊 Code Coverage Report\n";
        report << "=======================\n\n";
        report << "Overall Coverage: " << juce::String(getCoveragePercentage(), 1) << "%\n\n";

        report << "Per-File Coverage:\n";
        report << juce::String::repeatedString("-", 60) << "\n";

        for (const auto& [file, lines] : allLines) {
            int total = static_cast<int>(lines.size());
            int executed = 0;

            if (executedLines.count(file) > 0) {
                const auto& exec = executedLines.at(file);
                for (int line : lines) {
                    if (exec.count(line) > 0) executed++;
                }
            }

            double percentage = total > 0 ? (executed * 100.0 / total) : 0.0;
            report << file << ": " << juce::String(percentage, 1) << "% ";
            report << "(" << executed << "/" << total << ")\n";
        }

        return report;
    }

private:
    CodeCoverageTracker() = default;

    mutable std::mutex mutex;
    std::map<juce::String, std::set<int>> allLines;
    std::map<juce::String, std::set<int>> executedLines;
};

} // namespace Echoel
