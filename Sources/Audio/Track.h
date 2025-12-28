#pragma once

#include <JuceHeader.h>
#include <atomic>

/**
 * Track - Audio or MIDI track
 *
 * Represents a single track in the project.
 * Can be Audio (waveform) or MIDI (notes).
 */
class Track
{
public:
    enum class Type
    {
        Audio,
        MIDI
    };

    //==========================================================================
    Track(Type trackType, const juce::String& trackName = "Track");
    ~Track();

    //==========================================================================
    // Configuration
    //==========================================================================

    void prepare(double sampleRate, int maximumBlockSize);
    void releaseResources();

    Type getType() const { return type; }
    juce::String getName() const { return name; }
    void setName(const juce::String& newName) { name = newName; }

    //==========================================================================
    // Transport
    //==========================================================================

    void setMuted(bool shouldBeMuted) { muted.store(shouldBeMuted); }
    bool isMuted() const { return muted.load(); }

    void setSoloed(bool shouldBeSoloed) { soloed.store(shouldBeSoloed); }
    bool isSoloed() const { return soloed.load(); }

    void setArmed(bool shouldBeArmed) { armed.store(shouldBeArmed); }
    bool isArmed() const { return armed.load(); }

    //==========================================================================
    // Mixing
    //==========================================================================

    void setVolume(float newVolume);
    float getVolume() const { return volume.load(); }

    void setPan(float newPan);
    float getPan() const { return pan.load(); }

    //==========================================================================
    // Audio Processing
    //==========================================================================

    /** Process this track's audio into the output buffer */
    void processBlock(juce::AudioBuffer<float>& outputBuffer, int numSamples);

    /** Record input into this track */
    void recordInput(const float* const* input, int numInputs, int numSamples, int64_t position);

    //==========================================================================
    // Audio Clips
    //==========================================================================

    /** Add audio clip from file */
    bool addAudioClip(const juce::File& audioFile, int64_t startPosition);

    /** Add audio clip from buffer */
    void addAudioClip(const juce::AudioBuffer<float>& buffer, int64_t startPosition);

    /** Get recorded audio buffer (for saving) */
    const juce::AudioBuffer<float>& getRecordedAudio() const { return recordedAudio; }

    //==========================================================================
    // MIDI Clips (for MIDI tracks)
    //==========================================================================

    /** Add MIDI note */
    void addMIDINote(int noteNumber, float velocity, int64_t startSample, int lengthSamples);

    /** Get MIDI sequence */
    juce::MidiBuffer& getMIDISequence() { return midiSequence; }
    const juce::MidiBuffer& getMIDISequence() const { return midiSequence; }

private:
    Type type;
    juce::String name;

    std::atomic<bool> muted { false };
    std::atomic<bool> soloed { false };
    std::atomic<bool> armed { false };

    std::atomic<float> volume { 1.0f };
    std::atomic<float> pan { 0.0f }; // -1.0 (left) to +1.0 (right)

    // OPTIMIZATION: Pre-cached pan gains (calculated in setPan, used in processBlock)
    std::atomic<float> cachedLeftGain { 0.707f };   // Default: center (cos(pi/4))
    std::atomic<float> cachedRightGain { 0.707f };  // Default: center (sin(pi/4))

    double currentSampleRate = 48000.0;
    int currentBlockSize = 512;

    // Audio data
    juce::AudioBuffer<float> playbackBuffer;  // Pre-loaded audio
    juce::AudioBuffer<float> recordedAudio;   // Currently recording
    int64_t recordingStartPosition = 0;

    // MIDI data
    juce::MidiBuffer midiSequence;

    // Plugin chain (VST3, AUv3, etc.) - implemented later
    // std::vector<std::unique_ptr<PluginInstance>> plugins;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(Track)
};
