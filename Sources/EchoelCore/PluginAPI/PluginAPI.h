// =============================================================================
// PluginAPI - Native Plugin Interface with MIDI 2.0 Support
// =============================================================================
// Copyright (c) 2024-2026 Echoelmusic. All rights reserved.
// VST3/AU/CLAP compatible - NO JUCE, NO iPlug2
// =============================================================================

#pragma once

#include "../EchoelCore.h"
#include <string>
#include <vector>
#include <map>
#include <optional>
#include <variant>

namespace EchoelCore {
namespace Plugin {

// =============================================================================
// MIDI 2.0 Types (Universal MIDI Packet)
// =============================================================================

namespace MIDI2 {

// Message Types (4-bit)
enum class MessageType : uint8_t {
    Utility           = 0x0,  // 32-bit
    SystemRealTime    = 0x1,  // 32-bit
    MIDI1ChannelVoice = 0x2,  // 32-bit (legacy)
    Data64            = 0x3,  // 64-bit SysEx
    MIDI2ChannelVoice = 0x4,  // 64-bit
    Data128           = 0x5,  // 128-bit SysEx
    FlexData          = 0xD,  // 128-bit
    UMPStream         = 0xF   // 128-bit
};

// MIDI 2.0 Status bytes for Channel Voice
enum class ChannelVoiceStatus : uint8_t {
    RegisteredPerNoteController = 0x00,
    AssignablePerNoteController = 0x10,
    RegisteredController        = 0x20,
    AssignableController        = 0x30,
    RelativeRegisteredController = 0x40,
    RelativeAssignableController = 0x50,
    PerNotePitchBend            = 0x60,
    NoteOff                     = 0x80,
    NoteOn                      = 0x90,
    PolyPressure                = 0xA0,
    ControlChange               = 0xB0,
    ProgramChange               = 0xC0,
    ChannelPressure             = 0xD0,
    PitchBend                   = 0xE0,
    PerNoteManagement           = 0xF0
};

// Universal MIDI Packet (32-bit word)
struct UMPWord {
    uint32_t data;

    uint8_t getMessageType() const { return (data >> 28) & 0x0F; }
    uint8_t getGroup() const { return (data >> 24) & 0x0F; }
    uint8_t getStatus() const { return (data >> 16) & 0xFF; }
    uint8_t getChannel() const { return (data >> 16) & 0x0F; }
};

// MIDI 2.0 Note with per-note attributes
struct Note2 {
    uint8_t channel = 0;
    uint8_t noteNumber = 60;
    uint16_t velocity = 0x8000;     // 16-bit velocity (0x8000 = 0.5, 0xFFFF = 1.0)
    uint16_t attributeType = 0;     // 0 = none, 1 = manufacturer, 2 = profile, 3 = pitch 7.9
    uint16_t attributeData = 0;

    float getVelocityFloat() const {
        return static_cast<float>(velocity) / 65535.0f;
    }

    void setVelocityFloat(float v) {
        velocity = static_cast<uint16_t>(DSP::clamp(v, 0.0f, 1.0f) * 65535.0f);
    }
};

// MIDI 2.0 Controller with 32-bit resolution
struct Controller2 {
    uint8_t channel = 0;
    uint8_t index = 0;
    uint32_t value = 0;           // 32-bit value

    float getValueFloat() const {
        return static_cast<float>(value) / 4294967295.0f;
    }

    void setValueFloat(float v) {
        value = static_cast<uint32_t>(DSP::clamp(v, 0.0f, 1.0f) * 4294967295.0f);
    }
};

// MIDI 2.0 Pitch Bend (32-bit resolution)
struct PitchBend2 {
    uint8_t channel = 0;
    uint32_t value = 0x80000000;  // Center position

    // Get pitch bend in semitones (-2 to +2 default range)
    float getSemitones(float range = 2.0f) const {
        float normalized = (static_cast<float>(value) / 4294967295.0f) * 2.0f - 1.0f;
        return normalized * range;
    }
};

// Per-Note Pitch Bend (MIDI 2.0 exclusive)
struct PerNotePitchBend {
    uint8_t channel = 0;
    uint8_t noteNumber = 60;
    uint32_t value = 0x80000000;

    float getSemitones(float range = 48.0f) const {
        float normalized = (static_cast<float>(value) / 4294967295.0f) * 2.0f - 1.0f;
        return normalized * range;
    }
};

// Per-Note Controller (MIDI 2.0 exclusive)
struct PerNoteController {
    uint8_t channel = 0;
    uint8_t noteNumber = 60;
    uint8_t index = 0;
    uint32_t value = 0;

    float getValueFloat() const {
        return static_cast<float>(value) / 4294967295.0f;
    }
};

// MIDI 2.0 Message Container
using Message = std::variant<
    Note2,
    Controller2,
    PitchBend2,
    PerNotePitchBend,
    PerNoteController
>;

// MIDI 2.0 Message Queue
class MessageQueue {
public:
    void push(const Message& msg) {
        queue_.push_back(msg);
    }

    std::optional<Message> pop() {
        if (queue_.empty()) return std::nullopt;
        Message msg = queue_.front();
        queue_.erase(queue_.begin());
        return msg;
    }

    bool empty() const { return queue_.empty(); }
    size_t size() const { return queue_.size(); }
    void clear() { queue_.clear(); }

private:
    std::vector<Message> queue_;
};

} // namespace MIDI2

// =============================================================================
// Plugin Parameter
// =============================================================================

class Parameter {
public:
    enum class Type { Float, Int, Bool, Choice };

    Parameter(const std::string& id, const std::string& name, float defaultValue,
              float minValue = 0.0f, float maxValue = 1.0f)
        : id_(id), name_(name), value_(defaultValue),
          defaultValue_(defaultValue), minValue_(minValue), maxValue_(maxValue) {}

    const std::string& getId() const { return id_; }
    const std::string& getName() const { return name_; }

    float getValue() const { return value_; }
    float getNormalizedValue() const {
        return (value_ - minValue_) / (maxValue_ - minValue_);
    }

    void setValue(float v) {
        value_ = DSP::clamp(v, minValue_, maxValue_);
    }

    void setNormalizedValue(float v) {
        value_ = minValue_ + v * (maxValue_ - minValue_);
    }

    float getDefaultValue() const { return defaultValue_; }
    float getMinValue() const { return minValue_; }
    float getMaxValue() const { return maxValue_; }

    void setChoices(const std::vector<std::string>& choices) {
        choices_ = choices;
        type_ = Type::Choice;
    }

    const std::vector<std::string>& getChoices() const { return choices_; }
    Type getType() const { return type_; }

private:
    std::string id_;
    std::string name_;
    float value_;
    float defaultValue_;
    float minValue_;
    float maxValue_;
    Type type_ = Type::Float;
    std::vector<std::string> choices_;
};

// =============================================================================
// Plugin Base Class
// =============================================================================

class PluginBase {
public:
    virtual ~PluginBase() = default;

    // Lifecycle
    virtual void prepare(float sampleRate, int maxBlockSize) {
        sampleRate_ = sampleRate;
        maxBlockSize_ = maxBlockSize;
    }

    virtual void reset() {}

    // Audio Processing
    virtual void processBlock(AudioBuffer<float>& buffer) = 0;

    // MIDI Processing (MIDI 2.0)
    virtual void processMIDI(MIDI2::MessageQueue& messages) {
        // Default: clear messages
        messages.clear();
    }

    // Parameters
    void addParameter(std::unique_ptr<Parameter> param) {
        const std::string& id = param->getId();
        parameters_[id] = std::move(param);
        parameterOrder_.push_back(id);
    }

    Parameter* getParameter(const std::string& id) {
        auto it = parameters_.find(id);
        return (it != parameters_.end()) ? it->second.get() : nullptr;
    }

    const std::vector<std::string>& getParameterIds() const {
        return parameterOrder_;
    }

    // Plugin Info
    virtual const char* getName() const = 0;
    virtual const char* getVendor() const { return "Echoelmusic"; }
    virtual const char* getVersion() const { return "1.0.0"; }
    virtual const char* getUniqueId() const = 0;

    // Capabilities
    virtual bool supportsMIDI() const { return false; }
    virtual bool supportsMIDI2() const { return true; }  // MIDI 2.0 by default
    virtual bool isSynth() const { return false; }
    virtual int getNumInputs() const { return 2; }
    virtual int getNumOutputs() const { return 2; }

    // State
    virtual std::vector<uint8_t> getState() const {
        // Serialize parameters
        std::vector<uint8_t> state;
        // Implementation would serialize all parameter values
        return state;
    }

    virtual void setState(const std::vector<uint8_t>& state) {
        // Deserialize parameters
    }

protected:
    float sampleRate_ = DEFAULT_SAMPLE_RATE;
    int maxBlockSize_ = DEFAULT_BUFFER_SIZE;
    std::map<std::string, std::unique_ptr<Parameter>> parameters_;
    std::vector<std::string> parameterOrder_;
};

// =============================================================================
// Plugin Descriptor (for host discovery)
// =============================================================================

struct PluginDescriptor {
    const char* name;
    const char* vendor;
    const char* version;
    const char* uniqueId;
    const char* category;  // "Effect", "Instrument", "Analyzer"

    int numInputs;
    int numOutputs;
    bool isSynth;
    bool supportsMIDI;
    bool supportsMIDI2;

    // Factory function
    std::function<std::unique_ptr<PluginBase>()> createInstance;
};

// =============================================================================
// Plugin Registry
// =============================================================================

class PluginRegistry {
public:
    static PluginRegistry& instance() {
        static PluginRegistry registry;
        return registry;
    }

    void registerPlugin(const PluginDescriptor& descriptor) {
        plugins_[descriptor.uniqueId] = descriptor;
    }

    const PluginDescriptor* getDescriptor(const std::string& id) const {
        auto it = plugins_.find(id);
        return (it != plugins_.end()) ? &it->second : nullptr;
    }

    std::vector<const PluginDescriptor*> getAllPlugins() const {
        std::vector<const PluginDescriptor*> result;
        for (const auto& [id, desc] : plugins_) {
            result.push_back(&desc);
        }
        return result;
    }

private:
    std::map<std::string, PluginDescriptor> plugins_;
};

// Macro for plugin registration
#define REGISTER_PLUGIN(PluginClass) \
    static bool _registered_##PluginClass = []() { \
        PluginDescriptor desc; \
        auto instance = std::make_unique<PluginClass>(); \
        desc.name = instance->getName(); \
        desc.vendor = instance->getVendor(); \
        desc.version = instance->getVersion(); \
        desc.uniqueId = instance->getUniqueId(); \
        desc.category = instance->isSynth() ? "Instrument" : "Effect"; \
        desc.numInputs = instance->getNumInputs(); \
        desc.numOutputs = instance->getNumOutputs(); \
        desc.isSynth = instance->isSynth(); \
        desc.supportsMIDI = instance->supportsMIDI(); \
        desc.supportsMIDI2 = instance->supportsMIDI2(); \
        desc.createInstance = []() { return std::make_unique<PluginClass>(); }; \
        PluginRegistry::instance().registerPlugin(desc); \
        return true; \
    }()

// =============================================================================
// MPE Support
// =============================================================================

namespace MPE {

struct Zone {
    uint8_t masterChannel;      // 0 or 15
    uint8_t memberChannelCount; // 1-15
    int pitchBendRange = 48;    // Semitones (usually 48 for per-note)
};

struct Configuration {
    std::optional<Zone> lowerZone;  // Master = 0, Members = 1-n
    std::optional<Zone> upperZone;  // Master = 15, Members = 15-n down

    bool isChannelInZone(uint8_t channel, const Zone& zone) const {
        if (zone.masterChannel == 0) {
            return channel >= 1 && channel <= zone.memberChannelCount;
        } else {
            return channel >= 15 - zone.memberChannelCount && channel < 15;
        }
    }
};

} // namespace MPE

// =============================================================================
// Version Info
// =============================================================================

struct Version {
    static constexpr int major = 1;
    static constexpr int minor = 0;
    static constexpr int patch = 0;

    static const char* getString() { return "1.0.0"; }
    static const char* getName() { return "EchoelCore PluginAPI"; }
};

} // namespace Plugin
} // namespace EchoelCore
