#pragma once

#include <JuceHeader.h>
#include <vector>
#include <map>
#include <random>

/**
 * PROCEDURAL SAMPLE SYNTHESIZER - Die Revolution!
 *
 * Statt 1.2GB Samples herunterzuladen → < 10MB Code für prozedural generierte Samples
 *
 * VORTEILE:
 * - 99.2% kleiner (1.2GB → < 10MB)
 * - Vollständig parametrisch
 * - Keine Copyright-Probleme
 * - Infinite Variationen
 * - Perfekt für Echoelmusic Signature
 * - Zur Laufzeit generiert
 *
 * SYNTHESIZER ENGINES:
 * 1. Drum Synthesis (Kicks, Snares, Hihats, etc.)
 * 2. Bass Synthesis (808, Sub, Reese, FM)
 * 3. Melodic Synthesis (Wavetables, Pads, Leads)
 * 4. Texture Synthesis (Atmospheres, Noise, Vinyl)
 * 5. Vocal Synthesis (Formant-based)
 * 6. FX Synthesis (Impacts, Risers, Sweeps)
 *
 * Usage:
 * ```cpp
 * ProceduralSampleSynthesizer synth;
 * synth.initialize(44100.0);
 *
 * // Generate kick drum
 * auto kick = synth.generateKick(60.0f, 0.8f); // 60Hz, 0.8 punch
 *
 * // Generate 808 bass
 * auto bass808 = synth.generate808Bass(55.0f, 0.5f, 2.0f); // A1, decay, drive
 *
 * // Generate pad
 * auto pad = synth.generatePad(440.0f, 0.3f, "warm"); // A4, brightness, character
 * ```
 */

//==============================================================================
// Synthesis Parameters
//==============================================================================

struct DrumSynthParams
{
    // Kick
    struct Kick {
        float pitch = 60.0f;        // Hz
        float punch = 0.8f;         // 0-1
        float decay = 0.5f;         // seconds
        float click = 0.3f;         // 0-1
        float distortion = 0.2f;    // 0-1
    } kick;

    // Snare
    struct Snare {
        float pitch = 200.0f;       // Hz
        float tone = 0.5f;          // 0-1
        float snap = 0.7f;          // 0-1
        float noise = 0.6f;         // 0-1
        float decay = 0.2f;         // seconds
    } snare;

    // Hihat
    struct Hihat {
        float brightness = 0.7f;    // 0-1
        float decay = 0.1f;         // seconds
        bool closed = true;
        float metallic = 0.5f;      // 0-1
    } hihat;

    // Percussion
    struct Percussion {
        float pitch = 300.0f;
        float decay = 0.15f;
        float tone = 0.5f;
    } percussion;
};

struct BassSynthParams
{
    // 808 Bass
    struct Bass808 {
        float pitch = 55.0f;        // Hz (A1)
        float decay = 0.5f;         // seconds
        float drive = 2.0f;         // 0-5
        float tone = 0.5f;          // 0-1
        float glide = 0.0f;         // seconds
    } bass808;

    // Sub Bass
    struct SubBass {
        float pitch = 55.0f;
        float wave = 0.0f;          // 0=sine, 1=triangle
        float stereo = 0.0f;        // 0-1
    } subBass;

    // Reese Bass
    struct ReeseBass {
        float pitch = 55.0f;
        float detune = 0.1f;        // cents
        float voices = 7;           // 2-12
        float spread = 0.5f;        // 0-1
        float filter = 0.6f;        // 0-1
    } reeseBass;

    // FM Bass
    struct FMBass {
        float pitch = 55.0f;
        float modAmount = 2.0f;     // 0-10
        float modRatio = 1.5f;      // 0.5-8
        float brightness = 0.5f;
    } fmBass;
};

struct MelodicSynthParams
{
    // Wavetable
    struct Wavetable {
        float pitch = 440.0f;
        int waveform = 0;           // 0=saw, 1=square, 2=triangle, 3=sine
        float detune = 0.05f;       // cents
        int voices = 3;             // 1-8
        float spread = 0.3f;
    } wavetable;

    // Pad
    struct Pad {
        float pitch = 440.0f;
        float brightness = 0.3f;
        juce::String character = "warm";  // warm, bright, dark, ethereal
        float movement = 0.2f;      // 0-1 (LFO intensity)
        float stereo = 0.5f;
    } pad;

    // Lead
    struct Lead {
        float pitch = 440.0f;
        float hardness = 0.7f;      // 0-1
        float resonance = 0.5f;
        float portamento = 0.0f;    // seconds
    } lead;
};

//==============================================================================
// Procedural Sample Synthesizer
//==============================================================================

class ProceduralSampleSynthesizer
{
public:
    ProceduralSampleSynthesizer();
    ~ProceduralSampleSynthesizer();

    //==============================================================================
    // Initialization
    //==============================================================================

    void initialize(double sampleRate);
    void setSampleRate(double sampleRate);

    //==============================================================================
    // DRUM SYNTHESIS
    //==============================================================================

    /** Generate kick drum */
    juce::AudioBuffer<float> generateKick(
        float pitchHz = 60.0f,
        float punch = 0.8f,
        float decay = 0.5f,
        float click = 0.3f,
        float distortion = 0.2f
    );

    /** Generate snare drum */
    juce::AudioBuffer<float> generateSnare(
        float pitchHz = 200.0f,
        float tone = 0.5f,
        float snap = 0.7f,
        float noise = 0.6f,
        float decay = 0.2f
    );

    /** Generate hihat */
    juce::AudioBuffer<float> generateHihat(
        float brightness = 0.7f,
        float decay = 0.1f,
        bool closed = true,
        float metallic = 0.5f
    );

    /** Generate clap */
    juce::AudioBuffer<float> generateClap(
        float brightness = 0.6f,
        float decay = 0.15f,
        int layers = 3
    );

    /** Generate tom */
    juce::AudioBuffer<float> generateTom(
        float pitchHz = 100.0f,
        float decay = 0.3f,
        float tone = 0.5f
    );

    /** Generate cymbal */
    juce::AudioBuffer<float> generateCymbal(
        float brightness = 0.8f,
        float decay = 1.5f,
        bool crash = false
    );

    //==============================================================================
    // BASS SYNTHESIS
    //==============================================================================

    /** Generate 808 bass */
    juce::AudioBuffer<float> generate808Bass(
        float pitchHz = 55.0f,
        float decay = 0.5f,
        float drive = 2.0f,
        float tone = 0.5f
    );

    /** Generate sub bass */
    juce::AudioBuffer<float> generateSubBass(
        float pitchHz = 55.0f,
        float wave = 0.0f,      // 0=sine, 1=triangle
        float duration = 1.0f
    );

    /** Generate Reese bass */
    juce::AudioBuffer<float> generateReeseBass(
        float pitchHz = 55.0f,
        float detune = 0.1f,
        int voices = 7,
        float spread = 0.5f,
        float duration = 1.0f
    );

    /** Generate FM bass */
    juce::AudioBuffer<float> generateFMBass(
        float pitchHz = 55.0f,
        float modAmount = 2.0f,
        float modRatio = 1.5f,
        float duration = 1.0f
    );

    //==============================================================================
    // MELODIC SYNTHESIS
    //==============================================================================

    /** Generate wavetable oscillator */
    juce::AudioBuffer<float> generateWavetable(
        float pitchHz = 440.0f,
        int waveform = 0,       // 0=saw, 1=square, 2=tri, 3=sine
        float detune = 0.05f,
        int voices = 3,
        float duration = 1.0f
    );

    /** Generate pad sound */
    juce::AudioBuffer<float> generatePad(
        float pitchHz = 440.0f,
        float brightness = 0.3f,
        const juce::String& character = "warm",
        float duration = 4.0f
    );

    /** Generate lead sound */
    juce::AudioBuffer<float> generateLead(
        float pitchHz = 440.0f,
        float hardness = 0.7f,
        float resonance = 0.5f,
        float duration = 1.0f
    );

    //==============================================================================
    // TEXTURE SYNTHESIS
    //==============================================================================

    /** Generate atmospheric texture */
    juce::AudioBuffer<float> generateAtmosphere(
        float brightness = 0.3f,
        float movement = 0.2f,
        float duration = 8.0f
    );

    /** Generate noise texture */
    juce::AudioBuffer<float> generateNoise(
        float color = 0.5f,     // 0=white, 0.5=pink, 1=brown
        float duration = 1.0f
    );

    /** Generate vinyl crackle */
    juce::AudioBuffer<float> generateVinylCrackle(
        float intensity = 0.3f,
        float duration = 1.0f
    );

    //==============================================================================
    // FX SYNTHESIS
    //==============================================================================

    /** Generate impact/hit */
    juce::AudioBuffer<float> generateImpact(
        float power = 0.8f,
        float duration = 0.5f
    );

    /** Generate riser */
    juce::AudioBuffer<float> generateRiser(
        float startPitch = 100.0f,
        float endPitch = 2000.0f,
        float duration = 2.0f
    );

    /** Generate sweep */
    juce::AudioBuffer<float> generateSweep(
        float startFreq = 20.0f,
        float endFreq = 20000.0f,
        float duration = 1.0f
    );

    //==============================================================================
    // ECHOELMUSIC SIGNATURE PRESETS
    //==============================================================================

    /** Generate signature kick (optimiert für Echoelmusic) */
    juce::AudioBuffer<float> generateSignatureKick(int variation = 0);

    /** Generate signature bass */
    juce::AudioBuffer<float> generateSignatureBass(int variation = 0);

    /** Generate signature pad */
    juce::AudioBuffer<float> generateSignaturePad(int variation = 0);

    //==============================================================================
    // Utilities
    //==============================================================================

    /** Get total size of all generated samples in memory */
    size_t getTotalSizeBytes() const;

    /** Clear all cached samples */
    void clearCache();

private:
    //==============================================================================
    // DSP Helpers
    //==============================================================================

    float generateWaveform(float phase, int waveform);
    float applyEnvelope(float sample, float time, float attack, float decay, float sustain, float release);
    float applyFilter(float sample, float cutoff, float resonance);
    float applyDistortion(float sample, float amount);

    // Oscillators
    float sineWave(float phase);
    float sawWave(float phase);
    float squareWave(float phase);
    float triangleWave(float phase);

    // Noise generators
    float whiteNoise();
    float pinkNoise();
    float brownNoise();

    //==============================================================================
    // State
    //==============================================================================

    double currentSampleRate = 44100.0;
    std::mt19937 randomGen;
    std::uniform_real_distribution<float> randomDist{-1.0f, 1.0f};

    // Cache for generated samples
    std::map<juce::String, juce::AudioBuffer<float>> sampleCache;

    // Pink noise filter state
    float pinkNoiseB0 = 0.0f, pinkNoiseB1 = 0.0f, pinkNoiseB2 = 0.0f;
    float pinkNoiseB3 = 0.0f, pinkNoiseB4 = 0.0f, pinkNoiseB5 = 0.0f, pinkNoiseB6 = 0.0f;

    // Brown noise state
    float brownNoiseLast = 0.0f;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ProceduralSampleSynthesizer)
};
