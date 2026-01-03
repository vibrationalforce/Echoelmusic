#pragma once

#include <JuceHeader.h>
#include <vector>
#include <memory>
#include <atomic>

/**
 * InputMonitoringStrip - Professional Input Channel Strip
 *
 * Complete input monitoring section with:
 * - Input gain staging with metering
 * - Low-latency monitoring path
 * - Insert effects (pre/post)
 * - Cue mix sends with independent level
 * - Talkback integration
 * - Phase invert and polarity
 * - Hardware input selection
 * - Direct monitoring toggle
 *
 * Inspired by: Universal Audio Console, SSL, API
 */

namespace Echoelmusic {
namespace Recording {

//==============================================================================
// Input Source
//==============================================================================

struct InputSource
{
    juce::String name;
    int hardwareInputIndex = 0;
    bool isStereo = false;
    int leftChannel = 0;
    int rightChannel = 1;

    // Phantom power (for mics)
    bool phantomPowerAvailable = false;
    bool phantomPowerEnabled = false;

    // Pad
    bool padAvailable = false;
    bool padEnabled = false;  // -20dB typically
};

//==============================================================================
// Monitor Mix
//==============================================================================

struct MonitorMix
{
    juce::String name = "Monitor";
    float inputLevel = 1.0f;           // 0-1
    float playbackLevel = 1.0f;        // 0-1 (from DAW)
    float masterLevel = 1.0f;          // 0-1
    float pan = 0.0f;                  // -1 to +1

    bool muteInput = false;
    bool mutePlayback = false;

    // Dim
    bool dimEnabled = false;
    float dimAmount = 0.25f;           // -12dB typically

    // Mono check
    bool monoEnabled = false;
};

//==============================================================================
// Insert Effect Slot
//==============================================================================

struct InsertSlot
{
    juce::String name;
    bool bypassed = false;
    bool preGain = false;              // Pre or post input gain

    // Effect type
    enum class Type { None, EQ, Compressor, Gate, DeEsser, Saturator, Custom };
    Type type = Type::None;

    // Generic parameters (depends on type)
    std::map<juce::String, float> parameters;
};

//==============================================================================
// Input Monitoring Channel Strip
//==============================================================================

class InputMonitoringStrip
{
public:
    static constexpr int MaxInserts = 8;
    static constexpr int MaxCueSends = 4;

    //==========================================================================
    // Constructor
    //==========================================================================

    InputMonitoringStrip(const juce::String& name = "Input 1")
        : channelName(name)
    {
        inserts.resize(MaxInserts);
        cueSendLevels.fill(0.0f);
        cueSendEnabled.fill(false);
    }

    //==========================================================================
    // Preparation
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize)
    {
        currentSampleRate = sampleRate;
        this->maxBlockSize = maxBlockSize;

        // Initialize filters
        initializeFilters();
    }

    //==========================================================================
    // Input Configuration
    //==========================================================================

    void setInputSource(const InputSource& source)
    {
        inputSource = source;
    }

    const InputSource& getInputSource() const { return inputSource; }

    void setHardwareInput(int channelIndex)
    {
        inputSource.hardwareInputIndex = channelIndex;
        inputSource.leftChannel = channelIndex;
        inputSource.rightChannel = channelIndex + 1;
    }

    void setStereoInput(int leftChannel, int rightChannel)
    {
        inputSource.isStereo = true;
        inputSource.leftChannel = leftChannel;
        inputSource.rightChannel = rightChannel;
    }

    void setMonoInput(int channel)
    {
        inputSource.isStereo = false;
        inputSource.leftChannel = channel;
    }

    //==========================================================================
    // Gain Staging
    //==========================================================================

    /** Set input gain in dB (-40 to +40) */
    void setInputGain(float gainDb)
    {
        inputGainDb = juce::jlimit(-40.0f, 40.0f, gainDb);
        inputGain = std::pow(10.0f, inputGainDb / 20.0f);
    }

    float getInputGainDb() const { return inputGainDb; }

    /** Set output/fader level in dB (-inf to +12) */
    void setOutputLevel(float levelDb)
    {
        outputLevelDb = levelDb;
        outputLevel = (levelDb <= -80.0f) ? 0.0f : std::pow(10.0f, levelDb / 20.0f);
    }

    float getOutputLevelDb() const { return outputLevelDb; }

    /** Set trim/pad (-20dB) */
    void setPadEnabled(bool enabled)
    {
        inputSource.padEnabled = enabled;
        padGain = enabled ? 0.1f : 1.0f;  // -20dB
    }

    //==========================================================================
    // Phase & Polarity
    //==========================================================================

    void setPhaseInvert(bool invert)
    {
        phaseInverted = invert;
    }

    bool getPhaseInvert() const { return phaseInverted; }

    void setPolarity(bool inverted)
    {
        polarityInverted = inverted;
    }

    //==========================================================================
    // High-Pass Filter
    //==========================================================================

    void setHighPassEnabled(bool enabled)
    {
        highPassEnabled = enabled;
    }

    void setHighPassFrequency(float frequency)
    {
        highPassFreq = juce::jlimit(20.0f, 500.0f, frequency);
        updateHighPassFilter();
    }

    float getHighPassFrequency() const { return highPassFreq; }

    //==========================================================================
    // Pan
    //==========================================================================

    void setPan(float pan)
    {
        this->pan = juce::jlimit(-1.0f, 1.0f, pan);
    }

    float getPan() const { return pan; }

    //==========================================================================
    // Mute/Solo
    //==========================================================================

    void setMute(bool muted)
    {
        this->muted = muted;
    }

    bool getMute() const { return muted; }

    void setSolo(bool soloed)
    {
        this->soloed = soloed;
    }

    bool getSolo() const { return soloed; }

    //==========================================================================
    // Direct Monitoring
    //==========================================================================

    void setDirectMonitoring(bool enabled)
    {
        directMonitoringEnabled = enabled;
    }

    bool getDirectMonitoring() const { return directMonitoringEnabled; }

    void setDirectMonitoringLevel(float levelDb)
    {
        directMonitorLevel = std::pow(10.0f, levelDb / 20.0f);
    }

    //==========================================================================
    // Cue Sends
    //==========================================================================

    void setCueSendLevel(int cueIndex, float levelDb)
    {
        if (cueIndex >= 0 && cueIndex < MaxCueSends)
        {
            float linear = (levelDb <= -80.0f) ? 0.0f : std::pow(10.0f, levelDb / 20.0f);
            cueSendLevels[cueIndex] = linear;
        }
    }

    void setCueSendEnabled(int cueIndex, bool enabled)
    {
        if (cueIndex >= 0 && cueIndex < MaxCueSends)
            cueSendEnabled[cueIndex] = enabled;
    }

    float getCueSendLevel(int cueIndex) const
    {
        if (cueIndex >= 0 && cueIndex < MaxCueSends)
            return 20.0f * std::log10(cueSendLevels[cueIndex] + 1e-10f);
        return -80.0f;
    }

    //==========================================================================
    // Insert Effects
    //==========================================================================

    void setInsert(int slot, const InsertSlot& insert)
    {
        if (slot >= 0 && slot < MaxInserts)
            inserts[slot] = insert;
    }

    void bypassInsert(int slot, bool bypass)
    {
        if (slot >= 0 && slot < MaxInserts)
            inserts[slot].bypassed = bypass;
    }

    void clearInsert(int slot)
    {
        if (slot >= 0 && slot < MaxInserts)
            inserts[slot] = InsertSlot();
    }

    //==========================================================================
    // Monitor Mix
    //==========================================================================

    void setMonitorMix(const MonitorMix& mix)
    {
        monitorMix = mix;
    }

    MonitorMix& getMonitorMix() { return monitorMix; }

    void setMonitorInputLevel(float level)
    {
        monitorMix.inputLevel = juce::jlimit(0.0f, 2.0f, level);
    }

    void setMonitorPlaybackLevel(float level)
    {
        monitorMix.playbackLevel = juce::jlimit(0.0f, 2.0f, level);
    }

    void setMonitorDim(bool enabled)
    {
        monitorMix.dimEnabled = enabled;
    }

    void setMonitorMono(bool enabled)
    {
        monitorMix.monoEnabled = enabled;
    }

    //==========================================================================
    // Talkback
    //==========================================================================

    void setTalkbackEnabled(bool enabled)
    {
        talkbackEnabled = enabled;
    }

    void setTalkbackLevel(float levelDb)
    {
        talkbackLevel = std::pow(10.0f, levelDb / 20.0f);
    }

    bool getTalkbackEnabled() const { return talkbackEnabled; }

    //==========================================================================
    // Processing
    //==========================================================================

    void processBlock(const juce::AudioBuffer<float>& hardwareInput,
                      juce::AudioBuffer<float>& toDAW,
                      juce::AudioBuffer<float>& toMonitor,
                      const juce::AudioBuffer<float>& playbackFromDAW)
    {
        int numSamples = hardwareInput.getNumSamples();

        // Create working buffer
        juce::AudioBuffer<float> working(2, numSamples);

        // Copy input (mono to stereo if needed)
        if (inputSource.isStereo)
        {
            if (inputSource.leftChannel < hardwareInput.getNumChannels())
                working.copyFrom(0, 0, hardwareInput, inputSource.leftChannel, 0, numSamples);
            if (inputSource.rightChannel < hardwareInput.getNumChannels())
                working.copyFrom(1, 0, hardwareInput, inputSource.rightChannel, 0, numSamples);
        }
        else
        {
            if (inputSource.leftChannel < hardwareInput.getNumChannels())
            {
                working.copyFrom(0, 0, hardwareInput, inputSource.leftChannel, 0, numSamples);
                working.copyFrom(1, 0, hardwareInput, inputSource.leftChannel, 0, numSamples);
            }
        }

        // Apply pad
        if (inputSource.padEnabled)
            working.applyGain(padGain);

        // Apply input gain
        working.applyGain(inputGain);

        // Phase invert
        if (phaseInverted)
            working.applyGain(-1.0f);

        // High-pass filter
        if (highPassEnabled)
            applyHighPass(working);

        // Apply inserts (pre-fader)
        for (const auto& insert : inserts)
        {
            if (insert.type != InsertSlot::Type::None && !insert.bypassed && insert.preGain)
            {
                applyInsert(working, insert);
            }
        }

        // Update input metering (pre-fader)
        updateInputMetering(working);

        // Apply mute
        if (muted)
            working.applyGain(0.0f);

        // Apply fader/output level
        working.applyGain(outputLevel);

        // Apply pan
        if (std::abs(pan) > 0.01f)
        {
            float leftGain = std::cos((pan + 1.0f) * juce::MathConstants<float>::pi * 0.25f);
            float rightGain = std::sin((pan + 1.0f) * juce::MathConstants<float>::pi * 0.25f);
            working.applyGain(0, 0, numSamples, leftGain);
            working.applyGain(1, 0, numSamples, rightGain);
        }

        // Apply inserts (post-fader)
        for (const auto& insert : inserts)
        {
            if (insert.type != InsertSlot::Type::None && !insert.bypassed && !insert.preGain)
            {
                applyInsert(working, insert);
            }
        }

        // Update output metering (post-fader)
        updateOutputMetering(working);

        // Send to DAW (for recording)
        toDAW.makeCopyOf(working);

        // === Monitor Output ===
        toMonitor.clear();

        // Add processed input
        float inputMixLevel = monitorMix.inputLevel;
        if (!monitorMix.muteInput)
        {
            for (int ch = 0; ch < std::min(2, toMonitor.getNumChannels()); ++ch)
            {
                toMonitor.addFrom(ch, 0, working, ch, 0, numSamples, inputMixLevel);
            }
        }

        // Add playback from DAW
        float playbackMixLevel = monitorMix.playbackLevel;
        if (!monitorMix.mutePlayback && playbackFromDAW.getNumSamples() >= numSamples)
        {
            for (int ch = 0; ch < std::min(2, toMonitor.getNumChannels()); ++ch)
            {
                if (ch < playbackFromDAW.getNumChannels())
                    toMonitor.addFrom(ch, 0, playbackFromDAW, ch, 0, numSamples, playbackMixLevel);
            }
        }

        // Apply master level
        toMonitor.applyGain(monitorMix.masterLevel);

        // Dim
        if (monitorMix.dimEnabled)
            toMonitor.applyGain(monitorMix.dimAmount);

        // Mono
        if (monitorMix.monoEnabled && toMonitor.getNumChannels() >= 2)
        {
            for (int i = 0; i < numSamples; ++i)
            {
                float mono = (toMonitor.getSample(0, i) + toMonitor.getSample(1, i)) * 0.5f;
                toMonitor.setSample(0, i, mono);
                toMonitor.setSample(1, i, mono);
            }
        }
    }

    //==========================================================================
    // Metering
    //==========================================================================

    float getInputLevelL() const { return inputLevelL.load(); }
    float getInputLevelR() const { return inputLevelR.load(); }
    float getOutputLevelL() const { return outputLevelL.load(); }
    float getOutputLevelR() const { return outputLevelR.load(); }

    float getInputPeakL() const { return inputPeakL.load(); }
    float getInputPeakR() const { return inputPeakR.load(); }
    float getOutputPeakL() const { return outputPeakL.load(); }
    float getOutputPeakR() const { return outputPeakR.load(); }

    bool getInputClipping() const { return inputClipping.load(); }
    bool getOutputClipping() const { return outputClipping.load(); }

    void resetPeakHold()
    {
        inputPeakL = inputPeakR = 0.0f;
        outputPeakL = outputPeakR = 0.0f;
        inputClipping = outputClipping = false;
    }

    //==========================================================================
    // Name
    //==========================================================================

    void setName(const juce::String& name) { channelName = name; }
    const juce::String& getName() const { return channelName; }

    //==========================================================================
    // Color
    //==========================================================================

    void setColor(juce::Colour color) { channelColor = color; }
    juce::Colour getColor() const { return channelColor; }

private:
    juce::String channelName;
    juce::Colour channelColor = juce::Colours::grey;

    double currentSampleRate = 48000.0;
    int maxBlockSize = 512;

    // Input
    InputSource inputSource;
    float inputGainDb = 0.0f;
    float inputGain = 1.0f;
    float padGain = 1.0f;

    // Processing
    bool phaseInverted = false;
    bool polarityInverted = false;
    bool highPassEnabled = false;
    float highPassFreq = 80.0f;

    // Output
    float outputLevelDb = 0.0f;
    float outputLevel = 1.0f;
    float pan = 0.0f;
    bool muted = false;
    bool soloed = false;

    // Direct monitoring
    bool directMonitoringEnabled = true;
    float directMonitorLevel = 1.0f;

    // Cue sends
    std::array<float, MaxCueSends> cueSendLevels;
    std::array<bool, MaxCueSends> cueSendEnabled;

    // Inserts
    std::vector<InsertSlot> inserts;

    // Monitor mix
    MonitorMix monitorMix;

    // Talkback
    bool talkbackEnabled = false;
    float talkbackLevel = 0.5f;

    // High-pass filter state
    float hpCoeffA = 0.0f;
    float hpCoeffB = 0.0f;
    std::array<float, 2> hpStateL = { 0.0f, 0.0f };
    std::array<float, 2> hpStateR = { 0.0f, 0.0f };

    // Metering
    std::atomic<float> inputLevelL { 0.0f };
    std::atomic<float> inputLevelR { 0.0f };
    std::atomic<float> outputLevelL { 0.0f };
    std::atomic<float> outputLevelR { 0.0f };

    std::atomic<float> inputPeakL { 0.0f };
    std::atomic<float> inputPeakR { 0.0f };
    std::atomic<float> outputPeakL { 0.0f };
    std::atomic<float> outputPeakR { 0.0f };

    std::atomic<bool> inputClipping { false };
    std::atomic<bool> outputClipping { false };

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void initializeFilters()
    {
        updateHighPassFilter();
    }

    void updateHighPassFilter()
    {
        // Simple 2nd order high-pass
        float omega = 2.0f * juce::MathConstants<float>::pi * highPassFreq / static_cast<float>(currentSampleRate);
        float alpha = std::sin(omega) / (2.0f * 0.707f);  // Q = 0.707

        float a0 = 1.0f + alpha;
        hpCoeffA = (1.0f + std::cos(omega)) / (2.0f * a0);
        hpCoeffB = -(1.0f + std::cos(omega)) / a0;
    }

    void applyHighPass(juce::AudioBuffer<float>& buffer)
    {
        for (int i = 0; i < buffer.getNumSamples(); ++i)
        {
            // Left channel
            float inL = buffer.getSample(0, i);
            float outL = hpCoeffA * inL + hpCoeffA * hpStateL[0] + hpCoeffB * hpStateL[1];
            hpStateL[0] = inL;
            hpStateL[1] = outL;
            buffer.setSample(0, i, outL);

            // Right channel
            float inR = buffer.getSample(1, i);
            float outR = hpCoeffA * inR + hpCoeffA * hpStateR[0] + hpCoeffB * hpStateR[1];
            hpStateR[0] = inR;
            hpStateR[1] = outR;
            buffer.setSample(1, i, outR);
        }
    }

    void applyInsert(juce::AudioBuffer<float>& buffer, const InsertSlot& insert)
    {
        // Placeholder for insert processing
        // In production, this would apply EQ, compressor, etc.
        switch (insert.type)
        {
            case InsertSlot::Type::Compressor:
                // Apply compression
                break;
            case InsertSlot::Type::EQ:
                // Apply EQ
                break;
            case InsertSlot::Type::Gate:
                // Apply gate
                break;
            case InsertSlot::Type::DeEsser:
                // Apply de-essing
                break;
            case InsertSlot::Type::Saturator:
                // Apply saturation
                break;
            default:
                break;
        }
    }

    void updateInputMetering(const juce::AudioBuffer<float>& buffer)
    {
        float levelL = 0.0f, levelR = 0.0f;

        for (int i = 0; i < buffer.getNumSamples(); ++i)
        {
            levelL = std::max(levelL, std::abs(buffer.getSample(0, i)));
            levelR = std::max(levelR, std::abs(buffer.getSample(1, i)));
        }

        inputLevelL = levelL;
        inputLevelR = levelR;

        if (levelL > inputPeakL) inputPeakL = levelL;
        if (levelR > inputPeakR) inputPeakR = levelR;

        if (levelL > 0.99f || levelR > 0.99f)
            inputClipping = true;
    }

    void updateOutputMetering(const juce::AudioBuffer<float>& buffer)
    {
        float levelL = 0.0f, levelR = 0.0f;

        for (int i = 0; i < buffer.getNumSamples(); ++i)
        {
            levelL = std::max(levelL, std::abs(buffer.getSample(0, i)));
            levelR = std::max(levelR, std::abs(buffer.getSample(1, i)));
        }

        outputLevelL = levelL;
        outputLevelR = levelR;

        if (levelL > outputPeakL) outputPeakL = levelL;
        if (levelR > outputPeakR) outputPeakR = levelR;

        if (levelL > 0.99f || levelR > 0.99f)
            outputClipping = true;
    }

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(InputMonitoringStrip)
};

} // namespace Recording
} // namespace Echoelmusic
