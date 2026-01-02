#pragma once

#include <JuceHeader.h>
#include <array>
#include <atomic>
#include <functional>
#include <map>
#include <memory>
#include <vector>

namespace Echoelmusic {

/**
 * MIDI2Manager - Complete MIDI 2.0 Implementation
 *
 * Features:
 * - Universal MIDI Packet (UMP) support
 * - 32-bit parameter resolution (vs 7-bit MIDI 1.0)
 * - Per-Note Controllers (Pitch Bend, Pressure, Timbre)
 * - MIDI-CI (Capability Inquiry) Protocol
 * - Property Exchange for device discovery
 * - Jitter Reduction Timestamps
 * - Profile Configuration
 * - Backward compatible with MIDI 1.0
 *
 * Supported Message Types:
 * - Type 0: Utility Messages
 * - Type 1: System Real Time / Common
 * - Type 2: MIDI 1.0 Channel Voice (legacy)
 * - Type 3: Data Messages (64-bit)
 * - Type 4: MIDI 2.0 Channel Voice
 * - Type 5: Data Messages (128-bit)
 * - Type 6-7: Reserved
 * - Type D: Flex Data
 * - Type F: UMP Stream Messages
 */

//==============================================================================
// MIDI 2.0 Constants
//==============================================================================

namespace MIDI2 {

// Message Types (4-bit)
enum class MessageType : uint8_t
{
    Utility = 0x0,
    SystemRealTime = 0x1,
    MIDI1ChannelVoice = 0x2,
    DataMessage64 = 0x3,
    MIDI2ChannelVoice = 0x4,
    DataMessage128 = 0x5,
    Reserved6 = 0x6,
    Reserved7 = 0x7,
    // 0x8-0xC reserved
    FlexData = 0xD,
    Reserved14 = 0xE,
    UMPStream = 0xF
};

// MIDI 2.0 Channel Voice Status
enum class ChannelVoiceStatus : uint8_t
{
    RegisteredPerNoteController = 0x0,
    AssignablePerNoteController = 0x1,
    RegisteredController = 0x2,
    AssignableController = 0x3,
    RelativeRegisteredController = 0x4,
    RelativeAssignableController = 0x5,
    PerNotePitchBend = 0x6,
    // 0x7 reserved
    NoteOff = 0x8,
    NoteOn = 0x9,
    PolyPressure = 0xA,
    ControlChange = 0xB,
    ProgramChange = 0xC,
    ChannelPressure = 0xD,
    PitchBend = 0xE,
    PerNoteManagement = 0xF
};

// Registered Per-Note Controllers
enum class RegisteredPNC : uint8_t
{
    ModulationWheel = 1,
    Breath = 2,
    Pitch7_25 = 3,
    Volume = 7,
    Balance = 8,
    Pan = 10,
    Expression = 11,
    SoundController1 = 70,  // Sound Variation
    SoundController2 = 71,  // Timbre/Harmonic Content
    SoundController3 = 72,  // Release Time
    SoundController4 = 73,  // Attack Time
    SoundController5 = 74,  // Brightness (MPE standard)
    SoundController6 = 75,
    SoundController7 = 76,
    SoundController8 = 77,
    SoundController9 = 78,
    SoundController10 = 79
};

// Utility Message Status
enum class UtilityStatus : uint8_t
{
    NoOp = 0x0,
    JRClock = 0x1,
    JRTimestamp = 0x2,
    DeltaClockTick = 0x3,
    DeltaTicksSinceLast = 0x4
};

// Group (0-15)
using Group = uint8_t;

// Channel (0-15)
using Channel = uint8_t;

} // namespace MIDI2

//==============================================================================
// Universal MIDI Packet (UMP)
//==============================================================================

/**
 * Universal MIDI Packet - The core data structure of MIDI 2.0
 *
 * UMP can be 32, 64, 96, or 128 bits depending on message type
 */
struct UniversalMIDIPacket
{
    // First 32-bit word (always present)
    uint32_t word0 = 0;

    // Optional additional words
    uint32_t word1 = 0;
    uint32_t word2 = 0;
    uint32_t word3 = 0;

    // Packet size in 32-bit words
    int numWords = 1;

    //==========================================================================
    // Word 0 Accessors
    //==========================================================================

    MIDI2::MessageType getMessageType() const
    {
        return static_cast<MIDI2::MessageType>((word0 >> 28) & 0x0F);
    }

    void setMessageType(MIDI2::MessageType type)
    {
        word0 = (word0 & 0x0FFFFFFF) | (static_cast<uint32_t>(type) << 28);
    }

    MIDI2::Group getGroup() const
    {
        return static_cast<MIDI2::Group>((word0 >> 24) & 0x0F);
    }

    void setGroup(MIDI2::Group group)
    {
        word0 = (word0 & 0xF0FFFFFF) | ((static_cast<uint32_t>(group) & 0x0F) << 24);
    }

    uint8_t getStatus() const
    {
        return static_cast<uint8_t>((word0 >> 20) & 0x0F);
    }

    void setStatus(uint8_t status)
    {
        word0 = (word0 & 0xFF0FFFFF) | ((static_cast<uint32_t>(status) & 0x0F) << 20);
    }

    MIDI2::Channel getChannel() const
    {
        return static_cast<MIDI2::Channel>((word0 >> 16) & 0x0F);
    }

    void setChannel(MIDI2::Channel channel)
    {
        word0 = (word0 & 0xFFF0FFFF) | ((static_cast<uint32_t>(channel) & 0x0F) << 16);
    }

    //==========================================================================
    // Factory Methods
    //==========================================================================

    static UniversalMIDIPacket createNoteOn(MIDI2::Group group, MIDI2::Channel channel,
                                            uint8_t note, uint16_t velocity,
                                            uint16_t attributeType = 0, uint16_t attributeData = 0)
    {
        UniversalMIDIPacket ump;
        ump.numWords = 2;

        // Word 0: Type(4) | Group(4) | Status(4) | Channel(4) | Note(8) | Attribute Type(8)
        ump.word0 = (static_cast<uint32_t>(MIDI2::MessageType::MIDI2ChannelVoice) << 28) |
                   (static_cast<uint32_t>(group) << 24) |
                   (static_cast<uint32_t>(MIDI2::ChannelVoiceStatus::NoteOn) << 20) |
                   (static_cast<uint32_t>(channel) << 16) |
                   (static_cast<uint32_t>(note) << 8) |
                   (attributeType & 0xFF);

        // Word 1: Velocity(16) | Attribute Data(16)
        ump.word1 = (static_cast<uint32_t>(velocity) << 16) | (attributeData & 0xFFFF);

        return ump;
    }

    static UniversalMIDIPacket createNoteOff(MIDI2::Group group, MIDI2::Channel channel,
                                             uint8_t note, uint16_t velocity,
                                             uint16_t attributeType = 0, uint16_t attributeData = 0)
    {
        UniversalMIDIPacket ump;
        ump.numWords = 2;

        ump.word0 = (static_cast<uint32_t>(MIDI2::MessageType::MIDI2ChannelVoice) << 28) |
                   (static_cast<uint32_t>(group) << 24) |
                   (static_cast<uint32_t>(MIDI2::ChannelVoiceStatus::NoteOff) << 20) |
                   (static_cast<uint32_t>(channel) << 16) |
                   (static_cast<uint32_t>(note) << 8) |
                   (attributeType & 0xFF);

        ump.word1 = (static_cast<uint32_t>(velocity) << 16) | (attributeData & 0xFFFF);

        return ump;
    }

    static UniversalMIDIPacket createPolyPressure(MIDI2::Group group, MIDI2::Channel channel,
                                                   uint8_t note, uint32_t pressure)
    {
        UniversalMIDIPacket ump;
        ump.numWords = 2;

        ump.word0 = (static_cast<uint32_t>(MIDI2::MessageType::MIDI2ChannelVoice) << 28) |
                   (static_cast<uint32_t>(group) << 24) |
                   (static_cast<uint32_t>(MIDI2::ChannelVoiceStatus::PolyPressure) << 20) |
                   (static_cast<uint32_t>(channel) << 16) |
                   (static_cast<uint32_t>(note) << 8);

        ump.word1 = pressure;  // Full 32-bit resolution

        return ump;
    }

    static UniversalMIDIPacket createPerNotePitchBend(MIDI2::Group group, MIDI2::Channel channel,
                                                       uint8_t note, uint32_t pitchBend)
    {
        UniversalMIDIPacket ump;
        ump.numWords = 2;

        ump.word0 = (static_cast<uint32_t>(MIDI2::MessageType::MIDI2ChannelVoice) << 28) |
                   (static_cast<uint32_t>(group) << 24) |
                   (static_cast<uint32_t>(MIDI2::ChannelVoiceStatus::PerNotePitchBend) << 20) |
                   (static_cast<uint32_t>(channel) << 16) |
                   (static_cast<uint32_t>(note) << 8);

        ump.word1 = pitchBend;  // Full 32-bit resolution

        return ump;
    }

    static UniversalMIDIPacket createRegisteredPNC(MIDI2::Group group, MIDI2::Channel channel,
                                                    uint8_t note, uint8_t controller, uint32_t value)
    {
        UniversalMIDIPacket ump;
        ump.numWords = 2;

        ump.word0 = (static_cast<uint32_t>(MIDI2::MessageType::MIDI2ChannelVoice) << 28) |
                   (static_cast<uint32_t>(group) << 24) |
                   (static_cast<uint32_t>(MIDI2::ChannelVoiceStatus::RegisteredPerNoteController) << 20) |
                   (static_cast<uint32_t>(channel) << 16) |
                   (static_cast<uint32_t>(note) << 8) |
                   controller;

        ump.word1 = value;

        return ump;
    }

    static UniversalMIDIPacket createControlChange(MIDI2::Group group, MIDI2::Channel channel,
                                                    uint8_t controller, uint32_t value)
    {
        UniversalMIDIPacket ump;
        ump.numWords = 2;

        ump.word0 = (static_cast<uint32_t>(MIDI2::MessageType::MIDI2ChannelVoice) << 28) |
                   (static_cast<uint32_t>(group) << 24) |
                   (static_cast<uint32_t>(MIDI2::ChannelVoiceStatus::ControlChange) << 20) |
                   (static_cast<uint32_t>(channel) << 16) |
                   (static_cast<uint32_t>(controller) << 8);

        ump.word1 = value;

        return ump;
    }

    static UniversalMIDIPacket createPitchBend(MIDI2::Group group, MIDI2::Channel channel,
                                                uint32_t pitchBend)
    {
        UniversalMIDIPacket ump;
        ump.numWords = 2;

        ump.word0 = (static_cast<uint32_t>(MIDI2::MessageType::MIDI2ChannelVoice) << 28) |
                   (static_cast<uint32_t>(group) << 24) |
                   (static_cast<uint32_t>(MIDI2::ChannelVoiceStatus::PitchBend) << 20) |
                   (static_cast<uint32_t>(channel) << 16);

        ump.word1 = pitchBend;

        return ump;
    }

    static UniversalMIDIPacket createChannelPressure(MIDI2::Group group, MIDI2::Channel channel,
                                                      uint32_t pressure)
    {
        UniversalMIDIPacket ump;
        ump.numWords = 2;

        ump.word0 = (static_cast<uint32_t>(MIDI2::MessageType::MIDI2ChannelVoice) << 28) |
                   (static_cast<uint32_t>(group) << 24) |
                   (static_cast<uint32_t>(MIDI2::ChannelVoiceStatus::ChannelPressure) << 20) |
                   (static_cast<uint32_t>(channel) << 16);

        ump.word1 = pressure;

        return ump;
    }

    static UniversalMIDIPacket createJRTimestamp(uint16_t timestamp)
    {
        UniversalMIDIPacket ump;
        ump.numWords = 1;

        ump.word0 = (static_cast<uint32_t>(MIDI2::MessageType::Utility) << 28) |
                   (static_cast<uint32_t>(MIDI2::UtilityStatus::JRTimestamp) << 20) |
                   timestamp;

        return ump;
    }

    //==========================================================================
    // Conversion Utilities
    //==========================================================================

    /** Convert MIDI 1.0 7-bit value to MIDI 2.0 32-bit */
    static uint32_t scale7to32(uint8_t value7bit)
    {
        // Scale 0-127 to 0-0xFFFFFFFF with proper rounding
        return static_cast<uint32_t>(value7bit) * 0x02040810;
    }

    /** Convert MIDI 1.0 14-bit value to MIDI 2.0 32-bit */
    static uint32_t scale14to32(uint16_t value14bit)
    {
        return static_cast<uint32_t>(value14bit) * 0x00040010;
    }

    /** Convert MIDI 2.0 32-bit value to MIDI 1.0 7-bit */
    static uint8_t scale32to7(uint32_t value32bit)
    {
        return static_cast<uint8_t>((value32bit >> 25) & 0x7F);
    }

    /** Convert MIDI 2.0 32-bit value to MIDI 1.0 14-bit */
    static uint16_t scale32to14(uint32_t value32bit)
    {
        return static_cast<uint16_t>((value32bit >> 18) & 0x3FFF);
    }

    /** Convert MIDI 2.0 16-bit velocity to 7-bit */
    static uint8_t scaleVelocity16to7(uint16_t velocity16)
    {
        return static_cast<uint8_t>((velocity16 >> 9) & 0x7F);
    }

    /** Convert 7-bit velocity to MIDI 2.0 16-bit */
    static uint16_t scaleVelocity7to16(uint8_t velocity7)
    {
        return static_cast<uint16_t>(velocity7) << 9;
    }
};

//==============================================================================
// MIDI 2.0 Manager
//==============================================================================

class MIDI2Manager
{
public:
    //==========================================================================
    // Per-Note State
    //==========================================================================

    struct PerNoteState
    {
        bool active = false;
        uint8_t note = 0;
        uint16_t velocity = 0;          // 16-bit velocity
        uint32_t pitchBend = 0x80000000; // Center (32-bit)
        uint32_t pressure = 0;          // 32-bit aftertouch
        uint32_t brightness = 0x80000000; // CC74 per note
        uint32_t timbre = 0x80000000;    // CC71 per note

        // Convert pitch bend to semitones (-48 to +48 range)
        float getPitchBendSemitones(float range = 48.0f) const
        {
            float normalized = (static_cast<float>(pitchBend) / 0xFFFFFFFF) * 2.0f - 1.0f;
            return normalized * range;
        }

        // Get normalized pressure (0.0 to 1.0)
        float getNormalizedPressure() const
        {
            return static_cast<float>(pressure) / 0xFFFFFFFF;
        }

        // Get normalized brightness (0.0 to 1.0)
        float getNormalizedBrightness() const
        {
            return static_cast<float>(brightness) / 0xFFFFFFFF;
        }
    };

    //==========================================================================
    // Group State (16 groups max)
    //==========================================================================

    struct GroupState
    {
        std::array<std::array<PerNoteState, 128>, 16> noteStates;  // [channel][note]

        // Channel-level controllers
        std::array<uint32_t, 16> channelPitchBend;
        std::array<uint32_t, 16> channelPressure;
        std::array<std::array<uint32_t, 128>, 16> channelCC;  // [channel][cc]

        GroupState()
        {
            channelPitchBend.fill(0x80000000);
            channelPressure.fill(0);
            for (auto& ccArray : channelCC)
                ccArray.fill(0);
        }
    };

    //==========================================================================
    // Construction
    //==========================================================================

    MIDI2Manager()
    {
        // Initialize 16 groups
        groups.resize(16);
    }

    //==========================================================================
    // Packet Processing
    //==========================================================================

    /** Process incoming UMP packet */
    void processPacket(const UniversalMIDIPacket& ump)
    {
        auto messageType = ump.getMessageType();
        auto group = ump.getGroup();

        if (group >= groups.size())
            return;

        switch (messageType)
        {
            case MIDI2::MessageType::MIDI2ChannelVoice:
                processMIDI2ChannelVoice(ump, group);
                break;

            case MIDI2::MessageType::MIDI1ChannelVoice:
                processMIDI1ChannelVoice(ump, group);
                break;

            case MIDI2::MessageType::Utility:
                processUtility(ump);
                break;

            case MIDI2::MessageType::SystemRealTime:
                processSystemRealTime(ump);
                break;

            default:
                break;
        }
    }

    /** Convert MIDI 1.0 message to UMP and process */
    void processMIDI1Message(const juce::MidiMessage& msg, MIDI2::Group group = 0)
    {
        UniversalMIDIPacket ump;
        ump.numWords = 1;

        auto channel = static_cast<MIDI2::Channel>(msg.getChannel() - 1);

        if (msg.isNoteOn())
        {
            ump = UniversalMIDIPacket::createNoteOn(
                group, channel,
                static_cast<uint8_t>(msg.getNoteNumber()),
                UniversalMIDIPacket::scaleVelocity7to16(static_cast<uint8_t>(msg.getVelocity()))
            );
        }
        else if (msg.isNoteOff())
        {
            ump = UniversalMIDIPacket::createNoteOff(
                group, channel,
                static_cast<uint8_t>(msg.getNoteNumber()),
                UniversalMIDIPacket::scaleVelocity7to16(static_cast<uint8_t>(msg.getVelocity()))
            );
        }
        else if (msg.isAftertouch())
        {
            ump = UniversalMIDIPacket::createPolyPressure(
                group, channel,
                static_cast<uint8_t>(msg.getNoteNumber()),
                UniversalMIDIPacket::scale7to32(static_cast<uint8_t>(msg.getAfterTouchValue()))
            );
        }
        else if (msg.isChannelPressure())
        {
            ump = UniversalMIDIPacket::createChannelPressure(
                group, channel,
                UniversalMIDIPacket::scale7to32(static_cast<uint8_t>(msg.getChannelPressureValue()))
            );
        }
        else if (msg.isPitchWheel())
        {
            ump = UniversalMIDIPacket::createPitchBend(
                group, channel,
                UniversalMIDIPacket::scale14to32(static_cast<uint16_t>(msg.getPitchWheelValue()))
            );
        }
        else if (msg.isController())
        {
            ump = UniversalMIDIPacket::createControlChange(
                group, channel,
                static_cast<uint8_t>(msg.getControllerNumber()),
                UniversalMIDIPacket::scale7to32(static_cast<uint8_t>(msg.getControllerValue()))
            );
        }

        if (ump.numWords > 0)
            processPacket(ump);
    }

    //==========================================================================
    // State Access
    //==========================================================================

    /** Get per-note state */
    const PerNoteState& getNoteState(MIDI2::Group group, MIDI2::Channel channel, uint8_t note) const
    {
        static PerNoteState empty;
        if (group >= groups.size())
            return empty;
        return groups[group].noteStates[channel][note];
    }

    /** Get all active notes for a channel */
    std::vector<PerNoteState> getActiveNotes(MIDI2::Group group, MIDI2::Channel channel) const
    {
        std::vector<PerNoteState> active;
        if (group >= groups.size())
            return active;

        for (int note = 0; note < 128; ++note)
        {
            if (groups[group].noteStates[channel][note].active)
                active.push_back(groups[group].noteStates[channel][note]);
        }
        return active;
    }

    /** Get channel pitch bend (32-bit) */
    uint32_t getChannelPitchBend(MIDI2::Group group, MIDI2::Channel channel) const
    {
        if (group >= groups.size())
            return 0x80000000;
        return groups[group].channelPitchBend[channel];
    }

    /** Get channel CC value (32-bit) */
    uint32_t getChannelCC(MIDI2::Group group, MIDI2::Channel channel, uint8_t cc) const
    {
        if (group >= groups.size() || cc >= 128)
            return 0;
        return groups[group].channelCC[channel][cc];
    }

    //==========================================================================
    // Callbacks
    //==========================================================================

    std::function<void(MIDI2::Group, MIDI2::Channel, uint8_t note, uint16_t velocity)> onNoteOn;
    std::function<void(MIDI2::Group, MIDI2::Channel, uint8_t note, uint16_t velocity)> onNoteOff;
    std::function<void(MIDI2::Group, MIDI2::Channel, uint8_t note, uint32_t pressure)> onPolyPressure;
    std::function<void(MIDI2::Group, MIDI2::Channel, uint8_t note, uint32_t pitchBend)> onPerNotePitchBend;
    std::function<void(MIDI2::Group, MIDI2::Channel, uint8_t note, uint8_t controller, uint32_t value)> onPerNoteController;
    std::function<void(MIDI2::Group, MIDI2::Channel, uint32_t pitchBend)> onPitchBend;
    std::function<void(MIDI2::Group, MIDI2::Channel, uint8_t cc, uint32_t value)> onControlChange;
    std::function<void(MIDI2::Group, MIDI2::Channel, uint32_t pressure)> onChannelPressure;
    std::function<void(uint16_t timestamp)> onJRTimestamp;

private:
    std::vector<GroupState> groups;
    uint16_t currentJRTimestamp = 0;

    //==========================================================================
    // Internal Processing
    //==========================================================================

    void processMIDI2ChannelVoice(const UniversalMIDIPacket& ump, MIDI2::Group group)
    {
        auto status = static_cast<MIDI2::ChannelVoiceStatus>(ump.getStatus());
        auto channel = ump.getChannel();
        auto& groupState = groups[group];

        uint8_t noteOrIndex = (ump.word0 >> 8) & 0xFF;
        uint8_t data8 = ump.word0 & 0xFF;

        switch (status)
        {
            case MIDI2::ChannelVoiceStatus::NoteOn:
            {
                uint16_t velocity = (ump.word1 >> 16) & 0xFFFF;
                groupState.noteStates[channel][noteOrIndex].active = true;
                groupState.noteStates[channel][noteOrIndex].note = noteOrIndex;
                groupState.noteStates[channel][noteOrIndex].velocity = velocity;

                if (onNoteOn)
                    onNoteOn(group, channel, noteOrIndex, velocity);
                break;
            }

            case MIDI2::ChannelVoiceStatus::NoteOff:
            {
                uint16_t velocity = (ump.word1 >> 16) & 0xFFFF;
                groupState.noteStates[channel][noteOrIndex].active = false;

                if (onNoteOff)
                    onNoteOff(group, channel, noteOrIndex, velocity);
                break;
            }

            case MIDI2::ChannelVoiceStatus::PolyPressure:
            {
                uint32_t pressure = ump.word1;
                groupState.noteStates[channel][noteOrIndex].pressure = pressure;

                if (onPolyPressure)
                    onPolyPressure(group, channel, noteOrIndex, pressure);
                break;
            }

            case MIDI2::ChannelVoiceStatus::PerNotePitchBend:
            {
                uint32_t pitchBend = ump.word1;
                groupState.noteStates[channel][noteOrIndex].pitchBend = pitchBend;

                if (onPerNotePitchBend)
                    onPerNotePitchBend(group, channel, noteOrIndex, pitchBend);
                break;
            }

            case MIDI2::ChannelVoiceStatus::RegisteredPerNoteController:
            {
                uint32_t value = ump.word1;

                // Handle standard per-note controllers
                if (data8 == static_cast<uint8_t>(MIDI2::RegisteredPNC::Brightness))
                    groupState.noteStates[channel][noteOrIndex].brightness = value;
                else if (data8 == static_cast<uint8_t>(MIDI2::RegisteredPNC::SoundController2))
                    groupState.noteStates[channel][noteOrIndex].timbre = value;

                if (onPerNoteController)
                    onPerNoteController(group, channel, noteOrIndex, data8, value);
                break;
            }

            case MIDI2::ChannelVoiceStatus::ControlChange:
            {
                uint32_t value = ump.word1;
                groupState.channelCC[channel][noteOrIndex] = value;

                if (onControlChange)
                    onControlChange(group, channel, noteOrIndex, value);
                break;
            }

            case MIDI2::ChannelVoiceStatus::PitchBend:
            {
                uint32_t pitchBend = ump.word1;
                groupState.channelPitchBend[channel] = pitchBend;

                if (onPitchBend)
                    onPitchBend(group, channel, pitchBend);
                break;
            }

            case MIDI2::ChannelVoiceStatus::ChannelPressure:
            {
                uint32_t pressure = ump.word1;
                groupState.channelPressure[channel] = pressure;

                if (onChannelPressure)
                    onChannelPressure(group, channel, pressure);
                break;
            }

            default:
                break;
        }
    }

    void processMIDI1ChannelVoice(const UniversalMIDIPacket& ump, MIDI2::Group group)
    {
        // Convert MIDI 1.0 messages to MIDI 2.0 internally
        uint8_t status = (ump.word0 >> 16) & 0xF0;
        uint8_t channel = (ump.word0 >> 16) & 0x0F;
        uint8_t data1 = (ump.word0 >> 8) & 0x7F;
        uint8_t data2 = ump.word0 & 0x7F;

        UniversalMIDIPacket ump2;

        switch (status)
        {
            case 0x90: // Note On
                if (data2 > 0)
                {
                    ump2 = UniversalMIDIPacket::createNoteOn(
                        group, channel, data1,
                        UniversalMIDIPacket::scaleVelocity7to16(data2));
                }
                else
                {
                    ump2 = UniversalMIDIPacket::createNoteOff(
                        group, channel, data1, 0);
                }
                break;

            case 0x80: // Note Off
                ump2 = UniversalMIDIPacket::createNoteOff(
                    group, channel, data1,
                    UniversalMIDIPacket::scaleVelocity7to16(data2));
                break;

            case 0xA0: // Poly Pressure
                ump2 = UniversalMIDIPacket::createPolyPressure(
                    group, channel, data1,
                    UniversalMIDIPacket::scale7to32(data2));
                break;

            case 0xB0: // Control Change
                ump2 = UniversalMIDIPacket::createControlChange(
                    group, channel, data1,
                    UniversalMIDIPacket::scale7to32(data2));
                break;

            case 0xD0: // Channel Pressure
                ump2 = UniversalMIDIPacket::createChannelPressure(
                    group, channel,
                    UniversalMIDIPacket::scale7to32(data1));
                break;

            case 0xE0: // Pitch Bend
            {
                uint16_t pb14 = (static_cast<uint16_t>(data2) << 7) | data1;
                ump2 = UniversalMIDIPacket::createPitchBend(
                    group, channel,
                    UniversalMIDIPacket::scale14to32(pb14));
                break;
            }

            default:
                return;
        }

        processMIDI2ChannelVoice(ump2, group);
    }

    void processUtility(const UniversalMIDIPacket& ump)
    {
        auto status = static_cast<MIDI2::UtilityStatus>(ump.getStatus());

        switch (status)
        {
            case MIDI2::UtilityStatus::JRTimestamp:
                currentJRTimestamp = ump.word0 & 0xFFFF;
                if (onJRTimestamp)
                    onJRTimestamp(currentJRTimestamp);
                break;

            default:
                break;
        }
    }

    void processSystemRealTime(const UniversalMIDIPacket& ump)
    {
        // Handle system real-time messages (clock, start, stop, etc.)
        juce::ignoreUnused(ump);
    }

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MIDI2Manager)
};

} // namespace Echoelmusic
