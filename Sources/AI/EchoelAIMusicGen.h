#pragma once

/*
 * EchoelAIMusicGen.h
 * Ralph Wiggum Genius Loop Mode - AI Music Generation Engine
 *
 * Ultra-optimized AI-powered music and audio generation system
 * with biofeedback integration and real-time synthesis.
 */

#include <atomic>
#include <vector>
#include <array>
#include <memory>
#include <functional>
#include <string>
#include <cmath>
#include <algorithm>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <random>
#include <complex>

namespace Echoel {
namespace AI {

// ============================================================================
// Music Theory Constants
// ============================================================================

namespace MusicTheory {
    // Note frequencies (A4 = 440Hz standard)
    constexpr float A4_FREQUENCY = 440.0f;
    constexpr float SEMITONE_RATIO = 1.05946309436f; // 2^(1/12)

    // Scale intervals (semitones from root)
    constexpr std::array<int, 7> MAJOR_SCALE = {0, 2, 4, 5, 7, 9, 11};
    constexpr std::array<int, 7> MINOR_SCALE = {0, 2, 3, 5, 7, 8, 10};
    constexpr std::array<int, 7> DORIAN_SCALE = {0, 2, 3, 5, 7, 9, 10};
    constexpr std::array<int, 7> PHRYGIAN_SCALE = {0, 1, 3, 5, 7, 8, 10};
    constexpr std::array<int, 7> LYDIAN_SCALE = {0, 2, 4, 6, 7, 9, 11};
    constexpr std::array<int, 7> MIXOLYDIAN_SCALE = {0, 2, 4, 5, 7, 9, 10};
    constexpr std::array<int, 5> PENTATONIC_MAJOR = {0, 2, 4, 7, 9};
    constexpr std::array<int, 5> PENTATONIC_MINOR = {0, 3, 5, 7, 10};
    constexpr std::array<int, 8> HARMONIC_MINOR = {0, 2, 3, 5, 7, 8, 11, 12};

    // Chord types (intervals from root)
    constexpr std::array<int, 3> MAJOR_TRIAD = {0, 4, 7};
    constexpr std::array<int, 3> MINOR_TRIAD = {0, 3, 7};
    constexpr std::array<int, 4> MAJOR_7TH = {0, 4, 7, 11};
    constexpr std::array<int, 4> MINOR_7TH = {0, 3, 7, 10};
    constexpr std::array<int, 4> DOMINANT_7TH = {0, 4, 7, 10};
    constexpr std::array<int, 4> DIMINISHED_7TH = {0, 3, 6, 9};
    constexpr std::array<int, 4> HALF_DIMINISHED = {0, 3, 6, 10};
    constexpr std::array<int, 4> AUGMENTED_7TH = {0, 4, 8, 10};
    constexpr std::array<int, 5> MAJOR_9TH = {0, 4, 7, 11, 14};
    constexpr std::array<int, 5> MINOR_9TH = {0, 3, 7, 10, 14};

    inline float noteToFrequency(int midiNote) {
        return A4_FREQUENCY * std::pow(SEMITONE_RATIO, midiNote - 69);
    }

    inline int frequencyToNote(float frequency) {
        return static_cast<int>(std::round(69.0f + 12.0f * std::log2(frequency / A4_FREQUENCY)));
    }
}

// ============================================================================
// Enumerations
// ============================================================================

enum class MusicGenre {
    Ambient,
    Electronic,
    Orchestral,
    Jazz,
    Blues,
    Classical,
    World,
    Experimental,
    Meditation,
    Binaural,
    Isochronic,
    NatureSoundscape,
    DroneMusic,
    Generative,
    Algorithmic
};

enum class MoodType {
    Calm,
    Energetic,
    Melancholic,
    Uplifting,
    Mysterious,
    Intense,
    Dreamy,
    Focused,
    Relaxed,
    Euphoric,
    Contemplative,
    Transcendent
};

enum class SynthType {
    Subtractive,
    FM,
    Additive,
    Wavetable,
    Granular,
    Physical,
    Spectral,
    Neural,
    Hybrid
};

enum class TemporalPattern {
    Steady,
    Accelerating,
    Decelerating,
    Breathing,
    Pulsing,
    Evolving,
    Chaotic,
    Adaptive
};

enum class HarmonicComplexity {
    Simple,         // Basic triads
    Moderate,       // 7th chords
    Complex,        // Extended harmonies
    Chromatic,      // Chromatic movements
    Atonal,         // Non-functional harmony
    Microtonal      // Quarter tones, just intonation
};

// ============================================================================
// Bio-Reactive Music Parameters
// ============================================================================

struct BioMusicState {
    // Biofeedback inputs (0.0 - 1.0)
    float heartRate = 0.5f;          // Normalized BPM
    float heartRateVariability = 0.5f;
    float skinConductance = 0.5f;    // GSR
    float brainwaveAlpha = 0.5f;
    float brainwaveBeta = 0.5f;
    float brainwaveTheta = 0.5f;
    float brainwaveDelta = 0.5f;
    float breathingRate = 0.5f;
    float muscleActivity = 0.5f;     // EMG
    float temperature = 0.5f;

    // Derived emotional states
    float relaxationLevel = 0.5f;
    float focusLevel = 0.5f;
    float arousalLevel = 0.5f;
    float valenceLevel = 0.5f;       // Positive/negative

    // Target states
    float targetRelaxation = 0.7f;
    float targetFocus = 0.5f;
    float targetArousal = 0.3f;

    void updateDerivedStates() {
        // Calculate relaxation from HRV and alpha waves
        relaxationLevel = (heartRateVariability + brainwaveAlpha) * 0.5f;

        // Calculate focus from beta/theta ratio
        focusLevel = brainwaveBeta / (brainwaveTheta + 0.1f);
        focusLevel = std::clamp(focusLevel, 0.0f, 1.0f);

        // Calculate arousal from heart rate and skin conductance
        arousalLevel = (heartRate + skinConductance) * 0.5f;

        // Calculate valence (simplified)
        valenceLevel = (relaxationLevel + focusLevel) * 0.5f;
    }
};

// ============================================================================
// Neural Network Primitives
// ============================================================================

class NeuralLayer {
public:
    NeuralLayer(size_t inputSize, size_t outputSize)
        : inputSize_(inputSize), outputSize_(outputSize) {
        weights_.resize(inputSize * outputSize);
        biases_.resize(outputSize);
        initializeWeights();
    }

    void forward(const float* input, float* output) const {
        for (size_t o = 0; o < outputSize_; ++o) {
            float sum = biases_[o];
            for (size_t i = 0; i < inputSize_; ++i) {
                sum += input[i] * weights_[i * outputSize_ + o];
            }
            // ReLU activation
            output[o] = std::max(0.0f, sum);
        }
    }

    void forwardTanh(const float* input, float* output) const {
        for (size_t o = 0; o < outputSize_; ++o) {
            float sum = biases_[o];
            for (size_t i = 0; i < inputSize_; ++i) {
                sum += input[i] * weights_[i * outputSize_ + o];
            }
            output[o] = std::tanh(sum);
        }
    }

private:
    void initializeWeights() {
        std::mt19937 gen(42);
        float scale = std::sqrt(2.0f / inputSize_);
        std::normal_distribution<float> dist(0.0f, scale);

        for (auto& w : weights_) w = dist(gen);
        for (auto& b : biases_) b = 0.0f;
    }

    size_t inputSize_;
    size_t outputSize_;
    std::vector<float> weights_;
    std::vector<float> biases_;
};

// ============================================================================
// LSTM Cell for Sequence Generation
// ============================================================================

class LSTMCell {
public:
    LSTMCell(size_t inputSize, size_t hiddenSize)
        : inputSize_(inputSize), hiddenSize_(hiddenSize),
          forgetGate_(inputSize + hiddenSize, hiddenSize),
          inputGate_(inputSize + hiddenSize, hiddenSize),
          outputGate_(inputSize + hiddenSize, hiddenSize),
          cellGate_(inputSize + hiddenSize, hiddenSize) {

        hiddenState_.resize(hiddenSize, 0.0f);
        cellState_.resize(hiddenSize, 0.0f);
        combined_.resize(inputSize + hiddenSize);
        tempBuffer_.resize(hiddenSize);
    }

    void forward(const float* input, float* output) {
        // Combine input and hidden state
        std::copy(input, input + inputSize_, combined_.begin());
        std::copy(hiddenState_.begin(), hiddenState_.end(),
                  combined_.begin() + inputSize_);

        // Forget gate
        std::vector<float> fg(hiddenSize_);
        forgetGate_.forwardTanh(combined_.data(), fg.data());
        applySigmoid(fg);

        // Input gate
        std::vector<float> ig(hiddenSize_);
        inputGate_.forwardTanh(combined_.data(), ig.data());
        applySigmoid(ig);

        // Cell gate (candidate)
        std::vector<float> cg(hiddenSize_);
        cellGate_.forwardTanh(combined_.data(), cg.data());

        // Output gate
        std::vector<float> og(hiddenSize_);
        outputGate_.forwardTanh(combined_.data(), og.data());
        applySigmoid(og);

        // Update cell state
        for (size_t i = 0; i < hiddenSize_; ++i) {
            cellState_[i] = fg[i] * cellState_[i] + ig[i] * cg[i];
        }

        // Update hidden state and output
        for (size_t i = 0; i < hiddenSize_; ++i) {
            hiddenState_[i] = og[i] * std::tanh(cellState_[i]);
            output[i] = hiddenState_[i];
        }
    }

    void reset() {
        std::fill(hiddenState_.begin(), hiddenState_.end(), 0.0f);
        std::fill(cellState_.begin(), cellState_.end(), 0.0f);
    }

private:
    void applySigmoid(std::vector<float>& v) {
        for (auto& x : v) {
            x = 1.0f / (1.0f + std::exp(-x));
        }
    }

    size_t inputSize_;
    size_t hiddenSize_;
    NeuralLayer forgetGate_;
    NeuralLayer inputGate_;
    NeuralLayer outputGate_;
    NeuralLayer cellGate_;
    std::vector<float> hiddenState_;
    std::vector<float> cellState_;
    std::vector<float> combined_;
    std::vector<float> tempBuffer_;
};

// ============================================================================
// Oscillator Bank
// ============================================================================

class OscillatorBank {
public:
    static constexpr size_t MAX_OSCILLATORS = 64;

    struct Oscillator {
        float frequency = 440.0f;
        float phase = 0.0f;
        float amplitude = 1.0f;
        float pan = 0.5f;
        int waveform = 0;  // 0=sine, 1=saw, 2=square, 3=triangle
        bool active = false;
    };

    OscillatorBank() {
        oscillators_.fill(Oscillator{});
    }

    void setOscillator(size_t index, float freq, float amp, int wave = 0) {
        if (index < MAX_OSCILLATORS) {
            oscillators_[index].frequency = freq;
            oscillators_[index].amplitude = amp;
            oscillators_[index].waveform = wave;
            oscillators_[index].active = true;
        }
    }

    void process(float* output, size_t numSamples, float sampleRate) {
        const float twoPi = 6.28318530718f;

        std::fill(output, output + numSamples * 2, 0.0f);

        for (auto& osc : oscillators_) {
            if (!osc.active) continue;

            float phaseInc = osc.frequency / sampleRate;

            for (size_t i = 0; i < numSamples; ++i) {
                float sample = 0.0f;

                switch (osc.waveform) {
                    case 0: // Sine
                        sample = std::sin(osc.phase * twoPi);
                        break;
                    case 1: // Saw
                        sample = 2.0f * osc.phase - 1.0f;
                        break;
                    case 2: // Square
                        sample = osc.phase < 0.5f ? 1.0f : -1.0f;
                        break;
                    case 3: // Triangle
                        sample = 4.0f * std::abs(osc.phase - 0.5f) - 1.0f;
                        break;
                }

                sample *= osc.amplitude;

                // Stereo panning
                float leftGain = std::cos(osc.pan * 1.5708f);
                float rightGain = std::sin(osc.pan * 1.5708f);

                output[i * 2] += sample * leftGain;
                output[i * 2 + 1] += sample * rightGain;

                osc.phase += phaseInc;
                if (osc.phase >= 1.0f) osc.phase -= 1.0f;
            }
        }
    }

    void clear() {
        for (auto& osc : oscillators_) {
            osc.active = false;
        }
    }

private:
    std::array<Oscillator, MAX_OSCILLATORS> oscillators_;
};

// ============================================================================
// Granular Synthesizer
// ============================================================================

class GranularSynth {
public:
    struct Grain {
        size_t startPos = 0;
        size_t position = 0;
        size_t length = 0;
        float pitch = 1.0f;
        float amplitude = 1.0f;
        float pan = 0.5f;
        bool active = false;
    };

    static constexpr size_t MAX_GRAINS = 128;
    static constexpr size_t MAX_BUFFER_SIZE = 48000 * 30; // 30 seconds

    GranularSynth() {
        grains_.fill(Grain{});
        sourceBuffer_.resize(MAX_BUFFER_SIZE, 0.0f);
    }

    void loadBuffer(const float* data, size_t samples) {
        size_t copySize = std::min(samples, MAX_BUFFER_SIZE);
        std::copy(data, data + copySize, sourceBuffer_.begin());
        bufferSize_ = copySize;
    }

    void spawnGrain(size_t startPos, size_t length, float pitch, float amp, float pan) {
        for (auto& grain : grains_) {
            if (!grain.active) {
                grain.startPos = startPos % bufferSize_;
                grain.position = 0;
                grain.length = length;
                grain.pitch = pitch;
                grain.amplitude = amp;
                grain.pan = pan;
                grain.active = true;
                break;
            }
        }
    }

    void process(float* output, size_t numSamples) {
        std::fill(output, output + numSamples * 2, 0.0f);

        for (auto& grain : grains_) {
            if (!grain.active) continue;

            for (size_t i = 0; i < numSamples; ++i) {
                if (grain.position >= grain.length) {
                    grain.active = false;
                    break;
                }

                // Hann window envelope
                float env = 0.5f * (1.0f - std::cos(6.28318530718f *
                           grain.position / grain.length));

                // Linear interpolation for pitch shifting
                float srcPos = grain.startPos + grain.position * grain.pitch;
                size_t idx0 = static_cast<size_t>(srcPos) % bufferSize_;
                size_t idx1 = (idx0 + 1) % bufferSize_;
                float frac = srcPos - std::floor(srcPos);

                float sample = sourceBuffer_[idx0] * (1.0f - frac) +
                              sourceBuffer_[idx1] * frac;
                sample *= env * grain.amplitude;

                // Stereo panning
                float leftGain = std::cos(grain.pan * 1.5708f);
                float rightGain = std::sin(grain.pan * 1.5708f);

                output[i * 2] += sample * leftGain;
                output[i * 2 + 1] += sample * rightGain;

                grain.position++;
            }
        }
    }

private:
    std::array<Grain, MAX_GRAINS> grains_;
    std::vector<float> sourceBuffer_;
    size_t bufferSize_ = 0;
};

// ============================================================================
// Binaural Beat Generator
// ============================================================================

class BinauralBeatGenerator {
public:
    struct BinauralTone {
        float baseFrequency = 200.0f;
        float beatFrequency = 10.0f;  // Hz difference between ears
        float amplitude = 0.5f;
        bool active = false;
        float phaseL = 0.0f;
        float phaseR = 0.0f;
    };

    static constexpr size_t MAX_TONES = 8;

    BinauralBeatGenerator() {
        tones_.fill(BinauralTone{});
    }

    // Preset frequencies for different brainwave states
    void setDeltaState(float baseFreq = 150.0f) {
        // Delta: 0.5-4 Hz - Deep sleep, healing
        setTone(0, baseFreq, 2.0f, 0.4f);
        setTone(1, baseFreq * 2, 1.5f, 0.3f);
    }

    void setThetaState(float baseFreq = 200.0f) {
        // Theta: 4-8 Hz - Meditation, creativity
        setTone(0, baseFreq, 6.0f, 0.4f);
        setTone(1, baseFreq * 1.5f, 5.5f, 0.3f);
    }

    void setAlphaState(float baseFreq = 250.0f) {
        // Alpha: 8-13 Hz - Relaxed focus
        setTone(0, baseFreq, 10.0f, 0.4f);
        setTone(1, baseFreq * 1.5f, 10.5f, 0.3f);
    }

    void setBetaState(float baseFreq = 300.0f) {
        // Beta: 13-30 Hz - Active thinking
        setTone(0, baseFreq, 18.0f, 0.3f);
        setTone(1, baseFreq * 1.5f, 20.0f, 0.25f);
    }

    void setGammaState(float baseFreq = 350.0f) {
        // Gamma: 30-100 Hz - Peak focus
        setTone(0, baseFreq, 40.0f, 0.25f);
        setTone(1, baseFreq * 1.5f, 42.0f, 0.2f);
    }

    void setTone(size_t index, float baseFreq, float beatFreq, float amp) {
        if (index < MAX_TONES) {
            tones_[index].baseFrequency = baseFreq;
            tones_[index].beatFrequency = beatFreq;
            tones_[index].amplitude = amp;
            tones_[index].active = true;
        }
    }

    void process(float* output, size_t numSamples, float sampleRate) {
        const float twoPi = 6.28318530718f;

        for (size_t i = 0; i < numSamples; ++i) {
            float left = 0.0f;
            float right = 0.0f;

            for (auto& tone : tones_) {
                if (!tone.active) continue;

                float freqL = tone.baseFrequency - tone.beatFrequency * 0.5f;
                float freqR = tone.baseFrequency + tone.beatFrequency * 0.5f;

                left += std::sin(tone.phaseL * twoPi) * tone.amplitude;
                right += std::sin(tone.phaseR * twoPi) * tone.amplitude;

                tone.phaseL += freqL / sampleRate;
                tone.phaseR += freqR / sampleRate;

                if (tone.phaseL >= 1.0f) tone.phaseL -= 1.0f;
                if (tone.phaseR >= 1.0f) tone.phaseR -= 1.0f;
            }

            output[i * 2] += left;
            output[i * 2 + 1] += right;
        }
    }

    void clear() {
        for (auto& tone : tones_) {
            tone.active = false;
        }
    }

private:
    std::array<BinauralTone, MAX_TONES> tones_;
};

// ============================================================================
// Isochronic Tone Generator
// ============================================================================

class IsochronicGenerator {
public:
    struct IsochronicTone {
        float carrierFrequency = 200.0f;
        float pulseFrequency = 10.0f;
        float amplitude = 0.5f;
        float dutyCycle = 0.5f;
        float phase = 0.0f;
        float pulsePhase = 0.0f;
        bool active = false;
    };

    static constexpr size_t MAX_TONES = 4;

    IsochronicGenerator() {
        tones_.fill(IsochronicTone{});
    }

    void setTone(size_t index, float carrierFreq, float pulseFreq,
                 float amp, float dutyCycle = 0.5f) {
        if (index < MAX_TONES) {
            tones_[index].carrierFrequency = carrierFreq;
            tones_[index].pulseFrequency = pulseFreq;
            tones_[index].amplitude = amp;
            tones_[index].dutyCycle = dutyCycle;
            tones_[index].active = true;
        }
    }

    void process(float* output, size_t numSamples, float sampleRate) {
        const float twoPi = 6.28318530718f;

        for (size_t i = 0; i < numSamples; ++i) {
            float sample = 0.0f;

            for (auto& tone : tones_) {
                if (!tone.active) continue;

                // Carrier wave
                float carrier = std::sin(tone.phase * twoPi);

                // Pulse envelope (smooth)
                float pulseEnv = tone.pulsePhase < tone.dutyCycle ?
                    0.5f * (1.0f - std::cos(twoPi * tone.pulsePhase / tone.dutyCycle)) : 0.0f;

                sample += carrier * pulseEnv * tone.amplitude;

                tone.phase += tone.carrierFrequency / sampleRate;
                tone.pulsePhase += tone.pulseFrequency / sampleRate;

                if (tone.phase >= 1.0f) tone.phase -= 1.0f;
                if (tone.pulsePhase >= 1.0f) tone.pulsePhase -= 1.0f;
            }

            // Mono signal for isochronic
            output[i * 2] += sample;
            output[i * 2 + 1] += sample;
        }
    }

private:
    std::array<IsochronicTone, MAX_TONES> tones_;
};

// ============================================================================
// Melody Generator using Markov Chain
// ============================================================================

class MarkovMelodyGenerator {
public:
    static constexpr size_t NUM_NOTES = 12;
    static constexpr size_t CHAIN_ORDER = 2;

    MarkovMelodyGenerator() {
        initializeTransitionMatrix();
    }

    void setScale(const int* intervals, size_t numNotes) {
        scaleNotes_.clear();
        for (size_t i = 0; i < numNotes; ++i) {
            scaleNotes_.push_back(intervals[i]);
        }
        updateTransitionMatrix();
    }

    int generateNext(int currentNote1, int currentNote2) {
        size_t idx1 = currentNote1 % NUM_NOTES;
        size_t idx2 = currentNote2 % NUM_NOTES;

        std::uniform_real_distribution<float> dist(0.0f, 1.0f);
        float r = dist(rng_);

        float cumulative = 0.0f;
        for (size_t i = 0; i < NUM_NOTES; ++i) {
            cumulative += transitionMatrix_[idx1][idx2][i];
            if (r < cumulative) {
                return snapToScale(i);
            }
        }
        return snapToScale(0);
    }

    std::vector<int> generateSequence(int startNote, size_t length) {
        std::vector<int> sequence;
        sequence.reserve(length);

        int note1 = startNote;
        int note2 = startNote;

        for (size_t i = 0; i < length; ++i) {
            int nextNote = generateNext(note1, note2);
            sequence.push_back(nextNote + 60); // Middle C octave
            note1 = note2;
            note2 = nextNote;
        }

        return sequence;
    }

private:
    void initializeTransitionMatrix() {
        // Initialize with musical probability distribution
        for (size_t i = 0; i < NUM_NOTES; ++i) {
            for (size_t j = 0; j < NUM_NOTES; ++j) {
                float total = 0.0f;
                for (size_t k = 0; k < NUM_NOTES; ++k) {
                    // Prefer stepwise motion and consonant intervals
                    int interval = std::abs(static_cast<int>(k) - static_cast<int>(j));
                    float prob = 0.0f;

                    switch (interval) {
                        case 0: prob = 0.15f; break;  // Repeat
                        case 1: prob = 0.25f; break;  // Minor 2nd
                        case 2: prob = 0.25f; break;  // Major 2nd
                        case 3: prob = 0.10f; break;  // Minor 3rd
                        case 4: prob = 0.10f; break;  // Major 3rd
                        case 5: prob = 0.08f; break;  // Perfect 4th
                        case 7: prob = 0.05f; break;  // Perfect 5th
                        default: prob = 0.02f; break;
                    }

                    transitionMatrix_[i][j][k] = prob;
                    total += prob;
                }
                // Normalize
                for (size_t k = 0; k < NUM_NOTES; ++k) {
                    transitionMatrix_[i][j][k] /= total;
                }
            }
        }
    }

    void updateTransitionMatrix() {
        // Boost probabilities for scale notes
        for (size_t i = 0; i < NUM_NOTES; ++i) {
            for (size_t j = 0; j < NUM_NOTES; ++j) {
                float total = 0.0f;
                for (size_t k = 0; k < NUM_NOTES; ++k) {
                    if (isInScale(k)) {
                        transitionMatrix_[i][j][k] *= 2.0f;
                    }
                    total += transitionMatrix_[i][j][k];
                }
                // Renormalize
                for (size_t k = 0; k < NUM_NOTES; ++k) {
                    transitionMatrix_[i][j][k] /= total;
                }
            }
        }
    }

    bool isInScale(size_t note) const {
        for (int scaleNote : scaleNotes_) {
            if (static_cast<int>(note % 12) == scaleNote % 12) return true;
        }
        return false;
    }

    int snapToScale(size_t note) const {
        if (scaleNotes_.empty()) return note;

        int n = static_cast<int>(note % 12);
        int minDist = 12;
        int closest = n;

        for (int scaleNote : scaleNotes_) {
            int dist = std::abs(n - (scaleNote % 12));
            if (dist < minDist) {
                minDist = dist;
                closest = scaleNote % 12;
            }
        }
        return closest;
    }

    std::array<std::array<std::array<float, NUM_NOTES>, NUM_NOTES>, NUM_NOTES> transitionMatrix_;
    std::vector<int> scaleNotes_;
    std::mt19937 rng_{std::random_device{}()};
};

// ============================================================================
// Chord Progression Generator
// ============================================================================

class ChordProgressionGenerator {
public:
    struct Chord {
        int root = 0;           // MIDI note
        std::vector<int> notes;
        float duration = 1.0f;  // In beats
        std::string name;
    };

    ChordProgressionGenerator() {
        initializeProgressionRules();
    }

    void setKey(int rootNote, bool isMajor = true) {
        keyRoot_ = rootNote;
        isMajor_ = isMajor;
    }

    std::vector<Chord> generateProgression(size_t numChords) {
        std::vector<Chord> progression;
        progression.reserve(numChords);

        int currentDegree = 0; // Start on tonic

        for (size_t i = 0; i < numChords; ++i) {
            Chord chord = buildChord(currentDegree);
            progression.push_back(chord);
            currentDegree = getNextDegree(currentDegree);
        }

        return progression;
    }

    // Common progressions
    std::vector<Chord> getI_IV_V_I() {
        return generateFromDegrees({0, 3, 4, 0});
    }

    std::vector<Chord> getI_V_vi_IV() {
        return generateFromDegrees({0, 4, 5, 3});
    }

    std::vector<Chord> getii_V_I() {
        return generateFromDegrees({1, 4, 0});
    }

    std::vector<Chord> getI_vi_IV_V() {
        return generateFromDegrees({0, 5, 3, 4});
    }

private:
    Chord buildChord(int degree) {
        Chord chord;

        const auto& scale = isMajor_ ? MusicTheory::MAJOR_SCALE : MusicTheory::MINOR_SCALE;
        chord.root = keyRoot_ + scale[degree % 7];

        // Determine chord quality based on scale degree
        const int* intervals;
        size_t numIntervals;

        if (isMajor_) {
            switch (degree % 7) {
                case 0: case 3: case 4: // I, IV, V - major
                    intervals = MusicTheory::MAJOR_TRIAD.data();
                    numIntervals = 3;
                    break;
                case 1: case 2: case 5: // ii, iii, vi - minor
                    intervals = MusicTheory::MINOR_TRIAD.data();
                    numIntervals = 3;
                    break;
                default: // vii° - diminished
                    intervals = MusicTheory::MINOR_TRIAD.data();
                    numIntervals = 3;
                    break;
            }
        } else {
            switch (degree % 7) {
                case 0: case 3: case 4: // i, iv, v - minor
                    intervals = MusicTheory::MINOR_TRIAD.data();
                    numIntervals = 3;
                    break;
                case 2: case 5: case 6: // III, VI, VII - major
                    intervals = MusicTheory::MAJOR_TRIAD.data();
                    numIntervals = 3;
                    break;
                default: // ii° - diminished
                    intervals = MusicTheory::MINOR_TRIAD.data();
                    numIntervals = 3;
                    break;
            }
        }

        for (size_t i = 0; i < numIntervals; ++i) {
            chord.notes.push_back(chord.root + intervals[i]);
        }

        return chord;
    }

    std::vector<Chord> generateFromDegrees(const std::vector<int>& degrees) {
        std::vector<Chord> progression;
        for (int degree : degrees) {
            progression.push_back(buildChord(degree));
        }
        return progression;
    }

    int getNextDegree(int currentDegree) {
        std::uniform_real_distribution<float> dist(0.0f, 1.0f);
        float r = dist(rng_);

        float cumulative = 0.0f;
        for (size_t i = 0; i < 7; ++i) {
            cumulative += progressionRules_[currentDegree][i];
            if (r < cumulative) {
                return static_cast<int>(i);
            }
        }
        return 0;
    }

    void initializeProgressionRules() {
        // Probability matrix for chord movement
        // Row = current chord (I-vii), Column = next chord
        progressionRules_ = {{
            // I can go to: II, III, IV, V, VI, VII (common functional harmony)
            {0.05f, 0.10f, 0.05f, 0.30f, 0.25f, 0.15f, 0.10f},
            // ii typically goes to V or vii
            {0.10f, 0.05f, 0.05f, 0.10f, 0.50f, 0.10f, 0.10f},
            // iii goes to IV or vi
            {0.10f, 0.10f, 0.05f, 0.30f, 0.15f, 0.20f, 0.10f},
            // IV goes to I, V, or ii
            {0.30f, 0.20f, 0.05f, 0.05f, 0.30f, 0.05f, 0.05f},
            // V almost always goes to I or vi
            {0.60f, 0.05f, 0.05f, 0.05f, 0.05f, 0.15f, 0.05f},
            // vi goes to ii, IV, or V
            {0.10f, 0.25f, 0.10f, 0.25f, 0.20f, 0.05f, 0.05f},
            // vii° goes to I
            {0.70f, 0.05f, 0.05f, 0.05f, 0.05f, 0.05f, 0.05f}
        }};
    }

    int keyRoot_ = 60; // Middle C
    bool isMajor_ = true;
    std::array<std::array<float, 7>, 7> progressionRules_;
    std::mt19937 rng_{std::random_device{}()};
};

// ============================================================================
// Rhythm Generator
// ============================================================================

class RhythmGenerator {
public:
    struct RhythmEvent {
        float time = 0.0f;      // In beats
        float duration = 0.5f;
        float velocity = 0.8f;
        int subdivision = 0;    // 0=quarter, 1=eighth, 2=sixteenth
    };

    RhythmGenerator() {
        initializePatterns();
    }

    std::vector<RhythmEvent> generatePattern(size_t numBeats, float density = 0.5f) {
        std::vector<RhythmEvent> events;

        std::uniform_real_distribution<float> dist(0.0f, 1.0f);

        for (size_t beat = 0; beat < numBeats; ++beat) {
            // Main beat hit
            if (dist(rng_) < 0.9f) {
                RhythmEvent event;
                event.time = static_cast<float>(beat);
                event.velocity = 0.8f + dist(rng_) * 0.2f;
                events.push_back(event);
            }

            // Subdivisions based on density
            for (int sub = 1; sub < 4; ++sub) {
                float subTime = static_cast<float>(beat) + sub * 0.25f;
                if (dist(rng_) < density * 0.5f) {
                    RhythmEvent event;
                    event.time = subTime;
                    event.velocity = 0.5f + dist(rng_) * 0.3f;
                    event.subdivision = 2;
                    events.push_back(event);
                }
            }
        }

        return events;
    }

    std::vector<RhythmEvent> getEuclidean(int hits, int steps) {
        std::vector<RhythmEvent> events;

        // Bresenham-style Euclidean rhythm
        for (int i = 0; i < steps; ++i) {
            if ((i * hits) % steps < hits) {
                RhythmEvent event;
                event.time = static_cast<float>(i) / steps * 4.0f; // 4 beats
                events.push_back(event);
            }
        }

        return events;
    }

private:
    void initializePatterns() {
        // Pre-defined rhythm patterns could be loaded here
    }

    std::mt19937 rng_{std::random_device{}()};
};

// ============================================================================
// Main AI Music Generator
// ============================================================================

class EchoelAIMusicGen {
public:
    struct GenerationConfig {
        MusicGenre genre = MusicGenre::Ambient;
        MoodType mood = MoodType::Calm;
        float tempo = 80.0f;            // BPM
        int keyRoot = 60;               // MIDI note (C4)
        bool majorKey = true;
        HarmonicComplexity harmonyLevel = HarmonicComplexity::Moderate;
        float density = 0.5f;           // 0-1, note density
        float variation = 0.3f;         // 0-1, variation amount
        bool useBinauralBeats = true;
        bool useIsochronicTones = false;
        float binauralIntensity = 0.3f;
        float isochronicIntensity = 0.3f;
        float sampleRate = 48000.0f;

        // Bio-reactive settings
        bool bioReactive = true;
        float bioSensitivity = 0.5f;
        float targetAlpha = 0.5f;
        float targetTheta = 0.5f;
    };

    struct GeneratedAudio {
        std::vector<float> samples;     // Interleaved stereo
        float sampleRate = 48000.0f;
        float duration = 0.0f;          // Seconds

        // Analysis data
        std::vector<float> spectrum;
        std::vector<float> onsets;
        float averageLoudness = 0.0f;
    };

    EchoelAIMusicGen()
        : melodyGen_(), chordGen_(), rhythmGen_(),
          oscBank_(), granular_(), binaural_(), isochronic_() {

        lstm_ = std::make_unique<LSTMCell>(32, 64);
        outputLayer_ = std::make_unique<NeuralLayer>(64, 12);
    }

    void setConfig(const GenerationConfig& config) {
        config_ = config;
        chordGen_.setKey(config.keyRoot, config.majorKey);
        setupGenrePreset();
    }

    void setBioState(const BioMusicState& state) {
        bioState_ = state;
        bioState_.updateDerivedStates();
        adaptToBioState();
    }

    GeneratedAudio generate(float durationSeconds) {
        GeneratedAudio result;
        result.sampleRate = config_.sampleRate;
        result.duration = durationSeconds;

        size_t totalSamples = static_cast<size_t>(durationSeconds * config_.sampleRate);
        result.samples.resize(totalSamples * 2, 0.0f); // Stereo

        // Generate chord progression
        size_t numBars = static_cast<size_t>(durationSeconds * config_.tempo / 60.0f / 4.0f) + 1;
        auto chords = chordGen_.generateProgression(numBars * 2);

        // Generate melody
        setupScaleForMelody();
        auto melodyNotes = melodyGen_.generateSequence(config_.keyRoot % 12, numBars * 16);

        // Generate rhythm
        auto rhythm = rhythmGen_.generatePattern(numBars * 4, config_.density);

        // Render audio
        renderChords(result.samples.data(), totalSamples, chords);
        renderMelody(result.samples.data(), totalSamples, melodyNotes, rhythm);

        // Add binaural/isochronic if enabled
        if (config_.useBinauralBeats) {
            renderBinauralBeats(result.samples.data(), totalSamples);
        }
        if (config_.useIsochronicTones) {
            renderIsochronicTones(result.samples.data(), totalSamples);
        }

        // Apply master processing
        applyMasterProcessing(result.samples.data(), totalSamples);

        // Analyze output
        analyzeOutput(result);

        return result;
    }

    // Real-time generation for streaming
    void processRealtime(float* output, size_t numSamples) {
        oscBank_.process(output, numSamples, config_.sampleRate);

        if (config_.useBinauralBeats) {
            binaural_.process(output, numSamples, config_.sampleRate);
        }
        if (config_.useIsochronicTones) {
            isochronic_.process(output, numSamples, config_.sampleRate);
        }

        // Apply bio-reactive modulation
        if (config_.bioReactive) {
            applyBioModulation(output, numSamples);
        }
    }

    // LSTM-based note prediction
    int predictNextNote(const std::vector<float>& context) {
        std::vector<float> lstmOutput(64);
        std::vector<float> noteProbs(12);

        lstm_->forward(context.data(), lstmOutput.data());
        outputLayer_->forward(lstmOutput.data(), noteProbs.data());

        // Softmax and sample
        float maxProb = *std::max_element(noteProbs.begin(), noteProbs.end());
        float sum = 0.0f;
        for (auto& p : noteProbs) {
            p = std::exp(p - maxProb);
            sum += p;
        }
        for (auto& p : noteProbs) p /= sum;

        std::discrete_distribution<int> dist(noteProbs.begin(), noteProbs.end());
        return dist(rng_);
    }

    void resetState() {
        lstm_->reset();
        oscBank_.clear();
        binaural_.clear();
    }

private:
    void setupGenrePreset() {
        switch (config_.genre) {
            case MusicGenre::Ambient:
                config_.tempo = 60.0f + bioState_.relaxationLevel * 20.0f;
                config_.density = 0.2f;
                binaural_.setAlphaState();
                break;

            case MusicGenre::Meditation:
                config_.tempo = 50.0f + bioState_.relaxationLevel * 10.0f;
                config_.density = 0.15f;
                binaural_.setThetaState();
                break;

            case MusicGenre::Electronic:
                config_.tempo = 120.0f + bioState_.arousalLevel * 20.0f;
                config_.density = 0.6f;
                binaural_.setBetaState();
                break;

            case MusicGenre::Binaural:
                config_.tempo = 60.0f;
                config_.density = 0.1f;
                setupBinauralForBioState();
                break;

            case MusicGenre::Orchestral:
                config_.tempo = 90.0f;
                config_.density = 0.4f;
                break;

            default:
                break;
        }
    }

    void setupBinauralForBioState() {
        // Adapt binaural frequencies to guide user toward target state
        float currentAlpha = bioState_.brainwaveAlpha;
        float targetAlpha = config_.targetAlpha;

        if (currentAlpha < targetAlpha) {
            // Need to increase alpha - use alpha range beats
            binaural_.setAlphaState();
        } else if (bioState_.brainwaveTheta < config_.targetTheta) {
            // Need to increase theta
            binaural_.setThetaState();
        } else if (bioState_.arousalLevel > 0.7f) {
            // Too aroused - calm down
            binaural_.setDeltaState();
        } else {
            // Maintain current state
            binaural_.setAlphaState();
        }
    }

    void setupScaleForMelody() {
        const int* scaleData;
        size_t scaleSize;

        switch (config_.mood) {
            case MoodType::Calm:
            case MoodType::Relaxed:
                scaleData = MusicTheory::PENTATONIC_MAJOR.data();
                scaleSize = 5;
                break;

            case MoodType::Melancholic:
            case MoodType::Contemplative:
                scaleData = MusicTheory::MINOR_SCALE.data();
                scaleSize = 7;
                break;

            case MoodType::Mysterious:
                scaleData = MusicTheory::PHRYGIAN_SCALE.data();
                scaleSize = 7;
                break;

            case MoodType::Uplifting:
            case MoodType::Euphoric:
                scaleData = MusicTheory::LYDIAN_SCALE.data();
                scaleSize = 7;
                break;

            default:
                scaleData = MusicTheory::MAJOR_SCALE.data();
                scaleSize = 7;
                break;
        }

        melodyGen_.setScale(scaleData, scaleSize);
    }

    void renderChords(float* output, size_t numSamples,
                      const std::vector<ChordProgressionGenerator::Chord>& chords) {
        if (chords.empty()) return;

        float beatsPerSample = config_.tempo / 60.0f / config_.sampleRate;
        float currentBeat = 0.0f;
        size_t chordIndex = 0;
        float chordDuration = 4.0f; // Beats per chord

        for (size_t i = 0; i < numSamples; ++i) {
            // Check if we need to change chord
            if (currentBeat >= (chordIndex + 1) * chordDuration) {
                chordIndex = (chordIndex + 1) % chords.size();
                updateOscillatorsForChord(chords[chordIndex]);
            }

            currentBeat += beatsPerSample;
        }

        // Actually render the oscillators
        oscBank_.process(output, numSamples, config_.sampleRate);
    }

    void updateOscillatorsForChord(const ChordProgressionGenerator::Chord& chord) {
        oscBank_.clear();

        for (size_t i = 0; i < chord.notes.size() && i < 6; ++i) {
            float freq = MusicTheory::noteToFrequency(chord.notes[i]);
            float amp = 0.15f / chord.notes.size();
            oscBank_.setOscillator(i, freq, amp, 0); // Sine waves for pads
        }
    }

    void renderMelody(float* output, size_t numSamples,
                      const std::vector<int>& notes,
                      const std::vector<RhythmGenerator::RhythmEvent>& rhythm) {
        if (notes.empty() || rhythm.empty()) return;

        float beatsPerSample = config_.tempo / 60.0f / config_.sampleRate;
        const float twoPi = 6.28318530718f;

        size_t noteIndex = 0;
        float currentBeat = 0.0f;
        float notePhase = 0.0f;
        float noteEnv = 0.0f;
        float currentFreq = 0.0f;
        float noteDuration = 0.0f;
        float noteStartBeat = 0.0f;

        for (size_t i = 0; i < numSamples; ++i) {
            // Check for note triggers
            for (const auto& event : rhythm) {
                if (std::abs(currentBeat - event.time) < beatsPerSample) {
                    noteIndex = (noteIndex + 1) % notes.size();
                    currentFreq = MusicTheory::noteToFrequency(notes[noteIndex]);
                    noteStartBeat = currentBeat;
                    noteDuration = event.duration;
                    noteEnv = event.velocity;
                }
            }

            // ADSR envelope (simplified)
            float beatsSinceStart = currentBeat - noteStartBeat;
            float envValue = 0.0f;
            if (beatsSinceStart < 0.1f) {
                envValue = beatsSinceStart / 0.1f; // Attack
            } else if (beatsSinceStart < noteDuration) {
                envValue = 1.0f - (beatsSinceStart - 0.1f) / noteDuration * 0.3f; // Decay/Sustain
            } else {
                envValue = 0.7f * std::exp(-(beatsSinceStart - noteDuration) * 5.0f); // Release
            }
            envValue *= noteEnv;

            // Generate sample
            float sample = std::sin(notePhase * twoPi) * envValue * 0.2f;

            output[i * 2] += sample;
            output[i * 2 + 1] += sample;

            notePhase += currentFreq / config_.sampleRate;
            if (notePhase >= 1.0f) notePhase -= 1.0f;

            currentBeat += beatsPerSample;
        }
    }

    void renderBinauralBeats(float* output, size_t numSamples) {
        binaural_.process(output, numSamples, config_.sampleRate);

        // Scale by intensity
        for (size_t i = 0; i < numSamples * 2; ++i) {
            output[i] *= config_.binauralIntensity;
        }
    }

    void renderIsochronicTones(float* output, size_t numSamples) {
        // Set up isochronic based on desired brainwave state
        float targetFreq = 10.0f; // Alpha by default

        if (bioState_.brainwaveTheta > bioState_.brainwaveAlpha) {
            targetFreq = 6.0f; // Theta
        } else if (bioState_.brainwaveBeta > bioState_.brainwaveAlpha) {
            targetFreq = 15.0f; // Beta
        }

        isochronic_.setTone(0, 200.0f, targetFreq,
                           config_.isochronicIntensity);
        isochronic_.process(output, numSamples, config_.sampleRate);
    }

    void adaptToBioState() {
        if (!config_.bioReactive) return;

        // Tempo adaptation
        float relaxDiff = bioState_.targetRelaxation - bioState_.relaxationLevel;
        if (relaxDiff > 0.2f) {
            // Need more relaxation - slow down
            config_.tempo *= 0.95f;
        } else if (relaxDiff < -0.2f) {
            config_.tempo *= 1.02f;
        }
        config_.tempo = std::clamp(config_.tempo, 40.0f, 180.0f);

        // Density adaptation
        if (bioState_.arousalLevel > 0.7f) {
            config_.density *= 0.9f;
        }

        // Binaural adaptation
        setupBinauralForBioState();
    }

    void applyBioModulation(float* output, size_t numSamples) {
        float modDepth = config_.bioSensitivity * 0.1f;
        float breathMod = std::sin(bioState_.breathingRate * 0.5f);

        for (size_t i = 0; i < numSamples; ++i) {
            float mod = 1.0f + breathMod * modDepth *
                       (static_cast<float>(i) / numSamples);
            output[i * 2] *= mod;
            output[i * 2 + 1] *= mod;
        }
    }

    void applyMasterProcessing(float* output, size_t numSamples) {
        // Soft clipping
        for (size_t i = 0; i < numSamples * 2; ++i) {
            float x = output[i];
            output[i] = std::tanh(x);
        }

        // Simple DC blocking
        float dcL = 0.0f, dcR = 0.0f;
        const float dcCoeff = 0.995f;

        for (size_t i = 0; i < numSamples; ++i) {
            float inL = output[i * 2];
            float inR = output[i * 2 + 1];

            output[i * 2] = inL - dcL;
            output[i * 2 + 1] = inR - dcR;

            dcL = inL * (1.0f - dcCoeff) + dcL * dcCoeff;
            dcR = inR * (1.0f - dcCoeff) + dcR * dcCoeff;
        }
    }

    void analyzeOutput(GeneratedAudio& audio) {
        // Calculate average loudness
        float sumSquares = 0.0f;
        for (float sample : audio.samples) {
            sumSquares += sample * sample;
        }
        audio.averageLoudness = std::sqrt(sumSquares / audio.samples.size());

        // Simple onset detection (placeholder)
        audio.onsets.clear();

        // Spectrum analysis would go here
        audio.spectrum.resize(512, 0.0f);
    }

    GenerationConfig config_;
    BioMusicState bioState_;

    MarkovMelodyGenerator melodyGen_;
    ChordProgressionGenerator chordGen_;
    RhythmGenerator rhythmGen_;

    OscillatorBank oscBank_;
    GranularSynth granular_;
    BinauralBeatGenerator binaural_;
    IsochronicGenerator isochronic_;

    std::unique_ptr<LSTMCell> lstm_;
    std::unique_ptr<NeuralLayer> outputLayer_;

    std::mt19937 rng_{std::random_device{}()};
};

} // namespace AI
} // namespace Echoel
