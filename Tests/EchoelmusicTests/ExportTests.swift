#if canImport(AVFoundation)
// ExportTests.swift
// Echoelmusic — Phase 4 Test Coverage: Export Pipeline
//
// Tests for UniversalExportPipeline types: ExportPreset, ExportJob,
// AudioFormat, VideoFormat, Resolution, Bitrate, LoudnessTarget,
// FrameRate, Container, and associated enums.

import XCTest
@testable import Echoelmusic

// MARK: - ExportPreset.ExportCategory Tests

final class ExportCategoryTests: XCTestCase {

    func testAllCases() {
        let cases = ExportPreset.ExportCategory.allCases
        XCTAssertGreaterThanOrEqual(cases.count, 10)
        XCTAssertTrue(cases.contains(.professional))
        XCTAssertTrue(cases.contains(.broadcast))
        XCTAssertTrue(cases.contains(.cinema))
        XCTAssertTrue(cases.contains(.streaming))
        XCTAssertTrue(cases.contains(.social))
        XCTAssertTrue(cases.contains(.podcast))
        XCTAssertTrue(cases.contains(.music))
    }
}

// MARK: - AudioCodec Tests

final class AudioCodecTests: XCTestCase {

    func testAllCases() {
        let cases = ExportPreset.AudioFormat.AudioCodec.allCases
        XCTAssertGreaterThan(cases.count, 8)
        XCTAssertTrue(cases.contains(.pcm))
        XCTAssertTrue(cases.contains(.flac))
        XCTAssertTrue(cases.contains(.alac))
        XCTAssertTrue(cases.contains(.aac))
        XCTAssertTrue(cases.contains(.mp3))
        XCTAssertTrue(cases.contains(.opus))
    }
}

// MARK: - ChannelLayout Tests

final class ChannelLayoutTests: XCTestCase {

    func testAllCases() {
        let cases = ExportPreset.AudioFormat.ChannelLayout.allCases
        XCTAssertGreaterThanOrEqual(cases.count, 5)
        XCTAssertTrue(cases.contains(.mono))
        XCTAssertTrue(cases.contains(.stereo))
        XCTAssertTrue(cases.contains(.surround5_1))
        XCTAssertTrue(cases.contains(.surround7_1))
        XCTAssertTrue(cases.contains(.atmos))
    }
}

// MARK: - VideoCodec Tests

final class VideoCodecTests: XCTestCase {

    func testAllCases() {
        let cases = ExportPreset.VideoFormat.VideoCodec.allCases
        XCTAssertGreaterThanOrEqual(cases.count, 5)
        XCTAssertTrue(cases.contains(.h264))
        XCTAssertTrue(cases.contains(.h265))
        XCTAssertTrue(cases.contains(.prores))
        XCTAssertTrue(cases.contains(.av1))
    }
}

// MARK: - Container Tests

final class ContainerTests: XCTestCase {

    func testAllCases() {
        let cases = ExportPreset.Container.allCases
        XCTAssertGreaterThanOrEqual(cases.count, 8)
        XCTAssertTrue(cases.contains(.wav))
        XCTAssertTrue(cases.contains(.aiff))
        XCTAssertTrue(cases.contains(.mp4))
        XCTAssertTrue(cases.contains(.mov))
        XCTAssertTrue(cases.contains(.flac))
    }
}

// MARK: - FrameRate Tests

final class FrameRateTests: XCTestCase {

    func testValues() {
        XCTAssertEqual(ExportPreset.FrameRate.fps24.value, 24.0, accuracy: 0.01)
        XCTAssertEqual(ExportPreset.FrameRate.fps25.value, 25.0, accuracy: 0.01)
        XCTAssertEqual(ExportPreset.FrameRate.fps30.value, 30.0, accuracy: 0.01)
        XCTAssertEqual(ExportPreset.FrameRate.fps60.value, 60.0, accuracy: 0.01)
        XCTAssertEqual(ExportPreset.FrameRate.fps120.value, 120.0, accuracy: 0.01)
    }

    func testCinemaFrameRates() {
        XCTAssertEqual(ExportPreset.FrameRate.fps23_976.value, 23.976, accuracy: 0.01)
        XCTAssertEqual(ExportPreset.FrameRate.fps29_97.value, 29.97, accuracy: 0.01)
        XCTAssertEqual(ExportPreset.FrameRate.fps59_94.value, 59.94, accuracy: 0.01)
    }
}

// MARK: - Resolution Tests

final class ResolutionTests: XCTestCase {

    func testStandardResolutions() {
        XCTAssertEqual(ExportPreset.Resolution.sd_480p.width, 854)
        XCTAssertEqual(ExportPreset.Resolution.sd_480p.height, 480)

        XCTAssertEqual(ExportPreset.Resolution.hd_720p.width, 1280)
        XCTAssertEqual(ExportPreset.Resolution.hd_720p.height, 720)

        XCTAssertEqual(ExportPreset.Resolution.hd_1080p.width, 1920)
        XCTAssertEqual(ExportPreset.Resolution.hd_1080p.height, 1080)

        XCTAssertEqual(ExportPreset.Resolution.uhd_4k.width, 3840)
        XCTAssertEqual(ExportPreset.Resolution.uhd_4k.height, 2160)
    }

    func testCinema4K() {
        XCTAssertEqual(ExportPreset.Resolution.cinema_4k.width, 4096)
        XCTAssertEqual(ExportPreset.Resolution.cinema_4k.height, 2160)
    }

    func test8K() {
        XCTAssertEqual(ExportPreset.Resolution.uhd_8k.width, 7680)
        XCTAssertEqual(ExportPreset.Resolution.uhd_8k.height, 4320)
    }

    func testResolutionNames() {
        XCTAssertFalse(ExportPreset.Resolution.hd_1080p.name.isEmpty)
        XCTAssertFalse(ExportPreset.Resolution.uhd_4k.name.isEmpty)
    }
}

// MARK: - Bitrate Tests

final class BitrateTests: XCTestCase {

    func testAudioPresets() {
        XCTAssertNotNil(ExportPreset.Bitrate.audioLossless.audio)
        XCTAssertNotNil(ExportPreset.Bitrate.audioHigh.audio)
        XCTAssertNotNil(ExportPreset.Bitrate.audioMedium.audio)
        XCTAssertNotNil(ExportPreset.Bitrate.audioLow.audio)
    }

    func testVideoPresets() {
        XCTAssertNotNil(ExportPreset.Bitrate.videoUltra.video)
        XCTAssertNotNil(ExportPreset.Bitrate.videoHigh.video)
        XCTAssertNotNil(ExportPreset.Bitrate.videoMedium.video)
        XCTAssertNotNil(ExportPreset.Bitrate.videoLow.video)
    }

    func testAudioBitrateOrdering() throws {
        let lossless = try XCTUnwrap(ExportPreset.Bitrate.audioLossless.audio)
        let high = try XCTUnwrap(ExportPreset.Bitrate.audioHigh.audio)
        let medium = try XCTUnwrap(ExportPreset.Bitrate.audioMedium.audio)
        let low = try XCTUnwrap(ExportPreset.Bitrate.audioLow.audio)

        XCTAssertGreaterThan(lossless, high)
        XCTAssertGreaterThan(high, medium)
        XCTAssertGreaterThan(medium, low)
    }
}

// MARK: - ExportJob Tests

final class ExportJobTests: XCTestCase {

    func testStatusValues() {
        let statuses: [ExportJob.ExportStatus] = [
            .queued, .preparing, .exporting,
            .finalizing, .completed, .failed, .cancelled
        ]
        XCTAssertEqual(statuses.count, 7)
    }

    func testStatusRawValues() {
        XCTAssertEqual(ExportJob.ExportStatus.queued.rawValue, "queued")
        XCTAssertEqual(ExportJob.ExportStatus.completed.rawValue, "completed")
        XCTAssertEqual(ExportJob.ExportStatus.failed.rawValue, "failed")
    }
}

// MARK: - UniversalExportPipeline Tests

@MainActor
final class UniversalExportPipelineTests: XCTestCase {

    func testInit() {
        let pipeline = UniversalExportPipeline()
        XCTAssertNotNil(pipeline)
        XCTAssertEqual(pipeline.exportProgress, 0.0, accuracy: 0.001)
    }

    func testLoadPresets() {
        let pipeline = UniversalExportPipeline()
        pipeline.loadExportPresets()
        XCTAssertGreaterThan(pipeline.availablePresets.count, 0)
    }

    func testGetPresetsByCategory() {
        let pipeline = UniversalExportPipeline()
        pipeline.loadExportPresets()
        let musicPresets = pipeline.getPresets(for: .music)
        // Should have at least one music preset
        for preset in musicPresets {
            XCTAssertEqual(preset.category, .music)
        }
    }

    func testPresetFileExtension() {
        let pipeline = UniversalExportPipeline()
        pipeline.loadExportPresets()
        for preset in pipeline.availablePresets {
            XCTAssertFalse(preset.fileExtension.isEmpty, "\(preset.name) missing file extension")
        }
    }

    func testGenerateReport() {
        let pipeline = UniversalExportPipeline()
        pipeline.loadExportPresets()
        let report = pipeline.generateExportReport()
        XCTAssertFalse(report.isEmpty)
    }
}

// MARK: - ColorRange Tests (ProColorGrading)

final class ColorRangeTests: XCTestCase {

    func testAllCases() {
        let cases = ColorRange.allCases
        XCTAssertEqual(cases.count, 8)
        XCTAssertTrue(cases.contains(.red))
        XCTAssertTrue(cases.contains(.orange))
        XCTAssertTrue(cases.contains(.yellow))
        XCTAssertTrue(cases.contains(.green))
        XCTAssertTrue(cases.contains(.cyan))
        XCTAssertTrue(cases.contains(.blue))
        XCTAssertTrue(cases.contains(.purple))
        XCTAssertTrue(cases.contains(.magenta))
    }

    func testCenterHue() {
        for color in ColorRange.allCases {
            let hue = color.centerHue
            XCTAssertGreaterThanOrEqual(hue, 0)
            XCTAssertLessThanOrEqual(hue, 360)
        }
    }

    func testCodable() throws {
        let original = ColorRange.cyan
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ColorRange.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - CurvePoint Tests (ProColorGrading)

final class CurvePointTests: XCTestCase {

    func testInit() {
        let point = CurvePoint(input: 0.5, output: 0.7)
        XCTAssertEqual(point.input, 0.5, accuracy: 0.001)
        XCTAssertEqual(point.output, 0.7, accuracy: 0.001)
    }

    func testEquatable() {
        let a = CurvePoint(input: 0.3, output: 0.5)
        let b = CurvePoint(input: 0.3, output: 0.5)
        XCTAssertEqual(a, b)
    }

    func testCodable() throws {
        let original = CurvePoint(input: 0.2, output: 0.8)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CurvePoint.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}
#endif
