#pragma once

#include <JuceHeader.h>
#include <atomic>
#include <functional>
#include <map>
#include <memory>
#include <set>
#include <vector>

namespace Echoelmusic {

/**
 * MIDIRoutingMatrix - Complete MIDI Routing Infrastructure
 *
 * Features:
 * - Flexible source-to-destination routing matrix
 * - MIDI filtering (channels, message types, note range)
 * - MIDI transformation (transpose, velocity scaling, channel remap)
 * - Virtual MIDI ports
 * - MIDI merge and split
 * - MIDI thru/monitor
 * - Per-track MIDI input/output assignment
 * - MIDI learn functionality
 * - Clock and sync routing
 * - MPE zone-aware routing
 *
 * Signal Flow:
 * Hardware Input → Filter → Transform → Virtual Port → Track Input
 * Track Output → Filter → Transform → Virtual Port → Hardware Output
 */

//==============================================================================
// Forward Declarations
//==============================================================================

class MIDIRoute;
class MIDIFilter;
class MIDITransform;
class VirtualMIDIPort;

//==============================================================================
// MIDI Endpoint Types
//==============================================================================

enum class MIDIEndpointType
{
    HardwareInput,      // Physical MIDI input device
    HardwareOutput,     // Physical MIDI output device
    TrackInput,         // Track MIDI input
    TrackOutput,        // Track MIDI output
    PluginInput,        // Plugin MIDI input
    PluginOutput,       // Plugin MIDI output
    VirtualPort,        // Virtual MIDI port (internal routing)
    ExternalApp,        // External application (IAC, loopMIDI)
    NetworkMIDI,        // Network MIDI (RTP-MIDI)
    BluetoothMIDI       // Bluetooth LE MIDI
};

enum class MIDIMessageFilter
{
    All             = 0xFFFF,
    NoteOn          = 0x0001,
    NoteOff         = 0x0002,
    Notes           = 0x0003,
    PolyAftertouch  = 0x0004,
    ControlChange   = 0x0008,
    ProgramChange   = 0x0010,
    ChannelPressure = 0x0020,
    PitchBend       = 0x0040,
    ChannelVoice    = 0x007F,
    SysEx           = 0x0080,
    Clock           = 0x0100,
    Transport       = 0x0200,    // Start, Stop, Continue
    MTC             = 0x0400,    // MIDI Time Code
    SongPosition    = 0x0800,
    Sync            = 0x0F00,
    RealTime        = 0x1000,    // Active Sensing, Reset
    System          = 0x1F80
};

inline MIDIMessageFilter operator|(MIDIMessageFilter a, MIDIMessageFilter b)
{
    return static_cast<MIDIMessageFilter>(static_cast<int>(a) | static_cast<int>(b));
}

inline MIDIMessageFilter operator&(MIDIMessageFilter a, MIDIMessageFilter b)
{
    return static_cast<MIDIMessageFilter>(static_cast<int>(a) & static_cast<int>(b));
}

//==============================================================================
// MIDI Endpoint
//==============================================================================

struct MIDIEndpoint
{
    MIDIEndpointType type = MIDIEndpointType::HardwareInput;
    int index = 0;                  // Device/Track/Plugin index
    juce::String name;
    juce::String deviceId;          // Unique device identifier

    // Capabilities
    bool supportsMPE = false;
    bool supportsMIDI2 = false;
    bool supportsHighRes = false;

    // State
    bool isConnected = false;
    bool isEnabled = true;

    bool operator==(const MIDIEndpoint& other) const
    {
        return type == other.type && index == other.index && deviceId == other.deviceId;
    }

    bool operator<(const MIDIEndpoint& other) const
    {
        if (type != other.type) return type < other.type;
        if (index != other.index) return index < other.index;
        return deviceId < other.deviceId;
    }

    juce::String getDisplayName() const
    {
        switch (type)
        {
            case MIDIEndpointType::HardwareInput:   return "In: " + name;
            case MIDIEndpointType::HardwareOutput:  return "Out: " + name;
            case MIDIEndpointType::TrackInput:      return "Track " + juce::String(index + 1) + " In";
            case MIDIEndpointType::TrackOutput:     return "Track " + juce::String(index + 1) + " Out";
            case MIDIEndpointType::PluginInput:     return "Plugin " + name + " In";
            case MIDIEndpointType::PluginOutput:    return "Plugin " + name + " Out";
            case MIDIEndpointType::VirtualPort:     return "Virtual: " + name;
            case MIDIEndpointType::ExternalApp:     return "App: " + name;
            case MIDIEndpointType::NetworkMIDI:     return "Network: " + name;
            case MIDIEndpointType::BluetoothMIDI:   return "BT: " + name;
            default: return name;
        }
    }
};

//==============================================================================
// MIDI Filter - Channel and Message Filtering
//==============================================================================

class MIDIFilter
{
public:
    MIDIFilter() = default;

    //==========================================================================
    // Channel Filtering
    //==========================================================================

    /** Set which channels to pass (1-16) */
    void setChannelMask(uint16_t mask) { channelMask = mask; }
    uint16_t getChannelMask() const { return channelMask; }

    void enableChannel(int channel, bool enable)
    {
        if (channel >= 1 && channel <= 16)
        {
            if (enable)
                channelMask |= (1 << (channel - 1));
            else
                channelMask &= ~(1 << (channel - 1));
        }
    }

    bool isChannelEnabled(int channel) const
    {
        return channel >= 1 && channel <= 16 && (channelMask & (1 << (channel - 1)));
    }

    void enableAllChannels() { channelMask = 0xFFFF; }
    void disableAllChannels() { channelMask = 0; }

    //==========================================================================
    // Message Type Filtering
    //==========================================================================

    void setMessageFilter(MIDIMessageFilter filter) { messageFilter = filter; }
    MIDIMessageFilter getMessageFilter() const { return messageFilter; }

    bool passesMessageType(const juce::MidiMessage& msg) const
    {
        if (msg.isNoteOn())
            return static_cast<int>(messageFilter & MIDIMessageFilter::NoteOn) != 0;
        if (msg.isNoteOff())
            return static_cast<int>(messageFilter & MIDIMessageFilter::NoteOff) != 0;
        if (msg.isAftertouch())
            return static_cast<int>(messageFilter & MIDIMessageFilter::PolyAftertouch) != 0;
        if (msg.isController())
            return static_cast<int>(messageFilter & MIDIMessageFilter::ControlChange) != 0;
        if (msg.isProgramChange())
            return static_cast<int>(messageFilter & MIDIMessageFilter::ProgramChange) != 0;
        if (msg.isChannelPressure())
            return static_cast<int>(messageFilter & MIDIMessageFilter::ChannelPressure) != 0;
        if (msg.isPitchWheel())
            return static_cast<int>(messageFilter & MIDIMessageFilter::PitchBend) != 0;
        if (msg.isSysEx())
            return static_cast<int>(messageFilter & MIDIMessageFilter::SysEx) != 0;
        if (msg.isMidiClock())
            return static_cast<int>(messageFilter & MIDIMessageFilter::Clock) != 0;
        if (msg.isMidiStart() || msg.isMidiStop() || msg.isMidiContinue())
            return static_cast<int>(messageFilter & MIDIMessageFilter::Transport) != 0;
        if (msg.isQuarterFrame())
            return static_cast<int>(messageFilter & MIDIMessageFilter::MTC) != 0;
        if (msg.isSongPositionPointer())
            return static_cast<int>(messageFilter & MIDIMessageFilter::SongPosition) != 0;
        if (msg.isActiveSense())
            return static_cast<int>(messageFilter & MIDIMessageFilter::RealTime) != 0;

        return true; // Pass unknown messages
    }

    //==========================================================================
    // Note Range Filtering
    //==========================================================================

    void setNoteRange(int low, int high)
    {
        lowNote = juce::jlimit(0, 127, low);
        highNote = juce::jlimit(0, 127, high);
    }

    int getLowNote() const { return lowNote; }
    int getHighNote() const { return highNote; }

    //==========================================================================
    // Velocity Filtering
    //==========================================================================

    void setVelocityRange(int low, int high)
    {
        lowVelocity = juce::jlimit(0, 127, low);
        highVelocity = juce::jlimit(0, 127, high);
    }

    //==========================================================================
    // CC Filtering
    //==========================================================================

    void setCCFilter(int ccNumber, bool pass)
    {
        if (ccNumber >= 0 && ccNumber < 128)
            ccFilter[ccNumber] = pass;
    }

    void passAllCCs() { ccFilter.fill(true); }
    void blockAllCCs() { ccFilter.fill(false); }

    //==========================================================================
    // Apply Filter
    //==========================================================================

    bool passes(const juce::MidiMessage& msg) const
    {
        // Check message type
        if (!passesMessageType(msg))
            return false;

        // Check channel for channel messages
        if (msg.getChannel() > 0)
        {
            if (!isChannelEnabled(msg.getChannel()))
                return false;
        }

        // Check note range
        if (msg.isNoteOnOrOff())
        {
            int note = msg.getNoteNumber();
            if (note < lowNote || note > highNote)
                return false;

            // Check velocity for note on
            if (msg.isNoteOn())
            {
                int vel = msg.getVelocity();
                if (vel < lowVelocity || vel > highVelocity)
                    return false;
            }
        }

        // Check CC filter
        if (msg.isController())
        {
            int cc = msg.getControllerNumber();
            if (!ccFilter[cc])
                return false;
        }

        return true;
    }

private:
    uint16_t channelMask = 0xFFFF;          // All channels enabled
    MIDIMessageFilter messageFilter = MIDIMessageFilter::All;

    int lowNote = 0;
    int highNote = 127;
    int lowVelocity = 1;
    int highVelocity = 127;

    std::array<bool, 128> ccFilter;

public:
    MIDIFilter(const MIDIFilter&) = default;
    MIDIFilter& operator=(const MIDIFilter&) = default;
};

//==============================================================================
// MIDI Transform - Message Transformation
//==============================================================================

class MIDITransform
{
public:
    MIDITransform() = default;

    //==========================================================================
    // Transpose
    //==========================================================================

    void setTranspose(int semitones) { transpose = juce::jlimit(-48, 48, semitones); }
    int getTranspose() const { return transpose; }

    //==========================================================================
    // Velocity Scaling
    //==========================================================================

    void setVelocityScale(float scale) { velocityScale = juce::jlimit(0.0f, 2.0f, scale); }
    float getVelocityScale() const { return velocityScale; }

    void setVelocityOffset(int offset) { velocityOffset = juce::jlimit(-127, 127, offset); }
    int getVelocityOffset() const { return velocityOffset; }

    void setVelocityCurve(float curve) { velocityCurve = juce::jlimit(0.1f, 10.0f, curve); }
    float getVelocityCurve() const { return velocityCurve; }

    //==========================================================================
    // Channel Remapping
    //==========================================================================

    void setChannelRemap(int sourceChannel, int destChannel)
    {
        if (sourceChannel >= 1 && sourceChannel <= 16 && destChannel >= 1 && destChannel <= 16)
            channelMap[sourceChannel - 1] = destChannel;
    }

    void setAllChannelsTo(int destChannel)
    {
        for (int i = 0; i < 16; ++i)
            channelMap[i] = destChannel;
    }

    void resetChannelMap()
    {
        for (int i = 0; i < 16; ++i)
            channelMap[i] = i + 1;
    }

    //==========================================================================
    // CC Remapping
    //==========================================================================

    void setCCRemap(int sourceCC, int destCC)
    {
        if (sourceCC >= 0 && sourceCC < 128 && destCC >= 0 && destCC < 128)
            ccMap[sourceCC] = destCC;
    }

    void resetCCMap()
    {
        for (int i = 0; i < 128; ++i)
            ccMap[i] = i;
    }

    //==========================================================================
    // Note Remapping (for drum maps, etc.)
    //==========================================================================

    void setNoteRemap(int sourceNote, int destNote)
    {
        if (sourceNote >= 0 && sourceNote < 128 && destNote >= 0 && destNote < 128)
            noteMap[sourceNote] = destNote;
    }

    void resetNoteMap()
    {
        for (int i = 0; i < 128; ++i)
            noteMap[i] = i;
    }

    //==========================================================================
    // Apply Transform
    //==========================================================================

    juce::MidiMessage transform(const juce::MidiMessage& msg) const
    {
        if (msg.isNoteOnOrOff())
        {
            int note = noteMap[msg.getNoteNumber()];
            note += transpose;
            note = juce::jlimit(0, 127, note);

            int velocity = msg.getVelocity();
            if (msg.isNoteOn() && velocity > 0)
            {
                // Apply velocity curve
                float normVel = velocity / 127.0f;
                normVel = std::pow(normVel, velocityCurve);
                velocity = static_cast<int>(normVel * 127.0f);

                // Apply scale and offset
                velocity = static_cast<int>(velocity * velocityScale) + velocityOffset;
                velocity = juce::jlimit(1, 127, velocity);
            }

            int channel = channelMap[msg.getChannel() - 1];

            if (msg.isNoteOn())
                return juce::MidiMessage::noteOn(channel, note, (juce::uint8)velocity);
            else
                return juce::MidiMessage::noteOff(channel, note, (juce::uint8)velocity);
        }

        if (msg.isController())
        {
            int cc = ccMap[msg.getControllerNumber()];
            int channel = channelMap[msg.getChannel() - 1];
            return juce::MidiMessage::controllerEvent(channel, cc, msg.getControllerValue());
        }

        if (msg.isPitchWheel())
        {
            int channel = channelMap[msg.getChannel() - 1];
            return juce::MidiMessage::pitchWheel(channel, msg.getPitchWheelValue());
        }

        if (msg.isAftertouch())
        {
            int note = noteMap[msg.getNoteNumber()] + transpose;
            note = juce::jlimit(0, 127, note);
            int channel = channelMap[msg.getChannel() - 1];
            return juce::MidiMessage::aftertouchChange(channel, note, msg.getAfterTouchValue());
        }

        if (msg.isChannelPressure())
        {
            int channel = channelMap[msg.getChannel() - 1];
            return juce::MidiMessage::channelPressureChange(channel, msg.getChannelPressureValue());
        }

        if (msg.isProgramChange())
        {
            int channel = channelMap[msg.getChannel() - 1];
            return juce::MidiMessage::programChange(channel, msg.getProgramChangeNumber());
        }

        // Return unchanged for other message types
        return msg;
    }

private:
    int transpose = 0;
    float velocityScale = 1.0f;
    int velocityOffset = 0;
    float velocityCurve = 1.0f;     // 1.0 = linear

    std::array<int, 16> channelMap = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16};
    std::array<int, 128> ccMap;
    std::array<int, 128> noteMap;

public:
    MIDITransform(const MIDITransform&) = default;
    MIDITransform& operator=(const MIDITransform&) = default;
};

//==============================================================================
// MIDI Route - Source to Destination Connection
//==============================================================================

class MIDIRoute
{
public:
    MIDIRoute(MIDIEndpoint src, MIDIEndpoint dst)
        : source(src), destination(dst)
    {
    }

    //==========================================================================
    // Configuration
    //==========================================================================

    MIDIEndpoint getSource() const { return source; }
    MIDIEndpoint getDestination() const { return destination; }

    void setEnabled(bool e) { enabled.store(e); }
    bool isEnabled() const { return enabled.load(); }

    void setMuted(bool m) { muted.store(m); }
    bool isMuted() const { return muted.load(); }

    MIDIFilter& getFilter() { return filter; }
    const MIDIFilter& getFilter() const { return filter; }

    MIDITransform& getTransform() { return transform; }
    const MIDITransform& getTransform() const { return transform; }

    //==========================================================================
    // Processing
    //==========================================================================

    /** Process messages through this route */
    void processMessages(const juce::MidiBuffer& input, juce::MidiBuffer& output, int numSamples)
    {
        if (!enabled.load() || muted.load())
            return;

        for (const auto metadata : input)
        {
            auto msg = metadata.getMessage();

            // Apply filter
            if (!filter.passes(msg))
                continue;

            // Apply transform
            auto transformedMsg = transform.transform(msg);

            // Add to output
            output.addEvent(transformedMsg, metadata.samplePosition);

            // Update activity
            lastActivityTime = juce::Time::getMillisecondCounter();
            messageCount++;
        }
    }

    //==========================================================================
    // Monitoring
    //==========================================================================

    juce::int64 getMessageCount() const { return messageCount.load(); }
    juce::uint32 getLastActivityTime() const { return lastActivityTime; }

    bool hasRecentActivity(juce::uint32 thresholdMs = 500) const
    {
        return (juce::Time::getMillisecondCounter() - lastActivityTime) < thresholdMs;
    }

private:
    MIDIEndpoint source;
    MIDIEndpoint destination;

    std::atomic<bool> enabled { true };
    std::atomic<bool> muted { false };

    MIDIFilter filter;
    MIDITransform transform;

    std::atomic<juce::int64> messageCount { 0 };
    juce::uint32 lastActivityTime = 0;
};

//==============================================================================
// Virtual MIDI Port
//==============================================================================

class VirtualMIDIPort
{
public:
    VirtualMIDIPort(const juce::String& portName) : name(portName)
    {
    }

    juce::String getName() const { return name; }

    void prepare(int maxBlockSize)
    {
        buffer.ensureSize(maxBlockSize * 4); // Generous buffer
    }

    void addEvents(const juce::MidiBuffer& events)
    {
        buffer.addEvents(events, 0, -1, 0);
    }

    void addEvent(const juce::MidiMessage& msg, int samplePosition)
    {
        buffer.addEvent(msg, samplePosition);
    }

    const juce::MidiBuffer& getBuffer() const { return buffer; }

    void clear() { buffer.clear(); }

private:
    juce::String name;
    juce::MidiBuffer buffer;
};

//==============================================================================
// MIDI Learn Manager
//==============================================================================

class MIDILearnManager
{
public:
    using LearnCallback = std::function<void(int channel, int ccNumber, int value)>;

    void startLearning(const juce::String& parameterName, LearnCallback callback)
    {
        learning = true;
        currentParameter = parameterName;
        learnCallback = callback;
    }

    void stopLearning()
    {
        learning = false;
        currentParameter = "";
        learnCallback = nullptr;
    }

    bool isLearning() const { return learning; }
    juce::String getCurrentParameter() const { return currentParameter; }

    void processMessage(const juce::MidiMessage& msg)
    {
        if (!learning || !learnCallback)
            return;

        if (msg.isController())
        {
            learnCallback(msg.getChannel(), msg.getControllerNumber(), msg.getControllerValue());
            stopLearning();
        }
    }

private:
    bool learning = false;
    juce::String currentParameter;
    LearnCallback learnCallback;
};

//==============================================================================
// MIDI Routing Matrix Manager
//==============================================================================

class MIDIRoutingMatrix
{
public:
    static constexpr int MaxRoutes = 256;
    static constexpr int MaxVirtualPorts = 16;

    //==========================================================================
    // Construction
    //==========================================================================

    MIDIRoutingMatrix()
    {
        // Create default virtual ports
        createVirtualPort("Internal Bus A");
        createVirtualPort("Internal Bus B");
    }

    //==========================================================================
    // Initialization
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize)
    {
        currentSampleRate = sampleRate;
        currentBlockSize = maxBlockSize;

        for (auto& port : virtualPorts)
            port->prepare(maxBlockSize);

        outputBuffer.ensureSize(maxBlockSize * 4);
    }

    //==========================================================================
    // Endpoint Management
    //==========================================================================

    /** Register a hardware MIDI input */
    void registerHardwareInput(const juce::String& name, const juce::String& deviceId)
    {
        MIDIEndpoint endpoint;
        endpoint.type = MIDIEndpointType::HardwareInput;
        endpoint.index = static_cast<int>(hardwareInputs.size());
        endpoint.name = name;
        endpoint.deviceId = deviceId;
        endpoint.isConnected = true;
        hardwareInputs.push_back(endpoint);
    }

    /** Register a hardware MIDI output */
    void registerHardwareOutput(const juce::String& name, const juce::String& deviceId)
    {
        MIDIEndpoint endpoint;
        endpoint.type = MIDIEndpointType::HardwareOutput;
        endpoint.index = static_cast<int>(hardwareOutputs.size());
        endpoint.name = name;
        endpoint.deviceId = deviceId;
        endpoint.isConnected = true;
        hardwareOutputs.push_back(endpoint);
    }

    /** Get track input endpoint */
    MIDIEndpoint getTrackInputEndpoint(int trackIndex) const
    {
        MIDIEndpoint endpoint;
        endpoint.type = MIDIEndpointType::TrackInput;
        endpoint.index = trackIndex;
        endpoint.name = "Track " + juce::String(trackIndex + 1);
        return endpoint;
    }

    /** Get track output endpoint */
    MIDIEndpoint getTrackOutputEndpoint(int trackIndex) const
    {
        MIDIEndpoint endpoint;
        endpoint.type = MIDIEndpointType::TrackOutput;
        endpoint.index = trackIndex;
        endpoint.name = "Track " + juce::String(trackIndex + 1);
        return endpoint;
    }

    //==========================================================================
    // Route Management
    //==========================================================================

    /** Create a new route */
    int createRoute(const MIDIEndpoint& source, const MIDIEndpoint& destination)
    {
        if (routes.size() >= MaxRoutes)
            return -1;

        // Check for duplicate
        for (size_t i = 0; i < routes.size(); ++i)
        {
            if (routes[i]->getSource() == source && routes[i]->getDestination() == destination)
                return static_cast<int>(i);
        }

        routes.push_back(std::make_unique<MIDIRoute>(source, destination));
        return static_cast<int>(routes.size()) - 1;
    }

    /** Delete a route */
    void deleteRoute(int routeIndex)
    {
        if (routeIndex >= 0 && routeIndex < static_cast<int>(routes.size()))
        {
            routes.erase(routes.begin() + routeIndex);
        }
    }

    /** Get route */
    MIDIRoute* getRoute(int routeIndex)
    {
        return (routeIndex >= 0 && routeIndex < static_cast<int>(routes.size()))
               ? routes[routeIndex].get() : nullptr;
    }

    int getNumRoutes() const { return static_cast<int>(routes.size()); }

    /** Find routes from a source */
    std::vector<int> findRoutesFromSource(const MIDIEndpoint& source) const
    {
        std::vector<int> result;
        for (size_t i = 0; i < routes.size(); ++i)
        {
            if (routes[i]->getSource() == source)
                result.push_back(static_cast<int>(i));
        }
        return result;
    }

    /** Find routes to a destination */
    std::vector<int> findRoutesToDestination(const MIDIEndpoint& destination) const
    {
        std::vector<int> result;
        for (size_t i = 0; i < routes.size(); ++i)
        {
            if (routes[i]->getDestination() == destination)
                result.push_back(static_cast<int>(i));
        }
        return result;
    }

    //==========================================================================
    // Virtual Ports
    //==========================================================================

    /** Create a virtual MIDI port */
    int createVirtualPort(const juce::String& name)
    {
        if (virtualPorts.size() >= MaxVirtualPorts)
            return -1;

        virtualPorts.push_back(std::make_unique<VirtualMIDIPort>(name));
        if (currentSampleRate > 0)
            virtualPorts.back()->prepare(currentBlockSize);

        return static_cast<int>(virtualPorts.size()) - 1;
    }

    VirtualMIDIPort* getVirtualPort(int index)
    {
        return (index >= 0 && index < static_cast<int>(virtualPorts.size()))
               ? virtualPorts[index].get() : nullptr;
    }

    int getNumVirtualPorts() const { return static_cast<int>(virtualPorts.size()); }

    //==========================================================================
    // Quick Routing Helpers
    //==========================================================================

    /** Route all hardware inputs to a track */
    void routeAllInputsToTrack(int trackIndex)
    {
        MIDIEndpoint trackIn = getTrackInputEndpoint(trackIndex);
        for (const auto& hwIn : hardwareInputs)
        {
            createRoute(hwIn, trackIn);
        }
    }

    /** Route track output to all hardware outputs */
    void routeTrackToAllOutputs(int trackIndex)
    {
        MIDIEndpoint trackOut = getTrackOutputEndpoint(trackIndex);
        for (const auto& hwOut : hardwareOutputs)
        {
            createRoute(trackOut, hwOut);
        }
    }

    /** Create MIDI thru (input directly to output) */
    int createMIDIThru(int inputIndex, int outputIndex)
    {
        if (inputIndex < static_cast<int>(hardwareInputs.size()) &&
            outputIndex < static_cast<int>(hardwareOutputs.size()))
        {
            return createRoute(hardwareInputs[inputIndex], hardwareOutputs[outputIndex]);
        }
        return -1;
    }

    //==========================================================================
    // Processing
    //==========================================================================

    /** Begin processing block - clear virtual ports */
    void beginBlock()
    {
        for (auto& port : virtualPorts)
            port->clear();

        outputBuffer.clear();
    }

    /** Route messages from a source endpoint */
    void routeFromSource(const MIDIEndpoint& source, const juce::MidiBuffer& input, int numSamples)
    {
        // Find all routes from this source
        for (auto& route : routes)
        {
            if (route->getSource() == source && route->isEnabled())
            {
                // Route to destination buffer
                auto& dest = route->getDestination();

                if (dest.type == MIDIEndpointType::VirtualPort && dest.index < static_cast<int>(virtualPorts.size()))
                {
                    juce::MidiBuffer tempBuffer;
                    route->processMessages(input, tempBuffer, numSamples);
                    virtualPorts[dest.index]->addEvents(tempBuffer);
                }
                else
                {
                    // Store in pending outputs
                    route->processMessages(input, pendingOutputs[dest], numSamples);
                }
            }
        }

        // Process MIDI learn
        if (learnManager.isLearning())
        {
            for (const auto metadata : input)
            {
                learnManager.processMessage(metadata.getMessage());
            }
        }
    }

    /** Get messages for a destination endpoint */
    juce::MidiBuffer& getMessagesForDestination(const MIDIEndpoint& destination)
    {
        static juce::MidiBuffer emptyBuffer;

        auto it = pendingOutputs.find(destination);
        if (it != pendingOutputs.end())
            return it->second;

        return emptyBuffer;
    }

    /** Get messages for track input */
    juce::MidiBuffer& getTrackInputMessages(int trackIndex)
    {
        return getMessagesForDestination(getTrackInputEndpoint(trackIndex));
    }

    /** Route track output */
    void routeTrackOutput(int trackIndex, const juce::MidiBuffer& output, int numSamples)
    {
        MIDIEndpoint trackOut = getTrackOutputEndpoint(trackIndex);
        routeFromSource(trackOut, output, numSamples);
    }

    /** End processing block */
    void endBlock()
    {
        // Clear pending outputs for next block
        pendingOutputs.clear();
    }

    //==========================================================================
    // MIDI Learn
    //==========================================================================

    MIDILearnManager& getLearnManager() { return learnManager; }

    //==========================================================================
    // Device Discovery
    //==========================================================================

    void refreshDevices()
    {
        // Clear existing
        hardwareInputs.clear();
        hardwareOutputs.clear();

        // Get MIDI input devices
        auto midiInputs = juce::MidiInput::getAvailableDevices();
        for (const auto& device : midiInputs)
        {
            registerHardwareInput(device.name, device.identifier);
        }

        // Get MIDI output devices
        auto midiOutputs = juce::MidiOutput::getAvailableDevices();
        for (const auto& device : midiOutputs)
        {
            registerHardwareOutput(device.name, device.identifier);
        }
    }

    const std::vector<MIDIEndpoint>& getHardwareInputs() const { return hardwareInputs; }
    const std::vector<MIDIEndpoint>& getHardwareOutputs() const { return hardwareOutputs; }

    //==========================================================================
    // State Save/Restore
    //==========================================================================

    juce::var getState() const
    {
        juce::DynamicObject::Ptr state = new juce::DynamicObject();

        // Save routes
        juce::Array<juce::var> routeArray;
        for (const auto& route : routes)
        {
            juce::DynamicObject::Ptr routeState = new juce::DynamicObject();

            // Source
            juce::DynamicObject::Ptr srcState = new juce::DynamicObject();
            srcState->setProperty("type", static_cast<int>(route->getSource().type));
            srcState->setProperty("index", route->getSource().index);
            srcState->setProperty("deviceId", route->getSource().deviceId);
            routeState->setProperty("source", juce::var(srcState.get()));

            // Destination
            juce::DynamicObject::Ptr dstState = new juce::DynamicObject();
            dstState->setProperty("type", static_cast<int>(route->getDestination().type));
            dstState->setProperty("index", route->getDestination().index);
            dstState->setProperty("deviceId", route->getDestination().deviceId);
            routeState->setProperty("destination", juce::var(dstState.get()));

            // Settings
            routeState->setProperty("enabled", route->isEnabled());
            routeState->setProperty("muted", route->isMuted());
            routeState->setProperty("transpose", route->getTransform().getTranspose());
            routeState->setProperty("velocityScale", route->getTransform().getVelocityScale());
            routeState->setProperty("channelMask", static_cast<int>(route->getFilter().getChannelMask()));

            routeArray.add(juce::var(routeState.get()));
        }
        state->setProperty("routes", routeArray);

        // Save virtual ports
        juce::Array<juce::var> portArray;
        for (const auto& port : virtualPorts)
        {
            portArray.add(port->getName());
        }
        state->setProperty("virtualPorts", portArray);

        return juce::var(state.get());
    }

    void restoreState(const juce::var& state)
    {
        if (auto* obj = state.getDynamicObject())
        {
            // Restore virtual ports
            auto ports = obj->getProperty("virtualPorts").getArray();
            if (ports)
            {
                virtualPorts.clear();
                for (const auto& portName : *ports)
                {
                    createVirtualPort(portName.toString());
                }
            }

            // Restore routes
            auto routeArray = obj->getProperty("routes").getArray();
            if (routeArray)
            {
                routes.clear();
                for (const auto& routeState : *routeArray)
                {
                    if (auto* routeObj = routeState.getDynamicObject())
                    {
                        auto* srcObj = routeObj->getProperty("source").getDynamicObject();
                        auto* dstObj = routeObj->getProperty("destination").getDynamicObject();

                        if (srcObj && dstObj)
                        {
                            MIDIEndpoint src, dst;
                            src.type = static_cast<MIDIEndpointType>(static_cast<int>(srcObj->getProperty("type")));
                            src.index = srcObj->getProperty("index");
                            src.deviceId = srcObj->getProperty("deviceId").toString();

                            dst.type = static_cast<MIDIEndpointType>(static_cast<int>(dstObj->getProperty("type")));
                            dst.index = dstObj->getProperty("index");
                            dst.deviceId = dstObj->getProperty("deviceId").toString();

                            int idx = createRoute(src, dst);
                            if (idx >= 0)
                            {
                                routes[idx]->setEnabled(routeObj->getProperty("enabled"));
                                routes[idx]->setMuted(routeObj->getProperty("muted"));
                                routes[idx]->getTransform().setTranspose(routeObj->getProperty("transpose"));
                                routes[idx]->getTransform().setVelocityScale(routeObj->getProperty("velocityScale"));
                                routes[idx]->getFilter().setChannelMask(
                                    static_cast<uint16_t>(static_cast<int>(routeObj->getProperty("channelMask"))));
                            }
                        }
                    }
                }
            }
        }
    }

    //==========================================================================
    // Diagnostics
    //==========================================================================

    struct RoutingStats
    {
        int totalRoutes = 0;
        int activeRoutes = 0;
        juce::int64 totalMessages = 0;
        int routesWithActivity = 0;
    };

    RoutingStats getStats() const
    {
        RoutingStats stats;
        stats.totalRoutes = static_cast<int>(routes.size());

        for (const auto& route : routes)
        {
            if (route->isEnabled())
                stats.activeRoutes++;

            stats.totalMessages += route->getMessageCount();

            if (route->hasRecentActivity())
                stats.routesWithActivity++;
        }

        return stats;
    }

private:
    double currentSampleRate = 0;
    int currentBlockSize = 0;

    std::vector<MIDIEndpoint> hardwareInputs;
    std::vector<MIDIEndpoint> hardwareOutputs;

    std::vector<std::unique_ptr<MIDIRoute>> routes;
    std::vector<std::unique_ptr<VirtualMIDIPort>> virtualPorts;

    std::map<MIDIEndpoint, juce::MidiBuffer> pendingOutputs;
    juce::MidiBuffer outputBuffer;

    MIDILearnManager learnManager;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MIDIRoutingMatrix)
};

} // namespace Echoelmusic
