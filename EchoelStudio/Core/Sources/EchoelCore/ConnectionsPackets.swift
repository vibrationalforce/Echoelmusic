import Foundation

/// The wire formats the Connections module (wave W4) speaks, each as a pure function from
/// values to bytes: OSC 1.0, Art-Net's ArtDMX and sACN's E1.31 data packet. Ported from the
/// earlier app's proven senders (`Sync/OSCSender`, `Sync/ArtNetSender`, `Sync/SACNSender`),
/// stripped of their sockets: nothing here knows a host, and `ConnectionsPacketTests` pins every
/// byte against vectors written from the standards, not from this code (G-B contract).
///
/// Every builder takes what it is given and answers with a well-formed packet: an odd channel
/// count is padded, too many channels are cut at 512, a short CID is padded, a long one cut.
/// The caller decides what to send; these decide only how it is spelled.
public enum OSCPacket {
    /// One OSC 1.0 message carrying floats: the address, null-terminated and padded to a
    /// multiple of four bytes; the type tag string (`,` then one `f` per value), padded the same
    /// way; then each value as a big-endian IEEE 754 single. An address that already fills a
    /// multiple of four still gets its terminator plus a full pad — the spec's rule, and the one
    /// receivers trip on when a sender saves the four bytes.
    public static func message(address: String, floats: [Float]) -> Data {
        var data = Data()
        data.append(paddedString(address))
        data.append(paddedString("," + String(repeating: "f", count: floats.count)))
        for value in floats {
            var bits = value.bitPattern.bigEndian
            withUnsafeBytes(of: &bits) { data.append(contentsOf: $0) }
        }
        return data
    }

    /// The string's UTF-8, a null terminator, then zeros up to the next multiple of four.
    static func paddedString(_ string: String) -> Data {
        var bytes = Array(string.utf8)
        bytes.append(0)
        while bytes.count % 4 != 0 { bytes.append(0) }
        return Data(bytes)
    }
}

/// Art-Net 4's ArtDMX packet (OpOutput): one DMX universe over UDP, by the standard on port 6454.
public enum ArtDMXPacket {
    /// The port the standard fixes; a node listens there and nowhere else.
    public static let standardPort: UInt16 = 6454
    /// The 15-bit port address: Net (7 bits) above SubUni (8 bits).
    public static let universeRange: ClosedRange<Int> = 0...32767
    public static let headerLength = 18

    /// `channels` is the DMX data from slot 1; the standard wants an even length between 2 and
    /// 512, so it is padded or cut to that. `sequence` is 1 … 255 (0 tells the node the sender
    /// does not sequence); `nextSequence` keeps it in that range.
    public static func packet(universe: Int, sequence: UInt8, channels: [UInt8]) -> Data {
        var dmx = Array(channels.prefix(512))
        if dmx.count < 2 { dmx.append(contentsOf: [UInt8](repeating: 0, count: 2 - dmx.count)) }
        if dmx.count % 2 != 0 { dmx.append(0) }
        let length = dmx.count
        let address = Swift.min(Swift.max(universe, universeRange.lowerBound), universeRange.upperBound)

        var data = Data()
        data.append(contentsOf: Array("Art-Net".utf8))        // ID, 7 bytes …
        data.append(0)                                         // … null-terminated to 8
        data.append(contentsOf: [0x00, 0x50])                  // OpCode OpOutput 0x5000, little-endian
        data.append(contentsOf: [0x00, 0x0E])                  // ProtVer 14, big-endian
        data.append(sequence)
        data.append(0x00)                                      // Physical input port: none
        data.append(UInt8(address & 0xFF))                     // SubUni
        data.append(UInt8((address >> 8) & 0x7F))              // Net
        data.append(UInt8((length >> 8) & 0xFF))               // Length, big-endian
        data.append(UInt8(length & 0xFF))
        data.append(contentsOf: dmx)
        return data
    }

    /// The sequence number after `sequence`: 1 … 255, never 0.
    public static func nextSequence(_ sequence: UInt8) -> UInt8 {
        sequence >= 255 ? 1 : sequence + 1
    }
}

/// ANSI E1.31 (sACN): one DMX universe as an ACN data packet — root, framing and DMP layer —
/// over UDP, by the standard on port 5568. Always the full 512 slots, so a receiver never has
/// to merge partial universes.
public enum E131Packet {
    public static let standardPort: UInt16 = 5568
    public static let universeRange: ClosedRange<Int> = 1...63999
    /// The framing layer's Options bit 6: the source is leaving this universe. A receiver that
    /// hears it drops the source at once instead of waiting out its own timeout.
    public static let streamTerminatedOption: UInt8 = 0x40
    public static let defaultPriority: UInt8 = 100
    /// The name a console shows in its source list; 64 bytes in every packet.
    public static let sourceName = "Echoel Studio"
    public static let length = 638
    /// Where the first DMX slot sits in the packet, after the start code.
    public static let firstSlotOffset = 126

    /// `cid` is the sender's component identifier, 16 bytes, the same for the sender's life.
    /// `channels` is padded with zeros to 512 slots or cut there.
    public static func packet(universe: Int, sequence: UInt8, cid: [UInt8], channels: [UInt8],
                              priority: UInt8 = defaultPriority, options: UInt8 = 0) -> Data {
        let slotCount = 512
        var slots = Array(channels.prefix(slotCount))
        if slots.count < slotCount { slots.append(contentsOf: [UInt8](repeating: 0, count: slotCount - slots.count)) }
        var identifier = Array(cid.prefix(16))
        if identifier.count < 16 { identifier.append(contentsOf: [UInt8](repeating: 0, count: 16 - identifier.count)) }
        let address = Swift.min(Swift.max(universe, universeRange.lowerBound), universeRange.upperBound)
        var name = Array(sourceName.utf8.prefix(63))
        name.append(contentsOf: [UInt8](repeating: 0, count: 64 - name.count))

        // A PDU's flags-and-length field: 0x7 in the high nibble, the length from that field
        // to the end of the packet in the low twelve bits.
        func flagsAndLength(fromOffset offset: Int) -> [UInt8] {
            let value = 0x7000 | ((length - offset) & 0x0FFF)
            return [UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
        }

        var data = Data()
        // Root layer, 38 bytes.
        data.append(contentsOf: [0x00, 0x10])                  // Preamble size
        data.append(contentsOf: [0x00, 0x00])                  // Post-amble size
        data.append(contentsOf: [0x41, 0x53, 0x43, 0x2D, 0x45, 0x31, 0x2E, 0x31, 0x37, 0x00, 0x00, 0x00]) // "ASC-E1.17"
        data.append(contentsOf: flagsAndLength(fromOffset: 16))
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x04])      // VECTOR_ROOT_E131_DATA
        data.append(contentsOf: identifier)
        // Framing layer, 77 bytes.
        data.append(contentsOf: flagsAndLength(fromOffset: 38))
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x02])      // VECTOR_E131_DATA_PACKET
        data.append(contentsOf: name)
        data.append(priority)
        data.append(contentsOf: [0x00, 0x00])                  // Synchronization address: none
        data.append(sequence)
        data.append(options)
        data.append(contentsOf: [UInt8((address >> 8) & 0xFF), UInt8(address & 0xFF)])
        // DMP layer, 11 + 512 bytes.
        data.append(contentsOf: flagsAndLength(fromOffset: 115))
        data.append(0x02)                                      // VECTOR_DMP_SET_PROPERTY
        data.append(0xA1)                                      // Address and data type
        data.append(contentsOf: [0x00, 0x00])                  // First property address
        data.append(contentsOf: [0x00, 0x01])                  // Address increment
        data.append(contentsOf: [0x02, 0x01])                  // Property value count: 513
        data.append(0x00)                                      // DMX start code
        data.append(contentsOf: slots)
        return data
    }

    /// The multicast group the standard assigns a universe, for a receiver that joins it. Echoel
    /// sends unicast, so this names what an operator would type, not what the module does.
    public static func multicastHost(universe: Int) -> String {
        let address = Swift.min(Swift.max(universe, universeRange.lowerBound), universeRange.upperBound)
        return "239.255.\((address >> 8) & 0xFF).\(address & 0xFF)"
    }

    /// Sequence numbers wrap through 0 here (the standard's are plain 8-bit).
    public static func nextSequence(_ sequence: UInt8) -> UInt8 {
        sequence &+ 1
    }
}
