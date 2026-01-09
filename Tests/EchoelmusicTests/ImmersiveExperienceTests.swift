import XCTest
@testable import Echoelmusic

#if os(visionOS)

/// Tests for ImmersiveExperience, ImmersiveExperienceManager, and ImmersiveVideoCapture
final class ImmersiveExperienceTests: XCTestCase {

    // MARK: - ImmersiveMode Tests

    func testImmersiveModeRawValues() {
        XCTAssertEqual(ImmersiveMode.passthrough.rawValue, "Passthrough")
        XCTAssertEqual(ImmersiveMode.mixed.rawValue, "Mixed Reality")
        XCTAssertEqual(ImmersiveMode.full.rawValue, "Full Immersion")
        XCTAssertEqual(ImmersiveMode.spatial.rawValue, "Spatial Window")
    }

    func testImmersiveModeAllCases() {
        let modes = ImmersiveMode.allCases
        XCTAssertEqual(modes.count, 4)
    }

    func testImmersiveModeSystemImage() {
        XCTAssertEqual(ImmersiveMode.passthrough.systemImage, "eye")
        XCTAssertEqual(ImmersiveMode.mixed.systemImage, "cube.transparent")
        XCTAssertEqual(ImmersiveMode.full.systemImage, "visionpro")
        XCTAssertEqual(ImmersiveMode.spatial.systemImage, "square.3.layers.3d")
    }

    func testImmersiveModeDescription() {
        XCTAssertFalse(ImmersiveMode.passthrough.description.isEmpty)
        XCTAssertFalse(ImmersiveMode.mixed.description.isEmpty)
        XCTAssertFalse(ImmersiveMode.full.description.isEmpty)
        XCTAssertFalse(ImmersiveMode.spatial.description.isEmpty)
    }

    // MARK: - ExperienceType Tests

    func testExperienceTypeRawValues() {
        XCTAssertEqual(ImmersiveExperience.ExperienceType.meditation.rawValue, "Meditation")
        XCTAssertEqual(ImmersiveExperience.ExperienceType.focus.rawValue, "Focus")
        XCTAssertEqual(ImmersiveExperience.ExperienceType.creativity.rawValue, "Creativity")
        XCTAssertEqual(ImmersiveExperience.ExperienceType.healing.rawValue, "Healing")
        XCTAssertEqual(ImmersiveExperience.ExperienceType.performance.rawValue, "Performance")
        XCTAssertEqual(ImmersiveExperience.ExperienceType.visualization.rawValue, "Visualization")
    }

    func testExperienceTypeAllCases() {
        let types = ImmersiveExperience.ExperienceType.allCases
        XCTAssertEqual(types.count, 6)
    }

    // MARK: - EnvironmentType Tests

    func testEnvironmentTypeRawValues() {
        XCTAssertEqual(ImmersiveExperience.EnvironmentType.cosmos.rawValue, "Cosmos")
        XCTAssertEqual(ImmersiveExperience.EnvironmentType.nature.rawValue, "Nature")
        XCTAssertEqual(ImmersiveExperience.EnvironmentType.ocean.rawValue, "Ocean")
        XCTAssertEqual(ImmersiveExperience.EnvironmentType.sacred.rawValue, "Sacred")
        XCTAssertEqual(ImmersiveExperience.EnvironmentType.abstract.rawValue, "Abstract")
        XCTAssertEqual(ImmersiveExperience.EnvironmentType.void.rawValue, "Void")
        XCTAssertEqual(ImmersiveExperience.EnvironmentType.aurora.rawValue, "Aurora")
        XCTAssertEqual(ImmersiveExperience.EnvironmentType.quantum.rawValue, "Quantum")
        XCTAssertEqual(ImmersiveExperience.EnvironmentType.forest.rawValue, "Forest")
        XCTAssertEqual(ImmersiveExperience.EnvironmentType.mountain.rawValue, "Mountain")
    }

    // MARK: - ImmersiveExperience Tests

    func testImmersiveExperienceCreation() {
        let experience = ImmersiveExperience(
            name: "Test Experience",
            type: .meditation,
            environment: .cosmos,
            bioReactivity: ImmersiveExperience.BioReactivity(
                coherenceInfluence: 0.8,
                heartRateInfluence: 0.5,
                hrvInfluence: 0.6,
                breathingSync: true
            )
        )

        XCTAssertEqual(experience.name, "Test Experience")
        XCTAssertEqual(experience.type, .meditation)
        XCTAssertEqual(experience.environment, .cosmos)
        XCTAssertNotNil(experience.id)
    }

    func testBioReactivitySettings() {
        let bio = ImmersiveExperience.BioReactivity(
            coherenceInfluence: 1.0,
            heartRateInfluence: 0.5,
            hrvInfluence: 0.7,
            breathingSync: true
        )

        XCTAssertEqual(bio.coherenceInfluence, 1.0, accuracy: 0.001)
        XCTAssertEqual(bio.heartRateInfluence, 0.5, accuracy: 0.001)
        XCTAssertEqual(bio.hrvInfluence, 0.7, accuracy: 0.001)
        XCTAssertTrue(bio.breathingSync)
    }

    func testExperiencePreview() {
        let preview = ImmersiveExperience.ExperiencePreview(
            description: "A cosmic meditation journey",
            tags: ["meditation", "stars", "peaceful"],
            intensity: .gentle
        )

        XCTAssertEqual(preview.description, "A cosmic meditation journey")
        XCTAssertEqual(preview.tags.count, 3)
        XCTAssertEqual(preview.intensity, .gentle)
    }

    func testIntensityLevels() {
        XCTAssertEqual(ImmersiveExperience.ExperiencePreview.Intensity.gentle.rawValue, "Gentle")
        XCTAssertEqual(ImmersiveExperience.ExperiencePreview.Intensity.moderate.rawValue, "Moderate")
        XCTAssertEqual(ImmersiveExperience.ExperiencePreview.Intensity.intense.rawValue, "Intense")
        XCTAssertEqual(ImmersiveExperience.ExperiencePreview.Intensity.adaptive.rawValue, "Adaptive")
    }

    // MARK: - ImmersiveExperienceLibrary Tests

    func testLibraryExperiences() {
        let experiences = ImmersiveExperienceLibrary.experiences
        XCTAssertGreaterThanOrEqual(experiences.count, 9)

        // Check for expected experiences
        let names = experiences.map { $0.name }
        XCTAssertTrue(names.contains("Cosmic Meditation"))
        XCTAssertTrue(names.contains("Sacred Geometry Flow"))
        XCTAssertTrue(names.contains("Ocean Depths"))
    }

    func testExperiencesByType() {
        let meditationExperiences = ImmersiveExperienceLibrary.experiencesByType(.meditation)
        XCTAssertGreaterThan(meditationExperiences.count, 0)

        for experience in meditationExperiences {
            XCTAssertEqual(experience.type, .meditation)
        }
    }

    func testExperienceByID() {
        let experiences = ImmersiveExperienceLibrary.experiences
        guard let first = experiences.first else {
            XCTFail("No experiences in library")
            return
        }

        let found = ImmersiveExperienceLibrary.experience(byID: first.id)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, first.name)
    }

    // MARK: - ImmersiveExperienceManager Tests

    @MainActor
    func testManagerSingleton() async {
        let manager1 = ImmersiveExperienceManager.shared
        let manager2 = ImmersiveExperienceManager.shared
        XCTAssertTrue(manager1 === manager2)
    }

    @MainActor
    func testManagerInitialState() async {
        let manager = ImmersiveExperienceManager.shared

        XCTAssertEqual(manager.currentMode, .passthrough)
        XCTAssertNil(manager.activeExperience)
        XCTAssertFalse(manager.isImmersive)
    }

    @MainActor
    func testSetMode() async {
        let manager = ImmersiveExperienceManager.shared

        await manager.setMode(.mixed)
        XCTAssertEqual(manager.currentMode, .mixed)

        await manager.setMode(.full)
        XCTAssertEqual(manager.currentMode, .full)

        // Reset for other tests
        await manager.setMode(.passthrough)
    }

    @MainActor
    func testMotionComfortLevels() async {
        XCTAssertEqual(ImmersiveExperienceManager.MotionComfort.sensitive.rawValue, "Sensitive")
        XCTAssertEqual(ImmersiveExperienceManager.MotionComfort.standard.rawValue, "Standard")
        XCTAssertEqual(ImmersiveExperienceManager.MotionComfort.comfortable.rawValue, "Comfortable")

        // Check descriptions exist
        for level in ImmersiveExperienceManager.MotionComfort.allCases {
            XCTAssertFalse(level.description.isEmpty)
        }
    }

    // MARK: - VideoFormat Tests

    func testVideoFormats() {
        XCTAssertEqual(ImmersiveVideoCaptureManager.VideoFormat.immersive.rawValue, "Apple Immersive")
        XCTAssertEqual(ImmersiveVideoCaptureManager.VideoFormat.spatial.rawValue, "Spatial Video")
        XCTAssertEqual(ImmersiveVideoCaptureManager.VideoFormat.equirectangular360.rawValue, "360° Equirectangular")
        XCTAssertEqual(ImmersiveVideoCaptureManager.VideoFormat.standard.rawValue, "Standard HD")
    }

    func testVideoFormatAllCases() {
        let formats = ImmersiveVideoCaptureManager.VideoFormat.allCases
        XCTAssertEqual(formats.count, 4)
    }

    // MARK: - CaptureState Tests

    func testCaptureStates() {
        let states: [ImmersiveVideoCaptureManager.CaptureState] = [
            .idle, .preparing, .recording, .paused, .finishing
        ]

        // Verify we can create all states
        XCTAssertEqual(states.count, 5)
    }

    // MARK: - ImmersiveRecording Tests

    func testImmersiveRecordingCreation() {
        let recording = ImmersiveRecording(
            id: UUID(),
            name: "Test Recording",
            date: Date(),
            duration: 120.0,
            videoURL: URL(string: "file:///test.mp4")!,
            format: .immersive,
            bioDataPoints: [
                ImmersiveVideoCaptureManager.BioDataPoint(
                    timestamp: 0,
                    heartRate: 70,
                    hrv: 50,
                    coherence: 0.6
                ),
                ImmersiveVideoCaptureManager.BioDataPoint(
                    timestamp: 1,
                    heartRate: 72,
                    hrv: 52,
                    coherence: 0.65
                )
            ]
        )

        XCTAssertEqual(recording.name, "Test Recording")
        XCTAssertEqual(recording.duration, 120.0, accuracy: 0.001)
        XCTAssertEqual(recording.format, .immersive)
        XCTAssertEqual(recording.bioDataPoints.count, 2)
    }

    func testImmersiveRecordingAverages() {
        let recording = ImmersiveRecording(
            id: UUID(),
            name: "Test",
            date: Date(),
            duration: 60.0,
            videoURL: URL(string: "file:///test.mp4")!,
            format: .spatial,
            bioDataPoints: [
                ImmersiveVideoCaptureManager.BioDataPoint(timestamp: 0, heartRate: 60, hrv: 40, coherence: 0.4),
                ImmersiveVideoCaptureManager.BioDataPoint(timestamp: 1, heartRate: 70, hrv: 50, coherence: 0.5),
                ImmersiveVideoCaptureManager.BioDataPoint(timestamp: 2, heartRate: 80, hrv: 60, coherence: 0.6)
            ]
        )

        XCTAssertEqual(recording.averageHeartRate, 70.0, accuracy: 0.01)
        XCTAssertEqual(recording.averageCoherence, 0.5, accuracy: 0.01)
    }

    func testEmptyRecordingAverages() {
        let recording = ImmersiveRecording(
            id: UUID(),
            name: "Empty",
            date: Date(),
            duration: 0,
            videoURL: URL(string: "file:///empty.mp4")!,
            format: .standard,
            bioDataPoints: []
        )

        XCTAssertEqual(recording.averageHeartRate, 0)
        XCTAssertEqual(recording.averageCoherence, 0)
    }

    // MARK: - CaptureError Tests

    func testCaptureErrors() {
        let errors: [ImmersiveVideoCaptureManager.CaptureError] = [
            .cameraNotAvailable,
            .alreadyRecording,
            .notRecording,
            .encodingFailed,
            .saveFailed,
            .playbackFailed
        ]

        // Check all errors have descriptions
        for error in errors {
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }

    // MARK: - ImmersiveVideoCaptureManager Tests

    @MainActor
    func testCaptureManagerSingleton() async {
        let manager1 = ImmersiveVideoCaptureManager.shared
        let manager2 = ImmersiveVideoCaptureManager.shared
        XCTAssertTrue(manager1 === manager2)
    }

    @MainActor
    func testCaptureManagerInitialState() async {
        let manager = ImmersiveVideoCaptureManager.shared

        XCTAssertEqual(manager.captureState, .idle)
        XCTAssertEqual(manager.playbackState, .stopped)
        XCTAssertTrue(manager.bioOverlayEnabled)
    }
}

#else

// Non-visionOS placeholder tests
final class ImmersiveExperienceTests: XCTestCase {
    func testSkippedOnNonVisionOS() {
        // These tests only run on visionOS
        XCTAssertTrue(true, "Immersive tests skipped on non-visionOS platform")
    }
}

#endif
