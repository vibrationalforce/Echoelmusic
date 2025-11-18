#pragma once

#include <JuceHeader.h>

/**
 * 🎻 EchoelString - Physical Modeling String Engine
 *
 * SUPER INTELLIGENCE FEATURES:
 * - Waveguide synthesis for realistic strings
 * - ML bow pressure detection and emulation
 * - Automatic divisi (section splitting)
 * - Biometric vibrato from performer emotional state
 * - Real-time articulation switching (legato, spiccato, tremolo, sul ponticello)
 *
 * STRING SECTIONS:
 * - Solo Violin, Viola, Cello, Double Bass
 * - String Quartet (1st Violin, 2nd Violin, Viola, Cello)
 * - String Orchestra (8-8-6-6-4 typical)
 * - Chamber Strings (small ensemble)
 *
 * ARTICULATIONS:
 * - Arco (bowed): Legato, Détaché, Spiccato, Staccato, Marcato
 * - Tremolo (rapid bow)
 * - Col legno (hitting with wood)
 * - Pizzicato (plucked)
 * - Harmonics
 * - Sul ponticello (near bridge, glassy)
 * - Sul tasto (near fingerboard, warm)
 *
 * COMPETITORS: Spitfire Strings, Vienna Strings, EastWest Hollywood Strings
 * USP: Real-time physical modeling + ML bow control + Biometric vibrato + No samples
 */
class EchoelString
{
public:
    enum class StringInstrument {
        SoloViolin, SoloViola, SoloCello, SoloDoubleBass,
        StringQuartet, ChamberStrings, StringOrchestra
    };

    enum class BowArticulation {
        Legato, Detache, Spiccato, Staccato, Marcato,
        Tremolo, ColLegno, Pizzicato, Harmonics,
        SulPonticello, SulTasto
    };

    struct PhysicalStringParams {
        float bowPressure = 0.5f;
        float bowPosition = 0.1f;       // 0.0 = bridge, 1.0 = fingerboard
        float bowSpeed = 0.5f;
        float stringTension = 0.7f;

        // Body resonance
        float bodySize = 0.5f;          // Violin = 0, Cello = 0.5, Bass = 1.0
        float bodyResonance = 0.7f;
    };

    struct SectionParams {
        int violins1 = 8;
        int violins2 = 8;
        int violas = 6;
        int cellos = 6;
        int basses = 4;

        float sectionSpread = 0.5f;     // Stereo width
        float tuningVariation = 0.02f;  // Natural detuning
        float timingVariation = 0.01f;  // Attack spread (seconds)
    };

    void setInstrument(StringInstrument instrument);
    void setArticulation(BowArticulation articulation);
    void setPhysicalModel(const PhysicalStringParams& params);
    void setSectionSize(const SectionParams& params);

    // ML bow control
    void trainBowModel(const juce::File& referenceRecording);

    // Biometric vibrato
    void setEmotionalState(float joy, float sorrow);  // Affects vibrato character
    void setHeartRateVariability(float hrv);          // Natural vibrato variation

    // Auto-divisi (intelligent section splitting)
    void enableAutoDivisi(bool enable);

    void prepare(double sampleRate, int samplesPerBlock);
    void processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midi);

private:
    // Karplus-Strong / Waveguide synthesis
    struct WaveguideString {
        std::vector<float> delayLine;
        int writePos = 0;
        float dampingCoeff = 0.998f;

        float pluck(float frequency);
        float bow(float pressure, float speed);
    };

    std::vector<WaveguideString> strings;

    // ML bow model
    struct MLBowModel {
        void predictBowParams(float velocity, float& pressure, float& speed);
    };

    MLBowModel mlBowModel;
};
