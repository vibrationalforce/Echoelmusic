/**
 * MIDIEngine.h
 * Echoelmusic Desktop MIDI 2.0 Engine
 *
 * C++ port of MIDI2Manager.swift with JUCE CoreMIDI support
 * Features:
 * - MIDI 2.0 Universal MIDI Packet (UMP) support
 * - 32-bit parameter resolution
 * - Per-note controllers (PNC)
 * - Virtual MIDI source creation
 * - Multi-device management
 *
 * Copyright (c) 2025 Echoelmusic
 */

#pragma once

#include <JuceHeader.h>
#include <functional>
#include <memory>
#include <unordered_map>
#include <vector>
#include <atomic>
#include <mutex>

namespace Echoelmusic {

// ============================================================================
// MIDI 2.0 Types (Port of MIDI2Types.swift)
// ============================================================================

/// Universal MIDI Packet (32-bit)
struct UMPPacket32 {
    uint32_t word0 = 0;

    uint8_t messageType() const { return (word0 >> 28) & 0x0F; }
    uint8_t group() const { return (word0 >> 24) & 0x0F; }
    uint8_t status() const { return (word0 >> 16) & 0xFF; }
    uint8_t channel() const { return (word0 >> 16) & 0x0F; }
    uint8_t data1() const { return (word0 >> 8) & 0xFF; }
    uint8_t data2() const { return word0 & 0xFF; }

    static UMPPacket32 create(uint8_t type, uint8_t group, uint8_t status,
                              uint8_t d1, uint8_t d2) {
        UMPPacket32 p;
        p.word0 = ((type & 0x0F) << 28) | ((group & 0x0F) << 24) |
                  ((status & 0xFF) << 16) | ((d1 & 0xFF) << 8) | (d2 & 0xFF);
        return p;
    }
};

/// Universal MIDI Packet (64-bit) for MIDI 2.0
struct UMPPacket64 {
    uint32_t word0 = 0;
    uint32_t word1 = 0;

    uint8_t messageType() const { return (word0 >> 28) & 0x0F; }
    uint8_t group() const { return (word0 >> 24) & 0x0F; }
    uint8_t status() const { return (word0 >> 20) & 0x0F; }
    uint8_t channel() const { return (word0 >> 16) & 0x0F; }
    uint8_t noteNumber() const { return (word0 >> 8) & 0xFF; }
    uint8_t attributeType() const { return word0 & 0xFF; }
    uint16_t velocity() const { return (word1 >> 16) & 0xFFFF; }
    uint16_t attribute() const { return word1 & 0xFFFF; }
    uint32_t data() const { return word1; }

    static UMPPacket64 noteOn(uint8_t group, uint8_t channel, uint8_t note,
                              uint16_t velocity, uint8_t attrType = 0, uint16_t attr = 0) {
        UMPPacket64 p;
        p.word0 = (0x04 << 28) | ((group & 0x0F) << 24) | (0x09 << 20) |
                  ((channel & 0x0F) << 16) | ((note & 0x7F) << 8) | attrType;
        p.word1 = ((velocity & 0xFFFF) << 16) | (attr & 0xFFFF);
        return p;
    }

    static UMPPacket64 noteOff(uint8_t group, uint8_t channel, uint8_t note,
                               uint16_t velocity = 0) {
        UMPPacket64 p;
        p.word0 = (0x04 << 28) | ((group & 0x0F) << 24) | (0x08 << 20) |
                  ((channel & 0x0F) << 16) | ((note & 0x7F) << 8);
        p.word1 = ((velocity & 0xFFFF) << 16);
        return p;
    }

    static UMPPacket64 polyPressure(uint8_t group, uint8_t channel, uint8_t note,
                                    uint32_t pressure) {
        UMPPacket64 p;
        p.word0 = (0x04 << 28) | ((group & 0x0F) << 24) | (0x0A << 20) |
                  ((channel & 0x0F) << 16) | ((note & 0x7F) << 8);
        p.word1 = pressure;
        return p;
    }

    static UMPPacket64 controlChange(uint8_t group, uint8_t channel, uint8_t cc,
                                     uint32_t value) {
        UMPPacket64 p;
        p.word0 = (0x04 << 28) | ((group & 0x0F) << 24) | (0x0B << 20) |
                  ((channel & 0x0F) << 16) | ((cc & 0x7F) << 8);
        p.word1 = value;
        return p;
    }

    static UMPPacket64 pitchBend(uint8_t group, uint8_t channel, uint32_t value) {
        UMPPacket64 p;
        p.word0 = (0x04 << 28) | ((group & 0x0F) << 24) | (0x0E << 20) |
                  ((channel & 0x0F) << 16);
        p.word1 = value;
        return p;
    }

    static UMPPacket64 perNoteController(uint8_t group, uint8_t channel,
                                         uint8_t note, uint8_t controller, uint32_t value) {
        UMPPacket64 p;
        p.word0 = (0x04 << 28) | ((group & 0x0F) << 24) | (0x00 << 20) |
                  ((channel & 0x0F) << 16) | ((note & 0x7F) << 8) | controller;
        p.word1 = value;
        return p;
    }
};

/// Per-Note Controller IDs (MIDI 2.0)
enum class PerNoteController : uint8_t {
    Modulation = 1,
    Breath = 2,
    Pitch7_25 = 3,
    Volume = 7,
    Balance = 8,
    Pan = 10,
    Expression = 11,
    SoundController1 = 70,  // Brightness
    SoundController2 = 71,  // Timbre/Harmonic
    SoundController3 = 72,  // Release Time
    SoundController4 = 73,  // Attack Time
    SoundController5 = 74,  // Filter Cutoff
    SoundController6 = 75,  // Filter Resonance
};

/// MIDI Message Types
enum class MIDIMessageType {
    NoteOff,
    NoteOn,
    PolyPressure,
    ControlChange,
    ProgramChange,
    ChannelPressure,
    PitchBend,
    SystemExclusive,
    Unknown
};

// ============================================================================
// Active Note State
// ============================================================================

struct ActiveNote {
    uint8_t note = 0;
    uint8_t channel = 0;
    uint16_t velocity = 0;
    uint32_t pitchBend = 0x80000000;  // Center (32-bit)
    uint32_t pressure = 0;
    uint32_t brightness = 0x80000000;
    uint32_t timbre = 0x80000000;
    double startTime = 0;
    bool isActive = false;
};

// ============================================================================
// MIDI Device Info
// ============================================================================

struct MIDIDeviceInfo {
    juce::String name;
    juce::String identifier;
    bool isInput = false;
    bool isOutput = false;
    bool isConnected = false;
    bool supportsUMP = false;  // MIDI 2.0 support
};

// ============================================================================
// Callback Types
// ============================================================================

using NoteOnCallback = std::function<void(uint8_t channel, uint8_t note,
                                          uint16_t velocity, uint8_t group)>;
using NoteOffCallback = std::function<void(uint8_t channel, uint8_t note,
                                           uint16_t velocity, uint8_t group)>;
using ControlChangeCallback = std::function<void(uint8_t channel, uint8_t cc,
                                                 uint32_t value, uint8_t group)>;
using PitchBendCallback = std::function<void(uint8_t channel, uint32_t value, uint8_t group)>;
using PolyPressureCallback = std::function<void(uint8_t channel, uint8_t note,
                                                uint32_t pressure, uint8_t group)>;
using PerNoteControllerCallback = std::function<void(uint8_t channel, uint8_t note,
                                                     uint8_t controller, uint32_t value)>;

// ============================================================================
// MIDIEngine Class
// ============================================================================

class MIDIEngine : public juce::MidiInputCallback {
public:
    MIDIEngine();
    ~MIDIEngine() override;

    // --- Initialization ---
    void initialize();
    void shutdown();

    // --- Device Management ---
    std::vector<MIDIDeviceInfo> getAvailableInputDevices() const;
    std::vector<MIDIDeviceInfo> getAvailableOutputDevices() const;

    bool openInput(const juce::String& deviceIdentifier);
    bool openOutput(const juce::String& deviceIdentifier);
    void closeInput(const juce::String& deviceIdentifier);
    void closeOutput(const juce::String& deviceIdentifier);
    void closeAllDevices();

    bool isInputOpen(const juce::String& deviceIdentifier) const;
    bool isOutputOpen(const juce::String& deviceIdentifier) const;

    // --- Virtual MIDI Port ---
    bool createVirtualInput(const juce::String& name);
    bool createVirtualOutput(const juce::String& name);

    // --- MIDI Output ---
    void sendNoteOn(uint8_t channel, uint8_t note, uint16_t velocity, uint8_t group = 0);
    void sendNoteOff(uint8_t channel, uint8_t note, uint16_t velocity = 0, uint8_t group = 0);
    void sendControlChange(uint8_t channel, uint8_t cc, uint32_t value, uint8_t group = 0);
    void sendPitchBend(uint8_t channel, uint32_t value, uint8_t group = 0);
    void sendPolyPressure(uint8_t channel, uint8_t note, uint32_t pressure, uint8_t group = 0);
    void sendPerNoteController(uint8_t channel, uint8_t note, uint8_t controller,
                               uint32_t value, uint8_t group = 0);
    void sendProgramChange(uint8_t channel, uint8_t program, uint8_t group = 0);
    void sendAllNotesOff(uint8_t channel = 0xFF);  // 0xFF = all channels

    // --- Active Notes ---
    const std::unordered_map<uint16_t, ActiveNote>& getActiveNotes() const { return activeNotes; }
    int getActiveNoteCount() const;
    bool isNoteActive(uint8_t channel, uint8_t note) const;

    // --- Callbacks ---
    void setNoteOnCallback(NoteOnCallback callback) { noteOnCallback = callback; }
    void setNoteOffCallback(NoteOffCallback callback) { noteOffCallback = callback; }
    void setControlChangeCallback(ControlChangeCallback callback) { ccCallback = callback; }
    void setPitchBendCallback(PitchBendCallback callback) { pitchBendCallback = callback; }
    void setPolyPressureCallback(PolyPressureCallback callback) { polyPressureCallback = callback; }
    void setPerNoteControllerCallback(PerNoteControllerCallback callback) { pncCallback = callback; }

    // --- MIDI Learn ---
    void startMIDILearn(std::function<void(uint8_t channel, uint8_t cc)> callback);
    void stopMIDILearn();
    bool isMIDILearning() const { return midiLearnActive.load(); }

    // --- UMP Conversion ---
    static uint16_t velocity7to16(uint8_t vel7);
    static uint8_t velocity16to7(uint16_t vel16);
    static uint32_t value7to32(uint8_t val7);
    static uint8_t value32to7(uint32_t val32);
    static uint32_t pitchBend14to32(uint16_t bend14);
    static uint16_t pitchBend32to14(uint32_t bend32);

    // --- Statistics ---
    uint64_t getMessagesReceived() const { return messagesReceived.load(); }
    uint64_t getMessagesSent() const { return messagesSent.load(); }

private:
    // juce::MidiInputCallback
    void handleIncomingMidiMessage(juce::MidiInput* source,
                                   const juce::MidiMessage& message) override;

    // Internal processing
    void processNoteOn(const juce::MidiMessage& msg, uint8_t group);
    void processNoteOff(const juce::MidiMessage& msg, uint8_t group);
    void processControlChange(const juce::MidiMessage& msg, uint8_t group);
    void processPitchBend(const juce::MidiMessage& msg, uint8_t group);
    void processAftertouch(const juce::MidiMessage& msg, uint8_t group);
    void processPolyAftertouch(const juce::MidiMessage& msg, uint8_t group);

    // Active note key (channel << 8 | note)
    static uint16_t noteKey(uint8_t channel, uint8_t note) {
        return (static_cast<uint16_t>(channel) << 8) | note;
    }

    // Device management
    std::unordered_map<juce::String, std::unique_ptr<juce::MidiInput>> openInputs;
    std::unordered_map<juce::String, std::unique_ptr<juce::MidiOutput>> openOutputs;

    // Active notes tracking
    std::unordered_map<uint16_t, ActiveNote> activeNotes;
    mutable std::mutex notesMutex;

    // Callbacks
    NoteOnCallback noteOnCallback;
    NoteOffCallback noteOffCallback;
    ControlChangeCallback ccCallback;
    PitchBendCallback pitchBendCallback;
    PolyPressureCallback polyPressureCallback;
    PerNoteControllerCallback pncCallback;

    // MIDI Learn
    std::atomic<bool> midiLearnActive{false};
    std::function<void(uint8_t, uint8_t)> midiLearnCallback;

    // Statistics
    std::atomic<uint64_t> messagesReceived{0};
    std::atomic<uint64_t> messagesSent{0};

    // Thread safety
    mutable std::mutex deviceMutex;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MIDIEngine)
};

} // namespace Echoelmusic
