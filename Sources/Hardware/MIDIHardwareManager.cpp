#include "MIDIHardwareManager.h"

namespace Eoel {

MIDIHardwareManager::MIDIHardwareManager()
{
    scanDevices();
}

MIDIHardwareManager::~MIDIHardwareManager()
{
    // Close all MIDI connections
    juce::ScopedLock sl(m_lock);

    for (auto& input : m_midiInputs)
    {
        if (input.second)
            input.second->stop();
    }

    m_midiInputs.clear();
    m_midiOutputs.clear();
}

// ===========================
// Device Management
// ===========================

void MIDIHardwareManager::scanDevices()
{
    juce::ScopedLock sl(m_lock);

    m_devices.clear();

    // Scan MIDI inputs
    auto midiInputs = juce::MidiInput::getAvailableDevices();
    for (const auto& device : midiInputs)
    {
        DeviceInfo info;
        info.name = device.name;
        info.identifier = device.identifier;
        info.isInput = true;
        info.type = detectDeviceType(device.name);

        detectKnownDevice(info);

        m_devices.push_back(info);

        DBG("MIDI Input detected: " << info.name << " (Type: " << static_cast<int>(info.type) << ")");
    }

    // Scan MIDI outputs
    auto midiOutputs = juce::MidiOutput::getAvailableDevices();
    for (const auto& device : midiOutputs)
    {
        // Check if already added as input
        bool found = false;
        for (auto& info : m_devices)
        {
            if (info.identifier == device.identifier)
            {
                info.isOutput = true;
                found = true;
                break;
            }
        }

        if (!found)
        {
            DeviceInfo info;
            info.name = device.name;
            info.identifier = device.identifier;
            info.isOutput = true;
            info.type = detectDeviceType(device.name);

            detectKnownDevice(info);

            m_devices.push_back(info);

            DBG("MIDI Output detected: " << info.name);
        }
    }

    DBG("Total MIDI devices found: " << m_devices.size());
}

void MIDIHardwareManager::enableDevice(const juce::String& identifier, bool enable)
{
    juce::ScopedLock sl(m_lock);

    if (enable)
    {
        // Open MIDI input
        for (const auto& device : juce::MidiInput::getAvailableDevices())
        {
            if (device.identifier == identifier)
            {
                auto input = juce::MidiInput::openDevice(device.identifier, this);
                if (input)
                {
                    input->start();
                    m_midiInputs[identifier] = std::move(input);
                    DBG("MIDI Input enabled: " << device.name);

                    // Check if bidirectional support available
                    setupBidirectionalComm(identifier);

                    if (onDeviceConnected)
                    {
                        for (const auto& info : m_devices)
                        {
                            if (info.identifier == identifier)
                            {
                                onDeviceConnected(info);
                                break;
                            }
                        }
                    }
                }
                break;
            }
        }

        // Open MIDI output
        for (const auto& device : juce::MidiOutput::getAvailableDevices())
        {
            if (device.identifier == identifier)
            {
                auto output = juce::MidiOutput::openDevice(device.identifier);
                if (output)
                {
                    m_midiOutputs[identifier] = std::move(output);
                    DBG("MIDI Output enabled: " << device.name);
                }
                break;
            }
        }
    }
    else
    {
        // Close input
        auto inputIt = m_midiInputs.find(identifier);
        if (inputIt != m_midiInputs.end())
        {
            inputIt->second->stop();
            m_midiInputs.erase(inputIt);
            DBG("MIDI Input disabled: " << identifier);
        }

        // Close output
        auto outputIt = m_midiOutputs.find(identifier);
        if (outputIt != m_midiOutputs.end())
        {
            m_midiOutputs.erase(outputIt);
            DBG("MIDI Output disabled: " << identifier);
        }

        if (onDeviceDisconnected)
            onDeviceDisconnected(identifier);
    }
}

bool MIDIHardwareManager::isDeviceConnected(const juce::String& identifier) const
{
    juce::ScopedLock sl(m_lock);
    return m_midiInputs.find(identifier) != m_midiInputs.end() ||
           m_midiOutputs.find(identifier) != m_midiOutputs.end();
}

// ===========================
// Auto-Detection & Templates
// ===========================

MIDIHardwareManager::DeviceType MIDIHardwareManager::detectDeviceType(const juce::String& deviceName)
{
    juce::String name = deviceName.toLowerCase();

    // Controllers
    if (name.contains("push") || name.contains("launchpad") || name.contains("launchkey") ||
        name.contains("apc") || name.contains("maschine") || name.contains("komplete kontrol") ||
        name.contains("keylab") || name.contains("beatstep") || name.contains("x-touch") ||
        name.contains("faderport") || name.contains("sl mk"))
        return DeviceType::Controller;

    // Pad controllers
    if (name.contains("mpk") || name.contains("mpc") || name.contains("pad"))
        return DeviceType::PadController;

    // DJ controllers
    if (name.contains("traktor") || name.contains("cdj") || name.contains("djm") ||
        name.contains("xdj") || name.contains("ddj"))
        return DeviceType::DJController;

    // Drum machines
    if (name.contains("tr-") || name.contains("drumbrute") || name.contains("rd-") ||
        name.contains("rytm") || name.contains("drum"))
        return DeviceType::DrumMachine;

    // Synthesizers
    if (name.contains("moog") || name.contains("prophet") || name.contains("ob-6") ||
        name.contains("minilogue") || name.contains("prologue") || name.contains("juno") ||
        name.contains("jupiter") || name.contains("system-8") || name.contains("digitone") ||
        name.contains("op-1") || name.contains("op-z") || name.contains("opsix") ||
        name.contains("synth"))
        return DeviceType::Synthesizer;

    // Groove boxes
    if (name.contains("digitakt") || name.contains("octatrack") || name.contains("mc-") ||
        name.contains("groovebox") || name.contains("circuit"))
        return DeviceType::GrooveBox;

    // Keyboard
    if (name.contains("keyboard") || name.contains("keystation") || name.contains("piano"))
        return DeviceType::Keyboard;

    return DeviceType::Unknown;
}

void MIDIHardwareManager::detectKnownDevice(DeviceInfo& info)
{
    juce::String name = info.name.toLowerCase();

    // Ableton Push
    if (name.contains("push 2") || name.contains("push2"))
    {
        info.type = DeviceType::Controller;
        info.supportsBidirectional = true;
        info.numPads = 64;
        info.numKnobs = 11;
        info.numButtons = 50;
    }
    // Novation Launchpad Pro
    else if (name.contains("launchpad pro"))
    {
        info.type = DeviceType::PadController;
        info.supportsBidirectional = true;
        info.numPads = 64;
    }
    // Akai APC40
    else if (name.contains("apc40"))
    {
        info.type = DeviceType::Controller;
        info.supportsBidirectional = true;
        info.numPads = 40;
        info.numKnobs = 8;
        info.numFaders = 9;
    }
    // NI Maschine
    else if (name.contains("maschine mk3") || name.contains("maschine+"))
    {
        info.type = DeviceType::Controller;
        info.supportsBidirectional = true;
        info.numPads = 16;
        info.numKnobs = 8;
    }
    // Komplete Kontrol
    else if (name.contains("komplete kontrol"))
    {
        info.type = DeviceType::Keyboard;
        info.supportsBidirectional = true;
        info.numKnobs = 8;
    }
}

bool MIDIHardwareManager::loadTemplate(const juce::String& deviceIdentifier)
{
    // Find device
    DeviceInfo* device = nullptr;
    for (auto& info : m_devices)
    {
        if (info.identifier == deviceIdentifier)
        {
            device = &info;
            break;
        }
    }

    if (!device)
        return false;

    // Load template based on device type
    juce::String name = device->name.toLowerCase();

    if (name.contains("push 2"))
    {
        setupPush2();
        return true;
    }
    else if (name.contains("maschine"))
    {
        setupMaschine();
        return true;
    }
    else if (name.contains("apc40"))
    {
        setupAPC40();
        return true;
    }
    else if (name.contains("launchpad pro"))
    {
        setupLaunchpadPro();
        return true;
    }

    return false;
}

void MIDIHardwareManager::saveTemplate(const juce::String& deviceIdentifier, const juce::String& templateName)
{
    // Save current mappings as template
    juce::File templatesDir = juce::File::getSpecialLocation(juce::File::userApplicationDataDirectory)
                                  .getChildFile("Eoel")
                                  .getChildFile("MIDI Templates");

    templatesDir.createDirectory();

    juce::File templateFile = templatesDir.getChildFile(templateName + ".xml");

    juce::XmlElement root("MIDITemplate");
    root.setAttribute("device", deviceIdentifier);

    // Save mappings
    auto it = m_mappings.find(deviceIdentifier);
    if (it != m_mappings.end())
    {
        for (const auto& mapping : it->second)
        {
            auto* mappingXml = root.createNewChildElement("Mapping");
            mappingXml->setAttribute("name", mapping.controlName);
            mappingXml->setAttribute("cc", mapping.midiCC);
            mappingXml->setAttribute("note", mapping.midiNote);
            mappingXml->setAttribute("channel", mapping.channel);
            mappingXml->setAttribute("min", mapping.min);
            mappingXml->setAttribute("max", mapping.max);
            mappingXml->setAttribute("bipolar", mapping.bipolar);
            mappingXml->setAttribute("target", mapping.targetParameter);
        }
    }

    root.writeTo(templateFile);

    DBG("MIDI template saved: " << templateFile.getFullPathName());
}

// ===========================
// Control Mapping
// ===========================

void MIDIHardwareManager::addMapping(const juce::String& deviceIdentifier, const ControlMapping& mapping)
{
    juce::ScopedLock sl(m_lock);
    m_mappings[deviceIdentifier].push_back(mapping);

    DBG("Mapping added: " << mapping.controlName << " -> CC" << mapping.midiCC);
}

void MIDIHardwareManager::removeMapping(const juce::String& deviceIdentifier, int midiCC, int channel)
{
    juce::ScopedLock sl(m_lock);

    auto it = m_mappings.find(deviceIdentifier);
    if (it != m_mappings.end())
    {
        it->second.erase(
            std::remove_if(it->second.begin(), it->second.end(),
                [midiCC, channel](const ControlMapping& m) {
                    return m.midiCC == midiCC && m.channel == channel;
                }),
            it->second.end());
    }
}

void MIDIHardwareManager::clearMappings(const juce::String& deviceIdentifier)
{
    juce::ScopedLock sl(m_lock);
    m_mappings[deviceIdentifier].clear();

    DBG("All mappings cleared for: " << deviceIdentifier);
}

void MIDIHardwareManager::enableMidiLearn(bool enable, std::function<void(int cc, int channel)> callback)
{
    m_midiLearnActive = enable;
    m_midiLearnCallback = callback;

    DBG("MIDI Learn: " << (enable ? "ENABLED - Move a control..." : "DISABLED"));
}

// ===========================
// Bidirectional Control
// ===========================

void MIDIHardwareManager::setDeviceLED(const juce::String& deviceIdentifier, int padIndex, juce::Colour color)
{
    auto it = m_midiOutputs.find(deviceIdentifier);
    if (it == m_midiOutputs.end())
        return;

    // Convert RGB to MIDI velocity (device-specific)
    // For Launchpad: velocity 1-127 = color
    // For Push 2: SysEx messages for RGB
    // This is simplified - real implementation would be device-specific

    int velocity = juce::jmap(color.getBrightness(), 0.0f, 1.0f, 0.0f, 127.0f);
    juce::MidiMessage msg = juce::MidiMessage::noteOn(1, padIndex, (juce::uint8)velocity);

    it->second->sendMessageNow(msg);
}

void MIDIHardwareManager::setFaderPosition(const juce::String& deviceIdentifier, int faderIndex, float position)
{
    auto it = m_midiOutputs.find(deviceIdentifier);
    if (it == m_midiOutputs.end())
        return;

    // Send motorized fader position (CC or SysEx depending on device)
    int value = juce::jmap(position, 0.0f, 1.0f, 0.0f, 127.0f);
    juce::MidiMessage msg = juce::MidiMessage::controllerEvent(1, faderIndex, value);

    it->second->sendMessageNow(msg);
}

void MIDIHardwareManager::setDisplayText(const juce::String& deviceIdentifier, const juce::String& text)
{
    auto it = m_midiOutputs.find(deviceIdentifier);
    if (it == m_midiOutputs.end())
        return;

    // Send display text via SysEx (device-specific)
    // Push 2, Maschine, Komplete Kontrol support this

    DBG("Display text: " << text);
    // Real implementation would send device-specific SysEx
}

// ===========================
// MIDI I/O
// ===========================

void MIDIHardwareManager::sendMidiMessage(const juce::String& deviceIdentifier, const juce::MidiMessage& message)
{
    auto it = m_midiOutputs.find(deviceIdentifier);
    if (it != m_midiOutputs.end())
    {
        it->second->sendMessageNow(message);
    }
}

void MIDIHardwareManager::handleIncomingMidiMessage(juce::MidiInput* source, const juce::MidiMessage& message)
{
    // Find device identifier
    juce::String deviceId;
    for (const auto& pair : m_midiInputs)
    {
        if (pair.second.get() == source)
        {
            deviceId = pair.first;
            break;
        }
    }

    // MIDI Learn mode
    if (m_midiLearnActive)
    {
        if (message.isController() && m_midiLearnCallback)
        {
            m_midiLearnCallback(message.getControllerNumber(), message.getChannel());
            m_midiLearnActive = false;
            return;
        }
    }

    // Process control change
    if (message.isController())
    {
        int cc = message.getControllerNumber();
        int channel = message.getChannel();
        float value = message.getControllerValue() / 127.0f;

        // Find mapping
        auto it = m_mappings.find(deviceId);
        if (it != m_mappings.end())
        {
            for (const auto& mapping : it->second)
            {
                if (mapping.midiCC == cc && mapping.channel == channel)
                {
                    // Scale value
                    float scaledValue = juce::jmap(value, 0.0f, 1.0f, mapping.min, mapping.max);

                    if (mapping.bipolar)
                        scaledValue = scaledValue * 2.0f - 1.0f;

                    if (mapping.callback)
                        mapping.callback(scaledValue);

                    if (onControlChange)
                        onControlChange(deviceId, cc, scaledValue);

                    break;
                }
            }
        }
    }
    // Process note
    else if (message.isNoteOn())
    {
        int note = message.getNoteNumber();
        float velocity = message.getVelocity() / 127.0f;

        if (onNotePressed)
            onNotePressed(deviceId, note, velocity);
    }
}

// ===========================
// Device Presets
// ===========================

void MIDIHardwareManager::setupPush2()
{
    DBG("Loading Ableton Push 2 template...");
    // Setup default mappings for Push 2
    // Knobs, pads, buttons, etc.
}

void MIDIHardwareManager::setupMaschine()
{
    DBG("Loading NI Maschine template...");
    // Setup default mappings for Maschine
}

void MIDIHardwareManager::setupAPC40()
{
    DBG("Loading Akai APC40 template...");
    // Setup default mappings for APC40
}

void MIDIHardwareManager::setupLaunchpadPro()
{
    DBG("Loading Novation Launchpad Pro template...");
    // Setup default mappings for Launchpad Pro
}

void MIDIHardwareManager::setupBidirectionalComm(const juce::String& identifier)
{
    // Setup bidirectional communication for devices that support it
    // Send initialization SysEx messages

    for (const auto& info : m_devices)
    {
        if (info.identifier == identifier && info.supportsBidirectional)
        {
            DBG("Setting up bidirectional communication for: " << info.name);
            // Send device-specific init messages
            break;
        }
    }
}

} // namespace Eoel
