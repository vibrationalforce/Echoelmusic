import XCTest
@testable import Echoelmusic

/// Comprehensive tests for Recording and Session system
@MainActor
final class RecordingSessionTests: XCTestCase {

    // MARK: - Session Tests

    func testSessionCreation() throws {
        let session = Session(name: "Test Session", tempo: 120)

        XCTAssertEqual(session.name, "Test Session")
        XCTAssertEqual(session.tempo, 120)
        XCTAssertEqual(session.tracks.count, 0)
        XCTAssertEqual(session.timeSignature.numerator, 4)
        XCTAssertEqual(session.timeSignature.denominator, 4)
        XCTAssertTrue(session.bioData.isEmpty)
    }

    func testSessionTemplates() throws {
        // Test meditation template
        let meditationSession = Session.meditationTemplate()
        XCTAssertEqual(meditationSession.name, "Meditation Session")
        XCTAssertEqual(meditationSession.tempo, 60)
        XCTAssertEqual(meditationSession.metadata.genre, "Meditation")
        XCTAssertEqual(meditationSession.metadata.mood, "Calm")
        XCTAssertEqual(meditationSession.tracks.count, 1)

        // Test healing template
        let healingSession = Session.healingTemplate()
        XCTAssertEqual(healingSession.name, "Healing Session")
        XCTAssertEqual(healingSession.tempo, 72)
        XCTAssertEqual(healingSession.metadata.genre, "Healing")
        XCTAssertEqual(healingSession.tracks.count, 2)

        // Test creative template
        let creativeSession = Session.creativeTemplate()
        XCTAssertEqual(creativeSession.name, "Creative Session")
        XCTAssertEqual(creativeSession.tempo, 120)
        XCTAssertEqual(creativeSession.metadata.genre, "Experimental")
        XCTAssertEqual(creativeSession.tracks.count, 3)
    }

    func testTrackManagement() throws {
        var session = Session(name: "Track Test")

        // Add tracks
        let track1 = Track.voiceTrack()
        let track2 = Track.binauralTrack()

        session.addTrack(track1)
        XCTAssertEqual(session.tracks.count, 1)

        session.addTrack(track2)
        XCTAssertEqual(session.tracks.count, 2)

        // Remove track
        session.removeTrack(id: track1.id)
        XCTAssertEqual(session.tracks.count, 1)
        XCTAssertEqual(session.tracks.first?.id, track2.id)
    }

    func testBioDataManagement() throws {
        var session = Session(name: "Bio Test")

        // Add bio data points
        let point1 = BioDataPoint(
            timestamp: 0,
            hrv: 50,
            heartRate: 70,
            coherence: 60,
            audioLevel: 0.5,
            frequency: 440
        )

        let point2 = BioDataPoint(
            timestamp: 1,
            hrv: 60,
            heartRate: 65,
            coherence: 70,
            audioLevel: 0.6,
            frequency: 880
        )

        session.addBioDataPoint(point1)
        session.addBioDataPoint(point2)

        XCTAssertEqual(session.bioData.count, 2)

        // Test averages
        XCTAssertEqual(session.averageHRV, 55, accuracy: 0.1)
        XCTAssertEqual(session.averageHeartRate, 67.5, accuracy: 0.1)
        XCTAssertEqual(session.averageCoherence, 65, accuracy: 0.1)

        // Clear bio data
        session.clearBioData()
        XCTAssertTrue(session.bioData.isEmpty)
    }

    func testTimeSignature() throws {
        var ts = TimeSignature(beats: 4, noteValue: 4)
        XCTAssertEqual(ts.description, "4/4")
        XCTAssertEqual(ts.beats, 4)
        XCTAssertEqual(ts.noteValue, 4)

        ts.beats = 3
        XCTAssertEqual(ts.description, "3/4")

        let ts2 = TimeSignature(numerator: 6, denominator: 8)
        XCTAssertEqual(ts2.description, "6/8")
    }

    func testSessionMetadata() throws {
        var session = Session(name: "Metadata Test")

        session.metadata.tags = ["relaxation", "healing", "432Hz"]
        session.metadata.genre = "Ambient"
        session.metadata.mood = "Peaceful"
        session.metadata.notes = "Test recording session"

        XCTAssertEqual(session.metadata.tags.count, 3)
        XCTAssertEqual(session.metadata.genre, "Ambient")
        XCTAssertEqual(session.metadata.mood, "Peaceful")
        XCTAssertNotNil(session.metadata.notes)
    }

    // MARK: - Export Manager Tests

    func testExportFormatProperties() throws {
        // Test WAV format
        XCTAssertEqual(ExportManager.ExportFormat.wav.fileExtension, "wav")
        XCTAssertEqual(ExportManager.ExportFormat.wav.fileType, .wav)

        // Test M4A format
        XCTAssertEqual(ExportManager.ExportFormat.m4a.fileExtension, "m4a")
        XCTAssertEqual(ExportManager.ExportFormat.m4a.fileType, .m4a)

        // Test AIFF format
        XCTAssertEqual(ExportManager.ExportFormat.aiff.fileExtension, "aiff")
        XCTAssertEqual(ExportManager.ExportFormat.aiff.fileType, .aiff)

        // Test CAF format
        XCTAssertEqual(ExportManager.ExportFormat.caf.fileExtension, "caf")
        XCTAssertEqual(ExportManager.ExportFormat.caf.fileType, .caf)
    }

    func testBioDataFormatProperties() throws {
        XCTAssertEqual(ExportManager.BioDataFormat.json.fileExtension, "json")
        XCTAssertEqual(ExportManager.BioDataFormat.csv.fileExtension, "csv")
    }

    // MARK: - Session Persistence Tests

    func testSessionSaveLoad() async throws {
        // Create session with data
        var session = Session(name: "Persistence Test", tempo: 90)
        session.addTrack(.voiceTrack())

        let bioPoint = BioDataPoint(
            timestamp: 0,
            hrv: 55,
            heartRate: 72,
            coherence: 65,
            audioLevel: 0.5,
            frequency: 440
        )
        session.addBioDataPoint(bioPoint)

        // Save session
        try session.save()

        // Load session
        let loadedSession = try Session.load(id: session.id)

        XCTAssertEqual(loadedSession.name, "Persistence Test")
        XCTAssertEqual(loadedSession.tempo, 90)
        XCTAssertEqual(loadedSession.tracks.count, 1)
        XCTAssertEqual(loadedSession.bioData.count, 1)

        // Cleanup
        let sessionDir = session.getSessionDirectory()
        try? FileManager.default.removeItem(at: sessionDir)
    }

    func testSessionDirectoryCreation() throws {
        let session = Session(name: "Directory Test")

        try session.createSessionDirectory()

        let exists = FileManager.default.fileExists(atPath: session.getSessionDirectory().path)
        XCTAssertTrue(exists)

        // Cleanup
        try? FileManager.default.removeItem(at: session.getSessionDirectory())
    }
}

// MARK: - Bio Mapping Preset Tests

@MainActor
final class BioMappingPresetTests: XCTestCase {

    func testPresetLibraryInitialization() throws {
        let library = BioMappingPresetLibrary.shared

        XCTAssertFalse(library.presets.isEmpty)
        XCTAssertGreaterThanOrEqual(library.presets.count, 10, "Should have at least 10 presets")
    }

    func testPresetCategories() throws {
        let library = BioMappingPresetLibrary.shared

        // Test each category has presets
        for category in PresetCategory.allCases where category != .custom {
            let categoryPresets = library.presets(for: category)
            // Some categories may be empty, but core ones should have presets
            if [.meditation, .healing, .focus, .creative].contains(category) {
                XCTAssertFalse(categoryPresets.isEmpty, "\(category.rawValue) should have presets")
            }
        }
    }

    func testPresetByName() throws {
        let library = BioMappingPresetLibrary.shared

        let deepMeditation = library.preset(named: "Deep Meditation")
        XCTAssertNotNil(deepMeditation)
        XCTAssertEqual(deepMeditation?.category, .meditation)

        let nonExistent = library.preset(named: "Non Existent Preset")
        XCTAssertNil(nonExistent)
    }

    func testPresetParameterRanges() throws {
        let library = BioMappingPresetLibrary.shared

        for preset in library.presets {
            // Validate reverb range
            XCTAssertGreaterThanOrEqual(preset.hrvToReverbRange.lowerBound, 0)
            XCTAssertLessThanOrEqual(preset.hrvToReverbRange.upperBound, 1)

            // Validate filter range
            XCTAssertGreaterThan(preset.heartRateToFilterRange.lowerBound, 0)

            // Validate amplitude range
            XCTAssertGreaterThanOrEqual(preset.coherenceToAmplitudeRange.lowerBound, 0)
            XCTAssertLessThanOrEqual(preset.coherenceToAmplitudeRange.upperBound, 1)

            // Validate tempo range
            XCTAssertGreaterThan(preset.tempoRange.lowerBound, 0)

            // Validate base frequency
            XCTAssertGreaterThan(preset.baseFrequency, 0)
        }
    }

    func testPresetMappingFunctions() throws {
        let library = BioMappingPresetLibrary.shared
        guard let preset = library.preset(named: "Deep Meditation") else {
            XCTFail("Deep Meditation preset not found")
            return
        }

        // Test HRV to reverb mapping
        let lowReverb = preset.mapHRVToReverb(0)
        let highReverb = preset.mapHRVToReverb(100)
        XCTAssertLessThan(lowReverb, highReverb)
        XCTAssertGreaterThanOrEqual(lowReverb, preset.hrvToReverbRange.lowerBound)
        XCTAssertLessThanOrEqual(highReverb, preset.hrvToReverbRange.upperBound)

        // Test heart rate to filter mapping
        let lowFilter = preset.mapHeartRateToFilter(40)
        let highFilter = preset.mapHeartRateToFilter(120)
        XCTAssertLessThan(lowFilter, highFilter)

        // Test coherence to amplitude mapping
        let lowAmp = preset.mapCoherenceToAmplitude(0)
        let highAmp = preset.mapCoherenceToAmplitude(100)
        XCTAssertLessThan(lowAmp, highAmp)
    }

    func testPresetApplyToMapper() throws {
        let library = BioMappingPresetLibrary.shared
        let mapper = BioParameterMapper()

        guard let preset = library.preset(named: "Deep Focus") else {
            XCTFail("Deep Focus preset not found")
            return
        }

        preset.apply(to: mapper)

        // Verify parameters are within expected ranges
        XCTAssertGreaterThan(mapper.baseFrequency, 0)
        XCTAssertGreaterThan(mapper.tempo, 0)
        XCTAssertGreaterThanOrEqual(mapper.harmonicCount, 1)
    }

    func testBinauralStatePresets() throws {
        let library = BioMappingPresetLibrary.shared

        // Verify different brainwave states are covered
        let states = library.presets.map { $0.binauralState }

        XCTAssertTrue(states.contains(.delta), "Should have delta preset")
        XCTAssertTrue(states.contains(.theta), "Should have theta preset")
        XCTAssertTrue(states.contains(.alpha), "Should have alpha preset")
        XCTAssertTrue(states.contains(.beta), "Should have beta preset")
        XCTAssertTrue(states.contains(.gamma), "Should have gamma preset")
    }

    func testHarmonicProfiles() throws {
        let library = BioMappingPresetLibrary.shared

        let profiles = library.presets.map { $0.harmonicProfile }

        // Verify variety of harmonic profiles
        XCTAssertTrue(profiles.contains(.pure), "Should have pure profile")
        XCTAssertTrue(profiles.contains(.balanced), "Should have balanced profile")
        XCTAssertTrue(profiles.contains(.rich), "Should have rich profile")
    }

    func testSpatialMappingModes() throws {
        let library = BioMappingPresetLibrary.shared

        let modes = library.presets.map { $0.spatialMode }

        // Verify variety of spatial modes
        XCTAssertTrue(modes.contains(.centered), "Should have centered mode")
        XCTAssertTrue(modes.contains(.breathing), "Should have breathing mode")
    }
}

// MARK: - Float Extension Tests

final class FloatExtensionTests: XCTestCase {

    func testClampedToRange() {
        let value1: Float = 0.5
        XCTAssertEqual(value1.clamped(to: 0...1), 0.5)

        let value2: Float = -0.5
        XCTAssertEqual(value2.clamped(to: 0...1), 0)

        let value3: Float = 1.5
        XCTAssertEqual(value3.clamped(to: 0...1), 1)
    }
}
