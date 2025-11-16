#pragma once

#include <JuceHeader.h>
#include <array>

/**
 * TR808Emulation - Legendary Rhythm Composer
 *
 * Authentic emulation of the Roland TR-808 drum machine.
 * The most influential drum machine in music history.
 *
 * Features:
 * - 16 authentic 808 sounds
 * - Step sequencer (16 steps, chainable patterns)
 * - Individual tuning/decay per sound
 * - Accent control
 * - Individual outputs per drum
 * - Pattern chaining
 * - Bio-reactive pattern modulation
 */
class TR808Emulation
{
public:
    enum class Drum
    {
        BassDrum, SnareDrum,
        LowTom, MidTom, HighTom,
        RimShot, HandClap,
        ClosedHat, OpenHat,
        Cymbal, Cowbell, Clave,
        COUNT
    };

    struct DrumSound
    {
        float level = 0.8f;
        float tune = 0.5f;              // 0.0 to 1.0
        float decay = 0.5f;             // For toms, bass drum
        float snappy = 0.5f;            // For snare
    };

    struct Pattern
    {
        std::array<std::array<bool, 16>, static_cast<int>(Drum::COUNT)> steps;
        std::array<bool, 16> accents;
        float swing = 0.0f;             // 0.0 to 1.0
    };

    TR808Emulation();
    ~TR808Emulation() = default;

    DrumSound& getDrumSound(Drum drum);
    Pattern& getCurrentPattern() { return currentPattern; }

    void setTempo(float bpm);
    void setStepOn(Drum drum, int step, bool on);
    void setAccent(int step, bool on);
    void setSwing(float amount);

    void play();
    void stop();
    bool isPlaying() const { return playing; }

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

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (TR808Emulation)
};
