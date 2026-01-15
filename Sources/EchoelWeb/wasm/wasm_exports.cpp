/**
 * wasm_exports.cpp
 * Echoelmusic - WebAssembly DSP Core Exports
 *
 * Exports C++ DSP functions for use in the web browser via WebAssembly.
 * Compiled with Emscripten to echoelcore.wasm
 *
 * Build: emcc wasm_exports.cpp -o echoelcore.js -s WASM=1 -s EXPORTED_FUNCTIONS=[...] -O3
 *
 * Created: 2026-01-15
 */

#ifdef __EMSCRIPTEN__

#include <emscripten/emscripten.h>
#include <emscripten/bind.h>
#include <cmath>
#include <vector>
#include <array>
#include <algorithm>

// ============================================================================
// MARK: - Constants
// ============================================================================

constexpr float PI = 3.14159265358979323846f;
constexpr float TWO_PI = PI * 2.0f;
constexpr int MAX_VOICES = 16;

// ============================================================================
// MARK: - PolyBLEP Anti-Aliasing
// ============================================================================

inline float polyBLEP(float t, float dt) {
    if (t < dt) {
        t /= dt;
        return t + t - t * t - 1.0f;
    } else if (t > 1.0f - dt) {
        t = (t - 1.0f) / dt;
        return t * t + t + t + 1.0f;
    }
    return 0.0f;
}

// ============================================================================
// MARK: - Oscillator
// ============================================================================

class Oscillator {
public:
    enum Type { SINE = 0, TRIANGLE = 1, SAWTOOTH = 2, SQUARE = 3 };

    void setSampleRate(float sr) { sampleRate_ = sr; }
    void setFrequency(float freq) { frequency_ = freq; }
    void setType(int type) { type_ = static_cast<Type>(type); }
    void reset() { phase_ = 0.0f; }

    float process() {
        float dt = frequency_ / sampleRate_;
        float output = 0.0f;

        switch (type_) {
            case SINE:
                output = std::sin(phase_ * TWO_PI);
                break;
            case TRIANGLE:
                output = phase_ < 0.5f ? (4.0f * phase_ - 1.0f) : (3.0f - 4.0f * phase_);
                break;
            case SAWTOOTH:
                output = 2.0f * phase_ - 1.0f;
                output -= polyBLEP(phase_, dt);
                break;
            case SQUARE:
                output = phase_ < 0.5f ? 1.0f : -1.0f;
                output += polyBLEP(phase_, dt);
                output -= polyBLEP(std::fmod(phase_ + 0.5f, 1.0f), dt);
                break;
        }

        phase_ += dt;
        if (phase_ >= 1.0f) phase_ -= 1.0f;

        return output;
    }

private:
    float sampleRate_ = 48000.0f;
    float frequency_ = 440.0f;
    float phase_ = 0.0f;
    Type type_ = SAWTOOTH;
};

// ============================================================================
// MARK: - Filter (State Variable)
// ============================================================================

class Filter {
public:
    void setSampleRate(float sr) { sampleRate_ = sr; }
    void setCutoff(float cutoff) { cutoff_ = std::clamp(cutoff, 20.0f, 20000.0f); }
    void setResonance(float res) { resonance_ = std::clamp(res, 0.0f, 1.0f); }
    void reset() { lowpass_ = bandpass_ = highpass_ = 0.0f; }

    float process(float input) {
        float f = 2.0f * std::sin(PI * cutoff_ / sampleRate_);
        float q = 1.0f - resonance_;

        lowpass_ += f * bandpass_;
        highpass_ = input - lowpass_ - q * bandpass_;
        bandpass_ += f * highpass_;

        return lowpass_;
    }

private:
    float sampleRate_ = 48000.0f;
    float cutoff_ = 5000.0f;
    float resonance_ = 0.3f;
    float lowpass_ = 0.0f, bandpass_ = 0.0f, highpass_ = 0.0f;
};

// ============================================================================
// MARK: - Envelope (ADSR)
// ============================================================================

class Envelope {
public:
    enum Stage { IDLE = 0, ATTACK, DECAY, SUSTAIN, RELEASE };

    void setSampleRate(float sr) { sampleRate_ = sr; }
    void setAttack(float ms) { attackTime_ = ms; }
    void setDecay(float ms) { decayTime_ = ms; }
    void setSustain(float level) { sustainLevel_ = std::clamp(level, 0.0f, 1.0f); }
    void setRelease(float ms) { releaseTime_ = ms; }

    void noteOn() {
        stage_ = ATTACK;
        attackIncrement_ = 1.0f / (attackTime_ * sampleRate_ * 0.001f);
    }

    void noteOff() {
        if (stage_ != IDLE) {
            stage_ = RELEASE;
            releaseIncrement_ = level_ / (releaseTime_ * sampleRate_ * 0.001f);
        }
    }

    float process() {
        switch (stage_) {
            case IDLE:
                level_ = 0.0f;
                break;
            case ATTACK:
                level_ += attackIncrement_;
                if (level_ >= 1.0f) {
                    level_ = 1.0f;
                    stage_ = DECAY;
                    decayIncrement_ = (1.0f - sustainLevel_) / (decayTime_ * sampleRate_ * 0.001f);
                }
                break;
            case DECAY:
                level_ -= decayIncrement_;
                if (level_ <= sustainLevel_) {
                    level_ = sustainLevel_;
                    stage_ = SUSTAIN;
                }
                break;
            case SUSTAIN:
                level_ = sustainLevel_;
                break;
            case RELEASE:
                level_ -= releaseIncrement_;
                if (level_ <= 0.0f) {
                    level_ = 0.0f;
                    stage_ = IDLE;
                }
                break;
        }
        return level_;
    }

    bool isActive() const { return stage_ != IDLE; }
    int getStage() const { return static_cast<int>(stage_); }

private:
    float sampleRate_ = 48000.0f;
    float attackTime_ = 10.0f;
    float decayTime_ = 200.0f;
    float sustainLevel_ = 0.7f;
    float releaseTime_ = 300.0f;
    Stage stage_ = IDLE;
    float level_ = 0.0f;
    float attackIncrement_ = 0.0f;
    float decayIncrement_ = 0.0f;
    float releaseIncrement_ = 0.0f;
};

// ============================================================================
// MARK: - Voice
// ============================================================================

class Voice {
public:
    void setSampleRate(float sr) {
        osc_.setSampleRate(sr);
        filter_.setSampleRate(sr);
        env_.setSampleRate(sr);
    }

    void noteOn(int note, int velocity) {
        note_ = note;
        velocity_ = velocity / 127.0f;
        float freq = 440.0f * std::pow(2.0f, (note - 69) / 12.0f);
        osc_.setFrequency(freq);
        osc_.reset();
        filter_.reset();
        env_.noteOn();
    }

    void noteOff() { env_.noteOff(); }
    bool isActive() const { return env_.isActive(); }
    int getNote() const { return note_; }

    void setOscType(int type) { osc_.setType(type); }
    void setFilterCutoff(float cutoff) { filter_.setCutoff(cutoff); }
    void setFilterResonance(float res) { filter_.setResonance(res); }
    void setEnvelope(float a, float d, float s, float r) {
        env_.setAttack(a);
        env_.setDecay(d);
        env_.setSustain(s);
        env_.setRelease(r);
    }

    float process() {
        if (!isActive()) return 0.0f;

        float osc = osc_.process();
        float filtered = filter_.process(osc);
        float envLevel = env_.process();

        return filtered * envLevel * velocity_;
    }

private:
    Oscillator osc_;
    Filter filter_;
    Envelope env_;
    int note_ = 60;
    float velocity_ = 1.0f;
};

// ============================================================================
// MARK: - Synth Engine (Exported)
// ============================================================================

class SynthEngine {
public:
    SynthEngine() {
        for (auto& voice : voices_) {
            voice.setSampleRate(sampleRate_);
        }
    }

    void setSampleRate(float sr) {
        sampleRate_ = sr;
        for (auto& voice : voices_) {
            voice.setSampleRate(sr);
        }
    }

    void noteOn(int note, int velocity) {
        // Find free voice
        Voice* voice = nullptr;
        for (auto& v : voices_) {
            if (!v.isActive()) {
                voice = &v;
                break;
            }
        }
        // Steal if none free
        if (!voice) {
            voice = &voices_[0];
        }

        voice->setOscType(oscType_);
        voice->setFilterCutoff(filterCutoff_);
        voice->setFilterResonance(filterResonance_);
        voice->setEnvelope(attack_, decay_, sustain_, release_);
        voice->noteOn(note, velocity);
    }

    void noteOff(int note) {
        for (auto& v : voices_) {
            if (v.isActive() && v.getNote() == note) {
                v.noteOff();
            }
        }
    }

    void allNotesOff() {
        for (auto& v : voices_) {
            v.noteOff();
        }
    }

    float process() {
        float sample = 0.0f;
        for (auto& v : voices_) {
            sample += v.process();
        }

        // Soft clip
        if (sample > 1.0f) sample = 1.0f - std::exp(-sample + 1.0f);
        else if (sample < -1.0f) sample = -1.0f + std::exp(sample + 1.0f);

        return sample * masterVolume_;
    }

    void processBlock(uintptr_t outputPtr, int numFrames) {
        float* output = reinterpret_cast<float*>(outputPtr);
        for (int i = 0; i < numFrames; i++) {
            output[i] = process();
        }
    }

    // Parameter setters
    void setOscType(int type) { oscType_ = type; }
    void setFilterCutoff(float cutoff) { filterCutoff_ = cutoff; }
    void setFilterResonance(float res) { filterResonance_ = res; }
    void setAttack(float ms) { attack_ = ms; }
    void setDecay(float ms) { decay_ = ms; }
    void setSustain(float level) { sustain_ = level; }
    void setRelease(float ms) { release_ = ms; }
    void setMasterVolume(float vol) { masterVolume_ = std::clamp(vol, 0.0f, 1.0f); }

    // Bio modulation
    void setBioModulation(float heartRate, float coherence, float breathPhase) {
        // Apply subtle filter modulation based on coherence
        float modulatedCutoff = filterCutoff_ + coherence * 2000.0f;
        for (auto& v : voices_) {
            v.setFilterCutoff(modulatedCutoff);
        }
    }

private:
    std::array<Voice, MAX_VOICES> voices_;
    float sampleRate_ = 48000.0f;
    float masterVolume_ = 0.8f;
    int oscType_ = 2;  // Sawtooth
    float filterCutoff_ = 5000.0f;
    float filterResonance_ = 0.3f;
    float attack_ = 10.0f;
    float decay_ = 200.0f;
    float sustain_ = 0.7f;
    float release_ = 300.0f;
};

// ============================================================================
// MARK: - Emscripten Bindings
// ============================================================================

EMSCRIPTEN_BINDINGS(echoelcore) {
    emscripten::class_<SynthEngine>("SynthEngine")
        .constructor<>()
        .function("setSampleRate", &SynthEngine::setSampleRate)
        .function("noteOn", &SynthEngine::noteOn)
        .function("noteOff", &SynthEngine::noteOff)
        .function("allNotesOff", &SynthEngine::allNotesOff)
        .function("process", &SynthEngine::process)
        .function("processBlock", &SynthEngine::processBlock)
        .function("setOscType", &SynthEngine::setOscType)
        .function("setFilterCutoff", &SynthEngine::setFilterCutoff)
        .function("setFilterResonance", &SynthEngine::setFilterResonance)
        .function("setAttack", &SynthEngine::setAttack)
        .function("setDecay", &SynthEngine::setDecay)
        .function("setSustain", &SynthEngine::setSustain)
        .function("setRelease", &SynthEngine::setRelease)
        .function("setMasterVolume", &SynthEngine::setMasterVolume)
        .function("setBioModulation", &SynthEngine::setBioModulation);
}

#endif // __EMSCRIPTEN__
