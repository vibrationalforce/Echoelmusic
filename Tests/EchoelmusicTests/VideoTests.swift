// VideoTests.swift
// Echoelmusic — Comprehensive Video Module Tests
//
// Tests for Video module types: enums, structs, value types, Codable conformance,
// computed properties, boundary conditions, and pure functions.

import XCTest
import Foundation
@testable import Echoelmusic

// MARK: - VideoResolution Tests

final class VideoResolutionTests: XCTestCase {

    func testAllCasesCount() {
        let cases = VideoResolution.allCases
        XCTAssertEqual(cases.count, 9)
    }

    func testRawValues() {
        XCTAssertEqual(VideoResolution.sd480p.rawValue, "480p")
        XCTAssertEqual(VideoResolution.hd720p.rawValue, "720p")
        XCTAssertEqual(VideoResolution.fullHD1080p.rawValue, "1080p")
        XCTAssertEqual(VideoResolution.uhd4k.rawValue, "4K")
        XCTAssertEqual(VideoResolution.uhd8k.rawValue, "8K")
        XCTAssertEqual(VideoResolution.quantum16k.rawValue, "16K")
    }

    func testDimensions() {
        XCTAssertEqual(VideoResolution.sd480p.dimensions.width, 854)
        XCTAssertEqual(VideoResolution.sd480p.dimensions.height, 480)
        XCTAssertEqual(VideoResolution.fullHD1080p.dimensions.width, 1920)
        XCTAssertEqual(VideoResolution.fullHD1080p.dimensions.height, 1080)
        XCTAssertEqual(VideoResolution.uhd4k.dimensions.width, 3840)
        XCTAssertEqual(VideoResolution.uhd4k.dimensions.height, 2160)
    }

    func testPixelCount() {
        let res = VideoResolution.fullHD1080p
        XCTAssertEqual(res.pixelCount, 1920 * 1080)
    }

    func testBitrateIncreasesWithResolution() {
        let resolutions: [VideoResolution] = [.sd480p, .hd720p, .fullHD1080p, .uhd4k, .uhd8k]
        for i in 1..<resolutions.count {
            XCTAssertGreaterThan(resolutions[i].bitrate, resolutions[i - 1].bitrate,
                                 "\(resolutions[i].rawValue) bitrate should exceed \(resolutions[i - 1].rawValue)")
        }
    }

    func testCodableRoundTrip() throws {
        let original = VideoResolution.uhd4k
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VideoResolution.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - VideoFrameRate Tests

final class VideoFrameRateTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertGreaterThanOrEqual(VideoFrameRate.allCases.count, 10)
    }

    func testRawValues() {
        XCTAssertEqual(VideoFrameRate.cinema24.rawValue, 24.0)
        XCTAssertEqual(VideoFrameRate.standard30.rawValue, 30.0)
        XCTAssertEqual(VideoFrameRate.smooth60.rawValue, 60.0)
        XCTAssertEqual(VideoFrameRate.proMotion120.rawValue, 120.0)
    }

    func testCMTimeScale() {
        let fps = VideoFrameRate.standard30
        XCTAssertEqual(fps.cmTimeScale, CMTimeScale(30.0 * 1000))
    }

    func testCodableRoundTrip() throws {
        let original = VideoFrameRate.smooth60
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VideoFrameRate.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - VideoEffectType Tests

final class VideoEffectTypeTests: XCTestCase {

    func testAllCasesContainsExpectedEffects() {
        let cases = VideoEffectType.allCases
        XCTAssertTrue(cases.contains(.none))
        XCTAssertTrue(cases.contains(.blur))
        XCTAssertTrue(cases.contains(.filmGrain))
        XCTAssertTrue(cases.contains(.heartbeatPulse))
        XCTAssertTrue(cases.contains(.quantumWave))
    }

    func testCIFilterNameForKnownEffects() {
        XCTAssertEqual(VideoEffectType.blur.ciFilterName, "CIGaussianBlur")
        XCTAssertEqual(VideoEffectType.sharpen.ciFilterName, "CISharpenLuminance")
        XCTAssertEqual(VideoEffectType.comic.ciFilterName, "CIComicEffect")
        XCTAssertEqual(VideoEffectType.vignette.ciFilterName, "CIVignette")
    }

    func testCIFilterNameNilForCustomEffects() {
        XCTAssertNil(VideoEffectType.none.ciFilterName)
        XCTAssertNil(VideoEffectType.quantumWave.ciFilterName)
        XCTAssertNil(VideoEffectType.heartbeatPulse.ciFilterName)
        XCTAssertNil(VideoEffectType.filmGrain.ciFilterName)
    }

    func testRequiresMetalShaderForQuantumEffects() {
        XCTAssertTrue(VideoEffectType.quantumWave.requiresMetalShader)
        XCTAssertTrue(VideoEffectType.coherenceField.requiresMetalShader)
        XCTAssertTrue(VideoEffectType.heartbeatPulse.requiresMetalShader)
        XCTAssertTrue(VideoEffectType.depthOfField.requiresMetalShader)
    }

    func testDoesNotRequireMetalShaderForBasicEffects() {
        XCTAssertFalse(VideoEffectType.none.requiresMetalShader)
        XCTAssertFalse(VideoEffectType.blur.requiresMetalShader)
        XCTAssertFalse(VideoEffectType.filmGrain.requiresMetalShader)
        XCTAssertFalse(VideoEffectType.slowMotion.requiresMetalShader)
    }

    func testCodableRoundTrip() throws {
        let original = VideoEffectType.blur
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VideoEffectType.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - VideoLayer Tests

final class VideoLayerTests: XCTestCase {

    func testDefaultInitialization() {
        let layer = VideoLayer()
        XCTAssertEqual(layer.name, "Layer")
        XCTAssertEqual(layer.opacity, 1.0)
        XCTAssertEqual(layer.blendMode, .normal)
        XCTAssertTrue(layer.effects.isEmpty)
        XCTAssertTrue(layer.isVisible)
        XCTAssertFalse(layer.isMuted)
    }

    func testCustomInitialization() {
        let layer = VideoLayer(
            name: "Overlay",
            opacity: 0.5,
            blendMode: .screen,
            effects: [.blur, .vignette],
            isVisible: false,
            isMuted: true
        )
        XCTAssertEqual(layer.name, "Overlay")
        XCTAssertEqual(layer.opacity, 0.5)
        XCTAssertEqual(layer.blendMode, .screen)
        XCTAssertEqual(layer.effects.count, 2)
        XCTAssertFalse(layer.isVisible)
        XCTAssertTrue(layer.isMuted)
    }

    func testLayerTransformIdentity() {
        let identity = VideoLayer.LayerTransform.identity
        XCTAssertEqual(identity.position, .zero)
        XCTAssertEqual(identity.scale, SIMD2<Float>(1, 1))
        XCTAssertEqual(identity.rotation, 0)
        XCTAssertEqual(identity.anchor, SIMD2<Float>(0.5, 0.5))
    }

    func testBlendModeAllCases() {
        let cases = VideoLayer.BlendMode.allCases
        XCTAssertTrue(cases.contains(.normal))
        XCTAssertTrue(cases.contains(.multiply))
        XCTAssertTrue(cases.contains(.screen))
        XCTAssertTrue(cases.contains(.overlay))
        XCTAssertTrue(cases.contains(.quantumBlend))
        XCTAssertGreaterThanOrEqual(cases.count, 18)
    }

    func testCodableRoundTrip() throws {
        let layer = VideoLayer(name: "Test", opacity: 0.7, blendMode: .multiply, effects: [.blur])
        let data = try JSONEncoder().encode(layer)
        let decoded = try JSONDecoder().decode(VideoLayer.self, from: data)
        XCTAssertEqual(layer.id, decoded.id)
        XCTAssertEqual(layer.name, decoded.name)
        XCTAssertEqual(layer.opacity, decoded.opacity)
        XCTAssertEqual(layer.blendMode, decoded.blendMode)
    }
}

// MARK: - VideoProject Tests

final class VideoProjectTests: XCTestCase {

    func testDefaultInitialization() {
        let project = VideoProject()
        XCTAssertEqual(project.name, "Untitled Project")
        XCTAssertEqual(project.resolution, .uhd4k)
        XCTAssertEqual(project.frameRate, .smooth60)
        XCTAssertEqual(project.duration, 0)
        XCTAssertTrue(project.layers.isEmpty)
        XCTAssertTrue(project.audioTracks.isEmpty)
        XCTAssertTrue(project.markers.isEmpty)
    }

    func testCustomInitialization() {
        let project = VideoProject(name: "My Film", resolution: .fullHD1080p, frameRate: .cinema24)
        XCTAssertEqual(project.name, "My Film")
        XCTAssertEqual(project.resolution, .fullHD1080p)
        XCTAssertEqual(project.frameRate, .cinema24)
    }

    func testMetadataDefaults() {
        let project = VideoProject()
        XCTAssertEqual(project.metadata.author, "")
        XCTAssertEqual(project.metadata.description, "")
        XCTAssertTrue(project.metadata.tags.isEmpty)
        XCTAssertEqual(project.metadata.quantumCoherenceTarget, 0.85)
    }

    func testMarkerTypeAllCases() {
        let cases = VideoProject.TimelineMarker.MarkerType.allCases
        XCTAssertTrue(cases.contains(.standard))
        XCTAssertTrue(cases.contains(.chapter))
        XCTAssertTrue(cases.contains(.comment))
        XCTAssertTrue(cases.contains(.sync))
        XCTAssertTrue(cases.contains(.quantum))
    }
}

// MARK: - VideoProcessingStats Tests

final class VideoProcessingStatsTests: XCTestCase {

    func testZeroStats() {
        let stats = VideoProcessingStats.zero
        XCTAssertEqual(stats.framesProcessed, 0)
        XCTAssertEqual(stats.framesDropped, 0)
        XCTAssertEqual(stats.currentFPS, 0)
        XCTAssertEqual(stats.quantumCoherence, 0)
    }

    func testDropRateZeroWhenNoFrames() {
        let stats = VideoProcessingStats.zero
        XCTAssertEqual(stats.dropRate, 0)
    }

    func testDropRateCalculation() {
        let stats = VideoProcessingStats(
            framesProcessed: 90,
            framesDropped: 10,
            currentFPS: 60,
            averageFPS: 55,
            processingLatency: 0.01,
            gpuUtilization: 0.3,
            cpuUtilization: 0.2,
            memoryUsage: 100_000_000,
            encodingBitrate: 10_000_000,
            quantumCoherence: 0.8
        )
        XCTAssertEqual(stats.dropRate, 0.1, accuracy: 0.001)
    }
}

// MARK: - StreamingProtocol Tests

final class StreamingProtocolTests: XCTestCase {

    func testAllCases() {
        let cases = VideoStreamingManager.StreamingProtocol.allCases
        XCTAssertTrue(cases.contains(.rtmp))
        XCTAssertTrue(cases.contains(.srt))
        XCTAssertTrue(cases.contains(.webrtc))
        XCTAssertTrue(cases.contains(.hls))
    }

    func testRawValues() {
        XCTAssertEqual(VideoStreamingManager.StreamingProtocol.rtmp.rawValue, "RTMP")
        XCTAssertEqual(VideoStreamingManager.StreamingProtocol.srt.rawValue, "SRT")
        XCTAssertEqual(VideoStreamingManager.StreamingProtocol.hls.rawValue, "HLS")
    }
}

// MARK: - StreamingPlatform Tests

final class StreamingPlatformTests: XCTestCase {

    func testAllCases() {
        let cases = VideoStreamingManager.StreamingPlatform.allCases
        XCTAssertTrue(cases.contains(.youtube))
        XCTAssertTrue(cases.contains(.twitch))
        XCTAssertTrue(cases.contains(.tiktok))
        XCTAssertTrue(cases.contains(.custom))
    }

    func testRawValues() {
        XCTAssertEqual(VideoStreamingManager.StreamingPlatform.youtube.rawValue, "YouTube")
        XCTAssertEqual(VideoStreamingManager.StreamingPlatform.twitch.rawValue, "Twitch")
    }
}

// MARK: - CollaboratorRole Tests

final class CollaboratorRoleTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(VideoCollaborationHub.Collaborator.Role.director.rawValue, "director")
        XCTAssertEqual(VideoCollaborationHub.Collaborator.Role.editor.rawValue, "editor")
        XCTAssertEqual(VideoCollaborationHub.Collaborator.Role.colorist.rawValue, "colorist")
        XCTAssertEqual(VideoCollaborationHub.Collaborator.Role.vfx.rawValue, "vfx")
        XCTAssertEqual(VideoCollaborationHub.Collaborator.Role.audio.rawValue, "audio")
        XCTAssertEqual(VideoCollaborationHub.Collaborator.Role.viewer.rawValue, "viewer")
    }
}

// MARK: - ExportFormat (VideoExportManager) Tests

final class VideoExportFormatTests: XCTestCase {

    func testAllCasesCount() {
        let cases = VideoExportManager.ExportFormat.allCases
        XCTAssertEqual(cases.count, 11)
    }

    func testFileExtensionMp4ForH264() {
        XCTAssertEqual(VideoExportManager.ExportFormat.h264_baseline.fileExtension, "mp4")
        XCTAssertEqual(VideoExportManager.ExportFormat.h264_main.fileExtension, "mp4")
        XCTAssertEqual(VideoExportManager.ExportFormat.h264_high.fileExtension, "mp4")
    }

    func testFileExtensionMovForProRes() {
        XCTAssertEqual(VideoExportManager.ExportFormat.prores422.fileExtension, "mov")
        XCTAssertEqual(VideoExportManager.ExportFormat.prores4444.fileExtension, "mov")
    }

    func testFileExtensionForImageFormats() {
        XCTAssertEqual(VideoExportManager.ExportFormat.png_sequence.fileExtension, "png")
        XCTAssertEqual(VideoExportManager.ExportFormat.gif_animated.fileExtension, "gif")
    }

    func testIsImageSequence() {
        XCTAssertTrue(VideoExportManager.ExportFormat.png_sequence.isImageSequence)
        XCTAssertTrue(VideoExportManager.ExportFormat.gif_animated.isImageSequence)
        XCTAssertFalse(VideoExportManager.ExportFormat.h264_high.isImageSequence)
        XCTAssertFalse(VideoExportManager.ExportFormat.hevc_main.isImageSequence)
        XCTAssertFalse(VideoExportManager.ExportFormat.prores422.isImageSequence)
    }

    func testCodecTypeNilForImageFormats() {
        XCTAssertNil(VideoExportManager.ExportFormat.png_sequence.codecType)
        XCTAssertNil(VideoExportManager.ExportFormat.gif_animated.codecType)
    }

    func testCodecTypeNonNilForVideoFormats() {
        XCTAssertNotNil(VideoExportManager.ExportFormat.h264_high.codecType)
        XCTAssertNotNil(VideoExportManager.ExportFormat.hevc_main.codecType)
    }

    func testH264ProfileForH264Formats() {
        XCTAssertNotNil(VideoExportManager.ExportFormat.h264_baseline.h264Profile)
        XCTAssertNotNil(VideoExportManager.ExportFormat.h264_main.h264Profile)
        XCTAssertNotNil(VideoExportManager.ExportFormat.h264_high.h264Profile)
    }

    func testH264ProfileNilForNonH264() {
        XCTAssertNil(VideoExportManager.ExportFormat.hevc_main.h264Profile)
        XCTAssertNil(VideoExportManager.ExportFormat.prores422.h264Profile)
        XCTAssertNil(VideoExportManager.ExportFormat.png_sequence.h264Profile)
    }

    func testSupportsHardwareEncoding() {
        XCTAssertTrue(VideoExportManager.ExportFormat.h264_high.supportsHardwareEncoding)
        XCTAssertTrue(VideoExportManager.ExportFormat.hevc_main.supportsHardwareEncoding)
        XCTAssertFalse(VideoExportManager.ExportFormat.prores422.supportsHardwareEncoding)
        XCTAssertFalse(VideoExportManager.ExportFormat.png_sequence.supportsHardwareEncoding)
    }
}

// MARK: - ExportResolution Tests

final class ExportResolutionTests: XCTestCase {

    func testSizeReturnsCorrectDimensions() {
        XCTAssertEqual(VideoExportManager.Resolution.sd640x480.size, CGSize(width: 640, height: 480))
        XCTAssertEqual(VideoExportManager.Resolution.hd1280x720.size, CGSize(width: 1280, height: 720))
        XCTAssertEqual(VideoExportManager.Resolution.hd1920x1080.size, CGSize(width: 1920, height: 1080))
        XCTAssertEqual(VideoExportManager.Resolution.uhd3840x2160.size, CGSize(width: 3840, height: 2160))
    }

    func testOriginalResolutionReturnsNilSize() {
        XCTAssertNil(VideoExportManager.Resolution.original.size)
    }
}

// MARK: - ExportFrameRate Tests

final class ExportFrameRateTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(VideoExportManager.FrameRate.fps24.rawValue, 24)
        XCTAssertEqual(VideoExportManager.FrameRate.fps30.rawValue, 30)
        XCTAssertEqual(VideoExportManager.FrameRate.fps60.rawValue, 60)
        XCTAssertEqual(VideoExportManager.FrameRate.fps120.rawValue, 120)
    }
}

// MARK: - ExportQuality Tests

final class ExportQualityTests: XCTestCase {

    func testCompressionQualityRange() {
        for quality in VideoExportManager.Quality.allCases {
            XCTAssertGreaterThanOrEqual(quality.compressionQuality, 0.0)
            XCTAssertLessThanOrEqual(quality.compressionQuality, 1.0)
        }
    }

    func testCompressionQualityIncreases() {
        XCTAssertLessThan(VideoExportManager.Quality.low.compressionQuality,
                          VideoExportManager.Quality.medium.compressionQuality)
        XCTAssertLessThan(VideoExportManager.Quality.medium.compressionQuality,
                          VideoExportManager.Quality.high.compressionQuality)
        XCTAssertLessThan(VideoExportManager.Quality.high.compressionQuality,
                          VideoExportManager.Quality.maximum.compressionQuality)
    }

    func testBitrateIncreases() {
        XCTAssertLessThan(VideoExportManager.Quality.low.bitrate,
                          VideoExportManager.Quality.medium.bitrate)
        XCTAssertLessThan(VideoExportManager.Quality.medium.bitrate,
                          VideoExportManager.Quality.high.bitrate)
        XCTAssertLessThan(VideoExportManager.Quality.high.bitrate,
                          VideoExportManager.Quality.maximum.bitrate)
    }
}

// MARK: - ExportError Tests

final class ExportErrorTests: XCTestCase {

    func testErrorDescriptions() {
        XCTAssertNotNil(ExportError.exportAlreadyInProgress.errorDescription)
        XCTAssertNotNil(ExportError.exportSessionCreationFailed.errorDescription)
        XCTAssertNotNil(ExportError.exportFailed.errorDescription)
        XCTAssertNotNil(ExportError.exportCancelled.errorDescription)
        XCTAssertNotNil(ExportError.noVideoTrack.errorDescription)
    }
}

// MARK: - TimeSignature Tests

final class TimeSignatureTests: XCTestCase {

    func testDefaultInit() {
        let ts = TimeSignature()
        XCTAssertEqual(ts.numerator, 4)
        XCTAssertEqual(ts.denominator, 4)
    }

    func testCommonTimeSignatures() {
        XCTAssertEqual(TimeSignature.fourFour.numerator, 4)
        XCTAssertEqual(TimeSignature.fourFour.denominator, 4)
        XCTAssertEqual(TimeSignature.threeFour.numerator, 3)
        XCTAssertEqual(TimeSignature.sixEight.numerator, 6)
        XCTAssertEqual(TimeSignature.sixEight.denominator, 8)
    }

    func testDisplayString() {
        XCTAssertEqual(TimeSignature.fourFour.displayString, "4/4")
        XCTAssertEqual(TimeSignature.threeFour.displayString, "3/4")
        XCTAssertEqual(TimeSignature.sixEight.displayString, "6/8")
    }

    func testBeatsPerBarSimpleMeter() {
        XCTAssertEqual(TimeSignature.fourFour.beatsPerBar, 4)
        XCTAssertEqual(TimeSignature.threeFour.beatsPerBar, 3)
        XCTAssertEqual(TimeSignature.twoFour.beatsPerBar, 2)
    }

    func testBeatsPerBarCompoundMeter() {
        // 6/8 groups into 2 beats, 12/8 into 4 beats
        XCTAssertEqual(TimeSignature.sixEight.beatsPerBar, 2)
        XCTAssertEqual(TimeSignature.twelveEight.beatsPerBar, 4)
    }

    func testSubdivisionsPerBeatCompound() {
        XCTAssertEqual(TimeSignature.sixEight.subdivisionsPerBeat, 3)
        XCTAssertEqual(TimeSignature.twelveEight.subdivisionsPerBeat, 3)
    }

    func testSubdivisionsPerBeatSimple() {
        XCTAssertEqual(TimeSignature.fourFour.subdivisionsPerBeat, 1)
        XCTAssertEqual(TimeSignature.threeFour.subdivisionsPerBeat, 1)
    }

    func testCommonArrayContainsExpected() {
        XCTAssertGreaterThanOrEqual(TimeSignature.common.count, 7)
        XCTAssertTrue(TimeSignature.common.contains(.fourFour))
        XCTAssertTrue(TimeSignature.common.contains(.threeFour))
        XCTAssertTrue(TimeSignature.common.contains(.sixEight))
    }

    func testCodableRoundTrip() throws {
        let original = TimeSignature.sixEight
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TimeSignature.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - SnapMode Tests

final class SnapModeTests: XCTestCase {

    func testAllCases() {
        let cases = SnapMode.allCases
        XCTAssertTrue(cases.contains(.off))
        XCTAssertTrue(cases.contains(.beat))
        XCTAssertTrue(cases.contains(.bar))
        XCTAssertTrue(cases.contains(.triplet))
        XCTAssertTrue(cases.contains(.sixteenth))
    }

    func testSubdivisionsPerBeat() {
        XCTAssertEqual(SnapMode.off.subdivisionsPerBeat, 0)
        XCTAssertEqual(SnapMode.beat.subdivisionsPerBeat, 1)
        XCTAssertEqual(SnapMode.halfBeat.subdivisionsPerBeat, 2)
        XCTAssertEqual(SnapMode.quarterBeat.subdivisionsPerBeat, 4)
        XCTAssertEqual(SnapMode.triplet.subdivisionsPerBeat, 3)
        XCTAssertEqual(SnapMode.sixteenth.subdivisionsPerBeat, 16)
        XCTAssertEqual(SnapMode.thirtySecond.subdivisionsPerBeat, 32)
    }

    func testCodableRoundTrip() throws {
        let original = SnapMode.triplet
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SnapMode.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - BeatPosition Tests

final class BeatPositionTests: XCTestCase {

    func testDefaultInit() {
        let pos = BeatPosition()
        XCTAssertEqual(pos.bar, 1)
        XCTAssertEqual(pos.beat, 1)
        XCTAssertEqual(pos.tick, 0)
    }

    func testDisplayString() {
        let pos = BeatPosition(bar: 3, beat: 2, tick: 480)
        XCTAssertEqual(pos.displayString, "3.2.480")
    }

    func testShortDisplayString() {
        let pos = BeatPosition(bar: 5, beat: 3, tick: 0)
        XCTAssertEqual(pos.shortDisplayString, "5.3")
    }

    func testComparableOrdering() {
        let a = BeatPosition(bar: 1, beat: 1, tick: 0)
        let b = BeatPosition(bar: 1, beat: 2, tick: 0)
        let c = BeatPosition(bar: 2, beat: 1, tick: 0)
        XCTAssertLessThan(a, b)
        XCTAssertLessThan(b, c)
        XCTAssertLessThan(a, c)
    }

    func testComparableTickOrdering() {
        let a = BeatPosition(bar: 1, beat: 1, tick: 100)
        let b = BeatPosition(bar: 1, beat: 1, tick: 200)
        XCTAssertLessThan(a, b)
    }

    func testFromSecondsRoundTrip() {
        let bpm = 120.0
        let seconds = 2.0 // 2 seconds at 120 BPM = 4 beats = 1 bar of 4/4
        let position = BeatPosition.from(seconds: seconds, bpm: bpm)
        let roundTrip = position.toSeconds(bpm: bpm)
        XCTAssertEqual(roundTrip, seconds, accuracy: 0.01)
    }

    func testFromSecondsAtZero() {
        let pos = BeatPosition.from(seconds: 0, bpm: 120)
        XCTAssertEqual(pos.bar, 1)
        XCTAssertEqual(pos.beat, 1)
        XCTAssertEqual(pos.tick, 0)
    }

    func testToSecondsAtOrigin() {
        let pos = BeatPosition(bar: 1, beat: 1, tick: 0)
        let seconds = pos.toSeconds(bpm: 120)
        XCTAssertEqual(seconds, 0, accuracy: 0.001)
    }

    func testCodableRoundTrip() throws {
        let original = BeatPosition(bar: 4, beat: 3, tick: 240)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BeatPosition.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - BeatMarker Tests

final class BeatMarkerTests: XCTestCase {

    func testDefaultInit() {
        let marker = BeatMarker()
        XCTAssertEqual(marker.type, .beat)
        XCTAssertEqual(marker.label, "")
        XCTAssertEqual(marker.color, "#FF0000")
    }

    func testMarkerTypeAllCases() {
        let cases = BeatMarker.MarkerType.allCases
        XCTAssertTrue(cases.contains(.downbeat))
        XCTAssertTrue(cases.contains(.beat))
        XCTAssertTrue(cases.contains(.drop))
        XCTAssertTrue(cases.contains(.transition))
        XCTAssertTrue(cases.contains(.cut))
        XCTAssertGreaterThanOrEqual(cases.count, 10)
    }

    func testCodableRoundTrip() throws {
        let marker = BeatMarker(
            position: BeatPosition(bar: 2, beat: 1, tick: 0),
            type: .downbeat,
            label: "Chorus",
            color: "#00FF00"
        )
        let data = try JSONEncoder().encode(marker)
        let decoded = try JSONDecoder().decode(BeatMarker.self, from: data)
        XCTAssertEqual(decoded.type, .downbeat)
        XCTAssertEqual(decoded.label, "Chorus")
        XCTAssertEqual(decoded.color, "#00FF00")
    }
}

// MARK: - BPMGrid Tests

final class BPMGridTests: XCTestCase {

    func testDefaultInit() {
        let grid = BPMGrid()
        XCTAssertEqual(grid.bpm, 120)
        XCTAssertEqual(grid.offset, 0)
        XCTAssertTrue(grid.tempoChanges.isEmpty)
    }

    func testSecondsPerBeat() {
        let grid = BPMGrid(bpm: 120)
        XCTAssertEqual(grid.secondsPerBeat(), 0.5, accuracy: 0.001)
    }

    func testSecondsPerBar() {
        let grid = BPMGrid(bpm: 120, timeSignature: .fourFour)
        XCTAssertEqual(grid.secondsPerBar(), 2.0, accuracy: 0.001)
    }

    func testSnapToGridBeat() {
        let grid = BPMGrid(bpm: 120) // 0.5s per beat
        let snapped = grid.snapToGrid(seconds: 0.6, snapMode: .beat)
        XCTAssertEqual(snapped, 0.5, accuracy: 0.01)
    }

    func testSnapToGridBar() {
        let grid = BPMGrid(bpm: 120, timeSignature: .fourFour) // 2s per bar
        let snapped = grid.snapToGrid(seconds: 2.3, snapMode: .bar)
        XCTAssertEqual(snapped, 2.0, accuracy: 0.01)
    }

    func testSnapToGridOff() {
        let grid = BPMGrid(bpm: 120)
        let time = 0.73
        let snapped = grid.snapToGrid(seconds: time, snapMode: .off)
        XCTAssertEqual(snapped, time, accuracy: 0.001)
    }

    func testIsOnBeat() {
        let grid = BPMGrid(bpm: 120) // beats at 0.0, 0.5, 1.0, ...
        XCTAssertTrue(grid.isOnBeat(0.0))
        XCTAssertTrue(grid.isOnBeat(0.5))
        XCTAssertFalse(grid.isOnBeat(0.3))
    }

    func testIsOnDownbeat() {
        let grid = BPMGrid(bpm: 120, timeSignature: .fourFour) // bars at 0, 2, 4, ...
        XCTAssertTrue(grid.isOnDownbeat(0.0))
        XCTAssertTrue(grid.isOnDownbeat(2.0))
        XCTAssertFalse(grid.isOnDownbeat(0.5))
    }

    func testGridLinesReturnsCorrectCount() {
        let grid = BPMGrid(bpm: 120) // 0.5s per beat
        let lines = grid.gridLines(from: 0, to: 2.0, snapMode: .beat)
        // Should have beats at 0.0, 0.5, 1.0, 1.5, 2.0 = 5 lines
        XCTAssertEqual(lines.count, 5)
    }

    func testNextBeat() {
        let grid = BPMGrid(bpm: 120) // beats at 0.0, 0.5, 1.0
        let next = grid.nextBeat(after: 0.1)
        XCTAssertEqual(next, 0.5, accuracy: 0.01)
    }

    func testPreviousBeat() {
        let grid = BPMGrid(bpm: 120) // beats at 0.0, 0.5, 1.0
        let prev = grid.previousBeat(before: 0.9)
        XCTAssertEqual(prev, 0.5, accuracy: 0.01)
    }

    func testBPMAtWithNoTempoChanges() {
        let grid = BPMGrid(bpm: 140)
        XCTAssertEqual(grid.bpmAt(seconds: 5.0), 140)
    }
}

// MARK: - BeatDetectionResult Tests

final class BeatDetectionResultTests: XCTestCase {

    func testDefaultInit() {
        let result = BeatDetectionResult()
        XCTAssertEqual(result.bpm, 120)
        XCTAssertEqual(result.confidence, 0)
        XCTAssertTrue(result.beats.isEmpty)
        XCTAssertTrue(result.downbeats.isEmpty)
        XCTAssertEqual(result.offset, 0)
    }

    func testCodableRoundTrip() throws {
        let original = BeatDetectionResult(bpm: 140, confidence: 0.9, beats: [0.0, 0.428, 0.857], downbeats: [0.0], timeSignature: .fourFour, offset: 0.1)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BeatDetectionResult.self, from: data)
        XCTAssertEqual(decoded.bpm, 140)
        XCTAssertEqual(decoded.confidence, 0.9)
        XCTAssertEqual(decoded.beats.count, 3)
    }
}

// MARK: - BeatSyncedTransition Tests

final class BeatSyncedTransitionTests: XCTestCase {

    func testDefaultInit() {
        let transition = BeatSyncedTransition()
        XCTAssertEqual(transition.type, .cut)
        XCTAssertEqual(transition.durationBeats, 1)
        XCTAssertTrue(transition.startOnBeat)
        XCTAssertTrue(transition.endOnBeat)
        XCTAssertFalse(transition.syncToDownbeat)
        XCTAssertEqual(transition.intensity, 1.0)
    }

    func testTransitionTypeAllCases() {
        let cases = BeatSyncedTransition.TransitionType.allCases
        XCTAssertTrue(cases.contains(.cut))
        XCTAssertTrue(cases.contains(.crossfade))
        XCTAssertTrue(cases.contains(.glitch))
        XCTAssertTrue(cases.contains(.beatFlash))
        XCTAssertGreaterThanOrEqual(cases.count, 14)
    }

    func testCodableRoundTrip() throws {
        let transition = BeatSyncedTransition(type: .crossfade, durationBeats: 2, intensity: 0.8)
        let data = try JSONEncoder().encode(transition)
        let decoded = try JSONDecoder().decode(BeatSyncedTransition.self, from: data)
        XCTAssertEqual(decoded.type, .crossfade)
        XCTAssertEqual(decoded.durationBeats, 2)
    }
}

// MARK: - BeatSyncedEffect Tests

final class BeatSyncedEffectTests: XCTestCase {

    func testDefaultInit() {
        let effect = BeatSyncedEffect()
        XCTAssertEqual(effect.type, .pulse)
        XCTAssertEqual(effect.triggerOn, .everyBeat)
        XCTAssertEqual(effect.intensity, 1.0)
        XCTAssertEqual(effect.decay, 0.5)
        XCTAssertEqual(effect.phase, 0)
    }

    func testEffectTypeAllCases() {
        let cases = BeatSyncedEffect.EffectType.allCases
        XCTAssertTrue(cases.contains(.flash))
        XCTAssertTrue(cases.contains(.pulse))
        XCTAssertTrue(cases.contains(.glitch))
        XCTAssertTrue(cases.contains(.heartbeatPulse))
        XCTAssertGreaterThanOrEqual(cases.count, 20)
    }

    func testTriggerModeAllCases() {
        let cases = BeatSyncedEffect.TriggerMode.allCases
        XCTAssertTrue(cases.contains(.everyBeat))
        XCTAssertTrue(cases.contains(.everyDownbeat))
        XCTAssertTrue(cases.contains(.everyBar))
        XCTAssertTrue(cases.contains(.continuous))
        XCTAssertTrue(cases.contains(.random))
    }

    func testCodableRoundTrip() throws {
        let effect = BeatSyncedEffect(type: .flash, triggerOn: .everyDownbeat, intensity: 0.7, decay: 0.3, phase: 0.25)
        let data = try JSONEncoder().encode(effect)
        let decoded = try JSONDecoder().decode(BeatSyncedEffect.self, from: data)
        XCTAssertEqual(decoded.type, .flash)
        XCTAssertEqual(decoded.triggerOn, .everyDownbeat)
        XCTAssertEqual(decoded.phase, 0.25)
    }
}

// MARK: - TempoChange Tests

final class TempoChangeTests: XCTestCase {

    func testDefaultInit() {
        let tc = TempoChange()
        XCTAssertEqual(tc.bpm, 120)
        XCTAssertEqual(tc.curve, .instant)
    }

    func testTempoChangeCurveAllCases() {
        let cases = TempoChange.TempoChangeCurve.allCases
        XCTAssertTrue(cases.contains(.instant))
        XCTAssertTrue(cases.contains(.linear))
        XCTAssertTrue(cases.contains(.exponential))
        XCTAssertTrue(cases.contains(.sCurve))
    }

    func testCodableRoundTrip() throws {
        let tc = TempoChange(bpm: 140, curve: .linear)
        let data = try JSONEncoder().encode(tc)
        let decoded = try JSONDecoder().decode(TempoChange.self, from: data)
        XCTAssertEqual(decoded.bpm, 140)
        XCTAssertEqual(decoded.curve, .linear)
    }
}

// MARK: - CurvePoint Tests

final class CurvePointTests: XCTestCase {

    func testClampingInput() {
        let point = CurvePoint(input: -0.5, output: 1.5)
        XCTAssertEqual(point.input, 0.0)
        XCTAssertEqual(point.output, 1.0)
    }

    func testNormalValues() {
        let point = CurvePoint(input: 0.5, output: 0.7)
        XCTAssertEqual(point.input, 0.5)
        XCTAssertEqual(point.output, 0.7)
    }

    func testEquality() {
        let a = CurvePoint(input: 0.3, output: 0.6)
        let b = CurvePoint(input: 0.3, output: 0.6)
        XCTAssertEqual(a, b)
    }

    func testCodableRoundTrip() throws {
        let original = CurvePoint(input: 0.25, output: 0.75)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CurvePoint.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - ColorRange Tests

final class ColorRangeTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(ColorRange.allCases.count, 8)
    }

    func testCenterHueValues() {
        XCTAssertEqual(ColorRange.red.centerHue, 0)
        XCTAssertEqual(ColorRange.green.centerHue, 120)
        XCTAssertEqual(ColorRange.blue.centerHue, 240)
        XCTAssertEqual(ColorRange.cyan.centerHue, 180)
    }

    func testHueWidth() {
        for range in ColorRange.allCases {
            XCTAssertEqual(range.hueWidth, 22.5)
        }
    }

    func testCodableRoundTrip() throws {
        let original = ColorRange.magenta
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ColorRange.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - HSLValues Tests

final class HSLValuesTests: XCTestCase {

    func testDefaultIsNeutral() {
        let hsl = HSLValues()
        XCTAssertTrue(hsl.isNeutral)
    }

    func testNonNeutral() {
        let hsl = HSLValues(hueShift: 10)
        XCTAssertFalse(hsl.isNeutral)
    }

    func testClamping() {
        let hsl = HSLValues(hueShift: 200, saturation: -5, luminance: 3)
        XCTAssertEqual(hsl.hueShift, 180)
        XCTAssertEqual(hsl.saturation, -1)
        XCTAssertEqual(hsl.luminance, 1)
    }

    func testCodableRoundTrip() throws {
        let original = HSLValues(hueShift: 45, saturation: 0.5, luminance: -0.3)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HSLValues.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - TransitionEasing Tests

final class TransitionEasingTests: XCTestCase {

    func testLinearEasingBoundaries() {
        XCTAssertEqual(TransitionEasing.linear.evaluate(0), 0, accuracy: 0.001)
        XCTAssertEqual(TransitionEasing.linear.evaluate(1), 1, accuracy: 0.001)
        XCTAssertEqual(TransitionEasing.linear.evaluate(0.5), 0.5, accuracy: 0.001)
    }

    func testEaseInStartsSlow() {
        let earlyValue = TransitionEasing.easeIn.evaluate(0.25)
        // easeIn = t*t, so 0.25*0.25 = 0.0625
        XCTAssertEqual(earlyValue, 0.0625, accuracy: 0.001)
    }

    func testEaseOutEndsSlow() {
        let value = TransitionEasing.easeOut.evaluate(0.5)
        // easeOut = t * (2-t) = 0.5 * 1.5 = 0.75
        XCTAssertEqual(value, 0.75, accuracy: 0.001)
    }

    func testAllEasingsBoundary0And1() {
        for easing in TransitionEasing.allCases {
            XCTAssertEqual(easing.evaluate(0), 0, accuracy: 0.01, "\(easing.rawValue) at t=0")
            XCTAssertEqual(easing.evaluate(1), 1, accuracy: 0.01, "\(easing.rawValue) at t=1")
        }
    }

    func testClampsBeyondRange() {
        // Negative and >1 inputs should be clamped
        XCTAssertEqual(TransitionEasing.linear.evaluate(-1), 0, accuracy: 0.001)
        XCTAssertEqual(TransitionEasing.linear.evaluate(2), 1, accuracy: 0.001)
    }
}

// MARK: - GradeTransitionType Tests

final class GradeTransitionTypeTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertGreaterThanOrEqual(GradeTransitionType.allCases.count, 20)
    }

    func testDisplayNames() {
        XCTAssertEqual(GradeTransitionType.cut.displayName, "Cut")
        XCTAssertEqual(GradeTransitionType.crossDissolve.displayName, "Cross Dissolve")
        XCTAssertEqual(GradeTransitionType.dipToBlack.displayName, "Dip to Black")
    }

    func testRequiresTwoSources() {
        XCTAssertFalse(GradeTransitionType.cut.requiresTwoSources)
        XCTAssertTrue(GradeTransitionType.crossDissolve.requiresTwoSources)
        XCTAssertTrue(GradeTransitionType.wipeLeft.requiresTwoSources)
    }

    func testDefaultDurationCutIsZero() {
        XCTAssertEqual(GradeTransitionType.cut.defaultDuration, 0)
    }

    func testDefaultDurationPositiveForNonCut() {
        for transition in GradeTransitionType.allCases where transition != .cut {
            XCTAssertGreaterThan(transition.defaultDuration, 0,
                                 "\(transition.rawValue) should have positive default duration")
        }
    }

    func testCodableRoundTrip() throws {
        let original = GradeTransitionType.crossDissolve
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GradeTransitionType.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - ProTransition Tests

final class ProTransitionTests: XCTestCase {

    func testDefaultInit() {
        let transition = ProTransition()
        XCTAssertEqual(transition.type, .crossDissolve)
        XCTAssertEqual(transition.easing, .easeInOut)
        XCTAssertTrue(transition.parameters.isEmpty)
        XCTAssertEqual(transition.duration, GradeTransitionType.crossDissolve.defaultDuration)
    }

    func testCustomDurationOverridesDefault() {
        let transition = ProTransition(type: .crossDissolve, duration: 2.5)
        XCTAssertEqual(transition.duration, 2.5)
    }

    func testMixDelegatesToEasing() {
        let transition = ProTransition(type: .cut, easing: .linear)
        XCTAssertEqual(transition.mix(at: 0.5), 0.5, accuracy: 0.001)
    }

    func testCodableRoundTrip() throws {
        let original = ProTransition(type: .wipeLeft, duration: 1.5, easing: .easeIn, parameters: ["angle": 45.0])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ProTransition.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - ScopeType Tests

final class ScopeTypeTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(ScopeType.allCases.count, 5)
    }

    func testDisplayNames() {
        XCTAssertEqual(ScopeType.histogram.displayName, "Histogram")
        XCTAssertEqual(ScopeType.waveform.displayName, "Waveform")
        XCTAssertEqual(ScopeType.vectorscope.displayName, "Vectorscope")
        XCTAssertEqual(ScopeType.rgbParade.displayName, "RGB Parade")
        XCTAssertEqual(ScopeType.falseColor.displayName, "False Color")
    }

    func testCodableRoundTrip() throws {
        let original = ScopeType.vectorscope
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ScopeType.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - WipeDirection Tests

final class WipeDirectionTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(WipeDirection.allCases.count, 5)
    }

    func testCodableRoundTrip() throws {
        let original = WipeDirection.diagonal
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WipeDirection.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - ColorWheels Tests

final class ColorWheelsTests: XCTestCase {

    func testNeutralInit() {
        let wheels = ColorWheels()
        XCTAssertTrue(wheels.isNeutral)
    }

    func testNonNeutralWhenModified() {
        let wheels = ColorWheels(exposure: 1.0)
        XCTAssertFalse(wheels.isNeutral)
    }

    func testNeutralStatic() {
        let neutral = ColorWheels.neutral
        XCTAssertTrue(neutral.isNeutral)
    }

    func testClampingExposure() {
        let wheels = ColorWheels(exposure: 10)
        XCTAssertEqual(wheels.exposure, 5)
    }

    func testClampingSaturation() {
        let wheels = ColorWheels(saturation: 5)
        XCTAssertEqual(wheels.saturation, 2)
    }

    func testClampingTemperature() {
        let wheels = ColorWheels(temperature: -200)
        XCTAssertEqual(wheels.temperature, -100)
    }

    func testDefaultSaturationIsOne() {
        let wheels = ColorWheels()
        XCTAssertEqual(wheels.saturation, 1)
    }

    func testCodableRoundTrip() throws {
        let original = ColorWheels(exposure: 1.5, contrast: 20, saturation: 1.2)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ColorWheels.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - CurvesEditor Tests

final class CurvesEditorTests: XCTestCase {

    func testDefaultIsNeutral() {
        let editor = CurvesEditor()
        XCTAssertTrue(editor.isNeutral)
    }

    func testIdentityCurve() {
        let identity = CurvesEditor.identityCurve
        XCTAssertEqual(identity.count, 2)
        XCTAssertEqual(identity[0].input, 0)
        XCTAssertEqual(identity[0].output, 0)
        XCTAssertEqual(identity[1].input, 1)
        XCTAssertEqual(identity[1].output, 1)
    }

    func testCustomCurveIsNotNeutral() {
        let editor = CurvesEditor(masterCurve: [
            CurvePoint(input: 0, output: 0),
            CurvePoint(input: 0.5, output: 0.7),
            CurvePoint(input: 1, output: 1)
        ])
        XCTAssertFalse(editor.isNeutral)
    }
}

// MARK: - EditMode Tests

final class VideoEditModeTests: XCTestCase {

    func testAllCases() {
        let cases = VideoEditingEngine.EditMode.allCases
        XCTAssertTrue(cases.contains(.select))
        XCTAssertTrue(cases.contains(.ripple))
        XCTAssertTrue(cases.contains(.roll))
        XCTAssertTrue(cases.contains(.slip))
        XCTAssertTrue(cases.contains(.slide))
        XCTAssertTrue(cases.contains(.trim))
        XCTAssertTrue(cases.contains(.razor))
        XCTAssertEqual(cases.count, 7)
    }

    func testDescriptions() {
        for mode in VideoEditingEngine.EditMode.allCases {
            XCTAssertFalse(mode.description.isEmpty, "\(mode.rawValue) should have a description")
        }
    }
}

// MARK: - MarkerColor Tests

final class MarkerColorTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(MarkerColor.allCases.count, 6)
    }

    func testContainsExpectedColors() {
        XCTAssertTrue(MarkerColor.allCases.contains(.red))
        XCTAssertTrue(MarkerColor.allCases.contains(.green))
        XCTAssertTrue(MarkerColor.allCases.contains(.blue))
    }
}

// MARK: - KeyframeProperty Tests

final class KeyframePropertyTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(KeyframeProperty.opacity.rawValue, "Opacity")
        XCTAssertEqual(KeyframeProperty.scale.rawValue, "Scale")
        XCTAssertEqual(KeyframeProperty.rotation.rawValue, "Rotation")
        XCTAssertEqual(KeyframeProperty.volume.rawValue, "Volume")
    }
}

// MARK: - TextPreset Tests

final class TextPresetTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(TextPreset.allCases.count, 7)
    }

    func testTitlePresetCreatesOverlay() {
        let time = CMTime(seconds: 5, preferredTimescale: 600)
        let duration = CMTime(seconds: 3, preferredTimescale: 600)
        let overlay = TextPreset.title.createOverlay(text: "Hello", at: time, duration: duration)
        XCTAssertEqual(overlay.text, "Hello")
        XCTAssertEqual(overlay.startTime, time)
        XCTAssertEqual(overlay.duration, duration)
        XCTAssertEqual(overlay.alignment, .center)
    }

    func testLowerThirdPresetLeftAligned() {
        let time = CMTime.zero
        let duration = CMTime(seconds: 5, preferredTimescale: 600)
        let overlay = TextPreset.lowerThird.createOverlay(text: "Name", at: time, duration: duration)
        XCTAssertEqual(overlay.alignment, .left)
        XCTAssertNotNil(overlay.backgroundColor)
    }

    func testWatermarkPresetLongDuration() {
        let overlay = TextPreset.watermark.createOverlay(text: "Brand", at: .zero, duration: .zero)
        // Watermark overrides duration to 86400 seconds
        XCTAssertEqual(overlay.duration.seconds, 86400, accuracy: 1)
    }
}

// MARK: - VideoEditingError Tests

final class VideoEditingErrorTests: XCTestCase {

    func testErrorDescriptions() {
        XCTAssertNotNil(VideoEditingError.compositionCreationFailed.errorDescription)
        XCTAssertNotNil(VideoEditingError.clipNotFound.errorDescription)
        XCTAssertNotNil(VideoEditingError.invalidTimeRange.errorDescription)
    }
}

// MARK: - ProcessingExportManager.ExportFormat Tests

final class ProcessingExportFormatTests: XCTestCase {

    func testAllCases() {
        let cases = ProcessingExportManager.ExportFormat.allCases
        XCTAssertTrue(cases.contains(.h264))
        XCTAssertTrue(cases.contains(.h265))
        XCTAssertTrue(cases.contains(.prores))
        XCTAssertTrue(cases.contains(.av1))
        XCTAssertTrue(cases.contains(.gif))
    }
}

// MARK: - ProcessingExportManager.ExportPreset Tests

final class ProcessingExportPresetTests: XCTestCase {

    func testAllCases() {
        let cases = ProcessingExportManager.ExportPreset.allCases
        XCTAssertTrue(cases.contains(.web))
        XCTAssertTrue(cases.contains(.hd))
        XCTAssertTrue(cases.contains(.uhd))
        XCTAssertTrue(cases.contains(.youtube))
        XCTAssertTrue(cases.contains(.instagram))
        XCTAssertGreaterThanOrEqual(cases.count, 10)
    }
}

// MARK: - ChromaKeyPreset Tests

#if canImport(Metal)
final class ChromaKeyPresetTests: XCTestCase {

    func testPortraitPresetValues() {
        let preset = ChromaKeyPreset.portrait
        XCTAssertEqual(preset.name, "Portrait")
        XCTAssertEqual(preset.tolerance, 0.25)
        XCTAssertEqual(preset.edgeSoftness, 0.7)
        XCTAssertEqual(preset.despillStrength, 0.5)
        XCTAssertEqual(preset.lightWrapAmount, 0.3)
    }

    func testAllPresetsCount() {
        XCTAssertEqual(ChromaKeyPreset.allPresets.count, 6)
    }

    func testAllPresetsHaveUniqueNames() {
        let names = ChromaKeyPreset.allPresets.map { $0.name }
        XCTAssertEqual(Set(names).count, names.count)
    }

    func testPresetValuesInRange() {
        for preset in ChromaKeyPreset.allPresets {
            XCTAssertGreaterThanOrEqual(preset.tolerance, 0)
            XCTAssertLessThanOrEqual(preset.tolerance, 1)
            XCTAssertGreaterThanOrEqual(preset.edgeSoftness, 0)
            XCTAssertLessThanOrEqual(preset.edgeSoftness, 1)
            XCTAssertGreaterThanOrEqual(preset.despillStrength, 0)
            XCTAssertLessThanOrEqual(preset.despillStrength, 1)
            XCTAssertGreaterThanOrEqual(preset.lightWrapAmount, 0)
            XCTAssertLessThanOrEqual(preset.lightWrapAmount, 1)
        }
    }
}

// MARK: - ChromaKeyError Tests

final class ChromaKeyErrorTests: XCTestCase {

    func testErrorDescriptions() {
        XCTAssertNotNil(ChromaKeyError.engineNotActive.errorDescription)
        XCTAssertNotNil(ChromaKeyError.commandBufferCreationFailed.errorDescription)
        XCTAssertNotNil(ChromaKeyError.encoderCreationFailed.errorDescription)
        XCTAssertTrue(ChromaKeyError.shaderCompilationFailed("test").errorDescription?.contains("test") == true)
        XCTAssertTrue(ChromaKeyError.textureCreationFailed("matte").errorDescription?.contains("matte") == true)
        XCTAssertTrue(ChromaKeyError.pipelineStateNotFound("pass1").errorDescription?.contains("pass1") == true)
    }
}

// MARK: - ChromaKey ShaderPass Tests

final class ChromaKeyShaderPassTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(ChromaKeyEngine.ShaderPass.allCases.count, 6)
    }

    func testRawValues() {
        XCTAssertEqual(ChromaKeyEngine.ShaderPass.colorKey.rawValue, "chromaKeyColorExtraction")
        XCTAssertEqual(ChromaKeyEngine.ShaderPass.edgeDetection.rawValue, "chromaKeyEdgeDetection")
        XCTAssertEqual(ChromaKeyEngine.ShaderPass.composite.rawValue, "chromaKeyComposite")
    }
}

// MARK: - ChromaKey KeyColor Tests

final class ChromaKeyKeyColorTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(ChromaKeyEngine.KeyColor.allCases.count, 3)
    }

    func testGreenRGBValue() {
        let green = ChromaKeyEngine.KeyColor.green
        XCTAssertEqual(green.rgbValue.x, 0)
        XCTAssertEqual(green.rgbValue.y, 1)
        XCTAssertEqual(green.rgbValue.z, 0)
    }

    func testBlueRGBValue() {
        let blue = ChromaKeyEngine.KeyColor.blue
        XCTAssertEqual(blue.rgbValue.x, 0)
        XCTAssertEqual(blue.rgbValue.y, 0)
        XCTAssertEqual(blue.rgbValue.z, 1)
    }

    func testGreenHSVHue() {
        let green = ChromaKeyEngine.KeyColor.green
        // Hue 120 degrees normalized = 120/360
        XCTAssertEqual(green.hsvValue.x, 120.0 / 360.0, accuracy: 0.001)
    }

    func testBlueHSVHue() {
        let blue = ChromaKeyEngine.KeyColor.blue
        XCTAssertEqual(blue.hsvValue.x, 240.0 / 360.0, accuracy: 0.001)
    }
}

// MARK: - ChromaKey PreviewMode Tests

final class ChromaKeyPreviewModeTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(ChromaKeyEngine.PreviewMode.allCases.count, 5)
    }

    func testDescriptions() {
        for mode in ChromaKeyEngine.PreviewMode.allCases {
            XCTAssertFalse(mode.description.isEmpty, "\(mode.rawValue) should have a description")
        }
    }

    func testRawValues() {
        XCTAssertEqual(ChromaKeyEngine.PreviewMode.normal.rawValue, "Normal")
        XCTAssertEqual(ChromaKeyEngine.PreviewMode.keyOnly.rawValue, "Key Only")
        XCTAssertEqual(ChromaKeyEngine.PreviewMode.splitScreen.rawValue, "Split")
    }
}
#endif

// MARK: - MultiCamError Tests

#if os(iOS)
final class MultiCamErrorTests: XCTestCase {

    func testErrorDescriptions() {
        XCTAssertNotNil(MultiCamError.notSupported.errorDescription)
        XCTAssertNotNil(MultiCamError.permissionDenied.errorDescription)
        XCTAssertNotNil(MultiCamError.recordingFailed.errorDescription)
    }
}

// MARK: - StabilizationError Tests

final class StabilizationErrorTests: XCTestCase {

    func testErrorDescriptions() {
        XCTAssertNotNil(StabilizationError.noVideoTrack.errorDescription)
        XCTAssertNotNil(StabilizationError.processingFailed.errorDescription)
    }
}

// MARK: - StabilizationMode Tests

final class VideoStabilizationModeTests: XCTestCase {

    func testAllCases() {
        let cases = VideoStabilizer.StabilizationMode.allCases
        XCTAssertTrue(cases.contains(.off))
        XCTAssertTrue(cases.contains(.standard))
        XCTAssertTrue(cases.contains(.cinematic))
        XCTAssertTrue(cases.contains(.locked))
        XCTAssertEqual(cases.count, 4)
    }

    func testDescriptions() {
        for mode in VideoStabilizer.StabilizationMode.allCases {
            XCTAssertFalse(mode.description.isEmpty, "\(mode.rawValue) should have a description")
        }
    }
}

// MARK: - SyncStatus Tests

final class MultiCamSyncStatusTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(MultiCamManager.SyncStatus.notSynced.rawValue, "Not Synced")
        XCTAssertEqual(MultiCamManager.SyncStatus.syncing.rawValue, "Syncing")
        XCTAssertEqual(MultiCamManager.SyncStatus.synced.rawValue, "Synced")
        XCTAssertEqual(MultiCamManager.SyncStatus.syncFailed.rawValue, "Sync Failed")
    }
}
#endif

// MARK: - CameraAnalyzer ModulationMode Tests

final class CameraModulationModeTests: XCTestCase {

    func testAllCases() {
        let cases = CameraAnalyzer.ModulationMode.allCases
        XCTAssertEqual(cases.count, 3)
        XCTAssertTrue(cases.contains(.brightness))
        XCTAssertTrue(cases.contains(.color))
        XCTAssertTrue(cases.contains(.motion))
    }

    func testRawValues() {
        XCTAssertEqual(CameraAnalyzer.ModulationMode.brightness.rawValue, "Brightness")
        XCTAssertEqual(CameraAnalyzer.ModulationMode.color.rawValue, "Color")
        XCTAssertEqual(CameraAnalyzer.ModulationMode.motion.rawValue, "Motion")
    }
}

// MARK: - ColorGradeEffect Tests

final class ColorGradeEffectTests: XCTestCase {

    func testDefaultValues() {
        let grade = ColorGradeEffect()
        XCTAssertEqual(grade.exposure, 0.0)
        XCTAssertEqual(grade.contrast, 1.0)
        XCTAssertEqual(grade.saturation, 1.0)
        XCTAssertEqual(grade.temperature, 0.0)
        XCTAssertEqual(grade.tint, 0.0)
    }
}

// MARK: - CameraManager Enums Tests

#if os(iOS) || os(macOS)
final class CameraManagerEnumTests: XCTestCase {

    func testCameraPositionAllCases() {
        let cases = CameraManager.CameraPosition.allCases
        XCTAssertTrue(cases.contains(.front))
        XCTAssertTrue(cases.contains(.back))
        XCTAssertTrue(cases.contains(.ultraWide))
        XCTAssertTrue(cases.contains(.telephoto))
        XCTAssertEqual(cases.count, 5)
    }

    func testCameraPositionRawValues() {
        XCTAssertEqual(CameraManager.CameraPosition.front.rawValue, "Front")
        XCTAssertEqual(CameraManager.CameraPosition.back.rawValue, "Back")
        XCTAssertEqual(CameraManager.CameraPosition.ultraWide.rawValue, "Ultra Wide")
    }

    func testResolutionAllCases() {
        let cases = CameraManager.Resolution.allCases
        XCTAssertEqual(cases.count, 3)
        XCTAssertTrue(cases.contains(.hd1280x720))
        XCTAssertTrue(cases.contains(.hd1920x1080))
        XCTAssertTrue(cases.contains(.uhd3840x2160))
    }

    func testResolutionSize() {
        XCTAssertEqual(CameraManager.Resolution.hd1920x1080.size, CGSize(width: 1920, height: 1080))
        XCTAssertEqual(CameraManager.Resolution.hd1280x720.size, CGSize(width: 1280, height: 720))
    }

    func testExposureModeAllCases() {
        let cases = CameraManager.ExposureMode.allCases
        XCTAssertTrue(cases.contains(.auto))
        XCTAssertTrue(cases.contains(.locked))
        XCTAssertTrue(cases.contains(.custom))
    }

    func testFocusModeAllCases() {
        let cases = CameraManager.FocusMode.allCases
        XCTAssertTrue(cases.contains(.auto))
        XCTAssertTrue(cases.contains(.continuousAuto))
        XCTAssertTrue(cases.contains(.locked))
        XCTAssertTrue(cases.contains(.manual))
    }

    func testWhiteBalanceModeAllCases() {
        let cases = CameraManager.WhiteBalanceMode.allCases
        XCTAssertEqual(cases.count, 3)
    }

    func testTorchModeAllCases() {
        let cases = CameraManager.TorchMode.allCases
        XCTAssertEqual(cases.count, 3)
    }

    func testStabilizationModeAllCases() {
        let cases = CameraManager.StabilizationMode.allCases
        XCTAssertEqual(cases.count, 5)
        XCTAssertTrue(cases.contains(.cinematic))
        XCTAssertTrue(cases.contains(.cinematicExtended))
    }

    func testPhotoFormatAllCases() {
        let cases = CameraManager.PhotoFormat.allCases
        XCTAssertEqual(cases.count, 3)
        XCTAssertTrue(cases.contains(.heif))
        XCTAssertTrue(cases.contains(.jpeg))
        XCTAssertTrue(cases.contains(.raw))
    }
}
#endif
