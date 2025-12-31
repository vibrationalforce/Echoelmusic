#pragma once

#include <JuceHeader.h>
#include <vector>
#include <map>
#include <functional>
#include <memory>
#include <atomic>
#include <cmath>

namespace Echoelmusic {
namespace Automation {

//==============================================================================
// MIDI Automation Types
//==============================================================================
enum class MIDIMessageType {
    NoteOn,
    NoteOff,
    ControlChange,
    ProgramChange,
    PitchBend,
    Aftertouch,
    ChannelPressure,
    SysEx,
    Clock,
    Start,
    Stop,
    Continue
};

struct MIDIMapping {
    int channel = 0;           // 0-15, or -1 for omni
    int ccNumber = -1;         // CC number for CC messages
    int noteNumber = -1;       // Note number for note messages
    float minValue = 0.0f;
    float maxValue = 1.0f;
    bool invert = false;
    float curve = 1.0f;        // 1.0 = linear, <1 = log, >1 = exp

    float applyMapping(float rawValue) const {
        float normalized = rawValue / 127.0f;
        if (invert) normalized = 1.0f - normalized;

        // Apply curve
        if (curve != 1.0f) {
            normalized = std::pow(normalized, curve);
        }

        return minValue + normalized * (maxValue - minValue);
    }
};

//==============================================================================
// MPE (MIDI Polyphonic Expression) Support
//==============================================================================
struct MPENote {
    int noteNumber = 60;
    int channel = 0;           // Per-note channel (1-15 in MPE)
    float pressure = 0.0f;     // Z-axis / aftertouch
    float slide = 0.5f;        // Y-axis / CC74
    float pitchBend = 0.0f;    // X-axis / pitch bend (-1 to 1)
    float strike = 0.0f;       // Initial velocity
    float lift = 0.0f;         // Release velocity
    bool isActive = false;

    // Calculated frequency with pitch bend
    float getFrequency(float pitchBendRange = 48.0f) const {
        float semitones = noteNumber + (pitchBend * pitchBendRange);
        return 440.0f * std::pow(2.0f, (semitones - 69.0f) / 12.0f);
    }
};

struct MPEZone {
    int masterChannel = 0;     // 0 or 15
    int numMemberChannels = 15;
    float pitchBendRange = 48.0f;  // Semitones

    bool isLowerZone() const { return masterChannel == 0; }
    bool isUpperZone() const { return masterChannel == 15; }

    bool isMemberChannel(int channel) const {
        if (isLowerZone()) {
            return channel >= 1 && channel <= numMemberChannels;
        } else {
            return channel >= (15 - numMemberChannels) && channel < 15;
        }
    }
};

class MPEProcessor {
public:
    static constexpr int MAX_MPE_VOICES = 15;

    void processMessage(const juce::MidiMessage& msg) {
        int channel = msg.getChannel() - 1;  // 0-indexed

        if (msg.isNoteOn()) {
            // Find free voice or steal oldest
            int voiceIndex = findFreeVoice();
            if (voiceIndex >= 0) {
                voices[voiceIndex].noteNumber = msg.getNoteNumber();
                voices[voiceIndex].channel = channel;
                voices[voiceIndex].strike = msg.getVelocity() / 127.0f;
                voices[voiceIndex].pressure = 0.0f;
                voices[voiceIndex].slide = 0.5f;
                voices[voiceIndex].pitchBend = 0.0f;
                voices[voiceIndex].isActive = true;

                if (onNoteStart) onNoteStart(voiceIndex, voices[voiceIndex]);
            }
        }
        else if (msg.isNoteOff()) {
            int voiceIndex = findVoiceForChannel(channel);
            if (voiceIndex >= 0) {
                voices[voiceIndex].lift = msg.getVelocity() / 127.0f;
                voices[voiceIndex].isActive = false;

                if (onNoteEnd) onNoteEnd(voiceIndex, voices[voiceIndex]);
            }
        }
        else if (msg.isChannelPressure() || msg.isAftertouch()) {
            int voiceIndex = findVoiceForChannel(channel);
            if (voiceIndex >= 0) {
                voices[voiceIndex].pressure = msg.getChannelPressureValue() / 127.0f;
                if (onPressureChange) onPressureChange(voiceIndex, voices[voiceIndex]);
            }
        }
        else if (msg.isPitchWheel()) {
            int voiceIndex = findVoiceForChannel(channel);
            if (voiceIndex >= 0) {
                // Convert 14-bit pitch bend to -1 to 1
                int pitchValue = msg.getPitchWheelValue();
                voices[voiceIndex].pitchBend = (pitchValue - 8192) / 8192.0f;
                if (onPitchBendChange) onPitchBendChange(voiceIndex, voices[voiceIndex]);
            }
        }
        else if (msg.isController() && msg.getControllerNumber() == 74) {
            // CC74 = Slide (Y-axis)
            int voiceIndex = findVoiceForChannel(channel);
            if (voiceIndex >= 0) {
                voices[voiceIndex].slide = msg.getControllerValue() / 127.0f;
                if (onSlideChange) onSlideChange(voiceIndex, voices[voiceIndex]);
            }
        }
    }

    const MPENote& getVoice(int index) const { return voices[index]; }
    int getActiveVoiceCount() const {
        int count = 0;
        for (const auto& v : voices) if (v.isActive) count++;
        return count;
    }

    // Callbacks
    std::function<void(int, const MPENote&)> onNoteStart;
    std::function<void(int, const MPENote&)> onNoteEnd;
    std::function<void(int, const MPENote&)> onPressureChange;
    std::function<void(int, const MPENote&)> onPitchBendChange;
    std::function<void(int, const MPENote&)> onSlideChange;

    MPEZone lowerZone;
    MPEZone upperZone;

private:
    std::array<MPENote, MAX_MPE_VOICES> voices;

    int findFreeVoice() {
        for (int i = 0; i < MAX_MPE_VOICES; i++) {
            if (!voices[i].isActive) return i;
        }
        return 0;  // Voice stealing: take first
    }

    int findVoiceForChannel(int channel) {
        for (int i = 0; i < MAX_MPE_VOICES; i++) {
            if (voices[i].channel == channel && voices[i].isActive) return i;
        }
        return -1;
    }
};

//==============================================================================
// OSC (Open Sound Control) Support
//==============================================================================
struct OSCAddress {
    juce::String pattern;      // e.g., "/synth/filter/cutoff"
    juce::String typeTags;     // e.g., "f" for float, "i" for int

    bool matches(const juce::String& address) const {
        // Simple pattern matching with wildcards
        if (pattern == address) return true;
        if (pattern.contains("*")) {
            juce::String patternPart = pattern.upToFirstOccurrenceOf("*", false, false);
            return address.startsWith(patternPart);
        }
        return false;
    }
};

struct OSCMessage {
    juce::String address;
    std::vector<float> floatArgs;
    std::vector<int> intArgs;
    std::vector<juce::String> stringArgs;
    std::vector<std::vector<uint8_t>> blobArgs;

    float getFloat(int index) const {
        return index < floatArgs.size() ? floatArgs[index] : 0.0f;
    }

    int getInt(int index) const {
        return index < intArgs.size() ? intArgs[index] : 0;
    }
};

class OSCReceiver {
public:
    void setPort(int port) {
        receivePort = port;
        // In real implementation: socket.bind(port)
    }

    void addAddressPattern(const juce::String& pattern,
                           std::function<void(const OSCMessage&)> callback) {
        addressHandlers[pattern] = callback;
    }

    void processIncomingMessage(const OSCMessage& msg) {
        for (const auto& [pattern, handler] : addressHandlers) {
            OSCAddress addr{pattern, ""};
            if (addr.matches(msg.address)) {
                handler(msg);
            }
        }
    }

private:
    int receivePort = 8000;
    std::map<juce::String, std::function<void(const OSCMessage&)>> addressHandlers;
};

class OSCSender {
public:
    void setTarget(const juce::String& host, int port) {
        targetHost = host;
        targetPort = port;
    }

    void send(const juce::String& address, float value) {
        OSCMessage msg;
        msg.address = address;
        msg.floatArgs.push_back(value);
        sendMessage(msg);
    }

    void send(const juce::String& address, const std::vector<float>& values) {
        OSCMessage msg;
        msg.address = address;
        msg.floatArgs = values;
        sendMessage(msg);
    }

private:
    void sendMessage(const OSCMessage& msg) {
        // Real implementation would serialize and send via UDP
        if (onMessageSent) onMessageSent(msg);
    }

    juce::String targetHost = "127.0.0.1";
    int targetPort = 9000;

public:
    std::function<void(const OSCMessage&)> onMessageSent;
};

//==============================================================================
// Automation Lane System
//==============================================================================
struct AutomationPoint {
    double time = 0.0;         // In beats or seconds
    float value = 0.0f;

    enum class CurveType {
        Linear,
        Exponential,
        Logarithmic,
        SCurve,
        Step,
        Bezier
    };
    CurveType curve = CurveType::Linear;

    // Bezier control points (relative)
    float controlX1 = 0.33f;
    float controlY1 = 0.0f;
    float controlX2 = 0.66f;
    float controlY2 = 1.0f;
};

class AutomationLane {
public:
    juce::String name;
    juce::String targetParameter;

    void addPoint(double time, float value, AutomationPoint::CurveType curve = AutomationPoint::CurveType::Linear) {
        AutomationPoint pt;
        pt.time = time;
        pt.value = value;
        pt.curve = curve;

        // Insert sorted
        auto it = std::lower_bound(points.begin(), points.end(), pt,
            [](const AutomationPoint& a, const AutomationPoint& b) {
                return a.time < b.time;
            });
        points.insert(it, pt);
    }

    float getValueAt(double time) const {
        if (points.empty()) return 0.0f;
        if (time <= points.front().time) return points.front().value;
        if (time >= points.back().time) return points.back().value;

        // Find surrounding points
        for (size_t i = 0; i < points.size() - 1; i++) {
            if (time >= points[i].time && time < points[i + 1].time) {
                return interpolate(points[i], points[i + 1], time);
            }
        }

        return points.back().value;
    }

    const std::vector<AutomationPoint>& getPoints() const { return points; }

private:
    std::vector<AutomationPoint> points;

    float interpolate(const AutomationPoint& a, const AutomationPoint& b, double time) const {
        double t = (time - a.time) / (b.time - a.time);

        switch (a.curve) {
            case AutomationPoint::CurveType::Linear:
                return a.value + (b.value - a.value) * t;

            case AutomationPoint::CurveType::Exponential:
                return a.value + (b.value - a.value) * (std::pow(2.0, t) - 1.0);

            case AutomationPoint::CurveType::Logarithmic:
                return a.value + (b.value - a.value) * std::log2(1.0 + t);

            case AutomationPoint::CurveType::SCurve:
                t = t * t * (3.0 - 2.0 * t);  // Smoothstep
                return a.value + (b.value - a.value) * t;

            case AutomationPoint::CurveType::Step:
                return a.value;

            case AutomationPoint::CurveType::Bezier:
                return bezierInterpolate(a, b, t);

            default:
                return a.value + (b.value - a.value) * t;
        }
    }

    float bezierInterpolate(const AutomationPoint& a, const AutomationPoint& b, double t) const {
        // Cubic bezier
        double u = 1.0 - t;
        double tt = t * t;
        double uu = u * u;
        double uuu = uu * u;
        double ttt = tt * t;

        double y = uuu * a.value;
        y += 3 * uu * t * (a.value + a.controlY1 * (b.value - a.value));
        y += 3 * u * tt * (a.value + a.controlY2 * (b.value - a.value));
        y += ttt * b.value;

        return static_cast<float>(y);
    }
};

//==============================================================================
// Super Automation Engine - Central Hub
//==============================================================================
class SuperAutomationEngine {
public:
    SuperAutomationEngine() {
        setupDefaultMappings();
    }

    //==========================================================================
    // MIDI Processing
    //==========================================================================
    void processMIDI(const juce::MidiMessage& msg) {
        // Route to MPE processor if MPE enabled
        if (mpeEnabled && !msg.isController()) {
            mpeProcessor.processMessage(msg);
        }

        // Standard MIDI mapping
        if (msg.isController()) {
            int cc = msg.getControllerNumber();
            int channel = msg.getChannel() - 1;
            float value = msg.getControllerValue() / 127.0f;

            // Find mappings for this CC
            for (auto& [paramId, mapping] : midiMappings) {
                if (mapping.ccNumber == cc &&
                    (mapping.channel == -1 || mapping.channel == channel)) {
                    float mapped = mapping.applyMapping(msg.getControllerValue());
                    setParameterValue(paramId, mapped);
                }
            }
        }
        else if (msg.isNoteOn() && !mpeEnabled) {
            // Note-to-parameter mapping for non-MPE
            for (auto& [paramId, mapping] : midiMappings) {
                if (mapping.noteNumber == msg.getNoteNumber()) {
                    float velocity = msg.getVelocity() / 127.0f;
                    setParameterValue(paramId, velocity);
                }
            }
        }
    }

    void addMIDIMapping(const juce::String& parameterId, const MIDIMapping& mapping) {
        midiMappings[parameterId] = mapping;
    }

    void enableMPE(bool enable) { mpeEnabled = enable; }
    MPEProcessor& getMPEProcessor() { return mpeProcessor; }

    //==========================================================================
    // OSC Processing
    //==========================================================================
    void setupOSC(int receivePort, const juce::String& sendHost, int sendPort) {
        oscReceiver.setPort(receivePort);
        oscSender.setTarget(sendHost, sendPort);

        // Default address patterns
        oscReceiver.addAddressPattern("/param/*", [this](const OSCMessage& msg) {
            // Extract parameter name from address
            juce::String paramId = msg.address.fromLastOccurrenceOf("/", false, false);
            if (msg.floatArgs.size() > 0) {
                setParameterValue(paramId, msg.floatArgs[0]);
            }
        });

        oscReceiver.addAddressPattern("/transport/*", [this](const OSCMessage& msg) {
            handleTransportOSC(msg);
        });

        oscReceiver.addAddressPattern("/spatial/*", [this](const OSCMessage& msg) {
            handleSpatialOSC(msg);
        });
    }

    void sendOSC(const juce::String& address, float value) {
        oscSender.send(address, value);
    }

    void addOSCMapping(const juce::String& address, const juce::String& parameterId) {
        oscReceiver.addAddressPattern(address, [this, parameterId](const OSCMessage& msg) {
            if (msg.floatArgs.size() > 0) {
                setParameterValue(parameterId, msg.floatArgs[0]);
            }
        });
    }

    //==========================================================================
    // Automation Lanes
    //==========================================================================
    AutomationLane& createLane(const juce::String& name, const juce::String& targetParam) {
        automationLanes.emplace_back();
        automationLanes.back().name = name;
        automationLanes.back().targetParameter = targetParam;
        return automationLanes.back();
    }

    void updateAutomation(double currentTime) {
        for (const auto& lane : automationLanes) {
            float value = lane.getValueAt(currentTime);
            setParameterValue(lane.targetParameter, value);
        }
    }

    //==========================================================================
    // Parameter Management
    //==========================================================================
    void registerParameter(const juce::String& id,
                          std::function<void(float)> setter,
                          std::function<float()> getter) {
        parameterSetters[id] = setter;
        parameterGetters[id] = getter;
    }

    void setParameterValue(const juce::String& id, float value) {
        auto it = parameterSetters.find(id);
        if (it != parameterSetters.end()) {
            it->second(value);

            // Notify listeners
            if (onParameterChanged) {
                onParameterChanged(id, value);
            }

            // Send OSC feedback if enabled
            if (oscFeedbackEnabled) {
                oscSender.send("/param/" + id, value);
            }
        }
    }

    float getParameterValue(const juce::String& id) {
        auto it = parameterGetters.find(id);
        return it != parameterGetters.end() ? it->second() : 0.0f;
    }

    //==========================================================================
    // MIDI Learn
    //==========================================================================
    void startMIDILearn(const juce::String& parameterId) {
        midiLearnTarget = parameterId;
        midiLearnActive = true;
    }

    void processMIDILearn(const juce::MidiMessage& msg) {
        if (!midiLearnActive || midiLearnTarget.isEmpty()) return;

        if (msg.isController()) {
            MIDIMapping mapping;
            mapping.channel = msg.getChannel() - 1;
            mapping.ccNumber = msg.getControllerNumber();
            addMIDIMapping(midiLearnTarget, mapping);

            midiLearnActive = false;
            midiLearnTarget = "";

            if (onMIDILearned) {
                onMIDILearned(midiLearnTarget, mapping);
            }
        }
    }

    void cancelMIDILearn() {
        midiLearnActive = false;
        midiLearnTarget = "";
    }

    // Callbacks
    std::function<void(const juce::String&, float)> onParameterChanged;
    std::function<void(const juce::String&, const MIDIMapping&)> onMIDILearned;

private:
    // MIDI
    std::map<juce::String, MIDIMapping> midiMappings;
    MPEProcessor mpeProcessor;
    bool mpeEnabled = false;

    // OSC
    OSCReceiver oscReceiver;
    OSCSender oscSender;
    bool oscFeedbackEnabled = true;

    // Automation
    std::vector<AutomationLane> automationLanes;

    // Parameters
    std::map<juce::String, std::function<void(float)>> parameterSetters;
    std::map<juce::String, std::function<float()>> parameterGetters;

    // MIDI Learn
    bool midiLearnActive = false;
    juce::String midiLearnTarget;

    void setupDefaultMappings() {
        // Common MIDI CC mappings
        MIDIMapping modWheel;
        modWheel.ccNumber = 1;
        modWheel.channel = -1;
        midiMappings["modulation"] = modWheel;

        MIDIMapping expression;
        expression.ccNumber = 11;
        expression.channel = -1;
        midiMappings["expression"] = expression;

        MIDIMapping sustain;
        sustain.ccNumber = 64;
        sustain.channel = -1;
        midiMappings["sustain"] = sustain;
    }

    void handleTransportOSC(const OSCMessage& msg) {
        if (msg.address.endsWith("/play")) {
            if (onTransportCommand) onTransportCommand("play");
        }
        else if (msg.address.endsWith("/stop")) {
            if (onTransportCommand) onTransportCommand("stop");
        }
        else if (msg.address.endsWith("/tempo") && !msg.floatArgs.empty()) {
            if (onTempoChange) onTempoChange(msg.floatArgs[0]);
        }
    }

    void handleSpatialOSC(const OSCMessage& msg) {
        // /spatial/source/0/position x y z
        if (msg.address.contains("/position") && msg.floatArgs.size() >= 3) {
            if (onSpatialPosition) {
                onSpatialPosition(msg.floatArgs[0], msg.floatArgs[1], msg.floatArgs[2]);
            }
        }
    }

public:
    std::function<void(const juce::String&)> onTransportCommand;
    std::function<void(float)> onTempoChange;
    std::function<void(float, float, float)> onSpatialPosition;
};

//==============================================================================
// External Controller Integration Profiles
//==============================================================================
struct ControllerProfile {
    juce::String name;
    juce::String manufacturer;

    // Standard mappings for this controller
    std::map<int, juce::String> ccToParameter;
    std::map<int, juce::String> noteToTrigger;

    // Controller capabilities
    bool hasMPE = false;
    bool hasOSC = false;
    bool hasPressurePads = false;
    bool hasMotorizedFaders = false;
    int numEncoders = 0;
    int numPads = 0;
    int numFaders = 0;
};

class ControllerProfileManager {
public:
    void loadProfile(const juce::String& controllerName) {
        currentProfile = getBuiltInProfile(controllerName);
    }

    const ControllerProfile& getCurrentProfile() const { return currentProfile; }

    std::vector<juce::String> getAvailableProfiles() const {
        return {
            "Ableton Push 2",
            "Ableton Push 3",
            "Native Instruments Maschine",
            "Novation Launchpad",
            "Akai APC40",
            "Akai MPC",
            "ROLI Seaboard",
            "Sensel Morph",
            "Linnstrument",
            "Expressive E Touché",
            "Arturia KeyLab",
            "Korg nanoKONTROL",
            "Behringer X-Touch",
            "Generic MIDI",
            "TouchOSC",
            "Lemur"
        };
    }

private:
    ControllerProfile currentProfile;

    ControllerProfile getBuiltInProfile(const juce::String& name) {
        ControllerProfile profile;
        profile.name = name;

        if (name == "ROLI Seaboard" || name == "Linnstrument" || name == "Sensel Morph") {
            profile.hasMPE = true;
            profile.hasPressurePads = true;
        }
        else if (name == "Ableton Push 2" || name == "Ableton Push 3") {
            profile.manufacturer = "Ableton";
            profile.numPads = 64;
            profile.numEncoders = 8;
            profile.hasPressurePads = true;
        }
        else if (name == "TouchOSC" || name == "Lemur") {
            profile.hasOSC = true;
        }
        else if (name == "Behringer X-Touch") {
            profile.hasMotorizedFaders = true;
            profile.numFaders = 8;
        }

        return profile;
    }
};

} // namespace Automation
} // namespace Echoelmusic
