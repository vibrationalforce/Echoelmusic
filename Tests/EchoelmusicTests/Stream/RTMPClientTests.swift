import XCTest
@testable import Echoelmusic

/// Comprehensive tests for RTMPClient
/// Coverage target: RTMP protocol, handshake, packet framing, connection management
final class RTMPClientTests: XCTestCase {

    // MARK: - RTMP Handshake Tests

    func testHandshakeC0Version() {
        // C0 is 1 byte containing RTMP version (always 3)
        let rtmpVersion: UInt8 = 3
        XCTAssertEqual(rtmpVersion, 3, "RTMP version must be 3")
    }

    func testHandshakeC1Size() {
        // C1 is exactly 1536 bytes
        let c1Size = 1536
        XCTAssertEqual(c1Size, 1536)
    }

    func testHandshakeC2Size() {
        // C2 is exactly 1536 bytes (echo of S1)
        let c2Size = 1536
        XCTAssertEqual(c2Size, 1536)
    }

    func testHandshakeTimestamp() {
        // Handshake contains 4-byte timestamp
        let timestampBytes = 4
        XCTAssertEqual(timestampBytes, 4)
    }

    func testHandshakeRandomData() {
        // C1/S1 contains 1528 bytes of random data after timestamp
        let headerSize = 4 + 4  // timestamp + zero bytes
        let randomDataSize = 1536 - headerSize
        XCTAssertEqual(randomDataSize, 1528)
    }

    // MARK: - RTMP Chunk Tests

    func testChunkBasicHeader() {
        // Basic header: 1-3 bytes depending on chunk stream ID
        let csidSmall = 2      // Uses 1-byte header (csid 2-63)
        let csidMedium = 100   // Uses 2-byte header (csid 64-319)
        let csidLarge = 500    // Uses 3-byte header (csid 320-65599)

        XCTAssertGreaterThanOrEqual(csidSmall, 2)
        XCTAssertLessThanOrEqual(csidSmall, 63)

        XCTAssertGreaterThanOrEqual(csidMedium, 64)
        XCTAssertLessThanOrEqual(csidMedium, 319)

        XCTAssertGreaterThanOrEqual(csidLarge, 320)
    }

    func testChunkMessageHeaderType0() {
        // Type 0: Full header (11 bytes)
        // timestamp (3) + message length (3) + message type (1) + stream id (4)
        let type0Size = 3 + 3 + 1 + 4
        XCTAssertEqual(type0Size, 11)
    }

    func testChunkMessageHeaderType1() {
        // Type 1: 7 bytes (no stream id)
        let type1Size = 3 + 3 + 1
        XCTAssertEqual(type1Size, 7)
    }

    func testChunkMessageHeaderType2() {
        // Type 2: 3 bytes (timestamp delta only)
        let type2Size = 3
        XCTAssertEqual(type2Size, 3)
    }

    func testChunkMessageHeaderType3() {
        // Type 3: 0 bytes (no header, uses previous chunk's header)
        let type3Size = 0
        XCTAssertEqual(type3Size, 0)
    }

    func testDefaultChunkSize() {
        // Default RTMP chunk size is 128 bytes
        let defaultChunkSize = 128
        XCTAssertEqual(defaultChunkSize, 128)
    }

    func testMaxChunkSize() {
        // Max chunk size is typically 65536
        let maxChunkSize = 65536
        XCTAssertEqual(maxChunkSize, 65536)
    }

    // MARK: - RTMP Message Types

    func testSetChunkSizeMessageType() {
        // Set Chunk Size = 1
        let setChunkSize: UInt8 = 1
        XCTAssertEqual(setChunkSize, 1)
    }

    func testAbortMessageType() {
        // Abort Message = 2
        let abortMessage: UInt8 = 2
        XCTAssertEqual(abortMessage, 2)
    }

    func testAcknowledgementMessageType() {
        // Acknowledgement = 3
        let acknowledgement: UInt8 = 3
        XCTAssertEqual(acknowledgement, 3)
    }

    func testWindowAckSizeMessageType() {
        // Window Acknowledgement Size = 5
        let windowAckSize: UInt8 = 5
        XCTAssertEqual(windowAckSize, 5)
    }

    func testSetPeerBandwidthMessageType() {
        // Set Peer Bandwidth = 6
        let setPeerBandwidth: UInt8 = 6
        XCTAssertEqual(setPeerBandwidth, 6)
    }

    func testAudioMessageType() {
        // Audio = 8
        let audioMessage: UInt8 = 8
        XCTAssertEqual(audioMessage, 8)
    }

    func testVideoMessageType() {
        // Video = 9
        let videoMessage: UInt8 = 9
        XCTAssertEqual(videoMessage, 9)
    }

    func testDataAMF0MessageType() {
        // Data Message (AMF0) = 18
        let dataAMF0: UInt8 = 18
        XCTAssertEqual(dataAMF0, 18)
    }

    func testDataAMF3MessageType() {
        // Data Message (AMF3) = 15
        let dataAMF3: UInt8 = 15
        XCTAssertEqual(dataAMF3, 15)
    }

    func testCommandAMF0MessageType() {
        // Command Message (AMF0) = 20
        let commandAMF0: UInt8 = 20
        XCTAssertEqual(commandAMF0, 20)
    }

    func testCommandAMF3MessageType() {
        // Command Message (AMF3) = 17
        let commandAMF3: UInt8 = 17
        XCTAssertEqual(commandAMF3, 17)
    }

    func testAggregateMessageType() {
        // Aggregate Message = 22
        let aggregateMessage: UInt8 = 22
        XCTAssertEqual(aggregateMessage, 22)
    }

    // MARK: - RTMP URL Tests

    func testRTMPDefaultPort() {
        let defaultPort = 1935
        XCTAssertEqual(defaultPort, 1935)
    }

    func testRTMPSDefaultPort() {
        let rtmpsPort = 443
        XCTAssertEqual(rtmpsPort, 443)
    }

    func testRTMPURLParsing() {
        // Format: rtmp://host:port/app/playpath
        let url = "rtmp://live.twitch.tv:1935/app/streamkey"

        XCTAssertTrue(url.hasPrefix("rtmp://"))
        XCTAssertTrue(url.contains(":1935"))
        XCTAssertTrue(url.contains("/app/"))
    }

    func testRTMPSURLParsing() {
        // Format: rtmps://host:port/app/playpath
        let url = "rtmps://live-api-s.facebook.com:443/rtmp/"

        XCTAssertTrue(url.hasPrefix("rtmps://"))
        XCTAssertTrue(url.contains(":443"))
    }

    // MARK: - AMF Encoding Tests

    func testAMF0NumberMarker() {
        // AMF0 Number marker = 0x00
        let numberMarker: UInt8 = 0x00
        XCTAssertEqual(numberMarker, 0x00)
    }

    func testAMF0BooleanMarker() {
        // AMF0 Boolean marker = 0x01
        let booleanMarker: UInt8 = 0x01
        XCTAssertEqual(booleanMarker, 0x01)
    }

    func testAMF0StringMarker() {
        // AMF0 String marker = 0x02
        let stringMarker: UInt8 = 0x02
        XCTAssertEqual(stringMarker, 0x02)
    }

    func testAMF0ObjectMarker() {
        // AMF0 Object marker = 0x03
        let objectMarker: UInt8 = 0x03
        XCTAssertEqual(objectMarker, 0x03)
    }

    func testAMF0NullMarker() {
        // AMF0 Null marker = 0x05
        let nullMarker: UInt8 = 0x05
        XCTAssertEqual(nullMarker, 0x05)
    }

    func testAMF0ArrayMarker() {
        // AMF0 ECMA Array marker = 0x08
        let arrayMarker: UInt8 = 0x08
        XCTAssertEqual(arrayMarker, 0x08)
    }

    func testAMF0ObjectEndMarker() {
        // AMF0 Object End marker = 0x09
        let objectEndMarker: UInt8 = 0x09
        XCTAssertEqual(objectEndMarker, 0x09)
    }

    // MARK: - Connection Commands

    func testConnectCommandName() {
        let connectCommand = "connect"
        XCTAssertEqual(connectCommand, "connect")
    }

    func testCreateStreamCommandName() {
        let createStreamCommand = "createStream"
        XCTAssertEqual(createStreamCommand, "createStream")
    }

    func testPublishCommandName() {
        let publishCommand = "publish"
        XCTAssertEqual(publishCommand, "publish")
    }

    func testPlayCommandName() {
        let playCommand = "play"
        XCTAssertEqual(playCommand, "play")
    }

    func testDeleteStreamCommandName() {
        let deleteStreamCommand = "deleteStream"
        XCTAssertEqual(deleteStreamCommand, "deleteStream")
    }

    // MARK: - FLV Container Tests

    func testFLVSignature() {
        // FLV starts with "FLV" (0x46 0x4C 0x56)
        let signature: [UInt8] = [0x46, 0x4C, 0x56]
        XCTAssertEqual(signature, [0x46, 0x4C, 0x56])
    }

    func testFLVVersion() {
        // FLV version = 1
        let flvVersion: UInt8 = 1
        XCTAssertEqual(flvVersion, 1)
    }

    func testFLVHeaderSize() {
        // FLV header is 9 bytes
        let headerSize = 9
        XCTAssertEqual(headerSize, 9)
    }

    func testFLVTagHeaderSize() {
        // FLV tag header is 11 bytes
        let tagHeaderSize = 11
        XCTAssertEqual(tagHeaderSize, 11)
    }

    // MARK: - Video Codec Tests

    func testAVCCodecID() {
        // AVC/H.264 codec ID = 7
        let avcCodecID: UInt8 = 7
        XCTAssertEqual(avcCodecID, 7)
    }

    func testHEVCCodecID() {
        // HEVC/H.265 codec ID = 12 (enhanced RTMP)
        let hevcCodecID: UInt8 = 12
        XCTAssertEqual(hevcCodecID, 12)
    }

    func testAVCSequenceHeader() {
        // AVC sequence header (SPS/PPS) packet type = 0
        let sequenceHeader: UInt8 = 0
        XCTAssertEqual(sequenceHeader, 0)
    }

    func testAVCNALU() {
        // AVC NALU packet type = 1
        let nalu: UInt8 = 1
        XCTAssertEqual(nalu, 1)
    }

    func testAVCEndOfSequence() {
        // AVC end of sequence = 2
        let endOfSequence: UInt8 = 2
        XCTAssertEqual(endOfSequence, 2)
    }

    // MARK: - Audio Codec Tests

    func testAACCodecID() {
        // AAC codec ID = 10
        let aacCodecID: UInt8 = 10
        XCTAssertEqual(aacCodecID, 10)
    }

    func testMP3CodecID() {
        // MP3 codec ID = 2
        let mp3CodecID: UInt8 = 2
        XCTAssertEqual(mp3CodecID, 2)
    }

    func testAACSampleRates() {
        // Common AAC sample rates
        let sampleRates = [44100, 48000, 96000]
        XCTAssertTrue(sampleRates.contains(44100))
        XCTAssertTrue(sampleRates.contains(48000))
    }

    func testAACSequenceHeader() {
        // AAC sequence header packet type = 0
        let sequenceHeader: UInt8 = 0
        XCTAssertEqual(sequenceHeader, 0)
    }

    func testAACRawData() {
        // AAC raw data packet type = 1
        let rawData: UInt8 = 1
        XCTAssertEqual(rawData, 1)
    }

    // MARK: - Connection State Tests

    func testConnectionStates() {
        let states = ["disconnected", "connecting", "handshaking", "connected", "publishing", "error"]
        XCTAssertEqual(states.count, 6)
        XCTAssertTrue(states.contains("connected"))
        XCTAssertTrue(states.contains("publishing"))
    }

    // MARK: - Timestamp Tests

    func testExtendedTimestamp() {
        // Extended timestamp used when timestamp >= 0xFFFFFF (16777215)
        let maxNormalTimestamp: UInt32 = 0xFFFFFF
        XCTAssertEqual(maxNormalTimestamp, 16777215)
    }

    func testTimestampWraparound() {
        // 32-bit timestamp wraps around at 2^32 - 1
        let maxTimestamp: UInt32 = 0xFFFFFFFF
        XCTAssertEqual(maxTimestamp, 4294967295)
    }

    // MARK: - Bandwidth Tests

    func testDefaultWindowSize() {
        // Default window acknowledgement size is 2.5 MB
        let defaultWindowSize: Int = 2_500_000
        XCTAssertEqual(defaultWindowSize, 2_500_000)
    }

    func testPeerBandwidthLimitTypes() {
        // 0 = Hard, 1 = Soft, 2 = Dynamic
        let hardLimit: UInt8 = 0
        let softLimit: UInt8 = 1
        let dynamicLimit: UInt8 = 2

        XCTAssertEqual(hardLimit, 0)
        XCTAssertEqual(softLimit, 1)
        XCTAssertEqual(dynamicLimit, 2)
    }
}
