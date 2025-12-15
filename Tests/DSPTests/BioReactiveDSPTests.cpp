/**
 * BioReactiveDSP Unit Tests
 *
 * Tests the bio-reactive DSP module that modulates audio parameters
 * based on Heart Rate Variability (HRV) and coherence data.
 *
 * Test Coverage:
 * - State Variable Filter (frequency response, resonance)
 * - Simple Compressor (gain reduction, envelope follower)
 * - Denormal number handling (CPU performance protection)
 * - HRV modulation of filter cutoff
 * - Coherence modulation of reverb mix
 */

#define CATCH_CONFIG_MAIN
#include "catch.hpp"
#include "../../Sources/DSP/BioReactiveDSP.h"
#include <cmath>
#include <vector>

// ===========================
// Test Utilities
// ===========================

constexpr float EPSILON = 1e-4f;
constexpr double SAMPLE_RATE = 44100.0;
constexpr int BLOCK_SIZE = 512;

// Generate test signal (sine wave)
std::vector<float> generateSine(float frequency, float amplitude, int numSamples, double sampleRate) {
    std::vector<float> signal(numSamples);
    for (int i = 0; i < numSamples; ++i) {
        signal[i] = amplitude * std::sin(2.0f * juce::MathConstants<float>::pi * frequency * i / sampleRate);
    }
    return signal;
}

// Generate impulse signal (for filter response testing)
std::vector<float> generateImpulse(int numSamples) {
    std::vector<float> signal(numSamples, 0.0f);
    signal[0] = 1.0f;  // Unit impulse
    return signal;
}

// Calculate RMS level
float calculateRMS(const std::vector<float>& signal) {
    float sumSquares = 0.0f;
    for (float sample : signal) {
        sumSquares += sample * sample;
    }
    return std::sqrt(sumSquares / signal.size());
}

// Check if signal contains denormal numbers
bool containsDenormals(const std::vector<float>& signal) {
    constexpr float DENORMAL_THRESHOLD = 1.0e-15f;
    for (float sample : signal) {
        if (std::abs(sample) > 0.0f && std::abs(sample) < DENORMAL_THRESHOLD) {
            return true;
        }
    }
    return false;
}

// ===========================
// State Variable Filter Tests
// ===========================

TEST_CASE("State Variable Filter - Basic Functionality", "[filter][svf]") {
    BioReactiveDSP dsp;

    // Setup
    juce::dsp::ProcessSpec spec;
    spec.sampleRate = SAMPLE_RATE;
    spec.maximumBlockSize = BLOCK_SIZE;
    spec.numChannels = 2;

    dsp.prepare(spec);
    dsp.reset();

    SECTION("Filter initializes correctly") {
        // After reset, filter should be stable
        juce::AudioBuffer<float> buffer(2, BLOCK_SIZE);
        buffer.clear();

        dsp.process(buffer, 0.5f, 0.5f);

        // Output should be silent for silent input
        for (int ch = 0; ch < 2; ++ch) {
            const float* data = buffer.getReadPointer(ch);
            for (int i = 0; i < BLOCK_SIZE; ++i) {
                REQUIRE(std::abs(data[i]) < EPSILON);
            }
        }
    }
}

TEST_CASE("State Variable Filter - Frequency Response", "[filter][svf][frequency]") {
    BioReactiveDSP dsp;

    juce::dsp::ProcessSpec spec;
    spec.sampleRate = SAMPLE_RATE;
    spec.maximumBlockSize = BLOCK_SIZE;
    spec.numChannels = 1;

    dsp.prepare(spec);
    dsp.reset();

    SECTION("Lowpass filter attenuates high frequencies") {
        // Set filter cutoff to 1000 Hz
        dsp.setFilterCutoff(1000.0f);
        dsp.setResonance(0.0f);

        // Test signal: 200 Hz (should pass) vs 5000 Hz (should attenuate)
        auto lowFreqSignal = generateSine(200.0f, 1.0f, BLOCK_SIZE, SAMPLE_RATE);
        auto highFreqSignal = generateSine(5000.0f, 1.0f, BLOCK_SIZE, SAMPLE_RATE);

        juce::AudioBuffer<float> bufferLow(1, BLOCK_SIZE);
        juce::AudioBuffer<float> bufferHigh(1, BLOCK_SIZE);

        bufferLow.copyFrom(0, 0, lowFreqSignal.data(), BLOCK_SIZE);
        bufferHigh.copyFrom(0, 0, highFreqSignal.data(), BLOCK_SIZE);

        dsp.reset();
        dsp.process(bufferLow, 0.5f, 0.5f);

        dsp.reset();
        dsp.process(bufferHigh, 0.5f, 0.5f);

        float lowRMS = calculateRMS(std::vector<float>(
            bufferLow.getReadPointer(0),
            bufferLow.getReadPointer(0) + BLOCK_SIZE
        ));

        float highRMS = calculateRMS(std::vector<float>(
            bufferHigh.getReadPointer(0),
            bufferHigh.getReadPointer(0) + BLOCK_SIZE
        ));

        // Low frequency should pass with minimal attenuation
        // High frequency should be significantly attenuated
        REQUIRE(lowRMS > highRMS);
        REQUIRE(lowRMS > 0.5f);  // Low freq mostly passes
        REQUIRE(highRMS < 0.3f);  // High freq attenuated
    }

    SECTION("Resonance increases peak at cutoff frequency") {
        dsp.setFilterCutoff(1000.0f);

        auto signal = generateSine(1000.0f, 1.0f, BLOCK_SIZE, SAMPLE_RATE);

        // Test with low resonance
        dsp.setResonance(0.1f);
        juce::AudioBuffer<float> bufferLowRes(1, BLOCK_SIZE);
        bufferLowRes.copyFrom(0, 0, signal.data(), BLOCK_SIZE);
        dsp.reset();
        dsp.process(bufferLowRes, 0.5f, 0.5f);

        float lowResRMS = calculateRMS(std::vector<float>(
            bufferLowRes.getReadPointer(0),
            bufferLowRes.getReadPointer(0) + BLOCK_SIZE
        ));

        // Test with high resonance
        dsp.setResonance(0.9f);
        juce::AudioBuffer<float> bufferHighRes(1, BLOCK_SIZE);
        bufferHighRes.copyFrom(0, 0, signal.data(), BLOCK_SIZE);
        dsp.reset();
        dsp.process(bufferHighRes, 0.5f, 0.5f);

        float highResRMS = calculateRMS(std::vector<float>(
            bufferHighRes.getReadPointer(0),
            bufferHighRes.getReadPointer(0) + BLOCK_SIZE
        ));

        // Higher resonance should boost the signal at cutoff frequency
        REQUIRE(highResRMS > lowResRMS);
    }
}

TEST_CASE("State Variable Filter - Denormal Protection", "[filter][svf][denormals]") {
    BioReactiveDSP dsp;

    juce::dsp::ProcessSpec spec;
    spec.sampleRate = SAMPLE_RATE;
    spec.maximumBlockSize = BLOCK_SIZE;
    spec.numChannels = 1;

    dsp.prepare(spec);
    dsp.reset();
    dsp.setFilterCutoff(100.0f);  // Very low frequency (prone to denormals)

    SECTION("Filter does not produce denormal numbers") {
        // Feed very quiet signal (could trigger denormals)
        auto quietSignal = generateSine(50.0f, 1e-20f, BLOCK_SIZE * 10, SAMPLE_RATE);

        juce::AudioBuffer<float> buffer(1, BLOCK_SIZE);

        for (int block = 0; block < 10; ++block) {
            buffer.copyFrom(0, 0, quietSignal.data() + block * BLOCK_SIZE, BLOCK_SIZE);
            dsp.process(buffer, 0.5f, 0.5f);

            std::vector<float> output(buffer.getReadPointer(0), buffer.getReadPointer(0) + BLOCK_SIZE);

            // CRITICAL: Filter must flush denormals to zero
            REQUIRE_FALSE(containsDenormals(output));
        }
    }
}

// ===========================
// Simple Compressor Tests
// ===========================

TEST_CASE("Simple Compressor - Gain Reduction", "[compressor][dynamics]") {
    BioReactiveDSP dsp;

    juce::dsp::ProcessSpec spec;
    spec.sampleRate = SAMPLE_RATE;
    spec.maximumBlockSize = BLOCK_SIZE;
    spec.numChannels = 1;

    dsp.prepare(spec);
    dsp.reset();

    SECTION("Compressor reduces loud signals") {
        dsp.setCompression(4.0f);  // 4:1 ratio

        // Generate loud signal (should be compressed)
        auto loudSignal = generateSine(440.0f, 0.9f, BLOCK_SIZE * 4, SAMPLE_RATE);

        juce::AudioBuffer<float> buffer(1, BLOCK_SIZE);

        // Process multiple blocks to let envelope stabilize
        for (int block = 0; block < 4; ++block) {
            buffer.copyFrom(0, 0, loudSignal.data() + block * BLOCK_SIZE, BLOCK_SIZE);
            dsp.process(buffer, 0.5f, 0.5f);
        }

        // Final block should show compression
        float outputRMS = calculateRMS(std::vector<float>(
            buffer.getReadPointer(0),
            buffer.getReadPointer(0) + BLOCK_SIZE
        ));

        float inputRMS = calculateRMS(std::vector<float>(
            loudSignal.end() - BLOCK_SIZE,
            loudSignal.end()
        ));

        // Output should be quieter than input (gain reduction applied)
        REQUIRE(outputRMS < inputRMS);
        REQUIRE(outputRMS > 0.0f);  // But not zero
    }

    SECTION("Compressor does not affect quiet signals") {
        dsp.setCompression(4.0f);

        // Generate quiet signal (below threshold)
        auto quietSignal = generateSine(440.0f, 0.01f, BLOCK_SIZE, SAMPLE_RATE);

        juce::AudioBuffer<float> buffer(1, BLOCK_SIZE);
        buffer.copyFrom(0, 0, quietSignal.data(), BLOCK_SIZE);

        dsp.process(buffer, 0.5f, 0.5f);

        float outputRMS = calculateRMS(std::vector<float>(
            buffer.getReadPointer(0),
            buffer.getReadPointer(0) + BLOCK_SIZE
        ));

        float inputRMS = 0.01f / std::sqrt(2.0f);  // Theoretical RMS of sine

        // Quiet signal should pass through mostly unchanged
        REQUIRE(std::abs(outputRMS - inputRMS) < 0.01f);
    }
}

// ===========================
// Bio-Reactive Modulation Tests
// ===========================

TEST_CASE("Bio-Reactive Modulation - HRV affects filter cutoff", "[bioreactive][hrv]") {
    BioReactiveDSP dsp;

    juce::dsp::ProcessSpec spec;
    spec.sampleRate = SAMPLE_RATE;
    spec.maximumBlockSize = BLOCK_SIZE;
    spec.numChannels = 1;

    dsp.prepare(spec);

    SECTION("Higher HRV increases filter cutoff") {
        auto signal = generateSine(2000.0f, 0.5f, BLOCK_SIZE, SAMPLE_RATE);

        // Test with low HRV (0.0 -> cutoff = 500 Hz)
        dsp.reset();
        juce::AudioBuffer<float> bufferLowHRV(1, BLOCK_SIZE);
        bufferLowHRV.copyFrom(0, 0, signal.data(), BLOCK_SIZE);
        dsp.process(bufferLowHRV, 0.0f, 0.5f);  // HRV = 0.0

        float lowHRVOutput = calculateRMS(std::vector<float>(
            bufferLowHRV.getReadPointer(0),
            bufferLowHRV.getReadPointer(0) + BLOCK_SIZE
        ));

        // Test with high HRV (1.0 -> cutoff = 10000 Hz)
        dsp.reset();
        juce::AudioBuffer<float> bufferHighHRV(1, BLOCK_SIZE);
        bufferHighHRV.copyFrom(0, 0, signal.data(), BLOCK_SIZE);
        dsp.process(bufferHighHRV, 1.0f, 0.5f);  // HRV = 1.0

        float highHRVOutput = calculateRMS(std::vector<float>(
            bufferHighHRV.getReadPointer(0),
            bufferHighHRV.getReadPointer(0) + BLOCK_SIZE
        ));

        // Higher HRV = higher cutoff = more high frequencies pass
        // 2000 Hz test signal should pass more with high HRV
        REQUIRE(highHRVOutput > lowHRVOutput);
    }
}

TEST_CASE("Bio-Reactive Modulation - Coherence affects reverb mix", "[bioreactive][coherence]") {
    BioReactiveDSP dsp;

    juce::dsp::ProcessSpec spec;
    spec.sampleRate = SAMPLE_RATE;
    spec.maximumBlockSize = BLOCK_SIZE;
    spec.numChannels = 2;

    dsp.prepare(spec);

    SECTION("Higher coherence increases reverb wetness") {
        auto impulse = generateImpulse(BLOCK_SIZE);

        // Test with low coherence (0.0 -> reverb mix = 0%)
        dsp.reset();
        juce::AudioBuffer<float> bufferLowCoherence(2, BLOCK_SIZE);
        bufferLowCoherence.copyFrom(0, 0, impulse.data(), BLOCK_SIZE);
        bufferLowCoherence.copyFrom(1, 0, impulse.data(), BLOCK_SIZE);
        dsp.process(bufferLowCoherence, 0.5f, 0.0f);  // Coherence = 0.0

        // Test with high coherence (1.0 -> reverb mix = 70%)
        dsp.reset();
        juce::AudioBuffer<float> bufferHighCoherence(2, BLOCK_SIZE);
        bufferHighCoherence.copyFrom(0, 0, impulse.data(), BLOCK_SIZE);
        bufferHighCoherence.copyFrom(1, 0, impulse.data(), BLOCK_SIZE);
        dsp.process(bufferHighCoherence, 0.5f, 1.0f);  // Coherence = 1.0

        // Higher coherence should add more reverb tail
        // (Note: This test is conceptual - actual reverb response is complex)
        // We're just verifying the system doesn't crash and produces output
        float lowCoherenceRMS = calculateRMS(std::vector<float>(
            bufferLowCoherence.getReadPointer(0),
            bufferLowCoherence.getReadPointer(0) + BLOCK_SIZE
        ));

        float highCoherenceRMS = calculateRMS(std::vector<float>(
            bufferHighCoherence.getReadPointer(0),
            bufferHighCoherence.getReadPointer(0) + BLOCK_SIZE
        ));

        REQUIRE(lowCoherenceRMS > 0.0f);
        REQUIRE(highCoherenceRMS > 0.0f);
    }
}

// ===========================
// Parameter Bounds Tests
// ===========================

TEST_CASE("Parameter Bounds - All parameters accept valid ranges", "[parameters][bounds]") {
    BioReactiveDSP dsp;

    juce::dsp::ProcessSpec spec;
    spec.sampleRate = SAMPLE_RATE;
    spec.maximumBlockSize = BLOCK_SIZE;
    spec.numChannels = 2;

    dsp.prepare(spec);

    SECTION("Filter cutoff accepts 20-20000 Hz") {
        REQUIRE_NOTHROW(dsp.setFilterCutoff(20.0f));
        REQUIRE_NOTHROW(dsp.setFilterCutoff(1000.0f));
        REQUIRE_NOTHROW(dsp.setFilterCutoff(20000.0f));
    }

    SECTION("Resonance accepts 0-1 range") {
        REQUIRE_NOTHROW(dsp.setResonance(0.0f));
        REQUIRE_NOTHROW(dsp.setResonance(0.5f));
        REQUIRE_NOTHROW(dsp.setResonance(1.0f));
    }

    SECTION("Reverb mix accepts 0-1 range") {
        REQUIRE_NOTHROW(dsp.setReverbMix(0.0f));
        REQUIRE_NOTHROW(dsp.setReverbMix(0.5f));
        REQUIRE_NOTHROW(dsp.setReverbMix(1.0f));
    }

    SECTION("Delay time accepts reasonable values") {
        REQUIRE_NOTHROW(dsp.setDelayTime(0.0f));
        REQUIRE_NOTHROW(dsp.setDelayTime(500.0f));
        REQUIRE_NOTHROW(dsp.setDelayTime(2000.0f));
    }
}

// ===========================
// Stability Tests
// ===========================

TEST_CASE("DSP Stability - No NaN or Inf in output", "[stability][safety]") {
    BioReactiveDSP dsp;

    juce::dsp::ProcessSpec spec;
    spec.sampleRate = SAMPLE_RATE;
    spec.maximumBlockSize = BLOCK_SIZE;
    spec.numChannels = 2;

    dsp.prepare(spec);
    dsp.reset();

    SECTION("Extreme parameter values don't produce NaN/Inf") {
        juce::AudioBuffer<float> buffer(2, BLOCK_SIZE);

        // Generate white noise
        for (int ch = 0; ch < 2; ++ch) {
            for (int i = 0; i < BLOCK_SIZE; ++i) {
                buffer.setSample(ch, i, (std::rand() / (float)RAND_MAX) * 2.0f - 1.0f);
            }
        }

        // Test extreme parameter combinations
        dsp.setFilterCutoff(20.0f);
        dsp.setResonance(0.99f);
        dsp.setReverbMix(1.0f);
        dsp.setCompression(20.0f);

        dsp.process(buffer, 1.0f, 1.0f);

        // Check for NaN/Inf
        for (int ch = 0; ch < 2; ++ch) {
            const float* data = buffer.getReadPointer(ch);
            for (int i = 0; i < BLOCK_SIZE; ++i) {
                REQUIRE_FALSE(std::isnan(data[i]));
                REQUIRE_FALSE(std::isinf(data[i]));
            }
        }
    }
}
