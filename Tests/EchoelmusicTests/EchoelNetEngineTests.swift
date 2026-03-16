#if canImport(Network)
//
//  EchoelNetEngineTests.swift
//  Echoelmusic — EchoelNet / OSC / Art-Net / Ableton Link Tests
//
//  Comprehensive tests for the network layer:
//  - OSCMessage creation, address validation, argument encoding/decoding
//  - OSC binary format compliance (4-byte alignment, big-endian)
//  - Art-Net constants and DMX fixture configuration
//  - Ableton Link session state and timing calculations
//  - Echoelmusic OSC namespace validation
//
//  Pure computation tests — no live network connections required.
//

import XCTest
@testable import Echoelmusic

// MARK: - OSC Message Creation Tests

final class OSCMessageCreationTests: XCTestCase {

    // MARK: - Address Validation

    func testMessage_addressStartsWithSlash() {
        let msg = OSCMessage(address: "/test")
        XCTAssertTrue(msg.address.hasPrefix("/"), "OSC addresses must start with /")
    }

    func testMessage_addressPreservesFullPath() {
        let addr = "/echoelmusic/bio/heart/bpm"
        let msg = OSCMessage(address: addr)
        XCTAssertEqual(msg.address, addr)
    }

    func testMessage_emptyAddress() {
        let msg = OSCMessage(address: "")
        XCTAssertEqual(msg.address, "")
        // Encoding should still produce valid 4-byte aligned data
        let data = msg.encode()
        XCTAssertEqual(data.count % 4, 0)
    }

    func testMessage_longNestedAddress() {
        let addr = "/echoelmusic/bio/eeg/alpha/channel/0/amplitude"
        let msg = OSCMessage(address: addr)
        XCTAssertEqual(msg.address, addr)
        let data = msg.encode()
        let decoded = OSCMessage.decode(from: data)
        XCTAssertEqual(decoded?.address, addr)
    }

    // MARK: - Argument Count

    func testMessage_zeroArguments() {
        let msg = OSCMessage(address: "/ping")
        XCTAssertTrue(msg.arguments.isEmpty)
    }

    func testMessage_singleArgument() {
        let msg = OSCMessage(address: "/test", arguments: [.float(1.0)])
        XCTAssertEqual(msg.arguments.count, 1)
    }

    func testMessage_manyArguments() {
        let args: [OSCValue] = (0..<20).map { .float(Float($0)) }
        let msg = OSCMessage(address: "/multi", arguments: args)
        XCTAssertEqual(msg.arguments.count, 20)
    }

    func testMessage_mixedArgumentTypes() {
        let msg = OSCMessage(address: "/mixed", arguments: [
            .int(42),
            .float(3.14),
            .string("hello"),
            .blob(Data([0xCA, 0xFE])),
            .int64(999_999_999_999),
            .double(2.718281828),
            .bool(true),
            .bool(false),
            .nil_
        ])
        XCTAssertEqual(msg.arguments.count, 9)
    }
}

// MARK: - OSC Echoelmusic Namespace Tests

final class OSCEchoelmusicNamespaceTests: XCTestCase {

    /// All standard Echoelmusic OSC addresses per protocol spec
    static let bioAddresses: [(address: String, description: String)] = [
        ("/echoelmusic/bio/heart/bpm", "Heart rate BPM"),
        ("/echoelmusic/bio/heart/hrv", "Heart rate variability"),
        ("/echoelmusic/bio/breath/rate", "Breathing rate"),
        ("/echoelmusic/bio/breath/phase", "Breath phase"),
        ("/echoelmusic/bio/coherence", "Bio coherence"),
        ("/echoelmusic/audio/rms", "Audio RMS level"),
        ("/echoelmusic/audio/pitch", "Audio pitch Hz"),
    ]

    func testAllBioAddresses_startWithSlash() {
        for entry in Self.bioAddresses {
            XCTAssertTrue(entry.address.hasPrefix("/"), "\(entry.description) address must start with /")
        }
    }

    func testAllBioAddresses_startWithEchoelmusicPrefix() {
        for entry in Self.bioAddresses {
            XCTAssertTrue(entry.address.hasPrefix("/echoelmusic/"), "\(entry.description) must use /echoelmusic/ prefix")
        }
    }

    func testAllBioAddresses_roundTrip() {
        for entry in Self.bioAddresses {
            let msg = OSCMessage(address: entry.address, arguments: [.float(0.5)])
            let data = msg.encode()
            let decoded = OSCMessage.decode(from: data)
            XCTAssertNotNil(decoded, "Round-trip failed for \(entry.description)")
            XCTAssertEqual(decoded?.address, entry.address, "Address mismatch for \(entry.description)")
        }
    }

    func testHeartBPM_validRange() {
        // Valid heart rate range: 40-200 BPM
        let values: [Float] = [40.0, 60.0, 72.0, 100.0, 150.0, 200.0]
        for bpm in values {
            let msg = OSCMessage(address: "/echoelmusic/bio/heart/bpm", arguments: [.float(bpm)])
            let data = msg.encode()
            let decoded = OSCMessage.decode(from: data)
            if case .float(let v) = decoded?.arguments.first {
                XCTAssertEqual(v, bpm, accuracy: 0.001, "BPM value mismatch for \(bpm)")
                XCTAssertGreaterThanOrEqual(v, 40.0, "BPM below minimum")
                XCTAssertLessThanOrEqual(v, 200.0, "BPM above maximum")
            } else {
                XCTFail("Expected float argument for BPM \(bpm)")
            }
        }
    }

    func testHeartHRV_normalizedRange() {
        // HRV normalized: 0-1
        let values: [Float] = [0.0, 0.25, 0.5, 0.75, 1.0]
        for hrv in values {
            let msg = OSCMessage(address: "/echoelmusic/bio/heart/hrv", arguments: [.float(hrv)])
            let data = msg.encode()
            let decoded = OSCMessage.decode(from: data)
            if case .float(let v) = decoded?.arguments.first {
                XCTAssertEqual(v, hrv, accuracy: 0.001)
                XCTAssertGreaterThanOrEqual(v, 0.0)
                XCTAssertLessThanOrEqual(v, 1.0)
            } else {
                XCTFail("Expected float argument for HRV \(hrv)")
            }
        }
    }

    func testBreathRate_validRange() {
        // Breath rate: 4-30 breaths per minute
        let values: [Float] = [4.0, 8.0, 12.0, 18.0, 30.0]
        for rate in values {
            let msg = OSCMessage(address: "/echoelmusic/bio/breath/rate", arguments: [.float(rate)])
            let data = msg.encode()
            let decoded = OSCMessage.decode(from: data)
            if case .float(let v) = decoded?.arguments.first {
                XCTAssertEqual(v, rate, accuracy: 0.001)
                XCTAssertGreaterThanOrEqual(v, 4.0)
                XCTAssertLessThanOrEqual(v, 30.0)
            } else {
                XCTFail("Expected float argument for breath rate \(rate)")
            }
        }
    }

    func testBreathPhase_normalizedRange() {
        // Breath phase: 0-1
        let msg = OSCMessage(address: "/echoelmusic/bio/breath/phase", arguments: [.float(0.5)])
        let data = msg.encode()
        let decoded = OSCMessage.decode(from: data)
        if case .float(let v) = decoded?.arguments.first {
            XCTAssertEqual(v, 0.5, accuracy: 0.001)
        } else {
            XCTFail("Expected float argument")
        }
    }

    func testCoherence_normalizedRange() {
        // Coherence: 0-1
        for coherence: Float in [0.0, 0.33, 0.66, 1.0] {
            let msg = OSCMessage(address: "/echoelmusic/bio/coherence", arguments: [.float(coherence)])
            let data = msg.encode()
            let decoded = OSCMessage.decode(from: data)
            if case .float(let v) = decoded?.arguments.first {
                XCTAssertEqual(v, coherence, accuracy: 0.001)
            } else {
                XCTFail("Expected float argument for coherence \(coherence)")
            }
        }
    }

    func testAudioRMS_normalizedRange() {
        // RMS: 0-1
        let msg = OSCMessage(address: "/echoelmusic/audio/rms", arguments: [.float(0.75)])
        let data = msg.encode()
        let decoded = OSCMessage.decode(from: data)
        if case .float(let v) = decoded?.arguments.first {
            XCTAssertEqual(v, 0.75, accuracy: 0.001)
        } else {
            XCTFail("Expected float argument")
        }
    }

    func testAudioPitch_hertzValue() {
        // Pitch in Hz (e.g., A4 = 440 Hz)
        let msg = OSCMessage(address: "/echoelmusic/audio/pitch", arguments: [.float(440.0)])
        let data = msg.encode()
        let decoded = OSCMessage.decode(from: data)
        if case .float(let v) = decoded?.arguments.first {
            XCTAssertEqual(v, 440.0, accuracy: 0.001)
        } else {
            XCTFail("Expected float argument for pitch")
        }
    }

    func testEEGBandAddresses_roundTrip() {
        // EEG band addresses from OSC spec
        let bands = ["delta", "theta", "alpha", "beta", "gamma"]
        for band in bands {
            let addr = "/echoelmusic/bio/eeg/\(band)"
            let msg = OSCMessage(address: addr, arguments: [.float(0.5)])
            let data = msg.encode()
            let decoded = OSCMessage.decode(from: data)
            XCTAssertEqual(decoded?.address, addr, "EEG band \(band) round-trip failed")
        }
    }
}

// MARK: - OSC Binary Encoding Compliance Tests

final class OSCBinaryEncodingTests: XCTestCase {

    func testEncoding_allDataIs4ByteAligned() {
        let messages = [
            OSCMessage(address: "/a"),
            OSCMessage(address: "/ab"),
            OSCMessage(address: "/abc"),
            OSCMessage(address: "/abcd"),
            OSCMessage(address: "/abcde"),
            OSCMessage(address: "/test", arguments: [.float(1.0)]),
            OSCMessage(address: "/test", arguments: [.string("x")]),
            OSCMessage(address: "/test", arguments: [.blob(Data([0x01]))]),
            OSCMessage(address: "/test", arguments: [.blob(Data([0x01, 0x02, 0x03, 0x04, 0x05]))]),
        ]

        for msg in messages {
            let data = msg.encode()
            XCTAssertEqual(data.count % 4, 0,
                "Message \(msg.address) with \(msg.arguments.count) args produced \(data.count) bytes (not 4-byte aligned)")
        }
    }

    func testEncoding_addressComesFirst() {
        let msg = OSCMessage(address: "/test", arguments: [.int(1)])
        let data = msg.encode()
        XCTAssertEqual(data[0], UInt8(ascii: "/"), "First byte must be / from address")
    }

    func testEncoding_typeTagHasCommaPrefix() {
        let msg = OSCMessage(address: "/t", arguments: [.float(1.0)])
        let data = msg.encode()
        // Address "/t" encodes to 4 bytes, then type tag starts
        XCTAssertEqual(data[4], UInt8(ascii: ","), "Type tag string must start with comma")
    }

    func testEncoding_typeTagContainsCorrectChars() {
        let msg = OSCMessage(address: "/t", arguments: [.int(1), .float(2.0), .string("hi")])
        let data = msg.encode()
        // Type tag should be ",ifs" + padding
        XCTAssertEqual(data[4], UInt8(ascii: ","))
        XCTAssertEqual(data[5], UInt8(ascii: "i"))
        XCTAssertEqual(data[6], UInt8(ascii: "f"))
        XCTAssertEqual(data[7], UInt8(ascii: "s"))
    }

    func testEncoding_int32BigEndian() {
        let msg = OSCMessage(address: "/t", arguments: [.int(0x01020304)])
        let data = msg.encode()
        // Address "/t" = 4 bytes, type tag ",i" = 4 bytes
        XCTAssertGreaterThanOrEqual(data.count, 12)
        XCTAssertEqual(data[8], 0x01, "MSB first (big-endian)")
        XCTAssertEqual(data[9], 0x02)
        XCTAssertEqual(data[10], 0x03)
        XCTAssertEqual(data[11], 0x04)
    }

    func testEncoding_int64Is8Bytes() {
        let msg = OSCMessage(address: "/t", arguments: [.int64(42)])
        let data = msg.encode()
        // Address 4 + type tag 4 + int64 8 = 16
        XCTAssertEqual(data.count, 16)
    }

    func testEncoding_doubleIs8Bytes() {
        let msg = OSCMessage(address: "/t", arguments: [.double(3.14)])
        let data = msg.encode()
        // Address 4 + type tag 4 + double 8 = 16
        XCTAssertEqual(data.count, 16)
    }

    func testEncoding_boolAndNilHaveNoDataBytes() {
        let msg = OSCMessage(address: "/t", arguments: [.bool(true), .bool(false), .nil_])
        let data = msg.encode()
        // Address "/t" = 4, type tag ",TFN" = 4, no argument data = 0
        XCTAssertEqual(data.count, 8, "Bool and nil types should not add data bytes")
    }

    func testEncoding_blobIncludesSizePrefix() {
        let blob = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let msg = OSCMessage(address: "/t", arguments: [.blob(blob)])
        let data = msg.encode()
        // Address 4 + type tag 4 + size(4) + blob(4) = 16
        XCTAssertEqual(data.count, 16)

        // Verify size prefix is big-endian 4
        let sizeBytes = data.subdata(in: 8..<12)
        let size = sizeBytes.withUnsafeBytes { $0.load(as: Int32.self).bigEndian }
        XCTAssertEqual(size, 4, "Blob size prefix must match blob length")
    }

    func testEncoding_blobPaddedTo4Bytes() {
        // 3-byte blob needs 1 byte padding
        let blob = Data([0x01, 0x02, 0x03])
        let msg = OSCMessage(address: "/t", arguments: [.blob(blob)])
        let data = msg.encode()
        XCTAssertEqual(data.count % 4, 0, "Blob must be padded to 4-byte boundary")
    }

    func testEncoding_stringArgumentPaddedTo4Bytes() {
        let msg = OSCMessage(address: "/t", arguments: [.string("x")])
        let data = msg.encode()
        XCTAssertEqual(data.count % 4, 0, "String argument must be 4-byte padded")
    }

    func testEncoding_emptyStringArgument() {
        let msg = OSCMessage(address: "/t", arguments: [.string("")])
        let data = msg.encode()
        XCTAssertEqual(data.count % 4, 0)
        let decoded = OSCMessage.decode(from: data)
        if case .string(let v) = decoded?.arguments.first {
            XCTAssertEqual(v, "")
        } else {
            XCTFail("Expected empty string argument")
        }
    }
}

// MARK: - OSC Decode Edge Cases

final class OSCDecodeEdgeCaseTests: XCTestCase {

    func testDecode_emptyData_returnsNil() {
        XCTAssertNil(OSCMessage.decode(from: Data()))
    }

    func testDecode_truncatedData_returnsNil() {
        XCTAssertNil(OSCMessage.decode(from: Data([0x2F]))) // Just "/"
    }

    func testDecode_noTypeTag_returnsNil() {
        // Address only, no type tag string
        let data = OSCMessage.encodeString("/test")
        XCTAssertNil(OSCMessage.decode(from: data))
    }

    func testDecode_typeTagWithoutComma_returnsNil() {
        // Manually build invalid data: address + type tag without comma
        var data = OSCMessage.encodeString("/test")
        data.append(OSCMessage.encodeString("if")) // missing comma prefix
        XCTAssertNil(OSCMessage.decode(from: data))
    }

    func testDecode_truncatedIntArgument_returnsNil() {
        // Build message with int type tag but only 2 bytes of data
        var data = OSCMessage.encodeString("/test")
        data.append(OSCMessage.encodeString(",i"))
        data.append(Data([0x00, 0x01])) // Only 2 bytes, need 4
        XCTAssertNil(OSCMessage.decode(from: data))
    }

    func testDecode_truncatedFloatArgument_returnsNil() {
        var data = OSCMessage.encodeString("/test")
        data.append(OSCMessage.encodeString(",f"))
        data.append(Data([0x00])) // Only 1 byte, need 4
        XCTAssertNil(OSCMessage.decode(from: data))
    }

    func testDecode_truncatedInt64Argument_returnsNil() {
        var data = OSCMessage.encodeString("/test")
        data.append(OSCMessage.encodeString(",h"))
        data.append(Data([0x00, 0x00, 0x00, 0x00])) // Only 4 bytes, need 8
        XCTAssertNil(OSCMessage.decode(from: data))
    }

    func testDecode_truncatedDoubleArgument_returnsNil() {
        var data = OSCMessage.encodeString("/test")
        data.append(OSCMessage.encodeString(",d"))
        data.append(Data([0x00, 0x00])) // Only 2 bytes, need 8
        XCTAssertNil(OSCMessage.decode(from: data))
    }

    func testDecode_truncatedBlobSize_returnsNil() {
        var data = OSCMessage.encodeString("/test")
        data.append(OSCMessage.encodeString(",b"))
        data.append(Data([0x00, 0x00])) // Only 2 bytes for size, need 4
        XCTAssertNil(OSCMessage.decode(from: data))
    }

    func testDecode_blobSizeExceedsData_returnsNil() {
        var data = OSCMessage.encodeString("/test")
        data.append(OSCMessage.encodeString(",b"))
        // Size claims 100 bytes but no data follows
        var size = Int32(100).bigEndian
        data.append(Data(bytes: &size, count: 4))
        XCTAssertNil(OSCMessage.decode(from: data))
    }

    func testDecode_unknownTypeTag_skipped() {
        // Unknown type tags should be ignored gracefully
        var data = OSCMessage.encodeString("/test")
        data.append(OSCMessage.encodeString(",Zi")) // Z is unknown, i is valid
        // Add int data for the "i" argument
        var val = Int32(42).bigEndian
        data.append(Data(bytes: &val, count: 4))
        let decoded = OSCMessage.decode(from: data)
        // Should still decode (unknown tag skipped, int parsed)
        XCTAssertNotNil(decoded)
    }
}

// MARK: - OSC Round-Trip Precision Tests

final class OSCRoundTripPrecisionTests: XCTestCase {

    func testRoundTrip_floatZero() {
        let msg = OSCMessage(address: "/v", arguments: [.float(0.0)])
        let decoded = OSCMessage.decode(from: msg.encode())
        if case .float(let v) = decoded?.arguments.first {
            XCTAssertEqual(v, 0.0)
        } else {
            XCTFail("Expected float")
        }
    }

    func testRoundTrip_floatNegative() {
        let msg = OSCMessage(address: "/v", arguments: [.float(-42.5)])
        let decoded = OSCMessage.decode(from: msg.encode())
        if case .float(let v) = decoded?.arguments.first {
            XCTAssertEqual(v, -42.5, accuracy: 0.001)
        } else {
            XCTFail("Expected float")
        }
    }

    func testRoundTrip_intNegative() {
        let msg = OSCMessage(address: "/v", arguments: [.int(-1)])
        let decoded = OSCMessage.decode(from: msg.encode())
        if case .int(let v) = decoded?.arguments.first {
            XCTAssertEqual(v, -1)
        } else {
            XCTFail("Expected int")
        }
    }

    func testRoundTrip_intMaxValue() {
        let msg = OSCMessage(address: "/v", arguments: [.int(Int32.max)])
        let decoded = OSCMessage.decode(from: msg.encode())
        if case .int(let v) = decoded?.arguments.first {
            XCTAssertEqual(v, Int32.max)
        } else {
            XCTFail("Expected int")
        }
    }

    func testRoundTrip_intMinValue() {
        let msg = OSCMessage(address: "/v", arguments: [.int(Int32.min)])
        let decoded = OSCMessage.decode(from: msg.encode())
        if case .int(let v) = decoded?.arguments.first {
            XCTAssertEqual(v, Int32.min)
        } else {
            XCTFail("Expected int")
        }
    }

    func testRoundTrip_int64MaxValue() {
        let msg = OSCMessage(address: "/v", arguments: [.int64(Int64.max)])
        let decoded = OSCMessage.decode(from: msg.encode())
        if case .int64(let v) = decoded?.arguments.first {
            XCTAssertEqual(v, Int64.max)
        } else {
            XCTFail("Expected int64")
        }
    }

    func testRoundTrip_doublePrecision() {
        let precise = 3.141592653589793238
        let msg = OSCMessage(address: "/v", arguments: [.double(precise)])
        let decoded = OSCMessage.decode(from: msg.encode())
        if case .double(let v) = decoded?.arguments.first {
            XCTAssertEqual(v, precise, accuracy: 1e-15)
        } else {
            XCTFail("Expected double")
        }
    }

    func testRoundTrip_emptyBlob() {
        let msg = OSCMessage(address: "/v", arguments: [.blob(Data())])
        let decoded = OSCMessage.decode(from: msg.encode())
        if case .blob(let v) = decoded?.arguments.first {
            XCTAssertTrue(v.isEmpty)
        } else {
            XCTFail("Expected empty blob")
        }
    }

    func testRoundTrip_largeBlob() {
        let blob = Data(repeating: 0xAB, count: 1024)
        let msg = OSCMessage(address: "/v", arguments: [.blob(blob)])
        let decoded = OSCMessage.decode(from: msg.encode())
        if case .blob(let v) = decoded?.arguments.first {
            XCTAssertEqual(v.count, 1024)
            XCTAssertEqual(v, blob)
        } else {
            XCTFail("Expected blob")
        }
    }

    func testRoundTrip_unicodeString() {
        let msg = OSCMessage(address: "/v", arguments: [.string("Echoelmusic Synth")])
        let decoded = OSCMessage.decode(from: msg.encode())
        if case .string(let v) = decoded?.arguments.first {
            XCTAssertEqual(v, "Echoelmusic Synth")
        } else {
            XCTFail("Expected string")
        }
    }

    func testRoundTrip_allTypesInOneMessage() {
        let blob = Data([0xCA, 0xFE, 0xBA, 0xBE])
        let msg = OSCMessage(address: "/echoelmusic/all", arguments: [
            .int(42),
            .float(3.14),
            .string("test"),
            .blob(blob),
            .int64(999_999),
            .double(2.718),
            .bool(true),
            .bool(false),
            .nil_
        ])

        let decoded = OSCMessage.decode(from: msg.encode())
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.arguments.count, 9)

        if case .int(let v) = decoded?.arguments[0] { XCTAssertEqual(v, 42) }
        else { XCTFail("Arg 0: expected int") }

        if case .float(let v) = decoded?.arguments[1] { XCTAssertEqual(v, 3.14, accuracy: 0.01) }
        else { XCTFail("Arg 1: expected float") }

        if case .string(let v) = decoded?.arguments[2] { XCTAssertEqual(v, "test") }
        else { XCTFail("Arg 2: expected string") }

        if case .blob(let v) = decoded?.arguments[3] { XCTAssertEqual(v, blob) }
        else { XCTFail("Arg 3: expected blob") }

        if case .int64(let v) = decoded?.arguments[4] { XCTAssertEqual(v, 999_999) }
        else { XCTFail("Arg 4: expected int64") }

        if case .double(let v) = decoded?.arguments[5] { XCTAssertEqual(v, 2.718, accuracy: 0.001) }
        else { XCTFail("Arg 5: expected double") }

        if case .bool(let v) = decoded?.arguments[6] { XCTAssertTrue(v) }
        else { XCTFail("Arg 6: expected bool true") }

        if case .bool(let v) = decoded?.arguments[7] { XCTAssertFalse(v) }
        else { XCTFail("Arg 7: expected bool false") }

        if case .nil_ = decoded?.arguments[8] { /* OK */ }
        else { XCTFail("Arg 8: expected nil") }
    }
}

// MARK: - Art-Net Constants Tests

final class ArtNetConstantsTests: XCTestCase {

    func testArtNet_defaultPort() {
        XCTAssertEqual(ArtNetConstants.port, 6454, "Art-Net uses UDP port 6454")
    }

    func testArtNet_protocolIDIsArtNetNull() {
        let expected: [UInt8] = [0x41, 0x72, 0x74, 0x2D, 0x4E, 0x65, 0x74, 0x00]
        XCTAssertEqual(ArtNetConstants.protocolID, expected, "Protocol ID must be 'Art-Net\\0'")
        // Verify it spells "Art-Net\0"
        let str = String(bytes: ArtNetConstants.protocolID.dropLast(), encoding: .ascii)
        XCTAssertEqual(str, "Art-Net")
    }

    func testArtNet_protocolIDLength() {
        XCTAssertEqual(ArtNetConstants.protocolID.count, 8, "Protocol ID must be 8 bytes")
    }

    func testArtNet_opCodeDMX() {
        XCTAssertEqual(ArtNetConstants.opDmx, 0x5000, "OpDmx must be 0x5000")
    }

    func testArtNet_opCodePoll() {
        XCTAssertEqual(ArtNetConstants.opPoll, 0x2000, "OpPoll must be 0x2000")
    }

    func testArtNet_opCodePollReply() {
        XCTAssertEqual(ArtNetConstants.opPollReply, 0x2100, "OpPollReply must be 0x2100")
    }

    func testArtNet_protocolVersion() {
        XCTAssertEqual(ArtNetConstants.protocolVersionHi, 0)
        XCTAssertEqual(ArtNetConstants.protocolVersionLo, 14, "Art-Net 4 protocol version is 14")
    }

    func testArtNet_channelsPerUniverse() {
        XCTAssertEqual(ArtNetConstants.channelsPerUniverse, 512, "DMX 512 = 512 channels per universe")
    }
}

// MARK: - DMX Fixture Type Tests

final class DMXFixtureTypeTests: XCTestCase {

    func testDimmer_channelCount() {
        XCTAssertEqual(DMXFixtureType.dimmer.channelCount, 1)
    }

    func testRGB_channelCount() {
        XCTAssertEqual(DMXFixtureType.rgb.channelCount, 3)
    }

    func testRGBW_channelCount() {
        XCTAssertEqual(DMXFixtureType.rgbw.channelCount, 4)
    }

    func testRGBWAU_channelCount() {
        XCTAssertEqual(DMXFixtureType.rgbwau.channelCount, 6)
    }

    func testMovingHead_channelCount() {
        XCTAssertEqual(DMXFixtureType.movingHead.channelCount, 8)
    }

    func testLaser_channelCount() {
        XCTAssertEqual(DMXFixtureType.laser.channelCount, 5)
    }

    func testFogMachine_channelCount() {
        XCTAssertEqual(DMXFixtureType.fogMachine.channelCount, 2)
    }

    func testStrobeLight_channelCount() {
        XCTAssertEqual(DMXFixtureType.strobeLight.channelCount, 2)
    }

    func testLEDBar_channelCount() {
        XCTAssertEqual(DMXFixtureType.ledBar.channelCount, 3)
    }

    func testAllFixtureTypes_havePositiveChannelCount() {
        for type in DMXFixtureType.allCases {
            XCTAssertGreaterThan(type.channelCount, 0, "\(type.rawValue) must have at least 1 channel")
        }
    }

    func testAllFixtureTypes_fitInUniverse() {
        for type in DMXFixtureType.allCases {
            XCTAssertLessThanOrEqual(type.channelCount, ArtNetConstants.channelsPerUniverse,
                "\(type.rawValue) channel count must fit in a DMX universe")
        }
    }

    func testAllFixtureTypes_haveNonEmptyName() {
        for type in DMXFixtureType.allCases {
            XCTAssertFalse(type.rawValue.isEmpty, "Fixture type must have a display name")
        }
    }
}

// MARK: - DMX Fixture Configuration Tests

final class DMXFixtureConfigTests: XCTestCase {

    func testFixture_defaultValues() {
        let fixture = DMXFixture(name: "Test", type: .rgb)
        XCTAssertEqual(fixture.name, "Test")
        XCTAssertEqual(fixture.type, .rgb)
        XCTAssertEqual(fixture.universe, 0)
        XCTAssertEqual(fixture.startAddress, 1)
        XCTAssertTrue(fixture.isEnabled)
    }

    func testFixture_customAddress() {
        let fixture = DMXFixture(name: "Back Wash", type: .rgbw, universe: 1, startAddress: 100)
        XCTAssertEqual(fixture.universe, 1)
        XCTAssertEqual(fixture.startAddress, 100)
    }

    func testFixture_uniqueIDs() {
        let f1 = DMXFixture(name: "A", type: .rgb)
        let f2 = DMXFixture(name: "B", type: .rgb)
        XCTAssertNotEqual(f1.id, f2.id, "Each fixture must have a unique ID")
    }

    func testFixture_identifiable() {
        let fixture = DMXFixture(name: "Test", type: .dimmer)
        // Identifiable conformance: id must not be nil
        let _: UUID = fixture.id
        // If we got here without a crash, Identifiable works
    }
}

// MARK: - LightColor Tests

final class LightColorTests: XCTestCase {

    func testLightColor_defaultIsBlack() {
        let color = LightColor()
        XCTAssertEqual(color.red, 0)
        XCTAssertEqual(color.green, 0)
        XCTAssertEqual(color.blue, 0)
        XCTAssertEqual(color.white, 0)
    }

    func testLightColor_customValues() {
        let color = LightColor(red: 255, green: 128, blue: 64, white: 32)
        XCTAssertEqual(color.red, 255)
        XCTAssertEqual(color.green, 128)
        XCTAssertEqual(color.blue, 64)
        XCTAssertEqual(color.white, 32)
    }

    func testLightColor_fromCoherence_lowIsCoolBlue() {
        let color = LightColor.fromCoherence(0.0)
        // Low coherence: red and green should be low, blue should be high
        XCTAssertEqual(color.red, 0)
        XCTAssertEqual(color.green, 0)
        XCTAssertEqual(color.blue, 255)
        XCTAssertEqual(color.white, 0)
    }

    func testLightColor_fromCoherence_highIsWarmAmber() {
        let color = LightColor.fromCoherence(1.0)
        // High coherence: red high, green medium, blue low
        XCTAssertEqual(color.red, 255)
        XCTAssertEqual(color.green, 180)
        XCTAssertEqual(color.blue, 0)
        XCTAssertEqual(color.white, 100)
    }

    func testLightColor_fromCoherence_clampsBelow0() {
        let color = LightColor.fromCoherence(-1.0)
        // Should clamp to 0 (cool blue)
        XCTAssertEqual(color.red, 0)
        XCTAssertEqual(color.blue, 255)
    }

    func testLightColor_fromCoherence_clampsAbove1() {
        let color = LightColor.fromCoherence(2.0)
        // Should clamp to 1 (warm amber)
        XCTAssertEqual(color.red, 255)
        XCTAssertEqual(color.blue, 0)
    }

    func testLightColor_fromCoherence_midpoint() {
        let color = LightColor.fromCoherence(0.5)
        // 0.5 * 255 = 127.5 -> 127
        XCTAssertEqual(color.red, UInt8(0.5 * 255))
        XCTAssertEqual(color.green, UInt8(0.5 * 180))
        XCTAssertEqual(color.blue, UInt8(0.5 * 255))
    }
}

// MARK: - Ableton Link Constants Tests

final class AbletonLinkConstantsTests: XCTestCase {

    func testLink_multicastAddress() {
        XCTAssertEqual(LinkConstants.multicastAddress, "224.76.78.75")
    }

    func testLink_port() {
        XCTAssertEqual(LinkConstants.port, 20808)
    }

    func testLink_protocolVersion() {
        XCTAssertEqual(LinkConstants.protocolVersion, 2)
    }

    func testLink_discoveryInterval() {
        XCTAssertEqual(LinkConstants.discoveryInterval, 1.0, "Discovery interval should be 1 second")
    }

    func testLink_sessionTimeout() {
        XCTAssertEqual(LinkConstants.sessionTimeout, 5.0, "Session timeout should be 5 seconds")
    }

    func testLink_microsecondsPerBeatAt120BPM() {
        // At 120 BPM, each beat is 0.5 seconds = 500,000 microseconds
        XCTAssertEqual(LinkConstants.microsecondsPerBeatAt120BPM, 500_000)
    }

    func testLink_messageTypes_areDistinct() {
        let types: [UInt8] = [
            LinkConstants.msgPing,
            LinkConstants.msgPong,
            LinkConstants.msgState,
            LinkConstants.msgStartStop
        ]
        let uniqueCount = Set(types).count
        XCTAssertEqual(uniqueCount, types.count, "All message types must be unique")
    }

    func testLink_messageTypeValues() {
        XCTAssertEqual(LinkConstants.msgPing, 0x01)
        XCTAssertEqual(LinkConstants.msgPong, 0x02)
        XCTAssertEqual(LinkConstants.msgState, 0x03)
        XCTAssertEqual(LinkConstants.msgStartStop, 0x04)
    }
}

// MARK: - Link Session State Tests

final class LinkSessionStateTests: XCTestCase {

    func testSessionState_defaultValues() {
        let state = LinkSessionState()
        XCTAssertEqual(state.tempo, 120.0)
        XCTAssertEqual(state.beat, 0.0)
        XCTAssertEqual(state.phase, 0.0)
        XCTAssertEqual(state.quantum, 4.0)
        XCTAssertFalse(state.isPlaying)
        XCTAssertEqual(state.peerCount, 0)
    }

    func testSessionState_customTempo() {
        let state = LinkSessionState(tempo: 140.0)
        XCTAssertEqual(state.tempo, 140.0)
    }

    func testSessionState_customQuantum() {
        let state = LinkSessionState(quantum: 3.0)
        XCTAssertEqual(state.quantum, 3.0)
    }

    func testSessionState_timestampIsPositive() {
        let state = LinkSessionState()
        XCTAssertGreaterThan(state.timestamp, 0, "Timestamp should be set on init")
    }

    func testSessionState_equatable() {
        let a = LinkSessionState(tempo: 120.0, quantum: 4.0)
        var b = LinkSessionState(tempo: 120.0, quantum: 4.0)
        // Timestamps differ, so they should not be equal in general
        b.timestamp = a.timestamp
        b.beat = a.beat
        b.phase = a.phase
        XCTAssertEqual(a, b)
    }

    func testSessionState_updateBeat_advancesWithTime() {
        var state = LinkSessionState(tempo: 120.0)
        // Simulate passage of time by setting timestamp in the past
        let now = UInt64(CFAbsoluteTimeGetCurrent() * 1_000_000)
        // 1 second ago at 120 BPM = 2 beats
        state.timestamp = now - 1_000_000
        state.updateBeat()
        XCTAssertGreaterThanOrEqual(state.beat, 1.9, "At 120 BPM, 1 second should produce ~2 beats")
        XCTAssertLessThanOrEqual(state.beat, 2.2, "Beat should be approximately 2")
    }

    func testSessionState_updateBeat_phaseWrapsWithinQuantum() {
        var state = LinkSessionState(tempo: 120.0, quantum: 4.0)
        let now = UInt64(CFAbsoluteTimeGetCurrent() * 1_000_000)
        state.timestamp = now - 1_000_000 // 1 second ago
        state.updateBeat()
        // Phase should be between 0 and 1
        XCTAssertGreaterThanOrEqual(state.phase, 0.0)
        XCTAssertLessThan(state.phase, 1.0)
    }

    func testSessionState_updateBeat_guardsAgainstZeroTempo() {
        var state = LinkSessionState(tempo: 0.0) // Would cause division by zero
        let now = UInt64(CFAbsoluteTimeGetCurrent() * 1_000_000)
        state.timestamp = now - 1_000_000
        // Should not crash — uses max(tempo, 20.0)
        state.updateBeat()
        XCTAssertGreaterThanOrEqual(state.beat, 0.0, "Should handle zero tempo safely")
    }

    func testSessionState_updateBeat_guardsAgainstNegativeTempo() {
        var state = LinkSessionState(tempo: -10.0)
        let now = UInt64(CFAbsoluteTimeGetCurrent() * 1_000_000)
        state.timestamp = now - 500_000
        // Should not crash
        state.updateBeat()
        // max(-10, 20) = 20, so beat should be positive
        XCTAssertGreaterThanOrEqual(state.beat, 0.0)
    }
}

// MARK: - Link Peer Tests

final class LinkPeerTests: XCTestCase {

    func testPeer_isStale_withinTimeout() {
        let peer = LinkPeer(
            id: UUID(),
            address: "192.168.1.100",
            port: 20808,
            name: "Test Peer",
            tempo: 120.0,
            lastSeen: CFAbsoluteTimeGetCurrent() // Just now
        )
        XCTAssertFalse(peer.isStale, "Peer seen just now should not be stale")
    }

    func testPeer_isStale_beyondTimeout() {
        let peer = LinkPeer(
            id: UUID(),
            address: "192.168.1.100",
            port: 20808,
            name: "Old Peer",
            tempo: 120.0,
            lastSeen: CFAbsoluteTimeGetCurrent() - 10.0 // 10 seconds ago
        )
        XCTAssertTrue(peer.isStale, "Peer not seen for 10 seconds should be stale (timeout = 5s)")
    }

    func testPeer_equatable() {
        let id = UUID()
        let a = LinkPeer(id: id, address: "192.168.1.1", port: 20808, name: "A", tempo: 120.0, lastSeen: 0)
        let b = LinkPeer(id: id, address: "192.168.1.1", port: 20808, name: "A", tempo: 120.0, lastSeen: 0)
        XCTAssertEqual(a, b)
    }

    func testPeer_identifiable() {
        let peer = LinkPeer(id: UUID(), address: "10.0.0.1", port: 20808, name: "P", tempo: 90.0, lastSeen: 0)
        let _: UUID = peer.id
    }
}

// MARK: - OSC String Encoding Extended Tests

final class OSCStringEncodingExtendedTests: XCTestCase {

    func testEncodeString_exactlyAligned() {
        // "abc" + null = 4 bytes, already aligned
        let data = OSCMessage.encodeString("abc")
        XCTAssertEqual(data.count, 4)
    }

    func testEncodeString_needsOneBytePadding() {
        // "abcde" = 5 + null = 6 bytes, needs 2 padding = 8
        let data = OSCMessage.encodeString("abcde")
        XCTAssertEqual(data.count, 8)
    }

    func testEncodeString_longAddress() {
        let addr = "/echoelmusic/bio/eeg/alpha/power/normalized/channel/left/temporal"
        let data = OSCMessage.encodeString(addr)
        XCTAssertEqual(data.count % 4, 0)
        // Round-trip
        var offset = 0
        let decoded = OSCMessage.decodeString(from: data, offset: &offset)
        XCTAssertEqual(decoded, addr)
    }

    func testDecodeString_advancesOffset() {
        let str1 = OSCMessage.encodeString("/first")
        let str2 = OSCMessage.encodeString("/second")
        var combined = str1
        combined.append(str2)

        var offset = 0
        let decoded1 = OSCMessage.decodeString(from: combined, offset: &offset)
        XCTAssertEqual(decoded1, "/first")
        let decoded2 = OSCMessage.decodeString(from: combined, offset: &offset)
        XCTAssertEqual(decoded2, "/second")
    }

    func testDecodeString_offsetBeyondData() {
        let data = OSCMessage.encodeString("/test")
        var offset = data.count + 10
        let result = OSCMessage.decodeString(from: data, offset: &offset)
        XCTAssertNil(result, "Offset beyond data should return nil")
    }
}

// MARK: - OSC Type Tag Enum Tests

final class OSCTypeTagEnumTests: XCTestCase {

    func testTypeTag_rawValues_matchOSCSpec() {
        // OSC 1.0 type tag characters
        XCTAssertEqual(OSCTypeTag.int32.rawValue, "i")
        XCTAssertEqual(OSCTypeTag.float32.rawValue, "f")
        XCTAssertEqual(OSCTypeTag.string.rawValue, "s")
        XCTAssertEqual(OSCTypeTag.blob.rawValue, "b")
        XCTAssertEqual(OSCTypeTag.int64.rawValue, "h")
        XCTAssertEqual(OSCTypeTag.float64.rawValue, "d")
        XCTAssertEqual(OSCTypeTag.trueBool.rawValue, "T")
        XCTAssertEqual(OSCTypeTag.falseBool.rawValue, "F")
        XCTAssertEqual(OSCTypeTag.nil_.rawValue, "N")
    }

    func testTypeTag_initFromRawValue() {
        XCTAssertEqual(OSCTypeTag(rawValue: "i"), .int32)
        XCTAssertEqual(OSCTypeTag(rawValue: "f"), .float32)
        XCTAssertEqual(OSCTypeTag(rawValue: "s"), .string)
        XCTAssertEqual(OSCTypeTag(rawValue: "b"), .blob)
        XCTAssertEqual(OSCTypeTag(rawValue: "h"), .int64)
        XCTAssertEqual(OSCTypeTag(rawValue: "d"), .float64)
        XCTAssertEqual(OSCTypeTag(rawValue: "T"), .trueBool)
        XCTAssertEqual(OSCTypeTag(rawValue: "F"), .falseBool)
        XCTAssertEqual(OSCTypeTag(rawValue: "N"), .nil_)
    }

    func testTypeTag_unknownRawValue() {
        XCTAssertNil(OSCTypeTag(rawValue: "Z"))
        XCTAssertNil(OSCTypeTag(rawValue: "x"))
    }

    func testTypeTag_isSendable() {
        // Compile-time check: OSCTypeTag conforms to Sendable
        let tag: any Sendable = OSCTypeTag.int32
        XCTAssertNotNil(tag)
    }
}

// MARK: - OSC Value Sendable Tests

final class OSCValueSendableTests: XCTestCase {

    func testOSCValue_isSendable() {
        let values: [any Sendable] = [
            OSCValue.int(0),
            OSCValue.float(0),
            OSCValue.string(""),
            OSCValue.blob(Data()),
            OSCValue.int64(0),
            OSCValue.double(0),
            OSCValue.bool(true),
            OSCValue.nil_
        ]
        XCTAssertEqual(values.count, 8)
    }

    func testOSCMessage_isSendable() {
        let msg: any Sendable = OSCMessage(address: "/test")
        XCTAssertNotNil(msg)
    }
}

// MARK: - Lighting Scene Tests

final class LightingSceneTests: XCTestCase {

    func testScene_defaultEmptyFixtures() {
        let scene = LightingScene(name: "Test")
        XCTAssertEqual(scene.name, "Test")
        XCTAssertTrue(scene.fixtures.isEmpty)
    }

    func testScene_uniqueID() {
        let a = LightingScene(name: "A")
        let b = LightingScene(name: "B")
        XCTAssertNotEqual(a.id, b.id)
    }

    func testScene_withFixtureColors() {
        let fixtureID = UUID()
        let color = LightColor(red: 255, green: 0, blue: 128)
        let scene = LightingScene(name: "Custom", fixtures: [fixtureID: color])
        XCTAssertEqual(scene.fixtures.count, 1)
        XCTAssertEqual(scene.fixtures[fixtureID]?.red, 255)
    }
}

#endif // canImport(Network)
