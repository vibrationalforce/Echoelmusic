// VideoPipelineTests.swift
// Echoelmusic - Video Pipeline Integration Tests
// Phase 10000 Ralph Wiggum Lambda Loop Mode
// Created 2026-01-16

import XCTest
@testable import Echoelmusic

#if canImport(Metal)
import Metal
#endif

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
final class VideoPipelineTests: XCTestCase {

    // MARK: - VideoPipelineCoordinator Tests

    @MainActor
    func testVideoPipelineCoordinatorInitialization() async {
        let coordinator = VideoPipelineCoordinator()

        XCTAssertNotNil(coordinator)
        XCTAssertFalse(coordinator.isCapturing)
        XCTAssertFalse(coordinator.isProcessing)
        XCTAssertFalse(coordinator.isStreaming)
        XCTAssertFalse(coordinator.pipelineActive)
    }

    @MainActor
    func testVideoPipelineStatus() async {
        let coordinator = VideoPipelineCoordinator()

        let status = coordinator?.pipelineStatus

        XCTAssertNotNil(status)
        XCTAssertFalse(status?.cameraActive ?? true)
        XCTAssertFalse(status?.streamingActive ?? true)
        XCTAssertEqual(status?.droppedFrames ?? -1, 0)
    }

    @MainActor
    func testProcessingEnabled() async {
        let coordinator = VideoPipelineCoordinator()

        // Set processing enabled
        coordinator?.setProcessingEnabled(true)
        // No crash means success

        coordinator?.setProcessingEnabled(false)
        // No crash means success
    }

    // MARK: - StreamEngine Frame Injection Tests

    @MainActor
    func testStreamEngineFrameSourceMode() async {
        let streamEngine = StreamEngine()

        // Default should be internal scene
        XCTAssertEqual(streamEngine.frameSourceMode, .internalScene)

        // Switch to external camera
        streamEngine.setFrameSourceMode(.externalCamera)
        XCTAssertEqual(streamEngine.frameSourceMode, .externalCamera)

        // Switch back
        streamEngine.setFrameSourceMode(.internalScene)
        XCTAssertEqual(streamEngine.frameSourceMode, .internalScene)
    }

    @MainActor
    func testStreamEngineInjectFrameInInternalMode() async {
        let streamEngine = StreamEngine()

        // In internal mode, injected frames should be ignored
        streamEngine.setFrameSourceMode(.internalScene)

        // Create a dummy texture
        guard let device = MTLCreateSystemDefaultDevice(),
              let texture = createTestTexture(device: device) else {
            // Skip test on platforms without Metal
            return
        }

        // This should not crash, frame should be ignored
        streamEngine.injectFrame(texture: texture, time: .zero)
    }

    @MainActor
    func testStreamEngineInjectFrameInExternalMode() async {
        let streamEngine = StreamEngine()

        // In external mode, injected frames should be accepted
        streamEngine.setFrameSourceMode(.externalCamera)

        guard let device = MTLCreateSystemDefaultDevice(),
              let texture = createTestTexture(device: device) else {
            return
        }

        // This should accept the frame
        streamEngine.injectFrame(texture: texture, time: CMTime(value: 1, timescale: 60))
    }

    // MARK: - VideoProcessingEngine Tests

    @MainActor
    func testVideoProcessingEngineAddEffect() async {
        let engine = VideoProcessingEngine()

        // Add various effects
        engine.addEffect(.blur)
        engine.addEffect(.quantumWave)
        engine.addEffect(.heartbeatPulse)

        // Remove effect
        engine.removeEffect(.blur)
    }

    @MainActor
    func testVideoProcessingEngineBioParameters() async {
        let engine = VideoProcessingEngine()

        // Update bio parameters
        engine.updateBioParameters(coherence: 0.8, heartRate: 72.0, breathPhase: 0.5)
        engine.updateBioParameters(coherence: 0.0, heartRate: 60.0, breathPhase: 0.0)
        engine.updateBioParameters(coherence: 1.0, heartRate: 120.0, breathPhase: 1.0)
    }

    // MARK: - CameraManager Tests

    @MainActor
    func testCameraManagerResolutions() {
        XCTAssertEqual(CameraManager.Resolution.hd1280x720.rawValue, "720p")
        XCTAssertEqual(CameraManager.Resolution.hd1920x1080.rawValue, "1080p")
        XCTAssertEqual(CameraManager.Resolution.uhd3840x2160.rawValue, "4K")
    }

    @MainActor
    func testCameraManagerResolutionSizes() {
        XCTAssertEqual(CameraManager.Resolution.hd1280x720.size, CGSize(width: 1280, height: 720))
        XCTAssertEqual(CameraManager.Resolution.hd1920x1080.size, CGSize(width: 1920, height: 1080))
        XCTAssertEqual(CameraManager.Resolution.uhd3840x2160.size, CGSize(width: 3840, height: 2160))
    }

    @MainActor
    func testCameraManagerPositions() {
        XCTAssertEqual(CameraManager.CameraPosition.front.rawValue, "Front")
        XCTAssertEqual(CameraManager.CameraPosition.back.rawValue, "Back")
        XCTAssertEqual(CameraManager.CameraPosition.ultraWide.rawValue, "Ultra Wide")
    }

    // MARK: - VideoResolution Tests

    func testVideoResolutionDimensions() {
        XCTAssertEqual(VideoResolution.sd480p.dimensions.width, 854)
        XCTAssertEqual(VideoResolution.fullHD1080p.dimensions.width, 1920)
        XCTAssertEqual(VideoResolution.uhd4k.dimensions.width, 3840)
        XCTAssertEqual(VideoResolution.quantum16k.dimensions.width, 15360)
    }

    func testVideoResolutionBitrates() {
        XCTAssertEqual(VideoResolution.sd480p.bitrate, 2_500_000)
        XCTAssertEqual(VideoResolution.fullHD1080p.bitrate, 10_000_000)
        XCTAssertEqual(VideoResolution.uhd4k.bitrate, 50_000_000)
    }

    // MARK: - VideoFrameRate Tests

    func testVideoFrameRates() {
        XCTAssertEqual(VideoFrameRate.cinema24.rawValue, 24.0)
        XCTAssertEqual(VideoFrameRate.smooth60.rawValue, 60.0)
        XCTAssertEqual(VideoFrameRate.proMotion120.rawValue, 120.0)
        XCTAssertEqual(VideoFrameRate.lightSpeed1000.rawValue, 1000.0)
    }

    // MARK: - VideoEffectType Tests

    func testVideoEffectTypes() {
        XCTAssertEqual(VideoEffectType.blur.ciFilterName, "CIGaussianBlur")
        XCTAssertEqual(VideoEffectType.comic.ciFilterName, "CIComicEffect")
        XCTAssertNil(VideoEffectType.quantumWave.ciFilterName)
    }

    func testVideoEffectRequiresMetal() {
        XCTAssertTrue(VideoEffectType.quantumWave.requiresMetalShader)
        XCTAssertTrue(VideoEffectType.coherenceField.requiresMetalShader)
        XCTAssertTrue(VideoEffectType.heartbeatPulse.requiresMetalShader)
        XCTAssertFalse(VideoEffectType.blur.requiresMetalShader)
    }

    // MARK: - VideoPipelineError Tests

    func testVideoPipelineErrors() {
        XCTAssertEqual(VideoPipelineError.cameraInitFailed.errorDescription, "Failed to initialize camera")
        XCTAssertEqual(VideoPipelineError.cameraNotSetUp.errorDescription, "Camera not set up")
        XCTAssertEqual(VideoPipelineError.streamNotSetUp.errorDescription, "Stream engine not set up")
    }

    // MARK: - Helper Methods

    private func createTestTexture(device: MTLDevice) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: 320,
            height: 240,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        return device.makeTexture(descriptor: descriptor)
    }
}
