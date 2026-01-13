#pragma once
// ============================================================================
// EchoelDSP - MIDI 2.0 Protocol Support
// ============================================================================
// Universal MIDI Packet (UMP) implementation
// - MIDI 1.0 Channel Voice Messages (32-bit)
// - MIDI 2.0 Channel Voice Messages (64-bit)
// - System Messages
// - Data Messages (SysEx8, Mixed Data Set)
// - Flex Data (Metadata, Performance Controller)
// ============================================================================

#include <atomic>
#include <cstdint>
#include <array>
#include <string>
#include <vector>
#include <functional>

namespace Echoel::DSP::MIDI2 {

// ============================================================================
// MIDI 2.0 Universal MIDI Packet (UMP) Types
// ============================================================================

enum class MessageType : uint8_t {
    // Utility Messages (MT = 0x0)
    Utility = 0x0,

    // System Real Time and System Common (MT = 0x1)
    SystemRealTime = 0x1,

    // MIDI 1.0 Channel Voice Messages (MT = 0x2)
    MIDI1ChannelVoice = 0x2,

    // Data Messages including SysEx (MT = 0x3)
    Data64 = 0x3,

    // MIDI 2.0 Channel Voice Messages (MT = 0x4)
    MIDI2ChannelVoice = 0x4,

    // Data Messages (MT = 0x5)
    Data128 = 0x5,

    // Flex Data Messages (MT = 0xD)
    FlexData = 0xD,

    // UMP Stream Messages (MT = 0xF)
    UMPStream = 0xF
};

enum class MIDI1Status : uint8_t {
    NoteOff = 0x80,
    NoteOn = 0x90,
    PolyPressure = 0xA0,
    ControlChange = 0xB0,
    ProgramChange = 0xC0,
    ChannelPressure = 0xD0,
    PitchBend = 0xE0
};

enum class MIDI2Status : uint8_t {
    RegisteredPerNoteController = 0x00,
    AssignablePerNoteController = 0x10,
    RegisteredController = 0x20,
    AssignableController = 0x30,
    RelativeRegisteredController = 0x40,
    RelativeAssignableController = 0x50,
    PerNotePitchBend = 0x60,
    NoteOff = 0x80,
    NoteOn = 0x90,
    PolyPressure = 0xA0,
    ControlChange = 0xB0,
    ProgramChange = 0xC0,
    ChannelPressure = 0xD0,
    PitchBend = 0xE0,
    PerNoteManagement = 0xF0
};

// ============================================================================
// Universal MIDI Packet (UMP)
// ============================================================================

struct UniversalMIDIPacket {
    // UMP can be 32, 64, 96, or 128 bits
    std::array<uint32_t, 4> words{0, 0, 0, 0};

    // Header extraction
    MessageType messageType() const noexcept {
        return static_cast<MessageType>((words[0] >> 28) & 0xF);
    }

    uint8_t group() const noexcept {
        return (words[0] >> 24) & 0xF;
    }

    uint8_t channel() const noexcept {
        return (words[0] >> 16) & 0xF;
    }

    uint8_t status() const noexcept {
        return (words[0] >> 16) & 0xFF;
    }

    // Size in 32-bit words
    size_t sizeInWords() const noexcept {
        switch (messageType()) {
            case MessageType::Utility:
            case MessageType::SystemRealTime:
            case MessageType::MIDI1ChannelVoice:
                return 1;
            case MessageType::MIDI2ChannelVoice:
            case MessageType::Data64:
                return 2;
            case MessageType::Data128:
            case MessageType::FlexData:
            case MessageType::UMPStream:
                return 4;
            default:
                return 1;
        }
    }

    // Create MIDI 1.0 Note On
    static UniversalMIDIPacket midi1NoteOn(uint8_t group, uint8_t channel, uint8_t note, uint8_t velocity) {
        UniversalMIDIPacket ump;
        ump.words[0] = (static_cast<uint32_t>(MessageType::MIDI1ChannelVoice) << 28) |
                       (static_cast<uint32_t>(group) << 24) |
                       (static_cast<uint32_t>(0x90 | channel) << 16) |
                       (static_cast<uint32_t>(note) << 8) |
                       static_cast<uint32_t>(velocity);
        return ump;
    }

    // Create MIDI 1.0 Note Off
    static UniversalMIDIPacket midi1NoteOff(uint8_t group, uint8_t channel, uint8_t note, uint8_t velocity) {
        UniversalMIDIPacket ump;
        ump.words[0] = (static_cast<uint32_t>(MessageType::MIDI1ChannelVoice) << 28) |
                       (static_cast<uint32_t>(group) << 24) |
                       (static_cast<uint32_t>(0x80 | channel) << 16) |
                       (static_cast<uint32_t>(note) << 8) |
                       static_cast<uint32_t>(velocity);
        return ump;
    }

    // Create MIDI 1.0 Control Change
    static UniversalMIDIPacket midi1CC(uint8_t group, uint8_t channel, uint8_t controller, uint8_t value) {
        UniversalMIDIPacket ump;
        ump.words[0] = (static_cast<uint32_t>(MessageType::MIDI1ChannelVoice) << 28) |
                       (static_cast<uint32_t>(group) << 24) |
                       (static_cast<uint32_t>(0xB0 | channel) << 16) |
                       (static_cast<uint32_t>(controller) << 8) |
                       static_cast<uint32_t>(value);
        return ump;
    }

    // Create MIDI 2.0 Note On (64-bit with velocity, attribute)
    static UniversalMIDIPacket midi2NoteOn(uint8_t group, uint8_t channel, uint8_t note,
                                           uint16_t velocity, uint8_t attributeType = 0, uint16_t attributeData = 0) {
        UniversalMIDIPacket ump;
        ump.words[0] = (static_cast<uint32_t>(MessageType::MIDI2ChannelVoice) << 28) |
                       (static_cast<uint32_t>(group) << 24) |
                       (static_cast<uint32_t>(0x90 | channel) << 16) |
                       (static_cast<uint32_t>(note) << 8) |
                       static_cast<uint32_t>(attributeType);
        ump.words[1] = (static_cast<uint32_t>(velocity) << 16) | attributeData;
        return ump;
    }

    // Create MIDI 2.0 Note Off (64-bit)
    static UniversalMIDIPacket midi2NoteOff(uint8_t group, uint8_t channel, uint8_t note,
                                            uint16_t velocity, uint8_t attributeType = 0, uint16_t attributeData = 0) {
        UniversalMIDIPacket ump;
        ump.words[0] = (static_cast<uint32_t>(MessageType::MIDI2ChannelVoice) << 28) |
                       (static_cast<uint32_t>(group) << 24) |
                       (static_cast<uint32_t>(0x80 | channel) << 16) |
                       (static_cast<uint32_t>(note) << 8) |
                       static_cast<uint32_t>(attributeType);
        ump.words[1] = (static_cast<uint32_t>(velocity) << 16) | attributeData;
        return ump;
    }

    // Create MIDI 2.0 Control Change (64-bit, 32-bit value)
    static UniversalMIDIPacket midi2CC(uint8_t group, uint8_t channel, uint8_t controller, uint32_t value) {
        UniversalMIDIPacket ump;
        ump.words[0] = (static_cast<uint32_t>(MessageType::MIDI2ChannelVoice) << 28) |
                       (static_cast<uint32_t>(group) << 24) |
                       (static_cast<uint32_t>(0xB0 | channel) << 16) |
                       static_cast<uint32_t>(controller);
        ump.words[1] = value;
        return ump;
    }

    // Create MIDI 2.0 Pitch Bend (64-bit, 32-bit value)
    static UniversalMIDIPacket midi2PitchBend(uint8_t group, uint8_t channel, uint32_t value) {
        UniversalMIDIPacket ump;
        ump.words[0] = (static_cast<uint32_t>(MessageType::MIDI2ChannelVoice) << 28) |
                       (static_cast<uint32_t>(group) << 24) |
                       (static_cast<uint32_t>(0xE0 | channel) << 16);
        ump.words[1] = value;
        return ump;
    }

    // Create MIDI 2.0 Per-Note Pitch Bend (64-bit)
    static UniversalMIDIPacket midi2PerNotePitchBend(uint8_t group, uint8_t channel, uint8_t note, uint32_t value) {
        UniversalMIDIPacket ump;
        ump.words[0] = (static_cast<uint32_t>(MessageType::MIDI2ChannelVoice) << 28) |
                       (static_cast<uint32_t>(group) << 24) |
                       (static_cast<uint32_t>(0x60 | channel) << 16) |
                       (static_cast<uint32_t>(note) << 8);
        ump.words[1] = value;
        return ump;
    }

    // Create MIDI 2.0 Channel Pressure (64-bit, 32-bit value)
    static UniversalMIDIPacket midi2ChannelPressure(uint8_t group, uint8_t channel, uint32_t value) {
        UniversalMIDIPacket ump;
        ump.words[0] = (static_cast<uint32_t>(MessageType::MIDI2ChannelVoice) << 28) |
                       (static_cast<uint32_t>(group) << 24) |
                       (static_cast<uint32_t>(0xD0 | channel) << 16);
        ump.words[1] = value;
        return ump;
    }

    // Create MIDI 2.0 Poly Pressure (64-bit, 32-bit value)
    static UniversalMIDIPacket midi2PolyPressure(uint8_t group, uint8_t channel, uint8_t note, uint32_t value) {
        UniversalMIDIPacket ump;
        ump.words[0] = (static_cast<uint32_t>(MessageType::MIDI2ChannelVoice) << 28) |
                       (static_cast<uint32_t>(group) << 24) |
                       (static_cast<uint32_t>(0xA0 | channel) << 16) |
                       (static_cast<uint32_t>(note) << 8);
        ump.words[1] = value;
        return ump;
    }
};

// ============================================================================
// MIDI-CI (MIDI Capability Inquiry)
// ============================================================================

struct MIDICICapabilities {
    uint8_t protocolVersion{2};  // MIDI 2.0
    bool supportsProfileConfiguration{true};
    bool supportsPropertyExchange{true};
    bool supportsProcessInquiry{true};

    // Device identity
    uint8_t deviceManufacturer[3]{0x00, 0x21, 0x09};  // Example: Native Instruments
    uint8_t deviceFamily[2]{0x00, 0x00};
    uint8_t deviceModel[2]{0x00, 0x00};
    uint8_t softwareRevision[4]{1, 0, 0, 0};

    // MUID (Message UID) - unique identifier for this device
    uint32_t muid{0};
};

// ============================================================================
// MIDI 2.0 Profile Configuration
// ============================================================================

struct MIDIProfile {
    uint8_t profileId[5]{0};  // 5-byte profile ID
    std::string name;
    bool enabled{false};
    uint8_t numChannelsRequested{1};
};

// Standard Profiles
namespace StandardProfiles {
    // General MIDI 2 Profile
    constexpr uint8_t GeneralMIDI2[5] = {0x7E, 0x00, 0x00, 0x01, 0x01};

    // MPE Profile
    constexpr uint8_t MPE[5] = {0x7E, 0x00, 0x00, 0x02, 0x01};

    // Drawbar Organ Profile
    constexpr uint8_t DrawbarOrgan[5] = {0x7E, 0x00, 0x00, 0x03, 0x01};

    // Default Control Change Mapping
    constexpr uint8_t DefaultControlChange[5] = {0x7E, 0x00, 0x00, 0x04, 0x01};
}

// ============================================================================
// MPE (MIDI Polyphonic Expression) Support
// ============================================================================

class MPEConfiguration {
public:
    enum class Zone : uint8_t {
        Lower = 0,  // Channel 2-8  (Manager on Channel 1)
        Upper = 1   // Channel 9-15 (Manager on Channel 16)
    };

    struct ZoneConfig {
        Zone zone{Zone::Lower};
        uint8_t managerChannel{0};   // 0 for lower, 15 for upper
        uint8_t memberChannels{7};   // Number of member channels (1-15)
        uint16_t pitchBendRange{48}; // In semitones (default 48 for MPE)
        bool enabled{false};
    };

    ZoneConfig lowerZone;
    ZoneConfig upperZone;

    // Configure standard MPE with both zones
    void configureStandardMPE() {
        lowerZone.zone = Zone::Lower;
        lowerZone.managerChannel = 0;
        lowerZone.memberChannels = 7;
        lowerZone.pitchBendRange = 48;
        lowerZone.enabled = true;

        upperZone.zone = Zone::Upper;
        upperZone.managerChannel = 15;
        upperZone.memberChannels = 7;
        upperZone.pitchBendRange = 48;
        upperZone.enabled = true;
    }

    // Configure single zone MPE
    void configureSingleZone(Zone zone, uint8_t memberChannels = 15) {
        if (zone == Zone::Lower) {
            lowerZone.zone = Zone::Lower;
            lowerZone.managerChannel = 0;
            lowerZone.memberChannels = memberChannels;
            lowerZone.pitchBendRange = 48;
            lowerZone.enabled = true;
            upperZone.enabled = false;
        } else {
            upperZone.zone = Zone::Upper;
            upperZone.managerChannel = 15;
            upperZone.memberChannels = memberChannels;
            upperZone.pitchBendRange = 48;
            upperZone.enabled = true;
            lowerZone.enabled = false;
        }
    }

    // Get channel for a new note
    uint8_t allocateChannel(Zone zone) {
        // Round-robin channel allocation for per-note expression
        if (zone == Zone::Lower && lowerZone.enabled) {
            uint8_t channel = (lowerNextChannel_++ % lowerZone.memberChannels) + 1;
            return channel;
        } else if (zone == Zone::Upper && upperZone.enabled) {
            uint8_t channel = 15 - (upperNextChannel_++ % upperZone.memberChannels);
            return channel;
        }
        return 0;
    }

private:
    uint8_t lowerNextChannel_{0};
    uint8_t upperNextChannel_{0};
};

// ============================================================================
// MIDI 2.0 Message Processor
// ============================================================================

class MIDI2Processor {
public:
    using MessageCallback = std::function<void(const UniversalMIDIPacket& ump)>;

    void setCallback(MessageCallback callback) {
        callback_ = std::move(callback);
    }

    // Process incoming UMP
    void processUMP(const UniversalMIDIPacket& ump) {
        switch (ump.messageType()) {
            case MessageType::MIDI1ChannelVoice:
                processMIDI1ChannelVoice(ump);
                break;
            case MessageType::MIDI2ChannelVoice:
                processMIDI2ChannelVoice(ump);
                break;
            case MessageType::SystemRealTime:
                processSystemRealTime(ump);
                break;
            case MessageType::Data64:
            case MessageType::Data128:
                processDataMessage(ump);
                break;
            case MessageType::FlexData:
                processFlexData(ump);
                break;
            default:
                break;
        }

        if (callback_) {
            callback_(ump);
        }
    }

    // Convert MIDI 1.0 to MIDI 2.0 UMP
    static UniversalMIDIPacket convertMIDI1ToUMP(uint8_t group, const uint8_t* midiBytes, size_t length) {
        UniversalMIDIPacket ump;
        if (length == 0) return ump;

        uint8_t status = midiBytes[0] & 0xF0;
        uint8_t channel = midiBytes[0] & 0x0F;

        ump.words[0] = (static_cast<uint32_t>(MessageType::MIDI1ChannelVoice) << 28) |
                       (static_cast<uint32_t>(group) << 24) |
                       (static_cast<uint32_t>(midiBytes[0]) << 16);

        if (length > 1) {
            ump.words[0] |= (static_cast<uint32_t>(midiBytes[1]) << 8);
        }
        if (length > 2) {
            ump.words[0] |= static_cast<uint32_t>(midiBytes[2]);
        }

        return ump;
    }

    // Convert MIDI 1.0 to MIDI 2.0 with resolution upgrade
    static UniversalMIDIPacket upgradeMIDI1ToMIDI2(const UniversalMIDIPacket& midi1) {
        UniversalMIDIPacket midi2;
        uint8_t group = midi1.group();
        uint8_t channel = midi1.channel();
        uint8_t status = (midi1.words[0] >> 16) & 0xF0;

        switch (status) {
            case 0x80: // Note Off
            case 0x90: { // Note On
                uint8_t note = (midi1.words[0] >> 8) & 0x7F;
                uint8_t velocity = midi1.words[0] & 0x7F;
                // Scale 7-bit to 16-bit velocity
                uint16_t velocity16 = (velocity == 0) ? 0 : ((velocity << 9) | (velocity << 2) | (velocity >> 5));
                if (status == 0x90) {
                    midi2 = UniversalMIDIPacket::midi2NoteOn(group, channel, note, velocity16);
                } else {
                    midi2 = UniversalMIDIPacket::midi2NoteOff(group, channel, note, velocity16);
                }
                break;
            }
            case 0xB0: { // Control Change
                uint8_t controller = (midi1.words[0] >> 8) & 0x7F;
                uint8_t value = midi1.words[0] & 0x7F;
                // Scale 7-bit to 32-bit value
                uint32_t value32 = static_cast<uint32_t>(value) << 25;
                midi2 = UniversalMIDIPacket::midi2CC(group, channel, controller, value32);
                break;
            }
            case 0xE0: { // Pitch Bend
                uint8_t lsb = (midi1.words[0] >> 8) & 0x7F;
                uint8_t msb = midi1.words[0] & 0x7F;
                uint16_t value14 = (msb << 7) | lsb;
                // Scale 14-bit to 32-bit value
                uint32_t value32 = static_cast<uint32_t>(value14) << 18;
                midi2 = UniversalMIDIPacket::midi2PitchBend(group, channel, value32);
                break;
            }
            default:
                midi2 = midi1;
                break;
        }

        return midi2;
    }

    // MPE Configuration
    MPEConfiguration& getMPEConfig() { return mpeConfig_; }
    const MPEConfiguration& getMPEConfig() const { return mpeConfig_; }

    // MIDI-CI Capabilities
    MIDICICapabilities& getCICapabilities() { return ciCapabilities_; }
    const MIDICICapabilities& getCICapabilities() const { return ciCapabilities_; }

private:
    MessageCallback callback_;
    MPEConfiguration mpeConfig_;
    MIDICICapabilities ciCapabilities_;

    void processMIDI1ChannelVoice(const UniversalMIDIPacket& ump) {
        // Handle MIDI 1.0 messages
    }

    void processMIDI2ChannelVoice(const UniversalMIDIPacket& ump) {
        // Handle MIDI 2.0 messages with full resolution
    }

    void processSystemRealTime(const UniversalMIDIPacket& ump) {
        // Handle timing clock, start, stop, continue, etc.
    }

    void processDataMessage(const UniversalMIDIPacket& ump) {
        // Handle SysEx and other data messages
    }

    void processFlexData(const UniversalMIDIPacket& ump) {
        // Handle metadata, performance text, etc.
    }
};

// ============================================================================
// High-Resolution Controller Values
// ============================================================================

namespace Controllers {
    // Standard MIDI 1.0 Controllers (7-bit)
    constexpr uint8_t BankSelectMSB = 0;
    constexpr uint8_t ModWheel = 1;
    constexpr uint8_t BreathController = 2;
    constexpr uint8_t FootController = 4;
    constexpr uint8_t PortamentoTime = 5;
    constexpr uint8_t DataEntryMSB = 6;
    constexpr uint8_t Volume = 7;
    constexpr uint8_t Balance = 8;
    constexpr uint8_t Pan = 10;
    constexpr uint8_t Expression = 11;
    constexpr uint8_t BankSelectLSB = 32;
    constexpr uint8_t Sustain = 64;
    constexpr uint8_t Portamento = 65;
    constexpr uint8_t Sostenuto = 66;
    constexpr uint8_t SoftPedal = 67;
    constexpr uint8_t Legato = 68;
    constexpr uint8_t Hold2 = 69;

    // MIDI 2.0 Registered Controllers (full 32-bit resolution)
    namespace Registered {
        constexpr uint8_t PitchBendSensitivity = 0;
        constexpr uint8_t FineTuning = 1;
        constexpr uint8_t CoarseTuning = 2;
        constexpr uint8_t TuningProgramSelect = 3;
        constexpr uint8_t TuningBankSelect = 4;
        constexpr uint8_t MPEConfiguration = 6;
    }

    // MPE Controllers
    namespace MPE {
        constexpr uint8_t Slide = 74;      // Vertical movement (Y-axis)
        // Note: Pitch bend (X-axis) and pressure (Z-axis) are standard
    }

    // Bio-Reactive Controllers (Custom - Assignable range 102-119)
    namespace BioReactive {
        constexpr uint8_t HeartRate = 102;
        constexpr uint8_t HRVCoherence = 103;
        constexpr uint8_t BreathingRate = 104;
        constexpr uint8_t BreathingPhase = 105;
        constexpr uint8_t GSR = 106;
        constexpr uint8_t Temperature = 107;
        constexpr uint8_t SpO2 = 108;
        constexpr uint8_t EEGAlpha = 109;
        constexpr uint8_t EEGBeta = 110;
        constexpr uint8_t EEGTheta = 111;
        constexpr uint8_t LambdaScore = 112;
    }
}

} // namespace Echoel::DSP::MIDI2
