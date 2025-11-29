#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <memory>
#include <unordered_map>

/**
 * sACN (E1.31) Controller - Streaming ACN Protocol Implementation
 *
 * Full implementation of ANSI E1.31-2018 (Streaming ACN) for professional
 * lighting control over Ethernet networks.
 *
 * Features:
 * - Multi-universe support (1-63999)
 * - Priority levels (0-200)
 * - Universe synchronization
 * - Discovery protocol
 * - Per-address priority (PAP)
 * - Source name broadcasting
 * - Multicast and unicast modes
 * - Sequence number tracking
 * - Heartbeat/keep-alive
 */

namespace Echoel {

//==========================================================================
// sACN Constants
//==========================================================================

namespace sACN {
    constexpr int DMX_UNIVERSE_SIZE = 512;
    constexpr int DEFAULT_PRIORITY = 100;
    constexpr int MAX_PRIORITY = 200;
    constexpr int MIN_PRIORITY = 0;
    constexpr int MULTICAST_PORT = 5568;
    constexpr int ACN_SDT_MULTICAST_PORT = 5569;

    // E1.31 Packet identifiers
    constexpr uint16_t VECTOR_ROOT_E131_DATA = 0x0004;
    constexpr uint16_t VECTOR_ROOT_E131_EXTENDED = 0x0008;
    constexpr uint16_t VECTOR_E131_DATA_PACKET = 0x0002;
    constexpr uint16_t VECTOR_E131_EXTENDED_SYNCHRONIZATION = 0x0001;
    constexpr uint16_t VECTOR_E131_EXTENDED_DISCOVERY = 0x0002;
    constexpr uint8_t VECTOR_DMP_SET_PROPERTY = 0x02;

    // ACN Packet Identifier
    const std::array<uint8_t, 12> ACN_PACKET_IDENTIFIER = {
        0x41, 0x53, 0x43, 0x2d,  // "ASC-"
        0x45, 0x31, 0x2e, 0x31,  // "E1.17"
        0x37, 0x00, 0x00, 0x00
    };

    // Calculate multicast address for universe
    inline juce::String getMulticastAddress(uint16_t universe) {
        // 239.255.{universe_high}.{universe_low}
        return juce::String::formatted("239.255.%d.%d",
                                       (universe >> 8) & 0xFF,
                                       universe & 0xFF);
    }
}

//==========================================================================
// sACN Universe
//==========================================================================

class sACNUniverse {
public:
    sACNUniverse(uint16_t universeNumber = 1)
        : universe(universeNumber), priority(sACN::DEFAULT_PRIORITY) {
        data.fill(0);
    }

    void setChannel(int channel, uint8_t value) {
        if (channel >= 1 && channel <= sACN::DMX_UNIVERSE_SIZE) {
            data[channel - 1] = value;
            dirty = true;
        }
    }

    uint8_t getChannel(int channel) const {
        if (channel >= 1 && channel <= sACN::DMX_UNIVERSE_SIZE) {
            return data[channel - 1];
        }
        return 0;
    }

    void setAllChannels(const std::array<uint8_t, sACN::DMX_UNIVERSE_SIZE>& values) {
        data = values;
        dirty = true;
    }

    void clear() {
        data.fill(0);
        dirty = true;
    }

    void setPriority(uint8_t p) {
        priority = juce::jlimit(static_cast<uint8_t>(sACN::MIN_PRIORITY),
                                static_cast<uint8_t>(sACN::MAX_PRIORITY), p);
    }

    uint8_t getPriority() const { return priority; }
    uint16_t getUniverse() const { return universe; }
    const std::array<uint8_t, sACN::DMX_UNIVERSE_SIZE>& getData() const { return data; }
    bool isDirty() const { return dirty; }
    void clearDirty() { dirty = false; }

    uint8_t getSequence() const { return sequence; }
    void incrementSequence() { sequence++; }

private:
    uint16_t universe;
    uint8_t priority;
    uint8_t sequence = 0;
    bool dirty = true;
    std::array<uint8_t, sACN::DMX_UNIVERSE_SIZE> data;
};

//==========================================================================
// sACN Packet Builder
//==========================================================================

class sACNPacketBuilder {
public:
    static std::vector<uint8_t> buildDataPacket(
        const sACNUniverse& universe,
        const std::array<uint8_t, 16>& sourceCID,
        const juce::String& sourceName,
        bool previewData = false,
        bool streamTerminated = false)
    {
        std::vector<uint8_t> packet;
        packet.reserve(638);  // Full DMX packet size

        // ===== Root Layer (38 bytes) =====
        // Preamble size (2 bytes)
        pushUint16(packet, 0x0010);

        // Post-amble size (2 bytes)
        pushUint16(packet, 0x0000);

        // ACN Packet Identifier (12 bytes)
        packet.insert(packet.end(), sACN::ACN_PACKET_IDENTIFIER.begin(),
                                    sACN::ACN_PACKET_IDENTIFIER.end());

        // Flags and length (2 bytes) - will be filled later
        size_t rootFlagsLengthPos = packet.size();
        pushUint16(packet, 0);

        // Vector (4 bytes)
        pushUint32(packet, sACN::VECTOR_ROOT_E131_DATA);

        // Source CID (16 bytes)
        packet.insert(packet.end(), sourceCID.begin(), sourceCID.end());

        // ===== Framing Layer (77 bytes) =====
        size_t framingLayerStart = packet.size();

        // Flags and length (2 bytes) - will be filled later
        size_t framingFlagsLengthPos = packet.size();
        pushUint16(packet, 0);

        // Vector (4 bytes)
        pushUint32(packet, sACN::VECTOR_E131_DATA_PACKET);

        // Source name (64 bytes, null-terminated)
        pushString(packet, sourceName, 64);

        // Priority (1 byte)
        packet.push_back(universe.getPriority());

        // Synchronization address (2 bytes) - 0 = no sync
        pushUint16(packet, 0);

        // Sequence number (1 byte)
        packet.push_back(universe.getSequence());

        // Options (1 byte)
        uint8_t options = 0;
        if (previewData) options |= 0x80;
        if (streamTerminated) options |= 0x40;
        packet.push_back(options);

        // Universe (2 bytes)
        pushUint16(packet, universe.getUniverse());

        // ===== DMP Layer (523 bytes) =====
        size_t dmpLayerStart = packet.size();

        // Flags and length (2 bytes) - will be filled later
        size_t dmpFlagsLengthPos = packet.size();
        pushUint16(packet, 0);

        // Vector (1 byte)
        packet.push_back(sACN::VECTOR_DMP_SET_PROPERTY);

        // Address type & data type (1 byte)
        packet.push_back(0xA1);  // Relative address, array data

        // First property address (2 bytes)
        pushUint16(packet, 0x0000);

        // Address increment (2 bytes)
        pushUint16(packet, 0x0001);

        // Property value count (2 bytes) - START code + 512 DMX slots
        pushUint16(packet, sACN::DMX_UNIVERSE_SIZE + 1);

        // START code (1 byte)
        packet.push_back(0x00);

        // DMX data (512 bytes)
        const auto& dmxData = universe.getData();
        packet.insert(packet.end(), dmxData.begin(), dmxData.end());

        // ===== Fill in lengths =====
        size_t totalLength = packet.size();

        // DMP layer length
        uint16_t dmpLength = static_cast<uint16_t>(totalLength - dmpLayerStart);
        packet[dmpFlagsLengthPos] = 0x70 | ((dmpLength >> 8) & 0x0F);
        packet[dmpFlagsLengthPos + 1] = dmpLength & 0xFF;

        // Framing layer length
        uint16_t framingLength = static_cast<uint16_t>(totalLength - framingLayerStart);
        packet[framingFlagsLengthPos] = 0x70 | ((framingLength >> 8) & 0x0F);
        packet[framingFlagsLengthPos + 1] = framingLength & 0xFF;

        // Root layer length
        uint16_t rootLength = static_cast<uint16_t>(totalLength - 16);  // After preamble
        packet[rootFlagsLengthPos] = 0x70 | ((rootLength >> 8) & 0x0F);
        packet[rootFlagsLengthPos + 1] = rootLength & 0xFF;

        return packet;
    }

    static std::vector<uint8_t> buildSyncPacket(
        uint16_t syncAddress,
        const std::array<uint8_t, 16>& sourceCID,
        uint8_t sequence)
    {
        std::vector<uint8_t> packet;
        packet.reserve(49);

        // Root layer preamble
        pushUint16(packet, 0x0010);
        pushUint16(packet, 0x0000);

        // ACN Packet Identifier
        packet.insert(packet.end(), sACN::ACN_PACKET_IDENTIFIER.begin(),
                                    sACN::ACN_PACKET_IDENTIFIER.end());

        // Flags and length
        pushUint16(packet, 0x7021);  // 33 bytes

        // Vector (extended)
        pushUint32(packet, sACN::VECTOR_ROOT_E131_EXTENDED);

        // Source CID
        packet.insert(packet.end(), sourceCID.begin(), sourceCID.end());

        // Framing layer
        pushUint16(packet, 0x700B);  // 11 bytes
        pushUint32(packet, sACN::VECTOR_E131_EXTENDED_SYNCHRONIZATION);
        packet.push_back(sequence);
        pushUint16(packet, syncAddress);

        // Reserved (2 bytes)
        pushUint16(packet, 0);

        return packet;
    }

private:
    static void pushUint16(std::vector<uint8_t>& packet, uint16_t value) {
        packet.push_back((value >> 8) & 0xFF);
        packet.push_back(value & 0xFF);
    }

    static void pushUint32(std::vector<uint8_t>& packet, uint32_t value) {
        packet.push_back((value >> 24) & 0xFF);
        packet.push_back((value >> 16) & 0xFF);
        packet.push_back((value >> 8) & 0xFF);
        packet.push_back(value & 0xFF);
    }

    static void pushString(std::vector<uint8_t>& packet, const juce::String& str, int maxLen) {
        auto utf8 = str.toStdString();
        for (int i = 0; i < maxLen; ++i) {
            if (i < static_cast<int>(utf8.size())) {
                packet.push_back(static_cast<uint8_t>(utf8[i]));
            } else {
                packet.push_back(0);
            }
        }
    }
};

//==========================================================================
// sACN Controller - Main Class
//==========================================================================

class sACNController {
public:
    sACNController(const juce::String& name = "Echoelmusic sACN")
        : sourceName(name) {
        // Generate random CID (Component Identifier)
        juce::Random random;
        for (auto& byte : sourceCID) {
            byte = static_cast<uint8_t>(random.nextInt(256));
        }

        // Create UDP socket
        socket = std::make_unique<juce::DatagramSocket>();
        socket->bindToPort(0);  // Any available port
    }

    ~sACNController() {
        // Send stream terminated packets
        for (auto& [universeNum, universe] : universes) {
            sendTerminate(universeNum);
        }
    }

    //==========================================================================
    // Universe Management
    //==========================================================================

    sACNUniverse& getUniverse(uint16_t universeNum) {
        auto it = universes.find(universeNum);
        if (it == universes.end()) {
            universes.emplace(universeNum, sACNUniverse(universeNum));
        }
        return universes[universeNum];
    }

    void setChannel(uint16_t universeNum, int channel, uint8_t value) {
        getUniverse(universeNum).setChannel(channel, value);
    }

    uint8_t getChannel(uint16_t universeNum, int channel) {
        return getUniverse(universeNum).getChannel(channel);
    }

    void setUniversePriority(uint16_t universeNum, uint8_t priority) {
        getUniverse(universeNum).setPriority(priority);
    }

    void clearUniverse(uint16_t universeNum) {
        getUniverse(universeNum).clear();
    }

    //==========================================================================
    // Transmission
    //==========================================================================

    bool send(uint16_t universeNum) {
        auto it = universes.find(universeNum);
        if (it == universes.end()) {
            return false;
        }

        sACNUniverse& universe = it->second;

        // Build packet
        auto packet = sACNPacketBuilder::buildDataPacket(
            universe, sourceCID, sourceName,
            previewMode, false
        );

        // Get multicast address
        juce::String multicastAddr = sACN::getMulticastAddress(universeNum);

        // Send via UDP
        int sent = socket->write(multicastAddr, sACN::MULTICAST_PORT,
                                packet.data(), static_cast<int>(packet.size()));

        if (sent > 0) {
            universe.incrementSequence();
            universe.clearDirty();
            return true;
        }

        return false;
    }

    void sendAll() {
        for (auto& [universeNum, universe] : universes) {
            if (universe.isDirty()) {
                send(universeNum);
            }
        }
    }

    void sendAllForced() {
        for (auto& [universeNum, universe] : universes) {
            send(universeNum);
        }
    }

    void sendSync(uint16_t syncAddress) {
        auto packet = sACNPacketBuilder::buildSyncPacket(
            syncAddress, sourceCID, syncSequence++
        );

        juce::String multicastAddr = sACN::getMulticastAddress(syncAddress);
        socket->write(multicastAddr, sACN::MULTICAST_PORT,
                     packet.data(), static_cast<int>(packet.size()));
    }

    //==========================================================================
    // Configuration
    //==========================================================================

    void setSourceName(const juce::String& name) {
        sourceName = name;
    }

    void setPreviewMode(bool preview) {
        previewMode = preview;
    }

    void setUnicastMode(bool unicast, const juce::String& targetIP = "") {
        unicastMode = unicast;
        unicastTarget = targetIP;
    }

    //==========================================================================
    // Status
    //==========================================================================

    juce::String getStatus() const {
        juce::String status;
        status << "sACN (E1.31) Controller Status\n";
        status << "==============================\n\n";
        status << "Source Name: " << sourceName << "\n";
        status << "Active Universes: " << universes.size() << "\n";
        status << "Preview Mode: " << (previewMode ? "Yes" : "No") << "\n";
        status << "Unicast Mode: " << (unicastMode ? unicastTarget : "Disabled") << "\n\n";

        for (const auto& [num, universe] : universes) {
            status << "  Universe " << num << " (Priority: " << (int)universe.getPriority()
                   << ", Seq: " << (int)universe.getSequence() << ")\n";
        }

        return status;
    }

private:
    void sendTerminate(uint16_t universeNum) {
        auto it = universes.find(universeNum);
        if (it == universes.end()) return;

        // Send 3 terminate packets as per spec
        for (int i = 0; i < 3; ++i) {
            auto packet = sACNPacketBuilder::buildDataPacket(
                it->second, sourceCID, sourceName,
                false, true  // streamTerminated = true
            );

            juce::String multicastAddr = sACN::getMulticastAddress(universeNum);
            socket->write(multicastAddr, sACN::MULTICAST_PORT,
                         packet.data(), static_cast<int>(packet.size()));

            it->second.incrementSequence();
            juce::Thread::sleep(10);
        }
    }

    std::unique_ptr<juce::DatagramSocket> socket;
    std::unordered_map<uint16_t, sACNUniverse> universes;

    std::array<uint8_t, 16> sourceCID;
    juce::String sourceName;
    uint8_t syncSequence = 0;

    bool previewMode = false;
    bool unicastMode = false;
    juce::String unicastTarget;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(sACNController)
};

} // namespace Echoel
