#pragma once

#include <JuceHeader.h>
#include <atomic>
#include <memory>
#include <vector>

/**
 * AudioEngine - Core audio engine for Echoelmusic
 *
 * Cross-platform audio engine (Desktop + iOS).
 * Handles multi-track recording, playback, routing, and mixing.
 *
 * Real-time safe: No allocations, locks, or blocking calls in audio thread.
 */
class AudioEngine : public juce::AudioIODeviceCallback
{
public:
    //==========================================================================
    AudioEngine();
    ~AudioEngine() override;

    //==========================================================================
    // Setup & Configuration
    //==========================================================================

    /** Prepare for playback (called before audio starts) */
    void prepare(double sampleRate, int maximumBlockSize);

    /** Release resources */
    void releaseResources();

    /** Get current sample rate */
    double getSampleRate() const { return currentSampleRate; }

    /** Get current block size */
    int getBlockSize() const { return currentBlockSize; }

    //==========================================================================
    // Transport Control
    //==========================================================================

    /** Start playback */
    void play();

    /** Stop playback */
    void stop();

    /** Check if playing */
    bool isPlaying() const { return playing.load(); }

    /** Set playback position (in samples) */
    void setPosition(int64_t positionInSamples);

    /** Get playback position (in samples) */
    int64_t getPosition() const { return playheadPosition.load(); }

    /** Set loop region */
    void setLoopRegion(int64_t startSample, int64_t endSample);

    /** Enable/disable looping */
    void setLooping(bool shouldLoop);

    //==========================================================================
    // Tempo & Time Signature
    //==========================================================================

    /** Set tempo (BPM) */
    void setTempo(double bpm);

    /** Get current tempo */
    double getTempo() const { return currentTempo.load(); }

    /** Set time signature */
    void setTimeSignature(int numerator, int denominator);

    /** Get time signature */
    void getTimeSignature(int& numerator, int& denominator) const;

    //==========================================================================
    // Track Management
    //==========================================================================

    /** Add audio track */
    int addAudioTrack(const juce::String& name = "Audio");

    /** Add MIDI track */
    int addMIDITrack(const juce::String& name = "MIDI");

    /** Remove track */
    void removeTrack(int trackIndex);

    /** Get number of tracks */
    int getNumTracks() const;

    /** Get track at index */
    class Track* getTrack(int index) const;

    //==========================================================================
    // Recording
    //==========================================================================

    /** Arm track for recording */
    void armTrack(int trackIndex, bool armed);

    /** Check if track is armed */
    bool isTrackArmed(int trackIndex) const;

    /** Start recording on armed tracks */
    void startRecording();

    /** Stop recording */
    void stopRecording();

    /** Check if recording */
    bool isRecording() const { return recording.load(); }

    //==========================================================================
    // Master Bus
    //==========================================================================

    /** Get master output level (LUFS, for metering) */
    float getMasterLevelLUFS() const;

    /** Get master peak level (dBFS) */
    float getMasterPeakLevel() const;

    /** Set master volume (0.0 to 1.0) */
    void setMasterVolume(float volume);

    /** Get master volume */
    float getMasterVolume() const { return masterVolume.load(); }

    //==========================================================================
    // Sync Integration
    //==========================================================================

    /** Set external sync source (EchoelSync, Ableton Link, etc.) */
    void setSyncEnabled(bool enabled);

    /** Set sync tempo callback (called from sync engine) */
    void setSyncTempoCallback(std::function<double()> callback);

    /** Set sync transport callback */
    void setSyncTransportCallback(std::function<bool()> isPlayingCallback);

    //==========================================================================
    // AudioIODeviceCallback Implementation
    //==========================================================================

    void audioDeviceIOCallbackWithContext(const float* const* inputChannelData,
                                         int numInputChannels,
                                         float* const* outputChannelData,
                                         int numOutputChannels,
                                         int numSamples,
                                         const juce::AudioIODeviceCallbackContext& context) override;

    void audioDeviceAboutToStart(juce::AudioIODevice* device) override;
    void audioDeviceStopped() override;

private:
    //==========================================================================
    // Internal State
    //==========================================================================

    double currentSampleRate = 48000.0;
    int currentBlockSize = 512;

    std::atomic<bool> playing { false };
    std::atomic<bool> recording { false };
    std::atomic<int64_t> playheadPosition { 0 };

    std::atomic<double> currentTempo { 120.0 };
    int timeSignatureNumerator = 4;
    int timeSignatureDenominator = 4;

    bool looping = false;
    int64_t loopStart = 0;
    int64_t loopEnd = 0;

    std::atomic<float> masterVolume { 1.0f };
    std::atomic<float> masterPeakLeft { 0.0f };
    std::atomic<float> masterPeakRight { 0.0f };

    // Tracks (use lock-free structure for real-time safety)
    std::vector<std::unique_ptr<class Track>> tracks;
    juce::CriticalSection tracksLock; // Only for add/remove, not in audio thread

    // Master bus buffers (pre-allocated)
    juce::AudioBuffer<float> masterBuffer;
    juce::AudioBuffer<float> recordBuffer;

    // Sync callbacks
    bool syncEnabled = false;
    std::function<double()> syncTempoCallback;
    std::function<bool()> syncTransportCallback;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void processAudioBlock(const float* const* input, float* const* output,
                          int numInputs, int numOutputs, int numSamples);

    void mixTracksToMaster(int numSamples);
    void recordInputToTracks(const float* const* input, int numInputs, int numSamples);
    void updatePlayhead(int numSamples);
    void updateMetering(const float* const* output, int numOutputs, int numSamples);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(AudioEngine)
};
