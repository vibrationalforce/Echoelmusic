#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <memory>

/**
 * RhythmMatrix
 *
 * Professional sample-based drum machine inspired by Akai MPC, Native Instruments
 * Maschine, Ableton Drum Rack. 16-pad sampler with intelligent features.
 *
 * Features:
 * - 16 sample pads
 * - Multi-layer velocity switching (up to 8 layers per pad)
 * - Round-robin sample playback
 * - Per-pad: pitch, filter, envelope, pan, send
 * - Choke groups
 * - Pad mute/solo
 * - Built-in effects per pad
 * - Slice mode (auto-slice audio files)
 * - Time-stretch and pitch-shift
 * - MIDI learn
 * - Bio-reactive pad triggering
 */
class RhythmMatrix
{
public:
    //==========================================================================
    // Pad Configuration
    //==========================================================================

    struct SampleLayer
    {
        juce::AudioBuffer<float> audioData;
        int velocityMin = 0;       // 0-127
        int velocityMax = 127;     // 0-127
        juce::String filePath;

        SampleLayer() = default;
    };

    struct Pad
    {
        bool enabled = true;
        juce::String name;
        std::vector<SampleLayer> layers;  // Velocity layers
        int currentRoundRobin = 0;

        // Playback
        bool oneShot = true;           // false = loop
        float startPoint = 0.0f;       // 0.0 to 1.0
        float endPoint = 1.0f;         // 0.0 to 1.0
        bool reverse = false;

        // Tuning
        float pitch = 0.0f;            // Semitones (-24 to +24)
        float fineTune = 0.0f;         // Cents (-100 to +100)

        // Envelope
        float attack = 0.001f;         // seconds
        float decay = 0.1f;            // seconds
        float sustain = 1.0f;          // 0.0 to 1.0
        float release = 0.1f;          // seconds

        // Filter
        bool filterEnabled = false;
        float filterCutoff = 5000.0f;  // Hz
        float filterResonance = 0.0f;  // 0.0 to 1.0

        // Mix
        float level = 1.0f;            // 0.0 to 1.0
        float pan = 0.5f;              // 0.0 (L) to 1.0 (R)
        float sendA = 0.0f;            // Send to effect A (0.0 to 1.0)
        float sendB = 0.0f;            // Send to effect B (0.0 to 1.0)

        // Choke
        int chokeGroup = 0;            // 0 = no choke, 1-8 = choke groups

        // Mute/Solo
        bool muted = false;
        bool soloed = false;

        Pad() = default;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    RhythmMatrix();
    ~RhythmMatrix() = default;

    //==========================================================================
    // Pad Management
    //==========================================================================

    /** Get number of pads */
    constexpr int getNumPads() const { return 16; }

    /** Get/Set pad configuration */
    Pad& getPad(int index);
    const Pad& getPad(int index) const;
    void setPad(int index, const Pad& pad);

    //==========================================================================
    // Sample Loading
    //==========================================================================

    /** Load sample into pad (auto-detect velocity layer) */
    bool loadSample(int padIndex, const juce::File& file);

    /** Load sample into specific velocity layer */
    bool loadSampleToLayer(int padIndex, int layerIndex, const juce::File& file,
                          int velocityMin, int velocityMax);

    /** Clear all samples from pad */
    void clearPad(int padIndex);

    /** Auto-slice audio file across multiple pads */
    void autoSlice(const juce::File& file, int numSlices, int startPad);

    //==========================================================================
    // Playback Control
    //==========================================================================

    /** Trigger pad with velocity */
    void triggerPad(int padIndex, float velocity);

    /** Stop pad */
    void stopPad(int padIndex);

    /** Stop all pads */
    void stopAll();

    /** Check if pad is currently playing */
    bool isPadPlaying(int padIndex) const;

    //==========================================================================
    // Mute/Solo
    //==========================================================================

    void setPadMuted(int padIndex, bool muted);
    void setPadSoloed(int padIndex, bool soloed);
    void clearAllSolo();

    //==========================================================================
    // Bio-Reactive Triggering
    //==========================================================================

    /** Set bio-data for reactive pad triggering */
    void setBioData(float hrv, float coherence);

    /** Enable/disable bio-reactive auto-triggering */
    void setBioReactiveTrigger(bool enabled);

    //==========================================================================
    // Processing
    //==========================================================================

    /** Prepare for playback */
    void prepare(double sampleRate, int maxBlockSize);

    /** Reset all voices */
    void reset();

    /** Process audio buffer */
    void process(juce::AudioBuffer<float>& buffer);

    //==========================================================================
    // Visualization
    //==========================================================================

    /** Get pad waveform data for display */
    std::vector<float> getPadWaveform(int padIndex) const;

    /** Get pad playback position (0.0 to 1.0) */
    float getPadPlaybackPosition(int padIndex) const;

private:
    //==========================================================================
    // Voice State
    //==========================================================================

    struct Voice
    {
        int padIndex = -1;
        int layerIndex = -1;
        bool active = false;

        // Playback
        double playbackPosition = 0.0;
        float velocity = 0.0f;

        // Envelope
        enum class EnvelopeStage { Attack, Decay, Sustain, Release, Off };
        EnvelopeStage envelopeStage = EnvelopeStage::Off;
        float envelopeValue = 0.0f;

        // Filter
        float filterZ1 = 0.0f, filterZ2 = 0.0f;

        Voice() = default;
    };

    //==========================================================================
    // Member Variables
    //==========================================================================

    std::array<Pad, 16> pads;
    std::vector<Voice> voices;  // Polyphonic voice pool

    double currentSampleRate = 48000.0;
    int maxVoices = 32;

    // Bio-reactive
    float bioHRV = 0.5f;
    float bioCoherence = 0.5f;
    bool bioReactiveTrigger = false;
    float bioTriggerPhase = 0.0f;

    // Solo state
    bool anySoloed = false;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    Voice* allocateVoice(int padIndex, float velocity);
    void processVoice(Voice& voice, juce::AudioBuffer<float>& buffer,
                     int startSample, int numSamples);

    float processSample(Voice& voice, int channel);
    void updateEnvelope(Voice& voice, const Pad& pad);
    float applyFilter(Voice& voice, const Pad& pad, float input);

    void handleChokeGroups(int padIndex);
    void updateBioReactiveTrigger();

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (RhythmMatrix)
};
