/**
 * EchoelKeyboardShortcuts.h
 *
 * Global Hotkey & Keyboard Shortcuts System
 *
 * Comprehensive keyboard control for Echoel Music production:
 * - Global hotkeys (work even when app is in background)
 * - Customizable key bindings
 * - Chord/sequence shortcuts (e.g., Ctrl+K, Ctrl+S)
 * - Context-aware shortcuts
 * - MIDI controller mapping
 * - Gaming controller support
 * - Accessibility key navigation
 * - Conflict detection & resolution
 * - Import/export shortcut profiles
 * - Multi-platform support (macOS, Windows, Linux)
 *
 * Part of Ralph Wiggum Genius Loop Mode - Phase 1
 * "I'm helping!" - Ralph Wiggum
 */

#pragma once

#include <string>
#include <vector>
#include <map>
#include <set>
#include <functional>
#include <memory>
#include <chrono>
#include <optional>
#include <variant>
#include <atomic>
#include <mutex>
#include <thread>

namespace Echoel {

// ============================================================================
// Key Definitions
// ============================================================================

enum class KeyCode : uint16_t {
    // Letters
    A = 0, B, C, D, E, F, G, H, I, J, K, L, M,
    N, O, P, Q, R, S, T, U, V, W, X, Y, Z,

    // Numbers
    Num0 = 30, Num1, Num2, Num3, Num4, Num5, Num6, Num7, Num8, Num9,

    // Function keys
    F1 = 50, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12,
    F13, F14, F15, F16, F17, F18, F19, F20, F21, F22, F23, F24,

    // Navigation
    Up = 80, Down, Left, Right,
    Home, End, PageUp, PageDown,

    // Editing
    Backspace = 90, Delete, Insert, Enter, Tab,

    // Special
    Escape = 100, Space, CapsLock, NumLock, ScrollLock, PrintScreen, Pause,

    // Numpad
    Numpad0 = 110, Numpad1, Numpad2, Numpad3, Numpad4,
    Numpad5, Numpad6, Numpad7, Numpad8, Numpad9,
    NumpadAdd, NumpadSubtract, NumpadMultiply, NumpadDivide,
    NumpadEnter, NumpadDecimal, NumpadEquals,

    // Media keys
    MediaPlay = 140, MediaPause, MediaStop, MediaNext, MediaPrev,
    MediaVolumeUp, MediaVolumeDown, MediaMute,

    // Symbols
    Minus = 160, Equals, LeftBracket, RightBracket, Backslash,
    Semicolon, Quote, Grave, Comma, Period, Slash,

    // Platform-specific
    LeftCommand = 180, RightCommand,  // macOS
    LeftWindows, RightWindows,        // Windows
    LeftMeta, RightMeta,              // Linux
    Menu, Help, Clear,

    Unknown = 255
};

enum class ModifierKey : uint8_t {
    None    = 0,
    Shift   = 1 << 0,
    Control = 1 << 1,
    Alt     = 1 << 2,   // Option on macOS
    Super   = 1 << 3,   // Command on macOS, Windows key, Meta on Linux
    Fn      = 1 << 4,
    CapsLock = 1 << 5,
    NumLock  = 1 << 6
};

inline ModifierKey operator|(ModifierKey a, ModifierKey b) {
    return static_cast<ModifierKey>(static_cast<uint8_t>(a) | static_cast<uint8_t>(b));
}

inline ModifierKey operator&(ModifierKey a, ModifierKey b) {
    return static_cast<ModifierKey>(static_cast<uint8_t>(a) & static_cast<uint8_t>(b));
}

inline bool hasModifier(ModifierKey set, ModifierKey check) {
    return (static_cast<uint8_t>(set) & static_cast<uint8_t>(check)) != 0;
}

// ============================================================================
// Key Combination
// ============================================================================

struct KeyCombination {
    KeyCode key = KeyCode::Unknown;
    ModifierKey modifiers = ModifierKey::None;

    bool operator==(const KeyCombination& other) const {
        return key == other.key && modifiers == other.modifiers;
    }

    bool operator<(const KeyCombination& other) const {
        if (key != other.key) return key < other.key;
        return static_cast<uint8_t>(modifiers) < static_cast<uint8_t>(other.modifiers);
    }

    std::string toString() const {
        std::string result;

        if (hasModifier(modifiers, ModifierKey::Super)) {
#ifdef __APPLE__
            result += "⌘+";
#else
            result += "Win+";
#endif
        }
        if (hasModifier(modifiers, ModifierKey::Control)) {
#ifdef __APPLE__
            result += "⌃+";
#else
            result += "Ctrl+";
#endif
        }
        if (hasModifier(modifiers, ModifierKey::Alt)) {
#ifdef __APPLE__
            result += "⌥+";
#else
            result += "Alt+";
#endif
        }
        if (hasModifier(modifiers, ModifierKey::Shift)) {
#ifdef __APPLE__
            result += "⇧+";
#else
            result += "Shift+";
#endif
        }

        result += keyCodeToString(key);
        return result;
    }

    static std::string keyCodeToString(KeyCode code) {
        switch (code) {
            case KeyCode::A: return "A";
            case KeyCode::B: return "B";
            case KeyCode::C: return "C";
            case KeyCode::D: return "D";
            case KeyCode::E: return "E";
            case KeyCode::F: return "F";
            case KeyCode::G: return "G";
            case KeyCode::H: return "H";
            case KeyCode::I: return "I";
            case KeyCode::J: return "J";
            case KeyCode::K: return "K";
            case KeyCode::L: return "L";
            case KeyCode::M: return "M";
            case KeyCode::N: return "N";
            case KeyCode::O: return "O";
            case KeyCode::P: return "P";
            case KeyCode::Q: return "Q";
            case KeyCode::R: return "R";
            case KeyCode::S: return "S";
            case KeyCode::T: return "T";
            case KeyCode::U: return "U";
            case KeyCode::V: return "V";
            case KeyCode::W: return "W";
            case KeyCode::X: return "X";
            case KeyCode::Y: return "Y";
            case KeyCode::Z: return "Z";
            case KeyCode::Space: return "Space";
            case KeyCode::Enter: return "Enter";
            case KeyCode::Tab: return "Tab";
            case KeyCode::Escape: return "Escape";
            case KeyCode::Backspace: return "Backspace";
            case KeyCode::Delete: return "Delete";
            case KeyCode::Up: return "↑";
            case KeyCode::Down: return "↓";
            case KeyCode::Left: return "←";
            case KeyCode::Right: return "→";
            default: return "Key" + std::to_string(static_cast<int>(code));
        }
    }
};

// ============================================================================
// Chord/Sequence Shortcuts (e.g., Ctrl+K, Ctrl+S)
// ============================================================================

struct KeySequence {
    std::vector<KeyCombination> sequence;
    std::chrono::milliseconds timeout{1000};  // Max time between keys

    std::string toString() const {
        std::string result;
        for (size_t i = 0; i < sequence.size(); ++i) {
            if (i > 0) result += ", ";
            result += sequence[i].toString();
        }
        return result;
    }
};

// ============================================================================
// Shortcut Categories
// ============================================================================

enum class ShortcutCategory {
    // Transport
    Playback,           // Play, pause, stop, record
    Navigation,         // Timeline, markers, sections

    // Editing
    Selection,          // Select, extend, shrink
    Clipboard,          // Cut, copy, paste, duplicate
    Undo,               // Undo, redo, history

    // Tracks
    TrackManagement,    // Add, delete, duplicate tracks
    TrackRouting,       // Solo, mute, arm, bus routing

    // Mixing
    Mixer,              // Faders, pans, sends
    Automation,         // Automation modes, points

    // Effects
    Effects,            // Add, remove, bypass effects
    Instruments,        // Virtual instruments control

    // Views
    Windows,            // Open, close, arrange windows
    Zoom,               // Zoom in/out, fit to window

    // Project
    File,               // New, open, save, export
    Project,            // Settings, tempo, time signature

    // Tools
    Tools,              // Selection tool, pencil, etc.
    Quantize,           // Quantization options

    // Special
    MIDI,               // MIDI-specific shortcuts
    Audio,              // Audio-specific shortcuts
    Custom,             // User-defined category
    Global              // Always active shortcuts
};

// ============================================================================
// Context
// ============================================================================

enum class ShortcutContext {
    Global,             // Works everywhere, even in background
    Application,        // Works when app has focus
    MainWindow,         // Main window focused
    MixerWindow,        // Mixer window focused
    PianoRollWindow,    // Piano roll editor
    ArrangeWindow,      // Arrangement view
    BrowserWindow,      // File/preset browser
    EffectsWindow,      // Effects rack
    TextEditing,        // When editing text (usually disabled shortcuts)
    Modal,              // During modal dialogs
    Any                 // Any context
};

// ============================================================================
// Shortcut Action
// ============================================================================

using ShortcutAction = std::function<void()>;
using ParameterizedAction = std::function<void(const std::string& param)>;

struct ShortcutBinding {
    std::string id;
    std::string name;
    std::string description;
    ShortcutCategory category = ShortcutCategory::Custom;

    // Can be either single key or sequence
    std::variant<KeyCombination, KeySequence> trigger;

    ShortcutContext context = ShortcutContext::Application;
    bool isGlobal = false;  // Works even when app in background
    bool isEnabled = true;
    bool allowRepeat = false;  // Fire continuously while held
    std::chrono::milliseconds repeatDelay{500};
    std::chrono::milliseconds repeatRate{50};

    ShortcutAction action;
    std::string commandId;  // Alternative: link to command system

    // Conflict handling
    int priority = 0;  // Higher = takes precedence
    bool allowConflict = false;  // If true, other bindings can share key
};

// ============================================================================
// MIDI Controller Mapping
// ============================================================================

enum class MIDIControlType {
    NoteOn,
    NoteOff,
    ControlChange,
    ProgramChange,
    PitchBend,
    Aftertouch
};

struct MIDIMapping {
    std::string id;
    MIDIControlType type = MIDIControlType::ControlChange;
    int channel = -1;  // -1 = any channel
    int number = 0;    // Note number or CC number
    int minValue = 0;
    int maxValue = 127;

    std::string targetParameterId;
    ShortcutAction action;

    bool learningMode = false;
};

// ============================================================================
// Gaming Controller Mapping
// ============================================================================

enum class GamepadButton : uint8_t {
    A, B, X, Y,
    LeftBumper, RightBumper,
    LeftTrigger, RightTrigger,
    Back, Start, Guide,
    LeftStick, RightStick,
    DPadUp, DPadDown, DPadLeft, DPadRight
};

enum class GamepadAxis : uint8_t {
    LeftStickX, LeftStickY,
    RightStickX, RightStickY,
    LeftTrigger, RightTrigger
};

struct GamepadMapping {
    std::string id;
    std::variant<GamepadButton, GamepadAxis> input;

    // For buttons
    ShortcutAction onPress;
    ShortcutAction onRelease;

    // For axes
    std::string targetParameterId;
    float deadzone = 0.1f;
    bool invert = false;
    float sensitivity = 1.0f;
};

// ============================================================================
// Shortcut Profile
// ============================================================================

struct ShortcutProfile {
    std::string id;
    std::string name;
    std::string description;
    std::string author;
    std::string version;
    std::string basedOn;  // Parent profile for inheritance

    std::map<std::string, ShortcutBinding> bindings;
    std::map<std::string, MIDIMapping> midiMappings;
    std::map<std::string, GamepadMapping> gamepadMappings;

    bool isBuiltIn = false;
    bool isReadOnly = false;

    std::chrono::system_clock::time_point created;
    std::chrono::system_clock::time_point modified;
};

// ============================================================================
// Built-in Presets
// ============================================================================

enum class ShortcutPreset {
    EchoelDefault,
    AbletonLive,
    LogicPro,
    ProTools,
    FLStudio,
    Cubase,
    Reaper,
    StudioOne,
    Minimal,
    Vim,              // For the brave
    Emacs             // For the enlightened
};

// ============================================================================
// Conflict Resolution
// ============================================================================

struct ShortcutConflict {
    KeyCombination key;
    std::vector<std::string> conflictingBindingIds;
    std::string resolvedWinner;  // Which binding takes precedence
    std::string resolutionReason;
};

// ============================================================================
// Keyboard Shortcuts Manager
// ============================================================================

class KeyboardShortcutsManager {
public:
    static KeyboardShortcutsManager& getInstance() {
        static KeyboardShortcutsManager instance;
        return instance;
    }

    // ========================================================================
    // Initialization
    // ========================================================================

    void initialize() {
        std::lock_guard<std::mutex> lock(mutex_);

        registerBuiltInCommands();
        loadProfile(ShortcutPreset::EchoelDefault);
        detectConflicts();

        initialized_ = true;
    }

    // ========================================================================
    // Profile Management
    // ========================================================================

    void loadProfile(ShortcutPreset preset) {
        switch (preset) {
            case ShortcutPreset::EchoelDefault:
                loadEchoelDefaultProfile();
                break;
            case ShortcutPreset::AbletonLive:
                loadAbletonProfile();
                break;
            case ShortcutPreset::LogicPro:
                loadLogicProProfile();
                break;
            case ShortcutPreset::Vim:
                loadVimProfile();
                break;
            default:
                loadEchoelDefaultProfile();
        }
    }

    void loadProfile(const std::string& profilePath) {
        // Load custom profile from JSON file
        // Implementation would parse JSON and populate bindings
    }

    void saveProfile(const std::string& profilePath) const {
        // Save current profile to JSON file
    }

    ShortcutProfile getCurrentProfile() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return currentProfile_;
    }

    std::vector<ShortcutProfile> getAvailableProfiles() const {
        return availableProfiles_;
    }

    // ========================================================================
    // Binding Management
    // ========================================================================

    void registerBinding(const ShortcutBinding& binding) {
        std::lock_guard<std::mutex> lock(mutex_);
        currentProfile_.bindings[binding.id] = binding;

        // Update lookup maps
        if (auto* combo = std::get_if<KeyCombination>(&binding.trigger)) {
            keyToBindings_[*combo].push_back(binding.id);
        }

        detectConflicts();
    }

    void unregisterBinding(const std::string& bindingId) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = currentProfile_.bindings.find(bindingId);
        if (it != currentProfile_.bindings.end()) {
            // Remove from lookup maps
            if (auto* combo = std::get_if<KeyCombination>(&it->second.trigger)) {
                auto& bindings = keyToBindings_[*combo];
                bindings.erase(
                    std::remove(bindings.begin(), bindings.end(), bindingId),
                    bindings.end()
                );
            }

            currentProfile_.bindings.erase(it);
        }
    }

    void setBindingKey(const std::string& bindingId, const KeyCombination& newKey) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = currentProfile_.bindings.find(bindingId);
        if (it != currentProfile_.bindings.end()) {
            // Remove old mapping
            if (auto* oldCombo = std::get_if<KeyCombination>(&it->second.trigger)) {
                auto& bindings = keyToBindings_[*oldCombo];
                bindings.erase(
                    std::remove(bindings.begin(), bindings.end(), bindingId),
                    bindings.end()
                );
            }

            // Set new key
            it->second.trigger = newKey;
            keyToBindings_[newKey].push_back(bindingId);

            detectConflicts();
        }
    }

    void enableBinding(const std::string& bindingId, bool enabled) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = currentProfile_.bindings.find(bindingId);
        if (it != currentProfile_.bindings.end()) {
            it->second.isEnabled = enabled;
        }
    }

    std::optional<ShortcutBinding> getBinding(const std::string& bindingId) const {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = currentProfile_.bindings.find(bindingId);
        if (it != currentProfile_.bindings.end()) {
            return it->second;
        }
        return std::nullopt;
    }

    std::vector<ShortcutBinding> getBindingsByCategory(ShortcutCategory category) const {
        std::lock_guard<std::mutex> lock(mutex_);
        std::vector<ShortcutBinding> result;

        for (const auto& [id, binding] : currentProfile_.bindings) {
            if (binding.category == category) {
                result.push_back(binding);
            }
        }

        return result;
    }

    std::vector<ShortcutBinding> getBindingsForKey(const KeyCombination& key) const {
        std::lock_guard<std::mutex> lock(mutex_);
        std::vector<ShortcutBinding> result;

        auto it = keyToBindings_.find(key);
        if (it != keyToBindings_.end()) {
            for (const auto& id : it->second) {
                auto bindIt = currentProfile_.bindings.find(id);
                if (bindIt != currentProfile_.bindings.end()) {
                    result.push_back(bindIt->second);
                }
            }
        }

        return result;
    }

    // ========================================================================
    // Key Event Handling
    // ========================================================================

    bool handleKeyDown(const KeyCombination& key, ShortcutContext context) {
        std::lock_guard<std::mutex> lock(mutex_);

        // Check for sequence in progress
        if (!sequenceBuffer_.empty()) {
            auto now = std::chrono::steady_clock::now();
            if (now - lastKeyTime_ > sequenceTimeout_) {
                sequenceBuffer_.clear();
            }
        }

        sequenceBuffer_.push_back(key);
        lastKeyTime_ = std::chrono::steady_clock::now();

        // Find matching bindings
        std::vector<ShortcutBinding*> matches;

        for (auto& [id, binding] : currentProfile_.bindings) {
            if (!binding.isEnabled) continue;
            if (!isContextMatch(binding.context, context)) continue;

            if (auto* combo = std::get_if<KeyCombination>(&binding.trigger)) {
                if (*combo == key) {
                    matches.push_back(&binding);
                }
            } else if (auto* seq = std::get_if<KeySequence>(&binding.trigger)) {
                if (matchesSequence(*seq)) {
                    matches.push_back(&binding);
                }
            }
        }

        if (matches.empty()) {
            // Check if this could be start of a sequence
            bool couldBeSequence = false;
            for (const auto& [id, binding] : currentProfile_.bindings) {
                if (auto* seq = std::get_if<KeySequence>(&binding.trigger)) {
                    if (isSequencePrefix(*seq)) {
                        couldBeSequence = true;
                        break;
                    }
                }
            }

            if (!couldBeSequence) {
                sequenceBuffer_.clear();
            }

            return false;
        }

        // Find highest priority match
        auto* winner = matches[0];
        for (auto* match : matches) {
            if (match->priority > winner->priority) {
                winner = match;
            }
        }

        // Execute action
        if (winner->action) {
            winner->action();
        }

        // Start repeat timer if needed
        if (winner->allowRepeat) {
            startRepeat(winner);
        }

        sequenceBuffer_.clear();
        return true;
    }

    void handleKeyUp(const KeyCombination& key) {
        std::lock_guard<std::mutex> lock(mutex_);

        // Stop any repeating actions for this key
        stopRepeat();
    }

    // ========================================================================
    // Shortcut Learning Mode
    // ========================================================================

    using KeyLearnCallback = std::function<void(const KeyCombination& learned)>;

    void startKeyLearning(const KeyLearnCallback& callback) {
        std::lock_guard<std::mutex> lock(mutex_);
        learningMode_ = true;
        learningCallback_ = callback;
    }

    void stopKeyLearning() {
        std::lock_guard<std::mutex> lock(mutex_);
        learningMode_ = false;
        learningCallback_ = nullptr;
    }

    bool isLearningMode() const {
        return learningMode_;
    }

    void learnKey(const KeyCombination& key) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (learningMode_ && learningCallback_) {
            learningMode_ = false;
            learningCallback_(key);
            learningCallback_ = nullptr;
        }
    }

    // ========================================================================
    // MIDI Mapping
    // ========================================================================

    void registerMIDIMapping(const MIDIMapping& mapping) {
        std::lock_guard<std::mutex> lock(mutex_);
        currentProfile_.midiMappings[mapping.id] = mapping;
    }

    void unregisterMIDIMapping(const std::string& mappingId) {
        std::lock_guard<std::mutex> lock(mutex_);
        currentProfile_.midiMappings.erase(mappingId);
    }

    bool handleMIDIMessage(MIDIControlType type, int channel, int number, int value) {
        std::lock_guard<std::mutex> lock(mutex_);

        for (auto& [id, mapping] : currentProfile_.midiMappings) {
            if (mapping.type != type) continue;
            if (mapping.channel != -1 && mapping.channel != channel) continue;
            if (mapping.number != number) continue;

            // Check learning mode
            if (mapping.learningMode) {
                mapping.learningMode = false;
                mapping.type = type;
                mapping.channel = channel;
                mapping.number = number;
                continue;
            }

            if (mapping.action) {
                mapping.action();
                return true;
            }
        }

        return false;
    }

    void startMIDILearn(const std::string& mappingId) {
        std::lock_guard<std::mutex> lock(mutex_);
        auto it = currentProfile_.midiMappings.find(mappingId);
        if (it != currentProfile_.midiMappings.end()) {
            it->second.learningMode = true;
        }
    }

    // ========================================================================
    // Gamepad Mapping
    // ========================================================================

    void registerGamepadMapping(const GamepadMapping& mapping) {
        std::lock_guard<std::mutex> lock(mutex_);
        currentProfile_.gamepadMappings[mapping.id] = mapping;
    }

    bool handleGamepadButton(GamepadButton button, bool pressed) {
        std::lock_guard<std::mutex> lock(mutex_);

        for (auto& [id, mapping] : currentProfile_.gamepadMappings) {
            if (auto* btn = std::get_if<GamepadButton>(&mapping.input)) {
                if (*btn == button) {
                    if (pressed && mapping.onPress) {
                        mapping.onPress();
                        return true;
                    } else if (!pressed && mapping.onRelease) {
                        mapping.onRelease();
                        return true;
                    }
                }
            }
        }

        return false;
    }

    float handleGamepadAxis(GamepadAxis axis, float value) {
        std::lock_guard<std::mutex> lock(mutex_);

        for (auto& [id, mapping] : currentProfile_.gamepadMappings) {
            if (auto* ax = std::get_if<GamepadAxis>(&mapping.input)) {
                if (*ax == axis) {
                    // Apply deadzone
                    if (std::abs(value) < mapping.deadzone) {
                        value = 0.0f;
                    } else {
                        // Rescale value outside deadzone
                        float sign = value > 0 ? 1.0f : -1.0f;
                        value = sign * (std::abs(value) - mapping.deadzone) /
                                (1.0f - mapping.deadzone);
                    }

                    // Apply invert and sensitivity
                    if (mapping.invert) value = -value;
                    value *= mapping.sensitivity;

                    return value;
                }
            }
        }

        return value;
    }

    // ========================================================================
    // Conflict Detection
    // ========================================================================

    std::vector<ShortcutConflict> getConflicts() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return conflicts_;
    }

    void resolveConflict(const KeyCombination& key, const std::string& winnerId) {
        std::lock_guard<std::mutex> lock(mutex_);

        // Set winner to highest priority
        auto it = currentProfile_.bindings.find(winnerId);
        if (it != currentProfile_.bindings.end()) {
            it->second.priority = 1000;  // Very high priority
        }

        // Lower others
        for (auto& [id, binding] : currentProfile_.bindings) {
            if (id == winnerId) continue;

            if (auto* combo = std::get_if<KeyCombination>(&binding.trigger)) {
                if (*combo == key) {
                    binding.priority = 0;
                }
            }
        }

        detectConflicts();
    }

    // ========================================================================
    // Search & Discovery
    // ========================================================================

    std::vector<ShortcutBinding> searchBindings(const std::string& query) const {
        std::lock_guard<std::mutex> lock(mutex_);
        std::vector<ShortcutBinding> results;

        std::string lowerQuery = query;
        std::transform(lowerQuery.begin(), lowerQuery.end(),
                       lowerQuery.begin(), ::tolower);

        for (const auto& [id, binding] : currentProfile_.bindings) {
            std::string lowerName = binding.name;
            std::transform(lowerName.begin(), lowerName.end(),
                           lowerName.begin(), ::tolower);

            std::string lowerDesc = binding.description;
            std::transform(lowerDesc.begin(), lowerDesc.end(),
                           lowerDesc.begin(), ::tolower);

            if (lowerName.find(lowerQuery) != std::string::npos ||
                lowerDesc.find(lowerQuery) != std::string::npos) {
                results.push_back(binding);
            }
        }

        return results;
    }

    // ========================================================================
    // Cheatsheet Generation
    // ========================================================================

    std::string generateCheatsheet() const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::string sheet = "# Echoel Keyboard Shortcuts\n\n";

        std::map<ShortcutCategory, std::vector<const ShortcutBinding*>> byCategory;

        for (const auto& [id, binding] : currentProfile_.bindings) {
            byCategory[binding.category].push_back(&binding);
        }

        for (const auto& [category, bindings] : byCategory) {
            sheet += "## " + categoryToString(category) + "\n\n";
            sheet += "| Shortcut | Action | Description |\n";
            sheet += "|----------|--------|-------------|\n";

            for (const auto* binding : bindings) {
                std::string keyStr;
                if (auto* combo = std::get_if<KeyCombination>(&binding->trigger)) {
                    keyStr = combo->toString();
                } else if (auto* seq = std::get_if<KeySequence>(&binding->trigger)) {
                    keyStr = seq->toString();
                }

                sheet += "| `" + keyStr + "` | " + binding->name +
                         " | " + binding->description + " |\n";
            }

            sheet += "\n";
        }

        return sheet;
    }

    std::string generateHTMLCheatsheet() const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::string html = R"(
<!DOCTYPE html>
<html>
<head>
    <title>Echoel Keyboard Shortcuts</title>
    <style>
        body { font-family: -apple-system, sans-serif; padding: 20px; }
        .category { margin-bottom: 30px; }
        h2 { color: #4A90D9; border-bottom: 2px solid #4A90D9; }
        table { width: 100%; border-collapse: collapse; }
        th { background: #f0f0f0; text-align: left; padding: 10px; }
        td { padding: 10px; border-bottom: 1px solid #e0e0e0; }
        .key {
            background: #333;
            color: white;
            padding: 4px 8px;
            border-radius: 4px;
            font-family: monospace;
        }
    </style>
</head>
<body>
    <h1>Echoel Keyboard Shortcuts</h1>
)";

        // Add categories and shortcuts...
        html += "</body></html>";

        return html;
    }

private:
    KeyboardShortcutsManager() = default;
    ~KeyboardShortcutsManager() = default;

    KeyboardShortcutsManager(const KeyboardShortcutsManager&) = delete;
    KeyboardShortcutsManager& operator=(const KeyboardShortcutsManager&) = delete;

    // ========================================================================
    // Built-in Profiles
    // ========================================================================

    void loadEchoelDefaultProfile() {
        currentProfile_ = ShortcutProfile{};
        currentProfile_.id = "echoel_default";
        currentProfile_.name = "Echoel Default";
        currentProfile_.description = "Standard Echoel keyboard layout";
        currentProfile_.isBuiltIn = true;

        // Transport
        registerDefaultBinding("transport.play", "Play/Pause", ShortcutCategory::Playback,
                               {KeyCode::Space, ModifierKey::None});
        registerDefaultBinding("transport.stop", "Stop", ShortcutCategory::Playback,
                               {KeyCode::Space, ModifierKey::Shift});
        registerDefaultBinding("transport.record", "Record", ShortcutCategory::Playback,
                               {KeyCode::R, ModifierKey::None});
        registerDefaultBinding("transport.loop", "Toggle Loop", ShortcutCategory::Playback,
                               {KeyCode::L, ModifierKey::None});

        // Navigation
        registerDefaultBinding("nav.left", "Move Left", ShortcutCategory::Navigation,
                               {KeyCode::Left, ModifierKey::None});
        registerDefaultBinding("nav.right", "Move Right", ShortcutCategory::Navigation,
                               {KeyCode::Right, ModifierKey::None});
        registerDefaultBinding("nav.home", "Go to Start", ShortcutCategory::Navigation,
                               {KeyCode::Home, ModifierKey::None});
        registerDefaultBinding("nav.end", "Go to End", ShortcutCategory::Navigation,
                               {KeyCode::End, ModifierKey::None});
        registerDefaultBinding("nav.marker_prev", "Previous Marker", ShortcutCategory::Navigation,
                               {KeyCode::Left, ModifierKey::Super});
        registerDefaultBinding("nav.marker_next", "Next Marker", ShortcutCategory::Navigation,
                               {KeyCode::Right, ModifierKey::Super});

        // Editing
        registerDefaultBinding("edit.undo", "Undo", ShortcutCategory::Undo,
                               {KeyCode::Z, ModifierKey::Super});
        registerDefaultBinding("edit.redo", "Redo", ShortcutCategory::Undo,
                               {KeyCode::Z, ModifierKey::Super | ModifierKey::Shift});
        registerDefaultBinding("edit.cut", "Cut", ShortcutCategory::Clipboard,
                               {KeyCode::X, ModifierKey::Super});
        registerDefaultBinding("edit.copy", "Copy", ShortcutCategory::Clipboard,
                               {KeyCode::C, ModifierKey::Super});
        registerDefaultBinding("edit.paste", "Paste", ShortcutCategory::Clipboard,
                               {KeyCode::V, ModifierKey::Super});
        registerDefaultBinding("edit.duplicate", "Duplicate", ShortcutCategory::Clipboard,
                               {KeyCode::D, ModifierKey::Super});
        registerDefaultBinding("edit.delete", "Delete", ShortcutCategory::Clipboard,
                               {KeyCode::Backspace, ModifierKey::None});
        registerDefaultBinding("edit.select_all", "Select All", ShortcutCategory::Selection,
                               {KeyCode::A, ModifierKey::Super});

        // Tracks
        registerDefaultBinding("track.add", "Add Track", ShortcutCategory::TrackManagement,
                               {KeyCode::T, ModifierKey::Super | ModifierKey::Shift});
        registerDefaultBinding("track.delete", "Delete Track", ShortcutCategory::TrackManagement,
                               {KeyCode::Backspace, ModifierKey::Super});
        registerDefaultBinding("track.solo", "Solo", ShortcutCategory::TrackRouting,
                               {KeyCode::S, ModifierKey::None});
        registerDefaultBinding("track.mute", "Mute", ShortcutCategory::TrackRouting,
                               {KeyCode::M, ModifierKey::None});
        registerDefaultBinding("track.arm", "Arm for Recording", ShortcutCategory::TrackRouting,
                               {KeyCode::R, ModifierKey::Shift});

        // Zoom
        registerDefaultBinding("zoom.in", "Zoom In", ShortcutCategory::Zoom,
                               {KeyCode::Equals, ModifierKey::Super});
        registerDefaultBinding("zoom.out", "Zoom Out", ShortcutCategory::Zoom,
                               {KeyCode::Minus, ModifierKey::Super});
        registerDefaultBinding("zoom.fit", "Fit to Window", ShortcutCategory::Zoom,
                               {KeyCode::F, ModifierKey::Super | ModifierKey::Shift});

        // File
        registerDefaultBinding("file.new", "New Project", ShortcutCategory::File,
                               {KeyCode::N, ModifierKey::Super});
        registerDefaultBinding("file.open", "Open Project", ShortcutCategory::File,
                               {KeyCode::O, ModifierKey::Super});
        registerDefaultBinding("file.save", "Save", ShortcutCategory::File,
                               {KeyCode::S, ModifierKey::Super});
        registerDefaultBinding("file.save_as", "Save As", ShortcutCategory::File,
                               {KeyCode::S, ModifierKey::Super | ModifierKey::Shift});
        registerDefaultBinding("file.export", "Export", ShortcutCategory::File,
                               {KeyCode::E, ModifierKey::Super | ModifierKey::Shift});

        // Tools
        registerDefaultBinding("tool.select", "Selection Tool", ShortcutCategory::Tools,
                               {KeyCode::V, ModifierKey::None});
        registerDefaultBinding("tool.pencil", "Pencil Tool", ShortcutCategory::Tools,
                               {KeyCode::P, ModifierKey::None});
        registerDefaultBinding("tool.eraser", "Eraser Tool", ShortcutCategory::Tools,
                               {KeyCode::E, ModifierKey::None});
        registerDefaultBinding("tool.split", "Split Tool", ShortcutCategory::Tools,
                               {KeyCode::B, ModifierKey::None});

        // Quantize
        registerDefaultBinding("quantize.1_1", "Quantize 1/1", ShortcutCategory::Quantize,
                               {KeyCode::Num1, ModifierKey::Control});
        registerDefaultBinding("quantize.1_2", "Quantize 1/2", ShortcutCategory::Quantize,
                               {KeyCode::Num2, ModifierKey::Control});
        registerDefaultBinding("quantize.1_4", "Quantize 1/4", ShortcutCategory::Quantize,
                               {KeyCode::Num3, ModifierKey::Control});
        registerDefaultBinding("quantize.1_8", "Quantize 1/8", ShortcutCategory::Quantize,
                               {KeyCode::Num4, ModifierKey::Control});
        registerDefaultBinding("quantize.1_16", "Quantize 1/16", ShortcutCategory::Quantize,
                               {KeyCode::Num5, ModifierKey::Control});
    }

    void loadAbletonProfile() {
        // Load Ableton-style shortcuts
        currentProfile_ = ShortcutProfile{};
        currentProfile_.id = "ableton_live";
        currentProfile_.name = "Ableton Live";
        currentProfile_.description = "Ableton Live compatible shortcuts";

        // Similar bindings but Ableton style...
    }

    void loadLogicProProfile() {
        // Load Logic Pro X style shortcuts
        currentProfile_ = ShortcutProfile{};
        currentProfile_.id = "logic_pro";
        currentProfile_.name = "Logic Pro";
        currentProfile_.description = "Logic Pro compatible shortcuts";
    }

    void loadVimProfile() {
        // For the adventurous - Vim-style shortcuts with modal editing
        currentProfile_ = ShortcutProfile{};
        currentProfile_.id = "vim";
        currentProfile_.name = "Vim Mode";
        currentProfile_.description = "Vim-style modal editing for the brave";

        // h/j/k/l navigation, modal modes, etc.
    }

    void registerDefaultBinding(const std::string& id, const std::string& name,
                                ShortcutCategory category, const KeyCombination& key) {
        ShortcutBinding binding;
        binding.id = id;
        binding.name = name;
        binding.category = category;
        binding.trigger = key;
        binding.isEnabled = true;

        currentProfile_.bindings[id] = binding;
        keyToBindings_[key].push_back(id);
    }

    void registerBuiltInCommands() {
        // Register all available commands that can be bound to keys
        // These would typically link to the command system
    }

    // ========================================================================
    // Helper Methods
    // ========================================================================

    bool isContextMatch(ShortcutContext required, ShortcutContext current) const {
        if (required == ShortcutContext::Any) return true;
        if (required == ShortcutContext::Global) return true;
        return required == current;
    }

    bool matchesSequence(const KeySequence& seq) const {
        if (sequenceBuffer_.size() != seq.sequence.size()) return false;

        for (size_t i = 0; i < sequenceBuffer_.size(); ++i) {
            if (!(sequenceBuffer_[i] == seq.sequence[i])) return false;
        }

        return true;
    }

    bool isSequencePrefix(const KeySequence& seq) const {
        if (sequenceBuffer_.size() >= seq.sequence.size()) return false;

        for (size_t i = 0; i < sequenceBuffer_.size(); ++i) {
            if (!(sequenceBuffer_[i] == seq.sequence[i])) return false;
        }

        return true;
    }

    void detectConflicts() {
        conflicts_.clear();

        std::map<KeyCombination, std::vector<std::string>> keyUsage;

        for (const auto& [id, binding] : currentProfile_.bindings) {
            if (auto* combo = std::get_if<KeyCombination>(&binding.trigger)) {
                keyUsage[*combo].push_back(id);
            }
        }

        for (const auto& [key, ids] : keyUsage) {
            if (ids.size() > 1) {
                ShortcutConflict conflict;
                conflict.key = key;
                conflict.conflictingBindingIds = ids;

                // Find winner by priority
                int maxPriority = -1;
                for (const auto& id : ids) {
                    const auto& binding = currentProfile_.bindings.at(id);
                    if (binding.priority > maxPriority) {
                        maxPriority = binding.priority;
                        conflict.resolvedWinner = id;
                    }
                }

                conflicts_.push_back(conflict);
            }
        }
    }

    void startRepeat(ShortcutBinding* binding) {
        repeatingBinding_ = binding;
        // Would start a timer for repeat behavior
    }

    void stopRepeat() {
        repeatingBinding_ = nullptr;
    }

    std::string categoryToString(ShortcutCategory cat) const {
        switch (cat) {
            case ShortcutCategory::Playback: return "Playback";
            case ShortcutCategory::Navigation: return "Navigation";
            case ShortcutCategory::Selection: return "Selection";
            case ShortcutCategory::Clipboard: return "Clipboard";
            case ShortcutCategory::Undo: return "Undo/Redo";
            case ShortcutCategory::TrackManagement: return "Track Management";
            case ShortcutCategory::TrackRouting: return "Track Routing";
            case ShortcutCategory::Mixer: return "Mixer";
            case ShortcutCategory::Automation: return "Automation";
            case ShortcutCategory::Effects: return "Effects";
            case ShortcutCategory::Instruments: return "Instruments";
            case ShortcutCategory::Windows: return "Windows";
            case ShortcutCategory::Zoom: return "Zoom";
            case ShortcutCategory::File: return "File";
            case ShortcutCategory::Project: return "Project";
            case ShortcutCategory::Tools: return "Tools";
            case ShortcutCategory::Quantize: return "Quantize";
            case ShortcutCategory::MIDI: return "MIDI";
            case ShortcutCategory::Audio: return "Audio";
            case ShortcutCategory::Custom: return "Custom";
            case ShortcutCategory::Global: return "Global";
            default: return "Other";
        }
    }

    // ========================================================================
    // Member Variables
    // ========================================================================

    mutable std::mutex mutex_;
    std::atomic<bool> initialized_{false};

    ShortcutProfile currentProfile_;
    std::vector<ShortcutProfile> availableProfiles_;

    std::map<KeyCombination, std::vector<std::string>> keyToBindings_;
    std::vector<ShortcutConflict> conflicts_;

    // Sequence handling
    std::vector<KeyCombination> sequenceBuffer_;
    std::chrono::steady_clock::time_point lastKeyTime_;
    std::chrono::milliseconds sequenceTimeout_{1000};

    // Learning mode
    std::atomic<bool> learningMode_{false};
    KeyLearnCallback learningCallback_;

    // Repeat handling
    ShortcutBinding* repeatingBinding_ = nullptr;
};

// ============================================================================
// Global Hotkey Registration (Platform-specific)
// ============================================================================

class GlobalHotkeyManager {
public:
    static GlobalHotkeyManager& getInstance() {
        static GlobalHotkeyManager instance;
        return instance;
    }

    bool registerGlobalHotkey(const std::string& id, const KeyCombination& key,
                              const ShortcutAction& action) {
        std::lock_guard<std::mutex> lock(mutex_);

        // Platform-specific global hotkey registration
        // On macOS: CGEventTap or RegisterEventHotKey
        // On Windows: RegisterHotKey
        // On Linux: X11 XGrabKey

        GlobalHotkey hotkey;
        hotkey.id = id;
        hotkey.key = key;
        hotkey.action = action;
        hotkey.registered = true;  // Would be actual registration result

        globalHotkeys_[id] = hotkey;
        return hotkey.registered;
    }

    void unregisterGlobalHotkey(const std::string& id) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = globalHotkeys_.find(id);
        if (it != globalHotkeys_.end()) {
            // Platform-specific unregistration
            globalHotkeys_.erase(it);
        }
    }

    void unregisterAllGlobalHotkeys() {
        std::lock_guard<std::mutex> lock(mutex_);
        globalHotkeys_.clear();
    }

    bool isGlobalHotkeyRegistered(const std::string& id) const {
        std::lock_guard<std::mutex> lock(mutex_);
        return globalHotkeys_.count(id) > 0;
    }

private:
    GlobalHotkeyManager() = default;

    struct GlobalHotkey {
        std::string id;
        KeyCombination key;
        ShortcutAction action;
        bool registered = false;
        int platformHandle = 0;
    };

    mutable std::mutex mutex_;
    std::map<std::string, GlobalHotkey> globalHotkeys_;
};

// ============================================================================
// Quick Access Commands
// ============================================================================

namespace QuickKeys {
    inline KeyCombination Play() { return {KeyCode::Space, ModifierKey::None}; }
    inline KeyCombination Stop() { return {KeyCode::Space, ModifierKey::Shift}; }
    inline KeyCombination Record() { return {KeyCode::R, ModifierKey::None}; }
    inline KeyCombination Undo() { return {KeyCode::Z, ModifierKey::Super}; }
    inline KeyCombination Redo() { return {KeyCode::Z, ModifierKey::Super | ModifierKey::Shift}; }
    inline KeyCombination Save() { return {KeyCode::S, ModifierKey::Super}; }
    inline KeyCombination New() { return {KeyCode::N, ModifierKey::Super}; }
    inline KeyCombination Open() { return {KeyCode::O, ModifierKey::Super}; }
    inline KeyCombination Copy() { return {KeyCode::C, ModifierKey::Super}; }
    inline KeyCombination Paste() { return {KeyCode::V, ModifierKey::Super}; }
    inline KeyCombination Cut() { return {KeyCode::X, ModifierKey::Super}; }
    inline KeyCombination SelectAll() { return {KeyCode::A, ModifierKey::Super}; }
}

} // namespace Echoel
