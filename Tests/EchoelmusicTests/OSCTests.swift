#if canImport(Network)
// OSCTests.swift
// Echoelmusic — OSC Message Encoding/Decoding Tests
//
// Tests for OSCMessage, OSCValue, and string encoding.
// Pure computation tests — no network required.

import XCTest
@testable import Echoelmusic

// MARK: - OSC Value Type Tag Tests

final class OSCValueTests: XCTestCase {

    func testTypeTag_int32() {
        let value = OSCValue.int(42)
        XCTAssertEqual(value.typeTag, Character("i"))
    }

    func testTypeTag_float32() {
        let value = OSCValue.float(3.14)
        XCTAssertEqual(value.typeTag, Character("f"))
    }

    func testTypeTag_string() {
        let value = OSCValue.string("hello")
        XCTAssertEqual(value.typeTag, Character("s"))
    }

    func testTypeTag_blob() {
        let value = OSCValue.blob(Data([0x01, 0x02]))
        XCTAssertEqual(value.typeTag, Character("b"))
    }

    func testTypeTag_int64() {
        let value = OSCValue.int64(1_000_000)
        XCTAssertEqual(value.typeTag, Character("h"))
    }

    func testTypeTag_double() {
        let value = OSCValue.double(2.718281828)
        XCTAssertEqual(value.typeTag, Character("d"))
    }

    func testTypeTag_boolTrue() {
        let value = OSCValue.bool(true)
        XCTAssertEqual(value.typeTag, Character("T"))
    }

    func testTypeTag_boolFalse() {
        let value = OSCValue.bool(false)
        XCTAssertEqual(value.typeTag, Character("F"))
    }

    func testTypeTag_nil() {
        let value = OSCValue.nil_
        XCTAssertEqual(value.typeTag, Character("N"))
    }
}

// MARK: - OSC String Encoding Tests

final class OSCStringEncodingTests: XCTestCase {

    func testEncodeString_emptyString() {
        let data = OSCMessage.encodeString("")
        // Empty string: null terminator + 3 padding = 4 bytes
        XCTAssertEqual(data.count, 4)
        XCTAssertEqual(data[0], 0) // null terminator
    }

    func testEncodeString_shortString() {
        let data = OSCMessage.encodeString("hi")
        // "hi" = 2 chars + null = 3 bytes, padded to 4
        XCTAssertEqual(data.count, 4)
        XCTAssertEqual(data[0], UInt8(ascii: "h"))
        XCTAssertEqual(data[1], UInt8(ascii: "i"))
        XCTAssertEqual(data[2], 0) // null terminator
    }

    func testEncodeString_4ByteAligned() {
        // "abc" = 3 chars + null = 4 bytes — no padding needed
        let data = OSCMessage.encodeString("abc")
        XCTAssertEqual(data.count, 4)
        XCTAssertEqual(data[3], 0) // null terminator at byte 4
    }

    func testEncodeString_requiresPadding() {
        // "abcd" = 4 chars + null = 5 bytes, padded to 8
        let data = OSCMessage.encodeString("abcd")
        XCTAssertEqual(data.count, 8)
        XCTAssertEqual(data.count % 4, 0, "Must be 4-byte aligned")
    }

    func testEncodeString_oscAddress() {
        let data = OSCMessage.encodeString("/echoelmusic/bio/heart/bpm")
        XCTAssertEqual(data.count % 4, 0, "Address must be 4-byte aligned")
        // Verify starts with correct bytes
        XCTAssertEqual(data[0], UInt8(ascii: "/"))
    }

    func testDecodeString_roundTrip() {
        let original = "/echoelmusic/bio/coherence"
        let encoded = OSCMessage.encodeString(original)
        var offset = 0
        let decoded = OSCMessage.decodeString(from: encoded, offset: &offset)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(offset, encoded.count)
    }

    func testDecodeString_emptyData() {
        var offset = 0
        let result = OSCMessage.decodeString(from: Data(), offset: &offset)
        XCTAssertNil(result)
    }

    func testDecodeString_noNullTerminator() {
        var offset = 0
        let data = Data([0x41, 0x42, 0x43]) // "ABC" without null
        let result = OSCMessage.decodeString(from: data, offset: &offset)
        XCTAssertNil(result)
    }
}

// MARK: - OSC Message Encode/Decode Tests

final class OSCMessageTests: XCTestCase {

    func testInit_defaultArguments() {
        let msg = OSCMessage(address: "/test")
        XCTAssertEqual(msg.address, "/test")
        XCTAssertTrue(msg.arguments.isEmpty)
    }

    func testInit_withArguments() {
        let msg = OSCMessage(address: "/test", arguments: [.int(42), .float(1.5)])
        XCTAssertEqual(msg.address, "/test")
        XCTAssertEqual(msg.arguments.count, 2)
    }

    func testEncode_singleFloat() {
        let msg = OSCMessage(address: "/test", arguments: [.float(1.0)])
        let data = msg.encode()
        XCTAssertGreaterThan(data.count, 0)
        XCTAssertEqual(data.count % 4, 0, "OSC message must be 4-byte aligned")
    }

    func testEncode_singleInt() {
        let msg = OSCMessage(address: "/test", arguments: [.int(42)])
        let data = msg.encode()
        XCTAssertGreaterThan(data.count, 0)
        XCTAssertEqual(data.count % 4, 0)
    }

    func testRoundTrip_noArguments() {
        let original = OSCMessage(address: "/echoelmusic/ping")
        let data = original.encode()
        let decoded = OSCMessage.decode(from: data)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.address, "/echoelmusic/ping")
        XCTAssertEqual(decoded?.arguments.count, 0)
    }

    func testRoundTrip_singleFloat() {
        let original = OSCMessage(address: "/bio/heart/bpm", arguments: [.float(72.5)])
        let data = original.encode()
        let decoded = OSCMessage.decode(from: data)

        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.address, "/bio/heart/bpm")
        XCTAssertEqual(decoded?.arguments.count, 1)

        if case .float(let v) = decoded?.arguments.first {
            XCTAssertEqual(v, 72.5, accuracy: 0.001)
        } else {
            XCTFail("Expected float argument")
        }
    }

    func testRoundTrip_singleInt() {
        let original = OSCMessage(address: "/midi/note", arguments: [.int(60)])
        let data = original.encode()
        let decoded = OSCMessage.decode(from: data)

        XCTAssertNotNil(decoded)
        if case .int(let v) = decoded?.arguments.first {
            XCTAssertEqual(v, 60)
        } else {
            XCTFail("Expected int argument")
        }
    }

    func testRoundTrip_string() {
        let original = OSCMessage(address: "/info", arguments: [.string("Echoelmusic")])
        let data = original.encode()
        let decoded = OSCMessage.decode(from: data)

        XCTAssertNotNil(decoded)
        if case .string(let v) = decoded?.arguments.first {
            XCTAssertEqual(v, "Echoelmusic")
        } else {
            XCTFail("Expected string argument")
        }
    }

    func testRoundTrip_int64() {
        let original = OSCMessage(address: "/time", arguments: [.int64(1_000_000_000)])
        let data = original.encode()
        let decoded = OSCMessage.decode(from: data)

        XCTAssertNotNil(decoded)
        if case .int64(let v) = decoded?.arguments.first {
            XCTAssertEqual(v, 1_000_000_000)
        } else {
            XCTFail("Expected int64 argument")
        }
    }

    func testRoundTrip_double() {
        let original = OSCMessage(address: "/precise", arguments: [.double(3.14159265358979)])
        let data = original.encode()
        let decoded = OSCMessage.decode(from: data)

        XCTAssertNotNil(decoded)
        if case .double(let v) = decoded?.arguments.first {
            XCTAssertEqual(v, 3.14159265358979, accuracy: 1e-14)
        } else {
            XCTFail("Expected double argument")
        }
    }

    func testRoundTrip_bool() {
        let original = OSCMessage(address: "/toggle", arguments: [.bool(true), .bool(false)])
        let data = original.encode()
        let decoded = OSCMessage.decode(from: data)

        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.arguments.count, 2)
        if case .bool(let v1) = decoded?.arguments[0],
           case .bool(let v2) = decoded?.arguments[1] {
            XCTAssertTrue(v1)
            XCTAssertFalse(v2)
        } else {
            XCTFail("Expected bool arguments")
        }
    }

    func testRoundTrip_nil() {
        let original = OSCMessage(address: "/null", arguments: [.nil_])
        let data = original.encode()
        let decoded = OSCMessage.decode(from: data)

        XCTAssertNotNil(decoded)
        if case .nil_ = decoded?.arguments.first {
            // OK
        } else {
            XCTFail("Expected nil argument")
        }
    }

    func testRoundTrip_blob() {
        let blobData = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let original = OSCMessage(address: "/data", arguments: [.blob(blobData)])
        let data = original.encode()
        let decoded = OSCMessage.decode(from: data)

        XCTAssertNotNil(decoded)
        if case .blob(let v) = decoded?.arguments.first {
            XCTAssertEqual(v, blobData)
        } else {
            XCTFail("Expected blob argument")
        }
    }

    func testRoundTrip_multipleArguments() {
        let original = OSCMessage(address: "/echoelmusic/bio/all", arguments: [
            .float(72.5),   // HR
            .float(0.8),    // HRV
            .float(0.65),   // coherence
            .int(120),      // BPM
            .string("healthkit")
        ])
        let data = original.encode()
        let decoded = OSCMessage.decode(from: data)

        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.address, "/echoelmusic/bio/all")
        XCTAssertEqual(decoded?.arguments.count, 5)
    }

    func testRoundTrip_echoelmusicBioAddresses() {
        // Test all standard Echoelmusic OSC addresses
        let addresses = [
            "/echoelmusic/bio/heart/bpm",
            "/echoelmusic/bio/heart/hrv",
            "/echoelmusic/bio/breath/rate",
            "/echoelmusic/bio/breath/phase",
            "/echoelmusic/bio/coherence",
            "/echoelmusic/audio/rms",
            "/echoelmusic/audio/pitch"
        ]

        for addr in addresses {
            let msg = OSCMessage(address: addr, arguments: [.float(0.5)])
            let data = msg.encode()
            let decoded = OSCMessage.decode(from: data)
            XCTAssertEqual(decoded?.address, addr, "Failed round-trip for \(addr)")
        }
    }

    func testDecode_invalidData() {
        let result = OSCMessage.decode(from: Data([0x00, 0x01, 0x02]))
        XCTAssertNil(result)
    }

    func testDecode_emptyData() {
        let result = OSCMessage.decode(from: Data())
        XCTAssertNil(result)
    }

    func testEncode_bigEndianByteOrder() {
        let msg = OSCMessage(address: "/t", arguments: [.int(0x01020304)])
        let data = msg.encode()
        // Find the int bytes after address and type tag
        // Address "/t" = 4 bytes, type tag ",i" = 4 bytes, then 4 bytes int
        let intStart = 8
        XCTAssertGreaterThanOrEqual(data.count, intStart + 4)
        XCTAssertEqual(data[intStart], 0x01, "Big-endian MSB first")
        XCTAssertEqual(data[intStart + 1], 0x02)
        XCTAssertEqual(data[intStart + 2], 0x03)
        XCTAssertEqual(data[intStart + 3], 0x04)
    }
}

// MARK: - OSC Engine State Tests

@MainActor
final class OSCEngineStateTests: XCTestCase {

    func testTypeTagEnum_allCases() {
        // Verify all type tag characters match OSC 1.0 spec
        XCTAssertEqual(OSCTypeTag.int32.rawValue, Character("i"))
        XCTAssertEqual(OSCTypeTag.float32.rawValue, Character("f"))
        XCTAssertEqual(OSCTypeTag.string.rawValue, Character("s"))
        XCTAssertEqual(OSCTypeTag.blob.rawValue, Character("b"))
        XCTAssertEqual(OSCTypeTag.int64.rawValue, Character("h"))
        XCTAssertEqual(OSCTypeTag.float64.rawValue, Character("d"))
        XCTAssertEqual(OSCTypeTag.trueBool.rawValue, Character("T"))
        XCTAssertEqual(OSCTypeTag.falseBool.rawValue, Character("F"))
        XCTAssertEqual(OSCTypeTag.nil_.rawValue, Character("N"))
    }
}
#endif
