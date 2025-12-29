/**
 * EchoelFocusMode.h
 *
 * System Focus Mode Integration & Distraction-Free Environment
 *
 * Deep integration with system focus modes:
 * - iOS/macOS Focus Mode sync
 * - Custom Echoel focus profiles
 * - Notification filtering
 * - Time blocking
 * - Pomodoro timer integration
 * - Do Not Disturb automation
 * - Screen time integration
 * - Distraction blocking
 * - Ambient mode settings
 * - Creative flow state tracking
 *
 * Part of Ralph Wiggum Genius Loop Mode - Phase 1
 * "The doctor said I wouldn't have so many nosebleeds if I kept my finger outta there" - Ralph Wiggum
 */

#pragma once

#include <string>
#include <vector>
#include <map>
#include <set>
#include <memory>
#include <functional>
#include <chrono>
#include <optional>
#include <atomic>
#include <mutex>

namespace Echoel {

// ============================================================================
// Focus Mode Types
// ============================================================================

enum class SystemFocusMode {
    None,               // No system focus active
    DoNotDisturb,       // General DND
    Personal,           // Personal time
    Work,               // Work focus
    Sleep,              // Sleeping
    Driving,            // CarPlay/driving
    Fitness,            // Workout focus
    Gaming,             // Gaming focus
    Mindfulness,        // Meditation
    Reading,            // Reading focus
    Custom              // User-defined
};

enum class EchoelFocusMode {
    Off,                // Normal mode
    Creative,           // Deep creative work - minimal distractions
    Mixing,             // Mixing session - audio-focused
    Recording,          // Recording session - complete silence
    Collaboration,      // Team work - allow collaborator messages
    Learning,           // Tutorial/learning mode
    Performance,        // Live performance mode
    Ambient,            // Background music creation
    Meditation,         // Sound healing/meditation creation
    Custom              // User-defined
};

// ============================================================================
// Notification Filter
// ============================================================================

struct NotificationFilter {
    std::string id;
    std::string name;

    // What to allow
    bool allowCalls = false;
    bool allowMessages = false;
    bool allowMail = false;
    bool allowCalendar = true;
    bool allowReminders = true;
    bool allowCollaborators = true;  // Echoel collaborators

    // Specific apps
    std::set<std::string> allowedApps;
    std::set<std::string> blockedApps;

    // People
    std::set<std::string> allowedContacts;  // Only these people can reach
    bool allowFavorites = true;
    bool allowRepeatedCalls = true;  // Allow if same person calls twice

    // Time-based
    bool silenceAfterHours = true;
    std::chrono::hours quietHoursStart{22};
    std::chrono::hours quietHoursEnd{7};
};

// ============================================================================
// Focus Session
// ============================================================================

struct FocusSession {
    std::string id;
    EchoelFocusMode mode = EchoelFocusMode::Creative;

    std::chrono::system_clock::time_point startTime;
    std::chrono::system_clock::time_point endTime;
    std::optional<std::chrono::minutes> plannedDuration;

    // Session data
    std::string projectId;
    std::string projectName;
    std::vector<std::string> tracksWorkedOn;

    // Productivity metrics
    int notificationsBlocked = 0;
    int distractionsAvoided = 0;
    std::chrono::seconds activeTime{0};
    std::chrono::seconds idleTime{0};

    // Flow state
    enum class FlowState {
        Starting,       // Just beginning
        Warming,        // Getting into it
        Flowing,        // In the zone
        Cooling,        // Wrapping up
        Interrupted     // Flow broken
    } flowState = FlowState::Starting;

    float flowScore = 0.0f;  // 0-100

    // Notes
    std::string sessionNotes;
    std::vector<std::string> ideas;

    bool isActive = false;
    bool wasCompleted = false;
};

// ============================================================================
// Pomodoro Timer
// ============================================================================

struct PomodoroSettings {
    std::chrono::minutes focusDuration{25};
    std::chrono::minutes shortBreak{5};
    std::chrono::minutes longBreak{15};
    int cyclesBeforeLongBreak = 4;

    bool autoStartBreaks = true;
    bool autoStartFocus = false;

    // Sounds
    std::string focusStartSound = "gentle_bell";
    std::string breakStartSound = "soft_chime";
    std::string tickingSound = "";  // Optional ticking

    // Notifications
    bool showNotifications = true;
    bool playSound = true;
    bool vibrate = true;
};

struct PomodoroState {
    enum class Phase {
        Focus,
        ShortBreak,
        LongBreak,
        Idle
    } phase = Phase::Idle;

    int currentCycle = 0;
    int completedCycles = 0;

    std::chrono::steady_clock::time_point phaseStartTime;
    std::chrono::minutes remaining{0};

    bool isPaused = false;
    bool isRunning = false;
};

// ============================================================================
// Distraction Tracking
// ============================================================================

struct DistractionEvent {
    std::chrono::system_clock::time_point timestamp;

    enum class Type {
        Notification,       // System notification
        AppSwitch,          // Switched to another app
        BrowserTab,         // Opened browser
        SocialMedia,        // Social media access
        PhonePickup,        // Picked up phone
        ManualBreak,        // User took break
        ExternalInterrupt,  // Someone interrupted
        Unknown
    } type = Type::Unknown;

    std::string source;  // App/contact that caused distraction
    std::chrono::seconds duration{0};  // How long distracted

    bool wasBlocked = false;  // Did we block it?
    bool userChose = false;   // Did user choose to be distracted?
};

// ============================================================================
// Ambient Environment
// ============================================================================

struct AmbientSettings {
    // Screen
    bool dimScreen = true;
    float screenBrightness = 0.7f;
    bool nightShift = true;
    float nightShiftIntensity = 0.5f;

    // Color scheme
    enum class ColorScheme {
        Auto,
        Light,
        Dark,
        TrueDark,
        Custom
    } colorScheme = ColorScheme::Auto;

    std::string customAccentColor;

    // UI
    bool hideMenuBar = false;
    bool hideDock = false;
    bool fullScreen = false;
    bool zenMode = false;  // Ultra-minimal UI

    // Background sounds
    bool playAmbientSounds = false;
    std::string ambientSoundscape = "none";  // "rain", "forest", "cafe", etc.
    float ambientVolume = 0.3f;

    // Lighting (smart home)
    bool controlLights = false;
    std::string lightScene = "studio";
    float lightBrightness = 0.8f;
    int lightTemperature = 4000;  // Kelvin
};

// ============================================================================
// Focus Mode Manager
// ============================================================================

class FocusModeManager {
public:
    static FocusModeManager& getInstance() {
        static FocusModeManager instance;
        return instance;
    }

    // ========================================================================
    // System Focus Mode
    // ========================================================================

    void onSystemFocusModeChanged(SystemFocusMode mode) {
        std::lock_guard<std::mutex> lock(mutex_);
        currentSystemFocus_ = mode;

        // Auto-adjust Echoel settings based on system focus
        applySystemFocusSettings(mode);
    }

    SystemFocusMode getSystemFocusMode() const {
        return currentSystemFocus_;
    }

    bool requestSystemFocus(SystemFocusMode mode) {
        // Request iOS/macOS to activate focus mode
        // INFocusStatusCenter would be used on iOS
        return true;
    }

    // ========================================================================
    // Echoel Focus Mode
    // ========================================================================

    void startFocus(EchoelFocusMode mode, std::optional<std::chrono::minutes> duration = std::nullopt) {
        std::lock_guard<std::mutex> lock(mutex_);

        // End previous session if active
        if (currentSession_.isActive) {
            endFocusInternal();
        }

        // Start new session
        currentSession_ = FocusSession{};
        currentSession_.id = generateSessionId();
        currentSession_.mode = mode;
        currentSession_.startTime = std::chrono::system_clock::now();
        currentSession_.plannedDuration = duration;
        currentSession_.isActive = true;
        currentSession_.flowState = FocusSession::FlowState::Starting;

        // Apply focus settings
        currentMode_ = mode;
        applyFocusModeSettings(mode);

        // Notify listeners
        notifyFocusChange(mode);
    }

    void endFocus() {
        std::lock_guard<std::mutex> lock(mutex_);
        endFocusInternal();
    }

    void pauseFocus() {
        std::lock_guard<std::mutex> lock(mutex_);
        if (currentSession_.isActive) {
            focusPaused_ = true;
            // Temporarily restore notifications
        }
    }

    void resumeFocus() {
        std::lock_guard<std::mutex> lock(mutex_);
        if (currentSession_.isActive && focusPaused_) {
            focusPaused_ = false;
            applyFocusModeSettings(currentMode_);
        }
    }

    EchoelFocusMode getCurrentMode() const {
        return currentMode_;
    }

    FocusSession getCurrentSession() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return currentSession_;
    }

    bool isFocusActive() const {
        return currentSession_.isActive && !focusPaused_;
    }

    // ========================================================================
    // Pomodoro Timer
    // ========================================================================

    void startPomodoro() {
        std::lock_guard<std::mutex> lock(mutex_);

        pomodoroState_.phase = PomodoroState::Phase::Focus;
        pomodoroState_.phaseStartTime = std::chrono::steady_clock::now();
        pomodoroState_.remaining = pomodoroSettings_.focusDuration;
        pomodoroState_.isRunning = true;
        pomodoroState_.isPaused = false;

        // Also start focus mode
        if (!currentSession_.isActive) {
            startFocus(EchoelFocusMode::Creative, pomodoroSettings_.focusDuration);
        }
    }

    void pausePomodoro() {
        std::lock_guard<std::mutex> lock(mutex_);
        pomodoroState_.isPaused = true;
    }

    void resumePomodoro() {
        std::lock_guard<std::mutex> lock(mutex_);
        pomodoroState_.isPaused = false;
    }

    void stopPomodoro() {
        std::lock_guard<std::mutex> lock(mutex_);
        pomodoroState_.isRunning = false;
        pomodoroState_.phase = PomodoroState::Phase::Idle;
    }

    void skipPomodoroPhase() {
        std::lock_guard<std::mutex> lock(mutex_);
        advancePomodoroPhase();
    }

    PomodoroState getPomodoroState() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return pomodoroState_;
    }

    void setPomodoroSettings(const PomodoroSettings& settings) {
        std::lock_guard<std::mutex> lock(mutex_);
        pomodoroSettings_ = settings;
    }

    PomodoroSettings getPomodoroSettings() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return pomodoroSettings_;
    }

    // ========================================================================
    // Notification Filtering
    // ========================================================================

    void setNotificationFilter(const NotificationFilter& filter) {
        std::lock_guard<std::mutex> lock(mutex_);
        currentFilter_ = filter;
    }

    NotificationFilter getNotificationFilter() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return currentFilter_;
    }

    bool shouldAllowNotification(const std::string& appId,
                                  const std::string& contactId = "") const {
        std::lock_guard<std::mutex> lock(mutex_);

        if (!currentSession_.isActive) return true;

        const auto& filter = currentFilter_;

        // Check blocked apps first
        if (filter.blockedApps.count(appId) > 0) {
            return false;
        }

        // Check allowed apps
        if (filter.allowedApps.count(appId) > 0) {
            return true;
        }

        // Check contacts
        if (!contactId.empty()) {
            if (filter.allowedContacts.count(contactId) > 0) {
                return true;
            }
        }

        // Check collaborators
        if (filter.allowCollaborators && isCollaborator(contactId)) {
            return true;
        }

        // Default: block during focus
        return false;
    }

    void recordBlockedNotification() {
        std::lock_guard<std::mutex> lock(mutex_);
        if (currentSession_.isActive) {
            currentSession_.notificationsBlocked++;
        }
    }

    // ========================================================================
    // Distraction Tracking
    // ========================================================================

    void recordDistraction(const DistractionEvent& event) {
        std::lock_guard<std::mutex> lock(mutex_);

        distractionLog_.push_back(event);

        if (currentSession_.isActive) {
            currentSession_.distractionsAvoided++;

            // Check if flow was broken
            if (!event.wasBlocked && event.duration > std::chrono::seconds{30}) {
                currentSession_.flowState = FocusSession::FlowState::Interrupted;
                currentSession_.flowScore = std::max(0.0f, currentSession_.flowScore - 10.0f);
            }
        }
    }

    std::vector<DistractionEvent> getDistractionLog(
        std::optional<std::chrono::hours> within = std::nullopt) const {

        std::lock_guard<std::mutex> lock(mutex_);

        if (!within) {
            return distractionLog_;
        }

        auto cutoff = std::chrono::system_clock::now() - *within;
        std::vector<DistractionEvent> filtered;

        for (const auto& event : distractionLog_) {
            if (event.timestamp >= cutoff) {
                filtered.push_back(event);
            }
        }

        return filtered;
    }

    // ========================================================================
    // Flow State Tracking
    // ========================================================================

    void updateFlowState() {
        std::lock_guard<std::mutex> lock(mutex_);

        if (!currentSession_.isActive) return;

        auto now = std::chrono::system_clock::now();
        auto elapsed = std::chrono::duration_cast<std::chrono::minutes>(
            now - currentSession_.startTime);

        // Simple flow state progression
        if (elapsed < std::chrono::minutes{5}) {
            currentSession_.flowState = FocusSession::FlowState::Starting;
            currentSession_.flowScore = 20.0f;
        } else if (elapsed < std::chrono::minutes{15}) {
            currentSession_.flowState = FocusSession::FlowState::Warming;
            currentSession_.flowScore = 50.0f;
        } else if (elapsed < std::chrono::minutes{60}) {
            currentSession_.flowState = FocusSession::FlowState::Flowing;
            currentSession_.flowScore = std::min(100.0f, 50.0f + elapsed.count() * 0.5f);
        } else {
            currentSession_.flowState = FocusSession::FlowState::Cooling;
            currentSession_.flowScore = std::max(60.0f, currentSession_.flowScore - 0.1f);
        }

        // Reduce score for distractions
        float distractionPenalty = currentSession_.distractionsAvoided * 2.0f;
        currentSession_.flowScore = std::max(0.0f, currentSession_.flowScore - distractionPenalty);
    }

    FocusSession::FlowState getFlowState() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return currentSession_.flowState;
    }

    float getFlowScore() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return currentSession_.flowScore;
    }

    // ========================================================================
    // Ambient Settings
    // ========================================================================

    void setAmbientSettings(const AmbientSettings& settings) {
        std::lock_guard<std::mutex> lock(mutex_);
        ambientSettings_ = settings;
        applyAmbientSettings();
    }

    AmbientSettings getAmbientSettings() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return ambientSettings_;
    }

    void playAmbientSound(const std::string& soundscape) {
        std::lock_guard<std::mutex> lock(mutex_);
        ambientSettings_.ambientSoundscape = soundscape;
        ambientSettings_.playAmbientSounds = true;
        // Would start audio playback
    }

    void stopAmbientSound() {
        std::lock_guard<std::mutex> lock(mutex_);
        ambientSettings_.playAmbientSounds = false;
    }

    // ========================================================================
    // Session History
    // ========================================================================

    std::vector<FocusSession> getSessionHistory(int days = 30) const {
        std::lock_guard<std::mutex> lock(mutex_);

        auto cutoff = std::chrono::system_clock::now() - std::chrono::hours{days * 24};
        std::vector<FocusSession> result;

        for (const auto& session : sessionHistory_) {
            if (session.startTime >= cutoff) {
                result.push_back(session);
            }
        }

        return result;
    }

    std::chrono::seconds getTotalFocusTime(int days = 7) const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::chrono::seconds total{0};
        auto cutoff = std::chrono::system_clock::now() - std::chrono::hours{days * 24};

        for (const auto& session : sessionHistory_) {
            if (session.startTime >= cutoff) {
                total += std::chrono::duration_cast<std::chrono::seconds>(
                    session.endTime - session.startTime);
            }
        }

        return total;
    }

    float getAverageFlowScore(int days = 7) const {
        std::lock_guard<std::mutex> lock(mutex_);

        float totalScore = 0;
        int count = 0;
        auto cutoff = std::chrono::system_clock::now() - std::chrono::hours{days * 24};

        for (const auto& session : sessionHistory_) {
            if (session.startTime >= cutoff && session.wasCompleted) {
                totalScore += session.flowScore;
                count++;
            }
        }

        return count > 0 ? totalScore / count : 0.0f;
    }

    // ========================================================================
    // Quick Focus Presets
    // ========================================================================

    void quickFocus(int minutes) {
        startFocus(EchoelFocusMode::Creative, std::chrono::minutes{minutes});
    }

    void deepWork() {
        startFocus(EchoelFocusMode::Creative, std::chrono::minutes{90});
    }

    void recordingSession() {
        startFocus(EchoelFocusMode::Recording);
    }

    void mixingSession() {
        startFocus(EchoelFocusMode::Mixing, std::chrono::minutes{60});
    }

private:
    FocusModeManager() {
        initializeDefaultFilters();
    }
    ~FocusModeManager() = default;

    FocusModeManager(const FocusModeManager&) = delete;
    FocusModeManager& operator=(const FocusModeManager&) = delete;

    void initializeDefaultFilters() {
        // Creative mode filter
        NotificationFilter creative;
        creative.id = "creative";
        creative.name = "Creative Focus";
        creative.allowCalls = false;
        creative.allowMessages = false;
        creative.allowMail = false;
        creative.allowCollaborators = true;
        creative.allowFavorites = true;
        creative.allowRepeatedCalls = true;

        focusModeFilters_[EchoelFocusMode::Creative] = creative;

        // Recording mode - strict silence
        NotificationFilter recording;
        recording.id = "recording";
        recording.name = "Recording Session";
        recording.allowCalls = false;
        recording.allowMessages = false;
        recording.allowMail = false;
        recording.allowCalendar = false;
        recording.allowReminders = false;
        recording.allowCollaborators = false;
        recording.allowFavorites = false;

        focusModeFilters_[EchoelFocusMode::Recording] = recording;

        // Collaboration mode - allow team
        NotificationFilter collab;
        collab.id = "collaboration";
        collab.name = "Collaboration";
        collab.allowCalls = true;
        collab.allowMessages = true;
        collab.allowMail = false;
        collab.allowCollaborators = true;

        focusModeFilters_[EchoelFocusMode::Collaboration] = collab;
    }

    void applySystemFocusSettings(SystemFocusMode mode) {
        switch (mode) {
            case SystemFocusMode::DoNotDisturb:
                if (!currentSession_.isActive) {
                    startFocus(EchoelFocusMode::Creative);
                }
                break;

            case SystemFocusMode::Work:
                if (!currentSession_.isActive) {
                    startFocus(EchoelFocusMode::Mixing);
                }
                break;

            case SystemFocusMode::Sleep:
                if (currentSession_.isActive) {
                    endFocusInternal();
                }
                break;

            default:
                break;
        }
    }

    void applyFocusModeSettings(EchoelFocusMode mode) {
        auto it = focusModeFilters_.find(mode);
        if (it != focusModeFilters_.end()) {
            currentFilter_ = it->second;
        }

        // Apply ambient settings based on mode
        switch (mode) {
            case EchoelFocusMode::Recording:
                ambientSettings_.dimScreen = true;
                ambientSettings_.zenMode = true;
                ambientSettings_.playAmbientSounds = false;
                break;

            case EchoelFocusMode::Mixing:
                ambientSettings_.dimScreen = false;
                ambientSettings_.nightShift = true;
                break;

            case EchoelFocusMode::Meditation:
                ambientSettings_.dimScreen = true;
                ambientSettings_.colorScheme = AmbientSettings::ColorScheme::Dark;
                ambientSettings_.playAmbientSounds = true;
                ambientSettings_.ambientSoundscape = "peaceful";
                break;

            default:
                break;
        }

        applyAmbientSettings();
    }

    void applyAmbientSettings() {
        // Would apply screen brightness, color scheme, etc.
        // NSScreen brightness, Night Shift, etc.
    }

    void endFocusInternal() {
        if (!currentSession_.isActive) return;

        currentSession_.endTime = std::chrono::system_clock::now();
        currentSession_.isActive = false;
        currentSession_.wasCompleted = true;

        // Save to history
        sessionHistory_.push_back(currentSession_);

        // Reset
        currentMode_ = EchoelFocusMode::Off;
        focusPaused_ = false;

        // Notify
        notifyFocusChange(EchoelFocusMode::Off);
    }

    void advancePomodoroPhase() {
        switch (pomodoroState_.phase) {
            case PomodoroState::Phase::Focus:
                pomodoroState_.currentCycle++;
                pomodoroState_.completedCycles++;

                if (pomodoroState_.currentCycle >= pomodoroSettings_.cyclesBeforeLongBreak) {
                    pomodoroState_.phase = PomodoroState::Phase::LongBreak;
                    pomodoroState_.remaining = pomodoroSettings_.longBreak;
                    pomodoroState_.currentCycle = 0;
                } else {
                    pomodoroState_.phase = PomodoroState::Phase::ShortBreak;
                    pomodoroState_.remaining = pomodoroSettings_.shortBreak;
                }
                break;

            case PomodoroState::Phase::ShortBreak:
            case PomodoroState::Phase::LongBreak:
                pomodoroState_.phase = PomodoroState::Phase::Focus;
                pomodoroState_.remaining = pomodoroSettings_.focusDuration;
                break;

            default:
                break;
        }

        pomodoroState_.phaseStartTime = std::chrono::steady_clock::now();
    }

    bool isCollaborator(const std::string& contactId) const {
        // Would check if contact is a project collaborator
        return collaborators_.count(contactId) > 0;
    }

    std::string generateSessionId() {
        return "session_" + std::to_string(nextSessionId_++);
    }

    void notifyFocusChange(EchoelFocusMode mode) {
        // Would notify observers/UI
    }

    // ========================================================================
    // Member Variables
    // ========================================================================

    mutable std::mutex mutex_;

    // System focus
    std::atomic<SystemFocusMode> currentSystemFocus_{SystemFocusMode::None};

    // Echoel focus
    EchoelFocusMode currentMode_ = EchoelFocusMode::Off;
    FocusSession currentSession_;
    std::atomic<bool> focusPaused_{false};

    // Pomodoro
    PomodoroSettings pomodoroSettings_;
    PomodoroState pomodoroState_;

    // Filters
    NotificationFilter currentFilter_;
    std::map<EchoelFocusMode, NotificationFilter> focusModeFilters_;

    // Ambient
    AmbientSettings ambientSettings_;

    // Tracking
    std::vector<DistractionEvent> distractionLog_;
    std::vector<FocusSession> sessionHistory_;
    std::set<std::string> collaborators_;

    std::atomic<int> nextSessionId_{1};
};

// ============================================================================
// Convenience Functions
// ============================================================================

namespace Focus {

inline void start(EchoelFocusMode mode = EchoelFocusMode::Creative,
                  std::optional<std::chrono::minutes> duration = std::nullopt) {
    FocusModeManager::getInstance().startFocus(mode, duration);
}

inline void end() {
    FocusModeManager::getInstance().endFocus();
}

inline bool isActive() {
    return FocusModeManager::getInstance().isFocusActive();
}

inline void quickFocus(int minutes) {
    FocusModeManager::getInstance().quickFocus(minutes);
}

inline void deepWork() {
    FocusModeManager::getInstance().deepWork();
}

inline void startPomodoro() {
    FocusModeManager::getInstance().startPomodoro();
}

inline PomodoroState pomodoroState() {
    return FocusModeManager::getInstance().getPomodoroState();
}

} // namespace Focus

} // namespace Echoel
