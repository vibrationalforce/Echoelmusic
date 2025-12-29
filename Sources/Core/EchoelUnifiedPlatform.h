#pragma once

/*
 * EchoelUnifiedPlatform.h
 * Ralph Wiggum Genius Loop Mode - Unified Integration Layer
 *
 * This is the CENTRAL COORDINATOR that connects ALL Echoel subsystems
 * without duplicating code. It provides a unified API for:
 *
 * - Audio Engine (Sources/Core/EchoelAudioEngine.h)
 * - AI Systems (Sources/AI/EchoelAIEngine.h, EchoelAIMusicGen.h, etc.)
 * - Realtime Collaboration (Sources/Network/EchoelRealtimeCollab.h)
 * - Live Streaming (Sources/Network/EchoelLiveStream.h)
 * - Video Editing (Sources/Video/EchoelVideoEditor.h)
 * - Content Management (Sources/Content/EchoelContentManager.h)
 * - Research & Compliance (Sources/Content/EchoelResearchTool.h)
 * - Performance Optimization (Sources/Core/EchoelOptimizer.h)
 * - Biofeedback (Sources/BioData/*)
 *
 * DESIGN PRINCIPLES:
 * - No code duplication - references existing components
 * - Worldwide realtime collaboration support
 * - Inclusive accessibility for all users
 * - User owns 100% of all created content
 * - No health claims - educational/informational only
 */

#include <memory>
#include <string>
#include <map>
#include <vector>
#include <functional>
#include <atomic>
#include <mutex>

namespace Echoel {
namespace Core {

// ============================================================================
// Forward Declarations (to avoid circular includes)
// ============================================================================

// Core
class EchoelMainController;
class EchoelAudioEngine;
class EchoelOptimizer;
class EchoelThreadPool;
class EchoelMemoryPool;
class EchoelPresetManager;
class EchoelSessionRecorder;
class EchoelNetworkSync;
class EchoelErrorHandler;

// AI
namespace AI {
    class EchoelAIEngine;
    class EchoelAIMusicGen;
    class EchoelAIVisualGen;
    class EchoelAIBioPredictor;
    class EchoelCreativeAssistant;
}

// Network
namespace Network {
    class EchoelRealtimeCollab;
    class EchoelLiveStream;
    class EchoelCollabSession;
    class EchoelStreamEncoder;
    class EchoelChatSystem;
    class EchoelPresenceSystem;
}

// Video
namespace Video {
    class EchoelVideoEditor;
}

// Content
namespace Content {
    class EchoelContentManager;
    class EchoelResearchTool;
    class EchoelComplianceChecker;
}

// ============================================================================
// User & Access Management
// ============================================================================

enum class UserRole {
    Guest,              // View-only access
    Viewer,             // Can view and interact minimally
    Participant,        // Can participate in sessions
    Contributor,        // Can add content
    Creator,            // Full creative access
    Collaborator,       // Can collaborate in real-time
    Moderator,          // Can moderate content/users
    Administrator,      // Full admin access
    Owner               // Project owner
};

enum class AccessLevel {
    Public,             // Anyone can access
    Registered,         // Registered users only
    Subscribers,        // Paid subscribers
    Collaborators,      // Invited collaborators
    Private             // Owner only
};

struct UserProfile {
    std::string id;
    std::string displayName;
    std::string email;
    UserRole role = UserRole::Guest;
    std::string region;             // For latency optimization
    std::string timezone;
    std::string preferredLanguage;

    // Accessibility preferences
    struct AccessibilityPrefs {
        bool screenReaderMode = false;
        bool highContrastMode = false;
        bool reducedMotion = false;
        bool largeText = false;
        bool colorBlindMode = false;
        std::string colorBlindType;     // "protanopia", "deuteranopia", "tritanopia"
        bool keyboardOnlyNavigation = false;
        float uiScale = 1.0f;
    } accessibility;

    // Content ownership
    struct ContentRights {
        bool ownsAllCreatedContent = true;      // Always true
        bool allowsCollaboration = true;
        bool attributionRequired = true;
        std::string licensePreference;           // User's preferred license
    } contentRights;

    // Connection info
    bool isOnline = false;
    uint64_t lastSeen = 0;
};

// ============================================================================
// Region & Server Management
// ============================================================================

struct ServerRegion {
    std::string id;
    std::string name;
    std::string continent;
    std::string country;
    std::string city;
    float latitude = 0.0f;
    float longitude = 0.0f;

    // Performance metrics
    float avgLatency = 0.0f;        // ms
    float packetLoss = 0.0f;        // %
    int activeUsers = 0;
    int maxCapacity = 1000;
    bool available = true;
};

class RegionManager {
public:
    std::vector<ServerRegion> getRegions() const {
        return {
            {"eu-west", "Europe West", "Europe", "Germany", "Frankfurt", 50.1109f, 8.6821f},
            {"eu-north", "Europe North", "Europe", "Sweden", "Stockholm", 59.3293f, 18.0686f},
            {"na-east", "North America East", "North America", "USA", "New York", 40.7128f, -74.0060f},
            {"na-west", "North America West", "North America", "USA", "Los Angeles", 34.0522f, -118.2437f},
            {"asia-east", "Asia East", "Asia", "Japan", "Tokyo", 35.6762f, 139.6503f},
            {"asia-south", "Asia South", "Asia", "Singapore", "Singapore", 1.3521f, 103.8198f},
            {"oceania", "Oceania", "Oceania", "Australia", "Sydney", -33.8688f, 151.2093f},
            {"sa", "South America", "South America", "Brazil", "São Paulo", -23.5505f, -46.6333f},
            {"africa", "Africa", "Africa", "South Africa", "Johannesburg", -26.2041f, 28.0473f},
            {"me", "Middle East", "Asia", "UAE", "Dubai", 25.2048f, 55.2708f}
        };
    }

    ServerRegion findNearestRegion(float latitude, float longitude) const {
        auto regions = getRegions();
        if (regions.empty()) return {};

        float minDist = std::numeric_limits<float>::max();
        ServerRegion nearest = regions[0];

        for (const auto& region : regions) {
            float dist = calculateDistance(latitude, longitude,
                                           region.latitude, region.longitude);
            if (dist < minDist && region.available) {
                minDist = dist;
                nearest = region;
            }
        }

        return nearest;
    }

private:
    float calculateDistance(float lat1, float lon1, float lat2, float lon2) const {
        // Haversine formula (simplified)
        float dLat = (lat2 - lat1) * 0.0174533f;
        float dLon = (lon2 - lon1) * 0.0174533f;
        float a = std::sin(dLat/2) * std::sin(dLat/2) +
                  std::cos(lat1 * 0.0174533f) * std::cos(lat2 * 0.0174533f) *
                  std::sin(dLon/2) * std::sin(dLon/2);
        return 6371.0f * 2.0f * std::atan2(std::sqrt(a), std::sqrt(1-a));
    }
};

// ============================================================================
// Accessibility Manager
// ============================================================================

class AccessibilityManager {
public:
    struct AccessibilityConfig {
        // Visual
        bool highContrast = false;
        bool darkMode = false;
        bool reducedMotion = false;
        float uiScale = 1.0f;
        std::string fontFamily = "system-ui";
        float fontSize = 16.0f;

        // Color adjustments
        bool colorBlindAssist = false;
        std::string colorBlindType = "none";
        float saturationAdjust = 1.0f;

        // Motor
        bool keyboardOnly = false;
        bool stickyKeys = false;
        float clickTargetSize = 44.0f;  // Minimum touch target (px)
        float dwellClickTime = 0.0f;     // 0 = disabled

        // Audio
        bool monoAudio = false;
        bool captionsEnabled = false;
        std::string captionLanguage = "en";
        float captionFontSize = 18.0f;

        // Screen reader
        bool screenReaderMode = false;
        bool verboseDescriptions = false;
        float announcementRate = 1.0f;
    };

    void applyUserPreferences(const UserProfile::AccessibilityPrefs& prefs) {
        config_.highContrast = prefs.highContrastMode;
        config_.reducedMotion = prefs.reducedMotion;
        config_.uiScale = prefs.uiScale;
        config_.keyboardOnly = prefs.keyboardOnlyNavigation;
        config_.screenReaderMode = prefs.screenReaderMode;

        if (prefs.colorBlindMode) {
            config_.colorBlindAssist = true;
            config_.colorBlindType = prefs.colorBlindType;
        }

        if (prefs.largeText) {
            config_.fontSize = 20.0f;
        }
    }

    AccessibilityConfig getConfig() const { return config_; }

    // Generate accessible description for UI elements
    std::string generateAriaLabel(const std::string& element,
                                   const std::string& state,
                                   const std::string& hint = "") const {
        std::string label = element;
        if (!state.empty()) {
            label += ", " + state;
        }
        if (!hint.empty() && config_.verboseDescriptions) {
            label += ". " + hint;
        }
        return label;
    }

    // Get color adjusted for color blindness
    struct Color { float r, g, b; };

    Color adjustColorForColorBlindness(Color input) const {
        if (!config_.colorBlindAssist) return input;

        // Simplified color blind simulation/correction
        if (config_.colorBlindType == "protanopia") {
            // Red-blind: shift reds to blue
            return {input.r * 0.567f + input.g * 0.433f,
                    input.g * 0.558f + input.r * 0.442f,
                    input.b * 0.758f + input.r * 0.242f};
        } else if (config_.colorBlindType == "deuteranopia") {
            // Green-blind
            return {input.r * 0.625f + input.g * 0.375f,
                    input.g * 0.7f + input.r * 0.3f,
                    input.b};
        } else if (config_.colorBlindType == "tritanopia") {
            // Blue-blind
            return {input.r,
                    input.g * 0.95f + input.b * 0.05f,
                    input.g * 0.433f + input.b * 0.567f};
        }

        return input;
    }

private:
    AccessibilityConfig config_;
};

// ============================================================================
// Internationalization
// ============================================================================

class LocalizationManager {
public:
    void setLanguage(const std::string& languageCode) {
        currentLanguage_ = languageCode;
        loadLanguageStrings(languageCode);
    }

    std::string translate(const std::string& key) const {
        auto it = strings_.find(key);
        if (it != strings_.end()) {
            return it->second;
        }
        return key; // Fallback to key
    }

    std::string formatNumber(double value, int decimals = 2) const {
        // Use locale-appropriate formatting
        char buffer[64];
        snprintf(buffer, sizeof(buffer), "%.*f", decimals, value);
        return buffer;
    }

    std::string formatDate(uint64_t timestamp) const {
        // Simplified - real implementation would use locale
        return std::to_string(timestamp);
    }

    std::vector<std::string> getSupportedLanguages() const {
        return {
            "en", "de", "fr", "es", "it", "pt", "nl", "pl", "ru",
            "zh", "ja", "ko", "ar", "hi", "th", "vi", "id", "tr",
            "sv", "no", "da", "fi", "cs", "hu", "ro", "uk", "he"
        };
    }

    std::string getLanguageName(const std::string& code) const {
        static std::map<std::string, std::string> names = {
            {"en", "English"}, {"de", "Deutsch"}, {"fr", "Français"},
            {"es", "Español"}, {"it", "Italiano"}, {"pt", "Português"},
            {"nl", "Nederlands"}, {"pl", "Polski"}, {"ru", "Русский"},
            {"zh", "中文"}, {"ja", "日本語"}, {"ko", "한국어"},
            {"ar", "العربية"}, {"hi", "हिन्दी"}, {"th", "ไทย"},
            {"vi", "Tiếng Việt"}, {"id", "Bahasa Indonesia"}, {"tr", "Türkçe"},
            {"sv", "Svenska"}, {"no", "Norsk"}, {"da", "Dansk"},
            {"fi", "Suomi"}, {"cs", "Čeština"}, {"hu", "Magyar"},
            {"ro", "Română"}, {"uk", "Українська"}, {"he", "עברית"}
        };

        auto it = names.find(code);
        return it != names.end() ? it->second : code;
    }

private:
    void loadLanguageStrings(const std::string& lang) {
        strings_.clear();
        // In real implementation, load from files
        // Default English strings
        strings_["welcome"] = "Welcome";
        strings_["start_session"] = "Start Session";
        strings_["join_collab"] = "Join Collaboration";
        strings_["go_live"] = "Go Live";
        strings_["create_content"] = "Create Content";
        strings_["disclaimer"] = "For educational purposes only";
    }

    std::string currentLanguage_ = "en";
    std::map<std::string, std::string> strings_;
};

// ============================================================================
// Subsystem Status
// ============================================================================

enum class SubsystemStatus {
    Uninitialized,
    Initializing,
    Ready,
    Running,
    Paused,
    Error,
    Shutdown
};

struct SubsystemInfo {
    std::string name;
    SubsystemStatus status = SubsystemStatus::Uninitialized;
    std::string version;
    uint64_t lastUpdate = 0;
    std::vector<std::string> capabilities;
    std::vector<std::string> dependencies;
    std::string errorMessage;
};

// ============================================================================
// Platform Events
// ============================================================================

enum class PlatformEventType {
    // System
    SystemInitialized,
    SystemShutdown,
    SubsystemStatusChanged,
    ErrorOccurred,

    // User
    UserConnected,
    UserDisconnected,
    UserRoleChanged,

    // Collaboration
    CollabSessionCreated,
    CollabSessionJoined,
    CollabSessionLeft,
    CollabStateChanged,

    // Streaming
    StreamStarted,
    StreamEnded,
    ViewerJoined,
    ViewerLeft,

    // Content
    ContentCreated,
    ContentUpdated,
    ContentPublished,

    // Audio/Video
    AudioProcessingStarted,
    AudioProcessingStopped,
    VideoRenderingStarted,
    VideoRenderingStopped,

    // Bio
    BioDataReceived,
    BioStateChanged
};

struct PlatformEvent {
    PlatformEventType type;
    std::string sourceSubsystem;
    std::string data;                   // JSON encoded
    uint64_t timestamp = 0;
    std::string userId;                 // If user-related
};

using EventCallback = std::function<void(const PlatformEvent&)>;

// ============================================================================
// Main Unified Platform
// ============================================================================

class EchoelUnifiedPlatform {
public:
    /*
     * IMPORTANT DESIGN NOTES:
     *
     * 1. This class DOES NOT duplicate functionality from other components
     * 2. It REFERENCES and COORDINATES existing subsystems
     * 3. All content created belongs 100% to the user
     * 4. No health claims are made - educational/informational only
     * 5. Worldwide accessibility and localization support
     * 6. Real-time collaboration across all regions
     */

    static EchoelUnifiedPlatform& getInstance() {
        static EchoelUnifiedPlatform instance;
        return instance;
    }

    // ===== Initialization =====

    struct InitConfig {
        std::string appVersion;
        std::string userId;
        std::string region;
        std::string language = "en";
        bool enableAudio = true;
        bool enableVideo = true;
        bool enableAI = true;
        bool enableCollaboration = true;
        bool enableStreaming = true;
        bool enableBiofeedback = true;
        bool enableContentManagement = true;

        // Performance
        int threadPoolSize = 0;         // 0 = auto-detect
        size_t memoryPoolSize = 0;      // 0 = auto-detect

        // Accessibility
        UserProfile::AccessibilityPrefs accessibility;
    };

    bool initialize(const InitConfig& config) {
        std::lock_guard<std::mutex> lock(initMutex_);

        if (initialized_) return true;

        config_ = config;

        // Initialize localization
        localization_.setLanguage(config.language);

        // Set up accessibility
        accessibility_.applyUserPreferences(config.accessibility);

        // Find optimal region
        auto regions = regionManager_.getRegions();
        for (const auto& r : regions) {
            if (r.id == config.region) {
                currentRegion_ = r;
                break;
            }
        }

        // Initialize subsystems (references to existing components)
        initializeSubsystems(config);

        initialized_ = true;
        running_ = true;

        // Emit initialization event
        emitEvent({
            PlatformEventType::SystemInitialized,
            "core",
            "{\"version\":\"" + config.appVersion + "\"}",
            getCurrentTimestamp(),
            config.userId
        });

        return true;
    }

    void shutdown() {
        std::lock_guard<std::mutex> lock(initMutex_);

        if (!initialized_) return;

        running_ = false;

        emitEvent({
            PlatformEventType::SystemShutdown,
            "core",
            "{}",
            getCurrentTimestamp(),
            ""
        });

        // Shutdown subsystems in reverse order
        shutdownSubsystems();

        initialized_ = false;
    }

    bool isInitialized() const { return initialized_; }
    bool isRunning() const { return running_; }

    // ===== User Management =====

    void setCurrentUser(const UserProfile& user) {
        std::lock_guard<std::mutex> lock(userMutex_);
        currentUser_ = user;
        accessibility_.applyUserPreferences(user.accessibility);
    }

    UserProfile getCurrentUser() const {
        std::lock_guard<std::mutex> lock(userMutex_);
        return currentUser_;
    }

    bool hasPermission(UserRole requiredRole) const {
        return static_cast<int>(currentUser_.role) >= static_cast<int>(requiredRole);
    }

    // ===== Subsystem Access (Forwarding to existing components) =====

    SubsystemInfo getSubsystemInfo(const std::string& name) const {
        auto it = subsystems_.find(name);
        if (it != subsystems_.end()) {
            return it->second;
        }
        return {};
    }

    std::vector<SubsystemInfo> getAllSubsystems() const {
        std::vector<SubsystemInfo> result;
        for (const auto& [name, info] : subsystems_) {
            result.push_back(info);
        }
        return result;
    }

    // ===== Event System =====

    void addEventListener(PlatformEventType type, EventCallback callback) {
        std::lock_guard<std::mutex> lock(eventMutex_);
        eventListeners_[type].push_back(callback);
    }

    void emitEvent(const PlatformEvent& event) {
        std::lock_guard<std::mutex> lock(eventMutex_);
        auto it = eventListeners_.find(event.type);
        if (it != eventListeners_.end()) {
            for (const auto& callback : it->second) {
                callback(event);
            }
        }
    }

    // ===== Region & Connectivity =====

    ServerRegion getCurrentRegion() const { return currentRegion_; }

    void switchRegion(const std::string& regionId) {
        auto regions = regionManager_.getRegions();
        for (const auto& r : regions) {
            if (r.id == regionId) {
                currentRegion_ = r;
                // Notify subsystems of region change
                emitEvent({
                    PlatformEventType::SubsystemStatusChanged,
                    "network",
                    "{\"event\":\"region_changed\",\"region\":\"" + regionId + "\"}",
                    getCurrentTimestamp(),
                    currentUser_.id
                });
                break;
            }
        }
    }

    ServerRegion findOptimalRegion(float latitude, float longitude) const {
        return regionManager_.findNearestRegion(latitude, longitude);
    }

    // ===== Accessibility =====

    AccessibilityManager& getAccessibility() { return accessibility_; }
    const AccessibilityManager& getAccessibility() const { return accessibility_; }

    // ===== Localization =====

    LocalizationManager& getLocalization() { return localization_; }
    const LocalizationManager& getLocalization() const { return localization_; }

    std::string translate(const std::string& key) const {
        return localization_.translate(key);
    }

    // ===== Quick Actions (Convenience methods) =====

    // Start a collaborative session
    struct CollabSessionConfig {
        std::string sessionName;
        AccessLevel accessLevel = AccessLevel::Collaborators;
        int maxParticipants = 10;
        bool audioEnabled = true;
        bool videoEnabled = false;
        bool chatEnabled = true;
        std::string region;             // Empty = auto-select
    };

    std::string startCollabSession(const CollabSessionConfig& config) {
        if (!hasPermission(UserRole::Creator)) {
            return "";
        }

        // Generate session ID
        std::string sessionId = "session_" + std::to_string(getCurrentTimestamp());

        emitEvent({
            PlatformEventType::CollabSessionCreated,
            "collaboration",
            "{\"sessionId\":\"" + sessionId + "\",\"name\":\"" + config.sessionName + "\"}",
            getCurrentTimestamp(),
            currentUser_.id
        });

        return sessionId;
    }

    // Start live streaming
    struct StreamConfig {
        std::string streamTitle;
        std::string description;
        std::vector<std::string> platforms;     // ["youtube", "twitch", etc.]
        int quality = 1080;
        bool audioOnly = false;
        bool chatEnabled = true;
        std::string region;
    };

    std::string startStream(const StreamConfig& config) {
        if (!hasPermission(UserRole::Creator)) {
            return "";
        }

        std::string streamId = "stream_" + std::to_string(getCurrentTimestamp());

        emitEvent({
            PlatformEventType::StreamStarted,
            "streaming",
            "{\"streamId\":\"" + streamId + "\",\"title\":\"" + config.streamTitle + "\"}",
            getCurrentTimestamp(),
            currentUser_.id
        });

        return streamId;
    }

    // ===== Content Management Quick Access =====

    struct ContentCreationParams {
        std::string title;
        std::string contentType;        // "research", "tutorial", "educational"
        std::vector<std::string> platforms;
        bool includeDisclaimer = true;
        std::vector<std::string> sourceIds;
    };

    std::string createContent(const ContentCreationParams& params) {
        if (!hasPermission(UserRole::Creator)) {
            return "";
        }

        std::string contentId = "content_" + std::to_string(getCurrentTimestamp());

        emitEvent({
            PlatformEventType::ContentCreated,
            "content",
            "{\"contentId\":\"" + contentId + "\",\"title\":\"" + params.title + "\"}",
            getCurrentTimestamp(),
            currentUser_.id
        });

        return contentId;
    }

    // ===== System Status =====

    struct SystemStatus {
        bool allSubsystemsReady = false;
        int activeSubsystems = 0;
        int totalSubsystems = 0;
        std::string currentRegion;
        int connectedUsers = 0;
        float systemLoad = 0.0f;
        std::vector<std::string> warnings;
        std::vector<std::string> errors;
    };

    SystemStatus getSystemStatus() const {
        SystemStatus status;
        status.currentRegion = currentRegion_.name;

        for (const auto& [name, info] : subsystems_) {
            status.totalSubsystems++;
            if (info.status == SubsystemStatus::Ready ||
                info.status == SubsystemStatus::Running) {
                status.activeSubsystems++;
            }
            if (info.status == SubsystemStatus::Error) {
                status.errors.push_back(name + ": " + info.errorMessage);
            }
        }

        status.allSubsystemsReady =
            (status.activeSubsystems == status.totalSubsystems);

        return status;
    }

    // ===== Legal & Compliance =====

    std::string getRequiredDisclaimer(const std::string& contentType) const {
        if (contentType == "research" || contentType == "educational") {
            return "This information is for educational and informational purposes only. "
                   "It is not intended as medical advice, diagnosis, or treatment. "
                   "Always consult with a qualified healthcare provider.";
        } else if (contentType == "biofeedback") {
            return "Biofeedback and entrainment technologies are tools for relaxation "
                   "and self-exploration. They are not medical devices and do not "
                   "diagnose, treat, cure, or prevent any disease.";
        }
        return "For educational purposes only. Individual results may vary.";
    }

    std::string getUserOwnershipStatement() const {
        return "All content created using Echoel is 100% owned by you, the creator. "
               "You retain full copyright and creative credit for everything you create.";
    }

private:
    EchoelUnifiedPlatform() = default;
    ~EchoelUnifiedPlatform() = default;

    EchoelUnifiedPlatform(const EchoelUnifiedPlatform&) = delete;
    EchoelUnifiedPlatform& operator=(const EchoelUnifiedPlatform&) = delete;

    void initializeSubsystems(const InitConfig& config) {
        // Register subsystems (references to existing components)
        // Audio
        if (config.enableAudio) {
            registerSubsystem({
                "audio_engine",
                SubsystemStatus::Ready,
                "1.0.0",
                getCurrentTimestamp(),
                {"audio_processing", "dsp", "binaural", "isochronic"},
                {}
            });
        }

        // AI
        if (config.enableAI) {
            registerSubsystem({
                "ai_engine",
                SubsystemStatus::Ready,
                "1.0.0",
                getCurrentTimestamp(),
                {"music_gen", "visual_gen", "bio_prediction", "creative_assist"},
                {"audio_engine"}
            });
        }

        // Collaboration
        if (config.enableCollaboration) {
            registerSubsystem({
                "collaboration",
                SubsystemStatus::Ready,
                "1.0.0",
                getCurrentTimestamp(),
                {"realtime_sync", "presence", "chat", "session_management"},
                {}
            });
        }

        // Streaming
        if (config.enableStreaming) {
            registerSubsystem({
                "streaming",
                SubsystemStatus::Ready,
                "1.0.0",
                getCurrentTimestamp(),
                {"rtmp", "hls", "webrtc", "multi_platform"},
                {"collaboration"}
            });
        }

        // Video
        if (config.enableVideo) {
            registerSubsystem({
                "video_editor",
                SubsystemStatus::Ready,
                "1.0.0",
                getCurrentTimestamp(),
                {"timeline", "effects", "export", "bio_reactive"},
                {"audio_engine"}
            });
        }

        // Content
        if (config.enableContentManagement) {
            registerSubsystem({
                "content_manager",
                SubsystemStatus::Ready,
                "1.0.0",
                getCurrentTimestamp(),
                {"multi_platform", "scheduling", "compliance", "research"},
                {}
            });
        }

        // Biofeedback
        if (config.enableBiofeedback) {
            registerSubsystem({
                "biofeedback",
                SubsystemStatus::Ready,
                "1.0.0",
                getCurrentTimestamp(),
                {"hrv", "eeg", "gsr", "breathing", "gesture"},
                {}
            });
        }

        // Core optimization
        registerSubsystem({
            "optimizer",
            SubsystemStatus::Ready,
            "1.0.0",
            getCurrentTimestamp(),
            {"simd", "threading", "memory_pool", "thermal"},
            {}
        });
    }

    void shutdownSubsystems() {
        for (auto& [name, info] : subsystems_) {
            info.status = SubsystemStatus::Shutdown;
        }
    }

    void registerSubsystem(const SubsystemInfo& info) {
        subsystems_[info.name] = info;
    }

    uint64_t getCurrentTimestamp() const {
        return static_cast<uint64_t>(
            std::chrono::duration_cast<std::chrono::milliseconds>(
                std::chrono::system_clock::now().time_since_epoch()
            ).count()
        );
    }

    // State
    std::atomic<bool> initialized_{false};
    std::atomic<bool> running_{false};
    InitConfig config_;

    // User
    UserProfile currentUser_;
    mutable std::mutex userMutex_;

    // Subsystems
    std::map<std::string, SubsystemInfo> subsystems_;

    // Region
    RegionManager regionManager_;
    ServerRegion currentRegion_;

    // Accessibility & Localization
    AccessibilityManager accessibility_;
    LocalizationManager localization_;

    // Events
    std::map<PlatformEventType, std::vector<EventCallback>> eventListeners_;
    std::mutex eventMutex_;

    // Initialization
    std::mutex initMutex_;
};

// ============================================================================
// Convenience Macros
// ============================================================================

#define ECHOEL_PLATFORM Echoel::Core::EchoelUnifiedPlatform::getInstance()
#define ECHOEL_TRANSLATE(key) ECHOEL_PLATFORM.translate(key)
#define ECHOEL_HAS_PERMISSION(role) ECHOEL_PLATFORM.hasPermission(role)

} // namespace Core
} // namespace Echoel
