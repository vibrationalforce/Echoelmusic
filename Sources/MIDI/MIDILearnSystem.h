#pragma once

#include <JuceHeader.h>
#include <vector>
#include <map>
#include <set>
#include <memory>
#include <functional>

/**
 * MIDILearnSystem - Professional MIDI Controller Mapping
 *
 * Comprehensive MIDI learn and mapping system:
 * - Click-to-learn parameter mapping
 * - CC, note, program change, pitch bend mapping
 * - NRPN and RPN support
 * - Multiple controller profiles
 * - Curve shaping (linear, log, exp, S-curve)
 * - Range limiting and inversion
 * - Soft takeover to avoid jumps
 * - Button modes (toggle, momentary, trigger)
 * - Multi-parameter mapping
 * - Save/load mappings
 *
 * Inspired by: Ableton Live, Bitwig, Native Instruments
 */

namespace Echoelmusic {
namespace MIDI {

//==============================================================================
// MIDI Message Type
//==============================================================================

enum class MIDIMessageType
{
    ControlChange,       // CC (0-127)
    Note,               // Note on/off
    ProgramChange,      // Program change
    PitchBend,          // Pitch wheel
    Aftertouch,         // Channel aftertouch
    PolyAftertouch,     // Polyphonic aftertouch
    NRPN,               // Non-Registered Parameter Number
    RPN                 // Registered Parameter Number
};

//==============================================================================
// Curve Type for Value Mapping
//==============================================================================

enum class CurveType
{
    Linear,
    Logarithmic,
    Exponential,
    SCurve,
    ReversedLinear,
    ReversedLog,
    ReversedExp,
    Custom
};

//==============================================================================
// Button Mode
//==============================================================================

enum class ButtonMode
{
    Momentary,          // Value while held, resets on release
    Toggle,             // Alternates between min/max
    Trigger,            // Sends max value briefly
    Gate,               // Min on press, max on release (or vice versa)
    Increment,          // Each press increases value
    Decrement           // Each press decreases value
};

//==============================================================================
// MIDI Mapping
//==============================================================================

struct MIDIMapping
{
    juce::Uuid uuid;
    juce::String name;
    juce::String description;

    // MIDI source
    MIDIMessageType messageType = MIDIMessageType::ControlChange;
    int channel = 0;               // 0-15 (0 = omni)
    int controller = 0;            // CC number, note number, etc.

    // For NRPN/RPN
    int msbController = 0;
    int lsbController = 0;

    // Target parameter
    juce::String targetParameter;   // Parameter ID or path
    juce::String targetComponent;   // Component/module name

    // Value transformation
    CurveType curve = CurveType::Linear;
    float minValue = 0.0f;          // Output range min
    float maxValue = 1.0f;          // Output range max
    bool inverted = false;

    // For buttons/notes
    ButtonMode buttonMode = ButtonMode::Momentary;

    // Soft takeover
    bool softTakeoverEnabled = true;
    float softTakeoverThreshold = 0.05f;

    // Step (for incremental controls)
    float stepSize = 0.01f;

    // State
    float lastMIDIValue = 0.0f;
    float lastOutputValue = 0.0f;
    bool softTakeoverLocked = false;

    MIDIMapping()
    {
        uuid = juce::Uuid();
    }
};

//==============================================================================
// Controller Profile
//==============================================================================

struct ControllerProfile
{
    juce::String name;
    juce::String manufacturer;
    juce::String model;
    juce::Uuid uuid;

    std::vector<MIDIMapping> mappings;

    // Device identification
    juce::String midiInputName;
    juce::String midiOutputName;

    // Auto-detection SysEx
    std::vector<uint8_t> identitySysEx;

    ControllerProfile()
    {
        uuid = juce::Uuid();
    }

    ControllerProfile(const juce::String& profileName)
        : name(profileName)
    {
        uuid = juce::Uuid();
    }
};

//==============================================================================
// MIDI Learn State
//==============================================================================

struct LearnState
{
    bool isLearning = false;
    juce::String targetParameter;
    juce::String targetComponent;
    std::function<void(const MIDIMapping&)> onMappingCreated;

    // Last received MIDI for display
    MIDIMessageType lastMessageType = MIDIMessageType::ControlChange;
    int lastChannel = 0;
    int lastController = 0;
    int lastValue = 0;
};

//==============================================================================
// MIDI Learn System
//==============================================================================

class MIDILearnSystem
{
public:
    //==========================================================================
    // Constructor
    //==========================================================================

    MIDILearnSystem() = default;

    //==========================================================================
    // Profile Management
    //==========================================================================

    int createProfile(const juce::String& name)
    {
        ControllerProfile profile(name);
        profiles.push_back(profile);
        return static_cast<int>(profiles.size()) - 1;
    }

    void deleteProfile(int index)
    {
        if (index >= 0 && index < static_cast<int>(profiles.size()))
            profiles.erase(profiles.begin() + index);
    }

    void selectProfile(int index)
    {
        if (index >= 0 && index < static_cast<int>(profiles.size()))
            currentProfileIndex = index;
    }

    ControllerProfile* getCurrentProfile()
    {
        if (currentProfileIndex >= 0 && currentProfileIndex < static_cast<int>(profiles.size()))
            return &profiles[currentProfileIndex];
        return nullptr;
    }

    const std::vector<ControllerProfile>& getAllProfiles() const { return profiles; }

    //==========================================================================
    // Learn Mode
    //==========================================================================

    /** Start learning mode for a parameter */
    void startLearning(const juce::String& targetParameter,
                       const juce::String& targetComponent = "",
                       std::function<void(const MIDIMapping&)> callback = nullptr)
    {
        learnState.isLearning = true;
        learnState.targetParameter = targetParameter;
        learnState.targetComponent = targetComponent;
        learnState.onMappingCreated = callback;

        if (onLearningStarted)
            onLearningStarted(targetParameter, targetComponent);
    }

    /** Stop learning mode without creating mapping */
    void cancelLearning()
    {
        learnState.isLearning = false;

        if (onLearningCancelled)
            onLearningCancelled();
    }

    /** Check if currently learning */
    bool isLearning() const { return learnState.isLearning; }

    /** Get learn target parameter */
    juce::String getLearnTarget() const { return learnState.targetParameter; }

    //==========================================================================
    // MIDI Input Processing
    //==========================================================================

    /** Process incoming MIDI message */
    void processMIDIMessage(const juce::MidiMessage& message)
    {
        // Learning mode
        if (learnState.isLearning)
        {
            processLearnMessage(message);
            return;
        }

        // Normal mapping mode
        processMappedMessage(message);
    }

    //==========================================================================
    // Mapping Management
    //==========================================================================

    /** Add a mapping to current profile */
    void addMapping(const MIDIMapping& mapping)
    {
        auto* profile = getCurrentProfile();
        if (profile)
            profile->mappings.push_back(mapping);
    }

    /** Remove a mapping by index */
    void removeMapping(int index)
    {
        auto* profile = getCurrentProfile();
        if (profile && index >= 0 && index < static_cast<int>(profile->mappings.size()))
            profile->mappings.erase(profile->mappings.begin() + index);
    }

    /** Remove all mappings for a parameter */
    void removeMappingsForParameter(const juce::String& parameter)
    {
        auto* profile = getCurrentProfile();
        if (!profile)
            return;

        profile->mappings.erase(
            std::remove_if(profile->mappings.begin(), profile->mappings.end(),
                [&](const MIDIMapping& m) { return m.targetParameter == parameter; }),
            profile->mappings.end());
    }

    /** Find mappings for a parameter */
    std::vector<MIDIMapping*> findMappingsForParameter(const juce::String& parameter)
    {
        std::vector<MIDIMapping*> result;
        auto* profile = getCurrentProfile();
        if (!profile)
            return result;

        for (auto& mapping : profile->mappings)
        {
            if (mapping.targetParameter == parameter)
                result.push_back(&mapping);
        }

        return result;
    }

    /** Check if parameter has mapping */
    bool hasMapping(const juce::String& parameter) const
    {
        if (currentProfileIndex < 0 || currentProfileIndex >= static_cast<int>(profiles.size()))
            return false;

        const auto& profile = profiles[currentProfileIndex];
        for (const auto& mapping : profile.mappings)
        {
            if (mapping.targetParameter == parameter)
                return true;
        }
        return false;
    }

    //==========================================================================
    // Save/Load
    //==========================================================================

    bool saveProfile(int index, const juce::File& file) const
    {
        if (index < 0 || index >= static_cast<int>(profiles.size()))
            return false;

        const auto& profile = profiles[index];

        juce::var data;
        data.append(juce::var(profile.name));
        data.append(juce::var(profile.manufacturer));
        data.append(juce::var(profile.model));

        juce::var mappingsData;
        for (const auto& mapping : profile.mappings)
        {
            juce::var m;
            m.append(juce::var(mapping.name));
            m.append(juce::var(static_cast<int>(mapping.messageType)));
            m.append(juce::var(mapping.channel));
            m.append(juce::var(mapping.controller));
            m.append(juce::var(mapping.targetParameter));
            m.append(juce::var(mapping.targetComponent));
            m.append(juce::var(static_cast<int>(mapping.curve)));
            m.append(juce::var(mapping.minValue));
            m.append(juce::var(mapping.maxValue));
            m.append(juce::var(mapping.inverted));
            m.append(juce::var(static_cast<int>(mapping.buttonMode)));
            m.append(juce::var(mapping.softTakeoverEnabled));
            mappingsData.append(m);
        }
        data.append(mappingsData);

        return file.replaceWithText(juce::JSON::toString(data));
    }

    int loadProfile(const juce::File& file)
    {
        juce::var data = juce::JSON::parse(file.loadFileAsString());
        if (!data.isArray())
            return -1;

        ControllerProfile profile;
        profile.name = data[0].toString();
        profile.manufacturer = data[1].toString();
        profile.model = data[2].toString();

        juce::var mappingsData = data[3];
        if (mappingsData.isArray())
        {
            for (int i = 0; i < mappingsData.size(); ++i)
            {
                juce::var m = mappingsData[i];
                MIDIMapping mapping;
                mapping.name = m[0].toString();
                mapping.messageType = static_cast<MIDIMessageType>(static_cast<int>(m[1]));
                mapping.channel = static_cast<int>(m[2]);
                mapping.controller = static_cast<int>(m[3]);
                mapping.targetParameter = m[4].toString();
                mapping.targetComponent = m[5].toString();
                mapping.curve = static_cast<CurveType>(static_cast<int>(m[6]));
                mapping.minValue = static_cast<float>(m[7]);
                mapping.maxValue = static_cast<float>(m[8]);
                mapping.inverted = static_cast<bool>(m[9]);
                mapping.buttonMode = static_cast<ButtonMode>(static_cast<int>(m[10]));
                mapping.softTakeoverEnabled = static_cast<bool>(m[11]);
                profile.mappings.push_back(mapping);
            }
        }

        profiles.push_back(profile);
        return static_cast<int>(profiles.size()) - 1;
    }

    //==========================================================================
    // Preset Profiles
    //==========================================================================

    void createGenericProfile()
    {
        ControllerProfile profile("Generic MIDI");
        profile.manufacturer = "Generic";

        // Map CC 1 (mod wheel) to modulation
        MIDIMapping modWheel;
        modWheel.name = "Mod Wheel";
        modWheel.messageType = MIDIMessageType::ControlChange;
        modWheel.controller = 1;
        modWheel.targetParameter = "modulation";
        profile.mappings.push_back(modWheel);

        // Map CC 7 (volume) to master volume
        MIDIMapping volume;
        volume.name = "Volume";
        volume.messageType = MIDIMessageType::ControlChange;
        volume.controller = 7;
        volume.targetParameter = "masterVolume";
        profile.mappings.push_back(volume);

        // Map CC 10 (pan) to pan
        MIDIMapping pan;
        pan.name = "Pan";
        pan.messageType = MIDIMessageType::ControlChange;
        pan.controller = 10;
        pan.targetParameter = "pan";
        pan.minValue = -1.0f;
        pan.maxValue = 1.0f;
        profile.mappings.push_back(pan);

        profiles.push_back(profile);
    }

    //==========================================================================
    // Callbacks
    //==========================================================================

    std::function<void(const juce::String&, const juce::String&)> onLearningStarted;
    std::function<void()> onLearningCancelled;
    std::function<void(const MIDIMapping&)> onMappingCreated;
    std::function<void(const juce::String&, float)> onParameterChanged;
    std::function<void(MIDIMessageType, int, int, int)> onMIDIReceived;

private:
    std::vector<ControllerProfile> profiles;
    int currentProfileIndex = -1;

    LearnState learnState;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void processLearnMessage(const juce::MidiMessage& message)
    {
        MIDIMapping mapping;
        mapping.targetParameter = learnState.targetParameter;
        mapping.targetComponent = learnState.targetComponent;

        if (message.isController())
        {
            mapping.messageType = MIDIMessageType::ControlChange;
            mapping.channel = message.getChannel();
            mapping.controller = message.getControllerNumber();
            mapping.name = "CC " + juce::String(mapping.controller);

            learnState.lastMessageType = MIDIMessageType::ControlChange;
            learnState.lastChannel = mapping.channel;
            learnState.lastController = mapping.controller;
            learnState.lastValue = message.getControllerValue();
        }
        else if (message.isNoteOn())
        {
            mapping.messageType = MIDIMessageType::Note;
            mapping.channel = message.getChannel();
            mapping.controller = message.getNoteNumber();
            mapping.name = "Note " + juce::MidiMessage::getMidiNoteName(mapping.controller, true, true, 4);
            mapping.buttonMode = ButtonMode::Toggle;

            learnState.lastMessageType = MIDIMessageType::Note;
            learnState.lastChannel = mapping.channel;
            learnState.lastController = mapping.controller;
            learnState.lastValue = message.getVelocity();
        }
        else if (message.isPitchWheel())
        {
            mapping.messageType = MIDIMessageType::PitchBend;
            mapping.channel = message.getChannel();
            mapping.name = "Pitch Bend";
            mapping.minValue = -1.0f;
            mapping.maxValue = 1.0f;

            learnState.lastMessageType = MIDIMessageType::PitchBend;
            learnState.lastChannel = mapping.channel;
            learnState.lastValue = message.getPitchWheelValue();
        }
        else if (message.isAftertouch())
        {
            mapping.messageType = MIDIMessageType::Aftertouch;
            mapping.channel = message.getChannel();
            mapping.name = "Aftertouch";

            learnState.lastMessageType = MIDIMessageType::Aftertouch;
            learnState.lastChannel = mapping.channel;
            learnState.lastValue = message.getAfterTouchValue();
        }
        else if (message.isProgramChange())
        {
            mapping.messageType = MIDIMessageType::ProgramChange;
            mapping.channel = message.getChannel();
            mapping.controller = message.getProgramChangeNumber();
            mapping.name = "Program " + juce::String(mapping.controller);

            learnState.lastMessageType = MIDIMessageType::ProgramChange;
            learnState.lastChannel = mapping.channel;
            learnState.lastController = mapping.controller;
        }
        else
        {
            return;  // Unknown message type
        }

        // End learning
        learnState.isLearning = false;

        // Add to profile
        addMapping(mapping);

        // Callbacks
        if (learnState.onMappingCreated)
            learnState.onMappingCreated(mapping);

        if (onMappingCreated)
            onMappingCreated(mapping);
    }

    void processMappedMessage(const juce::MidiMessage& message)
    {
        auto* profile = getCurrentProfile();
        if (!profile)
            return;

        MIDIMessageType msgType;
        int channel = message.getChannel();
        int controller = 0;
        float rawValue = 0.0f;

        if (message.isController())
        {
            msgType = MIDIMessageType::ControlChange;
            controller = message.getControllerNumber();
            rawValue = message.getControllerValue() / 127.0f;
        }
        else if (message.isNoteOn())
        {
            msgType = MIDIMessageType::Note;
            controller = message.getNoteNumber();
            rawValue = 1.0f;
        }
        else if (message.isNoteOff())
        {
            msgType = MIDIMessageType::Note;
            controller = message.getNoteNumber();
            rawValue = 0.0f;
        }
        else if (message.isPitchWheel())
        {
            msgType = MIDIMessageType::PitchBend;
            rawValue = (message.getPitchWheelValue() - 8192) / 8192.0f;
        }
        else if (message.isAftertouch())
        {
            msgType = MIDIMessageType::Aftertouch;
            rawValue = message.getAfterTouchValue() / 127.0f;
        }
        else
        {
            return;
        }

        // Notify
        if (onMIDIReceived)
            onMIDIReceived(msgType, channel, controller, static_cast<int>(rawValue * 127));

        // Find matching mappings
        for (auto& mapping : profile->mappings)
        {
            if (mapping.messageType != msgType)
                continue;
            if (mapping.channel != 0 && mapping.channel != channel)
                continue;
            if (mapping.messageType == MIDIMessageType::ControlChange ||
                mapping.messageType == MIDIMessageType::Note)
            {
                if (mapping.controller != controller)
                    continue;
            }

            // Process mapping
            float outputValue = processMappingValue(mapping, rawValue, message.isNoteOn());

            // Notify
            if (onParameterChanged)
                onParameterChanged(mapping.targetParameter, outputValue);
        }
    }

    float processMappingValue(MIDIMapping& mapping, float rawValue, bool isNoteOn)
    {
        float value = rawValue;

        // Button mode processing
        if (mapping.messageType == MIDIMessageType::Note)
        {
            switch (mapping.buttonMode)
            {
                case ButtonMode::Toggle:
                    if (isNoteOn)
                    {
                        mapping.lastOutputValue = (mapping.lastOutputValue < 0.5f) ?
                            mapping.maxValue : mapping.minValue;
                    }
                    return mapping.lastOutputValue;

                case ButtonMode::Momentary:
                    value = isNoteOn ? 1.0f : 0.0f;
                    break;

                case ButtonMode::Trigger:
                    if (isNoteOn)
                    {
                        // Would trigger and reset
                        return mapping.maxValue;
                    }
                    return mapping.lastOutputValue;

                case ButtonMode::Gate:
                    value = isNoteOn ? mapping.maxValue : mapping.minValue;
                    break;

                case ButtonMode::Increment:
                    if (isNoteOn)
                    {
                        mapping.lastOutputValue = std::min(mapping.maxValue,
                            mapping.lastOutputValue + mapping.stepSize);
                    }
                    return mapping.lastOutputValue;

                case ButtonMode::Decrement:
                    if (isNoteOn)
                    {
                        mapping.lastOutputValue = std::max(mapping.minValue,
                            mapping.lastOutputValue - mapping.stepSize);
                    }
                    return mapping.lastOutputValue;
            }
        }

        // Soft takeover
        if (mapping.softTakeoverEnabled)
        {
            if (mapping.softTakeoverLocked)
            {
                // Check if we've caught up
                if (std::abs(value - mapping.lastOutputValue) < mapping.softTakeoverThreshold)
                {
                    mapping.softTakeoverLocked = false;
                }
                else
                {
                    return mapping.lastOutputValue;  // Ignore until caught up
                }
            }
            else
            {
                // Check for jump
                float scaledValue = applyValueCurve(value, mapping.curve);
                scaledValue = mapping.minValue + scaledValue * (mapping.maxValue - mapping.minValue);

                if (std::abs(scaledValue - mapping.lastOutputValue) > mapping.softTakeoverThreshold * 5)
                {
                    mapping.softTakeoverLocked = true;
                    return mapping.lastOutputValue;
                }
            }
        }

        // Apply curve
        value = applyValueCurve(value, mapping.curve);

        // Apply range
        if (mapping.inverted)
            value = 1.0f - value;

        value = mapping.minValue + value * (mapping.maxValue - mapping.minValue);

        mapping.lastMIDIValue = rawValue;
        mapping.lastOutputValue = value;

        return value;
    }

    float applyValueCurve(float value, CurveType curve)
    {
        switch (curve)
        {
            case CurveType::Linear:
                return value;

            case CurveType::Logarithmic:
                return std::log10(1.0f + value * 9.0f) / std::log10(10.0f);

            case CurveType::Exponential:
                return (std::pow(10.0f, value) - 1.0f) / 9.0f;

            case CurveType::SCurve:
                return value * value * (3.0f - 2.0f * value);

            case CurveType::ReversedLinear:
                return 1.0f - value;

            case CurveType::ReversedLog:
                return 1.0f - std::log10(1.0f + value * 9.0f) / std::log10(10.0f);

            case CurveType::ReversedExp:
                return 1.0f - (std::pow(10.0f, value) - 1.0f) / 9.0f;

            case CurveType::Custom:
            default:
                return value;
        }
    }

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MIDILearnSystem)
};

} // namespace MIDI
} // namespace Echoelmusic
