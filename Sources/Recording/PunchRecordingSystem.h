#pragma once

#include <JuceHeader.h>
#include <vector>
#include <memory>
#include <atomic>

/**
 * PunchRecordingSystem - Professional Punch In/Out Recording
 *
 * Industry-standard punch recording features:
 * - Pre-roll and post-roll with configurable bars/beats
 * - Auto punch with precise in/out points
 * - Manual punch (on-the-fly recording)
 * - Loop recording with takes
 * - Seamless crossfades at punch points
 * - Quick punch (single key trigger)
 * - Destructive and non-destructive modes
 * - Pre-record buffer for catching early takes
 *
 * Inspired by: Pro Tools, Logic Pro, Cubase
 */

namespace Echoelmusic {
namespace Recording {

//==============================================================================
// Punch Region
//==============================================================================

struct PunchRegion
{
    double startBeat = 0.0;
    double endBeat = 4.0;

    double startSample = 0;
    double endSample = 0;

    bool enabled = true;

    // Crossfade settings
    int crossfadeInSamples = 512;
    int crossfadeOutSamples = 512;

    void calculateSamples(double sampleRate, double bpm)
    {
        double samplesPerBeat = sampleRate * 60.0 / bpm;
        startSample = startBeat * samplesPerBeat;
        endSample = endBeat * samplesPerBeat;
    }
};

//==============================================================================
// Recording Take
//==============================================================================

struct RecordingTake
{
    juce::AudioBuffer<float> audio;
    double startSample = 0;
    double endSample = 0;

    juce::String name;
    juce::Time timestamp;
    int takeNumber = 1;

    bool isFavorite = false;
    int rating = 0;  // 1-5 stars

    // Metadata
    float peakLevel = 0.0f;
    bool hasClipping = false;

    RecordingTake()
    {
        timestamp = juce::Time::getCurrentTime();
    }
};

//==============================================================================
// Punch Recording Mode
//==============================================================================

enum class PunchMode
{
    Off,                // No punch recording
    AutoPunch,          // Record between punch in/out points
    ManualPunch,        // Record when manually triggered
    LoopPunch,          // Record multiple takes in loop
    QuickPunch          // Single key punch in/out
};

//==============================================================================
// Punch Recording System
//==============================================================================

class PunchRecordingSystem
{
public:
    //==========================================================================
    // Constructor
    //==========================================================================

    PunchRecordingSystem()
    {
        preRecordBuffer.setSize(2, preRecordBufferSize);
    }

    //==========================================================================
    // Preparation
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize, int numChannels)
    {
        currentSampleRate = sampleRate;
        this->maxBlockSize = maxBlockSize;
        this->numChannels = numChannels;

        // Resize buffers
        preRecordBuffer.setSize(numChannels, preRecordBufferSize);
        preRecordBuffer.clear();

        recordingBuffer.setSize(numChannels, static_cast<int>(sampleRate * 600));  // 10 min max
        recordingBuffer.clear();

        // Recalculate punch points
        punchRegion.calculateSamples(sampleRate, currentBPM);

        prepared = true;
    }

    //==========================================================================
    // Punch Region Configuration
    //==========================================================================

    void setPunchInPoint(double beat)
    {
        punchRegion.startBeat = beat;
        punchRegion.calculateSamples(currentSampleRate, currentBPM);
    }

    void setPunchOutPoint(double beat)
    {
        punchRegion.endBeat = beat;
        punchRegion.calculateSamples(currentSampleRate, currentBPM);
    }

    void setPunchRegion(double inBeat, double outBeat)
    {
        punchRegion.startBeat = inBeat;
        punchRegion.endBeat = outBeat;
        punchRegion.calculateSamples(currentSampleRate, currentBPM);
    }

    void setPunchEnabled(bool enabled)
    {
        punchRegion.enabled = enabled;
    }

    const PunchRegion& getPunchRegion() const { return punchRegion; }

    //==========================================================================
    // Pre/Post Roll
    //==========================================================================

    void setPreRoll(double beats)
    {
        preRollBeats = beats;
    }

    void setPostRoll(double beats)
    {
        postRollBeats = beats;
    }

    double getPreRollBeats() const { return preRollBeats; }
    double getPostRollBeats() const { return postRollBeats; }

    /** Get the playback start position including pre-roll */
    double getPlaybackStartBeat() const
    {
        return punchRegion.startBeat - preRollBeats;
    }

    //==========================================================================
    // Mode Configuration
    //==========================================================================

    void setPunchMode(PunchMode mode)
    {
        punchMode = mode;
    }

    PunchMode getPunchMode() const { return punchMode; }

    //==========================================================================
    // Crossfade Settings
    //==========================================================================

    void setCrossfadeLength(int samples)
    {
        punchRegion.crossfadeInSamples = samples;
        punchRegion.crossfadeOutSamples = samples;
    }

    void setCrossfadeLengthMs(float ms)
    {
        int samples = static_cast<int>(ms * currentSampleRate / 1000.0);
        setCrossfadeLength(samples);
    }

    //==========================================================================
    // Recording Control
    //==========================================================================

    /** Start recording (arm the track) */
    void arm()
    {
        isArmed = true;
        recordingWritePos = 0;
        recordingBuffer.clear();
    }

    /** Disarm recording */
    void disarm()
    {
        isArmed = false;

        // Finalize current take if recording
        if (isRecording)
            finalizeTake();
    }

    /** Manual punch in */
    void punchIn()
    {
        if (!isArmed || punchMode == PunchMode::Off)
            return;

        isRecording = true;
        recordingStartSample = currentPlayheadSample;
        recordingWritePos = 0;

        // Include pre-record buffer content
        includePreRecordBuffer();

        if (onPunchIn)
            onPunchIn();
    }

    /** Manual punch out */
    void punchOut()
    {
        if (!isRecording)
            return;

        isRecording = false;
        finalizeTake();

        if (onPunchOut)
            onPunchOut();
    }

    /** Quick punch toggle */
    void togglePunch()
    {
        if (isRecording)
            punchOut();
        else
            punchIn();
    }

    /** Check if currently recording */
    bool getIsRecording() const { return isRecording; }

    /** Check if armed */
    bool getIsArmed() const { return isArmed; }

    //==========================================================================
    // Audio Processing
    //==========================================================================

    void processBlock(const juce::AudioBuffer<float>& inputBuffer,
                      juce::AudioBuffer<float>& outputBuffer,
                      double playheadSample)
    {
        if (!prepared)
            return;

        currentPlayheadSample = playheadSample;
        int numSamples = inputBuffer.getNumSamples();

        // Always update pre-record buffer (circular)
        updatePreRecordBuffer(inputBuffer);

        // Auto-punch logic
        if (punchMode == PunchMode::AutoPunch && isArmed)
        {
            for (int i = 0; i < numSamples; ++i)
            {
                double samplePos = playheadSample + i;

                // Check punch in
                if (!isRecording && samplePos >= punchRegion.startSample)
                {
                    isRecording = true;
                    recordingStartSample = samplePos;
                    recordingWritePos = 0;

                    if (onPunchIn)
                        onPunchIn();
                }

                // Check punch out
                if (isRecording && samplePos >= punchRegion.endSample)
                {
                    isRecording = false;
                    finalizeTake();

                    if (onPunchOut)
                        onPunchOut();
                }
            }
        }

        // Record audio if recording
        if (isRecording)
        {
            recordAudio(inputBuffer);
        }

        // Metering
        updateMetering(inputBuffer);
    }

    //==========================================================================
    // Take Management
    //==========================================================================

    int getNumTakes() const { return static_cast<int>(takes.size()); }

    const RecordingTake* getTake(int index) const
    {
        if (index >= 0 && index < static_cast<int>(takes.size()))
            return &takes[index];
        return nullptr;
    }

    RecordingTake* getTake(int index)
    {
        if (index >= 0 && index < static_cast<int>(takes.size()))
            return &takes[index];
        return nullptr;
    }

    void deleteTake(int index)
    {
        if (index >= 0 && index < static_cast<int>(takes.size()))
            takes.erase(takes.begin() + index);
    }

    void clearAllTakes()
    {
        takes.clear();
        currentTakeNumber = 1;
    }

    /** Set take as favorite */
    void setTakeFavorite(int index, bool favorite)
    {
        if (index >= 0 && index < static_cast<int>(takes.size()))
            takes[index].isFavorite = favorite;
    }

    /** Rate a take */
    void rateTake(int index, int rating)
    {
        if (index >= 0 && index < static_cast<int>(takes.size()))
            takes[index].rating = juce::jlimit(0, 5, rating);
    }

    //==========================================================================
    // Loop Recording
    //==========================================================================

    void setLoopEnabled(bool enabled)
    {
        loopEnabled = enabled;
    }

    void setLoopRegion(double startBeat, double endBeat)
    {
        loopStartBeat = startBeat;
        loopEndBeat = endBeat;
    }

    /** Called when loop wraps - auto creates new take */
    void onLoopWrap()
    {
        if (punchMode == PunchMode::LoopPunch && isRecording)
        {
            finalizeTake();
            recordingWritePos = 0;
            recordingBuffer.clear();
        }
    }

    //==========================================================================
    // Pre-Record Buffer
    //==========================================================================

    void setPreRecordTime(float seconds)
    {
        preRecordBufferSize = static_cast<int>(seconds * currentSampleRate);
        preRecordBuffer.setSize(numChannels, preRecordBufferSize);
        preRecordBuffer.clear();
        preRecordWritePos = 0;
    }

    float getPreRecordTime() const
    {
        return preRecordBufferSize / static_cast<float>(currentSampleRate);
    }

    //==========================================================================
    // Tempo Sync
    //==========================================================================

    void setTempo(double bpm)
    {
        currentBPM = bpm;
        punchRegion.calculateSamples(currentSampleRate, bpm);
    }

    void setTimeSignature(int numerator, int denominator)
    {
        timeSignatureNum = numerator;
        timeSignatureDenom = denominator;
    }

    //==========================================================================
    // Metering
    //==========================================================================

    float getInputLevel() const { return inputLevel.load(); }
    float getPeakLevel() const { return peakLevel.load(); }
    bool getIsClipping() const { return isClipping.load(); }

    void resetPeakHold()
    {
        peakLevel = 0.0f;
        isClipping = false;
    }

    //==========================================================================
    // Count-In
    //==========================================================================

    void setCountInEnabled(bool enabled)
    {
        countInEnabled = enabled;
    }

    void setCountInBars(int bars)
    {
        countInBars = bars;
    }

    bool isInCountIn() const { return inCountIn; }

    int getCurrentCountInBeat() const { return currentCountInBeat; }

    //==========================================================================
    // Callbacks
    //==========================================================================

    std::function<void()> onPunchIn;
    std::function<void()> onPunchOut;
    std::function<void(int takeIndex)> onTakeCreated;
    std::function<void(int beat)> onCountInBeat;

    //==========================================================================
    // Apply Take to Track
    //==========================================================================

    /** Apply a take to an audio buffer with crossfades */
    void applyTakeToBuffer(int takeIndex,
                           juce::AudioBuffer<float>& destinationBuffer,
                           int destinationOffset)
    {
        if (takeIndex < 0 || takeIndex >= static_cast<int>(takes.size()))
            return;

        const auto& take = takes[takeIndex];
        int numSamples = take.audio.getNumSamples();
        int numChannelsToCopy = std::min(take.audio.getNumChannels(),
                                         destinationBuffer.getNumChannels());

        // Apply with crossfades
        for (int ch = 0; ch < numChannelsToCopy; ++ch)
        {
            for (int i = 0; i < numSamples; ++i)
            {
                int destPos = destinationOffset + i;
                if (destPos < 0 || destPos >= destinationBuffer.getNumSamples())
                    continue;

                float sample = take.audio.getSample(ch, i);

                // Crossfade in
                if (i < punchRegion.crossfadeInSamples)
                {
                    float fade = static_cast<float>(i) / punchRegion.crossfadeInSamples;
                    fade = fade * fade * (3.0f - 2.0f * fade);  // Smooth curve

                    float existing = destinationBuffer.getSample(ch, destPos);
                    sample = existing * (1.0f - fade) + sample * fade;
                }

                // Crossfade out
                int samplesFromEnd = numSamples - i - 1;
                if (samplesFromEnd < punchRegion.crossfadeOutSamples)
                {
                    float fade = static_cast<float>(samplesFromEnd) / punchRegion.crossfadeOutSamples;
                    fade = fade * fade * (3.0f - 2.0f * fade);

                    float existing = destinationBuffer.getSample(ch, destPos);
                    sample = sample * fade + existing * (1.0f - fade);
                }

                destinationBuffer.setSample(ch, destPos, sample);
            }
        }
    }

private:
    //==========================================================================
    // Member Variables
    //==========================================================================

    bool prepared = false;
    double currentSampleRate = 48000.0;
    int maxBlockSize = 512;
    int numChannels = 2;

    // Punch settings
    PunchMode punchMode = PunchMode::Off;
    PunchRegion punchRegion;
    double preRollBeats = 2.0;
    double postRollBeats = 1.0;

    // Recording state
    bool isArmed = false;
    bool isRecording = false;
    double recordingStartSample = 0;
    int recordingWritePos = 0;

    // Buffers
    juce::AudioBuffer<float> recordingBuffer;
    juce::AudioBuffer<float> preRecordBuffer;
    int preRecordBufferSize = 48000;  // 1 second default
    int preRecordWritePos = 0;

    // Takes
    std::vector<RecordingTake> takes;
    int currentTakeNumber = 1;

    // Transport
    double currentPlayheadSample = 0;
    double currentBPM = 120.0;
    int timeSignatureNum = 4;
    int timeSignatureDenom = 4;

    // Loop
    bool loopEnabled = false;
    double loopStartBeat = 0.0;
    double loopEndBeat = 4.0;

    // Count-in
    bool countInEnabled = false;
    int countInBars = 1;
    bool inCountIn = false;
    int currentCountInBeat = 0;

    // Metering
    std::atomic<float> inputLevel { 0.0f };
    std::atomic<float> peakLevel { 0.0f };
    std::atomic<bool> isClipping { false };

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void updatePreRecordBuffer(const juce::AudioBuffer<float>& input)
    {
        int numSamples = input.getNumSamples();
        int channelsToCopy = std::min(input.getNumChannels(), preRecordBuffer.getNumChannels());

        for (int i = 0; i < numSamples; ++i)
        {
            for (int ch = 0; ch < channelsToCopy; ++ch)
            {
                preRecordBuffer.setSample(ch, preRecordWritePos, input.getSample(ch, i));
            }
            preRecordWritePos = (preRecordWritePos + 1) % preRecordBufferSize;
        }
    }

    void includePreRecordBuffer()
    {
        // Copy pre-record buffer to start of recording
        int channelsToCopy = std::min(preRecordBuffer.getNumChannels(),
                                      recordingBuffer.getNumChannels());

        for (int i = 0; i < preRecordBufferSize; ++i)
        {
            int readPos = (preRecordWritePos + i) % preRecordBufferSize;
            for (int ch = 0; ch < channelsToCopy; ++ch)
            {
                recordingBuffer.setSample(ch, i, preRecordBuffer.getSample(ch, readPos));
            }
        }

        recordingWritePos = preRecordBufferSize;
    }

    void recordAudio(const juce::AudioBuffer<float>& input)
    {
        int numSamples = input.getNumSamples();
        int channelsToCopy = std::min(input.getNumChannels(), recordingBuffer.getNumChannels());

        // Check buffer space
        if (recordingWritePos + numSamples > recordingBuffer.getNumSamples())
        {
            // Buffer full - could expand or stop
            return;
        }

        for (int ch = 0; ch < channelsToCopy; ++ch)
        {
            recordingBuffer.copyFrom(ch, recordingWritePos, input, ch, 0, numSamples);
        }

        recordingWritePos += numSamples;
    }

    void finalizeTake()
    {
        if (recordingWritePos == 0)
            return;

        RecordingTake take;
        take.audio.setSize(recordingBuffer.getNumChannels(), recordingWritePos);

        for (int ch = 0; ch < recordingBuffer.getNumChannels(); ++ch)
        {
            take.audio.copyFrom(ch, 0, recordingBuffer, ch, 0, recordingWritePos);
        }

        take.startSample = recordingStartSample;
        take.endSample = recordingStartSample + recordingWritePos;
        take.takeNumber = currentTakeNumber++;
        take.name = "Take " + juce::String(take.takeNumber);

        // Analyze take
        take.peakLevel = take.audio.getMagnitude(0, take.audio.getNumSamples());
        take.hasClipping = take.peakLevel > 0.99f;

        takes.push_back(std::move(take));

        if (onTakeCreated)
            onTakeCreated(static_cast<int>(takes.size()) - 1);

        // Reset for next recording
        recordingWritePos = 0;
        recordingBuffer.clear();
    }

    void updateMetering(const juce::AudioBuffer<float>& input)
    {
        float level = input.getMagnitude(0, input.getNumSamples());
        inputLevel = level;

        if (level > peakLevel)
            peakLevel = level;

        if (level > 0.99f)
            isClipping = true;
    }

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(PunchRecordingSystem)
};

} // namespace Recording
} // namespace Echoelmusic
