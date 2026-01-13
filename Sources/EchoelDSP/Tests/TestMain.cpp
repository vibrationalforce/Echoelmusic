// ============================================================================
// EchoelDSP Unit Tests
// ============================================================================
// Comprehensive test suite for zero-dependency audio DSP library
// ============================================================================

#include "../EchoelDSP.h"
#include "../SIMD.h"
#include "../AudioBuffer.h"
#include "../FFT.h"
#include "../Filters.h"
#include "../MIDI2.h"
#include <cassert>
#include <cmath>
#include <iostream>
#include <vector>
#include <chrono>

using namespace Echoel::DSP;

// ============================================================================
// Test Utilities
// ============================================================================

static int testsRun = 0;
static int testsPassed = 0;
static int testsFailed = 0;

#define TEST(name) \
    void test_##name(); \
    struct TestRunner_##name { \
        TestRunner_##name() { \
            std::cout << "  Running: " << #name << "... "; \
            testsRun++; \
            try { \
                test_##name(); \
                std::cout << "PASSED" << std::endl; \
                testsPassed++; \
            } catch (const std::exception& e) { \
                std::cout << "FAILED: " << e.what() << std::endl; \
                testsFailed++; \
            } catch (...) { \
                std::cout << "FAILED: Unknown exception" << std::endl; \
                testsFailed++; \
            } \
        } \
    } testRunner_##name; \
    void test_##name()

#define ASSERT_EQ(a, b) \
    if ((a) != (b)) { \
        throw std::runtime_error("Assertion failed: " #a " != " #b); \
    }

#define ASSERT_NEAR(a, b, tolerance) \
    if (std::abs((a) - (b)) > (tolerance)) { \
        throw std::runtime_error("Assertion failed: " #a " not near " #b); \
    }

#define ASSERT_TRUE(cond) \
    if (!(cond)) { \
        throw std::runtime_error("Assertion failed: " #cond); \
    }

#define ASSERT_FALSE(cond) \
    if (cond) { \
        throw std::runtime_error("Assertion failed: " #cond " should be false"); \
    }

// ============================================================================
// SIMD Tests
// ============================================================================

TEST(SIMD_ApplyGain) {
    std::vector<float> buffer(1024);
    for (size_t i = 0; i < buffer.size(); ++i) {
        buffer[i] = 1.0f;
    }

    SIMD::applyGain(buffer.data(), buffer.size(), 0.5f);

    for (size_t i = 0; i < buffer.size(); ++i) {
        ASSERT_NEAR(buffer[i], 0.5f, 0.0001f);
    }
}

TEST(SIMD_ComputeRMS) {
    std::vector<float> buffer(1024, 1.0f);
    float rms = SIMD::computeRMS(buffer.data(), buffer.size());
    ASSERT_NEAR(rms, 1.0f, 0.0001f);

    // Test with sine wave
    for (size_t i = 0; i < buffer.size(); ++i) {
        buffer[i] = std::sin(2.0f * 3.14159f * i / buffer.size());
    }
    rms = SIMD::computeRMS(buffer.data(), buffer.size());
    ASSERT_NEAR(rms, 0.707f, 0.01f);  // RMS of sine wave is 1/sqrt(2)
}

TEST(SIMD_Copy) {
    std::vector<float> src(1024);
    std::vector<float> dst(1024);

    for (size_t i = 0; i < src.size(); ++i) {
        src[i] = static_cast<float>(i);
    }

    SIMD::copy(dst.data(), src.data(), src.size());

    for (size_t i = 0; i < src.size(); ++i) {
        ASSERT_EQ(dst[i], src[i]);
    }
}

TEST(SIMD_Add) {
    std::vector<float> a(1024, 1.0f);
    std::vector<float> b(1024, 2.0f);
    std::vector<float> c(1024);

    SIMD::add(c.data(), a.data(), b.data(), a.size());

    for (size_t i = 0; i < c.size(); ++i) {
        ASSERT_NEAR(c[i], 3.0f, 0.0001f);
    }
}

TEST(SIMD_Multiply) {
    std::vector<float> a(1024, 2.0f);
    std::vector<float> b(1024, 3.0f);
    std::vector<float> c(1024);

    SIMD::multiply(c.data(), a.data(), b.data(), a.size());

    for (size_t i = 0; i < c.size(); ++i) {
        ASSERT_NEAR(c[i], 6.0f, 0.0001f);
    }
}

// ============================================================================
// AudioBuffer Tests
// ============================================================================

TEST(AudioBuffer_Construction) {
    AudioBuffer<float> buffer(2, 1024);
    ASSERT_EQ(buffer.getNumChannels(), 2u);
    ASSERT_EQ(buffer.getNumSamples(), 1024u);
}

TEST(AudioBuffer_Clear) {
    AudioBuffer<float> buffer(2, 1024);

    // Fill with data
    for (size_t ch = 0; ch < buffer.getNumChannels(); ++ch) {
        float* channel = buffer.getWritePointer(ch);
        for (size_t i = 0; i < buffer.getNumSamples(); ++i) {
            channel[i] = 1.0f;
        }
    }

    buffer.clear();

    for (size_t ch = 0; ch < buffer.getNumChannels(); ++ch) {
        const float* channel = buffer.getReadPointer(ch);
        for (size_t i = 0; i < buffer.getNumSamples(); ++i) {
            ASSERT_EQ(channel[i], 0.0f);
        }
    }
}

TEST(AudioBuffer_ApplyGain) {
    AudioBuffer<float> buffer(2, 1024);

    for (size_t ch = 0; ch < buffer.getNumChannels(); ++ch) {
        float* channel = buffer.getWritePointer(ch);
        for (size_t i = 0; i < buffer.getNumSamples(); ++i) {
            channel[i] = 1.0f;
        }
    }

    buffer.applyGain(0.5f);

    for (size_t ch = 0; ch < buffer.getNumChannels(); ++ch) {
        const float* channel = buffer.getReadPointer(ch);
        for (size_t i = 0; i < buffer.getNumSamples(); ++i) {
            ASSERT_NEAR(channel[i], 0.5f, 0.0001f);
        }
    }
}

TEST(RingBuffer_PushPop) {
    RingBuffer<float, 1024> ringBuffer;

    ASSERT_TRUE(ringBuffer.empty());
    ASSERT_FALSE(ringBuffer.full());

    // Push items
    for (int i = 0; i < 100; ++i) {
        ASSERT_TRUE(ringBuffer.push(static_cast<float>(i)));
    }

    ASSERT_EQ(ringBuffer.size(), 100u);

    // Pop items
    for (int i = 0; i < 100; ++i) {
        float value;
        ASSERT_TRUE(ringBuffer.pop(value));
        ASSERT_NEAR(value, static_cast<float>(i), 0.0001f);
    }

    ASSERT_TRUE(ringBuffer.empty());
}

// ============================================================================
// FFT Tests
// ============================================================================

TEST(FFT_PowerOfTwo) {
    ASSERT_TRUE(FFT::isPowerOfTwo(1));
    ASSERT_TRUE(FFT::isPowerOfTwo(2));
    ASSERT_TRUE(FFT::isPowerOfTwo(4));
    ASSERT_TRUE(FFT::isPowerOfTwo(1024));
    ASSERT_TRUE(FFT::isPowerOfTwo(4096));

    ASSERT_FALSE(FFT::isPowerOfTwo(0));
    ASSERT_FALSE(FFT::isPowerOfTwo(3));
    ASSERT_FALSE(FFT::isPowerOfTwo(1000));
}

TEST(FFT_NextPowerOfTwo) {
    ASSERT_EQ(FFT::nextPowerOfTwo(1), 1u);
    ASSERT_EQ(FFT::nextPowerOfTwo(2), 2u);
    ASSERT_EQ(FFT::nextPowerOfTwo(3), 4u);
    ASSERT_EQ(FFT::nextPowerOfTwo(5), 8u);
    ASSERT_EQ(FFT::nextPowerOfTwo(1000), 1024u);
}

TEST(FFT_Forward_Inverse) {
    const size_t fftSize = 1024;
    FFT fft(fftSize);

    // Create test signal (sine wave)
    std::vector<float> real(fftSize);
    std::vector<float> imag(fftSize, 0.0f);

    for (size_t i = 0; i < fftSize; ++i) {
        real[i] = std::sin(2.0f * 3.14159f * 10 * i / fftSize);
    }

    // Copy original
    std::vector<float> original = real;

    // Forward FFT
    fft.forward(real.data(), imag.data());

    // Inverse FFT
    fft.inverse(real.data(), imag.data());

    // Check reconstruction
    for (size_t i = 0; i < fftSize; ++i) {
        ASSERT_NEAR(real[i], original[i], 0.001f);
    }
}

TEST(FFT_Window_Hann) {
    const size_t size = 1024;
    std::vector<float> window(size);

    WindowFunction::hann(window.data(), size);

    // Hann window should be 0 at edges, 1 at center
    ASSERT_NEAR(window[0], 0.0f, 0.001f);
    ASSERT_NEAR(window[size - 1], 0.0f, 0.01f);
    ASSERT_NEAR(window[size / 2], 1.0f, 0.001f);
}

// ============================================================================
// Filter Tests
// ============================================================================

TEST(BiquadFilter_LowPass) {
    BiquadFilter filter;
    filter.setLowPass(48000.0f, 1000.0f, 0.707f);

    // Process impulse
    float impulse = 1.0f;
    float output = filter.processSample(impulse);

    // Should not be zero (filter is active)
    ASSERT_TRUE(std::abs(output) > 0.0f);

    // Process more samples
    for (int i = 0; i < 100; ++i) {
        filter.processSample(0.0f);
    }

    // Output should decay toward zero
    float finalOutput = filter.processSample(0.0f);
    ASSERT_TRUE(std::abs(finalOutput) < 0.01f);
}

TEST(BiquadFilter_HighPass) {
    BiquadFilter filter;
    filter.setHighPass(48000.0f, 1000.0f, 0.707f);

    // DC should be blocked
    for (int i = 0; i < 1000; ++i) {
        filter.processSample(1.0f);
    }
    float output = filter.processSample(1.0f);
    ASSERT_NEAR(output, 0.0f, 0.01f);
}

TEST(StateVariableFilter_Modes) {
    StateVariableFilter svf;
    svf.setParameters(48000.0f, 1000.0f, 0.5f);

    // Test that all modes produce different outputs
    float input = 1.0f;

    svf.processSample(input);
    float lowPass = svf.getLowPass();
    float highPass = svf.getHighPass();
    float bandPass = svf.getBandPass();

    // They should be different
    ASSERT_TRUE(std::abs(lowPass - highPass) > 0.001f);
}

TEST(DCBlocker_BlocksDC) {
    DCBlocker blocker;
    blocker.setCoefficient(0.995f);

    // Feed constant DC
    for (int i = 0; i < 10000; ++i) {
        blocker.processSample(1.0f);
    }

    float output = blocker.processSample(1.0f);
    ASSERT_NEAR(output, 0.0f, 0.01f);
}

// ============================================================================
// MIDI 2.0 Tests
// ============================================================================

TEST(MIDI2_UMP_Creation) {
    using namespace MIDI2;

    auto noteOn = UniversalMIDIPacket::midi1NoteOn(0, 0, 60, 100);
    ASSERT_EQ(noteOn.messageType(), MessageType::MIDI1ChannelVoice);
    ASSERT_EQ(noteOn.group(), 0u);
    ASSERT_EQ(noteOn.sizeInWords(), 1u);
}

TEST(MIDI2_MIDI2_NoteOn) {
    using namespace MIDI2;

    auto noteOn = UniversalMIDIPacket::midi2NoteOn(0, 0, 60, 0x8000, 0, 0);
    ASSERT_EQ(noteOn.messageType(), MessageType::MIDI2ChannelVoice);
    ASSERT_EQ(noteOn.sizeInWords(), 2u);
}

TEST(MIDI2_Upgrade_MIDI1_To_MIDI2) {
    using namespace MIDI2;

    // Create MIDI 1.0 note on
    auto midi1 = UniversalMIDIPacket::midi1NoteOn(0, 0, 60, 100);

    // Upgrade to MIDI 2.0
    auto midi2 = MIDI2Processor::upgradeMIDI1ToMIDI2(midi1);

    ASSERT_EQ(midi2.messageType(), MessageType::MIDI2ChannelVoice);
}

TEST(MIDI2_MPE_Configuration) {
    using namespace MIDI2;

    MPEConfiguration mpe;
    mpe.configureStandardMPE();

    ASSERT_TRUE(mpe.lowerZone.enabled);
    ASSERT_TRUE(mpe.upperZone.enabled);
    ASSERT_EQ(mpe.lowerZone.memberChannels, 7u);
    ASSERT_EQ(mpe.upperZone.memberChannels, 7u);
}

// ============================================================================
// Oscillator Tests
// ============================================================================

TEST(Oscillator_Sine) {
    Oscillator osc;
    osc.setSampleRate(48000.0f);
    osc.setFrequency(440.0f);
    osc.setWaveform(Oscillator::Waveform::Sine);

    // Generate one cycle
    std::vector<float> samples(109);  // ~1 cycle at 440Hz, 48kHz
    for (size_t i = 0; i < samples.size(); ++i) {
        samples[i] = osc.process();
    }

    // Check that values are in [-1, 1]
    for (float sample : samples) {
        ASSERT_TRUE(sample >= -1.0f && sample <= 1.0f);
    }

    // Check that there's variation (not all zeros)
    float sum = 0.0f;
    for (float sample : samples) {
        sum += std::abs(sample);
    }
    ASSERT_TRUE(sum > 0.1f);
}

// ============================================================================
// Envelope Tests
// ============================================================================

TEST(EnvelopeFollower_Tracking) {
    EnvelopeFollower env;
    env.setAttackTime(0.001f, 48000.0f);
    env.setReleaseTime(0.1f, 48000.0f);

    // Feed loud signal
    float envelope = 0.0f;
    for (int i = 0; i < 480; ++i) {  // 10ms
        envelope = env.process(1.0f);
    }

    // Envelope should have risen
    ASSERT_TRUE(envelope > 0.9f);

    // Feed silence
    for (int i = 0; i < 4800; ++i) {  // 100ms
        envelope = env.process(0.0f);
    }

    // Envelope should have decayed
    ASSERT_TRUE(envelope < 0.1f);
}

// ============================================================================
// DelayLine Tests
// ============================================================================

TEST(DelayLine_Delay) {
    DelayLine delay;
    delay.setMaxDelay(48000);  // 1 second max
    delay.setDelay(480);       // 10ms at 48kHz

    // Write impulse
    delay.write(1.0f);

    // Read back immediately (should be old value = 0)
    float output = delay.read();
    ASSERT_NEAR(output, 0.0f, 0.0001f);

    // Advance 480 samples
    for (int i = 0; i < 479; ++i) {
        delay.write(0.0f);
    }

    output = delay.read();
    ASSERT_NEAR(output, 1.0f, 0.0001f);
}

// ============================================================================
// Parameter Smoother Tests
// ============================================================================

TEST(ParameterSmoother_Smoothing) {
    ParameterSmoother smoother;
    smoother.reset(48000.0f, 0.01f);  // 10ms smoothing
    smoother.setTargetValue(0.0f);

    // Jump to 1.0
    smoother.setTargetValue(1.0f);

    // Should not be at target immediately
    float value = smoother.getNextValue();
    ASSERT_TRUE(value < 1.0f);
    ASSERT_TRUE(value > 0.0f);

    // After many samples, should reach target
    for (int i = 0; i < 1000; ++i) {
        value = smoother.getNextValue();
    }
    ASSERT_NEAR(value, 1.0f, 0.01f);
}

// ============================================================================
// Performance Benchmarks
// ============================================================================

TEST(Performance_FFT_4096) {
    const size_t fftSize = 4096;
    FFT fft(fftSize);

    std::vector<float> real(fftSize);
    std::vector<float> imag(fftSize, 0.0f);

    for (size_t i = 0; i < fftSize; ++i) {
        real[i] = std::sin(2.0f * 3.14159f * 100 * i / fftSize);
    }

    auto start = std::chrono::high_resolution_clock::now();

    for (int i = 0; i < 1000; ++i) {
        fft.forward(real.data(), imag.data());
    }

    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start);

    std::cout << "(1000 FFT-4096: " << duration.count() / 1000.0f << "ms avg) ";

    // Should be under 2ms per FFT on modern hardware
    ASSERT_TRUE(duration.count() < 2000000);  // 2 seconds total for 1000 FFTs
}

TEST(Performance_Filter_Chain) {
    BiquadFilter lowPass, highPass, bandPass;
    lowPass.setLowPass(48000.0f, 5000.0f, 0.707f);
    highPass.setHighPass(48000.0f, 100.0f, 0.707f);
    bandPass.setBandPass(48000.0f, 1000.0f, 1.0f);

    const size_t numSamples = 48000;  // 1 second
    std::vector<float> buffer(numSamples);

    for (size_t i = 0; i < numSamples; ++i) {
        buffer[i] = std::sin(2.0f * 3.14159f * 440 * i / 48000.0f);
    }

    auto start = std::chrono::high_resolution_clock::now();

    for (int iter = 0; iter < 100; ++iter) {
        for (size_t i = 0; i < numSamples; ++i) {
            float sample = buffer[i];
            sample = lowPass.processSample(sample);
            sample = highPass.processSample(sample);
            sample = bandPass.processSample(sample);
            buffer[i] = sample;
        }
    }

    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start);

    std::cout << "(100x 48000 samples filter chain: " << duration.count() / 1000.0f << "ms) ";

    // Should process 100 seconds of audio in under 1 second
    ASSERT_TRUE(duration.count() < 1000000);
}

// ============================================================================
// Main
// ============================================================================

int main() {
    std::cout << std::endl;
    std::cout << "╔══════════════════════════════════════════════════════════════╗" << std::endl;
    std::cout << "║              EchoelDSP Unit Test Suite                       ║" << std::endl;
    std::cout << "╠══════════════════════════════════════════════════════════════╣" << std::endl;
    std::cout << "║  JUCE-FREE | iPlug2-FREE | Pure C++17 | SIMD-Optimized      ║" << std::endl;
    std::cout << "╚══════════════════════════════════════════════════════════════╝" << std::endl;
    std::cout << std::endl;

    // Tests are run automatically by static constructors

    std::cout << std::endl;
    std::cout << "════════════════════════════════════════════════════════════════" << std::endl;
    std::cout << "                        TEST RESULTS                            " << std::endl;
    std::cout << "════════════════════════════════════════════════════════════════" << std::endl;
    std::cout << std::endl;
    std::cout << "  Total:  " << testsRun << std::endl;
    std::cout << "  Passed: " << testsPassed << std::endl;
    std::cout << "  Failed: " << testsFailed << std::endl;
    std::cout << std::endl;

    if (testsFailed == 0) {
        std::cout << "╔══════════════════════════════════════════════════════════════╗" << std::endl;
        std::cout << "║              ALL TESTS PASSED                                ║" << std::endl;
        std::cout << "╚══════════════════════════════════════════════════════════════╝" << std::endl;
        return 0;
    } else {
        std::cout << "╔══════════════════════════════════════════════════════════════╗" << std::endl;
        std::cout << "║              SOME TESTS FAILED                               ║" << std::endl;
        std::cout << "╚══════════════════════════════════════════════════════════════╝" << std::endl;
        return 1;
    }
}
