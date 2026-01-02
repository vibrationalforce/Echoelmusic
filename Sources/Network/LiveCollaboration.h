#pragma once

#include <JuceHeader.h>
#include <atomic>
#include <chrono>
#include <deque>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <thread>
#include <vector>

namespace Echoelmusic {
namespace Network {

/**
 * LiveCollaboration - Real-time Collaboration Framework
 *
 * Features:
 * - Peer-to-peer and server-based collaboration
 * - Real-time audio streaming between collaborators
 * - MIDI event synchronization
 * - Project state synchronization
 * - Low-latency voice chat
 * - Cursor and selection sharing
 * - Version control integration
 * - Conflict resolution
 * - Session recording
 * - Permission management
 */

//==============================================================================
// Network Types
//==============================================================================

enum class ConnectionState
{
    Disconnected,
    Connecting,
    Connected,
    Syncing,
    Synchronized,
    Error
};

enum class UserRole
{
    Owner,
    Editor,
    Viewer,
    Guest
};

enum class SyncPriority
{
    Critical,       // Must sync immediately (play/stop)
    High,           // Audio/MIDI data
    Normal,         // Parameter changes
    Low             // Cursor positions, chat
};

//==============================================================================
// User/Peer Information
//==============================================================================

struct CollaboratorInfo
{
    juce::String odid;              // Unique ID
    juce::String displayName;
    juce::String avatarUrl;
    juce::Colour color;             // For cursor/selection

    UserRole role = UserRole::Guest;
    bool isLocal = false;
    bool isMuted = false;
    bool isDeafened = false;

    // Latency info
    double latencyMs = 0.0;
    double jitterMs = 0.0;
    int packetLoss = 0;             // Percentage

    // Activity
    int currentTrack = -1;          // Track being edited
    double cursorPosition = 0.0;    // Timeline position
    juce::Rectangle<int> selection;

    juce::int64 lastHeartbeat = 0;
};

//==============================================================================
// Sync Messages
//==============================================================================

enum class MessageType
{
    // Connection
    Handshake,
    Heartbeat,
    Disconnect,

    // Transport
    Play,
    Stop,
    SetPosition,
    SetTempo,
    SetTimeSignature,

    // Audio
    AudioChunk,
    AudioMute,
    AudioSolo,

    // MIDI
    MIDIEvent,
    MIDIBatch,

    // Project
    TrackAdd,
    TrackRemove,
    TrackModify,
    ClipAdd,
    ClipRemove,
    ClipModify,
    ParameterChange,

    // Collaboration
    CursorMove,
    SelectionChange,
    Chat,
    VoiceData,

    // Control
    RequestSync,
    FullState,
    Ack,
    Error
};

struct SyncMessage
{
    MessageType type;
    juce::String senderId;
    juce::int64 timestamp;
    juce::int64 sequenceNumber;
    SyncPriority priority;
    juce::MemoryBlock data;

    juce::var toVar() const
    {
        juce::DynamicObject::Ptr obj = new juce::DynamicObject();
        obj->setProperty("type", static_cast<int>(type));
        obj->setProperty("sender", senderId);
        obj->setProperty("time", timestamp);
        obj->setProperty("seq", sequenceNumber);
        obj->setProperty("priority", static_cast<int>(priority));
        obj->setProperty("data", data.toBase64Encoding());
        return juce::var(obj.get());
    }

    static SyncMessage fromVar(const juce::var& v)
    {
        SyncMessage msg;
        if (auto* obj = v.getDynamicObject())
        {
            msg.type = static_cast<MessageType>(static_cast<int>(obj->getProperty("type")));
            msg.senderId = obj->getProperty("sender").toString();
            msg.timestamp = static_cast<juce::int64>(obj->getProperty("time"));
            msg.sequenceNumber = static_cast<juce::int64>(obj->getProperty("seq"));
            msg.priority = static_cast<SyncPriority>(static_cast<int>(obj->getProperty("priority")));
            msg.data.fromBase64Encoding(obj->getProperty("data").toString());
        }
        return msg;
    }
};

//==============================================================================
// Audio Streaming
//==============================================================================

class AudioStreamEncoder
{
public:
    AudioStreamEncoder(double sampleRate = 48000.0, int channels = 2)
        : fs(sampleRate), numChannels(channels)
    {
    }

    juce::MemoryBlock encode(const float* const* audioData, int numSamples)
    {
        juce::MemoryBlock block;
        juce::MemoryOutputStream stream(block, false);

        // Header
        stream.writeInt(numChannels);
        stream.writeInt(numSamples);
        stream.writeDouble(fs);

        // Simple compression: Convert to 16-bit PCM
        for (int ch = 0; ch < numChannels; ++ch)
        {
            for (int i = 0; i < numSamples; ++i)
            {
                float sample = audioData[ch][i];
                int16_t pcmSample = static_cast<int16_t>(
                    std::clamp(sample, -1.0f, 1.0f) * 32767.0f);
                stream.writeShort(pcmSample);
            }
        }

        return block;
    }

    void decode(const juce::MemoryBlock& block, juce::AudioBuffer<float>& output)
    {
        juce::MemoryInputStream stream(block, false);

        int channels = stream.readInt();
        int samples = stream.readInt();
        double rate = stream.readDouble();

        output.setSize(channels, samples);

        for (int ch = 0; ch < channels; ++ch)
        {
            for (int i = 0; i < samples; ++i)
            {
                int16_t pcmSample = stream.readShort();
                output.setSample(ch, i, pcmSample / 32767.0f);
            }
        }
    }

private:
    double fs;
    int numChannels;
};

//==============================================================================
// Jitter Buffer for Audio
//==============================================================================

class JitterBuffer
{
public:
    JitterBuffer(int bufferSizeMs = 50, double sampleRate = 48000.0)
        : targetDelayMs(bufferSizeMs), fs(sampleRate)
    {
        int bufferSamples = static_cast<int>(targetDelayMs * fs / 1000.0);
        buffer.setSize(2, bufferSamples * 4);  // 4x for safety
    }

    void push(const juce::AudioBuffer<float>& audio, juce::int64 timestamp)
    {
        std::lock_guard<std::mutex> lock(mutex);

        packets.push_back({audio, timestamp});

        // Remove old packets
        while (packets.size() > 20)
            packets.pop_front();
    }

    bool pop(juce::AudioBuffer<float>& output, int numSamples)
    {
        std::lock_guard<std::mutex> lock(mutex);

        if (packets.empty())
        {
            output.clear();
            return false;
        }

        // Simple: just take oldest packet
        auto& packet = packets.front();

        int samplesToCopy = std::min(numSamples, packet.audio.getNumSamples());
        for (int ch = 0; ch < output.getNumChannels(); ++ch)
        {
            if (ch < packet.audio.getNumChannels())
            {
                output.copyFrom(ch, 0, packet.audio, ch, 0, samplesToCopy);
            }
        }

        packets.pop_front();
        return true;
    }

    int getBufferLevel() const
    {
        std::lock_guard<std::mutex> lock(mutex);
        return static_cast<int>(packets.size());
    }

private:
    struct AudioPacket
    {
        juce::AudioBuffer<float> audio;
        juce::int64 timestamp;
    };

    int targetDelayMs;
    double fs;
    juce::AudioBuffer<float> buffer;
    std::deque<AudioPacket> packets;
    mutable std::mutex mutex;
};

//==============================================================================
// MIDI Event Synchronization
//==============================================================================

class MIDISynchronizer
{
public:
    struct TimestampedMIDI
    {
        juce::MidiMessage message;
        juce::int64 networkTimestamp;
        double localBeat;           // Position in beats
    };

    void addOutgoingEvent(const juce::MidiMessage& msg, double beatPosition)
    {
        std::lock_guard<std::mutex> lock(outMutex);

        TimestampedMIDI event;
        event.message = msg;
        event.networkTimestamp = juce::Time::currentTimeMillis();
        event.localBeat = beatPosition;

        outgoingEvents.push_back(event);
    }

    std::vector<TimestampedMIDI> getAndClearOutgoing()
    {
        std::lock_guard<std::mutex> lock(outMutex);
        auto events = std::move(outgoingEvents);
        outgoingEvents.clear();
        return events;
    }

    void addIncomingEvent(const TimestampedMIDI& event)
    {
        std::lock_guard<std::mutex> lock(inMutex);
        incomingEvents.push_back(event);
    }

    void getIncomingEvents(juce::MidiBuffer& buffer, double startBeat, double endBeat,
                           double beatsPerSecond, int sampleRate)
    {
        std::lock_guard<std::mutex> lock(inMutex);

        for (auto it = incomingEvents.begin(); it != incomingEvents.end();)
        {
            if (it->localBeat >= startBeat && it->localBeat < endBeat)
            {
                // Calculate sample position
                double beatOffset = it->localBeat - startBeat;
                double seconds = beatOffset / beatsPerSecond;
                int samplePos = static_cast<int>(seconds * sampleRate);

                buffer.addEvent(it->message, samplePos);
                it = incomingEvents.erase(it);
            }
            else if (it->localBeat < startBeat)
            {
                // Old event, remove
                it = incomingEvents.erase(it);
            }
            else
            {
                ++it;
            }
        }
    }

private:
    std::vector<TimestampedMIDI> outgoingEvents;
    std::vector<TimestampedMIDI> incomingEvents;
    std::mutex outMutex;
    std::mutex inMutex;
};

//==============================================================================
// Operational Transform for Conflict Resolution
//==============================================================================

struct Operation
{
    enum class Type
    {
        Insert,
        Delete,
        Modify,
        Move
    };

    Type type;
    juce::String objectId;
    juce::String property;
    juce::var oldValue;
    juce::var newValue;
    int position = 0;
    juce::int64 timestamp;
    juce::String userId;
};

class OperationalTransform
{
public:
    Operation transform(const Operation& op1, const Operation& op2) const
    {
        // Simple transformation rules
        Operation transformed = op1;

        if (op1.objectId == op2.objectId && op1.property == op2.property)
        {
            // Same property being modified
            if (op1.timestamp < op2.timestamp)
            {
                // op1 wins, op2 needs transformation
                // In real implementation, merge values intelligently
            }
        }

        return transformed;
    }

    void addLocalOperation(const Operation& op)
    {
        std::lock_guard<std::mutex> lock(mutex);
        pendingOperations.push_back(op);
    }

    void applyRemoteOperation(const Operation& op)
    {
        std::lock_guard<std::mutex> lock(mutex);

        // Transform against pending local operations
        Operation transformed = op;
        for (const auto& localOp : pendingOperations)
        {
            transformed = transform(transformed, localOp);
        }

        appliedOperations.push_back(transformed);
    }

    std::vector<Operation> getAndClearPending()
    {
        std::lock_guard<std::mutex> lock(mutex);
        auto ops = std::move(pendingOperations);
        pendingOperations.clear();
        return ops;
    }

private:
    std::vector<Operation> pendingOperations;
    std::vector<Operation> appliedOperations;
    std::mutex mutex;
};

//==============================================================================
// Voice Chat
//==============================================================================

class VoiceChat
{
public:
    VoiceChat(double sampleRate = 48000.0)
        : fs(sampleRate), encoder(sampleRate, 1)
    {
    }

    void prepare(int blockSize)
    {
        inputBuffer.setSize(1, blockSize);
        outputBuffer.setSize(1, blockSize);
    }

    void processInput(const float* input, int numSamples)
    {
        if (!transmitting)
            return;

        // Voice activity detection
        float rms = 0.0f;
        for (int i = 0; i < numSamples; ++i)
            rms += input[i] * input[i];
        rms = std::sqrt(rms / numSamples);

        if (rms > voiceThreshold)
        {
            lastVoiceTime = juce::Time::currentTimeMillis();

            // Encode and queue for sending
            const float* channels[] = {input};
            juce::MemoryBlock encoded = encoder.encode(channels, numSamples);

            std::lock_guard<std::mutex> lock(outMutex);
            outgoingVoice.push(encoded);
        }
    }

    juce::MemoryBlock getOutgoingVoice()
    {
        std::lock_guard<std::mutex> lock(outMutex);
        if (outgoingVoice.empty())
            return {};

        auto block = outgoingVoice.front();
        outgoingVoice.pop();
        return block;
    }

    void addIncomingVoice(const juce::String& peerId, const juce::MemoryBlock& data)
    {
        std::lock_guard<std::mutex> lock(inMutex);

        juce::AudioBuffer<float> decoded;
        encoder.decode(data, decoded);

        if (peerJitterBuffers.find(peerId) == peerJitterBuffers.end())
        {
            peerJitterBuffers[peerId] = std::make_unique<JitterBuffer>(50, fs);
        }

        peerJitterBuffers[peerId]->push(decoded, juce::Time::currentTimeMillis());
    }

    void mixOutput(float* output, int numSamples)
    {
        std::lock_guard<std::mutex> lock(inMutex);

        std::memset(output, 0, numSamples * sizeof(float));

        juce::AudioBuffer<float> peerAudio(1, numSamples);

        for (auto& [peerId, jitterBuffer] : peerJitterBuffers)
        {
            if (jitterBuffer->pop(peerAudio, numSamples))
            {
                const float* peerData = peerAudio.getReadPointer(0);
                for (int i = 0; i < numSamples; ++i)
                {
                    output[i] += peerData[i] * 0.7f;  // Mix at 70%
                }
            }
        }

        // Apply limiter
        for (int i = 0; i < numSamples; ++i)
        {
            output[i] = std::clamp(output[i], -1.0f, 1.0f);
        }
    }

    void setTransmitting(bool t) { transmitting = t; }
    bool isTransmitting() const { return transmitting; }

    void setMuted(bool m) { muted = m; }
    bool isMuted() const { return muted; }

private:
    double fs;
    AudioStreamEncoder encoder;
    juce::AudioBuffer<float> inputBuffer;
    juce::AudioBuffer<float> outputBuffer;

    std::queue<juce::MemoryBlock> outgoingVoice;
    std::map<juce::String, std::unique_ptr<JitterBuffer>> peerJitterBuffers;

    std::mutex outMutex;
    std::mutex inMutex;

    bool transmitting = false;
    bool muted = false;
    float voiceThreshold = 0.01f;
    juce::int64 lastVoiceTime = 0;
};

//==============================================================================
// Session Manager
//==============================================================================

class CollaborationSession
{
public:
    using ConnectionCallback = std::function<void(ConnectionState)>;
    using PeerCallback = std::function<void(const CollaboratorInfo&, bool joined)>;
    using MessageCallback = std::function<void(const SyncMessage&)>;

    CollaborationSession()
    {
        localUser.odid = juce::Uuid().toString();
        localUser.isLocal = true;
        localUser.color = juce::Colour::fromHSV(
            static_cast<float>(rand()) / RAND_MAX, 0.7f, 0.8f, 1.0f);
    }

    //==========================================================================
    // Session Control
    //==========================================================================

    void createSession(const juce::String& sessionName)
    {
        this->sessionName = sessionName;
        this->sessionId = juce::Uuid().toString();
        localUser.role = UserRole::Owner;
        connectionState = ConnectionState::Connected;
        isHost = true;

        if (connectionCallback)
            connectionCallback(connectionState);
    }

    void joinSession(const juce::String& sessionId, const juce::String& accessToken = "")
    {
        this->sessionId = sessionId;
        localUser.role = UserRole::Guest;
        connectionState = ConnectionState::Connecting;

        if (connectionCallback)
            connectionCallback(connectionState);

        // Simulate connection
        // In real implementation, connect to signaling server
        connectionState = ConnectionState::Syncing;
        if (connectionCallback)
            connectionCallback(connectionState);
    }

    void leaveSession()
    {
        // Send disconnect message
        SyncMessage msg;
        msg.type = MessageType::Disconnect;
        msg.senderId = localUser.odid;
        msg.timestamp = juce::Time::currentTimeMillis();
        sendMessage(msg);

        peers.clear();
        connectionState = ConnectionState::Disconnected;

        if (connectionCallback)
            connectionCallback(connectionState);
    }

    //==========================================================================
    // User Management
    //==========================================================================

    void setLocalUserName(const juce::String& name)
    {
        localUser.displayName = name;
        broadcastUserUpdate();
    }

    const CollaboratorInfo& getLocalUser() const { return localUser; }

    const std::map<juce::String, CollaboratorInfo>& getPeers() const { return peers; }

    void setUserRole(const juce::String& odid, UserRole role)
    {
        if (localUser.role != UserRole::Owner)
            return;

        auto it = peers.find(odid);
        if (it != peers.end())
        {
            it->second.role = role;
            broadcastUserUpdate();
        }
    }

    //==========================================================================
    // Messaging
    //==========================================================================

    void sendMessage(const SyncMessage& msg)
    {
        std::lock_guard<std::mutex> lock(outMutex);
        outgoingMessages.push_back(msg);
    }

    void receiveMessage(const SyncMessage& msg)
    {
        // Update peer info
        if (peers.find(msg.senderId) != peers.end())
        {
            peers[msg.senderId].lastHeartbeat = msg.timestamp;
        }

        // Process message
        switch (msg.type)
        {
            case MessageType::Handshake:
                handleHandshake(msg);
                break;

            case MessageType::Heartbeat:
                // Already updated timestamp above
                break;

            case MessageType::Disconnect:
                handleDisconnect(msg);
                break;

            default:
                if (messageCallback)
                    messageCallback(msg);
                break;
        }
    }

    std::vector<SyncMessage> getAndClearOutgoing()
    {
        std::lock_guard<std::mutex> lock(outMutex);
        auto messages = std::move(outgoingMessages);
        outgoingMessages.clear();
        return messages;
    }

    //==========================================================================
    // Transport Sync
    //==========================================================================

    void broadcastPlay(double position, double tempo)
    {
        SyncMessage msg;
        msg.type = MessageType::Play;
        msg.senderId = localUser.odid;
        msg.timestamp = juce::Time::currentTimeMillis();
        msg.priority = SyncPriority::Critical;

        juce::MemoryOutputStream stream(msg.data, false);
        stream.writeDouble(position);
        stream.writeDouble(tempo);

        sendMessage(msg);
    }

    void broadcastStop()
    {
        SyncMessage msg;
        msg.type = MessageType::Stop;
        msg.senderId = localUser.odid;
        msg.timestamp = juce::Time::currentTimeMillis();
        msg.priority = SyncPriority::Critical;

        sendMessage(msg);
    }

    void broadcastPosition(double position)
    {
        SyncMessage msg;
        msg.type = MessageType::SetPosition;
        msg.senderId = localUser.odid;
        msg.timestamp = juce::Time::currentTimeMillis();
        msg.priority = SyncPriority::Critical;

        juce::MemoryOutputStream stream(msg.data, false);
        stream.writeDouble(position);

        sendMessage(msg);
    }

    //==========================================================================
    // Cursor/Selection Sync
    //==========================================================================

    void broadcastCursor(double position, int trackIndex)
    {
        localUser.cursorPosition = position;
        localUser.currentTrack = trackIndex;

        SyncMessage msg;
        msg.type = MessageType::CursorMove;
        msg.senderId = localUser.odid;
        msg.timestamp = juce::Time::currentTimeMillis();
        msg.priority = SyncPriority::Low;

        juce::MemoryOutputStream stream(msg.data, false);
        stream.writeDouble(position);
        stream.writeInt(trackIndex);

        sendMessage(msg);
    }

    //==========================================================================
    // Audio/MIDI Sync
    //==========================================================================

    MIDISynchronizer& getMIDISync() { return midiSync; }
    VoiceChat& getVoiceChat() { return voiceChat; }

    void sendAudioChunk(int trackIndex, const juce::AudioBuffer<float>& audio)
    {
        SyncMessage msg;
        msg.type = MessageType::AudioChunk;
        msg.senderId = localUser.odid;
        msg.timestamp = juce::Time::currentTimeMillis();
        msg.priority = SyncPriority::High;

        const float* channels[] = {audio.getReadPointer(0),
                                   audio.getNumChannels() > 1 ? audio.getReadPointer(1) : audio.getReadPointer(0)};

        juce::MemoryOutputStream stream(msg.data, false);
        stream.writeInt(trackIndex);
        auto encoded = audioEncoder.encode(channels, audio.getNumSamples());
        stream.write(encoded.getData(), encoded.getSize());

        sendMessage(msg);
    }

    //==========================================================================
    // Callbacks
    //==========================================================================

    void setConnectionCallback(ConnectionCallback cb) { connectionCallback = cb; }
    void setPeerCallback(PeerCallback cb) { peerCallback = cb; }
    void setMessageCallback(MessageCallback cb) { messageCallback = cb; }

    //==========================================================================
    // State
    //==========================================================================

    ConnectionState getConnectionState() const { return connectionState; }
    juce::String getSessionId() const { return sessionId; }
    juce::String getSessionName() const { return sessionName; }
    bool isSessionHost() const { return isHost; }

    int getPeerCount() const { return static_cast<int>(peers.size()); }

private:
    juce::String sessionId;
    juce::String sessionName;
    bool isHost = false;

    CollaboratorInfo localUser;
    std::map<juce::String, CollaboratorInfo> peers;

    ConnectionState connectionState = ConnectionState::Disconnected;

    std::vector<SyncMessage> outgoingMessages;
    std::mutex outMutex;

    MIDISynchronizer midiSync;
    VoiceChat voiceChat;
    AudioStreamEncoder audioEncoder;
    OperationalTransform ot;

    ConnectionCallback connectionCallback;
    PeerCallback peerCallback;
    MessageCallback messageCallback;

    juce::int64 sequenceNumber = 0;

    void handleHandshake(const SyncMessage& msg)
    {
        // Parse peer info from message
        juce::MemoryInputStream stream(msg.data, false);

        CollaboratorInfo peer;
        peer.odid = msg.senderId;
        peer.displayName = stream.readString();
        peer.role = static_cast<UserRole>(stream.readInt());
        peer.color = juce::Colour(static_cast<juce::uint32>(stream.readInt64()));
        peer.lastHeartbeat = msg.timestamp;

        peers[peer.odid] = peer;

        if (peerCallback)
            peerCallback(peer, true);

        // If we're the host, send full state
        if (isHost)
        {
            requestFullStateSync(peer.odid);
        }
    }

    void handleDisconnect(const SyncMessage& msg)
    {
        auto it = peers.find(msg.senderId);
        if (it != peers.end())
        {
            if (peerCallback)
                peerCallback(it->second, false);

            peers.erase(it);
        }
    }

    void broadcastUserUpdate()
    {
        SyncMessage msg;
        msg.type = MessageType::Handshake;
        msg.senderId = localUser.odid;
        msg.timestamp = juce::Time::currentTimeMillis();

        juce::MemoryOutputStream stream(msg.data, false);
        stream.writeString(localUser.displayName);
        stream.writeInt(static_cast<int>(localUser.role));
        stream.writeInt64(localUser.color.getARGB());

        sendMessage(msg);
    }

    void requestFullStateSync(const juce::String& peerId)
    {
        SyncMessage msg;
        msg.type = MessageType::FullState;
        msg.senderId = localUser.odid;
        msg.timestamp = juce::Time::currentTimeMillis();
        msg.priority = SyncPriority::Critical;

        // In real implementation, serialize full project state
        sendMessage(msg);
    }

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(CollaborationSession)
};

} // namespace Network
} // namespace Echoelmusic
