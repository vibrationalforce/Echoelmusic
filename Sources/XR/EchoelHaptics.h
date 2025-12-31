#pragma once

#include <string>
#include <vector>
#include <map>
#include <memory>
#include <functional>
#include <thread>
#include <mutex>
#include <cmath>
#include <chrono>
#include <queue>
#include <optional>

namespace Echoel {
namespace XR {

// =============================================================================
// HAPTIC TYPES & ENUMS
// =============================================================================

enum class HapticDeviceType {
    // Apple Devices
    iPhoneTapticEngine,
    AppleWatchTaptic,
    MacBookForceTouch,
    GameControllerApple,

    // Game Controllers
    DualSense,          // PS5 controller (advanced haptics)
    DualShock4,         // PS4 controller
    XboxSeries,         // Xbox Series X/S
    XboxOne,
    NintendoSwitch,
    NintendoJoyCon,

    // VR Controllers
    OculusTouch,
    ValveIndex,
    ViveCosmos,
    QuestPro,
    AppleVisionPro,
    PSVR2Sense,

    // Wearables
    HapticGlove,
    HapticVest,
    HapticSuit,
    HapticBand,

    // Audio Devices
    SubPac,             // Tactile bass
    WoojerVest,
    BassShaker,

    // Generic
    LinearResonantActuator,
    EccentricRotatingMass,
    PiezoActuator,
    VoiceCoilActuator,

    Custom,
    Unknown
};

enum class HapticCapability {
    SimpleVibration,    // On/off vibration
    IntensityControl,   // Variable intensity
    FrequencyControl,   // Variable frequency
    Waveforms,          // Pre-defined waveforms
    AdaptiveTriggers,   // Resistance triggers (DualSense)
    HD_Haptics,         // High-definition haptics
    SpatialHaptics,     // Position-aware haptics
    AudioHaptics,       // Audio-driven haptics
    TextureSimulation,  // Surface texture feedback
    ForceFeeback,       // Active resistance
    ThermalFeedback,    // Temperature feedback
    ElectroTactile      // Electrical stimulation
};

enum class HapticPattern {
    // Basic patterns
    Click,
    DoubleClick,
    TripleClick,
    Tap,
    Tick,
    Pop,

    // Notifications
    Success,
    Warning,
    Error,
    Notification,
    Alarm,

    // Music-related
    BeatPulse,
    BassHit,
    SnarePunch,
    KickDrum,
    HiHatTick,
    Cymbal,

    // Instruments
    PianoKeyPress,
    GuitarStrum,
    DrumHit,
    BassPluck,
    ViolinBow,
    BrassBlast,

    // Transport controls
    PlayStart,
    PlayStop,
    RecordStart,
    RecordStop,
    Rewind,
    FastForward,
    LoopPoint,
    MarkerHit,

    // DAW interactions
    FaderTouch,
    FaderMove,
    KnobTurn,
    ButtonPress,
    SnapToGrid,
    ZeroPosition,
    ClipStart,
    ClipEnd,

    // Effects
    Rumble,
    Explosion,
    Impact,
    Texture,
    Continuous,

    Custom
};

enum class HapticWaveform {
    Sine,
    Square,
    Triangle,
    Sawtooth,
    Noise,
    Impulse,
    Decay,
    Attack,
    AttackDecay,
    ADSR,
    Custom
};

enum class HapticChannel {
    Left,
    Right,
    Both,
    LeftTrigger,        // DualSense/Xbox adaptive trigger
    RightTrigger,
    LeftGrip,           // VR controller grip
    RightGrip,
    Chest,              // Haptic vest zones
    Back,
    LeftArm,
    RightArm,
    LeftLeg,
    RightLeg,
    Head,
    All
};

enum class AdaptiveTriggerMode {
    Off,
    Feedback,           // Resistance at position
    Weapon,             // Trigger pull feeling
    Vibration,          // Vibrating trigger
    MultipleRegions,    // Multiple resistance zones
    SlopeFeedback,      // Gradual resistance
    Custom
};

// =============================================================================
// HAPTIC DATA STRUCTURES
// =============================================================================

struct HapticPoint {
    float time = 0.0f;          // Seconds
    float intensity = 1.0f;     // 0-1
    float frequency = 150.0f;   // Hz
    float sharpness = 0.5f;     // 0 = rounded, 1 = sharp
};

struct HapticEnvelope {
    float attack = 0.01f;       // Seconds
    float decay = 0.05f;        // Seconds
    float sustain = 0.8f;       // 0-1 level
    float release = 0.1f;       // Seconds

    float getAmplitude(float time, float duration) const {
        if (time < attack) {
            return time / attack;
        }
        if (time < attack + decay) {
            float t = (time - attack) / decay;
            return 1.0f - t * (1.0f - sustain);
        }
        if (time < duration - release) {
            return sustain;
        }
        float t = (time - (duration - release)) / release;
        return sustain * (1.0f - t);
    }
};

struct HapticEvent {
    std::string id;
    HapticPattern pattern = HapticPattern::Click;
    HapticChannel channel = HapticChannel::Both;

    float startTime = 0.0f;     // When to trigger
    float duration = 0.1f;      // How long
    float intensity = 1.0f;     // 0-1
    float frequency = 150.0f;   // Base frequency Hz
    float sharpness = 0.5f;     // 0-1

    HapticWaveform waveform = HapticWaveform::Sine;
    HapticEnvelope envelope;

    // For custom waveforms
    std::vector<HapticPoint> customPoints;

    // Audio sync
    bool syncToAudio = false;
    std::string audioSourceId;
    float audioThreshold = 0.5f;
};

struct HapticSequence {
    std::string id;
    std::string name;
    std::vector<HapticEvent> events;
    bool isLooping = false;
    float loopDuration = 0.0f;

    void addEvent(const HapticEvent& event) {
        events.push_back(event);
    }

    float getTotalDuration() const {
        float maxEnd = 0.0f;
        for (const auto& e : events) {
            maxEnd = std::max(maxEnd, e.startTime + e.duration);
        }
        return maxEnd;
    }

    void sortByTime() {
        std::sort(events.begin(), events.end(),
            [](const HapticEvent& a, const HapticEvent& b) {
                return a.startTime < b.startTime;
            });
    }
};

struct AdaptiveTriggerParams {
    AdaptiveTriggerMode mode = AdaptiveTriggerMode::Off;

    // Feedback mode
    float startPosition = 0.0f;     // 0-1 trigger position
    float strength = 0.5f;          // 0-1 resistance

    // Weapon mode
    float weaponStartPosition = 0.2f;
    float weaponEndPosition = 0.7f;
    float weaponStrength = 0.8f;

    // Vibration mode
    float vibrationFrequency = 20.0f;
    float vibrationAmplitude = 0.5f;

    // Multiple regions
    struct Region {
        float start = 0.0f;
        float end = 1.0f;
        float strength = 0.5f;
    };
    std::vector<Region> regions;
};

struct HapticDeviceInfo {
    std::string id;
    std::string name;
    HapticDeviceType type = HapticDeviceType::Unknown;
    std::vector<HapticCapability> capabilities;

    // Hardware specs
    int numActuators = 1;
    float minFrequency = 50.0f;     // Hz
    float maxFrequency = 500.0f;    // Hz
    int intensityLevels = 256;
    float maxDuration = 5.0f;       // Seconds

    // Spatial info (for suits/vests)
    int numZones = 1;
    std::vector<HapticChannel> supportedChannels;

    bool hasCapability(HapticCapability cap) const {
        for (const auto& c : capabilities) {
            if (c == cap) return true;
        }
        return false;
    }
};

// =============================================================================
// AUDIO-TO-HAPTICS CONVERTER
// =============================================================================

class AudioHapticConverter {
public:
    struct ConversionParams {
        float intensityScale = 1.0f;
        float frequencyScale = 1.0f;
        float minIntensity = 0.1f;
        float maxIntensity = 1.0f;
        float minFrequency = 50.0f;
        float maxFrequency = 300.0f;

        // Frequency bands
        bool useBassForIntensity = true;
        bool useMidForFrequency = true;
        float bassLowCut = 20.0f;
        float bassHighCut = 200.0f;
        float midLowCut = 200.0f;
        float midHighCut = 2000.0f;

        // Beat detection
        bool detectBeats = true;
        float beatThreshold = 0.7f;
        float beatDecay = 0.95f;

        // Smoothing
        float attackTime = 0.01f;
        float releaseTime = 0.1f;
    };

    HapticSequence convertAudioToHaptics(const std::vector<float>& audio,
                                          int sampleRate,
                                          const ConversionParams& params = {}) {
        HapticSequence sequence;
        sequence.id = "audio_haptic_" + std::to_string(rand() % 10000);
        sequence.name = "Audio-driven Haptics";

        int windowSize = sampleRate / 50;  // 20ms windows
        float windowDuration = 1.0f / 50.0f;

        float currentIntensity = 0.0f;
        float beatEnergy = 0.0f;
        float prevEnergy = 0.0f;

        for (size_t i = 0; i + windowSize < audio.size(); i += windowSize) {
            float time = static_cast<float>(i) / sampleRate;

            // Calculate RMS energy
            float energy = 0.0f;
            for (size_t j = 0; j < windowSize; j++) {
                energy += audio[i + j] * audio[i + j];
            }
            energy = std::sqrt(energy / windowSize);

            // Bass energy (simplified frequency analysis)
            float bassEnergy = 0.0f;
            float midEnergy = 0.0f;

            // Simple approximation based on sample variation
            for (size_t j = 1; j < windowSize; j++) {
                float diff = std::abs(audio[i + j] - audio[i + j - 1]);
                bassEnergy += audio[i + j] * audio[i + j];
                midEnergy += diff;
            }
            bassEnergy /= windowSize;
            midEnergy /= windowSize;

            // Calculate intensity
            float targetIntensity = params.useBassForIntensity ?
                bassEnergy * params.intensityScale :
                energy * params.intensityScale;

            targetIntensity = std::clamp(targetIntensity,
                                          params.minIntensity,
                                          params.maxIntensity);

            // Smooth intensity
            if (targetIntensity > currentIntensity) {
                currentIntensity += (targetIntensity - currentIntensity) *
                                   (1.0f - std::exp(-windowDuration / params.attackTime));
            } else {
                currentIntensity += (targetIntensity - currentIntensity) *
                                   (1.0f - std::exp(-windowDuration / params.releaseTime));
            }

            // Calculate frequency
            float frequency = params.minFrequency +
                             (params.maxFrequency - params.minFrequency) *
                             (params.useMidForFrequency ? midEnergy * 10.0f : 0.5f);
            frequency = std::clamp(frequency, params.minFrequency, params.maxFrequency);

            // Beat detection
            bool isBeat = false;
            if (params.detectBeats) {
                if (energy > prevEnergy * 1.5f && energy > params.beatThreshold) {
                    isBeat = true;
                }
                prevEnergy = prevEnergy * params.beatDecay + energy * (1.0f - params.beatDecay);
            }

            // Create haptic event
            if (currentIntensity > 0.01f) {
                HapticEvent event;
                event.id = "audio_" + std::to_string(i);
                event.pattern = isBeat ? HapticPattern::BeatPulse : HapticPattern::Continuous;
                event.startTime = time;
                event.duration = windowDuration;
                event.intensity = currentIntensity;
                event.frequency = frequency;
                event.sharpness = isBeat ? 0.8f : 0.3f;

                sequence.addEvent(event);
            }
        }

        return sequence;
    }

    HapticEvent createBeatHaptic(float time, float intensity = 1.0f,
                                  HapticPattern pattern = HapticPattern::BeatPulse) {
        HapticEvent event;
        event.id = "beat_" + std::to_string(static_cast<int>(time * 1000));
        event.pattern = pattern;
        event.startTime = time;
        event.duration = 0.08f;
        event.intensity = intensity;
        event.frequency = 200.0f;
        event.sharpness = 0.8f;
        event.envelope.attack = 0.005f;
        event.envelope.decay = 0.02f;
        event.envelope.sustain = 0.3f;
        event.envelope.release = 0.05f;

        return event;
    }

    HapticSequence createBeatSequence(const std::vector<float>& beatTimes,
                                       float intensity = 1.0f) {
        HapticSequence sequence;
        sequence.id = "beats_" + std::to_string(rand() % 10000);
        sequence.name = "Beat Pattern";

        for (float time : beatTimes) {
            sequence.addEvent(createBeatHaptic(time, intensity));
        }

        return sequence;
    }

private:
    ConversionParams params_;
};

// =============================================================================
// HAPTIC PATTERN LIBRARY
// =============================================================================

class HapticPatternLibrary {
public:
    static HapticPatternLibrary& getInstance() {
        static HapticPatternLibrary instance;
        return instance;
    }

    HapticEvent getPattern(HapticPattern pattern, float intensity = 1.0f) {
        HapticEvent event;
        event.pattern = pattern;
        event.intensity = intensity;

        switch (pattern) {
            case HapticPattern::Click:
                event.duration = 0.01f;
                event.frequency = 200.0f;
                event.sharpness = 1.0f;
                event.envelope = {0.001f, 0.005f, 0.0f, 0.004f};
                break;

            case HapticPattern::DoubleClick:
                event.duration = 0.1f;
                event.frequency = 200.0f;
                event.sharpness = 1.0f;
                event.customPoints = {
                    {0.0f, 1.0f, 200.0f, 1.0f},
                    {0.01f, 0.0f, 0.0f, 0.0f},
                    {0.05f, 1.0f, 200.0f, 1.0f},
                    {0.06f, 0.0f, 0.0f, 0.0f}
                };
                break;

            case HapticPattern::Success:
                event.duration = 0.3f;
                event.frequency = 250.0f;
                event.sharpness = 0.6f;
                event.customPoints = {
                    {0.0f, 0.5f, 200.0f, 0.5f},
                    {0.1f, 1.0f, 300.0f, 0.8f},
                    {0.2f, 0.8f, 250.0f, 0.4f},
                    {0.3f, 0.0f, 150.0f, 0.2f}
                };
                break;

            case HapticPattern::Warning:
                event.duration = 0.4f;
                event.frequency = 150.0f;
                event.sharpness = 0.7f;
                event.customPoints = {
                    {0.0f, 1.0f, 150.0f, 0.8f},
                    {0.1f, 0.0f, 100.0f, 0.5f},
                    {0.2f, 1.0f, 150.0f, 0.8f},
                    {0.3f, 0.0f, 100.0f, 0.5f},
                    {0.4f, 0.0f, 50.0f, 0.3f}
                };
                break;

            case HapticPattern::Error:
                event.duration = 0.5f;
                event.frequency = 100.0f;
                event.sharpness = 0.9f;
                event.customPoints = {
                    {0.0f, 1.0f, 80.0f, 1.0f},
                    {0.15f, 0.0f, 50.0f, 0.5f},
                    {0.25f, 1.0f, 80.0f, 1.0f},
                    {0.4f, 0.0f, 50.0f, 0.5f},
                    {0.5f, 0.0f, 30.0f, 0.2f}
                };
                break;

            case HapticPattern::BeatPulse:
                event.duration = 0.08f;
                event.frequency = 200.0f;
                event.sharpness = 0.8f;
                event.envelope = {0.005f, 0.02f, 0.3f, 0.05f};
                break;

            case HapticPattern::BassHit:
                event.duration = 0.15f;
                event.frequency = 60.0f;
                event.sharpness = 0.9f;
                event.envelope = {0.002f, 0.05f, 0.5f, 0.1f};
                break;

            case HapticPattern::SnarePunch:
                event.duration = 0.1f;
                event.frequency = 180.0f;
                event.sharpness = 1.0f;
                event.envelope = {0.001f, 0.02f, 0.2f, 0.08f};
                break;

            case HapticPattern::KickDrum:
                event.duration = 0.12f;
                event.frequency = 50.0f;
                event.sharpness = 0.85f;
                event.envelope = {0.002f, 0.03f, 0.4f, 0.09f};
                break;

            case HapticPattern::HiHatTick:
                event.duration = 0.02f;
                event.frequency = 300.0f;
                event.sharpness = 0.7f;
                event.envelope = {0.001f, 0.01f, 0.0f, 0.01f};
                break;

            case HapticPattern::FaderTouch:
                event.duration = 0.015f;
                event.frequency = 250.0f;
                event.sharpness = 0.5f;
                event.envelope = {0.005f, 0.005f, 0.0f, 0.005f};
                break;

            case HapticPattern::KnobTurn:
                event.duration = 0.01f;
                event.frequency = 280.0f;
                event.sharpness = 0.4f;
                event.envelope = {0.002f, 0.003f, 0.0f, 0.005f};
                break;

            case HapticPattern::SnapToGrid:
                event.duration = 0.02f;
                event.frequency = 220.0f;
                event.sharpness = 0.9f;
                event.envelope = {0.001f, 0.01f, 0.0f, 0.01f};
                break;

            case HapticPattern::RecordStart:
                event.duration = 0.2f;
                event.frequency = 150.0f;
                event.sharpness = 0.6f;
                event.customPoints = {
                    {0.0f, 0.3f, 100.0f, 0.3f},
                    {0.1f, 1.0f, 200.0f, 0.8f},
                    {0.2f, 0.5f, 150.0f, 0.5f}
                };
                break;

            case HapticPattern::RecordStop:
                event.duration = 0.15f;
                event.frequency = 120.0f;
                event.sharpness = 0.7f;
                event.customPoints = {
                    {0.0f, 1.0f, 180.0f, 0.8f},
                    {0.1f, 0.3f, 100.0f, 0.4f},
                    {0.15f, 0.0f, 60.0f, 0.2f}
                };
                break;

            default:
                event.duration = 0.05f;
                event.frequency = 150.0f;
                event.sharpness = 0.5f;
                break;
        }

        return event;
    }

    HapticSequence getMetronomeSequence(float bpm, int beatsPerMeasure = 4,
                                         float duration = 4.0f) {
        HapticSequence sequence;
        sequence.id = "metronome_" + std::to_string(static_cast<int>(bpm));
        sequence.name = "Metronome " + std::to_string(static_cast<int>(bpm)) + " BPM";

        float beatDuration = 60.0f / bpm;
        float time = 0.0f;
        int beat = 0;

        while (time < duration) {
            HapticEvent event = (beat % beatsPerMeasure == 0) ?
                getPattern(HapticPattern::Click, 1.0f) :
                getPattern(HapticPattern::Tick, 0.6f);

            event.startTime = time;
            sequence.addEvent(event);

            time += beatDuration;
            beat++;
        }

        sequence.isLooping = true;
        sequence.loopDuration = beatsPerMeasure * beatDuration;

        return sequence;
    }

    void registerCustomPattern(const std::string& name, const HapticEvent& pattern) {
        customPatterns_[name] = pattern;
    }

    std::optional<HapticEvent> getCustomPattern(const std::string& name) {
        auto it = customPatterns_.find(name);
        if (it != customPatterns_.end()) {
            return it->second;
        }
        return std::nullopt;
    }

private:
    HapticPatternLibrary() = default;
    std::map<std::string, HapticEvent> customPatterns_;
};

// =============================================================================
// HAPTIC DEVICE INTERFACE
// =============================================================================

class IHapticDevice {
public:
    virtual ~IHapticDevice() = default;

    virtual bool initialize() = 0;
    virtual void shutdown() = 0;
    virtual bool isConnected() const = 0;

    virtual HapticDeviceInfo getInfo() const = 0;

    virtual void playEvent(const HapticEvent& event) = 0;
    virtual void playSequence(const HapticSequence& sequence) = 0;
    virtual void stopAll() = 0;

    virtual void setIntensityScale(float scale) = 0;
    virtual float getIntensityScale() const = 0;

    // Advanced features
    virtual void setAdaptiveTrigger(HapticChannel trigger,
                                     const AdaptiveTriggerParams& params) {}
    virtual void setResistance(HapticChannel channel, float resistance) {}
};

// =============================================================================
// PLATFORM-SPECIFIC IMPLEMENTATIONS (Stubs)
// =============================================================================

class AppleTapticDevice : public IHapticDevice {
public:
    bool initialize() override {
        connected_ = true;
        return true;
    }

    void shutdown() override {
        connected_ = false;
    }

    bool isConnected() const override {
        return connected_;
    }

    HapticDeviceInfo getInfo() const override {
        HapticDeviceInfo info;
        info.id = "apple_taptic";
        info.name = "Apple Taptic Engine";
        info.type = HapticDeviceType::iPhoneTapticEngine;
        info.capabilities = {
            HapticCapability::IntensityControl,
            HapticCapability::Waveforms,
            HapticCapability::HD_Haptics
        };
        info.minFrequency = 50.0f;
        info.maxFrequency = 400.0f;
        return info;
    }

    void playEvent(const HapticEvent& event) override {
        // Would call CHHapticEngine on iOS/macOS
        lastEvent_ = event;
    }

    void playSequence(const HapticSequence& sequence) override {
        // Would create CHHapticPattern
        currentSequence_ = sequence;
    }

    void stopAll() override {
        // Stop haptic engine
    }

    void setIntensityScale(float scale) override {
        intensityScale_ = std::clamp(scale, 0.0f, 1.0f);
    }

    float getIntensityScale() const override {
        return intensityScale_;
    }

private:
    bool connected_ = false;
    float intensityScale_ = 1.0f;
    HapticEvent lastEvent_;
    HapticSequence currentSequence_;
};

class DualSenseDevice : public IHapticDevice {
public:
    bool initialize() override {
        connected_ = true;
        return true;
    }

    void shutdown() override {
        connected_ = false;
    }

    bool isConnected() const override {
        return connected_;
    }

    HapticDeviceInfo getInfo() const override {
        HapticDeviceInfo info;
        info.id = "dualsense";
        info.name = "PlayStation DualSense";
        info.type = HapticDeviceType::DualSense;
        info.numActuators = 2;  // Left and right
        info.capabilities = {
            HapticCapability::IntensityControl,
            HapticCapability::FrequencyControl,
            HapticCapability::HD_Haptics,
            HapticCapability::AdaptiveTriggers,
            HapticCapability::AudioHaptics
        };
        info.supportedChannels = {
            HapticChannel::Left, HapticChannel::Right,
            HapticChannel::LeftTrigger, HapticChannel::RightTrigger
        };
        return info;
    }

    void playEvent(const HapticEvent& event) override {
        lastEvent_ = event;
    }

    void playSequence(const HapticSequence& sequence) override {
        currentSequence_ = sequence;
    }

    void stopAll() override {}

    void setIntensityScale(float scale) override {
        intensityScale_ = std::clamp(scale, 0.0f, 1.0f);
    }

    float getIntensityScale() const override {
        return intensityScale_;
    }

    void setAdaptiveTrigger(HapticChannel trigger,
                            const AdaptiveTriggerParams& params) override {
        if (trigger == HapticChannel::LeftTrigger) {
            leftTriggerParams_ = params;
        } else if (trigger == HapticChannel::RightTrigger) {
            rightTriggerParams_ = params;
        }
    }

private:
    bool connected_ = false;
    float intensityScale_ = 1.0f;
    HapticEvent lastEvent_;
    HapticSequence currentSequence_;
    AdaptiveTriggerParams leftTriggerParams_;
    AdaptiveTriggerParams rightTriggerParams_;
};

class VRHapticDevice : public IHapticDevice {
public:
    VRHapticDevice(HapticDeviceType type = HapticDeviceType::OculusTouch)
        : deviceType_(type) {}

    bool initialize() override {
        connected_ = true;
        return true;
    }

    void shutdown() override {
        connected_ = false;
    }

    bool isConnected() const override {
        return connected_;
    }

    HapticDeviceInfo getInfo() const override {
        HapticDeviceInfo info;
        info.id = "vr_haptic";
        info.type = deviceType_;

        switch (deviceType_) {
            case HapticDeviceType::OculusTouch:
                info.name = "Oculus Touch";
                break;
            case HapticDeviceType::ValveIndex:
                info.name = "Valve Index";
                break;
            case HapticDeviceType::QuestPro:
                info.name = "Quest Pro";
                break;
            case HapticDeviceType::AppleVisionPro:
                info.name = "Apple Vision Pro";
                break;
            default:
                info.name = "VR Controller";
        }

        info.numActuators = 2;
        info.capabilities = {
            HapticCapability::IntensityControl,
            HapticCapability::SpatialHaptics
        };
        info.supportedChannels = {
            HapticChannel::Left, HapticChannel::Right,
            HapticChannel::LeftGrip, HapticChannel::RightGrip
        };

        return info;
    }

    void playEvent(const HapticEvent& event) override {
        lastEvent_ = event;
    }

    void playSequence(const HapticSequence& sequence) override {
        currentSequence_ = sequence;
    }

    void stopAll() override {}

    void setIntensityScale(float scale) override {
        intensityScale_ = std::clamp(scale, 0.0f, 1.0f);
    }

    float getIntensityScale() const override {
        return intensityScale_;
    }

private:
    HapticDeviceType deviceType_;
    bool connected_ = false;
    float intensityScale_ = 1.0f;
    HapticEvent lastEvent_;
    HapticSequence currentSequence_;
};

// =============================================================================
// HAPTIC ENGINE
// =============================================================================

class HapticEngine {
public:
    static HapticEngine& getInstance() {
        static HapticEngine instance;
        return instance;
    }

    // Device Management
    bool initialize() {
        // Auto-detect devices (simplified)
        detectDevices();
        initialized_ = true;
        return true;
    }

    void shutdown() {
        for (auto& [id, device] : devices_) {
            device->shutdown();
        }
        devices_.clear();
        initialized_ = false;
    }

    void registerDevice(const std::string& id, std::shared_ptr<IHapticDevice> device) {
        if (device && device->initialize()) {
            devices_[id] = device;
        }
    }

    void removeDevice(const std::string& id) {
        if (devices_.count(id)) {
            devices_[id]->shutdown();
            devices_.erase(id);
        }
    }

    std::vector<std::string> getConnectedDevices() const {
        std::vector<std::string> ids;
        for (const auto& [id, device] : devices_) {
            if (device->isConnected()) {
                ids.push_back(id);
            }
        }
        return ids;
    }

    std::shared_ptr<IHapticDevice> getDevice(const std::string& id) {
        return devices_.count(id) ? devices_[id] : nullptr;
    }

    // Playback
    void play(HapticPattern pattern, float intensity = 1.0f) {
        auto event = HapticPatternLibrary::getInstance().getPattern(pattern, intensity);
        playEvent(event);
    }

    void playEvent(const HapticEvent& event, const std::string& deviceId = "") {
        std::lock_guard<std::mutex> lock(mutex_);

        if (deviceId.empty()) {
            // Play on all devices
            for (auto& [id, device] : devices_) {
                if (device->isConnected()) {
                    device->playEvent(event);
                }
            }
        } else if (devices_.count(deviceId)) {
            devices_[deviceId]->playEvent(event);
        }
    }

    void playSequence(const HapticSequence& sequence, const std::string& deviceId = "") {
        std::lock_guard<std::mutex> lock(mutex_);

        if (deviceId.empty()) {
            for (auto& [id, device] : devices_) {
                if (device->isConnected()) {
                    device->playSequence(sequence);
                }
            }
        } else if (devices_.count(deviceId)) {
            devices_[deviceId]->playSequence(sequence);
        }
    }

    void stopAll() {
        std::lock_guard<std::mutex> lock(mutex_);
        for (auto& [id, device] : devices_) {
            device->stopAll();
        }
    }

    // Audio Sync
    void syncToAudio(const std::vector<float>& audio, int sampleRate) {
        AudioHapticConverter converter;
        auto sequence = converter.convertAudioToHaptics(audio, sampleRate);
        playSequence(sequence);
    }

    void syncToBeats(const std::vector<float>& beatTimes, float intensity = 1.0f) {
        AudioHapticConverter converter;
        auto sequence = converter.createBeatSequence(beatTimes, intensity);
        playSequence(sequence);
    }

    // DAW Integration
    void onTransportStart() {
        play(HapticPattern::PlayStart);
    }

    void onTransportStop() {
        play(HapticPattern::PlayStop);
    }

    void onRecordStart() {
        play(HapticPattern::RecordStart);
    }

    void onRecordStop() {
        play(HapticPattern::RecordStop);
    }

    void onBeat(int beatNumber, int beatsPerMeasure) {
        float intensity = (beatNumber % beatsPerMeasure == 0) ? 1.0f : 0.5f;
        play(HapticPattern::BeatPulse, intensity);
    }

    void onMarkerHit() {
        play(HapticPattern::MarkerHit);
    }

    void onFaderTouch() {
        play(HapticPattern::FaderTouch, 0.3f);
    }

    void onKnobTurn() {
        play(HapticPattern::KnobTurn, 0.2f);
    }

    void onSnapToGrid() {
        play(HapticPattern::SnapToGrid, 0.4f);
    }

    // Settings
    void setGlobalIntensity(float intensity) {
        globalIntensity_ = std::clamp(intensity, 0.0f, 1.0f);
        for (auto& [id, device] : devices_) {
            device->setIntensityScale(globalIntensity_);
        }
    }

    float getGlobalIntensity() const {
        return globalIntensity_;
    }

    void setEnabled(bool enabled) {
        enabled_ = enabled;
    }

    bool isEnabled() const {
        return enabled_;
    }

    bool isInitialized() const {
        return initialized_;
    }

private:
    HapticEngine() = default;

    void detectDevices() {
        // In real implementation, would detect available haptic hardware
        // For now, register simulated devices

        auto taptic = std::make_shared<AppleTapticDevice>();
        registerDevice("taptic", taptic);

        auto dualsense = std::make_shared<DualSenseDevice>();
        registerDevice("dualsense", dualsense);

        auto vr = std::make_shared<VRHapticDevice>(HapticDeviceType::AppleVisionPro);
        registerDevice("visionpro", vr);
    }

    bool initialized_ = false;
    bool enabled_ = true;
    float globalIntensity_ = 1.0f;
    std::map<std::string, std::shared_ptr<IHapticDevice>> devices_;
    std::mutex mutex_;
};

// =============================================================================
// CONVENIENCE FUNCTIONS
// =============================================================================

inline void hapticClick() {
    HapticEngine::getInstance().play(HapticPattern::Click);
}

inline void hapticSuccess() {
    HapticEngine::getInstance().play(HapticPattern::Success);
}

inline void hapticWarning() {
    HapticEngine::getInstance().play(HapticPattern::Warning);
}

inline void hapticError() {
    HapticEngine::getInstance().play(HapticPattern::Error);
}

inline void hapticBeat(float intensity = 1.0f) {
    HapticEngine::getInstance().play(HapticPattern::BeatPulse, intensity);
}

inline void hapticKick() {
    HapticEngine::getInstance().play(HapticPattern::KickDrum);
}

inline void hapticSnare() {
    HapticEngine::getInstance().play(HapticPattern::SnarePunch);
}

inline void hapticFaderTouch() {
    HapticEngine::getInstance().onFaderTouch();
}

inline HapticSequence createMetronome(float bpm) {
    return HapticPatternLibrary::getInstance().getMetronomeSequence(bpm);
}

inline void playMetronome(float bpm) {
    auto seq = createMetronome(bpm);
    HapticEngine::getInstance().playSequence(seq);
}

} // namespace XR
} // namespace Echoel
