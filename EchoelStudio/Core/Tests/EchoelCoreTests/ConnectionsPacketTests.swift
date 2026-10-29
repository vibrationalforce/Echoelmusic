import XCTest
@testable import EchoelCore

/// Golden vectors for the three wire formats, written from the standards (OSC 1.0, Art-Net 4,
/// ANSI E1.31-2018) and not from the code under test. Where a packet has structure, an
/// independent reader written here from the same standard decodes it back (G-B contract).
final class ConnectionsPacketTests: XCTestCase {
    // MARK: - OSC 1.0

    func testAnOSCMessageWithOneFloatMatchesTheSpecification() {
        let data = OSCPacket.message(address: "/foo", floats: [1.0])
        XCTAssertEqual(Array(data), [
            0x2F, 0x66, 0x6F, 0x6F, 0x00, 0x00, 0x00, 0x00,   // "/foo" + null + pad to 8
            0x2C, 0x66, 0x00, 0x00,                           // ",f" + null + pad
            0x3F, 0x80, 0x00, 0x00,                           // 1.0 big-endian
        ])
    }

    func testAnAlignedAddressStillGetsItsTerminatorAndAFullPad() {
        let data = OSCPacket.message(address: "/abcd", floats: [])
        XCTAssertEqual(Array(data), [
            0x2F, 0x61, 0x62, 0x63, 0x64, 0x00, 0x00, 0x00,
            0x2C, 0x00, 0x00, 0x00,
        ])
    }

    func testTheTypeTagGrowsWithTheFloatsAndEachIsBigEndian() {
        let data = OSCPacket.message(address: "/m", floats: [0.0, 0.5, 1.0])
        XCTAssertEqual(Array(data), [
            0x2F, 0x6D, 0x00, 0x00,
            0x2C, 0x66, 0x66, 0x66, 0x00, 0x00, 0x00, 0x00,   // ",fff" + null + 3 pad
            0x00, 0x00, 0x00, 0x00,
            0x3F, 0x00, 0x00, 0x00,
            0x3F, 0x80, 0x00, 0x00,
        ])
    }

    func testAMessageWithoutArgumentsHasABareCommaTag() {
        XCTAssertEqual(Array(OSCPacket.message(address: "/x", floats: [])), [0x2F, 0x78, 0x00, 0x00, 0x2C, 0x00, 0x00, 0x00])
    }

    func testAnADMPositionMessageIsThirtySixBytesWithASignedAzimuth() {
        let data = OSCPacket.message(address: "/adm/obj/1/aed", floats: [-90, 0, 1])
        XCTAssertEqual(data.count, 16 + 8 + 12)
        XCTAssertEqual(Array(data[0..<16]), Array("/adm/obj/1/aed".utf8) + [0, 0])
        XCTAssertEqual(Array(data[16..<24]), [0x2C, 0x66, 0x66, 0x66, 0x00, 0x00, 0x00, 0x00])
        XCTAssertEqual(Array(data[24..<28]), [0xC2, 0xB4, 0x00, 0x00], "-90 as IEEE 754 single, big-endian")
        XCTAssertEqual(Array(data[28..<36]), [0x00, 0x00, 0x00, 0x00, 0x3F, 0x80, 0x00, 0x00])
    }

    /// An independent reader of OSC 1.0 (address, type tags, floats) gets back what went in, for
    /// addresses of every alignment and argument counts 0 … 5.
    func testAnIndependentDecoderReadsBackEveryShape() throws {
        let addresses = ["/a", "/ab", "/abc", "/abcd", "/echoelmusic/bio/heart/bpm", "/adm/obj/12/gain"]
        let values: [Float] = [0, 1, -1, 0.5, 72.5, -180, 3.4028235e38]
        for address in addresses {
            for count in 0...5 {
                let floats = Array(values.prefix(count))
                let data = OSCPacket.message(address: address, floats: floats)
                XCTAssertEqual(data.count % 4, 0, "\(address) \(count): every OSC message is a multiple of four bytes")
                let decoded = try Self.decode(Array(data))
                XCTAssertEqual(decoded.address, address)
                XCTAssertEqual(decoded.floats, floats)
            }
        }
    }

    // MARK: - Art-Net ArtDMX

    func testTheArtDMXHeaderMatchesTheSpecification() {
        let packet = Array(ArtDMXPacket.packet(universe: 0, sequence: 1, channels: [0, 0]))
        XCTAssertEqual(Array(packet[0..<8]), [0x41, 0x72, 0x74, 0x2D, 0x4E, 0x65, 0x74, 0x00], "\"Art-Net\" null-terminated")
        XCTAssertEqual(Array(packet[8..<10]), [0x00, 0x50], "OpOutput 0x5000 little-endian")
        XCTAssertEqual(Array(packet[10..<12]), [0x00, 0x0E], "protocol version 14 big-endian")
        XCTAssertEqual(packet[12], 1, "sequence")
        XCTAssertEqual(packet[13], 0, "physical")
        XCTAssertEqual(packet.count, ArtDMXPacket.headerLength + 2)
    }

    func testAWholeSmallArtDMXPacketByteForByte() {
        let packet = Array(ArtDMXPacket.packet(universe: 0, sequence: 1, channels: [0xFF, 0x80]))
        XCTAssertEqual(packet, [0x41, 0x72, 0x74, 0x2D, 0x4E, 0x65, 0x74, 0x00,
                                0x00, 0x50, 0x00, 0x0E, 0x01, 0x00, 0x00, 0x00, 0x00, 0x02,
                                0xFF, 0x80])
    }

    func testTheUniverseSplitsIntoSubUniAndNet() {
        let packet = Array(ArtDMXPacket.packet(universe: 0x0123, sequence: 5, channels: [1, 2]))
        XCTAssertEqual(packet[14], 0x23, "SubUni: the low byte")
        XCTAssertEqual(packet[15], 0x01, "Net: the high seven bits")
        let top = Array(ArtDMXPacket.packet(universe: 40_000, sequence: 5, channels: [1, 2]))
        XCTAssertEqual(Array(top[14..<16]), [0xFF, 0x7F], "held to the 15-bit port address")
        let below = Array(ArtDMXPacket.packet(universe: -3, sequence: 5, channels: [1, 2]))
        XCTAssertEqual(Array(below[14..<16]), [0x00, 0x00])
    }

    func testTheDMXLengthIsEvenBigEndianAndTheDataFollows() {
        let packet = Array(ArtDMXPacket.packet(universe: 0, sequence: 1, channels: [10, 20, 30]))
        let length = Int(packet[16]) << 8 | Int(packet[17])
        XCTAssertEqual(length, 4, "three channels are padded to an even four")
        XCTAssertEqual(Array(packet[18..<22]), [10, 20, 30, 0])
        XCTAssertEqual(packet.count, 18 + length)
        let empty = Array(ArtDMXPacket.packet(universe: 0, sequence: 1, channels: []))
        XCTAssertEqual(Array(empty[16..<20]), [0x00, 0x02, 0x00, 0x00], "at least two slots")
    }

    func testMoreThan512ChannelsAreCutAtTheUniverse() {
        let packet = Array(ArtDMXPacket.packet(universe: 0, sequence: 1, channels: [UInt8](repeating: 255, count: 600)))
        XCTAssertEqual(Int(packet[16]) << 8 | Int(packet[17]), 512)
        XCTAssertEqual(packet.count, 18 + 512)
    }

    func testTheArtNetSequenceRunsOneToTwoHundredFiftyFive() {
        XCTAssertEqual(ArtDMXPacket.nextSequence(0), 1)
        XCTAssertEqual(ArtDMXPacket.nextSequence(7), 8)
        XCTAssertEqual(ArtDMXPacket.nextSequence(254), 255)
        XCTAssertEqual(ArtDMXPacket.nextSequence(255), 1, "0 would tell the node we do not sequence")
        XCTAssertEqual(ArtDMXPacket.standardPort, 6454)
    }

    // MARK: - sACN E1.31

    private let cid: [UInt8] = Array(0..<16)

    func testAnE131PacketIsAlwaysOneFullUniverse() {
        XCTAssertEqual(E131Packet.packet(universe: 1, sequence: 0, cid: cid, channels: [1, 2, 3]).count, 638)
        XCTAssertEqual(E131Packet.packet(universe: 1, sequence: 0, cid: cid, channels: [UInt8](repeating: 200, count: 600)).count, 638)
        XCTAssertEqual(E131Packet.length, 638)
    }

    func testTheRootLayerIdentifiesACNAndTheSender() {
        let packet = Array(E131Packet.packet(universe: 1, sequence: 0, cid: cid, channels: []))
        XCTAssertEqual(Array(packet[0..<4]), [0x00, 0x10, 0x00, 0x00], "preamble 16, post-amble 0")
        XCTAssertEqual(Array(packet[4..<16]), [0x41, 0x53, 0x43, 0x2D, 0x45, 0x31, 0x2E, 0x31, 0x37, 0x00, 0x00, 0x00], "\"ASC-E1.17\"")
        XCTAssertEqual(Array(packet[16..<18]), [0x72, 0x6E], "flags 0x7, length 622 = 638 - 16")
        XCTAssertEqual(Array(packet[18..<22]), [0x00, 0x00, 0x00, 0x04], "VECTOR_ROOT_E131_DATA")
        XCTAssertEqual(Array(packet[22..<38]), cid)
    }

    func testTheFramingLayerCarriesNamePrioritySequenceOptionsAndUniverse() {
        let packet = Array(E131Packet.packet(universe: 0x0102, sequence: 7, cid: cid, channels: [], options: 0x40))
        XCTAssertEqual(Array(packet[38..<40]), [0x72, 0x58], "flags 0x7, length 600 = 638 - 38")
        XCTAssertEqual(Array(packet[40..<44]), [0x00, 0x00, 0x00, 0x02], "VECTOR_E131_DATA_PACKET")
        let name = Array("Echoel Studio".utf8)
        XCTAssertEqual(Array(packet[44..<(44 + name.count)]), name)
        XCTAssertEqual(Array(packet[(44 + name.count)..<108]), [UInt8](repeating: 0, count: 64 - name.count), "64 bytes, zero-filled")
        XCTAssertEqual(packet[108], 100, "priority")
        XCTAssertEqual(Array(packet[109..<111]), [0x00, 0x00], "no synchronization address")
        XCTAssertEqual(packet[111], 7, "sequence")
        XCTAssertEqual(packet[112], E131Packet.streamTerminatedOption, "options")
        XCTAssertEqual(Array(packet[113..<115]), [0x01, 0x02], "universe big-endian")
        let plain = Array(E131Packet.packet(universe: 1, sequence: 0, cid: cid, channels: []))
        XCTAssertEqual(plain[112], 0, "a data packet carries no options")
    }

    func testTheDMPLayerSetsFivehundredThirteenPropertiesFromAZeroStartCode() {
        let packet = Array(E131Packet.packet(universe: 1, sequence: 0, cid: cid, channels: [9, 8, 7]))
        XCTAssertEqual(Array(packet[115..<117]), [0x72, 0x0B], "flags 0x7, length 523 = 638 - 115")
        XCTAssertEqual(packet[117], 0x02, "VECTOR_DMP_SET_PROPERTY")
        XCTAssertEqual(packet[118], 0xA1, "address type and data type")
        XCTAssertEqual(Array(packet[119..<121]), [0x00, 0x00], "first property address")
        XCTAssertEqual(Array(packet[121..<123]), [0x00, 0x01], "address increment")
        XCTAssertEqual(Array(packet[123..<125]), [0x02, 0x01], "513 property values")
        XCTAssertEqual(packet[125], 0x00, "DMX start code")
        XCTAssertEqual(Array(packet[126..<129]), [9, 8, 7])
        XCTAssertEqual(Array(packet[129..<638]), [UInt8](repeating: 0, count: 509), "the rest of the universe is zero")
        XCTAssertEqual(E131Packet.firstSlotOffset, 126)
    }

    func testAShortOrLongCIDIsMadeSixteenBytes() {
        let short = Array(E131Packet.packet(universe: 1, sequence: 0, cid: [1, 2, 3], channels: []))
        XCTAssertEqual(Array(short[22..<38]), [1, 2, 3] + [UInt8](repeating: 0, count: 13))
        let long = Array(E131Packet.packet(universe: 1, sequence: 0, cid: Array(1...20), channels: []))
        XCTAssertEqual(Array(long[22..<38]), Array(1...16))
    }

    func testTheUniverseIsHeldToTheStandardsRange() {
        let low = Array(E131Packet.packet(universe: 0, sequence: 0, cid: cid, channels: []))
        XCTAssertEqual(Array(low[113..<115]), [0x00, 0x01])
        let high = Array(E131Packet.packet(universe: 70_000, sequence: 0, cid: cid, channels: []))
        XCTAssertEqual(Array(high[113..<115]), [0xF9, 0xFF], "63999")
        XCTAssertEqual(E131Packet.multicastHost(universe: 1), "239.255.0.1")
        XCTAssertEqual(E131Packet.multicastHost(universe: 258), "239.255.1.2")
        XCTAssertEqual(E131Packet.standardPort, 5568)
        XCTAssertEqual(E131Packet.nextSequence(255), 0)
    }

    // MARK: - An OSC 1.0 reader, from the specification

    struct Decoded: Equatable {
        var address: String
        var floats: [Float]
    }

    enum DecodeFailure: Error { case malformed }

    /// Reads one message: a padded string, a padded type tag string starting with ",", then one
    /// big-endian 32-bit float per "f". Anything else is malformed.
    static func decode(_ bytes: [UInt8]) throws -> Decoded {
        var cursor = 0
        func string() throws -> String {
            guard let end = bytes[cursor...].firstIndex(of: 0) else { throw DecodeFailure.malformed }
            let text = String(decoding: bytes[cursor..<end], as: UTF8.self)
            cursor = end + 1
            while cursor % 4 != 0 {
                guard cursor < bytes.count, bytes[cursor] == 0 else { throw DecodeFailure.malformed }
                cursor += 1
            }
            return text
        }
        let address = try string()
        let tags = try string()
        guard tags.first == "," else { throw DecodeFailure.malformed }
        var floats: [Float] = []
        for tag in tags.dropFirst() {
            guard tag == "f", cursor + 4 <= bytes.count else { throw DecodeFailure.malformed }
            let bits = UInt32(bytes[cursor]) << 24 | UInt32(bytes[cursor + 1]) << 16 | UInt32(bytes[cursor + 2]) << 8 | UInt32(bytes[cursor + 3])
            floats.append(Float(bitPattern: bits))
            cursor += 4
        }
        guard cursor == bytes.count else { throw DecodeFailure.malformed }
        return Decoded(address: address, floats: floats)
    }
}
