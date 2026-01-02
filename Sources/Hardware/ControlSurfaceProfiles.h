/*
  ==============================================================================

    ControlSurfaceProfiles.h
    Created: 2026
    Author:  Echoelmusic

    Control Surface Profile System
    MIDI controller mapping, learn mode, and hardware integration

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include <vector>
#include <memory>
#include <map>
#include <functional>
#include <set>

namespace Echoelmusic {
namespace Hardware {

//==============================================================================
/** Control type */
enum class ControlType {
    Fader,          // Linear slider (0-127)
    Knob,           // Rotary encoder or pot
    Button,         // Momentary or toggle
    Encoder,        // Endless rotary encoder
    Pad,            // Velocity-sensitive pad
    TouchStrip,     // Touch-sensitive strip
    Jog,            // Jog wheel
    XYPad           // 2D controller
};

/** Control behavior */
enum class ControlBehavior {
    Absolute,       // Direct value mapping
    Relative,       // Increment/decrement
    Toggle,         // Flip on press
    Momentary,      // Active while held
    RadioButton     // Exclusive in group
};

//==============================================================================
/** MIDI message type for controls */
enum class MIDIMessageType {
    ControlChange,
    NoteOn,
    NoteOff,
    PitchBend,
    Aftertouch,
    PolyAftertouch,
    ProgramChange,
    NRPN,           // Non-Registered Parameter Number
    RPN             // Registered Parameter Number
};

//==============================================================================
/** Parameter target for mapping */
struct ParameterTarget {
    enum class TargetType {
        TrackVolume,
        TrackPan,
        TrackMute,
        TrackSolo,
        TrackArm,
        SendLevel,
        PluginParameter,
        Transport,
        MasterVolume,
        Tempo,
        Custom
    };

    TargetType type = TargetType::Custom;
    juce::String trackId;           // For track-based targets
    int sendIndex = 0;              // For send level
    juce::String pluginId;          // For plugin parameters
    int parameterIndex = 0;         // Plugin parameter index
    juce::String customTarget;      // For custom mappings

    juce::var toVar() const {
        auto obj = new juce::DynamicObject();
        obj->setProperty("type", static_cast<int>(type));
        obj->setProperty("trackId", trackId);
        obj->setProperty("sendIndex", sendIndex);
        obj->setProperty("pluginId", pluginId);
        obj->setProperty("paramIndex", parameterIndex);
        obj->setProperty("customTarget", customTarget);
        return juce::var(obj);
    }

    static ParameterTarget fromVar(const juce::var& v) {
        ParameterTarget target;
        if (auto* obj = v.getDynamicObject()) {
            target.type = static_cast<TargetType>(int(obj->getProperty("type")));
            target.trackId = obj->getProperty("trackId").toString();
            target.sendIndex = obj->getProperty("sendIndex");
            target.pluginId = obj->getProperty("pluginId").toString();
            target.parameterIndex = obj->getProperty("paramIndex");
            target.customTarget = obj->getProperty("customTarget").toString();
        }
        return target;
    }
};

//==============================================================================
/** Single control mapping */
class ControlMapping {
public:
    ControlMapping() {
        id_ = juce::Uuid().toString();
    }

    //==============================================================================
    juce::String getId() const { return id_; }

    juce::String getName() const { return name_; }
    void setName(const juce::String& name) { name_ = name; }

    //==============================================================================
    // MIDI settings
    void setMIDI(int channel, int ccOrNote, MIDIMessageType msgType = MIDIMessageType::ControlChange) {
        midiChannel_ = juce::jlimit(1, 16, channel);
        midiNumber_ = juce::jlimit(0, 127, ccOrNote);
        messageType_ = msgType;
    }

    int getMIDIChannel() const { return midiChannel_; }
    int getMIDINumber() const { return midiNumber_; }
    MIDIMessageType getMessageType() const { return messageType_; }

    //==============================================================================
    // Control settings
    void setControlType(ControlType type) { controlType_ = type; }
    ControlType getControlType() const { return controlType_; }

    void setBehavior(ControlBehavior behavior) { behavior_ = behavior; }
    ControlBehavior getBehavior() const { return behavior_; }

    //==============================================================================
    // Value range
    void setRange(float min, float max) {
        minValue_ = min;
        maxValue_ = max;
    }

    float getMinValue() const { return minValue_; }
    float getMaxValue() const { return maxValue_; }

    /** Scale MIDI value to target range */
    float scaleValue(int midiValue) const {
        float normalized = static_cast<float>(midiValue) / 127.0f;
        return minValue_ + normalized * (maxValue_ - minValue_);
    }

    /** Scale target value to MIDI */
    int scaleToMIDI(float value) const {
        float normalized = (value - minValue_) / (maxValue_ - minValue_);
        return static_cast<int>(normalized * 127.0f);
    }

    //==============================================================================
    // Encoder settings for relative mode
    void setEncoderSensitivity(float sensitivity) {
        encoderSensitivity_ = juce::jlimit(0.01f, 10.0f, sensitivity);
    }

    float getEncoderSensitivity() const { return encoderSensitivity_; }

    void setEncoderMode(int mode) { encoderMode_ = mode; }
    int getEncoderMode() const { return encoderMode_; }

    //==============================================================================
    // Target
    ParameterTarget& getTarget() { return target_; }
    const ParameterTarget& getTarget() const { return target_; }

    //==============================================================================
    // Feedback (for motorized faders, LED rings)
    bool hasFeedback() const { return hasFeedback_; }
    void setHasFeedback(bool feedback) { hasFeedback_ = feedback; }

    //==============================================================================
    // State
    float getCurrentValue() const { return currentValue_; }
    void setCurrentValue(float value) { currentValue_ = value; }

    bool isEnabled() const { return enabled_; }
    void setEnabled(bool enabled) { enabled_ = enabled; }

    //==============================================================================
    // Serialization
    juce::var toVar() const {
        auto obj = new juce::DynamicObject();
        obj->setProperty("id", id_);
        obj->setProperty("name", name_);
        obj->setProperty("midiChannel", midiChannel_);
        obj->setProperty("midiNumber", midiNumber_);
        obj->setProperty("messageType", static_cast<int>(messageType_));
        obj->setProperty("controlType", static_cast<int>(controlType_));
        obj->setProperty("behavior", static_cast<int>(behavior_));
        obj->setProperty("minValue", minValue_);
        obj->setProperty("maxValue", maxValue_);
        obj->setProperty("encoderSensitivity", encoderSensitivity_);
        obj->setProperty("hasFeedback", hasFeedback_);
        obj->setProperty("enabled", enabled_);
        obj->setProperty("target", target_.toVar());
        return juce::var(obj);
    }

    static std::unique_ptr<ControlMapping> fromVar(const juce::var& v) {
        auto mapping = std::make_unique<ControlMapping>();
        if (auto* obj = v.getDynamicObject()) {
            mapping->id_ = obj->getProperty("id").toString();
            mapping->name_ = obj->getProperty("name").toString();
            mapping->midiChannel_ = obj->getProperty("midiChannel");
            mapping->midiNumber_ = obj->getProperty("midiNumber");
            mapping->messageType_ = static_cast<MIDIMessageType>(int(obj->getProperty("messageType")));
            mapping->controlType_ = static_cast<ControlType>(int(obj->getProperty("controlType")));
            mapping->behavior_ = static_cast<ControlBehavior>(int(obj->getProperty("behavior")));
            mapping->minValue_ = obj->getProperty("minValue");
            mapping->maxValue_ = obj->getProperty("maxValue");
            mapping->encoderSensitivity_ = obj->getProperty("encoderSensitivity");
            mapping->hasFeedback_ = obj->getProperty("hasFeedback");
            mapping->enabled_ = obj->getProperty("enabled");
            mapping->target_ = ParameterTarget::fromVar(obj->getProperty("target"));
        }
        return mapping;
    }

private:
    juce::String id_;
    juce::String name_;

    int midiChannel_ = 1;
    int midiNumber_ = 0;
    MIDIMessageType messageType_ = MIDIMessageType::ControlChange;

    ControlType controlType_ = ControlType::Knob;
    ControlBehavior behavior_ = ControlBehavior::Absolute;

    float minValue_ = 0.0f;
    float maxValue_ = 1.0f;
    float encoderSensitivity_ = 1.0f;
    int encoderMode_ = 0;  // 0 = signed, 1 = 2's complement, 2 = offset

    ParameterTarget target_;

    bool hasFeedback_ = false;
    bool enabled_ = true;
    float currentValue_ = 0.0f;
};

//==============================================================================
/** Control surface profile */
class ControlSurfaceProfile {
public:
    ControlSurfaceProfile(const juce::String& name = "New Profile")
        : name_(name)
    {
        id_ = juce::Uuid().toString();
    }

    //==============================================================================
    juce::String getId() const { return id_; }

    juce::String getName() const { return name_; }
    void setName(const juce::String& name) { name_ = name; }

    juce::String getDescription() const { return description_; }
    void setDescription(const juce::String& desc) { description_ = desc; }

    juce::String getManufacturer() const { return manufacturer_; }
    void setManufacturer(const juce::String& mfr) { manufacturer_ = mfr; }

    juce::String getDeviceName() const { return deviceName_; }
    void setDeviceName(const juce::String& device) { deviceName_ = device; }

    //==============================================================================
    /** Add mapping */
    ControlMapping* addMapping() {
        auto mapping = std::make_unique<ControlMapping>();
        ControlMapping* ptr = mapping.get();
        mappings_.push_back(std::move(mapping));
        return ptr;
    }

    /** Add existing mapping */
    void addMapping(std::unique_ptr<ControlMapping> mapping) {
        mappings_.push_back(std::move(mapping));
    }

    /** Remove mapping */
    void removeMapping(const juce::String& id) {
        mappings_.erase(
            std::remove_if(mappings_.begin(), mappings_.end(),
                           [&id](const auto& m) { return m->getId() == id; }),
            mappings_.end());
    }

    /** Get mapping by ID */
    ControlMapping* getMapping(const juce::String& id) {
        for (auto& m : mappings_) {
            if (m->getId() == id) return m.get();
        }
        return nullptr;
    }

    /** Find mapping by MIDI message */
    ControlMapping* findMapping(int channel, int ccOrNote, MIDIMessageType type) {
        for (auto& m : mappings_) {
            if (m->getMIDIChannel() == channel &&
                m->getMIDINumber() == ccOrNote &&
                m->getMessageType() == type) {
                return m.get();
            }
        }
        return nullptr;
    }

    /** Get all mappings */
    std::vector<ControlMapping*> getAllMappings() {
        std::vector<ControlMapping*> result;
        for (auto& m : mappings_) {
            result.push_back(m.get());
        }
        return result;
    }

    //==============================================================================
    /** Banks for multi-page surfaces */
    int getCurrentBank() const { return currentBank_; }
    void setCurrentBank(int bank) { currentBank_ = juce::jlimit(0, numBanks_ - 1, bank); }

    int getNumBanks() const { return numBanks_; }
    void setNumBanks(int num) { numBanks_ = std::max(1, num); }

    void nextBank() { setCurrentBank(currentBank_ + 1); }
    void prevBank() { setCurrentBank(currentBank_ - 1); }

    //==============================================================================
    // Serialization
    juce::var toVar() const {
        auto obj = new juce::DynamicObject();
        obj->setProperty("id", id_);
        obj->setProperty("name", name_);
        obj->setProperty("description", description_);
        obj->setProperty("manufacturer", manufacturer_);
        obj->setProperty("deviceName", deviceName_);
        obj->setProperty("numBanks", numBanks_);

        juce::var mappingsArray;
        for (const auto& m : mappings_) {
            mappingsArray.append(m->toVar());
        }
        obj->setProperty("mappings", mappingsArray);

        return juce::var(obj);
    }

    static std::unique_ptr<ControlSurfaceProfile> fromVar(const juce::var& v) {
        auto profile = std::make_unique<ControlSurfaceProfile>();
        if (auto* obj = v.getDynamicObject()) {
            profile->id_ = obj->getProperty("id").toString();
            profile->name_ = obj->getProperty("name").toString();
            profile->description_ = obj->getProperty("description").toString();
            profile->manufacturer_ = obj->getProperty("manufacturer").toString();
            profile->deviceName_ = obj->getProperty("deviceName").toString();
            profile->numBanks_ = obj->getProperty("numBanks");

            if (auto* mappingsArray = obj->getProperty("mappings").getArray()) {
                for (const auto& m : *mappingsArray) {
                    profile->mappings_.push_back(ControlMapping::fromVar(m));
                }
            }
        }
        return profile;
    }

private:
    juce::String id_;
    juce::String name_;
    juce::String description_;
    juce::String manufacturer_;
    juce::String deviceName_;

    std::vector<std::unique_ptr<ControlMapping>> mappings_;

    int currentBank_ = 0;
    int numBanks_ = 1;
};

//==============================================================================
/** Control Surface Manager with MIDI Learn */
class ControlSurfaceManager {
public:
    ControlSurfaceManager() {
        createBuiltInProfiles();
    }

    //==============================================================================
    /** Create profile */
    ControlSurfaceProfile* createProfile(const juce::String& name) {
        auto profile = std::make_unique<ControlSurfaceProfile>(name);
        ControlSurfaceProfile* ptr = profile.get();
        profiles_[profile->getId()] = std::move(profile);
        return ptr;
    }

    /** Get profile by ID */
    ControlSurfaceProfile* getProfile(const juce::String& id) {
        auto it = profiles_.find(id);
        return it != profiles_.end() ? it->second.get() : nullptr;
    }

    /** Get all profiles */
    std::vector<ControlSurfaceProfile*> getAllProfiles() {
        std::vector<ControlSurfaceProfile*> result;
        for (auto& pair : profiles_) {
            result.push_back(pair.second.get());
        }
        return result;
    }

    /** Set active profile */
    void setActiveProfile(const juce::String& id) {
        activeProfile_ = getProfile(id);
    }

    ControlSurfaceProfile* getActiveProfile() { return activeProfile_; }

    //==============================================================================
    /** Start MIDI learn mode */
    void startMIDILearn(ControlMapping* targetMapping) {
        learnMode_ = true;
        learnTarget_ = targetMapping;
    }

    /** Stop MIDI learn mode */
    void stopMIDILearn() {
        learnMode_ = false;
        learnTarget_ = nullptr;
    }

    bool isLearning() const { return learnMode_; }

    //==============================================================================
    /** Process incoming MIDI message */
    void processMIDIMessage(const juce::MidiMessage& message) {
        int channel = message.getChannel();
        int number = 0;
        int value = 0;
        MIDIMessageType type = MIDIMessageType::ControlChange;

        if (message.isController()) {
            type = MIDIMessageType::ControlChange;
            number = message.getControllerNumber();
            value = message.getControllerValue();
        } else if (message.isNoteOn()) {
            type = MIDIMessageType::NoteOn;
            number = message.getNoteNumber();
            value = message.getVelocity();
        } else if (message.isNoteOff()) {
            type = MIDIMessageType::NoteOff;
            number = message.getNoteNumber();
            value = 0;
        } else if (message.isPitchWheel()) {
            type = MIDIMessageType::PitchBend;
            value = message.getPitchWheelValue();
        } else if (message.isAftertouch()) {
            type = MIDIMessageType::Aftertouch;
            value = message.getAfterTouchValue();
        }

        // Handle learn mode
        if (learnMode_ && learnTarget_) {
            learnTarget_->setMIDI(channel, number, type);
            stopMIDILearn();
            if (onMIDILearned) onMIDILearned(learnTarget_);
            return;
        }

        // Find mapping and trigger
        if (activeProfile_) {
            if (auto* mapping = activeProfile_->findMapping(channel, number, type)) {
                if (mapping->isEnabled()) {
                    handleMapping(mapping, value);
                }
            }
        }
    }

    //==============================================================================
    /** Send feedback to controller */
    void sendFeedback(ControlMapping* mapping, float value) {
        if (!mapping || !mapping->hasFeedback()) return;

        int midiValue = mapping->scaleToMIDI(value);

        juce::MidiMessage message;
        switch (mapping->getMessageType()) {
            case MIDIMessageType::ControlChange:
                message = juce::MidiMessage::controllerEvent(
                    mapping->getMIDIChannel(), mapping->getMIDINumber(), midiValue);
                break;

            case MIDIMessageType::NoteOn:
                message = juce::MidiMessage::noteOn(
                    mapping->getMIDIChannel(), mapping->getMIDINumber(), (juce::uint8)midiValue);
                break;

            default:
                return;
        }

        if (onSendMIDI) onSendMIDI(message);
    }

    //==============================================================================
    /** Save profiles to file */
    bool saveProfiles(const juce::File& file) {
        juce::var profilesArray;
        for (auto& pair : profiles_) {
            profilesArray.append(pair.second->toVar());
        }

        auto obj = new juce::DynamicObject();
        obj->setProperty("version", 1);
        obj->setProperty("profiles", profilesArray);

        juce::FileOutputStream stream(file);
        if (stream.openedOk()) {
            juce::JSON::writeToStream(stream, juce::var(obj));
            return true;
        }
        return false;
    }

    /** Load profiles from file */
    bool loadProfiles(const juce::File& file) {
        if (!file.existsAsFile()) return false;

        juce::var data = juce::JSON::parse(file);
        if (!data.isObject()) return false;

        auto* obj = data.getDynamicObject();
        if (!obj) return false;

        if (auto* profilesArray = obj->getProperty("profiles").getArray()) {
            for (const auto& p : *profilesArray) {
                auto profile = ControlSurfaceProfile::fromVar(p);
                if (profile) {
                    profiles_[profile->getId()] = std::move(profile);
                }
            }
        }

        return true;
    }

    //==============================================================================
    // Callbacks
    std::function<void(ControlMapping*, float)> onMappingTriggered;
    std::function<void(ControlMapping*)> onMIDILearned;
    std::function<void(const juce::MidiMessage&)> onSendMIDI;

private:
    void handleMapping(ControlMapping* mapping, int midiValue) {
        float value = 0.0f;

        switch (mapping->getBehavior()) {
            case ControlBehavior::Absolute:
                value = mapping->scaleValue(midiValue);
                break;

            case ControlBehavior::Relative: {
                // Handle relative encoder values
                int delta = 0;
                if (mapping->getEncoderMode() == 0) {
                    // Signed mode (64 = no change)
                    delta = midiValue - 64;
                } else if (mapping->getEncoderMode() == 1) {
                    // 2's complement (127 = -1, 1 = +1)
                    delta = midiValue < 64 ? midiValue : midiValue - 128;
                }

                float currentValue = mapping->getCurrentValue();
                value = juce::jlimit(mapping->getMinValue(), mapping->getMaxValue(),
                                     currentValue + delta * mapping->getEncoderSensitivity() * 0.01f);
                break;
            }

            case ControlBehavior::Toggle:
                if (midiValue > 0) {
                    value = mapping->getCurrentValue() > 0.5f ? 0.0f : 1.0f;
                } else {
                    return;  // Ignore note-off for toggle
                }
                break;

            case ControlBehavior::Momentary:
                value = midiValue > 0 ? 1.0f : 0.0f;
                break;

            default:
                value = mapping->scaleValue(midiValue);
        }

        mapping->setCurrentValue(value);

        if (onMappingTriggered) {
            onMappingTriggered(mapping, value);
        }
    }

    void createBuiltInProfiles() {
        // Generic MIDI Controller
        {
            auto profile = std::make_unique<ControlSurfaceProfile>("Generic MIDI");
            profile->setDescription("Basic CC mapping for any MIDI controller");

            // Add 8 fader mappings
            for (int i = 0; i < 8; ++i) {
                auto* mapping = profile->addMapping();
                mapping->setName("Fader " + juce::String(i + 1));
                mapping->setMIDI(1, i, MIDIMessageType::ControlChange);
                mapping->setControlType(ControlType::Fader);
                mapping->getTarget().type = ParameterTarget::TargetType::TrackVolume;
            }

            // Add 8 knob mappings
            for (int i = 0; i < 8; ++i) {
                auto* mapping = profile->addMapping();
                mapping->setName("Knob " + juce::String(i + 1));
                mapping->setMIDI(1, 16 + i, MIDIMessageType::ControlChange);
                mapping->setControlType(ControlType::Knob);
                mapping->getTarget().type = ParameterTarget::TargetType::TrackPan;
            }

            profiles_[profile->getId()] = std::move(profile);
        }

        // Mackie Control Universal
        {
            auto profile = std::make_unique<ControlSurfaceProfile>("Mackie Control Universal");
            profile->setManufacturer("Mackie");
            profile->setDeviceName("Control Universal");
            profile->setDescription("MCU Protocol compatible controller");
            profile->setNumBanks(8);

            // MCU uses specific pitchbend for faders
            for (int i = 0; i < 8; ++i) {
                auto* mapping = profile->addMapping();
                mapping->setName("Channel " + juce::String(i + 1) + " Fader");
                mapping->setMIDI(1, i, MIDIMessageType::PitchBend);
                mapping->setControlType(ControlType::Fader);
                mapping->setHasFeedback(true);
                mapping->getTarget().type = ParameterTarget::TargetType::TrackVolume;
            }

            profiles_[profile->getId()] = std::move(profile);
        }

        // Novation Launchpad
        {
            auto profile = std::make_unique<ControlSurfaceProfile>("Novation Launchpad");
            profile->setManufacturer("Novation");
            profile->setDeviceName("Launchpad");
            profile->setDescription("Clip launch and pad control");

            // 64 pads in 8x8 grid
            for (int row = 0; row < 8; ++row) {
                for (int col = 0; col < 8; ++col) {
                    auto* mapping = profile->addMapping();
                    mapping->setName("Pad " + juce::String(row * 8 + col + 1));
                    mapping->setMIDI(1, row * 16 + col, MIDIMessageType::NoteOn);
                    mapping->setControlType(ControlType::Pad);
                    mapping->setBehavior(ControlBehavior::Momentary);
                    mapping->setHasFeedback(true);
                    mapping->getTarget().type = ParameterTarget::TargetType::Custom;
                    mapping->getTarget().customTarget = "clip_launch";
                }
            }

            profiles_[profile->getId()] = std::move(profile);
        }
    }

    std::map<juce::String, std::unique_ptr<ControlSurfaceProfile>> profiles_;
    ControlSurfaceProfile* activeProfile_ = nullptr;

    bool learnMode_ = false;
    ControlMapping* learnTarget_ = nullptr;
};

} // namespace Hardware
} // namespace Echoelmusic
