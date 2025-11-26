#pragma once

#include <JuceHeader.h>
#include <vector>
#include <map>

namespace Eoel {

/**
 * MIDIHardwareManager - Universal MIDI device integration
 *
 * Supported hardware (auto-detected):
 *
 * CONTROLLERS:
 * - Ableton Push 1/2/3
 * - Native Instruments Maschine, Komplete Kontrol
 * - Novation Launchpad, Launchkey, SL MkIII
 * - Akai APC40/Key, MPK, MPC Live/One/X
 * - Arturia KeyLab, BeatStep, DrumBrute
 * - Behringer X-Touch
 * - PreSonus FaderPort
 *
 * SYNTHESIZERS:
 * - Moog Mother-32, Grandmother, Matriarch, Voyager
 * - Sequential Prophet-5/6/10, OB-6, Pro 3
 * - Korg Minilogue, Prologue, MS-20, Wavestate
 * - Roland Juno, JD-Xi, System-8, Jupiter-X
 * - Elektron Digitakt, Digitone, Analog Four/Keys
 * - Teenage Engineering OP-1, OP-Z, OPsix
 *
 * DRUM MACHINES:
 * - Roland TR-8S, TR-909, TR-808, TR-707
 * - Elektron Analog Rytm
 * - Arturia DrumBrute Impact
 * - Behringer RD-8, RD-9
 *
 * Features:
 * - Auto-detect and map hardware
 * - Bidirectional communication (LED feedback, motorized faders)
 * - Template system for custom mappings
 * - MIDI learn mode
 * - Multi-device support (unlimited devices)
 */
class MIDIHardwareManager : public juce::MidiInputCallback
{
public:
    enum class DeviceType
    {
        Unknown,
        Controller,
        Synthesizer,
        DrumMachine,
        GrooveBox,
        Keyboard,
        PadController,
        FaderController,
        DJController,
        Modular
    };

    struct DeviceInfo
    {
        juce::String name;
        juce::String identifier;           // Unique ID
        DeviceType type = DeviceType::Unknown;
        bool isInput = false;
        bool isOutput = false;
        bool supportsBidirectional = false; // LED feedback, motorized faders
        int numPads = 0;
        int numKnobs = 0;
        int numFaders = 0;
        int numButtons = 0;
    };

    struct ControlMapping
    {
        juce::String controlName;
        int midiCC = -1;                   // CC number (0-127)
        int midiNote = -1;                 // Note number (0-127)
        int channel = 1;                   // MIDI channel (1-16)
        float min = 0.0f;
        float max = 1.0f;
        bool bipolar = false;              // -1 to +1 instead of 0 to 1

        juce::String targetParameter;      // Which plugin parameter to control
        std::function<void(float)> callback;
    };

    MIDIHardwareManager();
    ~MIDIHardwareManager() override;

    // ===========================
    // Device Management
    // ===========================

    /** Scan for all connected MIDI devices */
    void scanDevices();

    /** Get list of all detected devices */
    std::vector<DeviceInfo> getDevices() const { return m_devices; }

    /** Enable/disable a specific device */
    void enableDevice(const juce::String& identifier, bool enable);

    /** Check if device is connected */
    bool isDeviceConnected(const juce::String& identifier) const;

    // ===========================
    // Auto-Detection & Templates
    // ===========================

    /** Auto-detect device type from MIDI identifier */
    static DeviceType detectDeviceType(const juce::String& deviceName);

    /** Load control template for known hardware */
    bool loadTemplate(const juce::String& deviceIdentifier);

    /** Save custom template */
    void saveTemplate(const juce::String& deviceIdentifier, const juce::String& templateName);

    // ===========================
    // Control Mapping
    // ===========================

    /** Add control mapping */
    void addMapping(const juce::String& deviceIdentifier, const ControlMapping& mapping);

    /** Remove control mapping */
    void removeMapping(const juce::String& deviceIdentifier, int midiCC, int channel);

    /** Clear all mappings for device */
    void clearMappings(const juce::String& deviceIdentifier);

    /** MIDI Learn mode */
    void enableMidiLearn(bool enable, std::function<void(int cc, int channel)> callback);

    // ===========================
    // Bidirectional Control
    // ===========================

    /** Send LED/display feedback to device */
    void setDeviceLED(const juce::String& deviceIdentifier, int padIndex, juce::Colour color);

    /** Send fader position (for motorized faders) */
    void setFaderPosition(const juce::String& deviceIdentifier, int faderIndex, float position);

    /** Send display message (for devices with screens) */
    void setDisplayText(const juce::String& deviceIdentifier, const juce::String& text);

    // ===========================
    // MIDI I/O
    // ===========================

    /** Send MIDI message to device */
    void sendMidiMessage(const juce::String& deviceIdentifier, const juce::MidiMessage& message);

    /** MidiInputCallback implementation */
    void handleIncomingMidiMessage(juce::MidiInput* source, const juce::MidiMessage& message) override;

    // ===========================
    // Presets for Popular Devices
    // ===========================

    /** Ableton Push 2/3 */
    void setupPush2();

    /** Native Instruments Maschine */
    void setupMaschine();

    /** Akai APC40 */
    void setupAPC40();

    /** Novation Launchpad Pro */
    void setupLaunchpadPro();

    // ===========================
    // Callbacks
    // ===========================

    std::function<void(const juce::String& device, int cc, float value)> onControlChange;
    std::function<void(const juce::String& device, int note, float velocity)> onNotePressed;
    std::function<void(const DeviceInfo& device)> onDeviceConnected;
    std::function<void(const juce::String& identifier)> onDeviceDisconnected;

private:
    std::vector<DeviceInfo> m_devices;
    std::map<juce::String, std::vector<ControlMapping>> m_mappings;
    std::map<juce::String, std::unique_ptr<juce::MidiInput>> m_midiInputs;
    std::map<juce::String, std::unique_ptr<juce::MidiOutput>> m_midiOutputs;

    bool m_midiLearnActive = false;
    std::function<void(int cc, int channel)> m_midiLearnCallback;

    juce::CriticalSection m_lock;

    void detectKnownDevice(DeviceInfo& info);
    void setupBidirectionalComm(const juce::String& identifier);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MIDIHardwareManager)
};

} // namespace Eoel
