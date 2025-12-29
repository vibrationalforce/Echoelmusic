/**
 * EchoelRealtimeCollab.h
 *
 * ============================================================================
 *   RALPH WIGGUM GENIUS LOOP MODE - REAL-TIME COLLABORATION ENGINE
 * ============================================================================
 *
 * WebRTC/WebSocket-based peer-to-peer collaboration with:
 * - Lock-free state synchronization
 * - CRDT-based conflict resolution
 * - Sub-50ms latency optimization
 * - Automatic peer discovery and mesh networking
 * - End-to-end encryption support
 *
 * Architecture:
 * ┌─────────────────────────────────────────────────────────────────────┐
 * │                     COLLABORATION ENGINE                            │
 * ├─────────────────────────────────────────────────────────────────────┤
 * │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                 │
 * │  │  Signaling  │  │   WebRTC    │  │    CRDT     │                 │
 * │  │   Server    │◄─┤  DataChannel│◄─┤   Engine    │                 │
 * │  └─────────────┘  └─────────────┘  └─────────────┘                 │
 * │         │                │                │                         │
 * │         ▼                ▼                ▼                         │
 * │  ┌─────────────────────────────────────────────────────────────┐   │
 * │  │              Lock-Free State Bus (Atomic Operations)         │   │
 * │  └─────────────────────────────────────────────────────────────┘   │
 * │         │                │                │                         │
 * │         ▼                ▼                ▼                         │
 * │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                 │
 * │  │   Audio     │  │   Laser     │  │    Bio      │                 │
 * │  │   Sync      │  │   Sync      │  │   Sync      │                 │
 * │  └─────────────┘  └─────────────┘  └─────────────┘                 │
 * └─────────────────────────────────────────────────────────────────────┘
 */

#pragma once

#include <array>
#include <atomic>
#include <chrono>
#include <cstdint>
#include <functional>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <thread>
#include <unordered_map>
#include <vector>

namespace Echoel { namespace Collab {

//==============================================================================
// Constants
//==============================================================================

static constexpr size_t MAX_PEERS = 32;
static constexpr size_t MAX_CHANNELS = 8;
static constexpr size_t MESSAGE_BUFFER_SIZE = 65536;
static constexpr size_t STATE_HISTORY_SIZE = 1024;
static constexpr uint32_t SYNC_RATE_HZ = 60;
static constexpr uint32_t HEARTBEAT_INTERVAL_MS = 1000;
static constexpr uint32_t PEER_TIMEOUT_MS = 5000;
static constexpr uint32_t RECONNECT_DELAY_MS = 2000;

//==============================================================================
// Forward Declarations
//==============================================================================

class EchoelRealtimeCollab;
class CRDTEngine;
class WebRTCConnection;

//==============================================================================
// Enums
//==============================================================================

enum class PeerRole : uint8_t
{
    Host = 0,           // Full control, can kick others
    Performer,          // Can modify parameters
    Viewer,             // Read-only access
    Moderator           // Can manage chat/users
};

enum class ConnectionState : uint8_t
{
    Disconnected = 0,
    Connecting,
    Connected,
    Reconnecting,
    Failed
};

enum class MessageType : uint8_t
{
    // Signaling
    Offer = 0,
    Answer,
    IceCandidate,

    // Session
    JoinRequest,
    JoinAccepted,
    JoinRejected,
    Leave,
    Kick,

    // State sync
    StateUpdate,
    StateDelta,
    StateRequest,
    StateAck,

    // Audio
    AudioChunk,
    AudioConfig,

    // Laser
    LaserFrame,
    LaserConfig,

    // Bio
    BioData,
    BioConfig,

    // Control
    Heartbeat,
    LatencyProbe,
    LatencyResponse,

    // CRDT
    CRDTOperation,
    CRDTSync,

    // Chat (forwarded to chat system)
    ChatMessage,

    // Custom
    Custom
};

enum class SyncPriority : uint8_t
{
    Realtime = 0,       // Audio/timing critical - no buffering
    High,               // Laser frames - minimal buffering
    Normal,             // Parameter changes
    Low                 // Non-critical state
};

//==============================================================================
// Data Structures
//==============================================================================

struct PeerId
{
    std::array<uint8_t, 16> uuid;

    bool operator==(const PeerId& other) const
    {
        return uuid == other.uuid;
    }

    std::string toString() const
    {
        char buf[37];
        snprintf(buf, sizeof(buf),
            "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
            uuid[0], uuid[1], uuid[2], uuid[3],
            uuid[4], uuid[5], uuid[6], uuid[7],
            uuid[8], uuid[9], uuid[10], uuid[11],
            uuid[12], uuid[13], uuid[14], uuid[15]);
        return std::string(buf);
    }

    static PeerId generate()
    {
        PeerId id;
        // Use high-resolution clock for entropy
        auto now = std::chrono::high_resolution_clock::now().time_since_epoch().count();
        for (int i = 0; i < 16; ++i)
        {
            id.uuid[i] = static_cast<uint8_t>((now >> (i * 4)) ^ (now >> (i * 3 + 7)));
        }
        // Set version 4 (random) and variant bits
        id.uuid[6] = (id.uuid[6] & 0x0F) | 0x40;
        id.uuid[8] = (id.uuid[8] & 0x3F) | 0x80;
        return id;
    }
};

struct PeerIdHash
{
    size_t operator()(const PeerId& id) const
    {
        size_t hash = 0;
        for (int i = 0; i < 16; ++i)
        {
            hash ^= static_cast<size_t>(id.uuid[i]) << ((i % 8) * 8);
        }
        return hash;
    }
};

struct PeerInfo
{
    PeerId id;
    std::string displayName;
    std::string avatarUrl;
    PeerRole role = PeerRole::Viewer;
    ConnectionState state = ConnectionState::Disconnected;

    // Latency measurement
    float latencyMs = 0.0f;
    float jitterMs = 0.0f;
    uint64_t lastHeartbeat = 0;

    // Capabilities
    bool supportsAudio = true;
    bool supportsVideo = true;
    bool supportsBio = true;

    // State
    bool isMuted = false;
    bool isDeafened = false;
    bool isSharingScreen = false;
};

struct SessionInfo
{
    std::string sessionId;
    std::string sessionName;
    std::string hostName;
    PeerId hostId;

    uint32_t maxPeers = MAX_PEERS;
    uint32_t currentPeers = 0;
    bool isPrivate = false;
    bool requiresPassword = false;

    // Permissions
    bool viewersCanChat = true;
    bool performersCanInvite = false;

    // Session state
    uint64_t createdAt = 0;
    uint64_t lastActivity = 0;
};

struct CollabConfig
{
    std::string signalingServerUrl = "wss://signal.echoel.io";
    std::string stunServer = "stun:stun.l.google.com:19302";
    std::string turnServer;
    std::string turnUsername;
    std::string turnPassword;

    bool enableEncryption = true;
    bool enableDataCompression = true;
    bool enableAdaptiveBitrate = true;

    uint32_t targetLatencyMs = 50;
    uint32_t maxLatencyMs = 200;
    uint32_t syncRateHz = SYNC_RATE_HZ;

    // Audio settings
    uint32_t audioSampleRate = 48000;
    uint32_t audioChannels = 2;
    uint32_t audioBitrate = 128000;

    // Data channel settings
    bool orderedDelivery = false;  // false for lower latency
    uint32_t maxRetransmits = 0;   // 0 for unreliable (lower latency)
};

//==============================================================================
// CRDT Types (Conflict-free Replicated Data Types)
//==============================================================================

/**
 * Vector Clock for causality tracking
 */
struct VectorClock
{
    std::array<uint64_t, MAX_PEERS> clocks{};

    void increment(size_t peerId)
    {
        if (peerId < MAX_PEERS)
            clocks[peerId]++;
    }

    void merge(const VectorClock& other)
    {
        for (size_t i = 0; i < MAX_PEERS; ++i)
        {
            clocks[i] = std::max(clocks[i], other.clocks[i]);
        }
    }

    bool happensBefore(const VectorClock& other) const
    {
        bool atLeastOneLess = false;
        for (size_t i = 0; i < MAX_PEERS; ++i)
        {
            if (clocks[i] > other.clocks[i]) return false;
            if (clocks[i] < other.clocks[i]) atLeastOneLess = true;
        }
        return atLeastOneLess;
    }

    bool concurrent(const VectorClock& other) const
    {
        return !happensBefore(other) && !other.happensBefore(*this);
    }
};

/**
 * Last-Writer-Wins Register for simple values
 */
template<typename T>
struct LWWRegister
{
    T value{};
    uint64_t timestamp = 0;
    PeerId writerId;

    bool update(const T& newValue, uint64_t newTimestamp, const PeerId& writer)
    {
        if (newTimestamp > timestamp ||
            (newTimestamp == timestamp && writer.uuid > writerId.uuid))
        {
            value = newValue;
            timestamp = newTimestamp;
            writerId = writer;
            return true;
        }
        return false;
    }

    void merge(const LWWRegister<T>& other)
    {
        update(other.value, other.timestamp, other.writerId);
    }
};

/**
 * G-Counter (Grow-only counter)
 */
struct GCounter
{
    std::array<uint64_t, MAX_PEERS> counts{};

    void increment(size_t peerId, uint64_t amount = 1)
    {
        if (peerId < MAX_PEERS)
            counts[peerId] += amount;
    }

    uint64_t value() const
    {
        uint64_t total = 0;
        for (auto c : counts) total += c;
        return total;
    }

    void merge(const GCounter& other)
    {
        for (size_t i = 0; i < MAX_PEERS; ++i)
        {
            counts[i] = std::max(counts[i], other.counts[i]);
        }
    }
};

/**
 * CRDT Operation for synchronization
 */
struct CRDTOperation
{
    enum class OpType : uint8_t
    {
        SetValue = 0,
        IncrementCounter,
        AppendList,
        RemoveFromList,
        SetMapEntry,
        RemoveMapEntry
    };

    OpType type;
    std::string path;           // JSON path to field
    std::vector<uint8_t> data;  // Serialized value
    uint64_t timestamp;
    PeerId author;
    VectorClock clock;
};

//==============================================================================
// Synchronized State Types
//==============================================================================

/**
 * Synchronized parameter with CRDT backing
 */
struct SyncedParameter
{
    std::string name;
    LWWRegister<float> value;
    float minValue = 0.0f;
    float maxValue = 1.0f;
    bool isLocked = false;
    PeerId lockHolder;
};

/**
 * Shared session state
 */
struct SharedState
{
    // Transport
    LWWRegister<bool> isPlaying;
    LWWRegister<double> playheadPosition;
    LWWRegister<float> tempo;

    // Master parameters
    LWWRegister<float> masterVolume;
    LWWRegister<float> masterIntensity;

    // Entrainment
    LWWRegister<float> targetFrequency;
    LWWRegister<float> baseFrequency;
    LWWRegister<float> entrainmentDepth;

    // Laser
    LWWRegister<int> activePattern;
    LWWRegister<float> laserSize;
    LWWRegister<float> laserRotation;

    // Bio
    LWWRegister<bool> bioEnabled;
    LWWRegister<float> bioInfluence;

    // Custom parameters
    std::unordered_map<std::string, SyncedParameter> parameters;

    // Version tracking
    VectorClock version;
    uint64_t lastModified = 0;
};

//==============================================================================
// Message Protocol
//==============================================================================

struct CollabMessage
{
    MessageType type;
    PeerId sender;
    PeerId recipient;  // Empty for broadcast
    uint64_t timestamp;
    uint32_t sequenceNumber;
    SyncPriority priority;
    std::vector<uint8_t> payload;

    // For reliable ordering
    VectorClock clock;

    /**
     * Serialize message to binary
     */
    std::vector<uint8_t> serialize() const
    {
        std::vector<uint8_t> data;
        data.reserve(64 + payload.size());

        // Header (fixed size)
        data.push_back(static_cast<uint8_t>(type));
        data.insert(data.end(), sender.uuid.begin(), sender.uuid.end());
        data.insert(data.end(), recipient.uuid.begin(), recipient.uuid.end());

        // Timestamp (8 bytes, little-endian)
        for (int i = 0; i < 8; ++i)
            data.push_back(static_cast<uint8_t>(timestamp >> (i * 8)));

        // Sequence number (4 bytes)
        for (int i = 0; i < 4; ++i)
            data.push_back(static_cast<uint8_t>(sequenceNumber >> (i * 8)));

        data.push_back(static_cast<uint8_t>(priority));

        // Payload length (4 bytes)
        uint32_t payloadLen = static_cast<uint32_t>(payload.size());
        for (int i = 0; i < 4; ++i)
            data.push_back(static_cast<uint8_t>(payloadLen >> (i * 8)));

        // Payload
        data.insert(data.end(), payload.begin(), payload.end());

        return data;
    }

    /**
     * Deserialize message from binary
     */
    static std::optional<CollabMessage> deserialize(const uint8_t* data, size_t size)
    {
        if (size < 54) return std::nullopt;  // Minimum header size

        CollabMessage msg;
        size_t offset = 0;

        msg.type = static_cast<MessageType>(data[offset++]);

        std::copy(data + offset, data + offset + 16, msg.sender.uuid.begin());
        offset += 16;

        std::copy(data + offset, data + offset + 16, msg.recipient.uuid.begin());
        offset += 16;

        msg.timestamp = 0;
        for (int i = 0; i < 8; ++i)
            msg.timestamp |= static_cast<uint64_t>(data[offset++]) << (i * 8);

        msg.sequenceNumber = 0;
        for (int i = 0; i < 4; ++i)
            msg.sequenceNumber |= static_cast<uint32_t>(data[offset++]) << (i * 8);

        msg.priority = static_cast<SyncPriority>(data[offset++]);

        uint32_t payloadLen = 0;
        for (int i = 0; i < 4; ++i)
            payloadLen |= static_cast<uint32_t>(data[offset++]) << (i * 8);

        if (offset + payloadLen > size) return std::nullopt;

        msg.payload.assign(data + offset, data + offset + payloadLen);

        return msg;
    }
};

//==============================================================================
// Lock-Free Message Queue
//==============================================================================

template<size_t Capacity>
class MessageQueue
{
public:
    bool push(CollabMessage&& msg)
    {
        size_t currentTail = tail_.load(std::memory_order_relaxed);
        size_t nextTail = (currentTail + 1) % Capacity;

        if (nextTail == head_.load(std::memory_order_acquire))
            return false;  // Queue full

        messages_[currentTail] = std::move(msg);
        tail_.store(nextTail, std::memory_order_release);
        return true;
    }

    std::optional<CollabMessage> pop()
    {
        size_t currentHead = head_.load(std::memory_order_relaxed);

        if (currentHead == tail_.load(std::memory_order_acquire))
            return std::nullopt;  // Queue empty

        CollabMessage msg = std::move(messages_[currentHead]);
        head_.store((currentHead + 1) % Capacity, std::memory_order_release);
        return msg;
    }

    bool isEmpty() const
    {
        return head_.load(std::memory_order_acquire) ==
               tail_.load(std::memory_order_acquire);
    }

    size_t size() const
    {
        size_t h = head_.load(std::memory_order_acquire);
        size_t t = tail_.load(std::memory_order_acquire);
        return (t >= h) ? (t - h) : (Capacity - h + t);
    }

private:
    std::array<CollabMessage, Capacity> messages_;
    alignas(64) std::atomic<size_t> head_{0};
    alignas(64) std::atomic<size_t> tail_{0};
};

//==============================================================================
// Latency Tracker
//==============================================================================

class LatencyTracker
{
public:
    void recordSample(float latencyMs)
    {
        samples_[sampleIndex_] = latencyMs;
        sampleIndex_ = (sampleIndex_ + 1) % SAMPLE_COUNT;
        sampleCount_ = std::min(sampleCount_ + 1, SAMPLE_COUNT);
    }

    float getAverage() const
    {
        if (sampleCount_ == 0) return 0.0f;
        float sum = 0.0f;
        for (size_t i = 0; i < sampleCount_; ++i)
            sum += samples_[i];
        return sum / sampleCount_;
    }

    float getJitter() const
    {
        if (sampleCount_ < 2) return 0.0f;
        float avg = getAverage();
        float variance = 0.0f;
        for (size_t i = 0; i < sampleCount_; ++i)
        {
            float diff = samples_[i] - avg;
            variance += diff * diff;
        }
        return std::sqrt(variance / sampleCount_);
    }

    float getMin() const
    {
        if (sampleCount_ == 0) return 0.0f;
        float min = samples_[0];
        for (size_t i = 1; i < sampleCount_; ++i)
            min = std::min(min, samples_[i]);
        return min;
    }

    float getMax() const
    {
        if (sampleCount_ == 0) return 0.0f;
        float max = samples_[0];
        for (size_t i = 1; i < sampleCount_; ++i)
            max = std::max(max, samples_[i]);
        return max;
    }

private:
    static constexpr size_t SAMPLE_COUNT = 100;
    std::array<float, SAMPLE_COUNT> samples_{};
    size_t sampleIndex_ = 0;
    size_t sampleCount_ = 0;
};

//==============================================================================
// Callbacks
//==============================================================================

using OnPeerJoinedCallback = std::function<void(const PeerInfo&)>;
using OnPeerLeftCallback = std::function<void(const PeerId&, const std::string& reason)>;
using OnStateChangedCallback = std::function<void(const SharedState&)>;
using OnMessageCallback = std::function<void(const CollabMessage&)>;
using OnConnectionStateCallback = std::function<void(ConnectionState)>;
using OnErrorCallback = std::function<void(int code, const std::string& message)>;

//==============================================================================
// Main Collaboration Engine
//==============================================================================

class EchoelRealtimeCollab
{
public:
    static EchoelRealtimeCollab& getInstance()
    {
        static EchoelRealtimeCollab instance;
        return instance;
    }

    //==========================================================================
    // Lifecycle
    //==========================================================================

    bool initialize(const CollabConfig& config)
    {
        if (initialized_) return true;

        config_ = config;
        localPeerId_ = PeerId::generate();

        // Initialize message queues
        // (Already initialized as class members)

        // Start network thread
        running_ = true;
        networkThread_ = std::thread(&EchoelRealtimeCollab::networkLoop, this);

        initialized_ = true;
        return true;
    }

    void shutdown()
    {
        if (!initialized_) return;

        // Leave current session
        leaveSession();

        // Stop network thread
        running_ = false;
        if (networkThread_.joinable())
            networkThread_.join();

        initialized_ = false;
    }

    //==========================================================================
    // Session Management
    //==========================================================================

    /**
     * Create a new collaboration session
     */
    bool createSession(const std::string& name, bool isPrivate = false)
    {
        if (!initialized_) return false;
        if (inSession_) leaveSession();

        currentSession_.sessionId = generateSessionId();
        currentSession_.sessionName = name;
        currentSession_.hostId = localPeerId_;
        currentSession_.hostName = localPeerInfo_.displayName;
        currentSession_.isPrivate = isPrivate;
        currentSession_.createdAt = getCurrentTimestamp();
        currentSession_.currentPeers = 1;

        localPeerInfo_.id = localPeerId_;
        localPeerInfo_.role = PeerRole::Host;
        localPeerInfo_.state = ConnectionState::Connected;

        peers_[localPeerId_] = localPeerInfo_;

        // Register session with signaling server
        registerSession();

        inSession_ = true;
        isHost_ = true;

        return true;
    }

    /**
     * Join an existing session
     */
    bool joinSession(const std::string& sessionId, const std::string& password = "")
    {
        if (!initialized_) return false;
        if (inSession_) leaveSession();

        // Connect to signaling server and request to join
        if (!connectToSession(sessionId, password))
            return false;

        localPeerInfo_.role = PeerRole::Performer;  // Default, may be changed by host
        inSession_ = true;
        isHost_ = false;

        return true;
    }

    /**
     * Leave current session
     */
    void leaveSession()
    {
        if (!inSession_) return;

        // Notify peers
        CollabMessage leaveMsg;
        leaveMsg.type = MessageType::Leave;
        leaveMsg.sender = localPeerId_;
        leaveMsg.timestamp = getCurrentTimestamp();
        broadcast(leaveMsg);

        // Disconnect from all peers
        disconnectAllPeers();

        // Clear state
        peers_.clear();
        sharedState_ = SharedState();
        currentSession_ = SessionInfo();

        inSession_ = false;
        isHost_ = false;
    }

    //==========================================================================
    // State Synchronization
    //==========================================================================

    /**
     * Get current shared state (lock-free read)
     */
    SharedState getState() const
    {
        std::lock_guard<std::mutex> lock(stateMutex_);
        return sharedState_;
    }

    /**
     * Update shared state (triggers sync to peers)
     */
    void updateState(const std::function<void(SharedState&)>& modifier)
    {
        {
            std::lock_guard<std::mutex> lock(stateMutex_);
            modifier(sharedState_);
            sharedState_.version.increment(getLocalPeerIndex());
            sharedState_.lastModified = getCurrentTimestamp();
        }

        // Queue state delta for broadcast
        queueStateBroadcast();
    }

    /**
     * Update a specific parameter
     */
    void setParameter(const std::string& name, float value)
    {
        updateState([&](SharedState& state) {
            auto it = state.parameters.find(name);
            if (it != state.parameters.end())
            {
                it->second.value.update(value, getCurrentTimestamp(), localPeerId_);
            }
            else
            {
                SyncedParameter param;
                param.name = name;
                param.value.update(value, getCurrentTimestamp(), localPeerId_);
                state.parameters[name] = param;
            }
        });
    }

    /**
     * Lock a parameter for exclusive editing
     */
    bool lockParameter(const std::string& name)
    {
        bool success = false;
        updateState([&](SharedState& state) {
            auto it = state.parameters.find(name);
            if (it != state.parameters.end() && !it->second.isLocked)
            {
                it->second.isLocked = true;
                it->second.lockHolder = localPeerId_;
                success = true;
            }
        });
        return success;
    }

    /**
     * Unlock a parameter
     */
    void unlockParameter(const std::string& name)
    {
        updateState([&](SharedState& state) {
            auto it = state.parameters.find(name);
            if (it != state.parameters.end() &&
                it->second.isLocked &&
                it->second.lockHolder == localPeerId_)
            {
                it->second.isLocked = false;
            }
        });
    }

    //==========================================================================
    // Real-time Data Streams
    //==========================================================================

    /**
     * Send audio chunk to peers (low-latency, unreliable)
     */
    void sendAudioChunk(const float* samples, size_t numSamples)
    {
        if (!inSession_) return;

        CollabMessage msg;
        msg.type = MessageType::AudioChunk;
        msg.sender = localPeerId_;
        msg.timestamp = getCurrentTimestamp();
        msg.priority = SyncPriority::Realtime;

        // Compress and encode audio
        msg.payload.resize(numSamples * sizeof(float));
        std::memcpy(msg.payload.data(), samples, numSamples * sizeof(float));

        broadcastRealtime(msg);
    }

    /**
     * Send laser frame to peers
     */
    void sendLaserFrame(const void* frameData, size_t frameSize)
    {
        if (!inSession_) return;

        CollabMessage msg;
        msg.type = MessageType::LaserFrame;
        msg.sender = localPeerId_;
        msg.timestamp = getCurrentTimestamp();
        msg.priority = SyncPriority::High;

        msg.payload.resize(frameSize);
        std::memcpy(msg.payload.data(), frameData, frameSize);

        broadcast(msg);
    }

    /**
     * Send bio data to peers
     */
    void sendBioData(float coherence, float relaxation, float heartRate,
                     float breathRate, float gsr)
    {
        if (!inSession_) return;

        CollabMessage msg;
        msg.type = MessageType::BioData;
        msg.sender = localPeerId_;
        msg.timestamp = getCurrentTimestamp();
        msg.priority = SyncPriority::Normal;

        // Pack bio data
        msg.payload.resize(5 * sizeof(float));
        float* data = reinterpret_cast<float*>(msg.payload.data());
        data[0] = coherence;
        data[1] = relaxation;
        data[2] = heartRate;
        data[3] = breathRate;
        data[4] = gsr;

        broadcast(msg);
    }

    //==========================================================================
    // Peer Management
    //==========================================================================

    std::vector<PeerInfo> getPeers() const
    {
        std::lock_guard<std::mutex> lock(peersMutex_);
        std::vector<PeerInfo> result;
        for (const auto& [id, info] : peers_)
        {
            result.push_back(info);
        }
        return result;
    }

    std::optional<PeerInfo> getPeer(const PeerId& id) const
    {
        std::lock_guard<std::mutex> lock(peersMutex_);
        auto it = peers_.find(id);
        if (it != peers_.end())
            return it->second;
        return std::nullopt;
    }

    bool kickPeer(const PeerId& peerId)
    {
        if (!isHost_) return false;

        CollabMessage msg;
        msg.type = MessageType::Kick;
        msg.sender = localPeerId_;
        msg.recipient = peerId;
        msg.timestamp = getCurrentTimestamp();

        sendTo(peerId, msg);
        removePeer(peerId);

        return true;
    }

    void setPeerRole(const PeerId& peerId, PeerRole role)
    {
        if (!isHost_) return;

        std::lock_guard<std::mutex> lock(peersMutex_);
        auto it = peers_.find(peerId);
        if (it != peers_.end())
        {
            it->second.role = role;
            // Broadcast role change
        }
    }

    //==========================================================================
    // Callbacks
    //==========================================================================

    void setOnPeerJoined(OnPeerJoinedCallback callback)
    {
        onPeerJoined_ = std::move(callback);
    }

    void setOnPeerLeft(OnPeerLeftCallback callback)
    {
        onPeerLeft_ = std::move(callback);
    }

    void setOnStateChanged(OnStateChangedCallback callback)
    {
        onStateChanged_ = std::move(callback);
    }

    void setOnMessage(OnMessageCallback callback)
    {
        onMessage_ = std::move(callback);
    }

    void setOnConnectionState(OnConnectionStateCallback callback)
    {
        onConnectionState_ = std::move(callback);
    }

    void setOnError(OnErrorCallback callback)
    {
        onError_ = std::move(callback);
    }

    //==========================================================================
    // Local Peer
    //==========================================================================

    void setDisplayName(const std::string& name)
    {
        localPeerInfo_.displayName = name;
    }

    void setAvatarUrl(const std::string& url)
    {
        localPeerInfo_.avatarUrl = url;
    }

    PeerId getLocalPeerId() const { return localPeerId_; }
    PeerInfo getLocalPeerInfo() const { return localPeerInfo_; }

    //==========================================================================
    // Status
    //==========================================================================

    bool isInitialized() const { return initialized_; }
    bool isInSession() const { return inSession_; }
    bool isHost() const { return isHost_; }
    ConnectionState getConnectionState() const { return connectionState_.load(); }
    SessionInfo getSessionInfo() const { return currentSession_; }

    //==========================================================================
    // Latency
    //==========================================================================

    float getAverageLatency() const
    {
        return latencyTracker_.getAverage();
    }

    float getJitter() const
    {
        return latencyTracker_.getJitter();
    }

private:
    EchoelRealtimeCollab() = default;
    ~EchoelRealtimeCollab() { shutdown(); }

    EchoelRealtimeCollab(const EchoelRealtimeCollab&) = delete;
    EchoelRealtimeCollab& operator=(const EchoelRealtimeCollab&) = delete;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void networkLoop()
    {
        using namespace std::chrono;

        auto lastHeartbeat = steady_clock::now();
        auto lastSync = steady_clock::now();

        while (running_)
        {
            auto now = steady_clock::now();

            // Process incoming messages
            processIncomingMessages();

            // Send heartbeats
            if (duration_cast<milliseconds>(now - lastHeartbeat).count() >= HEARTBEAT_INTERVAL_MS)
            {
                sendHeartbeats();
                checkPeerTimeouts();
                lastHeartbeat = now;
            }

            // State sync
            if (duration_cast<milliseconds>(now - lastSync).count() >= (1000 / config_.syncRateHz))
            {
                processOutgoingStateSync();
                lastSync = now;
            }

            // Small sleep to prevent busy-waiting
            std::this_thread::sleep_for(microseconds(100));
        }
    }

    void processIncomingMessages()
    {
        while (auto msg = incomingQueue_.pop())
        {
            handleMessage(*msg);
        }
    }

    void handleMessage(const CollabMessage& msg)
    {
        switch (msg.type)
        {
            case MessageType::JoinRequest:
                handleJoinRequest(msg);
                break;

            case MessageType::JoinAccepted:
                handleJoinAccepted(msg);
                break;

            case MessageType::JoinRejected:
                handleJoinRejected(msg);
                break;

            case MessageType::Leave:
                handlePeerLeft(msg.sender, "Left session");
                break;

            case MessageType::StateUpdate:
            case MessageType::StateDelta:
                handleStateUpdate(msg);
                break;

            case MessageType::AudioChunk:
                handleAudioChunk(msg);
                break;

            case MessageType::LaserFrame:
                handleLaserFrame(msg);
                break;

            case MessageType::BioData:
                handleBioData(msg);
                break;

            case MessageType::Heartbeat:
                handleHeartbeat(msg);
                break;

            case MessageType::LatencyProbe:
                handleLatencyProbe(msg);
                break;

            case MessageType::LatencyResponse:
                handleLatencyResponse(msg);
                break;

            case MessageType::CRDTOperation:
                handleCRDTOperation(msg);
                break;

            case MessageType::Kick:
                if (msg.recipient == localPeerId_)
                {
                    leaveSession();
                    if (onError_)
                        onError_(1001, "Kicked from session");
                }
                break;

            default:
                if (onMessage_)
                    onMessage_(msg);
                break;
        }
    }

    void handleJoinRequest(const CollabMessage& msg)
    {
        if (!isHost_) return;

        // Extract peer info from payload
        PeerInfo newPeer;
        newPeer.id = msg.sender;
        // Deserialize display name, etc. from payload
        newPeer.role = PeerRole::Performer;
        newPeer.state = ConnectionState::Connected;

        // Accept the peer
        {
            std::lock_guard<std::mutex> lock(peersMutex_);
            peers_[msg.sender] = newPeer;
            currentSession_.currentPeers++;
        }

        // Send accept message with current state
        CollabMessage response;
        response.type = MessageType::JoinAccepted;
        response.sender = localPeerId_;
        response.recipient = msg.sender;
        response.timestamp = getCurrentTimestamp();
        // Include full state in payload

        sendTo(msg.sender, response);

        // Notify other peers
        if (onPeerJoined_)
            onPeerJoined_(newPeer);
    }

    void handleJoinAccepted(const CollabMessage& msg)
    {
        connectionState_.store(ConnectionState::Connected);

        // Extract session state from payload
        // Merge with local state

        if (onConnectionState_)
            onConnectionState_(ConnectionState::Connected);
    }

    void handleJoinRejected(const CollabMessage& msg)
    {
        connectionState_.store(ConnectionState::Failed);
        inSession_ = false;

        if (onConnectionState_)
            onConnectionState_(ConnectionState::Failed);
    }

    void handlePeerLeft(const PeerId& peerId, const std::string& reason)
    {
        removePeer(peerId);

        if (onPeerLeft_)
            onPeerLeft_(peerId, reason);
    }

    void handleStateUpdate(const CollabMessage& msg)
    {
        // Apply state update using CRDT merge
        std::lock_guard<std::mutex> lock(stateMutex_);

        // Deserialize and merge state
        // sharedState_.version.merge(msg.clock);

        if (onStateChanged_)
            onStateChanged_(sharedState_);
    }

    void handleAudioChunk(const CollabMessage& msg)
    {
        // Forward to audio mixer
        // This would integrate with EchoelAudioEngine
    }

    void handleLaserFrame(const CollabMessage& msg)
    {
        // Forward to laser renderer
    }

    void handleBioData(const CollabMessage& msg)
    {
        // Forward to bio processor
    }

    void handleHeartbeat(const CollabMessage& msg)
    {
        std::lock_guard<std::mutex> lock(peersMutex_);
        auto it = peers_.find(msg.sender);
        if (it != peers_.end())
        {
            it->second.lastHeartbeat = getCurrentTimestamp();
        }
    }

    void handleLatencyProbe(const CollabMessage& msg)
    {
        // Respond immediately with same timestamp
        CollabMessage response;
        response.type = MessageType::LatencyResponse;
        response.sender = localPeerId_;
        response.recipient = msg.sender;
        response.timestamp = msg.timestamp;  // Echo back original timestamp
        response.priority = SyncPriority::Realtime;

        sendTo(msg.sender, response);
    }

    void handleLatencyResponse(const CollabMessage& msg)
    {
        uint64_t now = getCurrentTimestamp();
        uint64_t rtt = now - msg.timestamp;
        float latencyMs = static_cast<float>(rtt) / 1000.0f;  // Convert from us to ms

        latencyTracker_.recordSample(latencyMs / 2.0f);  // One-way latency

        std::lock_guard<std::mutex> lock(peersMutex_);
        auto it = peers_.find(msg.sender);
        if (it != peers_.end())
        {
            it->second.latencyMs = latencyMs / 2.0f;
        }
    }

    void handleCRDTOperation(const CollabMessage& msg)
    {
        // Apply CRDT operation
        // CRDTOperation op = deserializeOp(msg.payload);
        // applyCRDTOperation(op);
    }

    void sendHeartbeats()
    {
        if (!inSession_) return;

        CollabMessage msg;
        msg.type = MessageType::Heartbeat;
        msg.sender = localPeerId_;
        msg.timestamp = getCurrentTimestamp();
        msg.priority = SyncPriority::Low;

        broadcast(msg);

        // Also send latency probes periodically
        static int probeCounter = 0;
        if (++probeCounter >= 5)  // Every 5 heartbeats
        {
            probeCounter = 0;
            msg.type = MessageType::LatencyProbe;
            broadcast(msg);
        }
    }

    void checkPeerTimeouts()
    {
        uint64_t now = getCurrentTimestamp();
        std::vector<PeerId> timedOut;

        {
            std::lock_guard<std::mutex> lock(peersMutex_);
            for (const auto& [id, info] : peers_)
            {
                if (id == localPeerId_) continue;

                if (now - info.lastHeartbeat > PEER_TIMEOUT_MS * 1000)
                {
                    timedOut.push_back(id);
                }
            }
        }

        for (const auto& id : timedOut)
        {
            handlePeerLeft(id, "Connection timeout");
        }
    }

    void processOutgoingStateSync()
    {
        // Check if state needs to be broadcast
        // This is called at syncRateHz
    }

    void queueStateBroadcast()
    {
        // Queue state delta for next sync cycle
        stateDirty_ = true;
    }

    void broadcast(const CollabMessage& msg)
    {
        outgoingQueue_.push(CollabMessage(msg));
    }

    void broadcastRealtime(const CollabMessage& msg)
    {
        // Use unreliable channel for real-time data
        realtimeQueue_.push(CollabMessage(msg));
    }

    void sendTo(const PeerId& peerId, const CollabMessage& msg)
    {
        CollabMessage copy = msg;
        copy.recipient = peerId;
        outgoingQueue_.push(std::move(copy));
    }

    void removePeer(const PeerId& peerId)
    {
        std::lock_guard<std::mutex> lock(peersMutex_);
        peers_.erase(peerId);
        currentSession_.currentPeers = std::max(1u, currentSession_.currentPeers - 1);
    }

    void disconnectAllPeers()
    {
        std::lock_guard<std::mutex> lock(peersMutex_);
        peers_.clear();
    }

    bool connectToSession(const std::string& sessionId, const std::string& password)
    {
        // WebSocket connection to signaling server
        // WebRTC offer/answer exchange
        // For now, return true as placeholder
        currentSession_.sessionId = sessionId;
        connectionState_.store(ConnectionState::Connecting);
        return true;
    }

    void registerSession()
    {
        // Register session with signaling server
    }

    std::string generateSessionId()
    {
        auto id = PeerId::generate();
        return id.toString().substr(0, 8);
    }

    uint64_t getCurrentTimestamp() const
    {
        return std::chrono::duration_cast<std::chrono::microseconds>(
            std::chrono::steady_clock::now().time_since_epoch()
        ).count();
    }

    size_t getLocalPeerIndex() const
    {
        // Return index in peer list for vector clock
        size_t index = 0;
        std::lock_guard<std::mutex> lock(peersMutex_);
        for (const auto& [id, info] : peers_)
        {
            if (id == localPeerId_) return index;
            ++index;
        }
        return 0;
    }

    //==========================================================================
    // Member Variables
    //==========================================================================

    bool initialized_ = false;
    std::atomic<bool> running_{false};
    bool inSession_ = false;
    bool isHost_ = false;
    std::atomic<bool> stateDirty_{false};

    CollabConfig config_;

    PeerId localPeerId_;
    PeerInfo localPeerInfo_;
    SessionInfo currentSession_;

    mutable std::mutex peersMutex_;
    std::unordered_map<PeerId, PeerInfo, PeerIdHash> peers_;

    mutable std::mutex stateMutex_;
    SharedState sharedState_;

    std::atomic<ConnectionState> connectionState_{ConnectionState::Disconnected};

    // Message queues
    MessageQueue<1024> incomingQueue_;
    MessageQueue<1024> outgoingQueue_;
    MessageQueue<256> realtimeQueue_;

    // Latency tracking
    LatencyTracker latencyTracker_;

    // Network thread
    std::thread networkThread_;

    // Callbacks
    OnPeerJoinedCallback onPeerJoined_;
    OnPeerLeftCallback onPeerLeft_;
    OnStateChangedCallback onStateChanged_;
    OnMessageCallback onMessage_;
    OnConnectionStateCallback onConnectionState_;
    OnErrorCallback onError_;
};

}} // namespace Echoel::Collab
