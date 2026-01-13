// =============================================================================
// EchoelDSP Unit Tests
// =============================================================================
// Copyright (c) 2024-2026 Echoelmusic. All rights reserved.
// NO JUCE. NO iPlug2. Pure native testing.
// =============================================================================

#include "../EchoelCore/EchoelCore.h"
#include "../EchoelDSP/EchoelDSP.h"
#include "../EchoelCore/PluginAPI/PluginAPI.h"

#include <iostream>
#include <cmath>
#include <cassert>
#include <vector>
#include <string>

using namespace EchoelCore;
using namespace EchoelDSP;
using namespace EchoelCore::Plugin;

// =============================================================================
// Test Framework (Minimal)
// =============================================================================

static int testsRun = 0;
static int testsPassed = 0;
static int testsFailed = 0;

#define TEST(name) \
    void test_##name(); \
    struct TestRunner_##name { \
        TestRunner_##name() { \
            std::cout << "Running: " << #name << "... "; \
            testsRun++; \
            try { \
                test_##name(); \
                testsPassed++; \
                std::cout << "PASSED" << std::endl; \
            } catch (const std::exception& e) { \
                testsFailed++; \
                std::cout << "FAILED: " << e.what() << std::endl; \
            } catch (...) { \
                testsFailed++; \
                std::cout << "FAILED: Unknown exception" << std::endl; \
            } \
        } \
    } testRunner_##name; \
    void test_##name()

#define ASSERT_TRUE(expr) \
    if (!(expr)) throw std::runtime_error("Assertion failed: " #expr)

#define ASSERT_FALSE(expr) \
    if (expr) throw std::runtime_error("Assertion failed: NOT " #expr)

#define ASSERT_EQ(a, b) \
    if ((a) != (b)) throw std::runtime_error("Assertion failed: " #a " == " #b)

#define ASSERT_NEAR(a, b, tol) \
    if (std::abs((a) - (b)) > (tol)) throw std::runtime_error("Assertion failed: " #a " ~= " #b)

// =============================================================================
// DSP Math Tests
// =============================================================================

TEST(DSP_FastSin) {
    // Test fast sin approximation
    ASSERT_NEAR(DSP::fastSin(0.0f), 0.0f, 0.01f);
    ASSERT_NEAR(DSP::fastSin(PI / 2.0f), 1.0f, 0.01f);
    ASSERT_NEAR(DSP::fastSin(PI), 0.0f, 0.01f);
    ASSERT_NEAR(DSP::fastSin(3.0f * PI / 2.0f), -1.0f, 0.01f);
}

TEST(DSP_FastCos) {
    ASSERT_NEAR(DSP::fastCos(0.0f), 1.0f, 0.01f);
    ASSERT_NEAR(DSP::fastCos(PI / 2.0f), 0.0f, 0.01f);
    ASSERT_NEAR(DSP::fastCos(PI), -1.0f, 0.01f);
}

TEST(DSP_FastTanh) {
    ASSERT_NEAR(DSP::fastTanh(0.0f), 0.0f, 0.01f);
    ASSERT_NEAR(DSP::fastTanh(1.0f), std::tanh(1.0f), 0.05f);
    ASSERT_NEAR(DSP::fastTanh(-1.0f), std::tanh(-1.0f), 0.05f);
    ASSERT_NEAR(DSP::fastTanh(10.0f), 1.0f, 0.01f);
    ASSERT_NEAR(DSP::fastTanh(-10.0f), -1.0f, 0.01f);
}

TEST(DSP_DbConversion) {
    ASSERT_NEAR(DSP::dbToLinear(0.0f), 1.0f, 0.001f);
    ASSERT_NEAR(DSP::dbToLinear(-6.0f), 0.501f, 0.01f);
    ASSERT_NEAR(DSP::dbToLinear(-20.0f), 0.1f, 0.01f);

    ASSERT_NEAR(DSP::linearToDb(1.0f), 0.0f, 0.001f);
    ASSERT_NEAR(DSP::linearToDb(0.5f), -6.02f, 0.1f);
}

TEST(DSP_MidiFrequency) {
    ASSERT_NEAR(DSP::midiToFrequency(69), 440.0f, 0.01f);  // A4
    ASSERT_NEAR(DSP::midiToFrequency(60), 261.63f, 0.1f);  // C4
    ASSERT_NEAR(DSP::midiToFrequency(81), 880.0f, 0.1f);   // A5

    ASSERT_EQ(DSP::frequencyToMidi(440.0f), 69);
    ASSERT_EQ(DSP::frequencyToMidi(261.63f), 60);
}

TEST(DSP_Clamp) {
    ASSERT_EQ(DSP::clamp(0.5f, 0.0f, 1.0f), 0.5f);
    ASSERT_EQ(DSP::clamp(-1.0f, 0.0f, 1.0f), 0.0f);
    ASSERT_EQ(DSP::clamp(2.0f, 0.0f, 1.0f), 1.0f);
}

TEST(DSP_Lerp) {
    ASSERT_EQ(DSP::lerp(0.0f, 1.0f, 0.0f), 0.0f);
    ASSERT_EQ(DSP::lerp(0.0f, 1.0f, 1.0f), 1.0f);
    ASSERT_EQ(DSP::lerp(0.0f, 1.0f, 0.5f), 0.5f);
    ASSERT_EQ(DSP::lerp(10.0f, 20.0f, 0.25f), 12.5f);
}

// =============================================================================
// AudioBuffer Tests
// =============================================================================

TEST(AudioBuffer_Create) {
    AudioBuffer<float> buffer(2, 512);
    ASSERT_EQ(buffer.getNumChannels(), 2);
    ASSERT_EQ(buffer.getNumSamples(), 512);
}

TEST(AudioBuffer_Clear) {
    AudioBuffer<float> buffer(2, 256);
    buffer.getWritePointer(0)[0] = 1.0f;
    buffer.clear();
    ASSERT_EQ(buffer.getReadPointer(0)[0], 0.0f);
}

TEST(AudioBuffer_ApplyGain) {
    AudioBuffer<float> buffer(1, 4);
    float* data = buffer.getWritePointer(0);
    data[0] = 1.0f; data[1] = 0.5f; data[2] = -0.5f; data[3] = -1.0f;

    buffer.applyGain(0.5f);

    ASSERT_NEAR(buffer.getReadPointer(0)[0], 0.5f, 0.001f);
    ASSERT_NEAR(buffer.getReadPointer(0)[1], 0.25f, 0.001f);
}

// =============================================================================
// Oscillator Tests
// =============================================================================

TEST(Oscillator_Sine) {
    Oscillator osc(48000.0f);
    osc.setWaveform(Oscillator::Waveform::Sine);
    osc.setFrequency(1000.0f);

    // First sample should be near 0
    float sample = osc.process();
    ASSERT_NEAR(sample, 0.0f, 0.1f);

    // Process quarter period (12 samples at 48kHz for 1kHz)
    for (int i = 0; i < 11; ++i) osc.process();
    sample = osc.process();
    ASSERT_NEAR(sample, 1.0f, 0.1f);  // Peak
}

TEST(Oscillator_Saw) {
    Oscillator osc(48000.0f);
    osc.setWaveform(Oscillator::Waveform::Saw);
    osc.setFrequency(1000.0f);

    float sample = osc.process();
    ASSERT_TRUE(sample >= -1.0f && sample <= 1.0f);
}

TEST(Oscillator_Square) {
    Oscillator osc(48000.0f);
    osc.setWaveform(Oscillator::Waveform::Square);
    osc.setFrequency(1000.0f);

    float sample = osc.process();
    ASSERT_TRUE(sample == 1.0f || sample == -1.0f);
}

// =============================================================================
// Envelope Tests
// =============================================================================

TEST(Envelope_Attack) {
    EnvelopeGenerator env;
    env.setParameters(10.0f, 100.0f, 0.7f, 100.0f, 48000.0f);
    env.noteOn();

    ASSERT_TRUE(env.isActive());
    ASSERT_EQ(env.getState(), EnvelopeGenerator::State::Attack);

    // Process through attack
    float lastValue = 0.0f;
    for (int i = 0; i < 500; ++i) {
        float value = env.process();
        ASSERT_TRUE(value >= lastValue - 0.001f);  // Should be increasing
        lastValue = value;
    }
}

TEST(Envelope_Release) {
    EnvelopeGenerator env;
    env.setParameters(1.0f, 1.0f, 0.5f, 10.0f, 48000.0f);
    env.noteOn();

    // Quick attack/decay
    for (int i = 0; i < 200; ++i) env.process();

    env.noteOff();
    ASSERT_EQ(env.getState(), EnvelopeGenerator::State::Release);

    // Should eventually become inactive
    for (int i = 0; i < 1000; ++i) env.process();
    ASSERT_FALSE(env.isActive());
}

// =============================================================================
// Filter Tests
// =============================================================================

TEST(Filter_StateVariable_Lowpass) {
    StateVariableFilter filter(48000.0f);
    filter.setParameters(1000.0f, 0.5f);
    filter.setMode(StateVariableFilter::Mode::Lowpass);

    // Low frequency should pass through
    Oscillator osc(48000.0f);
    osc.setFrequency(100.0f);  // Well below cutoff

    float sum = 0.0f;
    for (int i = 0; i < 1000; ++i) {
        float in = osc.process();
        float out = filter.process(in);
        sum += std::abs(out);
    }

    ASSERT_TRUE(sum > 100.0f);  // Signal should pass
}

TEST(Filter_StateVariable_Highpass) {
    StateVariableFilter filter(48000.0f);
    filter.setParameters(5000.0f, 0.5f);
    filter.setMode(StateVariableFilter::Mode::Highpass);

    // Low frequency should be attenuated
    Oscillator osc(48000.0f);
    osc.setFrequency(100.0f);  // Well below cutoff

    float sum = 0.0f;
    for (int i = 0; i < 1000; ++i) {
        float in = osc.process();
        float out = filter.process(in);
        sum += std::abs(out);
    }

    ASSERT_TRUE(sum < 50.0f);  // Signal should be attenuated
}

// =============================================================================
// BiquadFilter Tests
// =============================================================================

TEST(BiquadFilter_Peak) {
    BiquadFilter filter;
    filter.setType(BiquadFilter::Type::Peak, 48000.0f, 1000.0f, 1.0f, 6.0f);

    // Process some samples
    for (int i = 0; i < 100; ++i) {
        float out = filter.process(std::sin(TWO_PI * 1000.0f * i / 48000.0f));
        ASSERT_FALSE(std::isnan(out));
        ASSERT_FALSE(std::isinf(out));
    }
}

// =============================================================================
// Delay Tests
// =============================================================================

TEST(DelayLine_Basic) {
    DelayLine delay(1000);
    delay.setDelay(100.0f);

    // Input impulse
    float out = delay.process(1.0f);
    ASSERT_NEAR(out, 0.0f, 0.001f);  // Delayed output should be 0 initially

    // Process 100 samples
    for (int i = 0; i < 99; ++i) {
        delay.process(0.0f);
    }

    out = delay.process(0.0f);
    ASSERT_NEAR(out, 1.0f, 0.01f);  // Impulse should appear after delay
}

// =============================================================================
// Reverb Tests
// =============================================================================

TEST(Reverb_Schroeder) {
    SchroederReverb reverb(48000.0f);
    reverb.setRoomSize(0.5f);
    reverb.setDamping(0.5f);
    reverb.setWetDry(0.3f);

    // Process impulse
    float out = reverb.process(1.0f);
    ASSERT_FALSE(std::isnan(out));

    // Process tail
    for (int i = 0; i < 48000; ++i) {
        out = reverb.process(0.0f);
        ASSERT_FALSE(std::isnan(out));
    }
}

// =============================================================================
// Compressor Tests
// =============================================================================

TEST(Compressor_Threshold) {
    Compressor comp(48000.0f);
    comp.setThreshold(-20.0f);
    comp.setRatio(4.0f);
    comp.setAttack(1.0f);
    comp.setRelease(100.0f);

    // Loud signal should be compressed
    float out = comp.process(1.0f);
    ASSERT_TRUE(out < 1.0f);
}

// =============================================================================
// Dynamics Processor Tests
// =============================================================================

TEST(DynamicsProcessor_Compressor) {
    DynamicsProcessor dyn;
    dyn.setMode(DynamicsProcessor::Mode::Compressor);
    dyn.setThreshold(-20.0f);
    dyn.setRatio(4.0f);

    AudioBuffer<float> buffer(2, 256);
    for (int i = 0; i < 256; ++i) {
        buffer.getWritePointer(0)[i] = 1.0f;
        buffer.getWritePointer(1)[i] = 1.0f;
    }

    dyn.prepare(48000.0f, 256);
    dyn.process(buffer);

    // Output should be reduced
    ASSERT_TRUE(buffer.getReadPointer(0)[255] < 1.0f);
}

TEST(DynamicsProcessor_Gate) {
    DynamicsProcessor dyn;
    dyn.setMode(DynamicsProcessor::Mode::Gate);
    dyn.setThreshold(-40.0f);

    AudioBuffer<float> buffer(1, 256);
    for (int i = 0; i < 256; ++i) {
        buffer.getWritePointer(0)[i] = 0.001f;  // Very quiet
    }

    dyn.prepare(48000.0f, 256);
    dyn.process(buffer);

    // Output should be gated (nearly silent)
    ASSERT_TRUE(std::abs(buffer.getReadPointer(0)[255]) < 0.01f);
}

// =============================================================================
// Saturation Tests
// =============================================================================

TEST(Saturation_Soft) {
    Saturation sat;
    sat.setType(Saturation::Type::Soft);
    sat.setDrive(12.0f);
    sat.setMix(1.0f);

    AudioBuffer<float> buffer(1, 256);
    for (int i = 0; i < 256; ++i) {
        buffer.getWritePointer(0)[i] = std::sin(TWO_PI * 440.0f * i / 48000.0f);
    }

    sat.process(buffer);

    // Output should be bounded
    for (int i = 0; i < 256; ++i) {
        ASSERT_TRUE(buffer.getReadPointer(0)[i] >= -1.0f);
        ASSERT_TRUE(buffer.getReadPointer(0)[i] <= 1.0f);
    }
}

TEST(Saturation_Bitcrush) {
    Saturation sat;
    sat.setType(Saturation::Type::Bitcrush);
    sat.setBitDepth(4);
    sat.setMix(1.0f);

    AudioBuffer<float> buffer(1, 256);
    for (int i = 0; i < 256; ++i) {
        buffer.getWritePointer(0)[i] = 0.5f;
    }

    sat.process(buffer);

    // Output should be quantized
    float out = buffer.getReadPointer(0)[0];
    ASSERT_NEAR(out, 0.5f, 0.1f);
}

// =============================================================================
// PolySynth Tests
// =============================================================================

TEST(PolySynth_NoteOn) {
    PolySynth synth(8);
    synth.prepare(48000.0f, 256);

    synth.noteOn(60, 0.8f);  // Middle C

    AudioBuffer<float> buffer(2, 256);
    synth.process(buffer);

    // Should produce sound
    float sum = 0.0f;
    for (int i = 0; i < 256; ++i) {
        sum += std::abs(buffer.getReadPointer(0)[i]);
    }
    ASSERT_TRUE(sum > 0.1f);
}

TEST(PolySynth_NoteOff) {
    PolySynth synth(8);
    synth.prepare(48000.0f, 256);

    synth.noteOn(60, 0.8f);
    synth.noteOff(60);

    // Process many blocks for release
    AudioBuffer<float> buffer(2, 256);
    for (int i = 0; i < 100; ++i) {
        synth.process(buffer);
    }

    // Should eventually be silent
    float sum = 0.0f;
    for (int i = 0; i < 256; ++i) {
        sum += std::abs(buffer.getReadPointer(0)[i]);
    }
    ASSERT_TRUE(sum < 0.01f);
}

// =============================================================================
// BioReactive Modulator Tests
// =============================================================================

TEST(BioReactiveModulator_Basic) {
    BioReactiveModulator mod;

    BioReactiveModulator::BioData data;
    data.heartRate = 70.0f;
    data.hrv = 50.0f;
    data.coherence = 0.8f;
    data.breathingRate = 6.0f;
    data.breathPhase = 0.5f;

    mod.updateBioData(data);
    auto modulation = mod.getModulation();

    // High coherence should result in positive filter modulation
    ASSERT_TRUE(modulation.filterCutoff > 0.0f);
}

// =============================================================================
// MIDI 2.0 Tests
// =============================================================================

TEST(MIDI2_Note_Velocity) {
    MIDI2::Note2 note;
    note.setVelocityFloat(0.5f);
    ASSERT_NEAR(note.getVelocityFloat(), 0.5f, 0.001f);

    note.setVelocityFloat(1.0f);
    ASSERT_NEAR(note.getVelocityFloat(), 1.0f, 0.001f);

    note.setVelocityFloat(0.0f);
    ASSERT_NEAR(note.getVelocityFloat(), 0.0f, 0.001f);
}

TEST(MIDI2_Controller_32bit) {
    MIDI2::Controller2 ctrl;
    ctrl.setValueFloat(0.75f);
    ASSERT_NEAR(ctrl.getValueFloat(), 0.75f, 0.001f);
}

TEST(MIDI2_PitchBend_32bit) {
    MIDI2::PitchBend2 pb;
    pb.value = 0x80000000;  // Center
    ASSERT_NEAR(pb.getSemitones(2.0f), 0.0f, 0.01f);

    pb.value = 0xFFFFFFFF;  // Max
    ASSERT_NEAR(pb.getSemitones(2.0f), 2.0f, 0.01f);
}

TEST(MIDI2_PerNotePitchBend) {
    MIDI2::PerNotePitchBend pnpb;
    pnpb.noteNumber = 60;
    pnpb.value = 0x80000000;

    ASSERT_NEAR(pnpb.getSemitones(48.0f), 0.0f, 0.01f);
}

TEST(MIDI2_MessageQueue) {
    MIDI2::MessageQueue queue;
    ASSERT_TRUE(queue.empty());

    MIDI2::Note2 note;
    note.channel = 0;
    note.noteNumber = 60;
    queue.push(note);

    ASSERT_FALSE(queue.empty());
    ASSERT_EQ(queue.size(), 1);

    auto msg = queue.pop();
    ASSERT_TRUE(msg.has_value());
    ASSERT_TRUE(queue.empty());
}

// =============================================================================
// Plugin Parameter Tests
// =============================================================================

TEST(Parameter_Value) {
    Parameter param("gain", "Gain", 0.5f, 0.0f, 1.0f);

    ASSERT_EQ(param.getId(), "gain");
    ASSERT_EQ(param.getName(), "Gain");
    ASSERT_NEAR(param.getValue(), 0.5f, 0.001f);

    param.setValue(0.75f);
    ASSERT_NEAR(param.getValue(), 0.75f, 0.001f);

    // Clamping
    param.setValue(2.0f);
    ASSERT_NEAR(param.getValue(), 1.0f, 0.001f);
}

TEST(Parameter_Normalized) {
    Parameter param("freq", "Frequency", 1000.0f, 20.0f, 20000.0f);

    param.setNormalizedValue(0.5f);
    ASSERT_NEAR(param.getValue(), 10010.0f, 1.0f);

    ASSERT_NEAR(param.getNormalizedValue(), 0.5f, 0.001f);
}

// =============================================================================
// Stereo Widener Tests
// =============================================================================

TEST(StereoWidener_Width) {
    StereoWidener widener;
    widener.setWidth(1.5f);

    AudioBuffer<float> buffer(2, 256);
    for (int i = 0; i < 256; ++i) {
        buffer.getWritePointer(0)[i] = 0.5f;  // Left
        buffer.getWritePointer(1)[i] = 0.3f;  // Right
    }

    widener.process(buffer);

    // Channels should be different (widened)
    ASSERT_TRUE(buffer.getReadPointer(0)[0] != buffer.getReadPointer(1)[0]);
}

// =============================================================================
// Version Tests
// =============================================================================

TEST(Version_EchoelCore) {
    ASSERT_EQ(EchoelCore::Version::major, 1);
    ASSERT_EQ(EchoelCore::Version::minor, 0);
    ASSERT_EQ(std::string(EchoelCore::Version::getFrameworkName()), "EchoelCore");
}

TEST(Version_EchoelDSP) {
    ASSERT_EQ(EchoelDSP::Version::major, 1);
    ASSERT_EQ(EchoelDSP::Version::minor, 0);
    ASSERT_EQ(std::string(EchoelDSP::Version::getFrameworkName()), "EchoelDSP");
}

TEST(Version_PluginAPI) {
    ASSERT_EQ(Plugin::Version::major, 1);
    ASSERT_EQ(Plugin::Version::minor, 0);
}

// =============================================================================
// Main
// =============================================================================

int main() {
    std::cout << std::endl;
    std::cout << "=== EchoelDSP Unit Tests ===" << std::endl;
    std::cout << "NO JUCE. NO iPlug2. Pure native testing." << std::endl;
    std::cout << std::endl;

    // Tests run automatically via static initialization

    std::cout << std::endl;
    std::cout << "=== Results ===" << std::endl;
    std::cout << "Tests run:    " << testsRun << std::endl;
    std::cout << "Tests passed: " << testsPassed << std::endl;
    std::cout << "Tests failed: " << testsFailed << std::endl;
    std::cout << std::endl;

    return testsFailed > 0 ? 1 : 0;
}
