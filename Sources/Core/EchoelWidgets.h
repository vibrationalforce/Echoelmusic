/**
 * EchoelWidgets.h
 *
 * iOS/macOS Widget System & Home Screen Integration
 *
 * Comprehensive widget support for Echoel Music:
 * - iOS Home Screen widgets (small, medium, large, extra large)
 * - macOS Notification Center widgets
 * - Lock Screen widgets (iOS 16+)
 * - StandBy mode widgets (iOS 17+)
 * - Apple Watch complications
 * - Interactive widgets (iOS 17+)
 * - Live Activities for recording sessions
 * - Dynamic Island integration
 * - Control Center controls
 * - Quick actions (3D Touch / Haptic Touch)
 *
 * Part of Ralph Wiggum Genius Loop Mode - Phase 1
 * "My cat's breath smells like cat food!" - Ralph Wiggum
 */

#pragma once

#include <string>
#include <vector>
#include <map>
#include <memory>
#include <functional>
#include <chrono>
#include <optional>
#include <variant>
#include <atomic>
#include <mutex>

namespace Echoel {

// ============================================================================
// Widget Size & Family
// ============================================================================

enum class WidgetFamily {
    // iOS Home Screen
    SystemSmall,      // 2x2 grid squares
    SystemMedium,     // 4x2 grid squares
    SystemLarge,      // 4x4 grid squares
    SystemExtraLarge, // 8x4 grid squares (iPad only)

    // Lock Screen (iOS 16+)
    AccessoryCircular,
    AccessoryRectangular,
    AccessoryInline,

    // Apple Watch
    WatchSmall,
    WatchMedium,
    WatchLarge,

    // macOS
    MacSmall,
    MacMedium,
    MacLarge
};

enum class WidgetContext {
    HomeScreen,
    LockScreen,
    StandBy,
    NotificationCenter,
    AppleWatch,
    DynamicIsland
};

// ============================================================================
// Widget Data Types
// ============================================================================

struct ProjectStatus {
    std::string projectName;
    std::string lastModified;
    float completionPercentage = 0.0f;
    int trackCount = 0;
    std::chrono::seconds duration{0};
    bool isPlaying = false;
    bool isRecording = false;
    std::string thumbnailPath;
};

struct SessionStats {
    std::chrono::seconds todayTotal{0};
    std::chrono::seconds weekTotal{0};
    std::chrono::seconds monthTotal{0};
    int projectsWorkedOn = 0;
    int tracksCreated = 0;
    int samplesRecorded = 0;
    float streakDays = 0;
};

struct QuickAction {
    std::string id;
    std::string title;
    std::string iconName;
    std::string deepLink;
    bool isEnabled = true;
};

struct TransportState {
    bool isPlaying = false;
    bool isRecording = false;
    bool isLooping = false;
    float bpm = 120.0f;
    std::string timePosition;  // e.g., "1:23:45"
    std::string currentMarker;
};

struct MixerSnapshot {
    std::string trackName;
    float level = 0.0f;       // -inf to +6 dB
    float pan = 0.0f;         // -1.0 to +1.0
    bool muted = false;
    bool soloed = false;
    bool armed = false;
    float peakLeft = 0.0f;
    float peakRight = 0.0f;
};

// ============================================================================
// Widget Configuration
// ============================================================================

struct WidgetConfiguration {
    std::string widgetId;
    std::string displayName;
    WidgetFamily family = WidgetFamily::SystemSmall;

    // What to display
    enum class DisplayMode {
        CurrentProject,
        RecentProjects,
        SessionStats,
        QuickActions,
        Transport,
        MixerLevels,
        LoopPlayer,
        Metronome,
        Tuner,
        Timer,
        Inspiration
    } displayMode = DisplayMode::CurrentProject;

    // Customization
    std::string colorScheme = "auto";  // auto, light, dark, accent
    std::string accentColor = "#4A90D9";
    bool showBackground = true;
    float backgroundOpacity = 0.9f;
    bool showGradient = true;

    // Refresh
    std::chrono::minutes refreshInterval{15};
    bool enableLiveUpdates = true;

    // Actions
    std::vector<QuickAction> quickActions;
    std::string tapAction;  // Deep link on tap
};

// ============================================================================
// Live Activity (Dynamic Island)
// ============================================================================

struct LiveActivityState {
    std::string activityId;

    enum class ActivityType {
        Recording,
        Playback,
        Export,
        CloudSync,
        Collaboration,
        Timer
    } type = ActivityType::Recording;

    // Common state
    std::string title;
    std::string subtitle;
    std::chrono::seconds elapsed{0};
    std::chrono::seconds total{0};
    float progress = 0.0f;

    // Recording specific
    bool isRecording = false;
    float inputLevel = 0.0f;
    std::string inputSource;

    // Playback specific
    bool isPlaying = false;
    std::string trackName;
    std::string artistName;
    std::string albumArt;

    // Export specific
    std::string exportFormat;
    std::string outputPath;

    // Collaboration specific
    int collaborators = 0;
    std::vector<std::string> activeUsers;

    bool isPaused = false;
    bool showExpandedView = true;
};

// ============================================================================
// Control Center Controls
// ============================================================================

struct ControlCenterControl {
    std::string id;
    std::string title;
    std::string iconName;

    enum class ControlType {
        Toggle,
        Button,
        Slider,
        Picker
    } type = ControlType::Button;

    // State
    bool isOn = false;
    float value = 0.0f;
    int selectedIndex = 0;
    std::vector<std::string> options;

    std::function<void()> onTap;
    std::function<void(float)> onValueChange;
};

// ============================================================================
// StandBy Mode Configuration
// ============================================================================

struct StandByConfiguration {
    bool enabledInStandBy = true;

    enum class StandByStyle {
        Clock,      // Show clock with music status
        NowPlaying, // Focus on current playback
        Meters,     // Show level meters
        Minimal     // Just transport controls
    } style = StandByStyle::NowPlaying;

    bool showRedAccent = true;  // Red tint in dark StandBy
    bool useNightMode = true;   // Dim in bedroom
};

// ============================================================================
// Widget Data Provider
// ============================================================================

class WidgetDataProvider {
public:
    static WidgetDataProvider& getInstance() {
        static WidgetDataProvider instance;
        return instance;
    }

    // ========================================================================
    // Project Data
    // ========================================================================

    ProjectStatus getCurrentProject() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return currentProject_;
    }

    void updateCurrentProject(const ProjectStatus& project) {
        std::lock_guard<std::mutex> lock(mutex_);
        currentProject_ = project;
        notifyWidgets();
    }

    std::vector<ProjectStatus> getRecentProjects(int count = 5) const {
        std::lock_guard<std::mutex> lock(mutex_);
        std::vector<ProjectStatus> result;
        int limit = std::min(count, static_cast<int>(recentProjects_.size()));
        for (int i = 0; i < limit; ++i) {
            result.push_back(recentProjects_[i]);
        }
        return result;
    }

    void addRecentProject(const ProjectStatus& project) {
        std::lock_guard<std::mutex> lock(mutex_);

        // Remove if already exists
        recentProjects_.erase(
            std::remove_if(recentProjects_.begin(), recentProjects_.end(),
                [&](const ProjectStatus& p) {
                    return p.projectName == project.projectName;
                }),
            recentProjects_.end()
        );

        // Add to front
        recentProjects_.insert(recentProjects_.begin(), project);

        // Keep max 20
        if (recentProjects_.size() > 20) {
            recentProjects_.resize(20);
        }

        notifyWidgets();
    }

    // ========================================================================
    // Session Statistics
    // ========================================================================

    SessionStats getSessionStats() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return sessionStats_;
    }

    void updateSessionStats(const SessionStats& stats) {
        std::lock_guard<std::mutex> lock(mutex_);
        sessionStats_ = stats;
        notifyWidgets();
    }

    void addSessionTime(std::chrono::seconds time) {
        std::lock_guard<std::mutex> lock(mutex_);
        sessionStats_.todayTotal += time;
        notifyWidgets();
    }

    // ========================================================================
    // Transport State
    // ========================================================================

    TransportState getTransportState() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return transportState_;
    }

    void updateTransportState(const TransportState& state) {
        std::lock_guard<std::mutex> lock(mutex_);
        transportState_ = state;
        notifyWidgets();
        updateLiveActivity();
    }

    // ========================================================================
    // Mixer Snapshots
    // ========================================================================

    std::vector<MixerSnapshot> getMixerSnapshots() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return mixerSnapshots_;
    }

    void updateMixerSnapshots(const std::vector<MixerSnapshot>& snapshots) {
        std::lock_guard<std::mutex> lock(mutex_);
        mixerSnapshots_ = snapshots;
        notifyWidgets();
    }

    // ========================================================================
    // Widget Refresh
    // ========================================================================

    void requestRefresh() {
        // Request iOS/macOS to refresh widgets
        // WidgetCenter.shared.reloadAllTimelines()
        notifyWidgets();
    }

    void requestRefresh(const std::string& widgetId) {
        // Request refresh for specific widget
        // WidgetCenter.shared.reloadTimelines(ofKind: widgetId)
    }

private:
    WidgetDataProvider() = default;

    void notifyWidgets() {
        lastUpdate_ = std::chrono::system_clock::now();
        // Would call into Swift/ObjC to refresh widgets
    }

    void updateLiveActivity() {
        // Update any active Live Activities
    }

    mutable std::mutex mutex_;

    ProjectStatus currentProject_;
    std::vector<ProjectStatus> recentProjects_;
    SessionStats sessionStats_;
    TransportState transportState_;
    std::vector<MixerSnapshot> mixerSnapshots_;

    std::chrono::system_clock::time_point lastUpdate_;
};

// ============================================================================
// Live Activity Manager
// ============================================================================

class LiveActivityManager {
public:
    static LiveActivityManager& getInstance() {
        static LiveActivityManager instance;
        return instance;
    }

    // ========================================================================
    // Activity Lifecycle
    // ========================================================================

    std::string startRecordingActivity(const std::string& trackName) {
        std::lock_guard<std::mutex> lock(mutex_);

        LiveActivityState state;
        state.activityId = generateActivityId();
        state.type = LiveActivityState::ActivityType::Recording;
        state.title = "Recording";
        state.subtitle = trackName;
        state.isRecording = true;

        activeActivities_[state.activityId] = state;

        // Would call ActivityKit to start Live Activity
        // Activity<EchoelActivityAttributes>.request(...)

        return state.activityId;
    }

    std::string startPlaybackActivity(const std::string& trackName,
                                       const std::string& artistName = "") {
        std::lock_guard<std::mutex> lock(mutex_);

        LiveActivityState state;
        state.activityId = generateActivityId();
        state.type = LiveActivityState::ActivityType::Playback;
        state.title = trackName;
        state.subtitle = artistName;
        state.isPlaying = true;

        activeActivities_[state.activityId] = state;

        return state.activityId;
    }

    std::string startExportActivity(const std::string& format,
                                     const std::string& outputPath) {
        std::lock_guard<std::mutex> lock(mutex_);

        LiveActivityState state;
        state.activityId = generateActivityId();
        state.type = LiveActivityState::ActivityType::Export;
        state.title = "Exporting";
        state.subtitle = format;
        state.exportFormat = format;
        state.outputPath = outputPath;

        activeActivities_[state.activityId] = state;

        return state.activityId;
    }

    std::string startCollaborationActivity(int collaboratorCount) {
        std::lock_guard<std::mutex> lock(mutex_);

        LiveActivityState state;
        state.activityId = generateActivityId();
        state.type = LiveActivityState::ActivityType::Collaboration;
        state.title = "Collaborating";
        state.subtitle = std::to_string(collaboratorCount) + " collaborators";
        state.collaborators = collaboratorCount;

        activeActivities_[state.activityId] = state;

        return state.activityId;
    }

    // ========================================================================
    // Activity Updates
    // ========================================================================

    void updateActivity(const std::string& activityId,
                        const LiveActivityState& newState) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = activeActivities_.find(activityId);
        if (it != activeActivities_.end()) {
            it->second = newState;
            it->second.activityId = activityId;

            // Would update ActivityKit
            // activity.update(...)
        }
    }

    void updateProgress(const std::string& activityId, float progress) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = activeActivities_.find(activityId);
        if (it != activeActivities_.end()) {
            it->second.progress = progress;
            // Update ActivityKit
        }
    }

    void updateInputLevel(const std::string& activityId, float level) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = activeActivities_.find(activityId);
        if (it != activeActivities_.end()) {
            it->second.inputLevel = level;
            // Update ActivityKit (throttled for performance)
        }
    }

    void pauseActivity(const std::string& activityId) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = activeActivities_.find(activityId);
        if (it != activeActivities_.end()) {
            it->second.isPaused = true;
            it->second.isPlaying = false;
            it->second.isRecording = false;
        }
    }

    void resumeActivity(const std::string& activityId) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = activeActivities_.find(activityId);
        if (it != activeActivities_.end()) {
            it->second.isPaused = false;
            if (it->second.type == LiveActivityState::ActivityType::Recording) {
                it->second.isRecording = true;
            } else if (it->second.type == LiveActivityState::ActivityType::Playback) {
                it->second.isPlaying = true;
            }
        }
    }

    void endActivity(const std::string& activityId) {
        std::lock_guard<std::mutex> lock(mutex_);

        activeActivities_.erase(activityId);

        // Would end ActivityKit activity
        // activity.end(...)
    }

    void endAllActivities() {
        std::lock_guard<std::mutex> lock(mutex_);
        activeActivities_.clear();
    }

    // ========================================================================
    // Query Activities
    // ========================================================================

    std::optional<LiveActivityState> getActivity(const std::string& activityId) const {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = activeActivities_.find(activityId);
        if (it != activeActivities_.end()) {
            return it->second;
        }
        return std::nullopt;
    }

    std::vector<LiveActivityState> getAllActivities() const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<LiveActivityState> result;
        for (const auto& [id, state] : activeActivities_) {
            result.push_back(state);
        }
        return result;
    }

    bool hasActiveRecording() const {
        std::lock_guard<std::mutex> lock(mutex_);

        for (const auto& [id, state] : activeActivities_) {
            if (state.type == LiveActivityState::ActivityType::Recording &&
                state.isRecording) {
                return true;
            }
        }
        return false;
    }

private:
    LiveActivityManager() = default;

    std::string generateActivityId() {
        return "activity_" + std::to_string(nextActivityId_++);
    }

    mutable std::mutex mutex_;
    std::map<std::string, LiveActivityState> activeActivities_;
    std::atomic<int> nextActivityId_{1};
};

// ============================================================================
// Control Center Manager
// ============================================================================

class ControlCenterManager {
public:
    static ControlCenterManager& getInstance() {
        static ControlCenterManager instance;
        return instance;
    }

    void registerControls() {
        // Register Echoel controls for Control Center

        // Play/Pause toggle
        registerControl({
            .id = "transport.playpause",
            .title = "Play/Pause",
            .iconName = "play.fill",
            .type = ControlCenterControl::ControlType::Toggle,
            .isOn = false,
            .onTap = []() {
                // Toggle playback
            }
        });

        // Record button
        registerControl({
            .id = "transport.record",
            .title = "Record",
            .iconName = "record.circle",
            .type = ControlCenterControl::ControlType::Toggle,
            .isOn = false,
            .onTap = []() {
                // Toggle recording
            }
        });

        // Metronome toggle
        registerControl({
            .id = "metronome.toggle",
            .title = "Metronome",
            .iconName = "metronome",
            .type = ControlCenterControl::ControlType::Toggle,
            .isOn = false,
            .onTap = []() {
                // Toggle metronome
            }
        });

        // BPM slider
        registerControl({
            .id = "tempo.bpm",
            .title = "BPM",
            .iconName = "speedometer",
            .type = ControlCenterControl::ControlType::Slider,
            .value = 120.0f,
            .onValueChange = [](float bpm) {
                // Set tempo
            }
        });
    }

    void registerControl(const ControlCenterControl& control) {
        std::lock_guard<std::mutex> lock(mutex_);
        controls_[control.id] = control;
    }

    void updateControlState(const std::string& controlId, bool isOn) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = controls_.find(controlId);
        if (it != controls_.end()) {
            it->second.isOn = isOn;
        }
    }

    void updateControlValue(const std::string& controlId, float value) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = controls_.find(controlId);
        if (it != controls_.end()) {
            it->second.value = value;
        }
    }

private:
    ControlCenterManager() = default;

    mutable std::mutex mutex_;
    std::map<std::string, ControlCenterControl> controls_;
};

// ============================================================================
// Quick Actions (3D Touch / Haptic Touch)
// ============================================================================

class QuickActionsManager {
public:
    static QuickActionsManager& getInstance() {
        static QuickActionsManager instance;
        return instance;
    }

    void registerQuickActions() {
        std::lock_guard<std::mutex> lock(mutex_);

        // Static quick actions (defined in Info.plist)
        quickActions_ = {
            {
                .id = "new_project",
                .title = "New Project",
                .iconName = "plus.circle.fill",
                .deepLink = "echoel://new-project"
            },
            {
                .id = "recent_project",
                .title = "Recent Project",
                .iconName = "clock.fill",
                .deepLink = "echoel://recent"
            },
            {
                .id = "quick_record",
                .title = "Quick Record",
                .iconName = "mic.circle.fill",
                .deepLink = "echoel://quick-record"
            },
            {
                .id = "browse_sounds",
                .title = "Browse Sounds",
                .iconName = "waveform",
                .deepLink = "echoel://sounds"
            }
        };
    }

    void updateDynamicActions() {
        // Update quick actions based on recent activity

        std::lock_guard<std::mutex> lock(mutex_);

        // Add most recent project as quick action
        auto& dataProvider = WidgetDataProvider::getInstance();
        auto projects = dataProvider.getRecentProjects(1);

        if (!projects.empty()) {
            dynamicActions_.clear();
            dynamicActions_.push_back({
                .id = "open_recent",
                .title = "Open " + projects[0].projectName,
                .iconName = "doc.fill",
                .deepLink = "echoel://open?project=" + projects[0].projectName
            });
        }

        // Would call UIApplication to update shortcuts
    }

    std::vector<QuickAction> getAllActions() const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<QuickAction> all;
        all.insert(all.end(), quickActions_.begin(), quickActions_.end());
        all.insert(all.end(), dynamicActions_.begin(), dynamicActions_.end());
        return all;
    }

    void handleAction(const std::string& actionId) {
        // Handle quick action selection
        // Would navigate to appropriate deep link
    }

private:
    QuickActionsManager() = default;

    mutable std::mutex mutex_;
    std::vector<QuickAction> quickActions_;
    std::vector<QuickAction> dynamicActions_;
};

// ============================================================================
// Widget Timeline Provider
// ============================================================================

struct WidgetTimelineEntry {
    std::chrono::system_clock::time_point date;
    WidgetConfiguration configuration;

    // Data for this entry
    std::variant<
        ProjectStatus,
        SessionStats,
        TransportState,
        std::vector<QuickAction>,
        std::vector<MixerSnapshot>
    > data;
};

class WidgetTimelineProvider {
public:
    static WidgetTimelineProvider& getInstance() {
        static WidgetTimelineProvider instance;
        return instance;
    }

    std::vector<WidgetTimelineEntry> generateTimeline(
        const WidgetConfiguration& config,
        std::chrono::hours span = std::chrono::hours{24}) {

        std::vector<WidgetTimelineEntry> entries;
        auto now = std::chrono::system_clock::now();

        // Current entry
        WidgetTimelineEntry current;
        current.date = now;
        current.configuration = config;
        current.data = getDataForMode(config.displayMode);
        entries.push_back(current);

        // Future entries (for scheduled refreshes)
        auto interval = config.refreshInterval;
        auto endTime = now + span;

        while (now + interval < endTime) {
            now += interval;

            WidgetTimelineEntry entry;
            entry.date = now;
            entry.configuration = config;
            entry.data = getDataForMode(config.displayMode);
            entries.push_back(entry);
        }

        return entries;
    }

private:
    WidgetTimelineProvider() = default;

    std::variant<
        ProjectStatus,
        SessionStats,
        TransportState,
        std::vector<QuickAction>,
        std::vector<MixerSnapshot>
    > getDataForMode(WidgetConfiguration::DisplayMode mode) {

        auto& dataProvider = WidgetDataProvider::getInstance();

        switch (mode) {
            case WidgetConfiguration::DisplayMode::CurrentProject:
                return dataProvider.getCurrentProject();

            case WidgetConfiguration::DisplayMode::SessionStats:
                return dataProvider.getSessionStats();

            case WidgetConfiguration::DisplayMode::Transport:
                return dataProvider.getTransportState();

            case WidgetConfiguration::DisplayMode::QuickActions:
                return QuickActionsManager::getInstance().getAllActions();

            case WidgetConfiguration::DisplayMode::MixerLevels:
                return dataProvider.getMixerSnapshots();

            default:
                return dataProvider.getCurrentProject();
        }
    }
};

// ============================================================================
// Apple Watch Complications
// ============================================================================

struct WatchComplicationData {
    enum class ComplicationType {
        Circular,
        Rectangular,
        Inline,
        Graphic,
        ExtraLarge
    } type = ComplicationType::Circular;

    std::string title;
    std::string value;
    std::string iconName;
    float progress = 0.0f;

    std::optional<std::string> tintColor;
};

class WatchComplicationProvider {
public:
    static WatchComplicationProvider& getInstance() {
        static WatchComplicationProvider instance;
        return instance;
    }

    WatchComplicationData getCurrentComplication(
        WatchComplicationData::ComplicationType type) const {

        WatchComplicationData data;
        data.type = type;

        auto& dataProvider = WidgetDataProvider::getInstance();
        auto stats = dataProvider.getSessionStats();
        auto transport = dataProvider.getTransportState();

        switch (type) {
            case WatchComplicationData::ComplicationType::Circular:
                data.iconName = transport.isPlaying ? "play.fill" : "pause.fill";
                data.progress = 0.0f;  // Session progress
                break;

            case WatchComplicationData::ComplicationType::Rectangular:
                data.title = "Session";
                data.value = formatDuration(stats.todayTotal);
                data.iconName = "music.note";
                break;

            case WatchComplicationData::ComplicationType::Inline:
                data.value = transport.isPlaying ? "Playing" : "Paused";
                data.iconName = "waveform";
                break;

            default:
                break;
        }

        return data;
    }

    void refreshComplications() {
        // Request WatchKit to refresh complications
        // CLKComplicationServer.sharedInstance().reloadTimeline(for:)
    }

private:
    WatchComplicationProvider() = default;

    std::string formatDuration(std::chrono::seconds duration) const {
        auto hours = std::chrono::duration_cast<std::chrono::hours>(duration);
        auto mins = std::chrono::duration_cast<std::chrono::minutes>(duration - hours);

        return std::to_string(hours.count()) + "h " +
               std::to_string(mins.count()) + "m";
    }
};

// ============================================================================
// Convenience Functions
// ============================================================================

namespace Widgets {

inline void initialize() {
    // Initialize all widget systems
    QuickActionsManager::getInstance().registerQuickActions();
    ControlCenterManager::getInstance().registerControls();
}

inline void refresh() {
    WidgetDataProvider::getInstance().requestRefresh();
    WatchComplicationProvider::getInstance().refreshComplications();
    QuickActionsManager::getInstance().updateDynamicActions();
}

inline void updateProject(const ProjectStatus& project) {
    WidgetDataProvider::getInstance().updateCurrentProject(project);
    WidgetDataProvider::getInstance().addRecentProject(project);
    refresh();
}

inline void updateTransport(const TransportState& state) {
    WidgetDataProvider::getInstance().updateTransportState(state);
}

inline std::string startRecordingActivity(const std::string& trackName) {
    return LiveActivityManager::getInstance().startRecordingActivity(trackName);
}

inline void endActivity(const std::string& activityId) {
    LiveActivityManager::getInstance().endActivity(activityId);
}

} // namespace Widgets

} // namespace Echoel
