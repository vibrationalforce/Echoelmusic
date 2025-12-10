/**
 * MIDIEngine.cpp
 * Echoelmusic Desktop MIDI 2.0 Engine Implementation
 *
 * Copyright (c) 2025 Echoelmusic
 */

#include "MIDIEngine.h"

namespace Echoelmusic {

// ============================================================================
// Constructor / Destructor
// ============================================================================

MIDIEngine::MIDIEngine() {
    DBG("MIDIEngine: Initializing MIDI 2.0 Engine");
}

MIDIEngine::~MIDIEngine() {
    shutdown();
}

// ============================================================================
// Initialization
// ============================================================================

void MIDIEngine::initialize() {
    DBG("MIDIEngine: Scanning for MIDI devices...");

    auto inputs = juce::MidiInput::getAvailableDevices();
    auto outputs = juce::MidiOutput::getAvailableDevices();

    DBG("MIDIEngine: Found " << inputs.size() << " input(s), "
        << outputs.size() << " output(s)");

    for (const auto& device : inputs) {
        DBG("  Input: " << device.name << " [" << device.identifier << "]");
    }

    for (const auto& device : outputs) {
        DBG("  Output: " << device.name << " [" << device.identifier << "]");
    }
}

void MIDIEngine::shutdown() {
    DBG("MIDIEngine: Shutting down...");

    // Stop MIDI learn if active
    stopMIDILearn();

    // Send all notes off
    sendAllNotesOff();

    // Close all devices
    closeAllDevices();

    // Clear active notes
    {
        std::lock_guard<std::mutex> lock(notesMutex);
        activeNotes.clear();
    }

    DBG("MIDIEngine: Shutdown complete. Sent: " << messagesSent.load()
        << ", Received: " << messagesReceived.load());
}

// ============================================================================
// Device Management
// ============================================================================

std::vector<MIDIDeviceInfo> MIDIEngine::getAvailableInputDevices() const {
    std::vector<MIDIDeviceInfo> result;

    auto devices = juce::MidiInput::getAvailableDevices();
    for (const auto& device : devices) {
        MIDIDeviceInfo info;
        info.name = device.name;
        info.identifier = device.identifier;
        info.isInput = true;
        info.isOutput = false;
        info.isConnected = isInputOpen(device.identifier);
        info.supportsUMP = false;  // TODO: Detect MIDI 2.0 support
        result.push_back(info);
    }

    return result;
}

std::vector<MIDIDeviceInfo> MIDIEngine::getAvailableOutputDevices() const {
    std::vector<MIDIDeviceInfo> result;

    auto devices = juce::MidiOutput::getAvailableDevices();
    for (const auto& device : devices) {
        MIDIDeviceInfo info;
        info.name = device.name;
        info.identifier = device.identifier;
        info.isInput = false;
        info.isOutput = true;
        info.isConnected = isOutputOpen(device.identifier);
        info.supportsUMP = false;
        result.push_back(info);
    }

    return result;
}

bool MIDIEngine::openInput(const juce::String& deviceIdentifier) {
    std::lock_guard<std::mutex> lock(deviceMutex);

    // Check if already open
    if (openInputs.find(deviceIdentifier) != openInputs.end()) {
        DBG("MIDIEngine: Input already open: " << deviceIdentifier);
        return true;
    }

    // Find device
    auto devices = juce::MidiInput::getAvailableDevices();
    for (const auto& device : devices) {
        if (device.identifier == deviceIdentifier) {
            auto input = juce::MidiInput::openDevice(device.identifier, this);
            if (input) {
                input->start();
                openInputs[deviceIdentifier] = std::move(input);
                DBG("MIDIEngine: Opened input: " << device.name);
                return true;
            }
        }
    }

    DBG("MIDIEngine: Failed to open input: " << deviceIdentifier);
    return false;
}

bool MIDIEngine::openOutput(const juce::String& deviceIdentifier) {
    std::lock_guard<std::mutex> lock(deviceMutex);

    // Check if already open
    if (openOutputs.find(deviceIdentifier) != openOutputs.end()) {
        DBG("MIDIEngine: Output already open: " << deviceIdentifier);
        return true;
    }

    // Find device
    auto devices = juce::MidiOutput::getAvailableDevices();
    for (const auto& device : devices) {
        if (device.identifier == deviceIdentifier) {
            auto output = juce::MidiOutput::openDevice(device.identifier);
            if (output) {
                openOutputs[deviceIdentifier] = std::move(output);
                DBG("MIDIEngine: Opened output: " << device.name);
                return true;
            }
        }
    }

    DBG("MIDIEngine: Failed to open output: " << deviceIdentifier);
    return false;
}

void MIDIEngine::closeInput(const juce::String& deviceIdentifier) {
    std::lock_guard<std::mutex> lock(deviceMutex);

    auto it = openInputs.find(deviceIdentifier);
    if (it != openInputs.end()) {
        it->second->stop();
        openInputs.erase(it);
        DBG("MIDIEngine: Closed input: " << deviceIdentifier);
    }
}

void MIDIEngine::closeOutput(const juce::String& deviceIdentifier) {
    std::lock_guard<std::mutex> lock(deviceMutex);

    auto it = openOutputs.find(deviceIdentifier);
    if (it != openOutputs.end()) {
        openOutputs.erase(it);
        DBG("MIDIEngine: Closed output: " << deviceIdentifier);
    }
}

void MIDIEngine::closeAllDevices() {
    std::lock_guard<std::mutex> lock(deviceMutex);

    for (auto& [id, input] : openInputs) {
        input->stop();
    }
    openInputs.clear();
    openOutputs.clear();

    DBG("MIDIEngine: All devices closed");
}

bool MIDIEngine::isInputOpen(const juce::String& deviceIdentifier) const {
    std::lock_guard<std::mutex> lock(deviceMutex);
    return openInputs.find(deviceIdentifier) != openInputs.end();
}

bool MIDIEngine::isOutputOpen(const juce::String& deviceIdentifier) const {
    std::lock_guard<std::mutex> lock(deviceMutex);
    return openOutputs.find(deviceIdentifier) != openOutputs.end();
}

// ============================================================================
// Virtual MIDI Ports
// ============================================================================

bool MIDIEngine::createVirtualInput(const juce::String& name) {
#if JUCE_MAC || JUCE_IOS
    auto input = juce::MidiInput::createNewDevice(name, this);
    if (input) {
        input->start();
        std::lock_guard<std::mutex> lock(deviceMutex);
        openInputs["virtual:" + name] = std::move(input);
        DBG("MIDIEngine: Created virtual input: " << name);
        return true;
    }
#endif
    DBG("MIDIEngine: Virtual MIDI not supported on this platform");
    return false;
}

bool MIDIEngine::createVirtualOutput(const juce::String& name) {
#if JUCE_MAC || JUCE_IOS
    auto output = juce::MidiOutput::createNewDevice(name);
    if (output) {
        std::lock_guard<std::mutex> lock(deviceMutex);
        openOutputs["virtual:" + name] = std::move(output);
        DBG("MIDIEngine: Created virtual output: " << name);
        return true;
    }
#endif
    DBG("MIDIEngine: Virtual MIDI not supported on this platform");
    return false;
}

// ============================================================================
// MIDI Output
// ============================================================================

void MIDIEngine::sendNoteOn(uint8_t channel, uint8_t note, uint16_t velocity, uint8_t group) {
    // Convert 16-bit velocity to 7-bit for MIDI 1.0 output
    uint8_t vel7 = velocity16to7(velocity);

    juce::MidiMessage msg = juce::MidiMessage::noteOn(channel + 1, note, vel7);

    std::lock_guard<std::mutex> lock(deviceMutex);
    for (auto& [id, output] : openOutputs) {
        output->sendMessageNow(msg);
    }

    messagesSent++;
}

void MIDIEngine::sendNoteOff(uint8_t channel, uint8_t note, uint16_t velocity, uint8_t group) {
    uint8_t vel7 = velocity16to7(velocity);

    juce::MidiMessage msg = juce::MidiMessage::noteOff(channel + 1, note, vel7);

    std::lock_guard<std::mutex> lock(deviceMutex);
    for (auto& [id, output] : openOutputs) {
        output->sendMessageNow(msg);
    }

    messagesSent++;
}

void MIDIEngine::sendControlChange(uint8_t channel, uint8_t cc, uint32_t value, uint8_t group) {
    uint8_t val7 = value32to7(value);

    juce::MidiMessage msg = juce::MidiMessage::controllerEvent(channel + 1, cc, val7);

    std::lock_guard<std::mutex> lock(deviceMutex);
    for (auto& [id, output] : openOutputs) {
        output->sendMessageNow(msg);
    }

    messagesSent++;
}

void MIDIEngine::sendPitchBend(uint8_t channel, uint32_t value, uint8_t group) {
    uint16_t bend14 = pitchBend32to14(value);

    juce::MidiMessage msg = juce::MidiMessage::pitchWheel(channel + 1, bend14);

    std::lock_guard<std::mutex> lock(deviceMutex);
    for (auto& [id, output] : openOutputs) {
        output->sendMessageNow(msg);
    }

    messagesSent++;
}

void MIDIEngine::sendPolyPressure(uint8_t channel, uint8_t note, uint32_t pressure, uint8_t group) {
    uint8_t press7 = value32to7(pressure);

    juce::MidiMessage msg = juce::MidiMessage::aftertouchChange(channel + 1, note, press7);

    std::lock_guard<std::mutex> lock(deviceMutex);
    for (auto& [id, output] : openOutputs) {
        output->sendMessageNow(msg);
    }

    messagesSent++;
}

void MIDIEngine::sendPerNoteController(uint8_t channel, uint8_t note, uint8_t controller,
                                       uint32_t value, uint8_t group) {
    // MIDI 2.0 Per-Note Controllers - for now, map to CC
    // In full MIDI 2.0, this would use UMP packets
    uint8_t val7 = value32to7(value);

    // Map PNC to standard CC as fallback
    juce::MidiMessage msg = juce::MidiMessage::controllerEvent(channel + 1, controller, val7);

    std::lock_guard<std::mutex> lock(deviceMutex);
    for (auto& [id, output] : openOutputs) {
        output->sendMessageNow(msg);
    }

    messagesSent++;
}

void MIDIEngine::sendProgramChange(uint8_t channel, uint8_t program, uint8_t group) {
    juce::MidiMessage msg = juce::MidiMessage::programChange(channel + 1, program);

    std::lock_guard<std::mutex> lock(deviceMutex);
    for (auto& [id, output] : openOutputs) {
        output->sendMessageNow(msg);
    }

    messagesSent++;
}

void MIDIEngine::sendAllNotesOff(uint8_t channel) {
    std::lock_guard<std::mutex> lock(deviceMutex);

    if (channel == 0xFF) {
        // All channels
        for (int ch = 0; ch < 16; ++ch) {
            juce::MidiMessage msg = juce::MidiMessage::allNotesOff(ch + 1);
            for (auto& [id, output] : openOutputs) {
                output->sendMessageNow(msg);
            }
        }
    } else {
        juce::MidiMessage msg = juce::MidiMessage::allNotesOff(channel + 1);
        for (auto& [id, output] : openOutputs) {
            output->sendMessageNow(msg);
        }
    }

    // Clear active notes
    {
        std::lock_guard<std::mutex> notesLock(notesMutex);
        activeNotes.clear();
    }

    messagesSent++;
}

// ============================================================================
// Active Notes
// ============================================================================

int MIDIEngine::getActiveNoteCount() const {
    std::lock_guard<std::mutex> lock(notesMutex);
    int count = 0;
    for (const auto& [key, note] : activeNotes) {
        if (note.isActive) count++;
    }
    return count;
}

bool MIDIEngine::isNoteActive(uint8_t channel, uint8_t note) const {
    std::lock_guard<std::mutex> lock(notesMutex);
    auto it = activeNotes.find(noteKey(channel, note));
    return it != activeNotes.end() && it->second.isActive;
}

// ============================================================================
// MIDI Learn
// ============================================================================

void MIDIEngine::startMIDILearn(std::function<void(uint8_t channel, uint8_t cc)> callback) {
    midiLearnCallback = callback;
    midiLearnActive.store(true);
    DBG("MIDIEngine: MIDI Learn started");
}

void MIDIEngine::stopMIDILearn() {
    midiLearnActive.store(false);
    midiLearnCallback = nullptr;
    DBG("MIDIEngine: MIDI Learn stopped");
}

// ============================================================================
// MIDI Input Callback
// ============================================================================

void MIDIEngine::handleIncomingMidiMessage(juce::MidiInput* source,
                                           const juce::MidiMessage& message) {
    messagesReceived++;

    // Determine group from source (simplified - could be based on device)
    uint8_t group = 0;

    if (message.isNoteOn()) {
        processNoteOn(message, group);
    } else if (message.isNoteOff()) {
        processNoteOff(message, group);
    } else if (message.isController()) {
        processControlChange(message, group);
    } else if (message.isPitchWheel()) {
        processPitchBend(message, group);
    } else if (message.isChannelPressure()) {
        processAftertouch(message, group);
    } else if (message.isAftertouch()) {
        processPolyAftertouch(message, group);
    }
}

void MIDIEngine::processNoteOn(const juce::MidiMessage& msg, uint8_t group) {
    uint8_t channel = static_cast<uint8_t>(msg.getChannel() - 1);
    uint8_t note = static_cast<uint8_t>(msg.getNoteNumber());
    uint8_t vel7 = static_cast<uint8_t>(msg.getVelocity());
    uint16_t vel16 = velocity7to16(vel7);

    // Velocity 0 = note off
    if (vel7 == 0) {
        processNoteOff(msg, group);
        return;
    }

    // Update active notes
    {
        std::lock_guard<std::mutex> lock(notesMutex);
        auto key = noteKey(channel, note);
        ActiveNote& activeNote = activeNotes[key];
        activeNote.note = note;
        activeNote.channel = channel;
        activeNote.velocity = vel16;
        activeNote.pitchBend = 0x80000000;  // Center
        activeNote.pressure = 0;
        activeNote.brightness = 0x80000000;
        activeNote.timbre = 0x80000000;
        activeNote.startTime = juce::Time::getMillisecondCounterHiRes() / 1000.0;
        activeNote.isActive = true;
    }

    // Fire callback
    if (noteOnCallback) {
        noteOnCallback(channel, note, vel16, group);
    }
}

void MIDIEngine::processNoteOff(const juce::MidiMessage& msg, uint8_t group) {
    uint8_t channel = static_cast<uint8_t>(msg.getChannel() - 1);
    uint8_t note = static_cast<uint8_t>(msg.getNoteNumber());
    uint8_t vel7 = static_cast<uint8_t>(msg.getVelocity());
    uint16_t vel16 = velocity7to16(vel7);

    // Update active notes
    {
        std::lock_guard<std::mutex> lock(notesMutex);
        auto key = noteKey(channel, note);
        auto it = activeNotes.find(key);
        if (it != activeNotes.end()) {
            it->second.isActive = false;
        }
    }

    // Fire callback
    if (noteOffCallback) {
        noteOffCallback(channel, note, vel16, group);
    }
}

void MIDIEngine::processControlChange(const juce::MidiMessage& msg, uint8_t group) {
    uint8_t channel = static_cast<uint8_t>(msg.getChannel() - 1);
    uint8_t cc = static_cast<uint8_t>(msg.getControllerNumber());
    uint8_t val7 = static_cast<uint8_t>(msg.getControllerValue());
    uint32_t val32 = value7to32(val7);

    // MIDI Learn
    if (midiLearnActive.load() && midiLearnCallback) {
        midiLearnCallback(channel, cc);
        stopMIDILearn();
        return;
    }

    // Fire callback
    if (ccCallback) {
        ccCallback(channel, cc, val32, group);
    }
}

void MIDIEngine::processPitchBend(const juce::MidiMessage& msg, uint8_t group) {
    uint8_t channel = static_cast<uint8_t>(msg.getChannel() - 1);
    int bend14 = msg.getPitchWheelValue();
    uint32_t bend32 = pitchBend14to32(static_cast<uint16_t>(bend14));

    // Update active notes on this channel (for MPE per-note pitch)
    {
        std::lock_guard<std::mutex> lock(notesMutex);
        for (auto& [key, note] : activeNotes) {
            if (note.channel == channel && note.isActive) {
                note.pitchBend = bend32;
            }
        }
    }

    // Fire callback
    if (pitchBendCallback) {
        pitchBendCallback(channel, bend32, group);
    }
}

void MIDIEngine::processAftertouch(const juce::MidiMessage& msg, uint8_t group) {
    uint8_t channel = static_cast<uint8_t>(msg.getChannel() - 1);
    uint8_t pressure7 = static_cast<uint8_t>(msg.getChannelPressureValue());
    uint32_t pressure32 = value7to32(pressure7);

    // Update all active notes on this channel
    {
        std::lock_guard<std::mutex> lock(notesMutex);
        for (auto& [key, note] : activeNotes) {
            if (note.channel == channel && note.isActive) {
                note.pressure = pressure32;
            }
        }
    }

    // Fire as poly pressure for all active notes
    if (polyPressureCallback) {
        std::lock_guard<std::mutex> lock(notesMutex);
        for (const auto& [key, note] : activeNotes) {
            if (note.channel == channel && note.isActive) {
                polyPressureCallback(channel, note.note, pressure32, group);
            }
        }
    }
}

void MIDIEngine::processPolyAftertouch(const juce::MidiMessage& msg, uint8_t group) {
    uint8_t channel = static_cast<uint8_t>(msg.getChannel() - 1);
    uint8_t note = static_cast<uint8_t>(msg.getNoteNumber());
    uint8_t pressure7 = static_cast<uint8_t>(msg.getAfterTouchValue());
    uint32_t pressure32 = value7to32(pressure7);

    // Update active note
    {
        std::lock_guard<std::mutex> lock(notesMutex);
        auto key = noteKey(channel, note);
        auto it = activeNotes.find(key);
        if (it != activeNotes.end() && it->second.isActive) {
            it->second.pressure = pressure32;
        }
    }

    // Fire callback
    if (polyPressureCallback) {
        polyPressureCallback(channel, note, pressure32, group);
    }
}

// ============================================================================
// UMP Conversion Utilities
// ============================================================================

uint16_t MIDIEngine::velocity7to16(uint8_t vel7) {
    if (vel7 == 0) return 0;
    if (vel7 >= 127) return 0xFFFF;
    // Scale 1-126 to 1-65534
    return static_cast<uint16_t>((vel7 * 65535) / 127);
}

uint8_t MIDIEngine::velocity16to7(uint16_t vel16) {
    if (vel16 == 0) return 0;
    if (vel16 >= 0xFFFF) return 127;
    return static_cast<uint8_t>((vel16 * 127) / 65535);
}

uint32_t MIDIEngine::value7to32(uint8_t val7) {
    if (val7 == 0) return 0;
    if (val7 >= 127) return 0xFFFFFFFF;
    return static_cast<uint32_t>((static_cast<uint64_t>(val7) * 0xFFFFFFFF) / 127);
}

uint8_t MIDIEngine::value32to7(uint32_t val32) {
    if (val32 == 0) return 0;
    if (val32 >= 0xFFFFFFFF) return 127;
    return static_cast<uint8_t>((static_cast<uint64_t>(val32) * 127) / 0xFFFFFFFF);
}

uint32_t MIDIEngine::pitchBend14to32(uint16_t bend14) {
    // 14-bit: 0-16383, center = 8192
    // 32-bit: 0-0xFFFFFFFF, center = 0x80000000
    return static_cast<uint32_t>((static_cast<uint64_t>(bend14) * 0xFFFFFFFF) / 16383);
}

uint16_t MIDIEngine::pitchBend32to14(uint32_t bend32) {
    return static_cast<uint16_t>((static_cast<uint64_t>(bend32) * 16383) / 0xFFFFFFFF);
}

} // namespace Echoelmusic
