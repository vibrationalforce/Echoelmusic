/**
 * EchoelPresenceSystem.h
 *
 * ============================================================================
 *   RALPH WIGGUM GENIUS LOOP MODE - USER PRESENCE & CURSOR SYSTEM
 * ============================================================================
 *
 * Real-time presence tracking with:
 * - Online/offline status
 * - Cursor positions and selection
 * - Activity indicators (editing, viewing, idle)
 * - Typing indicators
 * - Bio state sharing (coherence aura)
 * - Lock-free updates for 60+ Hz sync
 *
 * Architecture:
 * ┌─────────────────────────────────────────────────────────────────────┐
 * │                      PRESENCE SYSTEM                                │
 * ├─────────────────────────────────────────────────────────────────────┤
 * │  ┌─────────────────────────────────────────────────────────────┐   │
 * │  │                    User Registry                             │   │
 * │  │     [User A] [User B] [User C] [User D] ...                 │   │
 * │  └─────────────────────────────────────────────────────────────┘   │
 * │                              │                                      │
 * │         ┌────────────────────┼────────────────────┐                │
 * │         ▼                    ▼                    ▼                │
 * │  ┌─────────────┐      ┌─────────────┐      ┌─────────────┐        │
 * │  │   Cursor    │      │  Activity   │      │    Bio      │        │
 * │  │   Tracker   │      │   Monitor   │      │   Aura      │        │
 * │  └─────────────┘      └─────────────┘      └─────────────┘        │
 * │         │                    │                    │                │
 * │         ▼                    ▼                    ▼                │
 * │  ┌─────────────────────────────────────────────────────────────┐   │
 * │  │              Lock-Free State Buffer (Triple Buffer)          │   │
 * │  │      [Write Buffer] → [Ready Buffer] → [Read Buffer]        │   │
 * │  └─────────────────────────────────────────────────────────────┘   │
 * │                              │                                      │
 * │                              ▼                                      │
 * │  ┌─────────────────────────────────────────────────────────────┐   │
 * │  │                    Network Sync (60 Hz)                      │   │
 * │  └─────────────────────────────────────────────────────────────┘   │
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

namespace Echoel { namespace Presence {

//==============================================================================
// Constants
//==============================================================================

static constexpr size_t MAX_USERS = 64;
static constexpr uint32_t PRESENCE_UPDATE_RATE_HZ = 60;
static constexpr uint32_t IDLE_TIMEOUT_MS = 60000;      // 1 minute
static constexpr uint32_t AWAY_TIMEOUT_MS = 300000;     // 5 minutes
static constexpr uint32_t TYPING_TIMEOUT_MS = 3000;     // 3 seconds
static constexpr uint32_t CURSOR_INTERPOLATION_MS = 50;

//==============================================================================
// Enums
//==============================================================================

enum class PresenceStatus : uint8_t
{
    Offline = 0,
    Online,
    Idle,
    Away,
    DoNotDisturb,
    Invisible       // Online but hidden
};

enum class ActivityType : uint8_t
{
    None = 0,
    Viewing,
    Editing,
    Recording,
    Streaming,
    InSession,
    Meditating,     // Bio-reactive: High coherence state
    Custom
};

enum class CursorType : uint8_t
{
    Default = 0,
    Pointer,
    Crosshair,
    Text,
    Grab,
    Grabbing,
    Move,
    Resize,
    Custom
};

//==============================================================================
// Data Structures
//==============================================================================

struct UserId
{
    std::array<uint8_t, 16> uuid;

    bool operator==(const UserId& other) const { return uuid == other.uuid; }
    bool operator!=(const UserId& other) const { return uuid != other.uuid; }

    size_t hash() const
    {
        size_t h = 0;
        for (int i = 0; i < 16; ++i)
            h ^= static_cast<size_t>(uuid[i]) << ((i % 8) * 8);
        return h;
    }
};

struct UserIdHash
{
    size_t operator()(const UserId& id) const { return id.hash(); }
};

/**
 * Cursor position and state
 */
struct CursorState
{
    // Position (normalized 0-1 or absolute pixels)
    float x = 0.0f;
    float y = 0.0f;
    bool normalized = true;

    // Previous position for interpolation
    float prevX = 0.0f;
    float prevY = 0.0f;

    // Cursor appearance
    CursorType type = CursorType::Default;
    std::string customCursorUrl;

    // Selection
    bool hasSelection = false;
    float selectionStartX = 0.0f;
    float selectionStartY = 0.0f;
    float selectionEndX = 0.0f;
    float selectionEndY = 0.0f;

    // Visibility
    bool visible = true;
    float opacity = 1.0f;

    // Timing for interpolation
    uint64_t lastUpdate = 0;

    /**
     * Interpolate cursor position
     */
    void interpolate(float t)
    {
        // Smooth interpolation between prev and current
        // t should be 0-1 based on time since last update
        // This is used for rendering, not the actual position
    }
};

/**
 * Activity information
 */
struct ActivityInfo
{
    ActivityType type = ActivityType::None;
    std::string description;        // e.g., "Editing laser pattern"
    std::string targetPath;         // Path/ID of what's being edited

    uint64_t startTime = 0;
    bool isActive = false;
};

/**
 * Typing indicator state
 */
struct TypingState
{
    bool isTyping = false;
    std::string context;            // e.g., "chat", "preset-name"
    uint64_t lastKeystroke = 0;
};

/**
 * Bio state for presence aura
 */
struct BioPresence
{
    float coherence = 0.0f;
    float relaxation = 0.0f;
    float heartRate = 0.0f;
    float breathRate = 0.0f;

    // Derived state
    bool isInFlowState = false;     // High coherence + activity
    bool isMeditating = false;      // High coherence + low activity

    // Aura visualization
    std::string auraColor;          // Based on bio state
    float auraIntensity = 0.0f;
    float auraPulseRate = 0.0f;     // Synced to heart rate
};

/**
 * Complete user presence state
 */
struct UserPresence
{
    UserId id;
    std::string displayName;
    std::string avatarUrl;
    std::string color;              // User-specific color for cursor/name

    // Status
    PresenceStatus status = PresenceStatus::Offline;
    uint64_t lastSeen = 0;
    uint64_t sessionStart = 0;

    // Cursor
    CursorState cursor;

    // Activity
    ActivityInfo activity;

    // Typing
    TypingState typing;

    // Bio (optional)
    BioPresence bio;

    // Device info
    std::string deviceType;         // "desktop", "mobile", "tablet"
    std::string platform;           // "windows", "macos", "ios", "android"

    // Focus
    std::string focusedElement;     // ID of UI element user is focused on
    std::string focusedTrack;       // Track ID if on timeline
    double focusedPosition = 0.0;   // Position on timeline

    bool operator==(const UserPresence& other) const
    {
        return id == other.id;
    }
};

/**
 * Configuration for presence system
 */
struct PresenceConfig
{
    uint32_t updateRateHz = PRESENCE_UPDATE_RATE_HZ;
    uint32_t idleTimeoutMs = IDLE_TIMEOUT_MS;
    uint32_t awayTimeoutMs = AWAY_TIMEOUT_MS;
    uint32_t typingTimeoutMs = TYPING_TIMEOUT_MS;

    bool shareCursor = true;
    bool shareActivity = true;
    bool shareTyping = true;
    bool shareBio = true;
    bool shareFocus = true;

    bool showIdleUsers = true;
    bool showAwayUsers = true;
    bool showInvisibleToSelf = true;

    // Cursor visualization
    bool smoothCursorInterpolation = true;
    uint32_t cursorInterpolationMs = CURSOR_INTERPOLATION_MS;
    bool showCursorTrails = false;
    uint32_t cursorTrailLength = 10;
};

//==============================================================================
// Lock-Free Triple Buffer for Presence State
//==============================================================================

template<typename T>
class TripleBuffer
{
public:
    TripleBuffer()
    {
        writeIndex_.store(0, std::memory_order_relaxed);
        readyIndex_.store(1, std::memory_order_relaxed);
        readIndex_.store(2, std::memory_order_relaxed);
    }

    T& getWriteBuffer()
    {
        return buffers_[writeIndex_.load(std::memory_order_relaxed)];
    }

    void publish()
    {
        // Swap write and ready buffers
        size_t write = writeIndex_.load(std::memory_order_relaxed);
        size_t ready = readyIndex_.exchange(write, std::memory_order_acq_rel);
        writeIndex_.store(ready, std::memory_order_release);
    }

    const T& getReadBuffer()
    {
        // Swap ready and read buffers if ready is newer
        size_t ready = readyIndex_.load(std::memory_order_acquire);
        size_t read = readIndex_.load(std::memory_order_relaxed);

        if (ready != read)
        {
            readyIndex_.compare_exchange_strong(ready, read,
                std::memory_order_acq_rel);
            readIndex_.store(ready, std::memory_order_release);
        }

        return buffers_[readIndex_.load(std::memory_order_relaxed)];
    }

private:
    std::array<T, 3> buffers_;
    std::atomic<size_t> writeIndex_;
    std::atomic<size_t> readyIndex_;
    std::atomic<size_t> readIndex_;
};

//==============================================================================
// Presence State Container
//==============================================================================

struct PresenceSnapshot
{
    std::array<UserPresence, MAX_USERS> users;
    std::array<bool, MAX_USERS> active;
    size_t userCount = 0;
    uint64_t timestamp = 0;
};

//==============================================================================
// Callbacks
//==============================================================================

using OnPresenceChangedCallback = std::function<void(const UserPresence&)>;
using OnUserOnlineCallback = std::function<void(const UserPresence&)>;
using OnUserOfflineCallback = std::function<void(const UserId&)>;
using OnCursorMovedCallback = std::function<void(const UserId&, float x, float y)>;
using OnActivityChangedCallback = std::function<void(const UserId&, const ActivityInfo&)>;
using OnTypingCallback = std::function<void(const UserId&, bool isTyping)>;

//==============================================================================
// Main Presence System
//==============================================================================

class EchoelPresenceSystem
{
public:
    static EchoelPresenceSystem& getInstance()
    {
        static EchoelPresenceSystem instance;
        return instance;
    }

    //==========================================================================
    // Lifecycle
    //==========================================================================

    bool initialize(const PresenceConfig& config)
    {
        if (initialized_)
            return true;

        config_ = config;

        // Start update thread
        running_ = true;
        updateThread_ = std::thread(&EchoelPresenceSystem::updateLoop, this);

        initialized_ = true;
        return true;
    }

    void shutdown()
    {
        if (!initialized_)
            return;

        running_ = false;
        if (updateThread_.joinable())
            updateThread_.join();

        initialized_ = false;
    }

    //==========================================================================
    // Local User
    //==========================================================================

    void setLocalUser(const UserId& id, const std::string& displayName)
    {
        std::lock_guard<std::mutex> lock(localMutex_);
        localUser_.id = id;
        localUser_.displayName = displayName;
        localUser_.status = PresenceStatus::Online;
        localUser_.sessionStart = getCurrentTime();
        localUser_.lastSeen = localUser_.sessionStart;
    }

    void setLocalStatus(PresenceStatus status)
    {
        std::lock_guard<std::mutex> lock(localMutex_);
        localUser_.status = status;
        localUser_.lastSeen = getCurrentTime();
        markDirty();
    }

    void setLocalColor(const std::string& color)
    {
        std::lock_guard<std::mutex> lock(localMutex_);
        localUser_.color = color;
        markDirty();
    }

    UserPresence getLocalUser() const
    {
        std::lock_guard<std::mutex> lock(localMutex_);
        return localUser_;
    }

    //==========================================================================
    // Cursor
    //==========================================================================

    /**
     * Update local cursor position (called frequently)
     */
    void updateCursor(float x, float y, bool normalized = true)
    {
        if (!config_.shareCursor)
            return;

        std::lock_guard<std::mutex> lock(localMutex_);

        localUser_.cursor.prevX = localUser_.cursor.x;
        localUser_.cursor.prevY = localUser_.cursor.y;
        localUser_.cursor.x = x;
        localUser_.cursor.y = y;
        localUser_.cursor.normalized = normalized;
        localUser_.cursor.lastUpdate = getCurrentTime();
        localUser_.lastSeen = localUser_.cursor.lastUpdate;

        markDirty();
    }

    void setCursorType(CursorType type)
    {
        std::lock_guard<std::mutex> lock(localMutex_);
        localUser_.cursor.type = type;
        markDirty();
    }

    void setCursorVisible(bool visible)
    {
        std::lock_guard<std::mutex> lock(localMutex_);
        localUser_.cursor.visible = visible;
        markDirty();
    }

    void setSelection(float startX, float startY, float endX, float endY)
    {
        std::lock_guard<std::mutex> lock(localMutex_);
        localUser_.cursor.hasSelection = true;
        localUser_.cursor.selectionStartX = startX;
        localUser_.cursor.selectionStartY = startY;
        localUser_.cursor.selectionEndX = endX;
        localUser_.cursor.selectionEndY = endY;
        markDirty();
    }

    void clearSelection()
    {
        std::lock_guard<std::mutex> lock(localMutex_);
        localUser_.cursor.hasSelection = false;
        markDirty();
    }

    //==========================================================================
    // Activity
    //==========================================================================

    void setActivity(ActivityType type, const std::string& description = "",
                     const std::string& targetPath = "")
    {
        if (!config_.shareActivity)
            return;

        std::lock_guard<std::mutex> lock(localMutex_);

        localUser_.activity.type = type;
        localUser_.activity.description = description;
        localUser_.activity.targetPath = targetPath;
        localUser_.activity.startTime = getCurrentTime();
        localUser_.activity.isActive = true;
        localUser_.lastSeen = localUser_.activity.startTime;

        markDirty();

        if (onActivityChanged_)
            onActivityChanged_(localUser_.id, localUser_.activity);
    }

    void clearActivity()
    {
        std::lock_guard<std::mutex> lock(localMutex_);
        localUser_.activity = ActivityInfo();
        markDirty();
    }

    //==========================================================================
    // Typing
    //==========================================================================

    void startTyping(const std::string& context = "chat")
    {
        if (!config_.shareTyping)
            return;

        std::lock_guard<std::mutex> lock(localMutex_);

        localUser_.typing.isTyping = true;
        localUser_.typing.context = context;
        localUser_.typing.lastKeystroke = getCurrentTime();
        localUser_.lastSeen = localUser_.typing.lastKeystroke;

        markDirty();

        if (onTyping_)
            onTyping_(localUser_.id, true);
    }

    void stopTyping()
    {
        std::lock_guard<std::mutex> lock(localMutex_);

        if (localUser_.typing.isTyping)
        {
            localUser_.typing.isTyping = false;
            markDirty();

            if (onTyping_)
                onTyping_(localUser_.id, false);
        }
    }

    void keystroke()
    {
        std::lock_guard<std::mutex> lock(localMutex_);
        localUser_.typing.lastKeystroke = getCurrentTime();
        localUser_.lastSeen = localUser_.typing.lastKeystroke;

        if (!localUser_.typing.isTyping)
        {
            localUser_.typing.isTyping = true;
            markDirty();
        }
    }

    //==========================================================================
    // Bio State
    //==========================================================================

    void updateBioState(float coherence, float relaxation,
                        float heartRate = 0.0f, float breathRate = 0.0f)
    {
        if (!config_.shareBio)
            return;

        std::lock_guard<std::mutex> lock(localMutex_);

        localUser_.bio.coherence = coherence;
        localUser_.bio.relaxation = relaxation;
        localUser_.bio.heartRate = heartRate;
        localUser_.bio.breathRate = breathRate;

        // Derive states
        bool wasInFlow = localUser_.bio.isInFlowState;
        localUser_.bio.isInFlowState = (coherence >= 0.7f &&
            localUser_.activity.type == ActivityType::Editing);

        bool wasMeditating = localUser_.bio.isMeditating;
        localUser_.bio.isMeditating = (coherence >= 0.7f &&
            localUser_.activity.type == ActivityType::None);

        // Calculate aura
        updateAura();

        // Update activity if transitioning to meditation
        if (localUser_.bio.isMeditating && !wasMeditating)
        {
            localUser_.activity.type = ActivityType::Meditating;
            localUser_.activity.startTime = getCurrentTime();
        }

        markDirty();
    }

    //==========================================================================
    // Focus
    //==========================================================================

    void setFocus(const std::string& elementId)
    {
        if (!config_.shareFocus)
            return;

        std::lock_guard<std::mutex> lock(localMutex_);
        localUser_.focusedElement = elementId;
        localUser_.lastSeen = getCurrentTime();
        markDirty();
    }

    void setTimelineFocus(const std::string& trackId, double position)
    {
        if (!config_.shareFocus)
            return;

        std::lock_guard<std::mutex> lock(localMutex_);
        localUser_.focusedTrack = trackId;
        localUser_.focusedPosition = position;
        localUser_.lastSeen = getCurrentTime();
        markDirty();
    }

    //==========================================================================
    // Remote Users
    //==========================================================================

    /**
     * Get all online users
     */
    std::vector<UserPresence> getOnlineUsers() const
    {
        const auto& snapshot = presenceBuffer_.getReadBuffer();
        std::vector<UserPresence> result;

        for (size_t i = 0; i < snapshot.userCount; ++i)
        {
            if (snapshot.active[i])
            {
                const auto& user = snapshot.users[i];
                if (user.status != PresenceStatus::Offline &&
                    (user.status != PresenceStatus::Invisible || config_.showInvisibleToSelf))
                {
                    result.push_back(user);
                }
            }
        }

        return result;
    }

    /**
     * Get specific user's presence
     */
    std::optional<UserPresence> getUserPresence(const UserId& id) const
    {
        const auto& snapshot = presenceBuffer_.getReadBuffer();

        for (size_t i = 0; i < snapshot.userCount; ++i)
        {
            if (snapshot.active[i] && snapshot.users[i].id == id)
            {
                return snapshot.users[i];
            }
        }

        return std::nullopt;
    }

    /**
     * Handle incoming presence update from remote user
     */
    void handleRemotePresence(const UserPresence& presence)
    {
        bool isNew = false;

        {
            std::lock_guard<std::mutex> lock(remoteMutex_);

            auto it = remoteUsers_.find(presence.id);
            if (it == remoteUsers_.end())
            {
                remoteUsers_[presence.id] = presence;
                isNew = true;
            }
            else
            {
                it->second = presence;
            }
        }

        if (isNew && onUserOnline_)
            onUserOnline_(presence);

        if (onPresenceChanged_)
            onPresenceChanged_(presence);

        if (onCursorMoved_ && presence.cursor.visible)
            onCursorMoved_(presence.id, presence.cursor.x, presence.cursor.y);
    }

    /**
     * Handle user going offline
     */
    void handleUserOffline(const UserId& id)
    {
        {
            std::lock_guard<std::mutex> lock(remoteMutex_);
            remoteUsers_.erase(id);
        }

        if (onUserOffline_)
            onUserOffline_(id);
    }

    //==========================================================================
    // Rendering Helpers
    //==========================================================================

    /**
     * Get interpolated cursor position for smooth rendering
     */
    std::pair<float, float> getInterpolatedCursor(const UserId& id,
                                                   uint64_t renderTime) const
    {
        auto presence = getUserPresence(id);
        if (!presence)
            return {0.0f, 0.0f};

        const auto& cursor = presence->cursor;

        if (!config_.smoothCursorInterpolation)
            return {cursor.x, cursor.y};

        // Calculate interpolation factor
        uint64_t elapsed = renderTime - cursor.lastUpdate;
        float t = std::min(1.0f, static_cast<float>(elapsed) / config_.cursorInterpolationMs);

        // Smooth interpolation
        float x = cursor.prevX + (cursor.x - cursor.prevX) * t;
        float y = cursor.prevY + (cursor.y - cursor.prevY) * t;

        return {x, y};
    }

    /**
     * Get cursor trail points for visualization
     */
    std::vector<std::pair<float, float>> getCursorTrail(const UserId& id) const
    {
        std::lock_guard<std::mutex> lock(trailMutex_);

        auto it = cursorTrails_.find(id);
        if (it != cursorTrails_.end())
        {
            return std::vector<std::pair<float, float>>(
                it->second.begin(), it->second.end());
        }

        return {};
    }

    //==========================================================================
    // Callbacks
    //==========================================================================

    void setOnPresenceChanged(OnPresenceChangedCallback cb) { onPresenceChanged_ = std::move(cb); }
    void setOnUserOnline(OnUserOnlineCallback cb) { onUserOnline_ = std::move(cb); }
    void setOnUserOffline(OnUserOfflineCallback cb) { onUserOffline_ = std::move(cb); }
    void setOnCursorMoved(OnCursorMovedCallback cb) { onCursorMoved_ = std::move(cb); }
    void setOnActivityChanged(OnActivityChangedCallback cb) { onActivityChanged_ = std::move(cb); }
    void setOnTyping(OnTypingCallback cb) { onTyping_ = std::move(cb); }

    //==========================================================================
    // Configuration
    //==========================================================================

    void setConfig(const PresenceConfig& config)
    {
        config_ = config;
    }

    PresenceConfig getConfig() const { return config_; }

    //==========================================================================
    // Serialization
    //==========================================================================

    /**
     * Serialize local presence for network transmission
     */
    std::vector<uint8_t> serializeLocalPresence() const
    {
        std::lock_guard<std::mutex> lock(localMutex_);

        std::vector<uint8_t> data;
        data.reserve(256);

        // User ID (16 bytes)
        data.insert(data.end(), localUser_.id.uuid.begin(), localUser_.id.uuid.end());

        // Status (1 byte)
        data.push_back(static_cast<uint8_t>(localUser_.status));

        // Cursor (17 bytes: visible + x + y + type)
        data.push_back(localUser_.cursor.visible ? 1 : 0);
        appendFloat(data, localUser_.cursor.x);
        appendFloat(data, localUser_.cursor.y);
        data.push_back(static_cast<uint8_t>(localUser_.cursor.type));

        // Activity (2 bytes: type + isActive)
        data.push_back(static_cast<uint8_t>(localUser_.activity.type));
        data.push_back(localUser_.activity.isActive ? 1 : 0);

        // Typing (1 byte)
        data.push_back(localUser_.typing.isTyping ? 1 : 0);

        // Bio (16 bytes: 4 floats)
        appendFloat(data, localUser_.bio.coherence);
        appendFloat(data, localUser_.bio.relaxation);
        appendFloat(data, localUser_.bio.heartRate);
        appendFloat(data, localUser_.bio.breathRate);

        return data;
    }

    /**
     * Deserialize remote presence from network
     */
    std::optional<UserPresence> deserializePresence(const uint8_t* data, size_t size) const
    {
        if (size < 53)  // Minimum size
            return std::nullopt;

        UserPresence presence;
        size_t offset = 0;

        // User ID
        std::copy(data + offset, data + offset + 16, presence.id.uuid.begin());
        offset += 16;

        // Status
        presence.status = static_cast<PresenceStatus>(data[offset++]);

        // Cursor
        presence.cursor.visible = data[offset++] != 0;
        presence.cursor.x = readFloat(data + offset); offset += 4;
        presence.cursor.y = readFloat(data + offset); offset += 4;
        presence.cursor.type = static_cast<CursorType>(data[offset++]);
        presence.cursor.lastUpdate = getCurrentTime();

        // Activity
        presence.activity.type = static_cast<ActivityType>(data[offset++]);
        presence.activity.isActive = data[offset++] != 0;

        // Typing
        presence.typing.isTyping = data[offset++] != 0;

        // Bio
        presence.bio.coherence = readFloat(data + offset); offset += 4;
        presence.bio.relaxation = readFloat(data + offset); offset += 4;
        presence.bio.heartRate = readFloat(data + offset); offset += 4;
        presence.bio.breathRate = readFloat(data + offset); offset += 4;

        presence.lastSeen = getCurrentTime();

        return presence;
    }

private:
    EchoelPresenceSystem() = default;
    ~EchoelPresenceSystem() { shutdown(); }

    EchoelPresenceSystem(const EchoelPresenceSystem&) = delete;
    EchoelPresenceSystem& operator=(const EchoelPresenceSystem&) = delete;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void updateLoop()
    {
        using namespace std::chrono;

        auto updateInterval = milliseconds(1000 / config_.updateRateHz);
        auto lastUpdate = steady_clock::now();

        while (running_)
        {
            auto now = steady_clock::now();

            if (duration_cast<milliseconds>(now - lastUpdate) >= updateInterval)
            {
                update();
                lastUpdate = now;
            }

            std::this_thread::sleep_for(milliseconds(1));
        }
    }

    void update()
    {
        uint64_t now = getCurrentTime();

        // Check typing timeout
        {
            std::lock_guard<std::mutex> lock(localMutex_);
            if (localUser_.typing.isTyping &&
                now - localUser_.typing.lastKeystroke > config_.typingTimeoutMs)
            {
                localUser_.typing.isTyping = false;
                markDirty();

                if (onTyping_)
                    onTyping_(localUser_.id, false);
            }

            // Check idle/away status
            updateIdleStatus(now);
        }

        // Update cursor trails
        if (config_.showCursorTrails)
        {
            updateCursorTrails();
        }

        // Build snapshot if dirty
        if (dirty_.exchange(false))
        {
            buildSnapshot();
        }
    }

    void updateIdleStatus(uint64_t now)
    {
        if (localUser_.status == PresenceStatus::DoNotDisturb ||
            localUser_.status == PresenceStatus::Invisible)
            return;

        uint64_t inactiveTime = now - localUser_.lastSeen;

        if (inactiveTime >= config_.awayTimeoutMs &&
            localUser_.status != PresenceStatus::Away)
        {
            localUser_.status = PresenceStatus::Away;
            markDirty();
        }
        else if (inactiveTime >= config_.idleTimeoutMs &&
                 localUser_.status == PresenceStatus::Online)
        {
            localUser_.status = PresenceStatus::Idle;
            markDirty();
        }
        else if (inactiveTime < config_.idleTimeoutMs &&
                 localUser_.status != PresenceStatus::Online)
        {
            localUser_.status = PresenceStatus::Online;
            markDirty();
        }
    }

    void updateCursorTrails()
    {
        std::lock_guard<std::mutex> lock(trailMutex_);

        // Update local trail
        auto& localTrail = cursorTrails_[localUser_.id];
        localTrail.push_back({localUser_.cursor.x, localUser_.cursor.y});
        while (localTrail.size() > config_.cursorTrailLength)
            localTrail.pop_front();

        // Update remote trails
        std::lock_guard<std::mutex> remoteLock(remoteMutex_);
        for (const auto& [id, user] : remoteUsers_)
        {
            auto& trail = cursorTrails_[id];
            trail.push_back({user.cursor.x, user.cursor.y});
            while (trail.size() > config_.cursorTrailLength)
                trail.pop_front();
        }
    }

    void updateAura()
    {
        // Calculate aura color based on bio state
        float h = localUser_.bio.coherence;  // 0-1 maps to color hue

        if (localUser_.bio.coherence >= 0.7f)
        {
            localUser_.bio.auraColor = "#00FF88";  // Green for high coherence
        }
        else if (localUser_.bio.coherence >= 0.4f)
        {
            localUser_.bio.auraColor = "#00CCFF";  // Blue for medium
        }
        else
        {
            localUser_.bio.auraColor = "#FF8800";  // Orange for low
        }

        localUser_.bio.auraIntensity = localUser_.bio.coherence;
        localUser_.bio.auraPulseRate = localUser_.bio.heartRate / 60.0f;  // Beats per second
    }

    void buildSnapshot()
    {
        auto& write = presenceBuffer_.getWriteBuffer();
        write.timestamp = getCurrentTime();
        write.userCount = 0;

        // Add local user
        {
            std::lock_guard<std::mutex> lock(localMutex_);
            write.users[0] = localUser_;
            write.active[0] = true;
            write.userCount = 1;
        }

        // Add remote users
        {
            std::lock_guard<std::mutex> lock(remoteMutex_);
            for (const auto& [id, user] : remoteUsers_)
            {
                if (write.userCount >= MAX_USERS)
                    break;

                write.users[write.userCount] = user;
                write.active[write.userCount] = true;
                write.userCount++;
            }
        }

        presenceBuffer_.publish();
    }

    void markDirty()
    {
        dirty_.store(true, std::memory_order_release);
    }

    uint64_t getCurrentTime() const
    {
        return std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now().time_since_epoch()
        ).count();
    }

    static void appendFloat(std::vector<uint8_t>& data, float value)
    {
        uint32_t bits;
        std::memcpy(&bits, &value, sizeof(float));
        data.push_back(static_cast<uint8_t>(bits & 0xFF));
        data.push_back(static_cast<uint8_t>((bits >> 8) & 0xFF));
        data.push_back(static_cast<uint8_t>((bits >> 16) & 0xFF));
        data.push_back(static_cast<uint8_t>((bits >> 24) & 0xFF));
    }

    static float readFloat(const uint8_t* data)
    {
        uint32_t bits = data[0] | (data[1] << 8) | (data[2] << 16) | (data[3] << 24);
        float value;
        std::memcpy(&value, &bits, sizeof(float));
        return value;
    }

    //==========================================================================
    // Member Variables
    //==========================================================================

    bool initialized_ = false;
    std::atomic<bool> running_{false};
    std::atomic<bool> dirty_{false};

    PresenceConfig config_;

    mutable std::mutex localMutex_;
    UserPresence localUser_;

    std::mutex remoteMutex_;
    std::unordered_map<UserId, UserPresence, UserIdHash> remoteUsers_;

    TripleBuffer<PresenceSnapshot> presenceBuffer_;

    mutable std::mutex trailMutex_;
    std::unordered_map<UserId, std::deque<std::pair<float, float>>, UserIdHash> cursorTrails_;

    std::thread updateThread_;

    // Callbacks
    OnPresenceChangedCallback onPresenceChanged_;
    OnUserOnlineCallback onUserOnline_;
    OnUserOfflineCallback onUserOffline_;
    OnCursorMovedCallback onCursorMoved_;
    OnActivityChangedCallback onActivityChanged_;
    OnTypingCallback onTyping_;
};

}} // namespace Echoel::Presence
