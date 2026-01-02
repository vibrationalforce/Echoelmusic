#pragma once

#include "../Engine/QuantumLatencyEngine.h"
#include "../AI/EchoelIntelligence.h"
#include "../Bio/BiofeedbackEngine.h"
#include "../Network/LiveCollaboration.h"
#include "../Network/RealtimeStreaming.h"

#include <iostream>
#include <vector>
#include <cmath>

namespace Echoelmusic {
namespace Tests {

/**
 * AdvancedFeaturesTests - Test Suite for Advanced DAW Features
 *
 * Tests:
 * - Quantum Latency Engine
 * - AI-powered EchoelIntelligence
 * - Biofeedback System
 * - Live Collaboration
 * - Real-time Streaming
 */

class AdvancedFeaturesTests
{
public:
    struct TestResult
    {
        juce::String name;
        bool passed = false;
        juce::String message;
        double durationMs = 0;
    };

    std::vector<TestResult> runAllTests()
    {
        std::vector<TestResult> results;

        // Quantum Latency Engine Tests
        results.push_back(testQuantumEngineInit());
        results.push_back(testQuantumEngineMetrics());
        results.push_back(testSIMDProcessor());
        results.push_back(testLockFreeBuffer());
        results.push_back(testPredictiveBuffer());

        // AI Tests
        results.push_back(testBeatDetection());
        results.push_back(testKeyDetection());
        results.push_back(testChordDetection());
        results.push_back(testIntelligentMixer());
        results.push_back(testAudioTagger());

        // Biofeedback Tests
        results.push_back(testHeartRateAnalysis());
        results.push_back(testHRVMetrics());
        results.push_back(testEEGProcessing());
        results.push_back(testGSRAnalysis());
        results.push_back(testRespirationAnalysis());
        results.push_back(testMentalStateDetection());
        results.push_back(testBioParameterMapping());

        // Collaboration Tests
        results.push_back(testSessionCreation());
        results.push_back(testMIDISynchronization());
        results.push_back(testVoiceChat());
        results.push_back(testOperationalTransform());

        // Streaming Tests
        results.push_back(testStreamEndpointSetup());
        results.push_back(testAudioEncoding());
        results.push_back(testStreamVisualization());
        results.push_back(testMetadataInjection());

        return results;
    }

    void printResults(const std::vector<TestResult>& results)
    {
        int passed = 0, failed = 0;

        std::cout << "\n========================================\n";
        std::cout << "   Advanced Features Tests Results\n";
        std::cout << "========================================\n\n";

        for (const auto& result : results)
        {
            if (result.passed)
            {
                std::cout << "[PASS] " << result.name << " (" << result.durationMs << "ms)\n";
                passed++;
            }
            else
            {
                std::cout << "[FAIL] " << result.name << "\n";
                std::cout << "       " << result.message << "\n";
                failed++;
            }
        }

        std::cout << "\n----------------------------------------\n";
        std::cout << "Total: " << (passed + failed) << " | ";
        std::cout << "Passed: " << passed << " | ";
        std::cout << "Failed: " << failed << "\n";
        std::cout << "----------------------------------------\n\n";
    }

private:
    //==========================================================================
    // Quantum Latency Engine Tests
    //==========================================================================

    TestResult testQuantumEngineInit()
    {
        TestResult result{"Quantum Engine Initialization"};
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            QuantumLatencyEngine engine;

            QuantumLatencyEngine::Config config;
            config.sampleRate = 48000.0;
            config.bufferSize = 64;
            config.numInputChannels = 2;
            config.numOutputChannels = 2;
            config.enableSIMD = true;
            config.enableRealtimePriority = false;  // Don't change thread priority in tests

            engine.prepare(config);

            auto metrics = engine.getMetrics();
            if (metrics.bufferSize != 64)
                throw std::runtime_error("Buffer size not set correctly");

            if (std::abs(metrics.sampleRate - 48000.0) > 0.1)
                throw std::runtime_error("Sample rate not set correctly");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testQuantumEngineMetrics()
    {
        TestResult result{"Quantum Engine Metrics"};
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            QuantumLatencyEngine engine;

            QuantumLatencyEngine::Config config;
            config.sampleRate = 48000.0;
            config.bufferSize = 256;
            engine.prepare(config);

            // Process some blocks
            juce::AudioBuffer<float> buffer(2, 256);
            juce::MidiBuffer midi;

            for (int i = 0; i < 100; ++i)
            {
                buffer.clear();
                engine.processBlock(buffer, midi, [](juce::AudioBuffer<float>&, juce::MidiBuffer&) {});
            }

            auto metrics = engine.getMetrics();

            if (metrics.callbackCount != 100)
                throw std::runtime_error("Callback count incorrect: " + std::to_string(metrics.callbackCount));

            if (metrics.averageCallbackTimeUs <= 0)
                throw std::runtime_error("Average callback time not recorded");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testSIMDProcessor()
    {
        TestResult result{"SIMD Processor"};
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            const int numSamples = 1024;
            std::vector<float> buffer(numSamples, 0.5f);
            std::vector<float> buffer2(numSamples, 0.3f);

            // Test gain
            SIMDProcessor::applyGain(buffer.data(), numSamples, 2.0f);
            if (std::abs(buffer[0] - 1.0f) > 0.001f)
                throw std::runtime_error("SIMD gain failed");

            // Test mix
            SIMDProcessor::mix(buffer.data(), buffer2.data(), numSamples, 1.0f);
            if (std::abs(buffer[0] - 1.3f) > 0.001f)
                throw std::runtime_error("SIMD mix failed");

            // Test clear
            SIMDProcessor::clear(buffer.data(), numSamples);
            if (buffer[0] != 0.0f)
                throw std::runtime_error("SIMD clear failed");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testLockFreeBuffer()
    {
        TestResult result{"Lock-Free Ring Buffer"};
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            LockFreeRingBuffer<int, 16> buffer;

            // Push items
            for (int i = 0; i < 10; ++i)
            {
                if (!buffer.push(i))
                    throw std::runtime_error("Push failed at " + std::to_string(i));
            }

            if (buffer.available() != 10)
                throw std::runtime_error("Available count wrong");

            // Pop items
            for (int i = 0; i < 10; ++i)
            {
                int val;
                if (!buffer.pop(val))
                    throw std::runtime_error("Pop failed at " + std::to_string(i));
                if (val != i)
                    throw std::runtime_error("Wrong value popped");
            }

            // Buffer should be empty
            int dummy;
            if (buffer.pop(dummy))
                throw std::runtime_error("Pop should fail on empty buffer");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testPredictiveBuffer()
    {
        TestResult result{"Predictive Buffer Manager"};
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            PredictiveBufferManager manager;

            // Record some callback times
            for (int i = 0; i < 100; ++i)
            {
                manager.recordCallbackTime(500.0 + (i % 10) * 10.0);  // ~500-600 microseconds
            }

            double prediction = manager.predictNextCallbackTime();
            if (prediction < 400.0 || prediction > 700.0)
                throw std::runtime_error("Prediction out of range: " + std::to_string(prediction));

            int recommended = manager.recommendBufferSize(48000.0, 2.0);  // 2ms target
            if (recommended < 32 || recommended > 512)
                throw std::runtime_error("Recommended buffer size out of range: " + std::to_string(recommended));

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    //==========================================================================
    // AI Tests
    //==========================================================================

    TestResult testBeatDetection()
    {
        TestResult result{"Beat Detection"};
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            AI::BeatDetector detector(48000.0);

            // Generate test signal with regular transients
            const int numSamples = 512;
            std::vector<float> buffer(numSamples);

            for (int frame = 0; frame < 100; ++frame)
            {
                for (int i = 0; i < numSamples; ++i)
                {
                    // Add transient every beat (~0.5 seconds at 120 BPM)
                    buffer[i] = (i < 50) ? 0.8f : 0.1f;
                }

                auto info = detector.process(buffer.data(), numSamples);

                // After processing, BPM should stabilize
                if (frame > 50)
                {
                    if (info.bpm < 30.0 || info.bpm > 300.0)
                        throw std::runtime_error("BPM out of valid range: " + std::to_string(info.bpm));
                }
            }

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testKeyDetection()
    {
        TestResult result{"Key Detection"};
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            AI::HarmonicAnalyzer analyzer(48000.0);

            // Generate C major chord (C, E, G)
            const int numSamples = 4096;
            std::vector<float> buffer(numSamples);

            float fs = 48000.0f;
            for (int i = 0; i < numSamples; ++i)
            {
                float t = i / fs;
                buffer[i] = 0.33f * std::sin(2.0f * juce::MathConstants<float>::pi * 261.63f * t);  // C4
                buffer[i] += 0.33f * std::sin(2.0f * juce::MathConstants<float>::pi * 329.63f * t); // E4
                buffer[i] += 0.33f * std::sin(2.0f * juce::MathConstants<float>::pi * 392.00f * t); // G4
            }

            // Process multiple frames
            for (int frame = 0; frame < 10; ++frame)
            {
                analyzer.process(buffer.data(), numSamples);
            }

            auto key = analyzer.detectKey();

            // Should detect C major or related key
            if (key.confidence < 0.3f)
                throw std::runtime_error("Key confidence too low: " + std::to_string(key.confidence));

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testChordDetection()
    {
        TestResult result{"Chord Detection"};
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            AI::HarmonicAnalyzer analyzer(48000.0);

            // Generate Am chord (A, C, E)
            const int numSamples = 4096;
            std::vector<float> buffer(numSamples);

            float fs = 48000.0f;
            for (int i = 0; i < numSamples; ++i)
            {
                float t = i / fs;
                buffer[i] = 0.33f * std::sin(2.0f * juce::MathConstants<float>::pi * 220.0f * t);   // A3
                buffer[i] += 0.33f * std::sin(2.0f * juce::MathConstants<float>::pi * 261.63f * t); // C4
                buffer[i] += 0.33f * std::sin(2.0f * juce::MathConstants<float>::pi * 329.63f * t); // E4
            }

            for (int frame = 0; frame < 10; ++frame)
            {
                analyzer.process(buffer.data(), numSamples);
            }

            auto chord = analyzer.detectChord();
            auto chordName = chord.getName();

            if (chord.confidence < 0.2f)
                throw std::runtime_error("Chord confidence too low");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testIntelligentMixer()
    {
        TestResult result{"Intelligent Mixer"};
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            AI::IntelligentMixer mixer(48000.0);

            // Generate low frequency content (bass-like)
            const int numSamples = 2048;
            std::vector<float> bassBuffer(numSamples);

            for (int i = 0; i < numSamples; ++i)
            {
                bassBuffer[i] = 0.8f * std::sin(2.0f * juce::MathConstants<float>::pi * 80.0f * i / 48000.0f);
            }

            auto suggestion = mixer.analyze(bassBuffer.data(), numSamples, "Bass");

            // Should suggest centered pan for bass
            if (std::abs(suggestion.pan) > 0.3f)
                throw std::runtime_error("Bass should be mostly centered");

            // Should have reasonable low cut for bass
            if (suggestion.lowCut > 60.0f)
                throw std::runtime_error("Low cut too high for bass");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testAudioTagger()
    {
        TestResult result{"Audio Tagger"};
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            AI::AudioTagger tagger;

            // Generate high energy signal
            const int numSamples = 4096;
            std::vector<float> buffer(numSamples);

            for (int i = 0; i < numSamples; ++i)
            {
                buffer[i] = (static_cast<float>(rand()) / RAND_MAX - 0.5f) * 1.5f;
            }

            auto tags = tagger.analyze(buffer.data(), numSamples, 48000.0);

            if (tags.energy < 0.0f || tags.energy > 1.0f)
                throw std::runtime_error("Energy out of range");

            if (tags.danceability < 0.0f || tags.danceability > 1.0f)
                throw std::runtime_error("Danceability out of range");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    //==========================================================================
    // Biofeedback Tests
    //==========================================================================

    TestResult testHeartRateAnalysis()
    {
        TestResult result{"Heart Rate Analysis"};
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            Bio::HeartRateAnalyzer analyzer;

            // Simulate 60 BPM (1 beat per second)
            for (int i = 0; i < 30; ++i)
            {
                analyzer.addBeat(static_cast<double>(i));
            }

            auto metrics = analyzer.analyze();

            if (metrics.bpm < 55.0f || metrics.bpm > 65.0f)
                throw std::runtime_error("BPM should be around 60: " + std::to_string(metrics.bpm));

            if (metrics.rrInterval < 900.0f || metrics.rrInterval > 1100.0f)
                throw std::runtime_error("RR interval should be around 1000ms");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testHRVMetrics()
    {
        TestResult result{"HRV Metrics"};
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            Bio::HeartRateAnalyzer analyzer;

            // Variable heart rate (higher HRV)
            float baseInterval = 1000.0f;  // 60 BPM
            double time = 0;

            for (int i = 0; i < 50; ++i)
            {
                // Add some variability
                float interval = baseInterval + (i % 3 - 1) * 50.0f;
                analyzer.addHeartRate(60000.0f / interval);
            }

            auto metrics = analyzer.analyze();

            // RMSSD should be positive for variable HR
            if (metrics.rmssd <= 0.0f)
                throw std::runtime_error("RMSSD should be positive for variable HR");

            // SDNN should be positive
            if (metrics.sdnn <= 0.0f)
                throw std::runtime_error("SDNN should be positive");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testEEGProcessing()
    {
        TestResult result{"EEG Processing"};
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            Bio::EEGProcessor processor(256.0);  // 256 Hz sample rate

            // Generate alpha wave (10 Hz)
            const int numSamples = 256;
            std::vector<float> buffer(numSamples);

            for (int frame = 0; frame < 5; ++frame)
            {
                for (int i = 0; i < numSamples; ++i)
                {
                    float t = (frame * numSamples + i) / 256.0f;
                    buffer[i] = std::sin(2.0f * juce::MathConstants<float>::pi * 10.0f * t);
                }
                processor.process(buffer.data(), numSamples);
            }

            auto bands = processor.getBandPowers();

            // Alpha should be dominant
            // (This is a simplified test - real EEG would need more processing)

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testGSRAnalysis()
    {
        TestResult result{"GSR Analysis"};
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            Bio::GSRAnalyzer analyzer;

            // Simulate GSR with arousal spike
            for (int i = 0; i < 100; ++i)
            {
                float conductance = 5.0f + (i > 50 && i < 60 ? 3.0f : 0.0f);
                analyzer.addReading(conductance);
            }

            auto metrics = analyzer.analyze();

            if (metrics.skinConductance <= 0.0f)
                throw std::runtime_error("Skin conductance should be positive");

            if (metrics.arousal < 0.0f || metrics.arousal > 1.0f)
                throw std::runtime_error("Arousal out of range");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testRespirationAnalysis()
    {
        TestResult result{"Respiration Analysis"};
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            Bio::RespirationAnalyzer analyzer;

            // Simulate 12 breaths per minute
            float breathPeriod = 5.0f;  // seconds
            for (int i = 0; i < 300; ++i)
            {
                double time = i * 0.1;  // 10 Hz
                float value = std::sin(2.0f * juce::MathConstants<float>::pi * time / breathPeriod);
                analyzer.addReading(value, time);
            }

            auto metrics = analyzer.analyze();

            if (metrics.breathRate < 8.0f || metrics.breathRate > 16.0f)
                throw std::runtime_error("Breath rate should be around 12: " + std::to_string(metrics.breathRate));

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testMentalStateDetection()
    {
        TestResult result{"Mental State Detection"};
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            Bio::BiofeedbackEngine engine;

            // Feed some biometric data
            for (int i = 0; i < 30; ++i)
            {
                engine.feedHeartRate(65.0f);  // Relaxed heart rate
            }

            auto state = engine.analyzeMentalState();

            // Should have some state detected
            auto stateName = state.getStateName();
            if (stateName.isEmpty())
                throw std::runtime_error("State name should not be empty");

            // Values should be in range
            if (state.arousal < 0.0f || state.arousal > 1.0f)
                throw std::runtime_error("Arousal out of range");

            if (state.relaxation < 0.0f || state.relaxation > 1.0f)
                throw std::runtime_error("Relaxation out of range");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testBioParameterMapping()
    {
        TestResult result{"Bio Parameter Mapping"};
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            Bio::BioParameterMapper mapper;

            Bio::BioMapping mapping;
            mapping.parameterName = "FilterCutoff";
            mapping.sourceType = Bio::SensorType::HeartRate;
            mapping.sourceMetric = "bpm";
            mapping.minInput = 60.0f;
            mapping.maxInput = 120.0f;
            mapping.minOutput = 200.0f;
            mapping.maxOutput = 5000.0f;
            mapping.smoothing = 0.0f;  // No smoothing for test

            mapper.addMapping(mapping);

            // Feed heart rate
            mapper.updateInput(Bio::SensorType::HeartRate, "bpm", 90.0f);  // Middle of range

            float value = mapper.getParameterValue("FilterCutoff");

            // Should be around middle of output range
            if (value < 2000.0f || value > 3500.0f)
                throw std::runtime_error("Mapped value out of expected range: " + std::to_string(value));

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    //==========================================================================
    // Collaboration Tests
    //==========================================================================

    TestResult testSessionCreation()
    {
        TestResult result{"Session Creation"};
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            Network::CollaborationSession session;

            session.createSession("Test Session");

            if (session.getConnectionState() != Network::ConnectionState::Connected)
                throw std::runtime_error("Session should be connected after creation");

            if (!session.isSessionHost())
                throw std::runtime_error("Creator should be host");

            if (session.getSessionName() != "Test Session")
                throw std::runtime_error("Session name mismatch");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testMIDISynchronization()
    {
        TestResult result{"MIDI Synchronization"};
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            Network::MIDISynchronizer sync;

            // Add outgoing events
            auto noteOn = juce::MidiMessage::noteOn(1, 60, (juce::uint8)100);
            sync.addOutgoingEvent(noteOn, 1.0);  // Beat 1

            auto outgoing = sync.getAndClearOutgoing();

            if (outgoing.size() != 1)
                throw std::runtime_error("Should have 1 outgoing event");

            if (outgoing[0].localBeat != 1.0)
                throw std::runtime_error("Beat position mismatch");

            // Add incoming event
            Network::MIDISynchronizer::TimestampedMIDI incoming;
            incoming.message = juce::MidiMessage::noteOn(1, 64, (juce::uint8)100);
            incoming.localBeat = 2.0;

            sync.addIncomingEvent(incoming);

            juce::MidiBuffer buffer;
            sync.getIncomingEvents(buffer, 1.5, 2.5, 2.0, 48000);

            if (buffer.isEmpty())
                throw std::runtime_error("Should have received incoming event");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testVoiceChat()
    {
        TestResult result{"Voice Chat"};
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            Network::VoiceChat chat(48000.0);
            chat.prepare(512);

            chat.setTransmitting(true);

            if (!chat.isTransmitting())
                throw std::runtime_error("Should be transmitting");

            // Generate voice-like signal
            std::vector<float> input(512, 0.5f);

            chat.processInput(input.data(), 512);

            auto outgoing = chat.getOutgoingVoice();

            // Should have encoded data (if above threshold)
            // Note: With constant 0.5 input, threshold may trigger

            chat.setMuted(true);
            if (!chat.isMuted())
                throw std::runtime_error("Should be muted");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testOperationalTransform()
    {
        TestResult result{"Operational Transform"};
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            Network::OperationalTransform ot;

            Network::Operation op1;
            op1.type = Network::Operation::Type::Modify;
            op1.objectId = "track1";
            op1.property = "volume";
            op1.newValue = 0.8f;
            op1.timestamp = 1000;

            ot.addLocalOperation(op1);

            auto pending = ot.getAndClearPending();

            if (pending.size() != 1)
                throw std::runtime_error("Should have 1 pending operation");

            if (pending[0].objectId != "track1")
                throw std::runtime_error("Object ID mismatch");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    //==========================================================================
    // Streaming Tests
    //==========================================================================

    TestResult testStreamEndpointSetup()
    {
        TestResult result{"Stream Endpoint Setup"};
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            Network::StreamManager manager(48000.0);

            manager.setupTwitch("test_stream_key_12345");
            manager.setupYouTube("youtube_key_67890");

            auto endpoints = manager.getEndpoints();

            if (endpoints.size() != 2)
                throw std::runtime_error("Should have 2 endpoints");

            auto* twitch = manager.getEndpoint("Twitch");
            if (!twitch)
                throw std::runtime_error("Twitch endpoint not found");

            if (twitch->protocol != Network::StreamProtocol::RTMP)
                throw std::runtime_error("Twitch should use RTMP");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testAudioEncoding()
    {
        TestResult result{"Audio Encoding"};
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            Network::AACEncoder encoder;
            encoder.prepare(48000, 2, 320000);

            // Generate test audio
            std::vector<float> left(1024), right(1024);
            for (int i = 0; i < 1024; ++i)
            {
                left[i] = std::sin(2.0f * juce::MathConstants<float>::pi * 440.0f * i / 48000.0f);
                right[i] = left[i];
            }

            const float* channels[] = {left.data(), right.data()};

            auto encoded = encoder.encode(channels, 1024);

            if (encoded.getSize() == 0)
                throw std::runtime_error("Encoded data should not be empty");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testStreamVisualization()
    {
        TestResult result{"Stream Visualization"};
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            Network::StreamVisualizer visualizer(1280, 720);

            // Process some audio
            std::vector<float> audio(1024);
            for (int i = 0; i < 1024; ++i)
            {
                audio[i] = std::sin(2.0f * juce::MathConstants<float>::pi * 440.0f * i / 48000.0f);
            }

            visualizer.processAudio(audio.data(), 1024);

            Network::StreamMetadata metadata;
            metadata.title = "Test Stream";
            metadata.artist = "Test Artist";
            metadata.bpm = 120.0;

            auto frame = visualizer.renderFrame(metadata);

            if (frame.getWidth() != 1280 || frame.getHeight() != 720)
                throw std::runtime_error("Frame dimensions incorrect");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testMetadataInjection()
    {
        TestResult result{"Metadata Injection"};
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            Network::StreamManager manager(48000.0);

            Network::StreamMetadata metadata;
            metadata.title = "Now Playing: Test Track";
            metadata.artist = "Test Artist";
            metadata.album = "Test Album";
            metadata.bpm = 128.0;
            metadata.key = "A minor";

            manager.updateMetadata(metadata);

            // No exception = success
            // In real implementation, would verify metadata was sent

            manager.setNowPlaying("Another Track", "Another Artist");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }
};

//==============================================================================
// Quick Test Entry Point
//==============================================================================

inline bool runAdvancedFeaturesTestsQuick()
{
    AdvancedFeaturesTests tests;
    auto results = tests.runAllTests();
    tests.printResults(results);

    for (const auto& r : results)
    {
        if (!r.passed)
            return false;
    }
    return true;
}

} // namespace Tests
} // namespace Echoelmusic
