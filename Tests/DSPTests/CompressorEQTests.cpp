/**
 * Compressor & ParametricEQ Unit Tests
 *
 * Comprehensive tests for professional dynamics and equalization processors.
 *
 * Test Coverage:
 * - Compressor: Threshold, ratio, attack/release, knee, modes
 * - ParametricEQ: 8-band filtering, frequency response, Q factor, presets
 */

#define CATCH_CONFIG_MAIN
#include "catch.hpp"
#include "../../Sources/DSP/Compressor.h"
#include "../../Sources/DSP/ParametricEQ.h"
#include <cmath>
#include <vector>

// ===========================
// Test Utilities
// ===========================

constexpr float EPSILON = 1e-4f;
constexpr double SAMPLE_RATE = 48000.0;
constexpr int BLOCK_SIZE = 512;

std::vector<float> generateSine(float frequency, float amplitude, int numSamples, double sampleRate) {
    std::vector<float> signal(numSamples);
    for (int i = 0; i < numSamples; ++i) {
        signal[i] = amplitude * std::sin(2.0f * juce::MathConstants<float>::pi * frequency * i / sampleRate);
    }
    return signal;
}

float calculateRMS(const std::vector<float>& signal) {
    float sumSquares = 0.0f;
    for (float sample : signal) {
        sumSquares += sample * sample;
    }
    return std::sqrt(sumSquares / signal.size());
}

float calculatePeak(const juce::AudioBuffer<float>& buffer, int channel) {
    float peak = 0.0f;
    const float* data = buffer.getReadPointer(channel);
    for (int i = 0; i < buffer.getNumSamples(); ++i) {
        peak = std::max(peak, std::abs(data[i]));
    }
    return peak;
}

// ===========================
// Compressor Tests
// ===========================

TEST_CASE("Compressor - Basic Functionality", "[compressor][dynamics]") {
    Compressor comp;
    comp.prepare(SAMPLE_RATE, BLOCK_SIZE);
    comp.reset();

    SECTION("Compressor initializes correctly") {
        juce::AudioBuffer<float> buffer(2, BLOCK_SIZE);
        buffer.clear();

        comp.process(buffer);

        // Silent input should produce silent output
        for (int ch = 0; ch < 2; ++ch) {
            const float* data = buffer.getReadPointer(ch);
            for (int i = 0; i < BLOCK_SIZE; ++i) {
                REQUIRE(std::abs(data[i]) < EPSILON);
            }
        }
    }

    SECTION("Gain reduction is zero for signals below threshold") {
        comp.setThreshold(-20.0f);
        comp.setRatio(4.0f);

        // Generate quiet signal (well below threshold)
        auto quietSignal = generateSine(440.0f, 0.01f, BLOCK_SIZE, SAMPLE_RATE);

        juce::AudioBuffer<float> buffer(2, BLOCK_SIZE);
        buffer.copyFrom(0, 0, quietSignal.data(), BLOCK_SIZE);
        buffer.copyFrom(1, 0, quietSignal.data(), BLOCK_SIZE);

        comp.process(buffer);

        // Gain reduction should be minimal
        float gainReduction = comp.getGainReduction();
        REQUIRE(gainReduction >= 0.0f); // Gain reduction is always >= 0
        REQUIRE(gainReduction < 1.0f);  // Should be very small
    }
}

TEST_CASE("Compressor - Threshold and Ratio", "[compressor][threshold][ratio]") {
    Compressor comp;
    comp.prepare(SAMPLE_RATE, BLOCK_SIZE);

    SECTION("Higher ratio increases gain reduction") {
        comp.setThreshold(-20.0f);
        auto loudSignal = generateSine(440.0f, 0.5f, BLOCK_SIZE * 4, SAMPLE_RATE);

        // Test with 2:1 ratio
        comp.reset();
        comp.setRatio(2.0f);
        juce::AudioBuffer<float> buffer2to1(2, BLOCK_SIZE);
        for (int block = 0; block < 4; ++block) {
            buffer2to1.copyFrom(0, 0, loudSignal.data() + block * BLOCK_SIZE, BLOCK_SIZE);
            buffer2to1.copyFrom(1, 0, loudSignal.data() + block * BLOCK_SIZE, BLOCK_SIZE);
            comp.process(buffer2to1);
        }
        float gr2to1 = comp.getGainReduction();

        // Test with 10:1 ratio
        comp.reset();
        comp.setRatio(10.0f);
        juce::AudioBuffer<float> buffer10to1(2, BLOCK_SIZE);
        for (int block = 0; block < 4; ++block) {
            buffer10to1.copyFrom(0, 0, loudSignal.data() + block * BLOCK_SIZE, BLOCK_SIZE);
            buffer10to1.copyFrom(1, 0, loudSignal.data() + block * BLOCK_SIZE, BLOCK_SIZE);
            comp.process(buffer10to1);
        }
        float gr10to1 = comp.getGainReduction();

        // Higher ratio should produce more gain reduction
        REQUIRE(gr10to1 > gr2to1);
    }

    SECTION("Lower threshold triggers compression sooner") {
        comp.setRatio(4.0f);
        auto signal = generateSine(440.0f, 0.3f, BLOCK_SIZE * 4, SAMPLE_RATE);

        // Test with -30 dB threshold (high, less compression)
        comp.reset();
        comp.setThreshold(-30.0f);
        juce::AudioBuffer<float> bufferHighThresh(2, BLOCK_SIZE);
        for (int block = 0; block < 4; ++block) {
            bufferHighThresh.copyFrom(0, 0, signal.data() + block * BLOCK_SIZE, BLOCK_SIZE);
            bufferHighThresh.copyFrom(1, 0, signal.data() + block * BLOCK_SIZE, BLOCK_SIZE);
            comp.process(bufferHighThresh);
        }
        float grHighThresh = comp.getGainReduction();

        // Test with -10 dB threshold (low, more compression)
        comp.reset();
        comp.setThreshold(-10.0f);
        juce::AudioBuffer<float> bufferLowThresh(2, BLOCK_SIZE);
        for (int block = 0; block < 4; ++block) {
            bufferLowThresh.copyFrom(0, 0, signal.data() + block * BLOCK_SIZE, BLOCK_SIZE);
            bufferLowThresh.copyFrom(1, 0, signal.data() + block * BLOCK_SIZE, BLOCK_SIZE);
            comp.process(bufferLowThresh);
        }
        float grLowThresh = comp.getGainReduction();

        // Lower threshold should produce more gain reduction
        REQUIRE(grLowThresh > grHighThresh);
    }
}

TEST_CASE("Compressor - Attack and Release", "[compressor][envelope]") {
    Compressor comp;
    comp.prepare(SAMPLE_RATE, BLOCK_SIZE);

    SECTION("Fast attack responds quickly to transients") {
        comp.setThreshold(-20.0f);
        comp.setRatio(8.0f);

        // Fast attack (0.5 ms)
        comp.reset();
        comp.setAttack(0.5f);
        comp.setRelease(100.0f);

        auto transient = generateSine(440.0f, 0.8f, BLOCK_SIZE, SAMPLE_RATE);
        juce::AudioBuffer<float> bufferFast(2, BLOCK_SIZE);
        bufferFast.copyFrom(0, 0, transient.data(), BLOCK_SIZE);
        bufferFast.copyFrom(1, 0, transient.data(), BLOCK_SIZE);

        comp.process(bufferFast);
        float peakFast = calculatePeak(bufferFast, 0);

        // Slow attack (50 ms)
        comp.reset();
        comp.setAttack(50.0f);
        comp.setRelease(100.0f);

        juce::AudioBuffer<float> bufferSlow(2, BLOCK_SIZE);
        bufferSlow.copyFrom(0, 0, transient.data(), BLOCK_SIZE);
        bufferSlow.copyFrom(1, 0, transient.data(), BLOCK_SIZE);

        comp.process(bufferSlow);
        float peakSlow = calculatePeak(bufferSlow, 0);

        // Fast attack should reduce peak more (catches transient faster)
        REQUIRE(peakFast < peakSlow);
    }
}

TEST_CASE("Compressor - Modes", "[compressor][modes]") {
    Compressor comp;
    comp.prepare(SAMPLE_RATE, BLOCK_SIZE);
    comp.setThreshold(-20.0f);
    comp.setRatio(4.0f);

    auto signal = generateSine(440.0f, 0.5f, BLOCK_SIZE * 2, SAMPLE_RATE);

    SECTION("All modes process without crashes") {
        std::vector<Compressor::Mode> modes = {
            Compressor::Mode::Transparent,
            Compressor::Mode::Vintage,
            Compressor::Mode::Aggressive
        };

        for (auto mode : modes) {
            comp.reset();
            comp.setMode(mode);

            juce::AudioBuffer<float> buffer(2, BLOCK_SIZE);
            buffer.copyFrom(0, 0, signal.data(), BLOCK_SIZE);
            buffer.copyFrom(1, 0, signal.data(), BLOCK_SIZE);

            REQUIRE_NOTHROW(comp.process(buffer));

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
}

TEST_CASE("Compressor - Makeup Gain", "[compressor][gain]") {
    Compressor comp;
    comp.prepare(SAMPLE_RATE, BLOCK_SIZE);
    comp.setThreshold(-20.0f);
    comp.setRatio(4.0f);

    auto signal = generateSine(440.0f, 0.5f, BLOCK_SIZE * 4, SAMPLE_RATE);

    SECTION("Makeup gain increases output level") {
        // Process without makeup gain
        comp.reset();
        comp.setMakeupGain(0.0f);
        juce::AudioBuffer<float> bufferNoGain(2, BLOCK_SIZE);
        for (int block = 0; block < 4; ++block) {
            bufferNoGain.copyFrom(0, 0, signal.data() + block * BLOCK_SIZE, BLOCK_SIZE);
            bufferNoGain.copyFrom(1, 0, signal.data() + block * BLOCK_SIZE, BLOCK_SIZE);
            comp.process(bufferNoGain);
        }
        float rmsNoGain = calculateRMS(std::vector<float>(
            bufferNoGain.getReadPointer(0),
            bufferNoGain.getReadPointer(0) + BLOCK_SIZE
        ));

        // Process with +6 dB makeup gain
        comp.reset();
        comp.setMakeupGain(6.0f);
        juce::AudioBuffer<float> bufferWithGain(2, BLOCK_SIZE);
        for (int block = 0; block < 4; ++block) {
            bufferWithGain.copyFrom(0, 0, signal.data() + block * BLOCK_SIZE, BLOCK_SIZE);
            bufferWithGain.copyFrom(1, 0, signal.data() + block * BLOCK_SIZE, BLOCK_SIZE);
            comp.process(bufferWithGain);
        }
        float rmsWithGain = calculateRMS(std::vector<float>(
            bufferWithGain.getReadPointer(0),
            bufferWithGain.getReadPointer(0) + BLOCK_SIZE
        ));

        // With makeup gain should be louder
        REQUIRE(rmsWithGain > rmsNoGain);
    }
}

// ===========================
// ParametricEQ Tests
// ===========================

TEST_CASE("ParametricEQ - Basic Functionality", "[eq][parametric]") {
    ParametricEQ eq;
    eq.prepare(SAMPLE_RATE, BLOCK_SIZE);
    eq.reset();

    SECTION("EQ initializes correctly") {
        juce::AudioBuffer<float> buffer(2, BLOCK_SIZE);
        buffer.clear();

        eq.process(buffer);

        // Silent input should produce silent output
        for (int ch = 0; ch < 2; ++ch) {
            const float* data = buffer.getReadPointer(ch);
            for (int i = 0; i < BLOCK_SIZE; ++i) {
                REQUIRE(std::abs(data[i]) < EPSILON);
            }
        }
    }

    SECTION("All bands disabled by default (flat response)") {
        for (int i = 0; i < ParametricEQ::numBands; ++i) {
            auto band = eq.getBand(i);
            REQUIRE_FALSE(band.enabled);
        }
    }
}

TEST_CASE("ParametricEQ - Band Configuration", "[eq][bands]") {
    ParametricEQ eq;
    eq.prepare(SAMPLE_RATE, BLOCK_SIZE);

    SECTION("Can configure individual bands") {
        ParametricEQ::Band band;
        band.type = ParametricEQ::Band::Type::Bell;
        band.frequency = 1000.0f;
        band.gain = 6.0f;
        band.Q = 2.0f;
        band.enabled = true;

        REQUIRE_NOTHROW(eq.setBand(0, band));

        auto retrievedBand = eq.getBand(0);
        REQUIRE(retrievedBand.type == ParametricEQ::Band::Type::Bell);
        REQUIRE(retrievedBand.frequency == 1000.0f);
        REQUIRE(retrievedBand.gain == 6.0f);
        REQUIRE(retrievedBand.Q == 2.0f);
        REQUIRE(retrievedBand.enabled == true);
    }

    SECTION("Can enable/disable bands individually") {
        eq.setBandEnabled(0, true);
        REQUIRE(eq.getBand(0).enabled == true);

        eq.setBandEnabled(0, false);
        REQUIRE(eq.getBand(0).enabled == false);
    }
}

TEST_CASE("ParametricEQ - Frequency Response", "[eq][frequency]") {
    ParametricEQ eq;
    eq.prepare(SAMPLE_RATE, BLOCK_SIZE);
    eq.reset();

    SECTION("Bell filter boosts target frequency") {
        // Configure band 0 as bell filter at 1000 Hz, +12 dB gain
        ParametricEQ::Band band;
        band.type = ParametricEQ::Band::Type::Bell;
        band.frequency = 1000.0f;
        band.gain = 12.0f;
        band.Q = 2.0f;
        band.enabled = true;
        eq.setBand(0, band);

        // Test signal at target frequency (1000 Hz)
        auto signal1k = generateSine(1000.0f, 0.1f, BLOCK_SIZE * 4, SAMPLE_RATE);

        juce::AudioBuffer<float> buffer(2, BLOCK_SIZE);
        for (int block = 0; block < 4; ++block) {
            buffer.copyFrom(0, 0, signal1k.data() + block * BLOCK_SIZE, BLOCK_SIZE);
            buffer.copyFrom(1, 0, signal1k.data() + block * BLOCK_SIZE, BLOCK_SIZE);
            eq.process(buffer);
        }

        float rms1k = calculateRMS(std::vector<float>(
            buffer.getReadPointer(0),
            buffer.getReadPointer(0) + BLOCK_SIZE
        ));

        // Test signal at different frequency (100 Hz)
        eq.reset();
        auto signal100 = generateSine(100.0f, 0.1f, BLOCK_SIZE * 4, SAMPLE_RATE);

        juce::AudioBuffer<float> buffer100(2, BLOCK_SIZE);
        for (int block = 0; block < 4; ++block) {
            buffer100.copyFrom(0, 0, signal100.data() + block * BLOCK_SIZE, BLOCK_SIZE);
            buffer100.copyFrom(1, 0, signal100.data() + block * BLOCK_SIZE, BLOCK_SIZE);
            eq.process(buffer100);
        }

        float rms100 = calculateRMS(std::vector<float>(
            buffer100.getReadPointer(0),
            buffer100.getReadPointer(0) + BLOCK_SIZE
        ));

        // 1000 Hz should be boosted more than 100 Hz
        REQUIRE(rms1k > rms100);
    }
}

TEST_CASE("ParametricEQ - Filter Types", "[eq][filters]") {
    ParametricEQ eq;
    eq.prepare(SAMPLE_RATE, BLOCK_SIZE);

    auto signal = generateSine(1000.0f, 0.5f, BLOCK_SIZE, SAMPLE_RATE);

    SECTION("All filter types process without crashes") {
        std::vector<ParametricEQ::Band::Type> types = {
            ParametricEQ::Band::Type::LowPass,
            ParametricEQ::Band::Type::HighPass,
            ParametricEQ::Band::Type::LowShelf,
            ParametricEQ::Band::Type::HighShelf,
            ParametricEQ::Band::Type::Bell,
            ParametricEQ::Band::Type::Notch,
            ParametricEQ::Band::Type::BandPass
        };

        for (auto type : types) {
            eq.reset();

            ParametricEQ::Band band;
            band.type = type;
            band.frequency = 1000.0f;
            band.gain = 6.0f;
            band.Q = 1.0f;
            band.enabled = true;
            eq.setBand(0, band);

            juce::AudioBuffer<float> buffer(2, BLOCK_SIZE);
            buffer.copyFrom(0, 0, signal.data(), BLOCK_SIZE);
            buffer.copyFrom(1, 0, signal.data(), BLOCK_SIZE);

            REQUIRE_NOTHROW(eq.process(buffer));

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
}

TEST_CASE("ParametricEQ - Presets", "[eq][presets]") {
    ParametricEQ eq;
    eq.prepare(SAMPLE_RATE, BLOCK_SIZE);

    auto signal = generateSine(1000.0f, 0.5f, BLOCK_SIZE, SAMPLE_RATE);

    SECTION("All presets load and process correctly") {
        std::vector<std::function<void()>> presets = {
            [&]() { eq.presetFlat(); },
            [&]() { eq.presetVocalWarmth(); },
            [&]() { eq.presetKickPunch(); },
            [&]() { eq.presetAirySynth(); },
            [&]() { eq.presetMasterBrightness(); }
        };

        for (auto& loadPreset : presets) {
            eq.reset();
            REQUIRE_NOTHROW(loadPreset());

            juce::AudioBuffer<float> buffer(2, BLOCK_SIZE);
            buffer.copyFrom(0, 0, signal.data(), BLOCK_SIZE);
            buffer.copyFrom(1, 0, signal.data(), BLOCK_SIZE);

            REQUIRE_NOTHROW(eq.process(buffer));

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
}

TEST_CASE("ParametricEQ - Q Factor", "[eq][q]") {
    ParametricEQ eq;
    eq.prepare(SAMPLE_RATE, BLOCK_SIZE);

    SECTION("Higher Q creates narrower filter") {
        // This is a conceptual test - actual frequency response analysis
        // would require FFT. We just verify Q can be set and processed.

        ParametricEQ::Band narrowBand;
        narrowBand.type = ParametricEQ::Band::Type::Bell;
        narrowBand.frequency = 1000.0f;
        narrowBand.gain = 12.0f;
        narrowBand.Q = 10.0f;  // Very narrow
        narrowBand.enabled = true;

        REQUIRE_NOTHROW(eq.setBand(0, narrowBand));

        ParametricEQ::Band wideBand;
        wideBand.type = ParametricEQ::Band::Type::Bell;
        wideBand.frequency = 1000.0f;
        wideBand.gain = 12.0f;
        wideBand.Q = 0.5f;  // Very wide
        wideBand.enabled = true;

        REQUIRE_NOTHROW(eq.setBand(1, wideBand));

        auto signal = generateSine(1000.0f, 0.5f, BLOCK_SIZE, SAMPLE_RATE);
        juce::AudioBuffer<float> buffer(2, BLOCK_SIZE);
        buffer.copyFrom(0, 0, signal.data(), BLOCK_SIZE);
        buffer.copyFrom(1, 0, signal.data(), BLOCK_SIZE);

        REQUIRE_NOTHROW(eq.process(buffer));
    }
}

// ===========================
// Stability Tests
// ===========================

TEST_CASE("Compressor & EQ - Extreme Parameters", "[stability][safety]") {
    SECTION("Compressor handles extreme values") {
        Compressor comp;
        comp.prepare(SAMPLE_RATE, BLOCK_SIZE);

        // Extreme parameters
        comp.setThreshold(-60.0f);
        comp.setRatio(20.0f);
        comp.setAttack(0.1f);
        comp.setRelease(1000.0f);
        comp.setKnee(12.0f);
        comp.setMakeupGain(24.0f);

        auto signal = generateSine(440.0f, 1.0f, BLOCK_SIZE, SAMPLE_RATE);
        juce::AudioBuffer<float> buffer(2, BLOCK_SIZE);
        buffer.copyFrom(0, 0, signal.data(), BLOCK_SIZE);
        buffer.copyFrom(1, 0, signal.data(), BLOCK_SIZE);

        REQUIRE_NOTHROW(comp.process(buffer));

        // Check for NaN/Inf
        for (int ch = 0; ch < 2; ++ch) {
            const float* data = buffer.getReadPointer(ch);
            for (int i = 0; i < BLOCK_SIZE; ++i) {
                REQUIRE_FALSE(std::isnan(data[i]));
                REQUIRE_FALSE(std::isinf(data[i]));
            }
        }
    }

    SECTION("ParametricEQ handles extreme values") {
        ParametricEQ eq;
        eq.prepare(SAMPLE_RATE, BLOCK_SIZE);

        // Configure all bands with extreme values
        for (int i = 0; i < ParametricEQ::numBands; ++i) {
            ParametricEQ::Band band;
            band.type = ParametricEQ::Band::Type::Bell;
            band.frequency = (i == 0) ? 20.0f : 20000.0f;  // Extremes
            band.gain = (i % 2 == 0) ? 24.0f : -24.0f;      // Max boost/cut
            band.Q = (i % 3 == 0) ? 0.1f : 10.0f;           // Extreme Q
            band.enabled = true;
            eq.setBand(i, band);
        }

        auto signal = generateSine(1000.0f, 1.0f, BLOCK_SIZE, SAMPLE_RATE);
        juce::AudioBuffer<float> buffer(2, BLOCK_SIZE);
        buffer.copyFrom(0, 0, signal.data(), BLOCK_SIZE);
        buffer.copyFrom(1, 0, signal.data(), BLOCK_SIZE);

        REQUIRE_NOTHROW(eq.process(buffer));

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
