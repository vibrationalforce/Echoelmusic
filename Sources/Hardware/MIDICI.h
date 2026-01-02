#pragma once

#include <JuceHeader.h>
#include "MIDI2Manager.h"
#include <array>
#include <functional>
#include <map>
#include <memory>
#include <random>
#include <vector>

namespace Echoelmusic {

/**
 * MIDI-CI (Capability Inquiry) Implementation
 *
 * MIDI-CI enables devices to:
 * - Discover each other's capabilities
 * - Negotiate protocols (MIDI 1.0 vs 2.0)
 * - Exchange properties (device info, presets)
 * - Configure profiles (MPE, etc.)
 *
 * Message Categories:
 * - Discovery: Find devices and capabilities
 * - Protocol Negotiation: Agree on MIDI 1.0/2.0
 * - Profile Configuration: Enable/disable profiles
 * - Property Exchange: Get/set device properties
 */

namespace MIDICI {

//==============================================================================
// Constants
//==============================================================================

// Universal System Exclusive
constexpr uint8_t SYSEX_START = 0xF0;
constexpr uint8_t SYSEX_END = 0xF7;
constexpr uint8_t UNIVERSAL_SYSEX_NON_REALTIME = 0x7E;
constexpr uint8_t UNIVERSAL_SYSEX_REALTIME = 0x7F;

// MIDI-CI Sub-IDs
constexpr uint8_t MIDI_CI_SUB_ID = 0x0D;

// MIDI-CI Message Types
enum class MessageType : uint8_t
{
    // Discovery
    DiscoveryInquiry = 0x70,
    DiscoveryReply = 0x71,
    InvalidateMUID = 0x7E,
    NAK = 0x7F,

    // Protocol Negotiation
    InitiateProtocolNegotiation = 0x10,
    ProtocolNegotiationReply = 0x11,
    SetNewProtocol = 0x12,
    TestNewProtocolInitiatorToResponder = 0x13,
    TestNewProtocolResponderToInitiator = 0x14,
    ConfirmNewProtocol = 0x15,

    // Profile Configuration
    ProfileInquiry = 0x20,
    ProfileInquiryReply = 0x21,
    SetProfileOn = 0x22,
    SetProfileOff = 0x23,
    ProfileEnabledReport = 0x24,
    ProfileDisabledReport = 0x25,
    ProfileDetailsInquiry = 0x28,
    ProfileDetailsReply = 0x29,

    // Property Exchange
    PropertyExchangeCapabilities = 0x30,
    PropertyExchangeCapabilitiesReply = 0x31,
    GetPropertyData = 0x34,
    GetPropertyDataReply = 0x35,
    SetPropertyData = 0x36,
    SetPropertyDataReply = 0x37,
    Subscription = 0x38,
    SubscriptionReply = 0x39,
    Notify = 0x3F
};

// Device Categories
enum class DeviceCategory : uint8_t
{
    Unknown = 0x00,
    Controller = 0x01,
    Synthesizer = 0x02,
    Sampler = 0x03,
    DrumMachine = 0x04,
    EffectProcessor = 0x05,
    Mixer = 0x06,
    DAW = 0x07,
    VirtualInstrument = 0x08,
    AudioInterface = 0x09
};

// Profile IDs (standardized)
struct ProfileID
{
    std::array<uint8_t, 5> bytes = {};

    static ProfileID MPE()
    {
        // MPE Profile: 0x7E 0x00 0x00 0x00 0x01
        return {{0x7E, 0x00, 0x00, 0x00, 0x01}};
    }

    static ProfileID GeneralMIDI()
    {
        return {{0x7E, 0x00, 0x00, 0x00, 0x02}};
    }

    static ProfileID GeneralMIDI2()
    {
        return {{0x7E, 0x00, 0x00, 0x00, 0x03}};
    }

    bool operator==(const ProfileID& other) const
    {
        return bytes == other.bytes;
    }
};

} // namespace MIDICI

//==============================================================================
// MUID (Manufacturer Unique ID)
//==============================================================================

struct MUID
{
    uint32_t value = 0;

    static MUID generate()
    {
        static std::random_device rd;
        static std::mt19937 gen(rd());
        static std::uniform_int_distribution<uint32_t> dist(0x00000001, 0x0FFFFFFE);

        MUID muid;
        muid.value = dist(gen);
        return muid;
    }

    static MUID broadcast()
    {
        return {0x0FFFFFFF};
    }

    bool isBroadcast() const
    {
        return value == 0x0FFFFFFF;
    }

    std::array<uint8_t, 4> toBytes() const
    {
        return {{
            static_cast<uint8_t>(value & 0x7F),
            static_cast<uint8_t>((value >> 7) & 0x7F),
            static_cast<uint8_t>((value >> 14) & 0x7F),
            static_cast<uint8_t>((value >> 21) & 0x7F)
        }};
    }

    static MUID fromBytes(const uint8_t* data)
    {
        MUID muid;
        muid.value = (static_cast<uint32_t>(data[0]) & 0x7F) |
                    ((static_cast<uint32_t>(data[1]) & 0x7F) << 7) |
                    ((static_cast<uint32_t>(data[2]) & 0x7F) << 14) |
                    ((static_cast<uint32_t>(data[3]) & 0x7F) << 21);
        return muid;
    }

    bool operator==(const MUID& other) const { return value == other.value; }
    bool operator!=(const MUID& other) const { return value != other.value; }
};

//==============================================================================
// Device Identity
//==============================================================================

struct DeviceIdentity
{
    uint8_t manufacturerSysExID[3] = {0x00, 0x21, 0x1C};  // Echoelmusic
    uint16_t familyCode = 0x0001;
    uint16_t modelNumber = 0x0001;
    uint32_t softwareRevision = 0x00010000;  // 1.0.0

    std::array<uint8_t, 14> toBytes() const
    {
        return {{
            manufacturerSysExID[0], manufacturerSysExID[1], manufacturerSysExID[2],
            static_cast<uint8_t>(familyCode & 0x7F),
            static_cast<uint8_t>((familyCode >> 7) & 0x7F),
            static_cast<uint8_t>(modelNumber & 0x7F),
            static_cast<uint8_t>((modelNumber >> 7) & 0x7F),
            static_cast<uint8_t>(softwareRevision & 0x7F),
            static_cast<uint8_t>((softwareRevision >> 7) & 0x7F),
            static_cast<uint8_t>((softwareRevision >> 14) & 0x7F),
            static_cast<uint8_t>((softwareRevision >> 21) & 0x7F),
            0, 0, 0  // Padding
        }};
    }
};

//==============================================================================
// Discovered Device
//==============================================================================

struct DiscoveredDevice
{
    MUID muid;
    DeviceIdentity identity;
    MIDICI::DeviceCategory category = MIDICI::DeviceCategory::Unknown;
    uint8_t ciVersion = 0x02;  // MIDI-CI version
    bool supportsMIDI2 = false;
    bool supportsMPE = false;
    bool supportsPropertyExchange = false;
    juce::String name;
};

//==============================================================================
// MIDI-CI Manager
//==============================================================================

class MIDICIManager
{
public:
    MIDICIManager()
    {
        // Generate our MUID
        ourMUID = MUID::generate();

        // Setup default identity
        ourIdentity.manufacturerSysExID[0] = 0x00;
        ourIdentity.manufacturerSysExID[1] = 0x21;
        ourIdentity.manufacturerSysExID[2] = 0x1C;  // Echoelmusic (example)
        ourIdentity.familyCode = 0x0001;
        ourIdentity.modelNumber = 0x0001;
        ourIdentity.softwareRevision = 0x00010000;
    }

    //==========================================================================
    // Discovery
    //==========================================================================

    /** Send discovery inquiry to find MIDI-CI devices */
    std::vector<uint8_t> createDiscoveryInquiry()
    {
        std::vector<uint8_t> sysex;

        sysex.push_back(MIDICI::SYSEX_START);
        sysex.push_back(MIDICI::UNIVERSAL_SYSEX_NON_REALTIME);
        sysex.push_back(0x7F);  // Device ID (broadcast)
        sysex.push_back(MIDICI::MIDI_CI_SUB_ID);
        sysex.push_back(static_cast<uint8_t>(MIDICI::MessageType::DiscoveryInquiry));
        sysex.push_back(0x02);  // CI Version

        // Source MUID
        auto muidBytes = ourMUID.toBytes();
        sysex.insert(sysex.end(), muidBytes.begin(), muidBytes.end());

        // Destination MUID (broadcast)
        auto broadcastMUID = MUID::broadcast().toBytes();
        sysex.insert(sysex.end(), broadcastMUID.begin(), broadcastMUID.end());

        // Device Identity
        auto identityBytes = ourIdentity.toBytes();
        sysex.insert(sysex.end(), identityBytes.begin(), identityBytes.end());

        // Category (DAW/Virtual Instrument)
        sysex.push_back(static_cast<uint8_t>(MIDICI::DeviceCategory::VirtualInstrument));

        // Receive Capabilities
        sysex.push_back(0x07);  // Supports: Protocol Negotiation, Profile Config, Property Exchange

        // Max SysEx Size (4 bytes, 7-bit encoded)
        sysex.push_back(0x00);
        sysex.push_back(0x20);  // 4096 bytes
        sysex.push_back(0x00);
        sysex.push_back(0x00);

        sysex.push_back(MIDICI::SYSEX_END);

        return sysex;
    }

    /** Process incoming MIDI-CI message */
    void processMessage(const uint8_t* data, size_t length)
    {
        if (length < 10)
            return;

        if (data[0] != MIDICI::SYSEX_START ||
            data[1] != MIDICI::UNIVERSAL_SYSEX_NON_REALTIME ||
            data[3] != MIDICI::MIDI_CI_SUB_ID)
            return;

        auto messageType = static_cast<MIDICI::MessageType>(data[4]);
        uint8_t ciVersion = data[5];
        MUID sourceMUID = MUID::fromBytes(&data[6]);
        MUID destMUID = MUID::fromBytes(&data[10]);

        juce::ignoreUnused(ciVersion);

        // Check if message is for us
        if (!destMUID.isBroadcast() && destMUID != ourMUID)
            return;

        switch (messageType)
        {
            case MIDICI::MessageType::DiscoveryReply:
                handleDiscoveryReply(data, length, sourceMUID);
                break;

            case MIDICI::MessageType::ProfileInquiryReply:
                handleProfileInquiryReply(data, length, sourceMUID);
                break;

            case MIDICI::MessageType::PropertyExchangeCapabilitiesReply:
                handlePropertyCapabilitiesReply(data, length, sourceMUID);
                break;

            case MIDICI::MessageType::GetPropertyDataReply:
                handleGetPropertyReply(data, length, sourceMUID);
                break;

            default:
                break;
        }
    }

    //==========================================================================
    // Profile Configuration
    //==========================================================================

    /** Create MPE Profile enable request */
    std::vector<uint8_t> createMPEProfileRequest(MUID targetMUID, bool enable)
    {
        std::vector<uint8_t> sysex;

        sysex.push_back(MIDICI::SYSEX_START);
        sysex.push_back(MIDICI::UNIVERSAL_SYSEX_NON_REALTIME);
        sysex.push_back(0x7F);
        sysex.push_back(MIDICI::MIDI_CI_SUB_ID);
        sysex.push_back(enable ?
            static_cast<uint8_t>(MIDICI::MessageType::SetProfileOn) :
            static_cast<uint8_t>(MIDICI::MessageType::SetProfileOff));
        sysex.push_back(0x02);

        auto sourceMUID = ourMUID.toBytes();
        sysex.insert(sysex.end(), sourceMUID.begin(), sourceMUID.end());

        auto destMUID = targetMUID.toBytes();
        sysex.insert(sysex.end(), destMUID.begin(), destMUID.end());

        // MPE Profile ID
        auto mpeProfile = MIDICI::ProfileID::MPE();
        sysex.insert(sysex.end(), mpeProfile.bytes.begin(), mpeProfile.bytes.end());

        // Number of channels (15 for full MPE)
        sysex.push_back(0x0F);
        sysex.push_back(0x00);

        sysex.push_back(MIDICI::SYSEX_END);

        return sysex;
    }

    //==========================================================================
    // Property Exchange
    //==========================================================================

    /** Create property get request */
    std::vector<uint8_t> createGetPropertyRequest(MUID targetMUID,
                                                   const juce::String& resourcePath)
    {
        std::vector<uint8_t> sysex;

        sysex.push_back(MIDICI::SYSEX_START);
        sysex.push_back(MIDICI::UNIVERSAL_SYSEX_NON_REALTIME);
        sysex.push_back(0x7F);
        sysex.push_back(MIDICI::MIDI_CI_SUB_ID);
        sysex.push_back(static_cast<uint8_t>(MIDICI::MessageType::GetPropertyData));
        sysex.push_back(0x02);

        auto sourceMUID = ourMUID.toBytes();
        sysex.insert(sysex.end(), sourceMUID.begin(), sourceMUID.end());

        auto destMUID = targetMUID.toBytes();
        sysex.insert(sysex.end(), destMUID.begin(), destMUID.end());

        // Request ID
        sysex.push_back(nextRequestID++);

        // Header length + data (JSON format)
        juce::String header = "{\"resource\":\"" + resourcePath + "\"}";
        auto headerData = header.toRawUTF8();
        size_t headerLen = header.getNumBytesAsUTF8();

        // Header length (2 bytes, 7-bit)
        sysex.push_back(static_cast<uint8_t>(headerLen & 0x7F));
        sysex.push_back(static_cast<uint8_t>((headerLen >> 7) & 0x7F));

        // Number of chunks
        sysex.push_back(0x01);
        sysex.push_back(0x00);

        // Chunk number
        sysex.push_back(0x01);
        sysex.push_back(0x00);

        // Header data
        for (size_t i = 0; i < headerLen; ++i)
            sysex.push_back(static_cast<uint8_t>(headerData[i]));

        sysex.push_back(MIDICI::SYSEX_END);

        return sysex;
    }

    //==========================================================================
    // Device Management
    //==========================================================================

    /** Get discovered devices */
    const std::map<uint32_t, DiscoveredDevice>& getDiscoveredDevices() const
    {
        return discoveredDevices;
    }

    /** Get our MUID */
    MUID getOurMUID() const { return ourMUID; }

    //==========================================================================
    // Callbacks
    //==========================================================================

    std::function<void(const DiscoveredDevice&)> onDeviceDiscovered;
    std::function<void(const DiscoveredDevice&, bool mpeEnabled)> onProfileChanged;
    std::function<void(MUID, const juce::String&, const juce::var&)> onPropertyReceived;

private:
    MUID ourMUID;
    DeviceIdentity ourIdentity;
    std::map<uint32_t, DiscoveredDevice> discoveredDevices;
    uint8_t nextRequestID = 1;

    void handleDiscoveryReply(const uint8_t* data, size_t length, MUID sourceMUID)
    {
        if (length < 30)
            return;

        DiscoveredDevice device;
        device.muid = sourceMUID;

        // Parse identity (starting at byte 14)
        device.identity.manufacturerSysExID[0] = data[14];
        device.identity.manufacturerSysExID[1] = data[15];
        device.identity.manufacturerSysExID[2] = data[16];
        device.identity.familyCode = data[17] | (static_cast<uint16_t>(data[18]) << 7);
        device.identity.modelNumber = data[19] | (static_cast<uint16_t>(data[20]) << 7);

        device.category = static_cast<MIDICI::DeviceCategory>(data[28]);

        // Parse capabilities
        uint8_t caps = data[29];
        device.supportsMIDI2 = (caps & 0x04) != 0;
        device.supportsPropertyExchange = (caps & 0x02) != 0;

        discoveredDevices[sourceMUID.value] = device;

        if (onDeviceDiscovered)
            onDeviceDiscovered(device);
    }

    void handleProfileInquiryReply(const uint8_t* data, size_t length, MUID sourceMUID)
    {
        juce::ignoreUnused(data, length);

        auto it = discoveredDevices.find(sourceMUID.value);
        if (it == discoveredDevices.end())
            return;

        // Parse enabled profiles
        // Check for MPE profile
        it->second.supportsMPE = true;  // Simplified

        if (onProfileChanged)
            onProfileChanged(it->second, true);
    }

    void handlePropertyCapabilitiesReply(const uint8_t* data, size_t length, MUID sourceMUID)
    {
        juce::ignoreUnused(data, length, sourceMUID);
        // Parse property exchange capabilities
    }

    void handleGetPropertyReply(const uint8_t* data, size_t length, MUID sourceMUID)
    {
        if (length < 20)
            return;

        // Parse JSON property data
        size_t headerLen = data[15] | (static_cast<size_t>(data[16]) << 7);

        if (length < 19 + headerLen)
            return;

        juce::String jsonData(reinterpret_cast<const char*>(&data[19]), headerLen);

        auto json = juce::JSON::parse(jsonData);
        if (json.isObject())
        {
            if (onPropertyReceived)
                onPropertyReceived(sourceMUID, jsonData, json);
        }
    }

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MIDICIManager)
};

} // namespace Echoelmusic
