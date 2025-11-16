#pragma once

#include <JuceHeader.h>
#include <array>

/**
 * TR909Emulation - Classic House/Techno Drum Machine
 *
 * Authentic emulation of the Roland TR-909.
 * Hybrid analog/sample drum machine that defined house and techno.
 *
 * Features:
 * - 11 authentic 909 sounds (analog + samples)
 * - Step sequencer with shuffle
 * - Individual tuning per sound
 * - Accent & flam
 * - Pattern storage & chaining
 * - MIDI learn for live performance
 * - Bio-reactive pattern evolution
 */
class TR909Emulation
{
public:
    enum class Drum
    {
        BassDrum, SnareDrum,
        LowTom, MidTom, HighTom,
        RimShot, HandClap,
        ClosedHat, OpenHat,
        RideCymbal, CrashCymbal,
        COUNT
    };

    struct DrumSound
    {
        float level = 0.8f;
        float tune = 0.5f;
        float decay = 0.5f;
        float attack = 0.0f;            // For 909 attack control
    };

    struct Pattern
    {
        std::array<std::array<bool, 16>, static_cast<int>(Drum::COUNT)> steps;
        std::array<bool, 16> accents;
        std::array<bool, 16> flams;
        float shuffle = 0.0f;           // 0.0 to 1.0
    };

    TR909Emulation();
    ~TR909Emulation() = default;

    DrumSound& getDrumSound(Drum drum);
    Pattern& getCurrentPattern() { return currentPattern; }

    void setTempo(float bpm);
    void setStepOn(Drum drum, int step, bool on);
    void setAccent(int step, bool on);
    void setFlam(int step, bool on);
    void setShuffle(float amount);

    void play();
    void stop();

    void setBioReactiveEnabled(bool enabled);
    void setBioData(float hrv, float coherence, float breath);

    void prepare(double sampleRate, int maxBlockSize);
    void reset();
    void process(juce::AudioBuffer<float>& buffer);

private:
    std::array<DrumSound, static_cast<int>(Drum::COUNT)> drumSounds;
    Pattern currentPattern;
    float tempo = 120.0f;
    bool playing = false;
    bool bioReactiveEnabled = false;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (TR909Emulation)
};
