import XCTest
@testable import Echoelmusic

/// Comprehensive tests for ProfessionalStreamingEngine
/// Tests streaming protocols, quality presets, and RTMP functionality
final class ProfessionalStreamingEngineTests: XCTestCase {

    var sut: ProfessionalStreamingEngine!

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        sut = ProfessionalStreamingEngine()
    }

    override func tearDown() async throws {
        try await super.tearDown()
        sut = nil
    }

    // MARK: - Streaming Constants Tests

    func testRTMPProtocolConstants() {
        XCTAssertEqual(StreamingConstants.rtmpVersion, 3)
        XCTAssertEqual(StreamingConstants.rtmpHandshakeSize, 1536)
        XCTAssertEqual(StreamingConstants.rtmpChunkSize, 4096)
        XCTAssertEqual(StreamingConstants.rtmpWindowSize, 2500000)
    }

    func testVideoSettingsConstants() {
        XCTAssertEqual(StreamingConstants.defaultBitrate, 6_000_000)
        XCTAssertEqual(StreamingConstants.maxBitrate, 50_000_000)
        XCTAssertEqual(StreamingConstants.defaultFPS, 30)
        XCTAssertEqual(StreamingConstants.maxFPS, 120)
        XCTAssertEqual(StreamingConstants.keyframeInterval, 2)
    }

    func testAudioSettingsConstants() {
        XCTAssertEqual(StreamingConstants.audioBitrate, 320_000)
        XCTAssertEqual(StreamingConstants.audioSampleRate, 48000)
        XCTAssertEqual(StreamingConstants.audioChannels, 2)
    }

    func testBufferSettingsConstants() {
        XCTAssertEqual(StreamingConstants.videoBufferCount, 3)
        XCTAssertEqual(StreamingConstants.audioBufferDuration, 0.1)
    }

    // MARK: - Stream Quality Tests

    func testStreamQualityMobileResolution() {
        let quality = StreamQuality.mobile
        XCTAssertEqual(quality.resolution.width, 854)
        XCTAssertEqual(quality.resolution.height, 480)
    }

    func testStreamQualityStandardResolution() {
        let quality = StreamQuality.standard
        XCTAssertEqual(quality.resolution.width, 1280)
        XCTAssertEqual(quality.resolution.height, 720)
    }

    func testStreamQualityHDResolution() {
        let quality = StreamQuality.hd
        XCTAssertEqual(quality.resolution.width, 1920)
        XCTAssertEqual(quality.resolution.height, 1080)
    }

    func testStreamQualityFullHDResolution() {
        let quality = StreamQuality.fullHD
        XCTAssertEqual(quality.resolution.width, 1920)
        XCTAssertEqual(quality.resolution.height, 1080)
    }

    func testStreamQualityQHDResolution() {
        let quality = StreamQuality.qhd
        XCTAssertEqual(quality.resolution.width, 2560)
        XCTAssertEqual(quality.resolution.height, 1440)
    }

    func testStreamQuality4KResolution() {
        let quality = StreamQuality.uhd4k
        XCTAssertEqual(quality.resolution.width, 3840)
        XCTAssertEqual(quality.resolution.height, 2160)
    }

    func testStreamQuality8KResolution() {
        let quality = StreamQuality.uhd8k
        XCTAssertEqual(quality.resolution.width, 7680)
        XCTAssertEqual(quality.resolution.height, 4320)
    }

    func testStreamQualityAllCases() {
        let allCases = StreamQuality.allCases
        XCTAssertEqual(allCases.count, 8)
        XCTAssertTrue(allCases.contains(.mobile))
        XCTAssertTrue(allCases.contains(.uhd8k))
    }

    // MARK: - Stream Quality Bitrate Tests

    func testStreamQualityBitrates() {
        XCTAssertEqual(StreamQuality.mobile.bitrate, 1_500_000)
        XCTAssertEqual(StreamQuality.standard.bitrate, 3_000_000)
        XCTAssertEqual(StreamQuality.hd.bitrate, 6_000_000)
        XCTAssertEqual(StreamQuality.fullHD.bitrate, 9_000_000)
        XCTAssertEqual(StreamQuality.qhd.bitrate, 16_000_000)
        XCTAssertEqual(StreamQuality.uhd4k.bitrate, 35_000_000)
        XCTAssertEqual(StreamQuality.uhd8k.bitrate, 80_000_000)
    }

    func testBitrateIncreasesWithQuality() {
        let qualities: [StreamQuality] = [.mobile, .standard, .hd, .qhd, .uhd4k, .uhd8k]
        var previousBitrate = 0

        for quality in qualities {
            XCTAssertGreaterThan(quality.bitrate, previousBitrate,
                                 "\(quality.rawValue) bitrate should be higher than previous")
            previousBitrate = quality.bitrate
        }
    }

    // MARK: - Stream Quality Identifiable Tests

    func testStreamQualityIdentifiable() {
        for quality in StreamQuality.allCases {
            XCTAssertEqual(quality.id, quality.rawValue)
            XCTAssertFalse(quality.id.isEmpty)
        }
    }

    // MARK: - Resolution Aspect Ratio Tests

    func testResolutionAspectRatios() {
        let expectedRatio = 16.0 / 9.0
        let tolerance = 0.1

        for quality in StreamQuality.allCases {
            let resolution = quality.resolution
            let actualRatio = Double(resolution.width) / Double(resolution.height)

            XCTAssertEqual(actualRatio, expectedRatio, accuracy: tolerance,
                           "\(quality.rawValue) should have 16:9 aspect ratio")
        }
    }

    // MARK: - Edge Case Tests

    func testCustomQualityDefaults() {
        let quality = StreamQuality.custom
        XCTAssertEqual(quality.resolution.width, 1920)
        XCTAssertEqual(quality.resolution.height, 1080)
        XCTAssertEqual(quality.bitrate, 6_000_000)
    }

    func testStreamQualityRawValues() {
        XCTAssertEqual(StreamQuality.mobile.rawValue, "Mobile (480p)")
        XCTAssertEqual(StreamQuality.uhd4k.rawValue, "4K UHD")
        XCTAssertEqual(StreamQuality.uhd8k.rawValue, "8K UHD")
    }

    // MARK: - Performance Tests

    func testStreamQualityLookupPerformance() {
        measure {
            for _ in 0..<10000 {
                _ = StreamQuality.hd.resolution
                _ = StreamQuality.uhd4k.bitrate
            }
        }
    }

    // MARK: - Resolution Validation Tests

    func testAllResolutionsArePositive() {
        for quality in StreamQuality.allCases {
            XCTAssertGreaterThan(quality.resolution.width, 0)
            XCTAssertGreaterThan(quality.resolution.height, 0)
        }
    }

    func testAllBitratesArePositive() {
        for quality in StreamQuality.allCases {
            XCTAssertGreaterThan(quality.bitrate, 0)
        }
    }

    // MARK: - RTMP Handshake Tests

    func testRTMPHandshakeSizeIsStandard() {
        // RTMP handshake must be exactly 1536 bytes per spec
        XCTAssertEqual(StreamingConstants.rtmpHandshakeSize, 1536)
    }

    func testRTMPVersionIsV3() {
        // RTMP protocol version 3 is standard
        XCTAssertEqual(StreamingConstants.rtmpVersion, 3)
    }
}
