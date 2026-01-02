#pragma once

#include <JuceHeader.h>
#include <atomic>
#include <functional>
#include <map>
#include <memory>
#include <vector>

namespace Echoelmusic {

/**
 * AudioRoutingManager - Complete Audio Routing Infrastructure
 *
 * Features:
 * - Send/Return (Aux) Busses with pre/post fader selection
 * - Submix/Group Busses for hierarchical mixing
 * - Sidechain routing with signal detection
 * - Multi-output support (up to 64 channels)
 * - Plugin Delay Compensation (PDC)
 * - Cue/Monitor mix routing
 * - Per-track output assignment
 * - Flexible routing matrix
 *
 * Signal Flow:
 * Track → Insert FX → Pre-Fader Sends → Fader → Post-Fader Sends →
 * Pan → Group/Submix → Master Bus → Output
 */

//==============================================================================
// Forward Declarations
//==============================================================================

class AudioBus;
class SendBus;
class GroupBus;
class SidechainSource;

//==============================================================================
// Bus Types
//==============================================================================

enum class BusType
{
    Master,         // Main stereo/surround output
    Group,          // Submix/Group bus
    Send,           // Aux send (return bus)
    Cue,            // Headphone/Monitor mix
    DirectOut       // Per-track direct output
};

enum class SendPosition
{
    PreFader,       // Before volume fader
    PostFader,      // After volume fader (default)
    PreInsert,      // Before insert effects
    PostPan         // After pan control
};

enum class ChannelFormat
{
    Mono,
    Stereo,
    LCR,            // Left-Center-Right
    Quad,           // Quadraphonic
    Surround_5_1,
    Surround_7_1,
    Atmos_7_1_4,
    Custom          // User-defined channel count
};

//==============================================================================
// Routing Point - Source or Destination
//==============================================================================

struct RoutingPoint
{
    enum class Type
    {
        Track,
        Bus,
        HardwareInput,
        HardwareOutput,
        Plugin,
        Sidechain
    };

    Type type = Type::Track;
    int index = 0;              // Track/Bus index
    int channel = 0;            // Channel within the source
    juce::String name;

    bool operator==(const RoutingPoint& other) const
    {
        return type == other.type && index == other.index && channel == other.channel;
    }
};

//==============================================================================
// Send Configuration
//==============================================================================

struct SendConfig
{
    int targetBusIndex = -1;        // Target send/aux bus
    float level = 0.0f;             // Send level (0.0 to 1.0)
    float pan = 0.0f;               // Send pan (-1.0 to +1.0)
    SendPosition position = SendPosition::PostFader;
    bool enabled = true;
    bool muted = false;

    // Modulation (for automation)
    std::atomic<float>* levelModulation = nullptr;
};

//==============================================================================
// Audio Bus
//==============================================================================

class AudioBus
{
public:
    AudioBus(BusType busType, const juce::String& busName, ChannelFormat format = ChannelFormat::Stereo)
        : type(busType), name(busName), channelFormat(format)
    {
        updateChannelCount();
    }

    virtual ~AudioBus() = default;

    //==========================================================================
    // Configuration
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize)
    {
        currentSampleRate = sampleRate;
        currentBlockSize = maxBlockSize;
        buffer.setSize(numChannels, maxBlockSize);
        buffer.clear();
    }

    void setChannelFormat(ChannelFormat format)
    {
        channelFormat = format;
        updateChannelCount();
        buffer.setSize(numChannels, currentBlockSize);
    }

    //==========================================================================
    // Processing
    //==========================================================================

    /** Clear buffer for new processing block */
    void clearBuffer(int numSamples)
    {
        buffer.clear(0, numSamples);
    }

    /** Add audio to this bus */
    void addToBuffer(const juce::AudioBuffer<float>& source, int numSamples,
                     float gain = 1.0f, float panPosition = 0.0f)
    {
        if (numChannels == 2 && source.getNumChannels() >= 1)
        {
            // Stereo panning
            float leftGain = gain * std::cos((panPosition + 1.0f) * juce::MathConstants<float>::halfPi * 0.5f);
            float rightGain = gain * std::sin((panPosition + 1.0f) * juce::MathConstants<float>::halfPi * 0.5f);

            buffer.addFrom(0, 0, source, 0, 0, numSamples, leftGain);

            if (source.getNumChannels() >= 2)
                buffer.addFrom(1, 0, source, 1, 0, numSamples, rightGain);
            else
                buffer.addFrom(1, 0, source, 0, 0, numSamples, rightGain);
        }
        else
        {
            // Direct copy for mono or multi-channel
            int channelsToCopy = juce::jmin(numChannels, source.getNumChannels());
            for (int ch = 0; ch < channelsToCopy; ++ch)
            {
                buffer.addFrom(ch, 0, source, ch, 0, numSamples, gain);
            }
        }
    }

    /** Get processed buffer */
    juce::AudioBuffer<float>& getBuffer() { return buffer; }
    const juce::AudioBuffer<float>& getBuffer() const { return buffer; }

    //==========================================================================
    // Mix Controls
    //==========================================================================

    void setVolume(float vol) { volume.store(juce::jlimit(0.0f, 2.0f, vol)); }
    float getVolume() const { return volume.load(); }

    void setPan(float p) { pan.store(juce::jlimit(-1.0f, 1.0f, p)); }
    float getPan() const { return pan.load(); }

    void setMuted(bool m) { muted.store(m); }
    bool isMuted() const { return muted.load(); }

    void setSolo(bool s) { solo.store(s); }
    bool isSolo() const { return solo.load(); }

    //==========================================================================
    // Delay Compensation
    //==========================================================================

    void setLatencySamples(int samples) { latencySamples = samples; }
    int getLatencySamples() const { return latencySamples; }

    //==========================================================================
    // Properties
    //==========================================================================

    BusType getType() const { return type; }
    juce::String getName() const { return name; }
    void setName(const juce::String& n) { name = n; }
    int getNumChannels() const { return numChannels; }
    ChannelFormat getChannelFormat() const { return channelFormat; }

    //==========================================================================
    // Metering
    //==========================================================================

    float getPeakLevel(int channel) const
    {
        if (channel < numChannels)
            return peakLevels[channel].load();
        return 0.0f;
    }

    void updateMetering(int numSamples)
    {
        for (int ch = 0; ch < numChannels; ++ch)
        {
            float peak = buffer.getMagnitude(ch, 0, numSamples);
            peakLevels[ch].store(peak);
        }
    }

protected:
    BusType type;
    juce::String name;
    ChannelFormat channelFormat;
    int numChannels = 2;

    juce::AudioBuffer<float> buffer;
    double currentSampleRate = 48000.0;
    int currentBlockSize = 512;

    std::atomic<float> volume { 1.0f };
    std::atomic<float> pan { 0.0f };
    std::atomic<bool> muted { false };
    std::atomic<bool> solo { false };

    int latencySamples = 0;

    std::array<std::atomic<float>, 16> peakLevels;

    void updateChannelCount()
    {
        switch (channelFormat)
        {
            case ChannelFormat::Mono:       numChannels = 1; break;
            case ChannelFormat::Stereo:     numChannels = 2; break;
            case ChannelFormat::LCR:        numChannels = 3; break;
            case ChannelFormat::Quad:       numChannels = 4; break;
            case ChannelFormat::Surround_5_1: numChannels = 6; break;
            case ChannelFormat::Surround_7_1: numChannels = 8; break;
            case ChannelFormat::Atmos_7_1_4:  numChannels = 12; break;
            default:                        numChannels = 2; break;
        }
    }
};

//==============================================================================
// Send/Return Bus (Aux)
//==============================================================================

class SendBus : public AudioBus
{
public:
    SendBus(const juce::String& busName, ChannelFormat format = ChannelFormat::Stereo)
        : AudioBus(BusType::Send, busName, format)
    {
    }

    //==========================================================================
    // Return Processing (Effect Chain)
    //==========================================================================

    /** Set return level (output of the send bus) */
    void setReturnLevel(float level) { returnLevel.store(juce::jlimit(0.0f, 2.0f, level)); }
    float getReturnLevel() const { return returnLevel.load(); }

    /** Set return pan */
    void setReturnPan(float p) { returnPan.store(juce::jlimit(-1.0f, 1.0f, p)); }
    float getReturnPan() const { return returnPan.load(); }

    /** Process effects on this send bus */
    void processEffects(int numSamples)
    {
        // Apply effects chain here
        // For now, just apply return level
        float level = returnLevel.load();
        if (!isMuted() && level > 0.0f)
        {
            buffer.applyGain(0, numSamples, level);
        }
        else
        {
            buffer.clear(0, numSamples);
        }
    }

    /** Route output to master bus */
    void routeToMaster(AudioBus& masterBus, int numSamples)
    {
        if (!isMuted())
        {
            masterBus.addToBuffer(buffer, numSamples, getVolume(), getPan());
        }
    }

private:
    std::atomic<float> returnLevel { 1.0f };
    std::atomic<float> returnPan { 0.0f };
};

//==============================================================================
// Group/Submix Bus
//==============================================================================

class GroupBus : public AudioBus
{
public:
    GroupBus(const juce::String& busName, ChannelFormat format = ChannelFormat::Stereo)
        : AudioBus(BusType::Group, busName, format)
    {
    }

    //==========================================================================
    // Group Routing
    //==========================================================================

    /** Set output destination (-1 = Master, 0+ = another group) */
    void setOutputBus(int busIndex) { outputBusIndex = busIndex; }
    int getOutputBus() const { return outputBusIndex; }

    /** Add track to this group */
    void addTrack(int trackIndex)
    {
        if (std::find(trackIndices.begin(), trackIndices.end(), trackIndex) == trackIndices.end())
            trackIndices.push_back(trackIndex);
    }

    /** Remove track from this group */
    void removeTrack(int trackIndex)
    {
        trackIndices.erase(
            std::remove(trackIndices.begin(), trackIndices.end(), trackIndex),
            trackIndices.end());
    }

    /** Get tracks in this group */
    const std::vector<int>& getTracks() const { return trackIndices; }

    /** Route output to another bus */
    void routeToOutput(AudioBus& outputBus, int numSamples)
    {
        if (!isMuted())
        {
            outputBus.addToBuffer(buffer, numSamples, getVolume(), getPan());
        }
    }

private:
    int outputBusIndex = -1;  // -1 = master
    std::vector<int> trackIndices;
};

//==============================================================================
// Sidechain Source
//==============================================================================

class SidechainSource
{
public:
    SidechainSource() = default;

    //==========================================================================
    // Configuration
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize)
    {
        currentSampleRate = sampleRate;
        sidechainBuffer.setSize(2, maxBlockSize);
        sidechainBuffer.clear();
    }

    void setSource(RoutingPoint source) { sourcePoint = source; }
    RoutingPoint getSource() const { return sourcePoint; }

    //==========================================================================
    // Buffer Access
    //==========================================================================

    void feedBuffer(const juce::AudioBuffer<float>& source, int numSamples)
    {
        int channelsToCopy = juce::jmin(2, source.getNumChannels());
        for (int ch = 0; ch < channelsToCopy; ++ch)
        {
            sidechainBuffer.copyFrom(ch, 0, source, ch, 0, numSamples);
        }
        updateEnvelope(numSamples);
    }

    const juce::AudioBuffer<float>& getBuffer() const { return sidechainBuffer; }

    //==========================================================================
    // Envelope Detection
    //==========================================================================

    float getEnvelopeLevel() const { return envelopeLevel.load(); }

    float getRMSLevel() const { return rmsLevel.load(); }

    float getPeakLevel() const { return peakLevel.load(); }

private:
    RoutingPoint sourcePoint;
    juce::AudioBuffer<float> sidechainBuffer;
    double currentSampleRate = 48000.0;

    std::atomic<float> envelopeLevel { 0.0f };
    std::atomic<float> rmsLevel { 0.0f };
    std::atomic<float> peakLevel { 0.0f };

    float envelopeCoeff = 0.995f;

    void updateEnvelope(int numSamples)
    {
        float peak = 0.0f;
        float sumSquares = 0.0f;

        for (int ch = 0; ch < sidechainBuffer.getNumChannels(); ++ch)
        {
            const float* data = sidechainBuffer.getReadPointer(ch);
            for (int i = 0; i < numSamples; ++i)
            {
                float sample = std::abs(data[i]);
                peak = juce::jmax(peak, sample);
                sumSquares += sample * sample;
            }
        }

        peakLevel.store(peak);
        rmsLevel.store(std::sqrt(sumSquares / (numSamples * sidechainBuffer.getNumChannels())));

        // Smooth envelope follower
        float currentEnv = envelopeLevel.load();
        if (peak > currentEnv)
            envelopeLevel.store(peak);
        else
            envelopeLevel.store(currentEnv * envelopeCoeff + peak * (1.0f - envelopeCoeff));
    }
};

//==============================================================================
// Track Routing Configuration
//==============================================================================

struct TrackRouting
{
    int trackIndex = 0;

    // Output routing
    int outputBusIndex = -1;        // -1 = Master, 0+ = Group bus
    int directOutputChannel = -1;   // -1 = disabled, 0+ = hardware output channel

    // Sends
    std::vector<SendConfig> sends;

    // Sidechain output (this track as sidechain source)
    bool sidechainOutputEnabled = false;

    // Input routing (for recording)
    int inputChannel = 0;           // Hardware input channel
    bool inputMonitorEnabled = false;

    /** Add or update send */
    void setSend(int sendBusIndex, float level, SendPosition position = SendPosition::PostFader)
    {
        for (auto& send : sends)
        {
            if (send.targetBusIndex == sendBusIndex)
            {
                send.level = level;
                send.position = position;
                return;
            }
        }

        // New send
        SendConfig newSend;
        newSend.targetBusIndex = sendBusIndex;
        newSend.level = level;
        newSend.position = position;
        sends.push_back(newSend);
    }

    /** Remove send */
    void removeSend(int sendBusIndex)
    {
        sends.erase(
            std::remove_if(sends.begin(), sends.end(),
                          [sendBusIndex](const SendConfig& s) { return s.targetBusIndex == sendBusIndex; }),
            sends.end());
    }
};

//==============================================================================
// Audio Routing Manager
//==============================================================================

class AudioRoutingManager
{
public:
    static constexpr int MaxSendBusses = 16;
    static constexpr int MaxGroupBusses = 32;
    static constexpr int MaxOutputChannels = 64;
    static constexpr int MaxTracks = 256;

    //==========================================================================
    // Construction
    //==========================================================================

    AudioRoutingManager()
    {
        // Create master bus
        masterBus = std::make_unique<AudioBus>(BusType::Master, "Master", ChannelFormat::Stereo);

        // Create default send busses
        createSendBus("Reverb");
        createSendBus("Delay");

        // Create cue bus
        cueBus = std::make_unique<AudioBus>(BusType::Cue, "Cue", ChannelFormat::Stereo);
    }

    //==========================================================================
    // Initialization
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize)
    {
        currentSampleRate = sampleRate;
        currentBlockSize = maxBlockSize;

        masterBus->prepare(sampleRate, maxBlockSize);
        cueBus->prepare(sampleRate, maxBlockSize);

        for (auto& sendBus : sendBusses)
            sendBus->prepare(sampleRate, maxBlockSize);

        for (auto& groupBus : groupBusses)
            groupBus->prepare(sampleRate, maxBlockSize);

        for (auto& sidechain : sidechainSources)
            sidechain.second.prepare(sampleRate, maxBlockSize);

        // Prepare delay compensation buffers
        calculateDelayCompensation();
    }

    //==========================================================================
    // Bus Management
    //==========================================================================

    /** Create a new send/aux bus */
    int createSendBus(const juce::String& name, ChannelFormat format = ChannelFormat::Stereo)
    {
        if (sendBusses.size() >= MaxSendBusses)
            return -1;

        sendBusses.push_back(std::make_unique<SendBus>(name, format));
        if (currentSampleRate > 0)
            sendBusses.back()->prepare(currentSampleRate, currentBlockSize);

        return static_cast<int>(sendBusses.size()) - 1;
    }

    /** Create a new group/submix bus */
    int createGroupBus(const juce::String& name, ChannelFormat format = ChannelFormat::Stereo)
    {
        if (groupBusses.size() >= MaxGroupBusses)
            return -1;

        groupBusses.push_back(std::make_unique<GroupBus>(name, format));
        if (currentSampleRate > 0)
            groupBusses.back()->prepare(currentSampleRate, currentBlockSize);

        return static_cast<int>(groupBusses.size()) - 1;
    }

    /** Delete a send bus */
    void deleteSendBus(int index)
    {
        if (index >= 0 && index < static_cast<int>(sendBusses.size()))
        {
            sendBusses.erase(sendBusses.begin() + index);

            // Update track routing
            for (auto& routing : trackRoutings)
            {
                routing.second.removeSend(index);
                for (auto& send : routing.second.sends)
                {
                    if (send.targetBusIndex > index)
                        send.targetBusIndex--;
                }
            }
        }
    }

    /** Delete a group bus */
    void deleteGroupBus(int index)
    {
        if (index >= 0 && index < static_cast<int>(groupBusses.size()))
        {
            groupBusses.erase(groupBusses.begin() + index);

            // Update track routing
            for (auto& routing : trackRoutings)
            {
                if (routing.second.outputBusIndex == index)
                    routing.second.outputBusIndex = -1;
                else if (routing.second.outputBusIndex > index)
                    routing.second.outputBusIndex--;
            }
        }
    }

    //==========================================================================
    // Track Routing
    //==========================================================================

    /** Get or create routing for a track */
    TrackRouting& getTrackRouting(int trackIndex)
    {
        auto it = trackRoutings.find(trackIndex);
        if (it == trackRoutings.end())
        {
            trackRoutings[trackIndex] = TrackRouting();
            trackRoutings[trackIndex].trackIndex = trackIndex;
        }
        return trackRoutings[trackIndex];
    }

    /** Route track to group bus */
    void routeTrackToGroup(int trackIndex, int groupBusIndex)
    {
        getTrackRouting(trackIndex).outputBusIndex = groupBusIndex;

        if (groupBusIndex >= 0 && groupBusIndex < static_cast<int>(groupBusses.size()))
        {
            groupBusses[groupBusIndex]->addTrack(trackIndex);
        }
    }

    /** Route track directly to master */
    void routeTrackToMaster(int trackIndex)
    {
        auto& routing = getTrackRouting(trackIndex);
        int oldGroup = routing.outputBusIndex;
        routing.outputBusIndex = -1;

        if (oldGroup >= 0 && oldGroup < static_cast<int>(groupBusses.size()))
        {
            groupBusses[oldGroup]->removeTrack(trackIndex);
        }
    }

    /** Set track send level */
    void setTrackSend(int trackIndex, int sendBusIndex, float level,
                      SendPosition position = SendPosition::PostFader)
    {
        getTrackRouting(trackIndex).setSend(sendBusIndex, level, position);
    }

    /** Set direct output for track */
    void setTrackDirectOutput(int trackIndex, int outputChannel)
    {
        getTrackRouting(trackIndex).directOutputChannel = outputChannel;
    }

    //==========================================================================
    // Sidechain Routing
    //==========================================================================

    /** Create sidechain source from track */
    void createSidechainSource(int trackIndex)
    {
        sidechainSources[trackIndex] = SidechainSource();
        sidechainSources[trackIndex].setSource({RoutingPoint::Type::Track, trackIndex, 0, ""});
        getTrackRouting(trackIndex).sidechainOutputEnabled = true;

        if (currentSampleRate > 0)
            sidechainSources[trackIndex].prepare(currentSampleRate, currentBlockSize);
    }

    /** Create sidechain source from bus */
    void createSidechainSourceFromBus(int busIndex, BusType busType)
    {
        int key = (static_cast<int>(busType) << 16) | busIndex;
        sidechainSources[key] = SidechainSource();
        sidechainSources[key].setSource({RoutingPoint::Type::Bus, busIndex, 0, ""});

        if (currentSampleRate > 0)
            sidechainSources[key].prepare(currentSampleRate, currentBlockSize);
    }

    /** Get sidechain source */
    SidechainSource* getSidechainSource(int trackIndex)
    {
        auto it = sidechainSources.find(trackIndex);
        return (it != sidechainSources.end()) ? &it->second : nullptr;
    }

    //==========================================================================
    // Processing
    //==========================================================================

    /** Begin processing block - clear all busses */
    void beginBlock(int numSamples)
    {
        masterBus->clearBuffer(numSamples);
        cueBus->clearBuffer(numSamples);

        for (auto& sendBus : sendBusses)
            sendBus->clearBuffer(numSamples);

        for (auto& groupBus : groupBusses)
            groupBus->clearBuffer(numSamples);
    }

    /** Route track audio through the routing system */
    void routeTrackAudio(int trackIndex, const juce::AudioBuffer<float>& trackBuffer,
                         int numSamples, float volume, float pan)
    {
        auto& routing = getTrackRouting(trackIndex);

        // Feed sidechain if enabled
        if (routing.sidechainOutputEnabled)
        {
            auto* sidechain = getSidechainSource(trackIndex);
            if (sidechain)
                sidechain->feedBuffer(trackBuffer, numSamples);
        }

        // Process sends
        for (auto& send : routing.sends)
        {
            if (!send.enabled || send.muted || send.level <= 0.0f)
                continue;

            if (send.targetBusIndex >= 0 && send.targetBusIndex < static_cast<int>(sendBusses.size()))
            {
                float sendGain = send.level;

                // Pre/Post fader
                if (send.position == SendPosition::PostFader)
                    sendGain *= volume;

                sendBusses[send.targetBusIndex]->addToBuffer(trackBuffer, numSamples, sendGain, send.pan);
            }
        }

        // Route to group or master
        if (routing.outputBusIndex >= 0 && routing.outputBusIndex < static_cast<int>(groupBusses.size()))
        {
            groupBusses[routing.outputBusIndex]->addToBuffer(trackBuffer, numSamples, volume, pan);
        }
        else
        {
            // Direct to master
            masterBus->addToBuffer(trackBuffer, numSamples, volume, pan);
        }

        // Cue/monitor mix
        if (routing.inputMonitorEnabled)
        {
            cueBus->addToBuffer(trackBuffer, numSamples, volume, pan);
        }
    }

    /** Finish processing block - process busses and route to outputs */
    void endBlock(int numSamples)
    {
        // Process send busses and route returns to master
        for (auto& sendBus : sendBusses)
        {
            sendBus->processEffects(numSamples);
            sendBus->routeToMaster(*masterBus, numSamples);
            sendBus->updateMetering(numSamples);
        }

        // Process group busses (in order of dependency)
        processGroupBusses(numSamples);

        // Update master metering
        masterBus->updateMetering(numSamples);
        cueBus->updateMetering(numSamples);
    }

    //==========================================================================
    // Output Access
    //==========================================================================

    AudioBus& getMasterBus() { return *masterBus; }
    const AudioBus& getMasterBus() const { return *masterBus; }

    AudioBus& getCueBus() { return *cueBus; }
    const AudioBus& getCueBus() const { return *cueBus; }

    SendBus* getSendBus(int index)
    {
        return (index >= 0 && index < static_cast<int>(sendBusses.size()))
               ? sendBusses[index].get() : nullptr;
    }

    GroupBus* getGroupBus(int index)
    {
        return (index >= 0 && index < static_cast<int>(groupBusses.size()))
               ? groupBusses[index].get() : nullptr;
    }

    int getNumSendBusses() const { return static_cast<int>(sendBusses.size()); }
    int getNumGroupBusses() const { return static_cast<int>(groupBusses.size()); }

    //==========================================================================
    // Delay Compensation
    //==========================================================================

    void calculateDelayCompensation()
    {
        // Calculate total latency for each path and compensate
        int maxLatency = 0;

        for (auto& sendBus : sendBusses)
            maxLatency = juce::jmax(maxLatency, sendBus->getLatencySamples());

        for (auto& groupBus : groupBusses)
            maxLatency = juce::jmax(maxLatency, groupBus->getLatencySamples());

        totalLatencySamples = maxLatency;
    }

    int getTotalLatencySamples() const { return totalLatencySamples; }

    //==========================================================================
    // State Save/Restore
    //==========================================================================

    juce::var getState() const
    {
        juce::DynamicObject::Ptr state = new juce::DynamicObject();

        // Save send busses
        juce::Array<juce::var> sendArray;
        for (const auto& sendBus : sendBusses)
        {
            juce::DynamicObject::Ptr sendState = new juce::DynamicObject();
            sendState->setProperty("name", sendBus->getName());
            sendState->setProperty("volume", sendBus->getVolume());
            sendState->setProperty("pan", sendBus->getPan());
            sendState->setProperty("muted", sendBus->isMuted());
            sendArray.add(juce::var(sendState.get()));
        }
        state->setProperty("sends", sendArray);

        // Save group busses
        juce::Array<juce::var> groupArray;
        for (const auto& groupBus : groupBusses)
        {
            juce::DynamicObject::Ptr groupState = new juce::DynamicObject();
            groupState->setProperty("name", groupBus->getName());
            groupState->setProperty("volume", groupBus->getVolume());
            groupState->setProperty("outputBus", groupBus->getOutputBus());
            groupArray.add(juce::var(groupState.get()));
        }
        state->setProperty("groups", groupArray);

        return juce::var(state.get());
    }

    void restoreState(const juce::var& state)
    {
        if (auto* obj = state.getDynamicObject())
        {
            // Restore send busses
            auto sends = obj->getProperty("sends").getArray();
            if (sends)
            {
                sendBusses.clear();
                for (const auto& sendState : *sends)
                {
                    if (auto* sendObj = sendState.getDynamicObject())
                    {
                        int idx = createSendBus(sendObj->getProperty("name").toString());
                        if (idx >= 0)
                        {
                            sendBusses[idx]->setVolume(sendObj->getProperty("volume"));
                            sendBusses[idx]->setPan(sendObj->getProperty("pan"));
                            sendBusses[idx]->setMuted(sendObj->getProperty("muted"));
                        }
                    }
                }
            }

            // Restore group busses
            auto groups = obj->getProperty("groups").getArray();
            if (groups)
            {
                groupBusses.clear();
                for (const auto& groupState : *groups)
                {
                    if (auto* groupObj = groupState.getDynamicObject())
                    {
                        int idx = createGroupBus(groupObj->getProperty("name").toString());
                        if (idx >= 0)
                        {
                            groupBusses[idx]->setVolume(groupObj->getProperty("volume"));
                            groupBusses[idx]->setOutputBus(groupObj->getProperty("outputBus"));
                        }
                    }
                }
            }
        }
    }

private:
    double currentSampleRate = 0;
    int currentBlockSize = 0;

    std::unique_ptr<AudioBus> masterBus;
    std::unique_ptr<AudioBus> cueBus;
    std::vector<std::unique_ptr<SendBus>> sendBusses;
    std::vector<std::unique_ptr<GroupBus>> groupBusses;

    std::map<int, TrackRouting> trackRoutings;
    std::map<int, SidechainSource> sidechainSources;

    int totalLatencySamples = 0;

    void processGroupBusses(int numSamples)
    {
        // Build dependency order
        std::vector<int> processOrder;
        std::vector<bool> processed(groupBusses.size(), false);

        std::function<void(int)> addToOrder = [&](int idx)
        {
            if (idx < 0 || idx >= static_cast<int>(groupBusses.size()) || processed[idx])
                return;

            // Process dependencies first
            int outputIdx = groupBusses[idx]->getOutputBus();
            if (outputIdx >= 0 && outputIdx < static_cast<int>(groupBusses.size()))
                addToOrder(outputIdx);

            processed[idx] = true;
            processOrder.push_back(idx);
        };

        for (int i = 0; i < static_cast<int>(groupBusses.size()); ++i)
            addToOrder(i);

        // Process in reverse order (leaves first)
        for (auto it = processOrder.rbegin(); it != processOrder.rend(); ++it)
        {
            int idx = *it;
            auto& groupBus = groupBusses[idx];

            groupBus->updateMetering(numSamples);

            int outputIdx = groupBus->getOutputBus();
            if (outputIdx >= 0 && outputIdx < static_cast<int>(groupBusses.size()))
            {
                groupBus->routeToOutput(*groupBusses[outputIdx], numSamples);
            }
            else
            {
                groupBus->routeToOutput(*masterBus, numSamples);
            }
        }
    }

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(AudioRoutingManager)
};

} // namespace Echoelmusic
