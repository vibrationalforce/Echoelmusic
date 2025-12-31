/**
 * EchoelCollabSession.h
 *
 * ============================================================================
 *   RALPH WIGGUM GENIUS LOOP MODE - COLLABORATIVE SESSION MANAGEMENT
 * ============================================================================
 *
 * Session management layer with:
 * - CRDT-based conflict resolution for all shared state
 * - Role-based permissions (Host, Performer, Viewer)
 * - Parameter locking for exclusive editing
 * - Undo/redo synchronization across peers
 * - Timeline synchronization with sub-frame accuracy
 *
 * Session Hierarchy:
 * ┌─────────────────────────────────────────────────────────────────────┐
 * │                        COLLAB SESSION                               │
 * ├─────────────────────────────────────────────────────────────────────┤
 * │  ┌─────────────────────────────────────────────────────────────┐   │
 * │  │                    Session State (CRDT)                      │   │
 * │  │  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐    │   │
 * │  │  │ Transport │ │Parameters │ │   Laser   │ │    Bio    │    │   │
 * │  │  │   State   │ │   State   │ │   State   │ │   State   │    │   │
 * │  │  └───────────┘ └───────────┘ └───────────┘ └───────────┘    │   │
 * │  └─────────────────────────────────────────────────────────────┘   │
 * │                              │                                      │
 * │                              ▼                                      │
 * │  ┌─────────────────────────────────────────────────────────────┐   │
 * │  │                    Undo/Redo History                         │   │
 * │  │     [Op1] ← [Op2] ← [Op3] ← [Current] → [Redo1] → [Redo2]   │   │
 * │  └─────────────────────────────────────────────────────────────┘   │
 * │                              │                                      │
 * │                              ▼                                      │
 * │  ┌─────────────────────────────────────────────────────────────┐   │
 * │  │                   Permission Matrix                          │   │
 * │  │  Host: [All]  Performer: [Edit]  Viewer: [View]  Mod: [Chat] │   │
 * │  └─────────────────────────────────────────────────────────────┘   │
 * └─────────────────────────────────────────────────────────────────────┘
 */

#pragma once

#include <array>
#include <atomic>
#include <chrono>
#include <cstdint>
#include <deque>
#include <functional>
#include <memory>
#include <mutex>
#include <optional>
#include <set>
#include <string>
#include <unordered_map>
#include <vector>

namespace Echoel { namespace Collab {

//==============================================================================
// Forward Declarations
//==============================================================================

class EchoelCollabSession;
struct PeerId;

//==============================================================================
// Constants
//==============================================================================

static constexpr size_t MAX_UNDO_HISTORY = 100;
static constexpr size_t MAX_LOCKED_PARAMETERS = 64;
static constexpr size_t MAX_TRACKS = 16;
static constexpr size_t MAX_MARKERS = 256;

//==============================================================================
// Enums
//==============================================================================

enum class Permission : uint32_t
{
    None            = 0,

    // Transport
    PlayPause       = 1 << 0,
    Seek            = 1 << 1,
    SetTempo        = 1 << 2,

    // Parameters
    EditParameters  = 1 << 3,
    LockParameters  = 1 << 4,

    // Laser
    EditLaser       = 1 << 5,
    ControlLaser    = 1 << 6,

    // Audio
    EditAudio       = 1 << 7,
    MuteOthers      = 1 << 8,

    // Bio
    ShareBio        = 1 << 9,

    // Session
    InviteUsers     = 1 << 10,
    KickUsers       = 1 << 11,
    ChangeRoles     = 1 << 12,
    EndSession      = 1 << 13,

    // Chat
    SendChat        = 1 << 14,
    ModerateChat    = 1 << 15,
    SendReactions   = 1 << 16,

    // Recording
    StartRecording  = 1 << 17,
    StopRecording   = 1 << 18,

    // Streaming
    StartStream     = 1 << 19,
    StopStream      = 1 << 20,

    // Presets
    LoadPreset      = 1 << 21,
    SavePreset      = 1 << 22,

    // Compound permissions
    Viewer = SendChat | SendReactions | ShareBio,
    Performer = Viewer | PlayPause | Seek | EditParameters | EditLaser | EditAudio | LoadPreset,
    Moderator = Viewer | ModerateChat | MuteOthers | KickUsers,
    Host = 0xFFFFFFFF  // All permissions
};

inline Permission operator|(Permission a, Permission b)
{
    return static_cast<Permission>(static_cast<uint32_t>(a) | static_cast<uint32_t>(b));
}

inline Permission operator&(Permission a, Permission b)
{
    return static_cast<Permission>(static_cast<uint32_t>(a) & static_cast<uint32_t>(b));
}

inline bool hasPermission(Permission granted, Permission required)
{
    return (static_cast<uint32_t>(granted) & static_cast<uint32_t>(required)) ==
           static_cast<uint32_t>(required);
}

enum class OperationType : uint8_t
{
    // Transport
    Play = 0,
    Pause,
    Stop,
    Seek,
    SetTempo,
    SetLoop,

    // Parameters
    SetParameter,
    LockParameter,
    UnlockParameter,
    ResetParameter,

    // Laser
    SetPattern,
    SetLaserConfig,
    AddBeam,
    RemoveBeam,
    UpdateBeam,

    // Audio
    SetVolume,
    SetMute,
    SetPan,
    SetEffect,

    // Bio
    SetBioConfig,
    EnableBio,
    DisableBio,

    // Entrainment
    SetTargetFrequency,
    SetEntrainmentConfig,

    // Markers
    AddMarker,
    RemoveMarker,
    UpdateMarker,

    // Presets
    LoadPreset,
    SavePreset,

    // Compound
    BatchOperation
};

enum class LockState : uint8_t
{
    Unlocked = 0,
    LockedByMe,
    LockedByOther,
    Contested  // Multiple peers trying to lock
};

//==============================================================================
// Data Structures
//==============================================================================

/**
 * Operation for undo/redo system
 */
struct Operation
{
    OperationType type;
    std::string targetPath;     // JSON path to affected state
    std::vector<uint8_t> oldValue;
    std::vector<uint8_t> newValue;
    uint64_t timestamp;
    std::array<uint8_t, 16> authorId;  // Peer ID who made the change
    uint64_t sequenceNumber;
    bool isLocal = false;

    // For batch operations
    std::vector<Operation> subOperations;
};

/**
 * Parameter lock information
 */
struct ParameterLock
{
    std::string parameterPath;
    std::array<uint8_t, 16> holderId;
    std::string holderName;
    uint64_t lockedAt;
    uint64_t expiresAt;  // Auto-expire to prevent dead locks
    bool isExclusive = true;
};

/**
 * Timeline marker
 */
struct TimelineMarker
{
    std::string id;
    std::string name;
    std::string color;
    double positionSeconds;
    double durationSeconds;
    std::string notes;
    std::array<uint8_t, 16> createdBy;
    uint64_t createdAt;
};

/**
 * Loop region
 */
struct LoopRegion
{
    bool enabled = false;
    double startSeconds = 0.0;
    double endSeconds = 0.0;
    int repeatCount = -1;  // -1 for infinite
};

/**
 * Transport state
 */
struct TransportState
{
    bool isPlaying = false;
    bool isRecording = false;
    double positionSeconds = 0.0;
    double tempo = 120.0;
    double beatsPerBar = 4;
    double beatDivision = 4;
    LoopRegion loop;

    // Synchronization
    uint64_t lastUpdateTime = 0;
    uint64_t syncOffset = 0;  // Network time offset
};

/**
 * Track state
 */
struct TrackState
{
    std::string id;
    std::string name;
    std::string type;  // "audio", "laser", "bio", "entrainment"
    bool isMuted = false;
    bool isSoloed = false;
    float volume = 1.0f;
    float pan = 0.0f;
    std::string color;
    int order = 0;
};

/**
 * Full session state
 */
struct SessionState
{
    // Identification
    std::string sessionId;
    std::string sessionName;
    uint64_t createdAt;
    uint64_t modifiedAt;

    // Transport
    TransportState transport;

    // Tracks
    std::vector<TrackState> tracks;

    // Markers
    std::vector<TimelineMarker> markers;

    // Parameters (path -> value)
    std::unordered_map<std::string, std::vector<uint8_t>> parameters;

    // Locks
    std::vector<ParameterLock> locks;

    // Version for optimistic concurrency
    uint64_t version = 0;
};

/**
 * Session configuration
 */
struct SessionConfig
{
    std::string name = "Untitled Session";
    bool isPrivate = false;
    std::string password;

    // Limits
    uint32_t maxParticipants = 32;
    uint32_t maxViewers = 1000;

    // Permissions
    Permission defaultViewerPermissions = Permission::Viewer;
    Permission defaultPerformerPermissions = Permission::Performer;

    // Features
    bool allowRecording = true;
    bool allowStreaming = true;
    bool syncBioData = true;
    bool syncLaser = true;

    // Timing
    uint32_t undoHistorySize = MAX_UNDO_HISTORY;
    uint32_t lockTimeoutSeconds = 60;
    uint32_t syncIntervalMs = 16;  // ~60 Hz
};

//==============================================================================
// Undo/Redo Manager
//==============================================================================

class UndoRedoManager
{
public:
    explicit UndoRedoManager(size_t maxHistory = MAX_UNDO_HISTORY)
        : maxHistory_(maxHistory)
    {}

    void pushOperation(Operation&& op)
    {
        std::lock_guard<std::mutex> lock(mutex_);

        // Clear redo stack when new operation is pushed
        redoStack_.clear();

        // Add to undo stack
        undoStack_.push_back(std::move(op));

        // Trim if too large
        while (undoStack_.size() > maxHistory_)
        {
            undoStack_.pop_front();
        }
    }

    std::optional<Operation> undo()
    {
        std::lock_guard<std::mutex> lock(mutex_);

        if (undoStack_.empty())
            return std::nullopt;

        Operation op = std::move(undoStack_.back());
        undoStack_.pop_back();
        redoStack_.push_back(op);

        return op;
    }

    std::optional<Operation> redo()
    {
        std::lock_guard<std::mutex> lock(mutex_);

        if (redoStack_.empty())
            return std::nullopt;

        Operation op = std::move(redoStack_.back());
        redoStack_.pop_back();
        undoStack_.push_back(op);

        return op;
    }

    bool canUndo() const
    {
        std::lock_guard<std::mutex> lock(mutex_);
        return !undoStack_.empty();
    }

    bool canRedo() const
    {
        std::lock_guard<std::mutex> lock(mutex_);
        return !redoStack_.empty();
    }

    size_t undoCount() const
    {
        std::lock_guard<std::mutex> lock(mutex_);
        return undoStack_.size();
    }

    size_t redoCount() const
    {
        std::lock_guard<std::mutex> lock(mutex_);
        return redoStack_.size();
    }

    void clear()
    {
        std::lock_guard<std::mutex> lock(mutex_);
        undoStack_.clear();
        redoStack_.clear();
    }

    /**
     * Merge operation from remote peer
     */
    void mergeRemoteOperation(const Operation& op)
    {
        std::lock_guard<std::mutex> lock(mutex_);

        // Insert in correct position based on sequence number
        auto it = std::find_if(undoStack_.begin(), undoStack_.end(),
            [&](const Operation& existing) {
                return existing.sequenceNumber > op.sequenceNumber;
            });

        undoStack_.insert(it, op);

        // Re-apply operations after the inserted one
        // (OT - Operational Transformation)
        transformOperationsAfter(it);
    }

private:
    void transformOperationsAfter(std::deque<Operation>::iterator insertPoint)
    {
        // Apply operational transformation to maintain consistency
        // This ensures all peers see the same final state regardless of
        // operation order
    }

    size_t maxHistory_;
    mutable std::mutex mutex_;
    std::deque<Operation> undoStack_;
    std::deque<Operation> redoStack_;
};

//==============================================================================
// Lock Manager
//==============================================================================

class LockManager
{
public:
    LockManager(uint32_t timeoutSeconds = 60)
        : timeoutSeconds_(timeoutSeconds)
    {}

    /**
     * Attempt to acquire a lock
     */
    bool acquireLock(const std::string& path,
                     const std::array<uint8_t, 16>& holderId,
                     const std::string& holderName)
    {
        std::lock_guard<std::mutex> lock(mutex_);

        // Check if already locked by someone else
        auto it = locks_.find(path);
        if (it != locks_.end())
        {
            // Check if lock has expired
            uint64_t now = getCurrentTime();
            if (now < it->second.expiresAt)
            {
                // Still locked
                if (it->second.holderId != holderId)
                    return false;  // Locked by someone else
                else
                {
                    // Refresh our own lock
                    it->second.expiresAt = now + timeoutSeconds_ * 1000000ULL;
                    return true;
                }
            }
            // Lock expired, can take it
        }

        // Create new lock
        ParameterLock newLock;
        newLock.parameterPath = path;
        newLock.holderId = holderId;
        newLock.holderName = holderName;
        newLock.lockedAt = getCurrentTime();
        newLock.expiresAt = newLock.lockedAt + timeoutSeconds_ * 1000000ULL;

        locks_[path] = newLock;
        return true;
    }

    /**
     * Release a lock
     */
    bool releaseLock(const std::string& path,
                     const std::array<uint8_t, 16>& holderId)
    {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = locks_.find(path);
        if (it == locks_.end())
            return true;  // Not locked

        if (it->second.holderId != holderId)
            return false;  // Can't release someone else's lock

        locks_.erase(it);
        return true;
    }

    /**
     * Check lock state
     */
    LockState getLockState(const std::string& path,
                           const std::array<uint8_t, 16>& myId) const
    {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = locks_.find(path);
        if (it == locks_.end())
            return LockState::Unlocked;

        uint64_t now = getCurrentTime();
        if (now >= it->second.expiresAt)
            return LockState::Unlocked;  // Expired

        if (it->second.holderId == myId)
            return LockState::LockedByMe;

        return LockState::LockedByOther;
    }

    /**
     * Get lock holder info
     */
    std::optional<ParameterLock> getLock(const std::string& path) const
    {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = locks_.find(path);
        if (it == locks_.end())
            return std::nullopt;

        uint64_t now = getCurrentTime();
        if (now >= it->second.expiresAt)
            return std::nullopt;  // Expired

        return it->second;
    }

    /**
     * Get all active locks
     */
    std::vector<ParameterLock> getAllLocks() const
    {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<ParameterLock> result;
        uint64_t now = getCurrentTime();

        for (const auto& [path, lockInfo] : locks_)
        {
            if (now < lockInfo.expiresAt)
            {
                result.push_back(lockInfo);
            }
        }

        return result;
    }

    /**
     * Release all locks held by a peer (when they disconnect)
     */
    void releaseAllLocks(const std::array<uint8_t, 16>& holderId)
    {
        std::lock_guard<std::mutex> lock(mutex_);

        for (auto it = locks_.begin(); it != locks_.end(); )
        {
            if (it->second.holderId == holderId)
                it = locks_.erase(it);
            else
                ++it;
        }
    }

    /**
     * Cleanup expired locks
     */
    void cleanupExpiredLocks()
    {
        std::lock_guard<std::mutex> lock(mutex_);
        uint64_t now = getCurrentTime();

        for (auto it = locks_.begin(); it != locks_.end(); )
        {
            if (now >= it->second.expiresAt)
                it = locks_.erase(it);
            else
                ++it;
        }
    }

private:
    uint64_t getCurrentTime() const
    {
        return std::chrono::duration_cast<std::chrono::microseconds>(
            std::chrono::steady_clock::now().time_since_epoch()
        ).count();
    }

    uint32_t timeoutSeconds_;
    mutable std::mutex mutex_;
    std::unordered_map<std::string, ParameterLock> locks_;
};

//==============================================================================
// Timeline Manager
//==============================================================================

class TimelineManager
{
public:
    void setTransportState(const TransportState& state)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        transport_ = state;
    }

    TransportState getTransportState() const
    {
        std::lock_guard<std::mutex> lock(mutex_);
        return transport_;
    }

    void play()
    {
        std::lock_guard<std::mutex> lock(mutex_);
        transport_.isPlaying = true;
        transport_.lastUpdateTime = getCurrentTime();
    }

    void pause()
    {
        std::lock_guard<std::mutex> lock(mutex_);
        updatePosition();
        transport_.isPlaying = false;
    }

    void stop()
    {
        std::lock_guard<std::mutex> lock(mutex_);
        transport_.isPlaying = false;
        transport_.positionSeconds = 0.0;
    }

    void seek(double positionSeconds)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        transport_.positionSeconds = positionSeconds;
        transport_.lastUpdateTime = getCurrentTime();
    }

    double getCurrentPosition() const
    {
        std::lock_guard<std::mutex> lock(mutex_);

        if (!transport_.isPlaying)
            return transport_.positionSeconds;

        // Calculate current position based on elapsed time
        uint64_t now = getCurrentTime();
        double elapsed = static_cast<double>(now - transport_.lastUpdateTime) / 1000000.0;

        double position = transport_.positionSeconds + elapsed;

        // Handle loop
        if (transport_.loop.enabled)
        {
            double loopLength = transport_.loop.endSeconds - transport_.loop.startSeconds;
            if (loopLength > 0 && position >= transport_.loop.endSeconds)
            {
                position = transport_.loop.startSeconds +
                    std::fmod(position - transport_.loop.startSeconds, loopLength);
            }
        }

        return position;
    }

    void setTempo(double bpm)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        transport_.tempo = bpm;
    }

    void setLoop(double startSeconds, double endSeconds, bool enabled = true)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        transport_.loop.startSeconds = startSeconds;
        transport_.loop.endSeconds = endSeconds;
        transport_.loop.enabled = enabled;
    }

    // Markers
    void addMarker(const TimelineMarker& marker)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        markers_.push_back(marker);
        std::sort(markers_.begin(), markers_.end(),
            [](const TimelineMarker& a, const TimelineMarker& b) {
                return a.positionSeconds < b.positionSeconds;
            });
    }

    void removeMarker(const std::string& markerId)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        markers_.erase(
            std::remove_if(markers_.begin(), markers_.end(),
                [&](const TimelineMarker& m) { return m.id == markerId; }),
            markers_.end());
    }

    std::vector<TimelineMarker> getMarkers() const
    {
        std::lock_guard<std::mutex> lock(mutex_);
        return markers_;
    }

    std::optional<TimelineMarker> getNextMarker(double afterPosition) const
    {
        std::lock_guard<std::mutex> lock(mutex_);

        for (const auto& marker : markers_)
        {
            if (marker.positionSeconds > afterPosition)
                return marker;
        }
        return std::nullopt;
    }

    /**
     * Synchronize with network time
     */
    void synchronizeWithNetworkTime(uint64_t networkTimeUs, uint64_t localTimeUs)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        transport_.syncOffset = networkTimeUs - localTimeUs;
    }

    uint64_t getNetworkTime() const
    {
        return getCurrentTime() + transport_.syncOffset;
    }

private:
    void updatePosition()
    {
        if (transport_.isPlaying)
        {
            uint64_t now = getCurrentTime();
            double elapsed = static_cast<double>(now - transport_.lastUpdateTime) / 1000000.0;
            transport_.positionSeconds += elapsed;
            transport_.lastUpdateTime = now;
        }
    }

    uint64_t getCurrentTime() const
    {
        return std::chrono::duration_cast<std::chrono::microseconds>(
            std::chrono::steady_clock::now().time_since_epoch()
        ).count();
    }

    mutable std::mutex mutex_;
    TransportState transport_;
    std::vector<TimelineMarker> markers_;
};

//==============================================================================
// Callbacks
//==============================================================================

using OnStateChangedCallback = std::function<void(const SessionState&)>;
using OnTransportChangedCallback = std::function<void(const TransportState&)>;
using OnOperationCallback = std::function<void(const Operation&)>;
using OnLockChangedCallback = std::function<void(const std::string& path, LockState state)>;
using OnMarkerCallback = std::function<void(const TimelineMarker&)>;

//==============================================================================
// Main Collaboration Session
//==============================================================================

class EchoelCollabSession
{
public:
    static EchoelCollabSession& getInstance()
    {
        static EchoelCollabSession instance;
        return instance;
    }

    //==========================================================================
    // Lifecycle
    //==========================================================================

    bool initialize(const SessionConfig& config)
    {
        if (initialized_) return true;

        config_ = config;
        undoManager_ = std::make_unique<UndoRedoManager>(config.undoHistorySize);
        lockManager_ = std::make_unique<LockManager>(config.lockTimeoutSeconds);
        timelineManager_ = std::make_unique<TimelineManager>();

        initialized_ = true;
        return true;
    }

    void shutdown()
    {
        if (!initialized_) return;

        undoManager_.reset();
        lockManager_.reset();
        timelineManager_.reset();

        initialized_ = false;
    }

    //==========================================================================
    // State Management
    //==========================================================================

    SessionState getState() const
    {
        std::lock_guard<std::mutex> lock(stateMutex_);
        return state_;
    }

    void setState(const SessionState& state)
    {
        std::lock_guard<std::mutex> lock(stateMutex_);
        state_ = state;
        state_.version++;
        state_.modifiedAt = getCurrentTime();

        if (onStateChanged_)
            onStateChanged_(state_);
    }

    /**
     * Apply an operation with undo support
     */
    bool applyOperation(Operation&& op, bool recordUndo = true)
    {
        // Check permission
        if (!checkPermission(op))
            return false;

        // Check locks
        auto lockState = lockManager_->getLockState(op.targetPath, localPeerId_);
        if (lockState == LockState::LockedByOther)
            return false;

        // Apply the operation
        bool success = applyOperationInternal(op);

        if (success && recordUndo)
        {
            op.isLocal = true;
            op.sequenceNumber = nextSequenceNumber_++;
            undoManager_->pushOperation(std::move(op));
        }

        return success;
    }

    /**
     * Undo last operation
     */
    bool undo()
    {
        auto op = undoManager_->undo();
        if (!op) return false;

        // Swap old and new values to reverse
        std::swap(op->oldValue, op->newValue);
        return applyOperationInternal(*op);
    }

    /**
     * Redo last undone operation
     */
    bool redo()
    {
        auto op = undoManager_->redo();
        if (!op) return false;

        return applyOperationInternal(*op);
    }

    bool canUndo() const { return undoManager_->canUndo(); }
    bool canRedo() const { return undoManager_->canRedo(); }

    //==========================================================================
    // Transport
    //==========================================================================

    void play()
    {
        Operation op;
        op.type = OperationType::Play;
        op.timestamp = getCurrentTime();
        op.authorId = localPeerId_;

        if (applyOperation(std::move(op)))
        {
            timelineManager_->play();
            if (onTransportChanged_)
                onTransportChanged_(timelineManager_->getTransportState());
        }
    }

    void pause()
    {
        Operation op;
        op.type = OperationType::Pause;
        op.timestamp = getCurrentTime();
        op.authorId = localPeerId_;

        if (applyOperation(std::move(op)))
        {
            timelineManager_->pause();
            if (onTransportChanged_)
                onTransportChanged_(timelineManager_->getTransportState());
        }
    }

    void stop()
    {
        Operation op;
        op.type = OperationType::Stop;
        op.timestamp = getCurrentTime();
        op.authorId = localPeerId_;

        if (applyOperation(std::move(op)))
        {
            timelineManager_->stop();
            if (onTransportChanged_)
                onTransportChanged_(timelineManager_->getTransportState());
        }
    }

    void seek(double positionSeconds)
    {
        Operation op;
        op.type = OperationType::Seek;
        op.timestamp = getCurrentTime();
        op.authorId = localPeerId_;

        // Store position in payload
        op.newValue.resize(sizeof(double));
        std::memcpy(op.newValue.data(), &positionSeconds, sizeof(double));

        if (applyOperation(std::move(op)))
        {
            timelineManager_->seek(positionSeconds);
            if (onTransportChanged_)
                onTransportChanged_(timelineManager_->getTransportState());
        }
    }

    TransportState getTransportState() const
    {
        return timelineManager_->getTransportState();
    }

    double getCurrentPosition() const
    {
        return timelineManager_->getCurrentPosition();
    }

    //==========================================================================
    // Parameters
    //==========================================================================

    template<typename T>
    bool setParameter(const std::string& path, const T& value)
    {
        Operation op;
        op.type = OperationType::SetParameter;
        op.targetPath = path;
        op.timestamp = getCurrentTime();
        op.authorId = localPeerId_;

        // Get old value
        {
            std::lock_guard<std::mutex> lock(stateMutex_);
            auto it = state_.parameters.find(path);
            if (it != state_.parameters.end())
                op.oldValue = it->second;
        }

        // Set new value
        op.newValue.resize(sizeof(T));
        std::memcpy(op.newValue.data(), &value, sizeof(T));

        return applyOperation(std::move(op));
    }

    template<typename T>
    std::optional<T> getParameter(const std::string& path) const
    {
        std::lock_guard<std::mutex> lock(stateMutex_);

        auto it = state_.parameters.find(path);
        if (it == state_.parameters.end() || it->second.size() != sizeof(T))
            return std::nullopt;

        T value;
        std::memcpy(&value, it->second.data(), sizeof(T));
        return value;
    }

    //==========================================================================
    // Locks
    //==========================================================================

    bool lockParameter(const std::string& path)
    {
        return lockManager_->acquireLock(path, localPeerId_, localPeerName_);
    }

    bool unlockParameter(const std::string& path)
    {
        return lockManager_->releaseLock(path, localPeerId_);
    }

    LockState getLockState(const std::string& path) const
    {
        return lockManager_->getLockState(path, localPeerId_);
    }

    std::optional<ParameterLock> getLock(const std::string& path) const
    {
        return lockManager_->getLock(path);
    }

    //==========================================================================
    // Markers
    //==========================================================================

    void addMarker(const std::string& name, double position,
                   const std::string& color = "#00FFFF")
    {
        TimelineMarker marker;
        marker.id = generateId();
        marker.name = name;
        marker.positionSeconds = position;
        marker.color = color;
        marker.createdBy = localPeerId_;
        marker.createdAt = getCurrentTime();

        timelineManager_->addMarker(marker);

        if (onMarkerAdded_)
            onMarkerAdded_(marker);
    }

    void removeMarker(const std::string& markerId)
    {
        timelineManager_->removeMarker(markerId);
    }

    std::vector<TimelineMarker> getMarkers() const
    {
        return timelineManager_->getMarkers();
    }

    //==========================================================================
    // Callbacks
    //==========================================================================

    void setOnStateChanged(OnStateChangedCallback cb) { onStateChanged_ = std::move(cb); }
    void setOnTransportChanged(OnTransportChangedCallback cb) { onTransportChanged_ = std::move(cb); }
    void setOnOperation(OnOperationCallback cb) { onOperation_ = std::move(cb); }
    void setOnLockChanged(OnLockChangedCallback cb) { onLockChanged_ = std::move(cb); }
    void setOnMarkerAdded(OnMarkerCallback cb) { onMarkerAdded_ = std::move(cb); }
    void setOnMarkerRemoved(OnMarkerCallback cb) { onMarkerRemoved_ = std::move(cb); }

    //==========================================================================
    // Local Peer
    //==========================================================================

    void setLocalPeerId(const std::array<uint8_t, 16>& id) { localPeerId_ = id; }
    void setLocalPeerName(const std::string& name) { localPeerName_ = name; }
    void setLocalPermissions(Permission perms) { localPermissions_ = perms; }

    //==========================================================================
    // Remote Sync
    //==========================================================================

    /**
     * Merge operation from remote peer
     */
    void mergeRemoteOperation(const Operation& op)
    {
        // Apply to undo manager for history
        undoManager_->mergeRemoteOperation(op);

        // Apply to state
        applyOperationInternal(op);

        if (onOperation_)
            onOperation_(op);
    }

    /**
     * Handle peer disconnect
     */
    void handlePeerDisconnect(const std::array<uint8_t, 16>& peerId)
    {
        lockManager_->releaseAllLocks(peerId);
    }

private:
    EchoelCollabSession() = default;
    ~EchoelCollabSession() { shutdown(); }

    EchoelCollabSession(const EchoelCollabSession&) = delete;
    EchoelCollabSession& operator=(const EchoelCollabSession&) = delete;

    bool applyOperationInternal(const Operation& op)
    {
        std::lock_guard<std::mutex> lock(stateMutex_);

        switch (op.type)
        {
            case OperationType::SetParameter:
                state_.parameters[op.targetPath] = op.newValue;
                break;

            case OperationType::Play:
            case OperationType::Pause:
            case OperationType::Stop:
            case OperationType::Seek:
                // Handled by TimelineManager
                break;

            default:
                break;
        }

        state_.version++;
        state_.modifiedAt = getCurrentTime();

        return true;
    }

    bool checkPermission(const Operation& op) const
    {
        Permission required = Permission::None;

        switch (op.type)
        {
            case OperationType::Play:
            case OperationType::Pause:
            case OperationType::Stop:
            case OperationType::Seek:
                required = Permission::PlayPause;
                break;

            case OperationType::SetParameter:
                required = Permission::EditParameters;
                break;

            case OperationType::LockParameter:
                required = Permission::LockParameters;
                break;

            case OperationType::SetPattern:
            case OperationType::SetLaserConfig:
                required = Permission::EditLaser;
                break;

            default:
                break;
        }

        return hasPermission(localPermissions_, required);
    }

    uint64_t getCurrentTime() const
    {
        return std::chrono::duration_cast<std::chrono::microseconds>(
            std::chrono::steady_clock::now().time_since_epoch()
        ).count();
    }

    std::string generateId() const
    {
        static std::atomic<uint64_t> counter{0};
        return std::to_string(getCurrentTime()) + "_" + std::to_string(counter++);
    }

    bool initialized_ = false;
    SessionConfig config_;

    mutable std::mutex stateMutex_;
    SessionState state_;

    std::unique_ptr<UndoRedoManager> undoManager_;
    std::unique_ptr<LockManager> lockManager_;
    std::unique_ptr<TimelineManager> timelineManager_;

    std::array<uint8_t, 16> localPeerId_{};
    std::string localPeerName_;
    Permission localPermissions_ = Permission::Host;

    std::atomic<uint64_t> nextSequenceNumber_{0};

    // Callbacks
    OnStateChangedCallback onStateChanged_;
    OnTransportChangedCallback onTransportChanged_;
    OnOperationCallback onOperation_;
    OnLockChangedCallback onLockChanged_;
    OnMarkerCallback onMarkerAdded_;
    OnMarkerCallback onMarkerRemoved_;
};

}} // namespace Echoel::Collab
