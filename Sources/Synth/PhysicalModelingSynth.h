#pragma once

#include <JuceHeader.h>
#include <vector>
#include <array>

/**
 * PhysicalModelingSynth - Real Physics Simulation
 *
 * Advanced physical modeling synthesizer using modal synthesis
 * and real-time physics solvers for authentic acoustic instruments.
 *
 * Features:
 * - Real-time physics simulation of acoustic instruments
 * - Modal synthesis (resonant modes)
 * - Multiple instrument types: strings, winds, membranes, plates, bars
 * - Material properties (wood, metal, glass, plastic, skin)
 * - Excitation modeling (pluck, bow, strike, blow, scrape)
 * - Resonator modeling (body, soundboard, tube, cavity)
 * - Real-time parameter morphing
 * - Bio-reactive material properties
 */
class PhysicalModelingSynth : public juce::Synthesiser
{
public:
    //==========================================================================
    // Instrument Types
    //==========================================================================

    enum class InstrumentType
    {
        // Strings
        PluckedString,      // Guitar, harp, pizzicato
        BowedString,        // Violin, cello
        StruckString,       // Piano, dulcimer

        // Winds
        Flute,              // Edge-tone instruments
        Reed,               // Clarinet, saxophone
        Brass,              // Trumpet, trombone

        // Membranes
        Drum,               // Tom, snare
        Timpani,            // Tuned membrane

        // Plates
        Cymbal,             // Crash, ride
        Gong,               // Large plate
        Bell,               // Church bell

        // Bars
        Marimba,            // Wooden bars
        Vibraphone,         // Metal bars
        Chimes              // Tubular bells
    };

    //==========================================================================
    // Material Properties
    //==========================================================================

    enum class Material
    {
        Wood,               // Warm, resonant
        Metal,              // Bright, long sustain
        Glass,              // Crystalline
        Plastic,            // Synthetic
        Nylon,              // Soft strings
        Steel,              // Bright strings
        Skin,               // Natural membrane
        Synthetic           // Synthetic membrane
    };

    //==========================================================================
    // Excitation Types
    //==========================================================================

    enum class Excitation
    {
        Pluck,              // Sudden displacement
        Bow,                // Continuous friction
        Strike,             // Impulse (hammer, mallet)
        Blow,               // Air pressure
        Scrape,             // Scratch, brush
        Pinch               // Harmonic excitation
    };

    //==========================================================================
    // Physical Parameters
    //==========================================================================

    struct StringParams
    {
        float length = 0.65f;           // meters
        float tension = 100.0f;         // Newtons
        float mass = 0.001f;            // kg/m
        float stiffness = 0.0001f;      // Bending stiffness
        float damping = 0.001f;         // Energy loss
        float inharmonicity = 0.0f;     // Stiffness-induced
    };

    struct WindParams
    {
        float tubeLength = 0.6f;        // meters
        float diameter = 0.02f;         // meters
        float pressure = 1000.0f;       // Pa
        float embouchureStiffness = 100.0f;
        float reedOpening = 0.5f;       // 0.0 to 1.0
    };

    struct MembraneParams
    {
        float diameter = 0.3f;          // meters
        float tension = 1000.0f;        // N/m
        float thickness = 0.001f;       // meters
        float damping = 0.01f;
    };

    struct PlateParams
    {
        float diameter = 0.4f;          // meters
        float thickness = 0.002f;       // meters
        float density = 7800.0f;        // kg/m³ (steel)
        float youngsModulus = 200e9f;   // Pa
        float damping = 0.001f;
    };

    struct BarParams
    {
        float length = 0.5f;            // meters
        float width = 0.05f;            // meters
        float thickness = 0.01f;        // meters
        float density = 1200.0f;        // kg/m³ (wood)
        float stiffness = 10e9f;        // Pa
    };

    //==========================================================================
    // Exciter Parameters
    //==========================================================================

    struct ExciterParams
    {
        Excitation type = Excitation::Pluck;

        // Pluck
        float pluckPosition = 0.1f;     // 0.0 to 1.0 (from bridge)
        float pluckForce = 0.5f;        // 0.0 to 1.0

        // Bow
        float bowPressure = 0.5f;       // 0.0 to 1.0
        float bowVelocity = 0.5f;       // 0.0 to 1.0
        float bowPosition = 0.1f;       // 0.0 to 1.0

        // Strike
        float strikePosition = 0.5f;    // 0.0 to 1.0
        float strikeHardness = 0.5f;    // Soft to hard mallet
        float strikeMass = 0.01f;       // kg

        // Blow
        float blowPressure = 0.5f;      // 0.0 to 1.0
        float blowTurbulence = 0.1f;    // Air noise
    };

    //==========================================================================
    // Resonator Parameters
    //==========================================================================

    struct ResonatorParams
    {
        bool enabled = true;

        enum class Type { Body, Soundboard, Tube, Cavity };
        Type type = Type::Body;

        float size = 0.5f;              // Volume/length
        float coupling = 0.5f;          // How much resonator affects sound
        int numModes = 8;               // Resonant modes
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    PhysicalModelingSynth();
    ~PhysicalModelingSynth() override = default;

    //==========================================================================
    // Instrument Configuration
    //==========================================================================

    void setInstrumentType(InstrumentType type);
    InstrumentType getInstrumentType() const { return instrumentType; }

    void setMaterial(Material material);
    Material getMaterial() const { return material; }

    //==========================================================================
    // Physical Parameters
    //==========================================================================

    StringParams& getStringParams() { return stringParams; }
    WindParams& getWindParams() { return windParams; }
    MembraneParams& getMembraneParams() { return membraneParams; }
    PlateParams& getPlateParams() { return plateParams; }
    BarParams& getBarParams() { return barParams; }

    //==========================================================================
    // Exciter & Resonator
    //==========================================================================

    ExciterParams& getExciterParams() { return exciterParams; }
    ResonatorParams& getResonatorParams() { return resonatorParams; }

    //==========================================================================
    // Bio-Reactive Control
    //==========================================================================

    void setBioReactiveEnabled(bool enabled);
    void setBioData(float hrv, float coherence, float breath);

    struct BioMapping
    {
        float hrvToTension = 0.5f;      // HRV affects string tension
        float coherenceToDamping = 0.5f; // Coherence affects damping
        float breathToPressure = 0.7f;  // Breath affects blow pressure
    };

    void setBioMapping(const BioMapping& mapping);

    //==========================================================================
    // Processing
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize);
    void reset();

    //==========================================================================
    // Visualization
    //==========================================================================

    /** Get current displacement of string/membrane/plate */
    std::vector<float> getDisplacementProfile() const;

    /** Get modal frequencies */
    std::vector<float> getModalFrequencies() const;

private:
    //==========================================================================
    // Voice Class
    //==========================================================================

    class PhysicalVoice : public juce::SynthesiserVoice
    {
    public:
        PhysicalVoice(PhysicalModelingSynth& parent);

        bool canPlaySound(juce::SynthesiserSound*) override { return true; }
        void startNote(int midiNoteNumber, float velocity,
                      juce::SynthesiserSound*, int currentPitchWheelPosition) override;
        void stopNote(float velocity, bool allowTailOff) override;
        void pitchWheelMoved(int newPitchWheelValue) override {}
        void controllerMoved(int controllerNumber, int newControllerValue) override {}
        void renderNextBlock(juce::AudioBuffer<float>& outputBuffer,
                            int startSample, int numSamples) override;

    private:
        PhysicalModelingSynth& synth;
        float baseFrequency = 440.0f;

        // Waveguide/modal synthesis state
        std::vector<float> delayLine;
        std::vector<float> modalAmplitudes;
        std::vector<float> modalFrequencies;
        std::vector<float> modalDecays;

        void simulatePhysics(float* output, int numSamples);
    };

    //==========================================================================
    // State
    //==========================================================================

    InstrumentType instrumentType = InstrumentType::PluckedString;
    Material material = Material::Nylon;

    StringParams stringParams;
    WindParams windParams;
    MembraneParams membraneParams;
    PlateParams plateParams;
    BarParams barParams;

    ExciterParams exciterParams;
    ResonatorParams resonatorParams;

    bool bioReactiveEnabled = false;
    BioMapping bioMapping;
    float bioHRV = 0.5f, bioCoherence = 0.5f, bioBreath = 0.5f;

    double currentSampleRate = 48000.0;

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (PhysicalModelingSynth)
};
