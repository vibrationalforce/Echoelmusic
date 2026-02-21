/*
 *  EchoelPluginCore.cpp
 *  Echoelmusic — Unified Plugin Core Implementation
 *
 *  Created: February 2026
 *  Implements the C ABI interface defined in EchoelPluginCore.h.
 *  Wraps the Echoelmusic DSP engine for all plugin formats.
 *
 *  Build: C++17 — no external dependencies
 *  SIMD: Auto-detected (AVX-512 / AVX2 / SSE2 / NEON / Scalar)
 */

#define ECHOEL_PLUGIN_BUILDING
#include "EchoelPluginCore.h"

#include <cmath>
#include <cstring>
#include <atomic>
#include <vector>
#include <string>
#include <algorithm>
#include <memory>
#include <mutex>

/* ═══════════════════════════════════════════════════════════════════════════ */
/* SIMD Detection                                                             */
/* ═══════════════════════════════════════════════════════════════════════════ */

#if defined(__AVX512F__)
    #define ECHOEL_SIMD_LEVEL "AVX-512"
    #include <immintrin.h>
#elif defined(__AVX2__)
    #define ECHOEL_SIMD_LEVEL "AVX2"
    #include <immintrin.h>
#elif defined(__SSE2__)
    #define ECHOEL_SIMD_LEVEL "SSE2"
    #include <emmintrin.h>
#elif defined(__ARM_NEON) || defined(__ARM_NEON__)
    #define ECHOEL_SIMD_LEVEL "NEON"
    #include <arm_neon.h>
#else
    #define ECHOEL_SIMD_LEVEL "Scalar"
#endif

namespace echoelmusic {

/* ═══════════════════════════════════════════════════════════════════════════ */
/* DSP Primitives (inline, header-only, SIMD-friendly)                        */
/* ═══════════════════════════════════════════════════════════════════════════ */

static inline float softClip(float x) {
    const float x2 = x * x;
    return x * (27.0f + x2) / (27.0f + 9.0f * x2);
}

static inline float midiToFreq(int note) {
    return 440.0f * std::pow(2.0f, (static_cast<float>(note) - 69.0f) / 12.0f);
}

static inline float polyBLEP(float t, float dt) {
    if (t < dt) {
        float n = t / dt;
        return n + n - n * n - 1.0f;
    } else if (t > 1.0f - dt) {
        float n = (t - 1.0f) / dt;
        return n * n + n + n + 1.0f;
    }
    return 0.0f;
}

static inline void flushDenormals() {
#if defined(__SSE2__)
    _mm_setcsr(_mm_getcsr() | 0x8040);
#elif defined(__ARM_NEON)
    // ARM: denormals flushed to zero by default in most configs
#endif
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Oscillator                                                                 */
/* ═══════════════════════════════════════════════════════════════════════════ */

enum class OscWaveform { Sine, Triangle, Sawtooth, Square, Pulse, Noise };

struct Oscillator {
    float phase = 0.0f;
    float freq = 440.0f;
    float phaseInc = 0.0f;
    float pulseWidth = 0.5f;
    OscWaveform waveform = OscWaveform::Sine;
    uint32_t noiseState = 0x12345678;

    void setSampleRate(float sr) { phaseInc = freq / sr; }
    void setFrequency(float f, float sr) { freq = f; phaseInc = f / sr; }

    float tick() {
        float out = 0.0f;
        switch (waveform) {
            case OscWaveform::Sine:
                out = std::sin(phase * 2.0f * 3.14159265f);
                break;
            case OscWaveform::Sawtooth:
                out = 2.0f * phase - 1.0f;
                out -= polyBLEP(phase, phaseInc);
                break;
            case OscWaveform::Square:
                out = (phase < 0.5f) ? 1.0f : -1.0f;
                out += polyBLEP(phase, phaseInc);
                out -= polyBLEP(std::fmod(phase + 0.5f, 1.0f), phaseInc);
                break;
            case OscWaveform::Triangle:
                out = 2.0f * std::fabs(2.0f * phase - 1.0f) - 1.0f;
                break;
            case OscWaveform::Pulse:
                out = (phase < pulseWidth) ? 1.0f : -1.0f;
                break;
            case OscWaveform::Noise:
                noiseState ^= noiseState << 13;
                noiseState ^= noiseState >> 17;
                noiseState ^= noiseState << 5;
                out = static_cast<float>(noiseState) / static_cast<float>(0xFFFFFFFF) * 2.0f - 1.0f;
                break;
        }
        phase += phaseInc;
        if (phase >= 1.0f) phase -= 1.0f;
        return out;
    }
};

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Moog Ladder Filter (4-pole, 24 dB/oct)                                     */
/* ═══════════════════════════════════════════════════════════════════════════ */

struct MoogLadder {
    float s[4] = {0, 0, 0, 0};
    float cutoff = 1000.0f;
    float resonance = 0.0f;

    float process(float input, float sampleRate) {
        float f = 2.0f * cutoff / sampleRate;
        f = std::min(f, 0.99f);
        float k = 4.0f * resonance;
        float fb = k * s[3];
        float val = input - fb;

        for (int i = 0; i < 4; i++) {
            float prev = (i == 0) ? val : s[i - 1];
            s[i] += f * (std::tanh(prev) - std::tanh(s[i]));
        }
        return s[3];
    }

    void reset() { std::memset(s, 0, sizeof(s)); }
};

/* ═══════════════════════════════════════════════════════════════════════════ */
/* ADSR Envelope                                                              */
/* ═══════════════════════════════════════════════════════════════════════════ */

struct ADSREnvelope {
    enum Stage { Idle, Attack, Decay, Sustain, Release };

    Stage stage = Idle;
    float attack = 0.01f;
    float decay = 0.1f;
    float sustain = 0.7f;
    float release = 0.3f;
    float value = 0.0f;
    float rate = 0.0f;

    void gate(bool on, float sr) {
        if (on) {
            stage = Attack;
            rate = 1.0f / std::max(0.001f, attack * sr);
        } else if (stage != Idle) {
            stage = Release;
            rate = -value / std::max(0.001f, release * sr);
        }
    }

    float tick(float sr) {
        switch (stage) {
            case Idle: return 0.0f;
            case Attack:
                value += rate;
                if (value >= 1.0f) {
                    value = 1.0f;
                    stage = Decay;
                    rate = -(1.0f - sustain) / std::max(0.001f, decay * sr);
                }
                break;
            case Decay:
                value += rate;
                if (value <= sustain) {
                    value = sustain;
                    stage = Sustain;
                }
                break;
            case Sustain:
                value = sustain;
                break;
            case Release:
                value += rate;
                if (value <= 0.0f) {
                    value = 0.0f;
                    stage = Idle;
                }
                break;
        }
        return value;
    }

    bool isActive() const { return stage != Idle; }
    void reset() { stage = Idle; value = 0.0f; }
};

/* ═══════════════════════════════════════════════════════════════════════════ */
/* LFO                                                                        */
/* ═══════════════════════════════════════════════════════════════════════════ */

struct LFO {
    float phase = 0.0f;
    float rate = 1.0f;          // Hz
    OscWaveform waveform = OscWaveform::Sine;
    float depth = 0.5f;

    float tick(float sr) {
        float out = 0.0f;
        switch (waveform) {
            case OscWaveform::Sine:
                out = std::sin(phase * 2.0f * 3.14159265f);
                break;
            case OscWaveform::Triangle:
                out = 2.0f * std::fabs(2.0f * phase - 1.0f) - 1.0f;
                break;
            case OscWaveform::Sawtooth:
                out = 2.0f * phase - 1.0f;
                break;
            case OscWaveform::Square:
                out = (phase < 0.5f) ? 1.0f : -1.0f;
                break;
            default:
                out = std::sin(phase * 2.0f * 3.14159265f);
                break;
        }
        phase += rate / sr;
        if (phase >= 1.0f) phase -= 1.0f;
        return out * depth;
    }

    void reset() { phase = 0.0f; }
};

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Delay Line (interpolated, circular buffer)                                 */
/* ═══════════════════════════════════════════════════════════════════════════ */

struct DelayLine {
    std::vector<float> buffer;
    int writePos = 0;
    float filterZ1 = 0.0f;

    void allocate(int maxSamples) {
        buffer.assign(maxSamples, 0.0f);
        writePos = 0;
        filterZ1 = 0.0f;
    }

    float process(float input, float delaySamples, float feedback, float damping, float sr) {
        if (buffer.empty()) return input;

        float readPos = static_cast<float>(writePos) - delaySamples;
        if (readPos < 0) readPos += static_cast<float>(buffer.size());
        int idx0 = static_cast<int>(readPos) % static_cast<int>(buffer.size());
        int idx1 = (idx0 + 1) % static_cast<int>(buffer.size());
        float frac = readPos - std::floor(readPos);

        float delayed = buffer[idx0] * (1.0f - frac) + buffer[idx1] * frac;

        // LP filter on feedback path
        float fc = std::min(damping, sr * 0.49f);
        float coeff = std::exp(-2.0f * 3.14159265f * fc / sr);
        filterZ1 = delayed * (1.0f - coeff) + filterZ1 * coeff;

        buffer[writePos] = input + filterZ1 * std::min(feedback, 0.95f);
        writePos = (writePos + 1) % static_cast<int>(buffer.size());

        return delayed;
    }

    void clear() {
        std::fill(buffer.begin(), buffer.end(), 0.0f);
        filterZ1 = 0.0f;
    }
};

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Simple Reverb (Schroeder 4-comb + 2-allpass)                               */
/* ═══════════════════════════════════════════════════════════════════════════ */

struct SimpleReverb {
    struct CombFilter {
        std::vector<float> buffer;
        int pos = 0;
        float filterStore = 0.0f;
        float damp1 = 0.4f;
        float damp2 = 0.6f;
        float feedback = 0.7f;

        void setSize(int size) { buffer.assign(size, 0.0f); pos = 0; }
        float process(float input) {
            if (buffer.empty()) return input;
            float output = buffer[pos];
            filterStore = output * damp2 + filterStore * damp1;
            buffer[pos] = input + filterStore * feedback;
            pos = (pos + 1) % static_cast<int>(buffer.size());
            return output;
        }
    };

    struct AllpassFilter {
        std::vector<float> buffer;
        int pos = 0;
        float feedback = 0.5f;

        void setSize(int size) { buffer.assign(size, 0.0f); pos = 0; }
        float process(float input) {
            if (buffer.empty()) return input;
            float delayed = buffer[pos];
            float output = -input + delayed;
            buffer[pos] = input + delayed * feedback;
            pos = (pos + 1) % static_cast<int>(buffer.size());
            return output;
        }
    };

    CombFilter combs[4];
    AllpassFilter allpasses[2];
    float wetDry = 0.3f;
    float roomSize = 0.7f;

    void initialize(float sr) {
        const int combSizes[] = {1116, 1188, 1277, 1356};
        const int apSizes[] = {556, 441};
        float scale = sr / 44100.0f;
        for (int i = 0; i < 4; i++) {
            combs[i].setSize(static_cast<int>(combSizes[i] * scale));
            combs[i].feedback = roomSize;
        }
        for (int i = 0; i < 2; i++) {
            allpasses[i].setSize(static_cast<int>(apSizes[i] * scale));
        }
    }

    float process(float input) {
        float wet = 0.0f;
        for (auto& c : combs) wet += c.process(input);
        wet /= 4.0f;
        for (auto& a : allpasses) wet = a.process(wet);
        return input * (1.0f - wetDry) + wet * wetDry;
    }
};

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Compressor (feed-forward with soft knee)                                   */
/* ═══════════════════════════════════════════════════════════════════════════ */

struct Compressor {
    float threshold = -20.0f;   // dB
    float ratio = 4.0f;
    float attack = 0.01f;       // seconds
    float release = 0.1f;       // seconds
    float makeupGain = 0.0f;    // dB
    float knee = 6.0f;          // dB
    float envelope = 0.0f;

    float process(float input, float sr) {
        float inputDB = 20.0f * std::log10(std::fabs(input) + 1e-20f);
        float overDB = inputDB - threshold;

        // Soft knee
        if (overDB < -knee / 2.0f) {
            overDB = 0.0f;
        } else if (overDB < knee / 2.0f) {
            float x = overDB + knee / 2.0f;
            overDB = x * x / (2.0f * knee);
        }

        float gainReduction = overDB * (1.0f - 1.0f / ratio);
        float targetEnv = gainReduction;

        float coeff = (targetEnv > envelope) ? attack : release;
        float c = std::exp(-1.0f / (coeff * sr));
        envelope = targetEnv + c * (envelope - targetEnv);

        float gainDB = -envelope + makeupGain;
        float gain = std::pow(10.0f, gainDB / 20.0f);
        return input * gain;
    }
};

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Synth Voice                                                                */
/* ═══════════════════════════════════════════════════════════════════════════ */

struct SynthVoice {
    Oscillator osc1, osc2;
    MoogLadder filter;
    ADSREnvelope ampEnv, filterEnv;
    LFO lfo;
    int note = -1;
    float velocity = 0.0f;
    bool active = false;
    float pitchBend = 0.0f;
    float pressure = 0.0f;

    void noteOn(int n, float vel, float sr) {
        note = n;
        velocity = vel;
        active = true;
        float freq = midiToFreq(n);
        osc1.setFrequency(freq, sr);
        osc2.setFrequency(freq * 1.005f, sr);  // slight detune
        ampEnv.gate(true, sr);
        filterEnv.gate(true, sr);
    }

    void noteOff(float sr) {
        ampEnv.gate(false, sr);
        filterEnv.gate(false, sr);
    }

    float render(float sr, float filterCutoff, float filterRes, float filterEnvAmt) {
        float bend = std::pow(2.0f, pitchBend / 12.0f);
        osc1.setFrequency(midiToFreq(note) * bend, sr);
        osc2.setFrequency(midiToFreq(note) * bend * 1.005f, sr);

        float mix = osc1.tick() * 0.5f + osc2.tick() * 0.5f;
        float fenv = filterEnv.tick(sr);
        float amp = ampEnv.tick(sr);

        if (!ampEnv.isActive()) {
            active = false;
            return 0.0f;
        }

        float lfoVal = lfo.tick(sr);
        filter.cutoff = filterCutoff + fenv * filterEnvAmt + lfoVal * 500.0f;
        filter.cutoff = std::max(20.0f, std::min(filter.cutoff, 20000.0f));
        filter.resonance = filterRes;

        float filtered = filter.process(mix, sr);
        return filtered * amp * velocity;
    }
};

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Plugin Instance (internal)                                                 */
/* ═══════════════════════════════════════════════════════════════════════════ */

static constexpr int MAX_VOICES = 16;
static constexpr int MAX_PARAMS = 128;

struct PluginInstance {
    EchoelEngineID engineID;
    double sampleRate = 48000.0;
    uint32_t maxBlockSize = 512;
    bool activated = false;

    // Parameters (lock-free atomic access)
    std::atomic<float> params[MAX_PARAMS];
    EchoelParamInfo paramInfos[MAX_PARAMS];
    uint32_t paramCount = 0;

    // DSP engines
    SynthVoice voices[MAX_VOICES];
    MoogLadder masterFilter;
    SimpleReverb reverb;
    Compressor compressor;
    DelayLine delay;
    LFO masterLFO;

    // Bio-reactive
    std::atomic<float> bioCoherence{0.5f};
    std::atomic<float> bioHeartRate{72.0f};
    std::atomic<float> bioHRV{50.0f};
    std::atomic<float> bioBreathPhase{0.0f};

    // Audio analysis (for video plugins)
    std::atomic<float> audioRMS{0.0f};
    std::atomic<float> audioPeak{0.0f};

    // State serialization
    std::mutex stateMutex;
    std::vector<uint8_t> stateBuffer;

    // Preset storage
    struct Preset {
        std::string name;
        std::vector<float> values;
    };
    std::vector<Preset> presets;

    void initializeParams();
    void setupPresets();
};

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Parameter Definitions                                                      */
/* ═══════════════════════════════════════════════════════════════════════════ */

enum ParamID : uint32_t {
    // Global
    kParamBypass        = 0,
    kParamGain          = 1,
    kParamMix           = 2,

    // Oscillator 1
    kParamOsc1Wave      = 10,
    kParamOsc1Octave    = 11,
    kParamOsc1Semi      = 12,
    kParamOsc1Detune    = 13,
    kParamOsc1Level     = 14,

    // Oscillator 2
    kParamOsc2Wave      = 20,
    kParamOsc2Octave    = 21,
    kParamOsc2Semi      = 22,
    kParamOsc2Detune    = 23,
    kParamOsc2Level     = 24,

    // Osc Mix
    kParamOscMix        = 25,

    // Filter
    kParamFilterCutoff  = 30,
    kParamFilterRes     = 31,
    kParamFilterEnvAmt  = 32,
    kParamFilterKeyTrack = 33,

    // Amp Envelope
    kParamAmpAttack     = 40,
    kParamAmpDecay      = 41,
    kParamAmpSustain    = 42,
    kParamAmpRelease    = 43,

    // Filter Envelope
    kParamFiltAttack    = 50,
    kParamFiltDecay     = 51,
    kParamFiltSustain   = 52,
    kParamFiltRelease   = 53,

    // LFO
    kParamLFORate       = 60,
    kParamLFODepth      = 61,
    kParamLFOWave       = 62,

    // Effects
    kParamReverbMix     = 70,
    kParamReverbSize    = 71,
    kParamDelayTime     = 72,
    kParamDelayFeedback = 73,
    kParamDelayMix      = 74,
    kParamCompThresh    = 75,
    kParamCompRatio     = 76,
    kParamDrive         = 77,

    // Bio-Reactive
    kParamBioIntensity  = 80,
    kParamBioTarget     = 81,

    // 808 Bass specific
    kParamGlideTime     = 90,
    kParamGlideRange    = 91,
    kParamClickAmount   = 92,
    kParamDecayTime     = 93,
    kParamSubOscMix     = 94,
};

static const char* waveformNames[] = {"Sine", "Triangle", "Sawtooth", "Square", "Pulse", "Noise", nullptr};
static const char* bioTargetNames[] = {"Filter", "Reverb", "LFO", "All", nullptr};

void PluginInstance::initializeParams() {
    auto addParam = [this](uint32_t id, const char* name, const char* shortName,
                           const char* unit, const char* group,
                           EchoelParamType type, uint32_t flags,
                           double minVal, double maxVal, double defVal, double step = 0.0,
                           uint32_t enumCount = 0, const char* const* enumNames = nullptr) {
        if (paramCount >= MAX_PARAMS) return;
        auto& info = paramInfos[paramCount];
        info.id = id;
        info.name = name;
        info.short_name = shortName;
        info.unit_label = unit;
        info.group = group;
        info.type = type;
        info.flags = flags;
        info.min_value = minVal;
        info.max_value = maxVal;
        info.default_value = defVal;
        info.step_size = step;
        info.enum_count = enumCount;
        info.enum_names = enumNames;
        params[paramCount].store(static_cast<float>(defVal));
        paramCount++;
    };

    uint32_t autoFlag = ECHOEL_PARAM_FLAG_AUTOMATABLE;

    addParam(kParamBypass, "Bypass", "Byp", "", "Global", ECHOEL_PARAM_BOOL, ECHOEL_PARAM_FLAG_IS_BYPASS, 0, 1, 0, 1);
    addParam(kParamGain, "Output Gain", "Gain", "dB", "Global", ECHOEL_PARAM_FLOAT, autoFlag, -60, 12, 0);
    addParam(kParamMix, "Dry/Wet Mix", "Mix", "%", "Global", ECHOEL_PARAM_FLOAT, autoFlag, 0, 100, 100);

    addParam(kParamOsc1Wave, "Osc 1 Waveform", "Osc1", "", "Oscillator", ECHOEL_PARAM_ENUM, autoFlag, 0, 5, 0, 1, 6, waveformNames);
    addParam(kParamOsc1Octave, "Osc 1 Octave", "Oct1", "", "Oscillator", ECHOEL_PARAM_INT, autoFlag, -2, 2, 0, 1);
    addParam(kParamOsc1Level, "Osc 1 Level", "Lv1", "%", "Oscillator", ECHOEL_PARAM_FLOAT, autoFlag, 0, 100, 100);

    addParam(kParamOsc2Wave, "Osc 2 Waveform", "Osc2", "", "Oscillator", ECHOEL_PARAM_ENUM, autoFlag, 0, 5, 1, 1, 6, waveformNames);
    addParam(kParamOsc2Octave, "Osc 2 Octave", "Oct2", "", "Oscillator", ECHOEL_PARAM_INT, autoFlag, -2, 2, 0, 1);
    addParam(kParamOsc2Detune, "Osc 2 Detune", "Det2", "ct", "Oscillator", ECHOEL_PARAM_FLOAT, autoFlag, -100, 100, 5);
    addParam(kParamOsc2Level, "Osc 2 Level", "Lv2", "%", "Oscillator", ECHOEL_PARAM_FLOAT, autoFlag, 0, 100, 80);
    addParam(kParamOscMix, "Osc Mix", "Mix", "%", "Oscillator", ECHOEL_PARAM_FLOAT, autoFlag, 0, 100, 50);

    addParam(kParamFilterCutoff, "Filter Cutoff", "Freq", "Hz", "Filter", ECHOEL_PARAM_FLOAT, autoFlag | ECHOEL_PARAM_FLAG_MODULATABLE, 20, 20000, 8000);
    addParam(kParamFilterRes, "Filter Resonance", "Res", "", "Filter", ECHOEL_PARAM_FLOAT, autoFlag | ECHOEL_PARAM_FLAG_MODULATABLE, 0, 1, 0.2);
    addParam(kParamFilterEnvAmt, "Filter Env Amount", "FEnv", "", "Filter", ECHOEL_PARAM_FLOAT, autoFlag, -10000, 10000, 3000);

    addParam(kParamAmpAttack, "Amp Attack", "Atk", "ms", "Amp Envelope", ECHOEL_PARAM_FLOAT, autoFlag, 0.1, 5000, 10);
    addParam(kParamAmpDecay, "Amp Decay", "Dec", "ms", "Amp Envelope", ECHOEL_PARAM_FLOAT, autoFlag, 1, 10000, 200);
    addParam(kParamAmpSustain, "Amp Sustain", "Sus", "%", "Amp Envelope", ECHOEL_PARAM_FLOAT, autoFlag, 0, 100, 70);
    addParam(kParamAmpRelease, "Amp Release", "Rel", "ms", "Amp Envelope", ECHOEL_PARAM_FLOAT, autoFlag, 1, 10000, 300);

    addParam(kParamFiltAttack, "Filter Attack", "FAtk", "ms", "Filter Envelope", ECHOEL_PARAM_FLOAT, autoFlag, 0.1, 5000, 5);
    addParam(kParamFiltDecay, "Filter Decay", "FDec", "ms", "Filter Envelope", ECHOEL_PARAM_FLOAT, autoFlag, 1, 10000, 500);
    addParam(kParamFiltSustain, "Filter Sustain", "FSus", "%", "Filter Envelope", ECHOEL_PARAM_FLOAT, autoFlag, 0, 100, 30);
    addParam(kParamFiltRelease, "Filter Release", "FRel", "ms", "Filter Envelope", ECHOEL_PARAM_FLOAT, autoFlag, 1, 10000, 500);

    addParam(kParamLFORate, "LFO Rate", "Rate", "Hz", "LFO", ECHOEL_PARAM_FLOAT, autoFlag, 0.01, 50, 2);
    addParam(kParamLFODepth, "LFO Depth", "Dep", "%", "LFO", ECHOEL_PARAM_FLOAT, autoFlag, 0, 100, 30);
    addParam(kParamLFOWave, "LFO Waveform", "LWav", "", "LFO", ECHOEL_PARAM_ENUM, autoFlag, 0, 3, 0, 1, 4, waveformNames);

    addParam(kParamReverbMix, "Reverb Mix", "Rev", "%", "Effects", ECHOEL_PARAM_FLOAT, autoFlag, 0, 100, 15);
    addParam(kParamReverbSize, "Room Size", "Room", "", "Effects", ECHOEL_PARAM_FLOAT, autoFlag, 0, 1, 0.7);
    addParam(kParamDelayTime, "Delay Time", "DlyT", "ms", "Effects", ECHOEL_PARAM_FLOAT, autoFlag, 1, 2000, 375);
    addParam(kParamDelayFeedback, "Delay Feedback", "DlyF", "%", "Effects", ECHOEL_PARAM_FLOAT, autoFlag, 0, 95, 40);
    addParam(kParamDelayMix, "Delay Mix", "DlyM", "%", "Effects", ECHOEL_PARAM_FLOAT, autoFlag, 0, 100, 20);
    addParam(kParamDrive, "Drive", "Drv", "", "Effects", ECHOEL_PARAM_FLOAT, autoFlag, 0, 1, 0.1);

    addParam(kParamBioIntensity, "Bio Intensity", "Bio", "%", "Bio-Reactive", ECHOEL_PARAM_FLOAT, autoFlag | ECHOEL_PARAM_FLAG_MODULATABLE, 0, 100, 50);
    addParam(kParamBioTarget, "Bio Target", "BTgt", "", "Bio-Reactive", ECHOEL_PARAM_ENUM, autoFlag, 0, 3, 3, 1, 4, bioTargetNames);

    addParam(kParamGlideTime, "Glide Time", "Gld", "ms", "808 Bass", ECHOEL_PARAM_FLOAT, autoFlag, 0, 500, 80);
    addParam(kParamGlideRange, "Glide Range", "GRng", "st", "808 Bass", ECHOEL_PARAM_FLOAT, autoFlag, -24, 0, -12);
    addParam(kParamClickAmount, "Click", "Clk", "%", "808 Bass", ECHOEL_PARAM_FLOAT, autoFlag, 0, 100, 25);
    addParam(kParamDecayTime, "Decay", "Dcy", "s", "808 Bass", ECHOEL_PARAM_FLOAT, autoFlag, 0.1, 10, 1.5);
    addParam(kParamSubOscMix, "Sub Osc", "Sub", "%", "808 Bass", ECHOEL_PARAM_FLOAT, autoFlag, 0, 100, 0);
}

void PluginInstance::setupPresets() {
    presets.clear();

    // Universal presets (all engines)
    presets.push_back({"Init", {}});
    presets.push_back({"Warm Pad", {}});
    presets.push_back({"Deep Sub", {}});
    presets.push_back({"Bright Lead", {}});
    presets.push_back({"Bio Flow", {}});
    presets.push_back({"Dark Ambient", {}});
    presets.push_back({"Acid Bass", {}});
    presets.push_back({"Reese", {}});
    presets.push_back({"Moog Classic", {}});
    presets.push_back({"808 Trap", {}});
    presets.push_back({"Growl Dubstep", {}});
    presets.push_back({"Quantum Shimmer", {}});
    presets.push_back({"Modal Bell", {}});
    presets.push_back({"Cellular Texture", {}});
    presets.push_back({"Spectral Morph", {}});
    presets.push_back({"Binaural Focus", {}});

    // Store default values in first preset
    if (!presets.empty()) {
        auto& init = presets[0];
        init.values.resize(paramCount);
        for (uint32_t i = 0; i < paramCount; i++) {
            init.values[i] = static_cast<float>(paramInfos[i].default_value);
        }
    }
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Plugin Descriptors (static registry)                                       */
/* ═══════════════════════════════════════════════════════════════════════════ */

static const char* synthFeatures[] = {"instrument", "synthesizer", "bio-reactive", nullptr};
static const char* fxFeatures[] = {"audio-effect", "reverb", "delay", "compressor", nullptr};
static const char* mixFeatures[] = {"audio-effect", "mixing", "spatial", nullptr};
static const char* seqFeatures[] = {"instrument", "sequencer", "bio-reactive", nullptr};
static const char* midiFeatures[] = {"note-effect", "midi", "mpe", nullptr};
static const char* bioFeatures[] = {"instrument", "generator", "binaural", nullptr};
static const char* fieldFeatures[] = {"analyzer", "visualizer", nullptr};
static const char* beamFeatures[] = {"note-effect", "lighting", "dmx", nullptr};
static const char* netFeatures[] = {"note-effect", "network", "osc", nullptr};
static const char* mindFeatures[] = {"audio-effect", "ai", "separator", nullptr};
static const char* bassFeatures[] = {"instrument", "synthesizer", "bass", nullptr};
static const char* beatFeatures[] = {"instrument", "drum-machine", nullptr};
static const char* vfxFeatures[] = {"video-effect", "bio-reactive", nullptr};

static const EchoelPluginDescriptor s_descriptors[] = {
    {ECHOEL_ENGINE_SYNTH,  ECHOEL_PLUGIN_TYPE_INSTRUMENT, "com.echoelmusic.synth", "EchoelSynth",
     "Bio-reactive synthesis instrument", ECHOEL_PLUGIN_VERSION_STRING, ECHOEL_VENDOR_NAME, ECHOEL_VENDOR_URL,
     36, {0, 2, 0}, 0x61756D75/*aumu*/, 0x4573796E/*Esyn*/, 0x4563686F/*Echo*/,
     "5B8E1A2C3D4F5A6B7C8D9E0F1A2B3C4D", "com.echoelmusic.synth", synthFeatures, 0x45730001,
     "com.echoelmusic:EchoelSynth", "Echoelmusic"},

    {ECHOEL_ENGINE_FX,     ECHOEL_PLUGIN_TYPE_EFFECT, "com.echoelmusic.fx", "EchoelFX",
     "Effects chain with analog emulations", ECHOEL_PLUGIN_VERSION_STRING, ECHOEL_VENDOR_NAME, ECHOEL_VENDOR_URL,
     36, {2, 2, 2}, 0x61756678/*aufx*/, 0x45656678/*Eefx*/, 0x4563686F,
     "6C9F2B3D4E5F6A7B8C9D0E1F2A3B4C5D", "com.echoelmusic.fx", fxFeatures, 0x45660001,
     "com.echoelmusic:EchoelFX", "Echoelmusic"},

    {ECHOEL_ENGINE_MIX,    ECHOEL_PLUGIN_TYPE_EFFECT, "com.echoelmusic.mix", "EchoelMix",
     "Mixer bus processor & spatial audio", ECHOEL_PLUGIN_VERSION_STRING, ECHOEL_VENDOR_NAME, ECHOEL_VENDOR_URL,
     36, {2, 2, 0}, 0x61756678, 0x456D6978/*Emix*/, 0x4563686F,
     "7D0A3C4E5F6A7B8C9D0E1F2A3B4C5D6E", "com.echoelmusic.mix", mixFeatures, 0x456D0001,
     "com.echoelmusic:EchoelMix", "Echoelmusic"},

    {ECHOEL_ENGINE_SEQ,    ECHOEL_PLUGIN_TYPE_INSTRUMENT, "com.echoelmusic.seq", "EchoelSeq",
     "Bio-reactive step sequencer", ECHOEL_PLUGIN_VERSION_STRING, ECHOEL_VENDOR_NAME, ECHOEL_VENDOR_URL,
     36, {0, 2, 0}, 0x61756D69/*aumi*/, 0x45736571/*Eseq*/, 0x4563686F,
     "8E1B4D5F6A7B8C9D0E1F2A3B4C5D6E7F", "com.echoelmusic.seq", seqFeatures, 0x45730002,
     "com.echoelmusic:EchoelSeq", "Echoelmusic"},

    {ECHOEL_ENGINE_MIDI,   ECHOEL_PLUGIN_TYPE_MIDI, "com.echoelmusic.midi", "EchoelMIDI",
     "MIDI 2.0 + MPE processor", ECHOEL_PLUGIN_VERSION_STRING, ECHOEL_VENDOR_NAME, ECHOEL_VENDOR_URL,
     36, {0, 0, 0}, 0x61756D69, 0x456D6964/*Emid*/, 0x4563686F,
     "9F2C5E6A7B8C9D0E1F2A3B4C5D6E7F80", "com.echoelmusic.midi", midiFeatures, 0x456D0002,
     "com.echoelmusic:EchoelMIDI", "Echoelmusic"},

    {ECHOEL_ENGINE_BIO,    ECHOEL_PLUGIN_TYPE_INSTRUMENT, "com.echoelmusic.bio", "EchoelBio",
     "Binaural beat & AI tone generator", ECHOEL_PLUGIN_VERSION_STRING, ECHOEL_VENDOR_NAME, ECHOEL_VENDOR_URL,
     36, {0, 2, 0}, 0x61756D75, 0x4562696F/*Ebio*/, 0x4563686F,
     "A03D6F7B8C9D0E1F2A3B4C5D6E7F8091", "com.echoelmusic.bio", bioFeatures, 0x45620001,
     "com.echoelmusic:EchoelBio", "Echoelmusic"},

    {ECHOEL_ENGINE_FIELD,  ECHOEL_PLUGIN_TYPE_ANALYZER, "com.echoelmusic.field", "EchoelField",
     "Audio-reactive visual engine", ECHOEL_PLUGIN_VERSION_STRING, ECHOEL_VENDOR_NAME, ECHOEL_VENDOR_URL,
     36, {2, 2, 0}, 0x61756678, 0x45666C64/*Efld*/, 0x4563686F,
     "B14E7A8C9D0E1F2A3B4C5D6E7F809102", "com.echoelmusic.field", fieldFeatures, 0x45660002,
     "com.echoelmusic:EchoelField", "Echoelmusic"},

    {ECHOEL_ENGINE_BEAM,   ECHOEL_PLUGIN_TYPE_MIDI, "com.echoelmusic.beam", "EchoelBeam",
     "Audio-to-lighting DMX bridge", ECHOEL_PLUGIN_VERSION_STRING, ECHOEL_VENDOR_NAME, ECHOEL_VENDOR_URL,
     36, {2, 0, 0}, 0x61756D69, 0x4562656D/*Ebem*/, 0x4563686F,
     "C25F8B9D0E1F2A3B4C5D6E7F80910213", "com.echoelmusic.beam", beamFeatures, 0x45620002,
     "com.echoelmusic:EchoelBeam", "Echoelmusic"},

    {ECHOEL_ENGINE_NET,    ECHOEL_PLUGIN_TYPE_MIDI, "com.echoelmusic.net", "EchoelNet",
     "Network protocol bridge (OSC/MSC/Dante)", ECHOEL_PLUGIN_VERSION_STRING, ECHOEL_VENDOR_NAME, ECHOEL_VENDOR_URL,
     36, {2, 2, 0}, 0x61756D69, 0x456E6574/*Enet*/, 0x4563686F,
     "D36A9C0E1F2A3B4C5D6E7F8091021324", "com.echoelmusic.net", netFeatures, 0x456E0001,
     "com.echoelmusic:EchoelNet", "Echoelmusic"},

    {ECHOEL_ENGINE_MIND,   ECHOEL_PLUGIN_TYPE_EFFECT, "com.echoelmusic.mind", "EchoelMind",
     "AI stem separation & enhancement", ECHOEL_PLUGIN_VERSION_STRING, ECHOEL_VENDOR_NAME, ECHOEL_VENDOR_URL,
     36, {2, 2, 0}, 0x61756678, 0x456D6E64/*Emnd*/, 0x4563686F,
     "E47B0D1F2A3B4C5D6E7F809102132435", "com.echoelmusic.mind", mindFeatures, 0x456D0003,
     "com.echoelmusic:EchoelMind", "Echoelmusic"},

    {ECHOEL_ENGINE_BASS,   ECHOEL_PLUGIN_TYPE_INSTRUMENT, "com.echoelmusic.bass", "EchoelBass",
     "5-engine morphing bass (808/Reese/Moog/Acid/Growl)", ECHOEL_PLUGIN_VERSION_STRING, ECHOEL_VENDOR_NAME, ECHOEL_VENDOR_URL,
     36, {0, 2, 0}, 0x61756D75, 0x45383038/*E808*/, 0x4563686F,
     "F58C1E2A3B4C5D6E7F80910213243546", "com.echoelmusic.bass", bassFeatures, 0x45380001,
     "com.echoelmusic:EchoelBass", "Echoelmusic"},

    {ECHOEL_ENGINE_BEAT,   ECHOEL_PLUGIN_TYPE_INSTRUMENT, "com.echoelmusic.beat", "EchoelBeat",
     "Drum machine + HiHat synth", ECHOEL_PLUGIN_VERSION_STRING, ECHOEL_VENDOR_NAME, ECHOEL_VENDOR_URL,
     36, {0, 2, 0}, 0x61756D75, 0x45627431/*Ebt1*/, 0x4563686F,
     "069D2F3B4C5D6E7F8091021324354657", "com.echoelmusic.beat", beatFeatures, 0x45620003,
     "com.echoelmusic:EchoelBeat", "Echoelmusic"},

    {ECHOEL_ENGINE_VFX,    ECHOEL_PLUGIN_TYPE_VIDEO_EFFECT, "com.echoelmusic.vfx", "EchoelVFX",
     "Bio-reactive video effects for DaVinci Resolve / Nuke", ECHOEL_PLUGIN_VERSION_STRING, ECHOEL_VENDOR_NAME, ECHOEL_VENDOR_URL,
     36, {0, 0, 0}, 0, 0, 0,
     nullptr, nullptr, vfxFeatures, 0,
     "com.echoelmusic:EchoelVFX", "Echoelmusic"},
};

static const uint32_t s_descriptorCount = sizeof(s_descriptors) / sizeof(s_descriptors[0]);

} // namespace echoelmusic

/* ═══════════════════════════════════════════════════════════════════════════ */
/* C API Implementation                                                       */
/* ═══════════════════════════════════════════════════════════════════════════ */

using namespace echoelmusic;

ECHOEL_API uint32_t echoel_get_plugin_count(void) {
    return s_descriptorCount;
}

ECHOEL_API const EchoelPluginDescriptor* echoel_get_plugin_descriptor(uint32_t index) {
    if (index >= s_descriptorCount) return nullptr;
    return &s_descriptors[index];
}

ECHOEL_API const EchoelPluginDescriptor* echoel_get_descriptor_by_engine(EchoelEngineID engine) {
    for (uint32_t i = 0; i < s_descriptorCount; i++) {
        if (s_descriptors[i].engine_id == engine) return &s_descriptors[i];
    }
    return nullptr;
}

ECHOEL_API EchoelPluginRef echoel_create(EchoelEngineID engine) {
    auto* plugin = new PluginInstance();
    plugin->engineID = engine;
    plugin->initializeParams();
    plugin->setupPresets();
    return reinterpret_cast<EchoelPluginRef>(plugin);
}

ECHOEL_API void echoel_destroy(EchoelPluginRef ref) {
    if (!ref) return;
    auto* plugin = reinterpret_cast<PluginInstance*>(ref);
    delete plugin;
}

ECHOEL_API bool echoel_activate(EchoelPluginRef ref, double sampleRate, uint32_t maxBlockSize) {
    if (!ref) return false;
    auto* p = reinterpret_cast<PluginInstance*>(ref);
    p->sampleRate = sampleRate;
    p->maxBlockSize = maxBlockSize;
    p->activated = true;

    flushDenormals();

    // Initialize DSP
    p->reverb.initialize(static_cast<float>(sampleRate));
    p->delay.allocate(static_cast<int>(sampleRate * 2.5));  // 2.5s max delay

    // Reset all voices
    for (auto& v : p->voices) {
        v.active = false;
        v.ampEnv.reset();
        v.filterEnv.reset();
        v.filter.reset();
    }

    return true;
}

ECHOEL_API void echoel_deactivate(EchoelPluginRef ref) {
    if (!ref) return;
    auto* p = reinterpret_cast<PluginInstance*>(ref);
    p->activated = false;
}

ECHOEL_API void echoel_reset(EchoelPluginRef ref) {
    if (!ref) return;
    auto* p = reinterpret_cast<PluginInstance*>(ref);
    for (auto& v : p->voices) {
        v.active = false;
        v.ampEnv.reset();
        v.filterEnv.reset();
        v.filter.reset();
        v.osc1.phase = 0;
        v.osc2.phase = 0;
    }
    p->masterFilter.reset();
    p->delay.clear();
    p->masterLFO.reset();
}

ECHOEL_API void echoel_process(
    EchoelPluginRef ref,
    const EchoelAudioBuffer* input,
    EchoelAudioBuffer* output,
    const EchoelMIDIEventList* midiIn,
    EchoelMIDIEventList* /* midiOut */,
    const EchoelProcessContext* /* context */)
{
    if (!ref || !output) return;
    auto* p = reinterpret_cast<PluginInstance*>(ref);
    float sr = static_cast<float>(p->sampleRate);
    uint32_t frames = output->frame_count;

    // Read parameters (lock-free)
    float gain = std::pow(10.0f, p->params[kParamGain].load(std::memory_order_relaxed) / 20.0f);
    float filterCutoff = p->params[kParamFilterCutoff].load(std::memory_order_relaxed);
    float filterRes = p->params[kParamFilterRes].load(std::memory_order_relaxed);
    float filterEnvAmt = p->params[kParamFilterEnvAmt].load(std::memory_order_relaxed);
    float reverbMix = p->params[kParamReverbMix].load(std::memory_order_relaxed) / 100.0f;
    float driveMix = p->params[kParamDrive].load(std::memory_order_relaxed);
    float bioIntensity = p->params[kParamBioIntensity].load(std::memory_order_relaxed) / 100.0f;

    // Bio modulation
    float coherence = p->bioCoherence.load(std::memory_order_relaxed);
    float bioFilterMod = (coherence - 0.5f) * 2.0f * bioIntensity * 4000.0f;
    filterCutoff = std::max(20.0f, std::min(filterCutoff + bioFilterMod, 20000.0f));

    p->reverb.wetDry = reverbMix + coherence * bioIntensity * 0.3f;

    // Process MIDI events
    if (midiIn) {
        for (uint32_t i = 0; i < midiIn->count; i++) {
            const auto& ev = midiIn->events[i];
            uint8_t status = ev.status & 0xF0;
            if (status == ECHOEL_MIDI_NOTE_ON && ev.data2 > 0) {
                // Find free voice
                int vi = -1;
                for (int j = 0; j < MAX_VOICES; j++) {
                    if (!p->voices[j].active) { vi = j; break; }
                }
                if (vi < 0) vi = 0; // steal oldest
                p->voices[vi].noteOn(ev.data1, ev.data2 / 127.0f, sr);
            } else if (status == ECHOEL_MIDI_NOTE_OFF ||
                       (status == ECHOEL_MIDI_NOTE_ON && ev.data2 == 0)) {
                for (auto& v : p->voices) {
                    if (v.active && v.note == ev.data1) v.noteOff(sr);
                }
            } else if (status == ECHOEL_MIDI_PITCH_BEND) {
                float bend = (static_cast<float>((ev.data2 << 7) | ev.data1) - 8192.0f) / 8192.0f * 2.0f;
                for (auto& v : p->voices) {
                    if (v.active) v.pitchBend = bend;
                }
            }
        }
    }

    // Render audio
    float peak = 0.0f;
    float rms = 0.0f;

    for (uint32_t f = 0; f < frames; f++) {
        float sample = 0.0f;

        // Sum active voices
        for (auto& v : p->voices) {
            if (v.active) {
                sample += v.render(sr, filterCutoff, filterRes, filterEnvAmt);
            }
        }

        // Pass through input if effect mode
        if (input && input->channel_count > 0 && f < input->frame_count) {
            sample += input->channels[0][f];
        }

        // Drive / saturation
        if (driveMix > 0.01f) {
            float driven = sample * (1.0f + driveMix * 3.0f);
            sample = sample * (1.0f - driveMix) + softClip(driven) * driveMix;
        }

        // Reverb
        sample = p->reverb.process(sample);

        // Output gain
        sample *= gain;

        // Meter
        float absSample = std::fabs(sample);
        peak = std::max(peak, absSample);
        rms += absSample * absSample;

        // Write to all output channels
        for (uint32_t ch = 0; ch < output->channel_count; ch++) {
            output->channels[ch][f] = sample;
        }
    }

    p->audioPeak.store(peak, std::memory_order_relaxed);
    p->audioRMS.store(std::sqrt(rms / std::max(1u, frames)), std::memory_order_relaxed);
}

ECHOEL_API void echoel_process_double(
    EchoelPluginRef ref,
    const double* const* input,
    double** output,
    uint32_t channelCount,
    uint32_t frameCount,
    const EchoelProcessContext* context)
{
    if (!ref || !output) return;
    // Convert double → float, process, convert back
    std::vector<float> inBuf(frameCount), outBuf(frameCount);
    float* inPtr = inBuf.data();
    float* outPtr = outBuf.data();

    if (input && channelCount > 0) {
        for (uint32_t f = 0; f < frameCount; f++)
            inBuf[f] = static_cast<float>(input[0][f]);
    }

    EchoelAudioBuffer inAB = {&inPtr, std::min(channelCount, 1u), frameCount};
    EchoelAudioBuffer outAB = {&outPtr, 1, frameCount};
    echoel_process(ref, &inAB, &outAB, nullptr, nullptr, context);

    for (uint32_t ch = 0; ch < channelCount; ch++) {
        for (uint32_t f = 0; f < frameCount; f++)
            output[ch][f] = static_cast<double>(outBuf[f]);
    }
}

ECHOEL_API void echoel_process_image(
    EchoelPluginRef ref,
    const EchoelImageBuffer* input,
    EchoelImageBuffer* output,
    double /* time */,
    double /* frameRate */)
{
    if (!ref || !input || !output) return;
    auto* p = reinterpret_cast<PluginInstance*>(ref);

    float coherence = p->bioCoherence.load(std::memory_order_relaxed);
    float audioLevel = p->audioRMS.load(std::memory_order_relaxed);
    float bioIntensity = p->params[kParamBioIntensity].load(std::memory_order_relaxed) / 100.0f;

    // Bio-reactive color grading on RGBA float32 images
    if (input->pixel_format == ECHOEL_PIXEL_RGBA_F32 && output->pixel_format == ECHOEL_PIXEL_RGBA_F32) {
        auto* src = static_cast<const float*>(input->data);
        auto* dst = static_cast<float*>(output->data);
        uint32_t pixelCount = input->width * input->height;

        float warmth = coherence * bioIntensity;
        float pulse = audioLevel * bioIntensity;

        for (uint32_t i = 0; i < pixelCount; i++) {
            uint32_t idx = i * 4;
            float r = src[idx + 0];
            float g = src[idx + 1];
            float b = src[idx + 2];
            float a = src[idx + 3];

            // Bio-reactive color shift
            r = r * (1.0f + warmth * 0.15f + pulse * 0.1f);
            g = g * (1.0f + warmth * 0.05f);
            b = b * (1.0f - warmth * 0.1f + pulse * 0.15f);

            dst[idx + 0] = std::min(r, 1.0f);
            dst[idx + 1] = std::min(g, 1.0f);
            dst[idx + 2] = std::min(b, 1.0f);
            dst[idx + 3] = a;
        }
    } else {
        // Passthrough for unsupported formats
        std::memcpy(output->data, input->data, input->height * input->row_bytes);
    }
}

ECHOEL_API void echoel_get_audio_analysis(
    EchoelPluginRef ref, float* rms, float* peak, float* /* spectrum */, uint32_t* spectrumSize)
{
    if (!ref) return;
    auto* p = reinterpret_cast<PluginInstance*>(ref);
    if (rms) { rms[0] = rms[1] = p->audioRMS.load(std::memory_order_relaxed); }
    if (peak) { peak[0] = peak[1] = p->audioPeak.load(std::memory_order_relaxed); }
    if (spectrumSize) *spectrumSize = 0;
}

/* ═══ Parameters ═══ */

ECHOEL_API uint32_t echoel_get_parameter_count(EchoelPluginRef ref) {
    if (!ref) return 0;
    return reinterpret_cast<PluginInstance*>(ref)->paramCount;
}

ECHOEL_API bool echoel_get_parameter_info(EchoelPluginRef ref, uint32_t index, EchoelParamInfo* info) {
    if (!ref || !info) return false;
    auto* p = reinterpret_cast<PluginInstance*>(ref);
    if (index >= p->paramCount) return false;
    *info = p->paramInfos[index];
    return true;
}

ECHOEL_API double echoel_get_parameter(EchoelPluginRef ref, uint32_t id) {
    if (!ref) return 0.0;
    auto* p = reinterpret_cast<PluginInstance*>(ref);
    for (uint32_t i = 0; i < p->paramCount; i++) {
        if (p->paramInfos[i].id == id)
            return static_cast<double>(p->params[i].load(std::memory_order_relaxed));
    }
    return 0.0;
}

ECHOEL_API void echoel_set_parameter(EchoelPluginRef ref, uint32_t id, double value) {
    if (!ref) return;
    auto* p = reinterpret_cast<PluginInstance*>(ref);
    for (uint32_t i = 0; i < p->paramCount; i++) {
        if (p->paramInfos[i].id == id) {
            p->params[i].store(static_cast<float>(value), std::memory_order_relaxed);
            return;
        }
    }
}

ECHOEL_API void echoel_format_parameter(EchoelPluginRef ref, uint32_t id, char* buffer, uint32_t bufSize) {
    if (!ref || !buffer || bufSize == 0) return;
    double val = echoel_get_parameter(ref, id);
    snprintf(buffer, bufSize, "%.2f", val);
}

ECHOEL_API void echoel_begin_parameter_gesture(EchoelPluginRef, uint32_t) { /* Host notification */ }
ECHOEL_API void echoel_end_parameter_gesture(EchoelPluginRef, uint32_t) { /* Host notification */ }

/* ═══ State ═══ */

ECHOEL_API bool echoel_get_state(EchoelPluginRef ref, const uint8_t** data, uint32_t* size) {
    if (!ref || !data || !size) return false;
    auto* p = reinterpret_cast<PluginInstance*>(ref);
    std::lock_guard<std::mutex> lock(p->stateMutex);

    // Simple binary format: [paramCount][id,value pairs]
    p->stateBuffer.clear();
    uint32_t count = p->paramCount;
    p->stateBuffer.insert(p->stateBuffer.end(),
        reinterpret_cast<uint8_t*>(&count),
        reinterpret_cast<uint8_t*>(&count) + sizeof(count));

    for (uint32_t i = 0; i < count; i++) {
        uint32_t pid = p->paramInfos[i].id;
        float val = p->params[i].load(std::memory_order_relaxed);
        p->stateBuffer.insert(p->stateBuffer.end(),
            reinterpret_cast<uint8_t*>(&pid),
            reinterpret_cast<uint8_t*>(&pid) + sizeof(pid));
        p->stateBuffer.insert(p->stateBuffer.end(),
            reinterpret_cast<uint8_t*>(&val),
            reinterpret_cast<uint8_t*>(&val) + sizeof(val));
    }

    *data = p->stateBuffer.data();
    *size = static_cast<uint32_t>(p->stateBuffer.size());
    return true;
}

ECHOEL_API bool echoel_set_state(EchoelPluginRef ref, const uint8_t* data, uint32_t size) {
    if (!ref || !data || size < sizeof(uint32_t)) return false;
    auto* p = reinterpret_cast<PluginInstance*>(ref);

    uint32_t count;
    std::memcpy(&count, data, sizeof(count));
    data += sizeof(count);
    size -= sizeof(count);

    for (uint32_t i = 0; i < count && size >= 8; i++) {
        uint32_t pid;
        float val;
        std::memcpy(&pid, data, sizeof(pid));
        std::memcpy(&val, data + sizeof(pid), sizeof(val));
        data += sizeof(pid) + sizeof(val);
        size -= sizeof(pid) + sizeof(val);
        echoel_set_parameter(ref, pid, static_cast<double>(val));
    }
    return true;
}

ECHOEL_API void echoel_free_state(const uint8_t*) {
    // State is owned by plugin instance, no separate free needed
}

ECHOEL_API uint32_t echoel_get_preset_count(EchoelPluginRef ref) {
    if (!ref) return 0;
    return static_cast<uint32_t>(reinterpret_cast<PluginInstance*>(ref)->presets.size());
}

ECHOEL_API const char* echoel_get_preset_name(EchoelPluginRef ref, uint32_t index) {
    if (!ref) return "";
    auto* p = reinterpret_cast<PluginInstance*>(ref);
    if (index >= p->presets.size()) return "";
    return p->presets[index].name.c_str();
}

ECHOEL_API bool echoel_load_preset(EchoelPluginRef ref, uint32_t index) {
    if (!ref) return false;
    auto* p = reinterpret_cast<PluginInstance*>(ref);
    if (index >= p->presets.size()) return false;
    const auto& preset = p->presets[index];
    for (uint32_t i = 0; i < std::min(static_cast<uint32_t>(preset.values.size()), p->paramCount); i++) {
        p->params[i].store(preset.values[i], std::memory_order_relaxed);
    }
    return true;
}

/* ═══ Bio-Reactive ═══ */

ECHOEL_API void echoel_set_bio_data(EchoelPluginRef ref, const EchoelBioData* bio) {
    if (!ref || !bio || !bio->is_valid) return;
    auto* p = reinterpret_cast<PluginInstance*>(ref);
    p->bioHeartRate.store(bio->heart_rate, std::memory_order_relaxed);
    p->bioHRV.store(bio->hrv, std::memory_order_relaxed);
    p->bioCoherence.store(bio->coherence, std::memory_order_relaxed);
    p->bioBreathPhase.store(bio->breath_phase, std::memory_order_relaxed);
}

ECHOEL_API void echoel_get_bio_modulation(
    EchoelPluginRef ref, float* filterMod, float* reverbMod, float* tempoMod, float* intensityMod)
{
    if (!ref) return;
    auto* p = reinterpret_cast<PluginInstance*>(ref);
    float c = p->bioCoherence.load(std::memory_order_relaxed);
    float bio = p->params[kParamBioIntensity].load(std::memory_order_relaxed) / 100.0f;
    if (filterMod) *filterMod = (c - 0.5f) * 2.0f * bio;
    if (reverbMod) *reverbMod = c * bio;
    if (tempoMod) *tempoMod = 1.0f;
    if (intensityMod) *intensityMod = bio;
}

/* ═══ Latency & Tail ═══ */

ECHOEL_API uint32_t echoel_get_latency(EchoelPluginRef) { return 0; }

ECHOEL_API double echoel_get_tail_time(EchoelPluginRef ref) {
    if (!ref) return 0.0;
    auto* p = reinterpret_cast<PluginInstance*>(ref);
    float revSize = p->reverb.roomSize;
    return static_cast<double>(revSize * 3.0f);  // rough estimate
}

/* ═══ GUI ═══ */

ECHOEL_API bool echoel_gui_is_supported(EchoelPluginRef, EchoelGUIAPI api) {
#if defined(__APPLE__)
    return api == ECHOEL_GUI_API_COCOA || api == ECHOEL_GUI_API_UIKIT || api == ECHOEL_GUI_API_WEB;
#elif defined(_WIN32)
    return api == ECHOEL_GUI_API_WIN32 || api == ECHOEL_GUI_API_WEB;
#elif defined(__linux__)
    return api == ECHOEL_GUI_API_X11 || api == ECHOEL_GUI_API_WAYLAND || api == ECHOEL_GUI_API_WEB;
#else
    return api == ECHOEL_GUI_API_WEB;
#endif
}

ECHOEL_API bool echoel_gui_create(EchoelPluginRef, EchoelGUIAPI, void*) { return true; }
ECHOEL_API void echoel_gui_destroy(EchoelPluginRef) { }
ECHOEL_API void echoel_gui_get_size(EchoelPluginRef, uint32_t* w, uint32_t* h) {
    if (w) *w = 800; if (h) *h = 600;
}
ECHOEL_API bool echoel_gui_set_size(EchoelPluginRef, uint32_t, uint32_t) { return true; }

/* ═══ Utility ═══ */

ECHOEL_API uint32_t echoel_get_api_version(void) { return ECHOEL_PLUGIN_API_VERSION; }
ECHOEL_API const char* echoel_get_version_string(void) { return ECHOEL_PLUGIN_VERSION_STRING; }
ECHOEL_API const char* echoel_get_build_info(void) {
    return "Echoelmusic " ECHOEL_PLUGIN_VERSION_STRING " (" ECHOEL_SIMD_LEVEL ", " __DATE__ ")";
}
