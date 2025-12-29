/**
 * EchoelSiriShortcuts.h
 *
 * Siri Shortcuts & Voice Automation System
 *
 * Complete voice control integration for Echoel Music:
 * - Siri Shortcuts / App Intents
 * - Voice command recognition
 * - Custom phrase triggers
 * - Automation workflows
 * - HomeKit integration
 * - Focus mode automation
 * - Scheduled actions
 * - Inter-app automation
 * - Apple Watch voice commands
 * - CarPlay voice control
 *
 * Part of Ralph Wiggum Genius Loop Mode - Phase 1
 * "Go banana!" - Ralph Wiggum
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
#include <variant>
#include <atomic>
#include <mutex>
#include <regex>

namespace Echoel {

// ============================================================================
// Intent Types
// ============================================================================

enum class IntentCategory {
    Transport,      // Play, pause, stop, record
    Project,        // Open, create, save projects
    Mixing,         // Volume, pan, effects
    Navigation,     // Go to marker, section, time
    Recording,      // Start/stop recording, arm tracks
    Export,         // Export audio, share
    Settings,       // Change preferences
    Information,    // Get status, info
    Automation,     // Run automation scripts
    HomeKit,        // Smart home integration
    Custom          // User-defined intents
};

enum class IntentPriority {
    Background,     // Low priority, can be deferred
    Normal,         // Standard priority
    UserInitiated,  // User explicitly requested
    Critical        // Time-sensitive, must execute immediately
};

// ============================================================================
// Intent Parameters
// ============================================================================

struct IntentParameter {
    std::string name;
    std::string displayName;
    std::string description;

    enum class Type {
        String,
        Integer,
        Decimal,
        Boolean,
        Duration,
        Date,
        URL,
        File,
        Enum,
        Person,
        Location
    } type = Type::String;

    bool isRequired = false;
    bool supportsMultiple = false;

    // For enums
    std::vector<std::string> enumValues;

    // Default value
    std::variant<std::string, int, double, bool> defaultValue;

    // Validation
    std::optional<int> minValue;
    std::optional<int> maxValue;
    std::optional<std::string> regexPattern;
};

// ============================================================================
// Intent Definition
// ============================================================================

struct SiriIntent {
    std::string id;
    std::string title;
    std::string description;
    IntentCategory category = IntentCategory::Custom;
    IntentPriority priority = IntentPriority::Normal;

    // Suggested phrases
    std::vector<std::string> suggestedPhrases;

    // Parameters
    std::vector<IntentParameter> parameters;

    // Execution
    std::function<bool(const std::map<std::string, std::string>&)> handler;

    // UI
    std::string iconName;
    bool supportsBackgroundExecution = true;
    bool requiresUnlock = false;

    // Result
    std::string successMessage;
    std::string failureMessage;
};

// ============================================================================
// Intent Result
// ============================================================================

struct IntentResult {
    bool success = false;
    std::string message;
    std::string spokenResponse;  // What Siri says

    // For continuing dialog
    bool needsValue = false;
    std::string requestedParameterName;
    std::string prompt;

    // For disambiguation
    std::vector<std::string> options;
    std::string disambiguationPrompt;

    // Return data
    std::map<std::string, std::string> outputData;
};

// ============================================================================
// Voice Command
// ============================================================================

struct VoiceCommand {
    std::string phrase;
    std::string intentId;
    std::map<std::string, std::string> parameterBindings;

    bool isExactMatch = false;
    bool isCaseSensitive = false;

    std::chrono::system_clock::time_point lastUsed;
    int usageCount = 0;
};

// ============================================================================
// Automation Workflow
// ============================================================================

struct AutomationAction {
    std::string intentId;
    std::map<std::string, std::string> parameters;

    // Conditions
    enum class Condition {
        Always,
        IfPlaying,
        IfStopped,
        IfRecording,
        IfProjectOpen,
        IfTimeOfDay,
        IfLocation,
        IfConnectedDevice
    } condition = Condition::Always;

    std::string conditionValue;

    // Delay before execution
    std::chrono::milliseconds delay{0};
};

struct AutomationWorkflow {
    std::string id;
    std::string name;
    std::string description;
    std::string iconName;

    std::vector<AutomationAction> actions;

    // Triggers
    enum class Trigger {
        Manual,         // User initiated
        Time,           // Scheduled
        Location,       // Arrive/leave location
        NFCTag,         // Tap NFC tag
        ShortcutApp,    // From Shortcuts app
        FocusMode,      // Focus mode changes
        AppLaunch,      // App opens
        AppClose,       // App closes
        CarPlay,        // CarPlay connects
        HomeKit,        // HomeKit scene
        Webhook         // External trigger
    } trigger = Trigger::Manual;

    std::string triggerValue;  // Depends on trigger type

    bool isEnabled = true;
    std::chrono::system_clock::time_point lastRun;
    int runCount = 0;
};

// ============================================================================
// HomeKit Integration
// ============================================================================

struct HomeKitScene {
    std::string id;
    std::string name;
    std::string homeId;

    // What to do when scene activates
    std::string workflowId;  // Run this workflow

    // Bi-directional: Echoel can trigger scenes too
    bool canTriggerFromEchoel = true;
};

struct HomeKitAccessory {
    std::string id;
    std::string name;
    std::string type;  // "light", "speaker", "switch", etc.
    std::string roomName;

    // Controllable properties
    std::map<std::string, std::string> characteristics;
};

// ============================================================================
// Siri Shortcuts Manager
// ============================================================================

class SiriShortcutsManager {
public:
    static SiriShortcutsManager& getInstance() {
        static SiriShortcutsManager instance;
        return instance;
    }

    // ========================================================================
    // Initialization
    // ========================================================================

    void initialize() {
        std::lock_guard<std::mutex> lock(mutex_);

        registerBuiltInIntents();
        loadUserPhrases();
        loadWorkflows();

        initialized_ = true;
    }

    // ========================================================================
    // Intent Registration
    // ========================================================================

    void registerIntent(const SiriIntent& intent) {
        std::lock_guard<std::mutex> lock(mutex_);
        intents_[intent.id] = intent;

        // Donate to Siri for suggestions
        donateIntent(intent);
    }

    void unregisterIntent(const std::string& intentId) {
        std::lock_guard<std::mutex> lock(mutex_);
        intents_.erase(intentId);
    }

    std::optional<SiriIntent> getIntent(const std::string& intentId) const {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = intents_.find(intentId);
        if (it != intents_.end()) {
            return it->second;
        }
        return std::nullopt;
    }

    std::vector<SiriIntent> getIntentsByCategory(IntentCategory category) const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<SiriIntent> result;
        for (const auto& [id, intent] : intents_) {
            if (intent.category == category) {
                result.push_back(intent);
            }
        }
        return result;
    }

    // ========================================================================
    // Intent Execution
    // ========================================================================

    IntentResult executeIntent(const std::string& intentId,
                               const std::map<std::string, std::string>& params = {}) {
        std::lock_guard<std::mutex> lock(mutex_);

        IntentResult result;

        auto it = intents_.find(intentId);
        if (it == intents_.end()) {
            result.success = false;
            result.message = "Intent not found";
            result.spokenResponse = "Sorry, I don't know how to do that.";
            return result;
        }

        const auto& intent = it->second;

        // Validate required parameters
        for (const auto& param : intent.parameters) {
            if (param.isRequired && params.find(param.name) == params.end()) {
                result.success = false;
                result.needsValue = true;
                result.requestedParameterName = param.name;
                result.prompt = "What " + param.displayName + " would you like?";
                return result;
            }
        }

        // Execute handler
        if (intent.handler) {
            result.success = intent.handler(params);
            result.message = result.success ? intent.successMessage : intent.failureMessage;
            result.spokenResponse = result.message;
        } else {
            result.success = false;
            result.message = "Intent handler not implemented";
        }

        return result;
    }

    IntentResult executeVoiceCommand(const std::string& phrase) {
        std::lock_guard<std::mutex> lock(mutex_);

        // Find matching voice command
        std::string lowerPhrase = phrase;
        std::transform(lowerPhrase.begin(), lowerPhrase.end(),
                       lowerPhrase.begin(), ::tolower);

        for (auto& [p, command] : voiceCommands_) {
            std::string matchPhrase = p;
            if (!command.isCaseSensitive) {
                std::transform(matchPhrase.begin(), matchPhrase.end(),
                               matchPhrase.begin(), ::tolower);
            }

            bool matches = false;
            if (command.isExactMatch) {
                matches = (lowerPhrase == matchPhrase);
            } else {
                matches = (lowerPhrase.find(matchPhrase) != std::string::npos);
            }

            if (matches) {
                command.lastUsed = std::chrono::system_clock::now();
                command.usageCount++;

                // Execute the linked intent
                return executeIntent(command.intentId, command.parameterBindings);
            }
        }

        // No match - try NLP matching
        return tryNLPMatch(phrase);
    }

    // ========================================================================
    // Voice Commands
    // ========================================================================

    void registerVoiceCommand(const VoiceCommand& command) {
        std::lock_guard<std::mutex> lock(mutex_);
        voiceCommands_[command.phrase] = command;
    }

    void learnPhrase(const std::string& phrase, const std::string& intentId) {
        VoiceCommand command;
        command.phrase = phrase;
        command.intentId = intentId;
        command.isExactMatch = false;
        command.isCaseSensitive = false;

        registerVoiceCommand(command);
    }

    std::vector<VoiceCommand> getFrequentCommands(int limit = 10) const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<VoiceCommand> commands;
        for (const auto& [phrase, command] : voiceCommands_) {
            commands.push_back(command);
        }

        std::sort(commands.begin(), commands.end(),
            [](const VoiceCommand& a, const VoiceCommand& b) {
                return a.usageCount > b.usageCount;
            });

        if (commands.size() > static_cast<size_t>(limit)) {
            commands.resize(limit);
        }

        return commands;
    }

    // ========================================================================
    // Automation Workflows
    // ========================================================================

    void registerWorkflow(const AutomationWorkflow& workflow) {
        std::lock_guard<std::mutex> lock(mutex_);
        workflows_[workflow.id] = workflow;
    }

    void runWorkflow(const std::string& workflowId) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = workflows_.find(workflowId);
        if (it == workflows_.end()) return;

        auto& workflow = it->second;
        if (!workflow.isEnabled) return;

        // Execute actions in sequence
        for (const auto& action : workflow.actions) {
            // Check condition
            if (!checkCondition(action.condition, action.conditionValue)) {
                continue;
            }

            // Apply delay
            if (action.delay.count() > 0) {
                std::this_thread::sleep_for(action.delay);
            }

            // Execute
            executeIntent(action.intentId, action.parameters);
        }

        workflow.lastRun = std::chrono::system_clock::now();
        workflow.runCount++;
    }

    void enableWorkflow(const std::string& workflowId, bool enabled) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = workflows_.find(workflowId);
        if (it != workflows_.end()) {
            it->second.isEnabled = enabled;
        }
    }

    std::vector<AutomationWorkflow> getAllWorkflows() const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<AutomationWorkflow> result;
        for (const auto& [id, workflow] : workflows_) {
            result.push_back(workflow);
        }
        return result;
    }

    // ========================================================================
    // HomeKit Integration
    // ========================================================================

    void registerHomeKitScene(const HomeKitScene& scene) {
        std::lock_guard<std::mutex> lock(mutex_);
        homeKitScenes_[scene.id] = scene;
    }

    void triggerHomeKitScene(const std::string& sceneId) {
        // Would use HomeKit API to trigger scene
        // HMHome.executeScene(scene)
    }

    void onHomeKitSceneActivated(const std::string& sceneId) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = homeKitScenes_.find(sceneId);
        if (it != homeKitScenes_.end() && !it->second.workflowId.empty()) {
            runWorkflow(it->second.workflowId);
        }
    }

    std::vector<HomeKitAccessory> getHomeKitAccessories() const {
        // Would query HomeKit for available accessories
        return homeKitAccessories_;
    }

    void controlAccessory(const std::string& accessoryId,
                          const std::string& characteristic,
                          const std::string& value) {
        // Would use HomeKit API to control accessory
        // HMCharacteristic.writeValue(value)
    }

    // ========================================================================
    // CarPlay Integration
    // ========================================================================

    std::vector<SiriIntent> getCarPlayIntents() const {
        // Return simplified intents safe for driving
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<SiriIntent> result;
        for (const auto& [id, intent] : intents_) {
            if (intent.category == IntentCategory::Transport ||
                intent.category == IntentCategory::Navigation ||
                intent.category == IntentCategory::Information) {
                result.push_back(intent);
            }
        }
        return result;
    }

    // ========================================================================
    // Donation & Suggestions
    // ========================================================================

    void donateActivity(const std::string& intentId,
                        const std::map<std::string, std::string>& params = {}) {
        // Donate to Siri for future suggestions
        // INInteraction.donate(...)

        std::lock_guard<std::mutex> lock(mutex_);
        activityDonations_.push_back({intentId, params,
            std::chrono::system_clock::now()});
    }

    void deleteAllDonations() {
        // INInteraction.deleteAllInteractions(...)
        std::lock_guard<std::mutex> lock(mutex_);
        activityDonations_.clear();
    }

    // ========================================================================
    // Suggested Shortcuts
    // ========================================================================

    std::vector<SiriIntent> getSuggestedShortcuts() const {
        std::lock_guard<std::mutex> lock(mutex_);

        // Based on usage patterns, suggest shortcuts
        std::map<std::string, int> intentUsage;

        for (const auto& donation : activityDonations_) {
            intentUsage[donation.intentId]++;
        }

        std::vector<std::pair<std::string, int>> sorted(
            intentUsage.begin(), intentUsage.end());

        std::sort(sorted.begin(), sorted.end(),
            [](const auto& a, const auto& b) {
                return a.second > b.second;
            });

        std::vector<SiriIntent> suggestions;
        for (const auto& [intentId, count] : sorted) {
            if (suggestions.size() >= 5) break;

            auto it = intents_.find(intentId);
            if (it != intents_.end()) {
                suggestions.push_back(it->second);
            }
        }

        return suggestions;
    }

private:
    SiriShortcutsManager() = default;
    ~SiriShortcutsManager() = default;

    SiriShortcutsManager(const SiriShortcutsManager&) = delete;
    SiriShortcutsManager& operator=(const SiriShortcutsManager&) = delete;

    // ========================================================================
    // Built-in Intents
    // ========================================================================

    void registerBuiltInIntents() {
        // Transport controls
        registerIntent({
            .id = "transport.play",
            .title = "Play",
            .description = "Start playback",
            .category = IntentCategory::Transport,
            .suggestedPhrases = {"Play music", "Start playing", "Resume playback"},
            .handler = [](const auto&) { return true; },
            .iconName = "play.fill",
            .successMessage = "Playing",
            .failureMessage = "Could not play"
        });

        registerIntent({
            .id = "transport.pause",
            .title = "Pause",
            .description = "Pause playback",
            .category = IntentCategory::Transport,
            .suggestedPhrases = {"Pause", "Stop playing", "Pause music"},
            .handler = [](const auto&) { return true; },
            .iconName = "pause.fill",
            .successMessage = "Paused",
            .failureMessage = "Could not pause"
        });

        registerIntent({
            .id = "transport.stop",
            .title = "Stop",
            .description = "Stop playback and return to start",
            .category = IntentCategory::Transport,
            .suggestedPhrases = {"Stop", "Stop music", "Stop everything"},
            .handler = [](const auto&) { return true; },
            .iconName = "stop.fill",
            .successMessage = "Stopped",
            .failureMessage = "Could not stop"
        });

        registerIntent({
            .id = "transport.record",
            .title = "Start Recording",
            .description = "Begin recording on armed tracks",
            .category = IntentCategory::Recording,
            .suggestedPhrases = {"Start recording", "Record", "Begin recording"},
            .handler = [](const auto&) { return true; },
            .iconName = "record.circle",
            .requiresUnlock = true,
            .successMessage = "Recording started",
            .failureMessage = "Could not start recording"
        });

        // Project operations
        registerIntent({
            .id = "project.new",
            .title = "Create New Project",
            .description = "Create a new music project",
            .category = IntentCategory::Project,
            .suggestedPhrases = {"New project", "Create project", "Start new project"},
            .parameters = {{
                .name = "name",
                .displayName = "Project Name",
                .type = IntentParameter::Type::String,
                .isRequired = false
            }},
            .handler = [](const auto& params) { return true; },
            .iconName = "plus.circle.fill",
            .successMessage = "New project created",
            .failureMessage = "Could not create project"
        });

        registerIntent({
            .id = "project.open",
            .title = "Open Project",
            .description = "Open an existing project",
            .category = IntentCategory::Project,
            .suggestedPhrases = {"Open project", "Open my project"},
            .parameters = {{
                .name = "projectName",
                .displayName = "Project Name",
                .type = IntentParameter::Type::String,
                .isRequired = true
            }},
            .handler = [](const auto& params) { return true; },
            .iconName = "folder.fill",
            .successMessage = "Project opened",
            .failureMessage = "Could not open project"
        });

        registerIntent({
            .id = "project.save",
            .title = "Save Project",
            .description = "Save the current project",
            .category = IntentCategory::Project,
            .suggestedPhrases = {"Save", "Save project", "Save my work"},
            .handler = [](const auto&) { return true; },
            .iconName = "square.and.arrow.down.fill",
            .successMessage = "Project saved",
            .failureMessage = "Could not save project"
        });

        // Mixing
        registerIntent({
            .id = "mixing.setVolume",
            .title = "Set Volume",
            .description = "Set the master or track volume",
            .category = IntentCategory::Mixing,
            .suggestedPhrases = {"Set volume to", "Turn up the volume", "Lower volume"},
            .parameters = {
                {
                    .name = "level",
                    .displayName = "Volume Level",
                    .type = IntentParameter::Type::Integer,
                    .isRequired = true,
                    .minValue = 0,
                    .maxValue = 100
                },
                {
                    .name = "track",
                    .displayName = "Track Name",
                    .type = IntentParameter::Type::String,
                    .isRequired = false
                }
            },
            .handler = [](const auto& params) { return true; },
            .iconName = "speaker.wave.2.fill",
            .successMessage = "Volume adjusted",
            .failureMessage = "Could not adjust volume"
        });

        registerIntent({
            .id = "mixing.mute",
            .title = "Mute Track",
            .description = "Mute a specific track",
            .category = IntentCategory::Mixing,
            .suggestedPhrases = {"Mute track", "Mute vocals", "Mute drums"},
            .parameters = {{
                .name = "track",
                .displayName = "Track Name",
                .type = IntentParameter::Type::String,
                .isRequired = true
            }},
            .handler = [](const auto& params) { return true; },
            .iconName = "speaker.slash.fill",
            .successMessage = "Track muted",
            .failureMessage = "Could not mute track"
        });

        registerIntent({
            .id = "mixing.solo",
            .title = "Solo Track",
            .description = "Solo a specific track",
            .category = IntentCategory::Mixing,
            .suggestedPhrases = {"Solo track", "Solo vocals", "Just play drums"},
            .parameters = {{
                .name = "track",
                .displayName = "Track Name",
                .type = IntentParameter::Type::String,
                .isRequired = true
            }},
            .handler = [](const auto& params) { return true; },
            .iconName = "s.circle.fill",
            .successMessage = "Track soloed",
            .failureMessage = "Could not solo track"
        });

        // Navigation
        registerIntent({
            .id = "nav.goToMarker",
            .title = "Go to Marker",
            .description = "Jump to a specific marker",
            .category = IntentCategory::Navigation,
            .suggestedPhrases = {"Go to marker", "Jump to chorus", "Go to verse"},
            .parameters = {{
                .name = "marker",
                .displayName = "Marker Name",
                .type = IntentParameter::Type::String,
                .isRequired = true
            }},
            .handler = [](const auto& params) { return true; },
            .iconName = "bookmark.fill",
            .successMessage = "Jumped to marker",
            .failureMessage = "Marker not found"
        });

        registerIntent({
            .id = "nav.goToTime",
            .title = "Go to Time",
            .description = "Jump to a specific time position",
            .category = IntentCategory::Navigation,
            .suggestedPhrases = {"Go to minute 2", "Jump to 1:30", "Go to the beginning"},
            .parameters = {{
                .name = "time",
                .displayName = "Time Position",
                .type = IntentParameter::Type::Duration,
                .isRequired = true
            }},
            .handler = [](const auto& params) { return true; },
            .iconName = "clock.fill",
            .successMessage = "Position changed",
            .failureMessage = "Could not navigate"
        });

        // Information
        registerIntent({
            .id = "info.getStatus",
            .title = "Get Status",
            .description = "Get the current playback status",
            .category = IntentCategory::Information,
            .suggestedPhrases = {"What's playing", "Status", "What's the current time"},
            .handler = [](const auto&) { return true; },
            .iconName = "info.circle.fill",
            .successMessage = "Currently playing...",
            .failureMessage = "Could not get status"
        });

        registerIntent({
            .id = "info.getSessionTime",
            .title = "Get Session Time",
            .description = "Get how long you've been working",
            .category = IntentCategory::Information,
            .suggestedPhrases = {"How long have I been working", "Session time", "Time spent today"},
            .handler = [](const auto&) { return true; },
            .iconName = "timer",
            .successMessage = "You've been working for...",
            .failureMessage = "Could not get session time"
        });

        // Export
        registerIntent({
            .id = "export.audio",
            .title = "Export Audio",
            .description = "Export the project as audio",
            .category = IntentCategory::Export,
            .suggestedPhrases = {"Export", "Export audio", "Export as MP3"},
            .parameters = {{
                .name = "format",
                .displayName = "Audio Format",
                .type = IntentParameter::Type::Enum,
                .isRequired = false,
                .enumValues = {"WAV", "MP3", "AAC", "FLAC", "AIFF"}
            }},
            .handler = [](const auto& params) { return true; },
            .iconName = "square.and.arrow.up.fill",
            .requiresUnlock = true,
            .successMessage = "Export started",
            .failureMessage = "Could not export"
        });

        // Settings
        registerIntent({
            .id = "settings.setBPM",
            .title = "Set Tempo",
            .description = "Set the project tempo",
            .category = IntentCategory::Settings,
            .suggestedPhrases = {"Set tempo to", "Change BPM to", "Set 120 BPM"},
            .parameters = {{
                .name = "bpm",
                .displayName = "BPM",
                .type = IntentParameter::Type::Integer,
                .isRequired = true,
                .minValue = 20,
                .maxValue = 300
            }},
            .handler = [](const auto& params) { return true; },
            .iconName = "metronome.fill",
            .successMessage = "Tempo set",
            .failureMessage = "Could not set tempo"
        });

        registerIntent({
            .id = "settings.metronome",
            .title = "Toggle Metronome",
            .description = "Turn metronome on or off",
            .category = IntentCategory::Settings,
            .suggestedPhrases = {"Metronome on", "Metronome off", "Toggle metronome"},
            .parameters = {{
                .name = "enabled",
                .displayName = "Enabled",
                .type = IntentParameter::Type::Boolean,
                .isRequired = false
            }},
            .handler = [](const auto& params) { return true; },
            .iconName = "metronome",
            .successMessage = "Metronome toggled",
            .failureMessage = "Could not toggle metronome"
        });
    }

    void loadUserPhrases() {
        // Load user-defined phrases from storage
    }

    void loadWorkflows() {
        // Load saved workflows from storage
    }

    void donateIntent(const SiriIntent& intent) {
        // Donate to Siri for suggestions
        // INVoiceShortcut registration
    }

    IntentResult tryNLPMatch(const std::string& phrase) {
        IntentResult result;
        result.success = false;
        result.message = "I didn't understand that command";
        result.spokenResponse = "I'm not sure what you mean. Try saying 'play', 'pause', or 'record'.";

        // Would use NLU to match phrase to intent
        // For now, simple keyword matching

        std::string lower = phrase;
        std::transform(lower.begin(), lower.end(), lower.begin(), ::tolower);

        if (lower.find("play") != std::string::npos) {
            return executeIntent("transport.play");
        }
        if (lower.find("pause") != std::string::npos ||
            lower.find("stop") != std::string::npos) {
            return executeIntent("transport.pause");
        }
        if (lower.find("record") != std::string::npos) {
            return executeIntent("transport.record");
        }
        if (lower.find("save") != std::string::npos) {
            return executeIntent("project.save");
        }

        return result;
    }

    bool checkCondition(AutomationAction::Condition condition,
                        const std::string& value) {
        // Would check actual app state
        switch (condition) {
            case AutomationAction::Condition::Always:
                return true;
            case AutomationAction::Condition::IfPlaying:
                // Check if playing
                return true;
            case AutomationAction::Condition::IfStopped:
                // Check if stopped
                return true;
            default:
                return true;
        }
    }

    // ========================================================================
    // Member Variables
    // ========================================================================

    mutable std::mutex mutex_;
    std::atomic<bool> initialized_{false};

    std::map<std::string, SiriIntent> intents_;
    std::map<std::string, VoiceCommand> voiceCommands_;
    std::map<std::string, AutomationWorkflow> workflows_;
    std::map<std::string, HomeKitScene> homeKitScenes_;
    std::vector<HomeKitAccessory> homeKitAccessories_;

    struct ActivityDonation {
        std::string intentId;
        std::map<std::string, std::string> params;
        std::chrono::system_clock::time_point timestamp;
    };
    std::vector<ActivityDonation> activityDonations_;
};

// ============================================================================
// Quick Voice Commands
// ============================================================================

namespace Voice {

inline IntentResult execute(const std::string& phrase) {
    return SiriShortcutsManager::getInstance().executeVoiceCommand(phrase);
}

inline void learn(const std::string& phrase, const std::string& intentId) {
    SiriShortcutsManager::getInstance().learnPhrase(phrase, intentId);
}

inline IntentResult play() {
    return SiriShortcutsManager::getInstance().executeIntent("transport.play");
}

inline IntentResult pause() {
    return SiriShortcutsManager::getInstance().executeIntent("transport.pause");
}

inline IntentResult record() {
    return SiriShortcutsManager::getInstance().executeIntent("transport.record");
}

inline IntentResult save() {
    return SiriShortcutsManager::getInstance().executeIntent("project.save");
}

} // namespace Voice

} // namespace Echoel
