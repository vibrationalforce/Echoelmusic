import XCTest
@testable import EchoelmusicCore

final class SessionTests: XCTestCase {

    // MARK: - Roundtrip Tests

    func testSessionSaveLoadRoundtrip() throws {
        // Create a session with various data
        var session = Session(name: "Test Session", tempo: 120.0)

        // Add tracks
        session.addTrack(.voiceTrack())
        session.addTrack(.binauralTrack())
        session.addTrack(.spatialTrack())

        // Add bio data
        let bioPoint1 = BioDataPoint(
            timestamp: 1.0,
            hrv: 50.0,
            heartRate: 70.0,
            coherence: 80.0,
            audioLevel: 0.5,
            frequency: 440.0
        )
        let bioPoint2 = BioDataPoint(
            timestamp: 2.0,
            hrv: 55.0,
            heartRate: 72.0,
            coherence: 82.0,
            audioLevel: 0.6,
            frequency: 442.0
        )
        session.addBioDataPoint(bioPoint1)
        session.addBioDataPoint(bioPoint2)

        // Set metadata
        session.metadata.genre = "Test Genre"
        session.metadata.mood = "Test Mood"
        session.metadata.tags = ["test", "roundtrip"]
        session.metadata.notes = "This is a test session"

        // Save
        try session.save()

        // Load
        let loaded = try Session.load(id: session.id)

        // Verify identity
        XCTAssertEqual(loaded.id, session.id, "Session ID should match")
        XCTAssertEqual(loaded.name, session.name, "Session name should match")
        XCTAssertEqual(loaded.tempo, session.tempo, "Tempo should match")

        // Verify time signature
        XCTAssertEqual(loaded.timeSignature.numerator, session.timeSignature.numerator)
        XCTAssertEqual(loaded.timeSignature.denominator, session.timeSignature.denominator)

        // Verify tracks
        XCTAssertEqual(loaded.tracks.count, session.tracks.count, "Track count should match")
        for (index, track) in loaded.tracks.enumerated() {
            let original = session.tracks[index]
            XCTAssertEqual(track.id, original.id, "Track ID should match")
            XCTAssertEqual(track.name, original.name, "Track name should match")
            XCTAssertEqual(track.type, original.type, "Track type should match")
            XCTAssertEqual(track.volume, original.volume, accuracy: 0.001, "Track volume should match")
            XCTAssertEqual(track.pan, original.pan, accuracy: 0.001, "Track pan should match")
        }

        // Verify bio data
        XCTAssertEqual(loaded.bioData.count, session.bioData.count, "Bio data count should match")
        for (index, point) in loaded.bioData.enumerated() {
            let original = session.bioData[index]
            XCTAssertEqual(point.timestamp, original.timestamp, accuracy: 0.001)
            XCTAssertEqual(point.hrv, original.hrv, accuracy: 0.001)
            XCTAssertEqual(point.heartRate, original.heartRate, accuracy: 0.001)
            XCTAssertEqual(point.coherence, original.coherence, accuracy: 0.001)
            XCTAssertEqual(point.audioLevel, original.audioLevel, accuracy: 0.001)
            XCTAssertEqual(point.frequency, original.frequency, accuracy: 0.001)
        }

        // Verify metadata
        XCTAssertEqual(loaded.metadata.genre, session.metadata.genre)
        XCTAssertEqual(loaded.metadata.mood, session.metadata.mood)
        XCTAssertEqual(loaded.metadata.tags, session.metadata.tags)
        XCTAssertEqual(loaded.metadata.notes, session.metadata.notes)

        print("✅ Session roundtrip test passed")
    }

    func testEmptySessionSaveLoad() throws {
        // Test with minimal session
        let session = Session(name: "Empty Session", tempo: 90.0)

        // Save
        try session.save()

        // Load
        let loaded = try Session.load(id: session.id)

        // Verify
        XCTAssertEqual(loaded.id, session.id)
        XCTAssertEqual(loaded.name, session.name)
        XCTAssertEqual(loaded.tempo, session.tempo)
        XCTAssertTrue(loaded.tracks.isEmpty)
        XCTAssertTrue(loaded.bioData.isEmpty)

        print("✅ Empty session roundtrip test passed")
    }

    func testSessionWithManyBioPoints() throws {
        // Test with large bio dataset
        var session = Session(name: "Bio Test", tempo: 120.0)

        // Add 1000 bio data points
        for i in 0..<1000 {
            let point = BioDataPoint(
                timestamp: Double(i),
                hrv: 50.0 + Double(i % 50),
                heartRate: 70.0 + Double(i % 30),
                coherence: 80.0 + Double(i % 20),
                audioLevel: Float(i % 100) / 100.0,
                frequency: 440.0 + Float(i % 100)
            )
            session.addBioDataPoint(point)
        }

        // Save
        try session.save()

        // Load
        let loaded = try Session.load(id: session.id)

        // Verify
        XCTAssertEqual(loaded.bioData.count, 1000)
        XCTAssertEqual(loaded.bioData.first?.timestamp, 0.0)
        XCTAssertEqual(loaded.bioData.last?.timestamp, 999.0)

        print("✅ Large bio dataset roundtrip test passed")
    }

    // MARK: - Validation Tests

    func testValidationEmptyName() throws {
        var session = Session(name: "", tempo: 120.0)
        XCTAssertThrowsError(try session.validate()) { error in
            XCTAssertEqual(error as? SessionError, .invalidName)
        }
    }

    func testValidationLongName() throws {
        let longName = String(repeating: "A", count: 250)
        var session = Session(name: longName, tempo: 120.0)
        XCTAssertThrowsError(try session.validate()) { error in
            XCTAssertEqual(error as? SessionError, .nameTooLong)
        }
    }

    func testValidationInvalidTempo() throws {
        var session = Session(name: "Test", tempo: -10)
        XCTAssertThrowsError(try session.validate()) { error in
            XCTAssertEqual(error as? SessionError, .invalidTempo)
        }

        session.tempo = 1000
        XCTAssertThrowsError(try session.validate()) { error in
            XCTAssertEqual(error as? SessionError, .invalidTempo)
        }
    }

    func testValidationInvalidTimeSignature() throws {
        var session = Session(name: "Test", tempo: 120)
        session.timeSignature = TimeSignature(numerator: 0, denominator: 4)
        XCTAssertThrowsError(try session.validate()) { error in
            XCTAssertEqual(error as? SessionError, .invalidTimeSignature)
        }

        session.timeSignature = TimeSignature(numerator: 4, denominator: 3)
        XCTAssertThrowsError(try session.validate()) { error in
            XCTAssertEqual(error as? SessionError, .invalidTimeSignature)
        }
    }

    func testValidationInvalidTrackVolume() throws {
        var session = Session(name: "Test", tempo: 120)
        var track = Track(name: "Test Track")
        track.volume = 1.5
        session.addTrack(track)

        XCTAssertThrowsError(try session.validate()) { error in
            XCTAssertEqual(error as? SessionError, .invalidTrackVolume)
        }
    }

    func testValidationInvalidTrackPan() throws {
        var session = Session(name: "Test", tempo: 120)
        var track = Track(name: "Test Track")
        track.pan = -2.0
        session.addTrack(track)

        XCTAssertThrowsError(try session.validate()) { error in
            XCTAssertEqual(error as? SessionError, .invalidTrackPan)
        }
    }

    func testValidationInvalidBioData() throws {
        var session = Session(name: "Test", tempo: 120)

        // Invalid HRV
        let point1 = BioDataPoint(
            timestamp: 1.0,
            hrv: 600.0, // too high
            heartRate: 70.0,
            coherence: 80.0,
            audioLevel: 0.5,
            frequency: 440.0
        )
        session.addBioDataPoint(point1)

        XCTAssertThrowsError(try session.validate()) { error in
            XCTAssertEqual(error as? SessionError, .invalidBioData)
        }
    }

    func testValidationValidSession() throws {
        var session = Session(name: "Valid Session", tempo: 120.0)
        session.addTrack(.voiceTrack())
        session.addTrack(.binauralTrack())

        let point = BioDataPoint(
            timestamp: 1.0,
            hrv: 50.0,
            heartRate: 70.0,
            coherence: 80.0,
            audioLevel: 0.5,
            frequency: 440.0
        )
        session.addBioDataPoint(point)

        // Should not throw
        XCTAssertNoThrow(try session.validate())
    }

    // MARK: - Template Tests

    func testMeditationTemplate() throws {
        let session = Session.meditationTemplate()

        XCTAssertEqual(session.name, "Meditation Session")
        XCTAssertEqual(session.tempo, 60.0)
        XCTAssertEqual(session.tracks.count, 1)
        XCTAssertEqual(session.tracks.first?.type, .binaural)
        XCTAssertEqual(session.metadata.genre, "Meditation")
        XCTAssertEqual(session.metadata.mood, "Calm")

        // Should be valid
        XCTAssertNoThrow(try session.validate())
    }

    func testHealingTemplate() throws {
        let session = Session.healingTemplate()

        XCTAssertEqual(session.name, "Healing Session")
        XCTAssertEqual(session.tempo, 72.0)
        XCTAssertEqual(session.tracks.count, 2)
        XCTAssertEqual(session.metadata.genre, "Healing")

        // Should be valid
        XCTAssertNoThrow(try session.validate())
    }

    func testCreativeTemplate() throws {
        let session = Session.creativeTemplate()

        XCTAssertEqual(session.name, "Creative Session")
        XCTAssertEqual(session.tempo, 120.0)
        XCTAssertEqual(session.tracks.count, 3)
        XCTAssertEqual(session.metadata.genre, "Experimental")

        // Should be valid
        XCTAssertNoThrow(try session.validate())
    }

    // MARK: - Statistics Tests

    func testSessionStatistics() throws {
        var session = Session(name: "Stats Test", tempo: 120)

        // Add bio points
        for i in 0..<10 {
            let point = BioDataPoint(
                timestamp: Double(i),
                hrv: 50.0,
                heartRate: 70.0,
                coherence: 80.0,
                audioLevel: 0.5,
                frequency: 440.0
            )
            session.addBioDataPoint(point)
        }

        XCTAssertEqual(session.averageHRV, 50.0, accuracy: 0.001)
        XCTAssertEqual(session.averageHeartRate, 70.0, accuracy: 0.001)
        XCTAssertEqual(session.averageCoherence, 80.0, accuracy: 0.001)
    }

    func testEmptySessionStatistics() throws {
        let session = Session(name: "Empty Stats", tempo: 120)

        // Empty session should have default values
        XCTAssertEqual(session.averageHRV, 0.0)
        XCTAssertEqual(session.averageHeartRate, 60.0)
        XCTAssertEqual(session.averageCoherence, 50.0)
    }
}
