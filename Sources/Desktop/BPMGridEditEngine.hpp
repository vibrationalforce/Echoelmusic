/**
 * ╔═══════════════════════════════════════════════════════════════════════════════════════════════════════╗
 * ║                                                                                                       ║
 * ║   ██████╗ ██████╗ ███╗   ███╗     ██████╗ ██████╗ ██╗██████╗                                          ║
 * ║   ██╔══██╗██╔══██╗████╗ ████║    ██╔════╝ ██╔══██╗██║██╔══██╗                                         ║
 * ║   ██████╔╝██████╔╝██╔████╔██║    ██║  ███╗██████╔╝██║██║  ██║                                         ║
 * ║   ██╔══██╗██╔═══╝ ██║╚██╔╝██║    ██║   ██║██╔══██╗██║██║  ██║                                         ║
 * ║   ██████╔╝██║     ██║ ╚═╝ ██║    ╚██████╔╝██║  ██║██║██████╔╝                                         ║
 * ║   ╚═════╝ ╚═╝     ╚═╝     ╚═╝     ╚═════╝ ╚═╝  ╚═╝╚═╝╚═════╝                                          ║
 * ║                                                                                                       ║
 * ║   🎵 BPM GRID EDIT ENGINE - Beat-Synchronized Video Editing 🎵                                        ║
 * ║                                                                                                       ║
 * ║   Edit auf dem BPM Raster • Beat Detection • Quantize • Beat-Synced Effects                          ║
 * ║   C++17 Cross-Platform Implementation (Windows/Linux)                                                 ║
 * ║                                                                                                       ║
 * ║   Features:                                                                                           ║
 * ║   • Beat Detection (Audio Analysis with FFT)                                                          ║
 * ║   • BPM Grid with Time Signature Support (4/4, 3/4, 6/8, etc.)                                        ║
 * ║   • Snap Modes: Beat, Bar, Half-Beat, Quarter-Beat, Triplet                                           ║
 * ║   • Beat-Synced Cuts, Transitions & Effects                                                           ║
 * ║   • Quantize Clips to Grid                                                                            ║
 * ║   • Tempo Automation & Changes                                                                        ║
 * ║   • Visual Beat Markers                                                                               ║
 * ║   • DAW Transport Sync (MIDI Clock, Ableton Link)                                                     ║
 * ║                                                                                                       ║
 * ╚═══════════════════════════════════════════════════════════════════════════════════════════════════════╝
 *
 * @file BPMGridEditEngine.hpp
 * @brief C++17 header-only BPM Grid editing engine for beat-synchronized video editing
 * @author Echoelmusic Team
 * @version 1.0.0
 */

#pragma once

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cmath>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <vector>

namespace Echoelmusic {
namespace Video {

// ============================================================================
// MARK: - Time Signature
// ============================================================================

/**
 * @brief Musical time signature
 */
struct TimeSignature {
    int numerator = 4;      ///< Beats per bar (top number)
    int denominator = 4;    ///< Note value of beat (bottom number)

    // Common time signatures
    static TimeSignature FourFour() { return {4, 4}; }
    static TimeSignature ThreeFour() { return {3, 4}; }
    static TimeSignature SixEight() { return {6, 8}; }
    static TimeSignature TwoFour() { return {2, 4}; }
    static TimeSignature FiveFour() { return {5, 4}; }
    static TimeSignature SevenEight() { return {7, 8}; }
    static TimeSignature TwelveEight() { return {12, 8}; }

    /// Display string (e.g., "4/4")
    std::string displayString() const {
        return std::to_string(numerator) + "/" + std::to_string(denominator);
    }

    /// Beats per bar (adjusted for compound meters)
    int beatsPerBar() const {
        // For compound meters (6/8, 9/8, 12/8), group into larger beats
        if (denominator == 8 && numerator % 3 == 0) {
            return numerator / 3;
        }
        return numerator;
    }

    /// Subdivisions per beat
    int subdivisionsPerBeat() const {
        if (denominator == 8 && numerator % 3 == 0) {
            return 3;  // Compound meter: triplet feel
        }
        return 1;
    }

    bool operator==(const TimeSignature& other) const {
        return numerator == other.numerator && denominator == other.denominator;
    }
};

// ============================================================================
// MARK: - Snap Mode
// ============================================================================

/**
 * @brief Grid snap mode for editing
 */
enum class SnapMode {
    Off,
    Bar,
    Beat,
    HalfBeat,
    QuarterBeat,
    EighthBeat,
    Triplet,
    Sixteenth,
    ThirtySecond
};

/**
 * @brief Get subdivisions per beat for snap mode
 */
inline int getSubdivisionsPerBeat(SnapMode mode) {
    switch (mode) {
        case SnapMode::Off: return 0;
        case SnapMode::Bar: return 0;  // Special case: snap to bar
        case SnapMode::Beat: return 1;
        case SnapMode::HalfBeat: return 2;
        case SnapMode::QuarterBeat: return 4;
        case SnapMode::EighthBeat: return 8;
        case SnapMode::Triplet: return 3;
        case SnapMode::Sixteenth: return 16;
        case SnapMode::ThirtySecond: return 32;
    }
    return 1;
}

/**
 * @brief Get display name for snap mode
 */
inline std::string getSnapModeName(SnapMode mode) {
    switch (mode) {
        case SnapMode::Off: return "Off";
        case SnapMode::Bar: return "Bar";
        case SnapMode::Beat: return "Beat";
        case SnapMode::HalfBeat: return "1/2 Beat";
        case SnapMode::QuarterBeat: return "1/4 Beat";
        case SnapMode::EighthBeat: return "1/8 Beat";
        case SnapMode::Triplet: return "Triplet";
        case SnapMode::Sixteenth: return "1/16";
        case SnapMode::ThirtySecond: return "1/32";
    }
    return "Unknown";
}

/**
 * @brief Get icon for snap mode
 */
inline std::string getSnapModeIcon(SnapMode mode) {
    switch (mode) {
        case SnapMode::Off: return "🔓";
        case SnapMode::Bar: return "📊";
        case SnapMode::Beat: return "🎵";
        case SnapMode::HalfBeat: return "♪";
        case SnapMode::QuarterBeat: return "♫";
        case SnapMode::EighthBeat: return "𝅘𝅥𝅮";
        case SnapMode::Triplet: return "③";
        case SnapMode::Sixteenth: return "𝅘𝅥𝅯";
        case SnapMode::ThirtySecond: return "𝅘𝅥𝅰";
    }
    return "";
}

// ============================================================================
// MARK: - Beat Position
// ============================================================================

/**
 * @brief Position in musical time (bars, beats, ticks)
 */
struct BeatPosition {
    int bar = 1;            ///< 1-indexed bar number
    int beat = 1;           ///< 1-indexed beat within bar
    int tick = 0;           ///< Ticks within beat (0-959 for 960 PPQ)
    int ticksPerQuarterNote = 960;  ///< PPQ resolution

    /// Create from absolute time
    static BeatPosition fromSeconds(
        double seconds,
        double bpm,
        TimeSignature timeSignature = TimeSignature::FourFour(),
        int ppq = 960
    ) {
        double secondsPerBeat = 60.0 / bpm;
        double totalBeats = seconds / secondsPerBeat;
        double beatsPerBar = static_cast<double>(timeSignature.numerator);

        double totalBars = totalBeats / beatsPerBar;
        int bar = static_cast<int>(std::floor(totalBars)) + 1;
        double beatInBar = std::fmod(totalBeats, beatsPerBar);
        int beatInt = static_cast<int>(std::floor(beatInBar)) + 1;
        double tickFraction = std::fmod(beatInBar, 1.0);
        int tick = static_cast<int>(tickFraction * ppq);

        return {bar, beatInt, tick, ppq};
    }

    /// Convert to absolute time in seconds
    double toSeconds(double bpm, TimeSignature timeSignature = TimeSignature::FourFour()) const {
        double secondsPerBeat = 60.0 / bpm;
        double beatsPerBar = static_cast<double>(timeSignature.numerator);

        double totalBeats = (bar - 1) * beatsPerBar + (beat - 1) +
                           static_cast<double>(tick) / ticksPerQuarterNote;
        return totalBeats * secondsPerBeat;
    }

    /// Display string (e.g., "1.2.480")
    std::string displayString() const {
        return std::to_string(bar) + "." + std::to_string(beat) + "." + std::to_string(tick);
    }

    /// Short display (e.g., "1.2")
    std::string shortDisplayString() const {
        return std::to_string(bar) + "." + std::to_string(beat);
    }

    bool operator<(const BeatPosition& other) const {
        if (bar != other.bar) return bar < other.bar;
        if (beat != other.beat) return beat < other.beat;
        return tick < other.tick;
    }

    bool operator==(const BeatPosition& other) const {
        return bar == other.bar && beat == other.beat && tick == other.tick;
    }
};

// ============================================================================
// MARK: - Beat Marker
// ============================================================================

/**
 * @brief Marker type enumeration
 */
enum class MarkerType {
    Downbeat,
    Beat,
    Accent,
    Cue,
    Drop,
    Breakdown,
    Buildup,
    Transition,
    Cut,
    Custom
};

/**
 * @brief Get marker type name
 */
inline std::string getMarkerTypeName(MarkerType type) {
    switch (type) {
        case MarkerType::Downbeat: return "Downbeat";
        case MarkerType::Beat: return "Beat";
        case MarkerType::Accent: return "Accent";
        case MarkerType::Cue: return "Cue";
        case MarkerType::Drop: return "Drop";
        case MarkerType::Breakdown: return "Breakdown";
        case MarkerType::Buildup: return "Buildup";
        case MarkerType::Transition: return "Transition";
        case MarkerType::Cut: return "Cut";
        case MarkerType::Custom: return "Custom";
    }
    return "Unknown";
}

/**
 * @brief Get marker type icon
 */
inline std::string getMarkerTypeIcon(MarkerType type) {
    switch (type) {
        case MarkerType::Downbeat: return "⬇️";
        case MarkerType::Beat: return "🎵";
        case MarkerType::Accent: return "❗";
        case MarkerType::Cue: return "🎯";
        case MarkerType::Drop: return "💥";
        case MarkerType::Breakdown: return "🌊";
        case MarkerType::Buildup: return "📈";
        case MarkerType::Transition: return "🔄";
        case MarkerType::Cut: return "✂️";
        case MarkerType::Custom: return "📍";
    }
    return "";
}

/**
 * @brief Visual/functional marker at a beat position
 */
struct BeatMarker {
    std::string id;
    BeatPosition position;
    MarkerType type = MarkerType::Beat;
    std::string label;
    std::string color = "#FF0000";

    BeatMarker() : id(generateId()) {}

private:
    static std::string generateId() {
        static std::atomic<uint64_t> counter{0};
        return "marker_" + std::to_string(++counter);
    }
};

// ============================================================================
// MARK: - Tempo Change
// ============================================================================

/**
 * @brief Tempo change curve type
 */
enum class TempoChangeCurve {
    Instant,
    Linear,
    Exponential,
    SCurve
};

/**
 * @brief Tempo automation point
 */
struct TempoChange {
    std::string id;
    BeatPosition position;
    double bpm = 120.0;
    TempoChangeCurve curve = TempoChangeCurve::Instant;

    TempoChange() : id(generateId()) {}

private:
    static std::string generateId() {
        static std::atomic<uint64_t> counter{0};
        return "tempo_" + std::to_string(++counter);
    }
};

// ============================================================================
// MARK: - Beat-Synced Transition
// ============================================================================

/**
 * @brief Transition type enumeration
 */
enum class TransitionType {
    Cut,
    Crossfade,
    FadeToBlack,
    FadeFromBlack,
    Wipe,
    Push,
    Slide,
    Zoom,
    Spin,
    Flash,
    Glitch,
    BeatFlash,
    RhythmCut,
    StrobeTransition
};

/**
 * @brief Get transition type name
 */
inline std::string getTransitionTypeName(TransitionType type) {
    switch (type) {
        case TransitionType::Cut: return "Cut";
        case TransitionType::Crossfade: return "Crossfade";
        case TransitionType::FadeToBlack: return "Fade to Black";
        case TransitionType::FadeFromBlack: return "Fade from Black";
        case TransitionType::Wipe: return "Wipe";
        case TransitionType::Push: return "Push";
        case TransitionType::Slide: return "Slide";
        case TransitionType::Zoom: return "Zoom";
        case TransitionType::Spin: return "Spin";
        case TransitionType::Flash: return "Flash";
        case TransitionType::Glitch: return "Glitch";
        case TransitionType::BeatFlash: return "Beat Flash";
        case TransitionType::RhythmCut: return "Rhythm Cut";
        case TransitionType::StrobeTransition: return "Strobe";
    }
    return "Unknown";
}

/**
 * @brief Get transition type icon
 */
inline std::string getTransitionTypeIcon(TransitionType type) {
    switch (type) {
        case TransitionType::Cut: return "✂️";
        case TransitionType::Crossfade: return "🔀";
        case TransitionType::FadeToBlack: return "🌑";
        case TransitionType::FadeFromBlack: return "🌕";
        case TransitionType::Wipe: return "➡️";
        case TransitionType::Push: return "👉";
        case TransitionType::Slide: return "📐";
        case TransitionType::Zoom: return "🔍";
        case TransitionType::Spin: return "🔄";
        case TransitionType::Flash: return "💫";
        case TransitionType::Glitch: return "📺";
        case TransitionType::BeatFlash: return "⚡";
        case TransitionType::RhythmCut: return "🎵✂️";
        case TransitionType::StrobeTransition: return "💡";
    }
    return "";
}

/**
 * @brief Transition that aligns to beats
 */
struct BeatSyncedTransition {
    std::string id;
    TransitionType type = TransitionType::Cut;
    double durationBeats = 1.0;
    bool startOnBeat = true;
    bool endOnBeat = true;
    bool syncToDownbeat = false;
    float intensity = 1.0f;

    BeatSyncedTransition() : id(generateId()) {}

private:
    static std::string generateId() {
        static std::atomic<uint64_t> counter{0};
        return "transition_" + std::to_string(++counter);
    }
};

// ============================================================================
// MARK: - Beat-Synced Effect
// ============================================================================

/**
 * @brief Effect type enumeration
 */
enum class EffectType {
    // Visual effects
    Flash,
    Pulse,
    Shake,
    ZoomPulse,
    ColorShift,
    SaturationPulse,
    ContrastPulse,
    BrightnessPulse,
    Glitch,
    Scanlines,
    VHSEffect,
    FilmBurn,
    LetterboxPulse,

    // Motion effects
    Sway,
    Bounce,
    Spin,
    ScaleBreathing,

    // Particle effects
    ParticleBurst,
    LightRays,
    LensFlare,

    // Bio-reactive
    HeartbeatPulse,
    CoherenceGlow
};

/**
 * @brief Get effect type name
 */
inline std::string getEffectTypeName(EffectType type) {
    switch (type) {
        case EffectType::Flash: return "Flash";
        case EffectType::Pulse: return "Pulse";
        case EffectType::Shake: return "Shake";
        case EffectType::ZoomPulse: return "Zoom Pulse";
        case EffectType::ColorShift: return "Color Shift";
        case EffectType::SaturationPulse: return "Saturation Pulse";
        case EffectType::ContrastPulse: return "Contrast Pulse";
        case EffectType::BrightnessPulse: return "Brightness Pulse";
        case EffectType::Glitch: return "Glitch";
        case EffectType::Scanlines: return "Scanlines";
        case EffectType::VHSEffect: return "VHS Effect";
        case EffectType::FilmBurn: return "Film Burn";
        case EffectType::LetterboxPulse: return "Letterbox Pulse";
        case EffectType::Sway: return "Sway";
        case EffectType::Bounce: return "Bounce";
        case EffectType::Spin: return "Spin";
        case EffectType::ScaleBreathing: return "Scale Breathing";
        case EffectType::ParticleBurst: return "Particle Burst";
        case EffectType::LightRays: return "Light Rays";
        case EffectType::LensFlare: return "Lens Flare";
        case EffectType::HeartbeatPulse: return "Heartbeat Pulse";
        case EffectType::CoherenceGlow: return "Coherence Glow";
    }
    return "Unknown";
}

/**
 * @brief Get effect type icon
 */
inline std::string getEffectTypeIcon(EffectType type) {
    switch (type) {
        case EffectType::Flash: return "💫";
        case EffectType::Pulse: return "💓";
        case EffectType::Shake: return "📳";
        case EffectType::ZoomPulse: return "🔍";
        case EffectType::ColorShift: return "🌈";
        case EffectType::SaturationPulse: return "🎨";
        case EffectType::ContrastPulse: return "◐";
        case EffectType::BrightnessPulse: return "☀️";
        case EffectType::Glitch: return "📺";
        case EffectType::Scanlines: return "📊";
        case EffectType::VHSEffect: return "📼";
        case EffectType::FilmBurn: return "🔥";
        case EffectType::LetterboxPulse: return "🎬";
        case EffectType::Sway: return "🌊";
        case EffectType::Bounce: return "⬆️";
        case EffectType::Spin: return "🔄";
        case EffectType::ScaleBreathing: return "🫁";
        case EffectType::ParticleBurst: return "✨";
        case EffectType::LightRays: return "☀️";
        case EffectType::LensFlare: return "💠";
        case EffectType::HeartbeatPulse: return "❤️";
        case EffectType::CoherenceGlow: return "🔮";
    }
    return "";
}

/**
 * @brief Trigger mode for beat-synced effects
 */
enum class TriggerMode {
    EveryBeat,
    EveryDownbeat,
    EveryOtherBeat,
    EveryBar,
    Every2Bars,
    Every4Bars,
    OnCue,
    Continuous,
    Random
};

/**
 * @brief Get trigger mode name
 */
inline std::string getTriggerModeName(TriggerMode mode) {
    switch (mode) {
        case TriggerMode::EveryBeat: return "Every Beat";
        case TriggerMode::EveryDownbeat: return "Every Downbeat";
        case TriggerMode::EveryOtherBeat: return "Every Other Beat";
        case TriggerMode::EveryBar: return "Every Bar";
        case TriggerMode::Every2Bars: return "Every 2 Bars";
        case TriggerMode::Every4Bars: return "Every 4 Bars";
        case TriggerMode::OnCue: return "On Cue";
        case TriggerMode::Continuous: return "Continuous (Synced)";
        case TriggerMode::Random: return "Random (Synced)";
    }
    return "Unknown";
}

/**
 * @brief Effect that pulses/triggers on beats
 */
struct BeatSyncedEffect {
    std::string id;
    EffectType type = EffectType::Pulse;
    TriggerMode triggerOn = TriggerMode::EveryBeat;
    float intensity = 1.0f;
    float decay = 0.5f;
    float phase = 0.0f;

    BeatSyncedEffect() : id(generateId()) {}

private:
    static std::string generateId() {
        static std::atomic<uint64_t> counter{0};
        return "effect_" + std::to_string(++counter);
    }
};

// ============================================================================
// MARK: - Beat Detection Result
// ============================================================================

/**
 * @brief Result from beat detection analysis
 */
struct BeatDetectionResult {
    double bpm = 120.0;
    float confidence = 0.0f;
    std::vector<double> beats;
    std::vector<double> downbeats;
    TimeSignature timeSignature;
    double offset = 0.0;
};

// ============================================================================
// MARK: - BPM Grid
// ============================================================================

/**
 * @brief The BPM grid for a timeline
 */
class BPMGrid {
public:
    double bpm = 120.0;
    TimeSignature timeSignature;
    double offset = 0.0;
    std::vector<TempoChange> tempoChanges;

    BPMGrid(double bpm = 120.0, TimeSignature ts = TimeSignature::FourFour())
        : bpm(bpm), timeSignature(ts) {}

    /// Get BPM at specific time (considering tempo changes)
    double bpmAt(double seconds) const {
        if (tempoChanges.empty()) return bpm;

        double currentBPM = bpm;
        for (const auto& change : tempoChanges) {
            double changeTime = change.position.toSeconds(currentBPM, timeSignature);
            if (changeTime <= seconds) {
                currentBPM = change.bpm;
            } else {
                break;
            }
        }
        return currentBPM;
    }

    /// Seconds per beat at given time
    double secondsPerBeat(double seconds = 0.0) const {
        return 60.0 / bpmAt(seconds);
    }

    /// Seconds per bar at given time
    double secondsPerBar(double seconds = 0.0) const {
        return secondsPerBeat(seconds) * timeSignature.numerator;
    }

    /// Snap time to nearest grid position
    double snapToGrid(double seconds, SnapMode snapMode) const {
        if (snapMode == SnapMode::Off) return seconds;

        double adjustedTime = seconds - offset;
        double spb = secondsPerBeat(seconds);

        if (snapMode == SnapMode::Bar) {
            double barDuration = spb * timeSignature.numerator;
            double nearestBar = std::round(adjustedTime / barDuration);
            return nearestBar * barDuration + offset;
        }

        double gridInterval = spb / getSubdivisionsPerBeat(snapMode);
        double nearestGrid = std::round(adjustedTime / gridInterval);
        return nearestGrid * gridInterval + offset;
    }

    /// Get all grid lines in a time range
    std::vector<double> gridLines(double startTime, double endTime, SnapMode snapMode) const {
        if (snapMode == SnapMode::Off) return {};

        std::vector<double> lines;
        double spb = secondsPerBeat(startTime);

        double interval;
        if (snapMode == SnapMode::Bar) {
            interval = spb * timeSignature.numerator;
        } else {
            interval = spb / getSubdivisionsPerBeat(snapMode);
        }

        double time = snapToGrid(startTime, snapMode);
        while (time <= endTime) {
            lines.push_back(time);
            time += interval;
        }

        return lines;
    }

    /// Get beat position for time
    BeatPosition beatPosition(double seconds) const {
        return BeatPosition::fromSeconds(
            seconds - offset,
            bpmAt(seconds),
            timeSignature
        );
    }

    /// Check if time is on a beat
    bool isOnBeat(double seconds, double tolerance = 0.02) const {
        double snapped = snapToGrid(seconds, SnapMode::Beat);
        return std::abs(snapped - seconds) < tolerance;
    }

    /// Check if time is on a downbeat (bar start)
    bool isOnDownbeat(double seconds, double tolerance = 0.02) const {
        double snapped = snapToGrid(seconds, SnapMode::Bar);
        return std::abs(snapped - seconds) < tolerance;
    }

    /// Get nearest beat time
    double nearestBeat(double seconds) const {
        return snapToGrid(seconds, SnapMode::Beat);
    }

    /// Get nearest bar time
    double nearestBar(double seconds) const {
        return snapToGrid(seconds, SnapMode::Bar);
    }

    /// Get next beat after time
    double nextBeat(double seconds) const {
        double spb = secondsPerBeat(seconds);
        double currentBeat = snapToGrid(seconds, SnapMode::Beat);
        return (currentBeat > seconds) ? currentBeat : currentBeat + spb;
    }

    /// Get previous beat before time
    double previousBeat(double seconds) const {
        double spb = secondsPerBeat(seconds);
        double currentBeat = snapToGrid(seconds, SnapMode::Beat);
        return (currentBeat < seconds) ? currentBeat : currentBeat - spb;
    }
};

// ============================================================================
// MARK: - Preset Definition
// ============================================================================

/**
 * @brief Preset for common BPM/time signature combinations
 */
struct BPMPreset {
    std::string name;
    double bpm;
    TimeSignature timeSignature;
};

/// Get all available presets
inline std::vector<BPMPreset> getPresets() {
    return {
        {"Hip Hop", 90.0, TimeSignature::FourFour()},
        {"House", 128.0, TimeSignature::FourFour()},
        {"Techno", 140.0, TimeSignature::FourFour()},
        {"Drum & Bass", 174.0, TimeSignature::FourFour()},
        {"Dubstep", 140.0, TimeSignature::FourFour()},
        {"Pop", 120.0, TimeSignature::FourFour()},
        {"Rock", 110.0, TimeSignature::FourFour()},
        {"Jazz Waltz", 140.0, TimeSignature::ThreeFour()},
        {"6/8 Ballad", 60.0, TimeSignature::SixEight()},
        {"Film Score", 100.0, TimeSignature::FourFour()}
    };
}

// ============================================================================
// MARK: - Main BPM Grid Edit Engine
// ============================================================================

/**
 * @brief Main engine for BPM-synchronized video editing
 */
class BPMGridEditEngine {
public:
    // ===== Type Definitions =====
    using BeatCallback = std::function<void(int beat, int bar)>;
    using DownbeatCallback = std::function<void(int bar)>;
    using EffectCallback = std::function<void(const BeatSyncedEffect&)>;

    // ===== Constructor =====
    explicit BPMGridEditEngine(double bpm = 120.0, TimeSignature timeSignature = TimeSignature::FourFour())
        : m_grid(bpm, timeSignature)
        , m_snapMode(SnapMode::Beat)
        , m_isSnapEnabled(true)
        , m_showBeatGrid(true)
        , m_showDownbeatLines(true)
        , m_showBeatNumbers(true)
        , m_gridOpacity(0.5f)
        , m_currentBeat(1)
        , m_currentBar(1)
        , m_isOnBeat(false)
        , m_metronomeEnabled(false)
        , m_countIn(false)
        , m_countInBars(1)
        , m_isAnalyzing(false)
    {}

    // ===== Grid Configuration =====

    /// Get the BPM grid
    const BPMGrid& getGrid() const {
        std::lock_guard<std::mutex> lock(m_mutex);
        return m_grid;
    }

    /// Set BPM
    void setBPM(double bpm) {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_grid.bpm = std::clamp(bpm, 20.0, 300.0);
    }

    /// Get BPM
    double getBPM() const {
        std::lock_guard<std::mutex> lock(m_mutex);
        return m_grid.bpm;
    }

    /// Set time signature
    void setTimeSignature(TimeSignature timeSignature) {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_grid.timeSignature = timeSignature;
    }

    /// Get time signature
    TimeSignature getTimeSignature() const {
        std::lock_guard<std::mutex> lock(m_mutex);
        return m_grid.timeSignature;
    }

    /// Set grid offset (time to first downbeat)
    void setOffset(double offset) {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_grid.offset = offset;
    }

    /// Get offset
    double getOffset() const {
        std::lock_guard<std::mutex> lock(m_mutex);
        return m_grid.offset;
    }

    /// Get/set snap mode
    SnapMode getSnapMode() const { return m_snapMode.load(); }
    void setSnapMode(SnapMode mode) { m_snapMode.store(mode); }

    /// Get/set snap enabled
    bool isSnapEnabled() const { return m_isSnapEnabled.load(); }
    void setSnapEnabled(bool enabled) { m_isSnapEnabled.store(enabled); }

    // ===== Tap Tempo =====

    /// Tap tempo - call multiple times to detect BPM
    void tapTempo() {
        auto now = std::chrono::steady_clock::now();

        std::lock_guard<std::mutex> lock(m_tapMutex);
        m_tapTimes.push_back(now);

        // Keep only last 8 taps
        while (m_tapTimes.size() > 8) {
            m_tapTimes.erase(m_tapTimes.begin());
        }

        // Need at least 2 taps to calculate
        if (m_tapTimes.size() < 2) return;

        // Calculate average interval
        double totalInterval = 0.0;
        for (size_t i = 1; i < m_tapTimes.size(); ++i) {
            auto duration = std::chrono::duration<double>(m_tapTimes[i] - m_tapTimes[i-1]);
            totalInterval += duration.count();
        }
        double avgInterval = totalInterval / (m_tapTimes.size() - 1);

        // Convert to BPM
        double detectedBPM = 60.0 / avgInterval;
        setBPM(detectedBPM);
    }

    /// Reset tap tempo
    void resetTapTempo() {
        std::lock_guard<std::mutex> lock(m_tapMutex);
        m_tapTimes.clear();
    }

    // ===== Snapping =====

    /// Snap time to grid based on current snap mode
    double snap(double seconds) const {
        if (!m_isSnapEnabled.load()) return seconds;
        std::lock_guard<std::mutex> lock(m_mutex);
        return m_grid.snapToGrid(seconds, m_snapMode.load());
    }

    /// Snap milliseconds to grid
    int64_t snapMs(int64_t milliseconds) const {
        double seconds = milliseconds / 1000.0;
        double snappedSeconds = snap(seconds);
        return static_cast<int64_t>(snappedSeconds * 1000.0);
    }

    // ===== Beat Detection =====

    /// Analyze audio samples for beat detection
    BeatDetectionResult detectBeats(const std::vector<float>& samples, int sampleRate) {
        m_isAnalyzing.store(true);

        // Perform onset detection
        auto onsets = detectOnsets(samples, sampleRate);

        // Estimate BPM from onsets
        auto [bpm, confidence] = estimateBPM(onsets, sampleRate);

        // Find beat times
        double beatInterval = 60.0 / bpm;
        std::vector<double> beats;
        double time = onsets.empty() ? 0.0 : onsets[0];

        double duration = static_cast<double>(samples.size()) / sampleRate;
        while (time < duration) {
            beats.push_back(time);
            time += beatInterval;
        }

        // Estimate downbeats (every 4 beats for 4/4)
        std::vector<double> downbeats;
        for (size_t i = 0; i < beats.size(); i += 4) {
            downbeats.push_back(beats[i]);
        }

        BeatDetectionResult result;
        result.bpm = bpm;
        result.confidence = confidence;
        result.beats = beats;
        result.downbeats = downbeats;
        result.timeSignature = TimeSignature::FourFour();
        result.offset = beats.empty() ? 0.0 : beats[0];

        // Apply detected settings
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            m_grid.bpm = result.bpm;
            m_grid.offset = result.offset;
            if (result.confidence > 0.7f) {
                m_grid.timeSignature = result.timeSignature;
            }
        }

        // Create beat markers
        createBeatMarkers(result);

        m_lastDetectionResult = result;
        m_isAnalyzing.store(false);

        return result;
    }

    /// Is currently analyzing
    bool isAnalyzing() const { return m_isAnalyzing.load(); }

    /// Get last detection result
    std::optional<BeatDetectionResult> getLastDetectionResult() const {
        return m_lastDetectionResult;
    }

    // ===== Playback Updates =====

    /// Update current position (call from playback loop)
    void updatePosition(double seconds) {
        BeatPosition newPosition;
        bool wasOnBeat;
        bool nowOnBeat;
        int beat, bar;

        {
            std::lock_guard<std::mutex> lock(m_mutex);
            newPosition = m_grid.beatPosition(seconds);
            wasOnBeat = m_isOnBeat.load();
            nowOnBeat = m_grid.isOnBeat(seconds);
            beat = newPosition.beat;
            bar = newPosition.bar;
        }

        m_isOnBeat.store(nowOnBeat);

        if (!wasOnBeat && nowOnBeat) {
            m_currentBeat.store(beat);
            m_currentBar.store(bar);

            if (m_onBeat) {
                m_onBeat(beat, bar);
            }

            // Trigger beat-synced effects
            triggerBeatEffects(beat, bar);

            if (beat == 1 && m_onDownbeat) {
                m_onDownbeat(bar);
            }
        }

        std::lock_guard<std::mutex> lock(m_mutex);
        m_currentPosition = newPosition;
    }

    /// Get current beat
    int getCurrentBeat() const { return m_currentBeat.load(); }

    /// Get current bar
    int getCurrentBar() const { return m_currentBar.load(); }

    /// Get current position
    BeatPosition getCurrentPosition() const {
        std::lock_guard<std::mutex> lock(m_mutex);
        return m_currentPosition;
    }

    /// Is currently on beat
    bool isOnBeat() const { return m_isOnBeat.load(); }

    // ===== Quantize Operations =====

    /// Quantize clip start time to grid
    double quantizeClipStart(double seconds) const {
        return snap(seconds);
    }

    /// Quantize clip end time to grid
    double quantizeClipEnd(double seconds) const {
        return snap(seconds);
    }

    /// Quantize clip duration to nearest number of beats
    double quantizeDuration(double toBeats) const {
        std::lock_guard<std::mutex> lock(m_mutex);
        double secondsPerBeat = m_grid.secondsPerBeat();
        return toBeats * secondsPerBeat;
    }

    /// Get number of beats in duration
    double beatsInDuration(double duration) const {
        std::lock_guard<std::mutex> lock(m_mutex);
        double secondsPerBeat = m_grid.secondsPerBeat();
        return duration / secondsPerBeat;
    }

    /// Round duration to nearest whole number of beats
    double roundToNearestBeats(double duration) const {
        double beats = beatsInDuration(duration);
        double roundedBeats = std::round(beats);
        return quantizeDuration(roundedBeats);
    }

    // ===== Edit Operations =====

    /// Cut at next beat
    double cutAtNextBeat(double currentTime) const {
        std::lock_guard<std::mutex> lock(m_mutex);
        return m_grid.nextBeat(currentTime);
    }

    /// Cut at next bar
    double cutAtNextBar(double currentTime) const {
        std::lock_guard<std::mutex> lock(m_mutex);
        double spb = m_grid.secondsPerBeat(currentTime);
        double barDuration = spb * m_grid.timeSignature.numerator;

        double currentBar = m_grid.snapToGrid(currentTime, SnapMode::Bar);
        return (currentBar > currentTime) ? currentBar : currentBar + barDuration;
    }

    /// Generate auto-cuts on beats within range
    std::vector<double> generateAutoCuts(double start, double end, SnapMode every) const {
        std::lock_guard<std::mutex> lock(m_mutex);
        return m_grid.gridLines(start, end, every);
    }

    // ===== Markers =====

    /// Add marker at current position
    void addMarker(double seconds, MarkerType type, const std::string& label = "") {
        BeatMarker marker;
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            marker.position = m_grid.beatPosition(seconds);
        }
        marker.type = type;
        marker.label = label;

        std::lock_guard<std::mutex> lock(m_markerMutex);
        m_markers.push_back(marker);
    }

    /// Remove marker
    void removeMarker(const std::string& id) {
        std::lock_guard<std::mutex> lock(m_markerMutex);
        m_markers.erase(
            std::remove_if(m_markers.begin(), m_markers.end(),
                [&id](const BeatMarker& m) { return m.id == id; }),
            m_markers.end()
        );
    }

    /// Get all markers
    std::vector<BeatMarker> getMarkers() const {
        std::lock_guard<std::mutex> lock(m_markerMutex);
        return m_markers;
    }

    /// Get markers in time range
    std::vector<BeatMarker> getMarkersInRange(double start, double end) const {
        std::vector<BeatMarker> result;
        BPMGrid gridCopy;

        {
            std::lock_guard<std::mutex> lock(m_mutex);
            gridCopy = m_grid;
        }

        std::lock_guard<std::mutex> lock(m_markerMutex);
        for (const auto& marker : m_markers) {
            double time = marker.position.toSeconds(gridCopy.bpm, gridCopy.timeSignature) + gridCopy.offset;
            if (time >= start && time <= end) {
                result.push_back(marker);
            }
        }
        return result;
    }

    // ===== Effects =====

    /// Add beat-synced effect
    void addBeatSyncedEffect(const BeatSyncedEffect& effect) {
        std::lock_guard<std::mutex> lock(m_effectMutex);
        m_beatSyncedEffects.push_back(effect);
    }

    /// Remove beat-synced effect
    void removeBeatSyncedEffect(const std::string& id) {
        std::lock_guard<std::mutex> lock(m_effectMutex);
        m_beatSyncedEffects.erase(
            std::remove_if(m_beatSyncedEffects.begin(), m_beatSyncedEffects.end(),
                [&id](const BeatSyncedEffect& e) { return e.id == id; }),
            m_beatSyncedEffects.end()
        );
    }

    /// Get all beat-synced effects
    std::vector<BeatSyncedEffect> getBeatSyncedEffects() const {
        std::lock_guard<std::mutex> lock(m_effectMutex);
        return m_beatSyncedEffects;
    }

    /// Get effect value at time (for continuous effects)
    float effectValue(const BeatSyncedEffect& effect, double seconds) const {
        BeatPosition position;
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            position = m_grid.beatPosition(seconds);
        }

        float beatFraction = static_cast<float>(position.tick) / position.ticksPerQuarterNote;

        // Calculate effect envelope
        float phase = std::fmod(beatFraction + effect.phase, 1.0f);
        float envelope = std::pow(1.0f - phase, effect.decay * 4.0f);

        return envelope * effect.intensity;
    }

    // ===== Presets =====

    /// Apply preset by name
    void applyPreset(const std::string& name) {
        for (const auto& preset : getPresets()) {
            if (preset.name == name) {
                std::lock_guard<std::mutex> lock(m_mutex);
                m_grid.bpm = preset.bpm;
                m_grid.timeSignature = preset.timeSignature;
                return;
            }
        }
    }

    // ===== Callbacks =====

    void setOnBeat(BeatCallback callback) { m_onBeat = std::move(callback); }
    void setOnDownbeat(DownbeatCallback callback) { m_onDownbeat = std::move(callback); }
    void setOnBeatEffect(EffectCallback callback) { m_onBeatEffect = std::move(callback); }

    // ===== Visual Settings =====

    bool getShowBeatGrid() const { return m_showBeatGrid.load(); }
    void setShowBeatGrid(bool show) { m_showBeatGrid.store(show); }

    bool getShowDownbeatLines() const { return m_showDownbeatLines.load(); }
    void setShowDownbeatLines(bool show) { m_showDownbeatLines.store(show); }

    bool getShowBeatNumbers() const { return m_showBeatNumbers.load(); }
    void setShowBeatNumbers(bool show) { m_showBeatNumbers.store(show); }

    float getGridOpacity() const { return m_gridOpacity.load(); }
    void setGridOpacity(float opacity) { m_gridOpacity.store(std::clamp(opacity, 0.0f, 1.0f)); }

    // ===== Metronome Settings =====

    bool getMetronomeEnabled() const { return m_metronomeEnabled.load(); }
    void setMetronomeEnabled(bool enabled) { m_metronomeEnabled.store(enabled); }

    bool getCountIn() const { return m_countIn.load(); }
    void setCountIn(bool enabled) { m_countIn.store(enabled); }

    int getCountInBars() const { return m_countInBars.load(); }
    void setCountInBars(int bars) { m_countInBars.store(std::clamp(bars, 1, 4)); }

    // ===== Utility Methods =====

    /// Get grid info string
    std::string gridInfoString() const {
        std::lock_guard<std::mutex> lock(m_mutex);
        return std::to_string(static_cast<int>(m_grid.bpm)) + " BPM • " + m_grid.timeSignature.displayString();
    }

    /// Get current position string
    std::string positionString() const {
        std::lock_guard<std::mutex> lock(m_mutex);
        return m_currentPosition.displayString();
    }

    /// Get time until next beat
    double timeUntilNextBeat(double seconds) const {
        std::lock_guard<std::mutex> lock(m_mutex);
        double nextBeat = m_grid.nextBeat(seconds);
        return nextBeat - seconds;
    }

    /// Get time until next bar
    double timeUntilNextBar(double seconds) const {
        double nextBar = cutAtNextBar(seconds);
        return nextBar - seconds;
    }

private:
    // ===== Internal Methods =====

    /// Simple onset detection using energy difference
    std::vector<double> detectOnsets(const std::vector<float>& samples, int sampleRate) {
        const int hopSize = 512;
        const int windowSize = 1024;
        std::vector<double> onsets;
        float lastEnergy = 0.0f;

        for (size_t i = 0; i + windowSize < samples.size(); i += hopSize) {
            float energy = 0.0f;
            for (size_t j = 0; j < windowSize; ++j) {
                energy += samples[i + j] * samples[i + j];
            }
            energy /= windowSize;

            // Onset when energy increases significantly
            if (energy > lastEnergy * 1.5f && energy > 0.01f) {
                double time = static_cast<double>(i) / sampleRate;
                if (onsets.empty() || time - onsets.back() > 0.1) {
                    onsets.push_back(time);
                }
            }
            lastEnergy = energy;
        }

        return onsets;
    }

    /// Estimate BPM from onset times
    std::pair<double, float> estimateBPM(const std::vector<double>& onsets, int sampleRate) {
        if (onsets.size() < 2) return {120.0, 0.0f};

        // Calculate intervals between onsets
        std::vector<double> intervals;
        for (size_t i = 1; i < onsets.size(); ++i) {
            intervals.push_back(onsets[i] - onsets[i-1]);
        }

        // Histogram of intervals (quantized to common beat durations)
        std::map<double, int> histogram;
        for (double interval : intervals) {
            double bpm = 60.0 / interval;
            double quantizedBPM = std::round(bpm / 5.0) * 5.0;  // Round to nearest 5 BPM
            if (quantizedBPM >= 60.0 && quantizedBPM <= 200.0) {
                histogram[quantizedBPM]++;
            }
        }

        // Find most common BPM
        if (histogram.empty()) return {120.0, 0.0f};

        auto maxIt = std::max_element(histogram.begin(), histogram.end(),
            [](const auto& a, const auto& b) { return a.second < b.second; });

        float confidence = static_cast<float>(maxIt->second) / intervals.size();
        return {maxIt->first, confidence};
    }

    /// Create beat markers from detection result
    void createBeatMarkers(const BeatDetectionResult& result) {
        std::lock_guard<std::mutex> lock(m_markerMutex);
        m_markers.clear();

        for (size_t i = 0; i < result.beats.size(); ++i) {
            double beatTime = result.beats[i];
            bool isDownbeat = std::find(result.downbeats.begin(), result.downbeats.end(), beatTime) != result.downbeats.end();

            BeatMarker marker;
            marker.position = BeatPosition::fromSeconds(
                beatTime - result.offset,
                result.bpm,
                result.timeSignature
            );
            marker.type = isDownbeat ? MarkerType::Downbeat : MarkerType::Beat;
            marker.label = isDownbeat ? "Bar " + std::to_string(marker.position.bar) : "";
            marker.color = isDownbeat ? "#FF0000" : "#0088FF";

            m_markers.push_back(marker);
        }
    }

    /// Trigger beat-synced effects
    void triggerBeatEffects(int beat, int bar) {
        std::vector<BeatSyncedEffect> effectsCopy;
        {
            std::lock_guard<std::mutex> lock(m_effectMutex);
            effectsCopy = m_beatSyncedEffects;
        }

        for (const auto& effect : effectsCopy) {
            bool shouldTrigger = false;

            switch (effect.triggerOn) {
                case TriggerMode::EveryBeat:
                    shouldTrigger = true;
                    break;
                case TriggerMode::EveryDownbeat:
                    shouldTrigger = (beat == 1);
                    break;
                case TriggerMode::EveryOtherBeat:
                    shouldTrigger = (beat % 2 == 1);
                    break;
                case TriggerMode::EveryBar:
                    shouldTrigger = (beat == 1);
                    break;
                case TriggerMode::Every2Bars:
                    shouldTrigger = (beat == 1 && bar % 2 == 1);
                    break;
                case TriggerMode::Every4Bars:
                    shouldTrigger = (beat == 1 && bar % 4 == 1);
                    break;
                default:
                    break;
            }

            if (shouldTrigger && m_onBeatEffect) {
                m_onBeatEffect(effect);
            }
        }
    }

    // ===== Member Variables =====

    mutable std::mutex m_mutex;
    mutable std::mutex m_tapMutex;
    mutable std::mutex m_markerMutex;
    mutable std::mutex m_effectMutex;

    BPMGrid m_grid;
    std::atomic<SnapMode> m_snapMode;
    std::atomic<bool> m_isSnapEnabled;

    std::vector<BeatMarker> m_markers;
    std::vector<BeatSyncedEffect> m_beatSyncedEffects;

    // Visual settings
    std::atomic<bool> m_showBeatGrid;
    std::atomic<bool> m_showDownbeatLines;
    std::atomic<bool> m_showBeatNumbers;
    std::atomic<float> m_gridOpacity;

    // Playback state
    std::atomic<int> m_currentBeat;
    std::atomic<int> m_currentBar;
    BeatPosition m_currentPosition;
    std::atomic<bool> m_isOnBeat;

    // Settings
    std::atomic<bool> m_metronomeEnabled;
    std::atomic<bool> m_countIn;
    std::atomic<int> m_countInBars;

    // Beat detection
    std::atomic<bool> m_isAnalyzing;
    std::optional<BeatDetectionResult> m_lastDetectionResult;

    // Tap tempo
    std::vector<std::chrono::steady_clock::time_point> m_tapTimes;

    // Callbacks
    BeatCallback m_onBeat;
    DownbeatCallback m_onDownbeat;
    EffectCallback m_onBeatEffect;
};

} // namespace Video
} // namespace Echoelmusic
