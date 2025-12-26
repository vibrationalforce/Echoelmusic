#pragma once

#include <JuceHeader.h>
#include <array>

/**
 * Drum Synthesizer
 *
 * Classic analog drum synthesis inspired by Roland TR-808 and TR-909.
 * Generates drum sounds using oscillators, noise, and envelopes.
 *
 * Drum Types:
 * - Kick (808/909 style with pitch envelope, attack, decay, tone)
 * - Snare (body + noise, tuning, snap)
 * - Hi-Hat (metallic noise with envelope, open/closed)
 * - Tom (pitched oscillator with decay)
 * - Clap (filtered noise bursts)
 * - Cowbell (dual oscillator with metallic tone)
 * - Rim Shot (high-pitched click + decay)
 * - Cymbal (complex metallic noise)
 *
 * Features:
 * - Zero-latency synthesis
 * - Sample-accurate triggering
 * - Velocity sensitivity
 * - Individual outputs per voice
 * - Polyphony (multiple voices)
 */
class DrumSynthesizer
{
public:
    //==========================================================================
    // Drum Types
    //==========================================================================

    enum class DrumType
    {
        Kick,
        Snare,
        HiHatClosed,
        HiHatOpen,
        TomLow,
        TomMid,
        TomHigh,
        Clap,
        Cowbell,
        RimShot,
        Crash,
        Ride
    };

    //==========================================================================
    // Voice Parameters
    //==========================================================================

    struct VoiceParameters
    {
        DrumType drumType = DrumType::Kick;

        // Common parameters
        float pitch = 0.0f;           // -12 to +12 semitones
        float decay = 0.5f;           // 0-1
        float attack = 0.01f;         // 0-1
        float tone = 0.5f;            // 0-1 (brightness/filtering)
        float snap = 0.5f;            // 0-1 (transient punch)
        float level = 1.0f;           // 0-1

        // Kick-specific
        float kickPitchDecay = 0.5f;  // Pitch envelope amount

        // Hi-hat specific
        float hiHatDecay = 0.3f;      // Open hi-hat decay time

        // Snare-specific
        float snareNoise = 0.5f;      // Balance between body and noise

        bool enabled = true;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    DrumSynthesizer();
    ~DrumSynthesizer() = default;

    //==========================================================================
    // Voice Management
    //==========================================================================

    /** Trigger a drum voice with velocity (0.0 to 1.0) */
    void trigger(DrumType drumType, float velocity = 1.0f);

    /** Stop all voices */
    void stopAll();

    /** Set parameters for a drum type */
    void setParameters(DrumType drumType, const VoiceParameters& params);

    /** Get parameters for a drum type */
    VoiceParameters getParameters(DrumType drumType) const;

    //==========================================================================
    // Processing
    //==========================================================================

    /** Prepare for processing */
    void prepare(double sampleRate, int maxBlockSize);

    /** Reset all voices */
    void reset();

    /** Process and fill audio buffer (stereo mix) */
    void process(juce::AudioBuffer<float>& buffer);

    /** Process with individual outputs per drum (NEW) */
    void processIndividualOutputs(juce::AudioBuffer<float>& buffer);

    /** Get single sample (for inline processing) */
    float processSample();

    //==========================================================================
    // Individual Outputs (NEW: 12 stereo pairs = 24 channels)
    //==========================================================================

    void setIndividualOutputsEnabled(bool enabled);
    bool getIndividualOutputsEnabled() const { return individualOutputsEnabled; }

    /** Get output channel index for drum type (0-23) */
    int getOutputChannelForDrum(DrumType type) const;

    //==========================================================================
    // Preset System (NEW)
    //==========================================================================

    enum class Preset
    {
        Classic808,        // Roland TR-808 style
        Classic909,        // Roland TR-909 style
        ModernTrap,        // 808 with modern processing
        Acoustic,          // Acoustic drum kit emulation
        Electronic,        // Modern electronic kit
        LoFi,              // Lo-fi hip-hop kit
        Industrial,        // Harsh industrial sounds
        Minimal,           // Minimal techno kit
        DnB,               // Drum and bass kit
        Reggaeton,         // Dembow-style kit
        Custom             // User-defined
    };

    void loadPreset(Preset preset);
    void savePreset(const juce::File& file);
    bool loadPresetFromFile(const juce::File& file);

private:
    //==========================================================================
    // Voice State
    //==========================================================================

    struct Voice
    {
        bool active = false;
        DrumType drumType = DrumType::Kick;
        float velocity = 1.0f;

        // Envelope
        float envelope = 0.0f;
        float phase = 0.0f;

        // Oscillators
        float osc1Phase = 0.0f;
        float osc2Phase = 0.0f;

        // Pitch envelope (for kick)
        float pitchEnvelope = 0.0f;

        // Noise generator state
        float noiseState = 0.0f;

        // Filter state (for snare body, etc.)
        float filterX1 = 0.0f, filterX2 = 0.0f;
        float filterY1 = 0.0f, filterY2 = 0.0f;

        // Clap burst state
        int clapBurstCount = 0;
        int clapBurstTimer = 0;

        VoiceParameters params;
    };

    static constexpr int maxVoices = 16;
    std::array<Voice, maxVoices> voices;

    double currentSampleRate = 48000.0;

    // Individual outputs (NEW)
    bool individualOutputsEnabled = false;

    //==========================================================================
    // Parameter Storage
    //==========================================================================

    std::array<VoiceParameters, 12> drumParameters;  // One per DrumType

    //==========================================================================
    // Voice Synthesis
    //==========================================================================

    void initializeVoice(Voice& voice, DrumType drumType, float velocity);
    float synthesizeVoice(Voice& voice);

    // Specific drum synthesis functions
    float synthesizeKick(Voice& voice);
    float synthesizeSnare(Voice& voice);
    float synthesizeHiHat(Voice& voice, bool open);
    float synthesizeTom(Voice& voice);
    float synthesizeClap(Voice& voice);
    float synthesizeCowbell(Voice& voice);
    float synthesizeRimShot(Voice& voice);
    float synthesizeCymbal(Voice& voice, bool crash);

    // Utility functions
    float generateNoise();
    float applyBiquadFilter(float input, Voice& voice, float cutoff, float resonance);

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (DrumSynthesizer)
};
