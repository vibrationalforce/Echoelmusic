#pragma once

#include <JuceHeader.h>

/**
 * Harmonizer - Intelligent Pitch-Shifted Harmony Generator
 *
 * Creates professional multi-voice harmonies with scale awareness:
 * - Up to 4 harmony voices
 * - Scale-aware intervals (automatic 3rd/5th/octave)
 * - Independent pitch shift per voice (±24 semitones)
 * - Independent pan and level per voice
 * - Formant preservation for natural sound
 * - Delay compensation for phase alignment
 *
 * Used on: Choir stacking, harmonies, Imogen Heap-style vocals
 */
class Harmonizer
{
public:
    Harmonizer();
    ~Harmonizer();

    //==============================================================================
    // DSP Lifecycle
    void prepare(double sampleRate, int maximumBlockSize);
    void reset();
    void process(juce::AudioBuffer<float>& buffer);

    //==============================================================================
    // Parameters

    /** Set number of active voices (0-4) */
    void setVoiceCount(int count);

    /** Set voice interval in semitones (-24 to +24) */
    void setVoiceInterval(int voiceIndex, int semitones);

    /** Set voice level (0-1) */
    void setVoiceLevel(int voiceIndex, float level);

    /** Set voice pan (-1 to +1) */
    void setVoicePan(int voiceIndex, float pan);

    /** Set scale mode for intelligent harmonies (0=chromatic, 1=major, 2=minor) */
    void setScaleMode(int mode);

    /** Set root note (0-11): C, C#, D, D#, E, F, F#, G, G#, A, A#, B */
    void setRootNote(int note);

    /** Enable formant preservation */
    void setFormantPreservation(bool enabled);

    /** Set mix (0-1): dry/wet blend */
    void setMix(float mix);

private:
    //==============================================================================
    // Voice Processor (Pitch Shifter per Voice)
    struct HarmonyVoice
    {
        juce::dsp::DelayLine<float, juce::dsp::DelayLineInterpolationTypes::Lagrange3rd> delayLine;
        float sampleRate = 44100.0f;
        int semitones = 0;
        float level = 1.0f;
        float pan = 0.0f;  // -1 (left) to +1 (right)
        bool active = false;
        float grainPhase = 0.0f;
        float grainSize = 0.0f;

        void prepare(const juce::dsp::ProcessSpec& spec)
        {
            sampleRate = static_cast<float>(spec.sampleRate);
            delayLine.prepare(spec);
            delayLine.setMaximumDelayInSamples(static_cast<int>(0.1f * sampleRate));  // 100ms
            grainSize = 0.02f * sampleRate;  // 20ms grains
        }

        void reset()
        {
            delayLine.reset();
            grainPhase = 0.0f;
        }

        float process(float input, int channel)
        {
            if (!active || level < 0.001f)
                return 0.0f;

            // Calculate pitch ratio
            float pitchRatio = std::pow(2.0f, semitones / 12.0f);

            // Push input to delay line
            delayLine.pushSample(channel, input);

            // Read with pitch shift
            float delay = grainSize * (1.0f - pitchRatio);
            if (delay < 0.0f) delay = 0.0f;

            float output = delayLine.popSample(channel, delay);

            // Apply window (Hann window for smooth crossfade)
            float windowPhase = std::fmod(grainPhase, grainSize) / grainSize;
            float window = 0.5f - 0.5f * std::cos(2.0f * juce::MathConstants<float>::pi * windowPhase);

            grainPhase += pitchRatio;
            if (grainPhase >= grainSize)
                grainPhase -= grainSize;

            // Apply pan (simple constant power panning)
            float panGain = 1.0f;
            if (channel == 0)  // Left
                panGain = std::cos((pan + 1.0f) * juce::MathConstants<float>::pi / 4.0f);
            else  // Right
                panGain = std::sin((pan + 1.0f) * juce::MathConstants<float>::pi / 4.0f);

            return output * window * level * panGain;
        }
    };

    std::array<HarmonyVoice, 4> voices;

    //==============================================================================
    // Scale-Aware Interval Quantizer
    struct IntervalQuantizer
    {
        int scaleMode = 0;  // 0=chromatic, 1=major, 2=minor
        int rootNote = 0;   // 0-11 (C-B)

        int quantizeInterval(int semitones)
        {
            if (scaleMode == 0)  // Chromatic - no quantization
                return semitones;

            // Major scale intervals: 0, 2, 4, 5, 7, 9, 11
            const std::array<int, 12> majorScale = {1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1};
            // Minor scale intervals: 0, 2, 3, 5, 7, 8, 10
            const std::array<int, 12> minorScale = {1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 0};

            const auto& scale = (scaleMode == 1) ? majorScale : minorScale;

            // Quantize to nearest scale degree
            int octave = semitones / 12;
            int noteInScale = ((semitones % 12) + 12) % 12;

            // Find nearest scale note
            int direction = semitones >= 0 ? 1 : -1;
            while (!scale[noteInScale])
            {
                noteInScale += direction;
                if (noteInScale < 0) { noteInScale += 12; octave--; }
                if (noteInScale >= 12) { noteInScale -= 12; octave++; }
            }

            return octave * 12 + noteInScale;
        }
    };

    IntervalQuantizer intervalQuantizer;

    //==============================================================================
    // Intelligent Preset Intervals
    void applyPresetIntervals()
    {
        // Common harmony intervals based on scale
        if (intervalQuantizer.scaleMode == 1)  // Major
        {
            // Major 3rd, Perfect 5th, Octave
            voices[0].semitones = 4;   // Major 3rd
            voices[1].semitones = 7;   // Perfect 5th
            voices[2].semitones = 12;  // Octave up
            voices[3].semitones = -12; // Octave down
        }
        else if (intervalQuantizer.scaleMode == 2)  // Minor
        {
            // Minor 3rd, Perfect 5th, Octave
            voices[0].semitones = 3;   // Minor 3rd
            voices[1].semitones = 7;   // Perfect 5th
            voices[2].semitones = 12;  // Octave up
            voices[3].semitones = -12; // Octave down
        }
        else  // Chromatic
        {
            // Default intervals
            voices[0].semitones = 4;   // Major 3rd
            voices[1].semitones = 7;   // Perfect 5th
            voices[2].semitones = 12;  // Octave up
            voices[3].semitones = -5;  // Perfect 4th down
        }
    }

    //==============================================================================
    // Parameters
    int voiceCount = 2;
    int scaleMode = 0;
    int rootNote = 0;
    bool formantPreservation = true;
    float currentMix = 0.5f;

    double currentSampleRate = 44100.0;

    // ✅ OPTIMIZATION: Pre-allocated buffers to avoid audio thread allocation
    juce::AudioBuffer<float> dryBuffer;
    juce::AudioBuffer<float> harmonyBuffer;
    std::array<juce::AudioBuffer<float>, 4> voiceBuffers;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (Harmonizer)
};
