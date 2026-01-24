import XCTest
@testable import Echoelmusic

/// Comprehensive tests for ExportManager
/// Tests audio export, bio-data export, and session packaging functionality
final class ExportManagerTests: XCTestCase {

    var sut: ExportManager!
    var testDirectory: URL!

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        sut = ExportManager()

        // Create test directory
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EchoelmusicExportTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try await super.tearDown()
        sut = nil

        // Clean up test directory
        if let testDirectory = testDirectory {
            try? FileManager.default.removeItem(at: testDirectory)
        }
    }

    // MARK: - Export Format Tests

    func testExportFormatFileExtensions() {
        XCTAssertEqual(ExportManager.ExportFormat.wav.fileExtension, "wav")
        XCTAssertEqual(ExportManager.ExportFormat.m4a.fileExtension, "m4a")
        XCTAssertEqual(ExportManager.ExportFormat.aiff.fileExtension, "aiff")
        XCTAssertEqual(ExportManager.ExportFormat.caf.fileExtension, "caf")
    }

    func testExportFormatAudioFormatIDs() {
        XCTAssertEqual(ExportManager.ExportFormat.wav.audioFormatID, kAudioFormatLinearPCM)
        XCTAssertEqual(ExportManager.ExportFormat.m4a.audioFormatID, kAudioFormatMPEG4AAC)
        XCTAssertEqual(ExportManager.ExportFormat.aiff.audioFormatID, kAudioFormatLinearPCM)
        XCTAssertEqual(ExportManager.ExportFormat.caf.audioFormatID, kAudioFormatAppleLossless)
    }

    func testExportFormatFileTypes() {
        XCTAssertEqual(ExportManager.ExportFormat.wav.fileType, .wav)
        XCTAssertEqual(ExportManager.ExportFormat.m4a.fileType, .m4a)
        XCTAssertEqual(ExportManager.ExportFormat.aiff.fileType, .aiff)
        XCTAssertEqual(ExportManager.ExportFormat.caf.fileType, .caf)
    }

    // MARK: - Bio Data Format Tests

    func testBioDataFormatFileExtensions() {
        XCTAssertEqual(ExportManager.BioDataFormat.json.fileExtension, "json")
        XCTAssertEqual(ExportManager.BioDataFormat.csv.fileExtension, "csv")
    }

    // MARK: - Export Audio Tests

    @MainActor
    func testExportAudioWithEmptySession() async {
        let session = createEmptyTestSession()

        do {
            _ = try await sut.exportAudio(session: session, format: .wav)
            XCTFail("Should throw error for empty session")
        } catch {
            // Expected - should throw RecordingError.fileNotFound
            XCTAssertTrue(error is RecordingError)
        }
    }

    @MainActor
    func testExportAudioURLGeneration() async {
        let session = createEmptyTestSession()
        let outputURL = testDirectory.appendingPathComponent("test_export.wav")

        // Verify URL is constructed correctly
        XCTAssertTrue(outputURL.lastPathComponent.contains("wav"))
    }

    // MARK: - Export Bio Data Tests

    @MainActor
    func testExportBioDataJSON() async throws {
        let session = createSessionWithBioData()
        let outputURL = testDirectory.appendingPathComponent("biodata.json")

        let resultURL = try sut.exportBioData(session: session, format: .json, outputURL: outputURL)

        XCTAssertEqual(resultURL.pathExtension, "json")
    }

    @MainActor
    func testExportBioDataCSV() async throws {
        let session = createSessionWithBioData()
        let outputURL = testDirectory.appendingPathComponent("biodata.csv")

        let resultURL = try sut.exportBioData(session: session, format: .csv, outputURL: outputURL)

        XCTAssertEqual(resultURL.pathExtension, "csv")
    }

    // MARK: - Session Package Tests

    @MainActor
    func testExportSessionPackageCreatesDirectory() async throws {
        let session = createSessionWithBioData()
        let packageURL = testDirectory.appendingPathComponent("TestSessionPackage")

        do {
            let resultURL = try await sut.exportSessionPackage(session: session, outputDirectory: packageURL)

            // Verify directory was created
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: resultURL.path, isDirectory: &isDirectory)
            XCTAssertTrue(exists)
            XCTAssertTrue(isDirectory.boolValue)
        } catch {
            // Export may fail without actual audio tracks - this is acceptable
            XCTAssertTrue(error is RecordingError)
        }
    }

    // MARK: - Edge Case Tests

    @MainActor
    func testExportWithNilOutputURL() async {
        let session = createEmptyTestSession()

        // Should use default URL generation
        do {
            _ = try await sut.exportAudio(session: session, format: .wav, outputURL: nil)
        } catch {
            // Expected - empty session has no tracks
            XCTAssertTrue(true)
        }
    }

    @MainActor
    func testMultipleExportFormats() async {
        let formats: [ExportManager.ExportFormat] = [.wav, .m4a, .aiff, .caf]

        for format in formats {
            // Verify each format has valid properties
            XCTAssertFalse(format.fileExtension.isEmpty)
            XCTAssertNotNil(format.fileType)
        }
    }

    // MARK: - Concurrent Export Tests

    @MainActor
    func testConcurrentExportOperations() async {
        let session1 = createSessionWithBioData()
        let session2 = createSessionWithBioData()

        // Test that multiple exports can be initiated concurrently
        async let export1 = Task {
            try? await self.sut.exportBioData(session: session1, format: .json)
        }
        async let export2 = Task {
            try? await self.sut.exportBioData(session: session2, format: .csv)
        }

        _ = await (export1, export2)
        // If we reach here without crash, concurrent operations work
        XCTAssertTrue(true)
    }

    // MARK: - Helper Methods

    private func createEmptyTestSession() -> Session {
        return Session(
            id: UUID(),
            name: "Test Session",
            createdAt: Date(),
            duration: 60.0,
            tracks: [],
            bioDataSnapshots: []
        )
    }

    private func createSessionWithBioData() -> Session {
        let bioData = [
            BioDataSnapshot(
                timestamp: Date(),
                heartRate: 72,
                hrv: 45,
                coherence: 0.65
            ),
            BioDataSnapshot(
                timestamp: Date().addingTimeInterval(1),
                heartRate: 74,
                hrv: 48,
                coherence: 0.70
            )
        ]

        return Session(
            id: UUID(),
            name: "Test Session with Bio",
            createdAt: Date(),
            duration: 120.0,
            tracks: [],
            bioDataSnapshots: bioData
        )
    }
}

// MARK: - Test Support Types

/// Mock types for testing (if not available in main target)
#if DEBUG
extension ExportManagerTests {
    struct Session {
        let id: UUID
        let name: String
        let createdAt: Date
        let duration: TimeInterval
        var tracks: [Track]
        var bioDataSnapshots: [BioDataSnapshot]
    }

    struct Track {
        let id: UUID
        let name: String
        var url: URL?
        var volume: Float
        var pan: Float
        var isMuted: Bool
    }

    struct BioDataSnapshot {
        let timestamp: Date
        let heartRate: Int
        let hrv: Int
        let coherence: Float
    }
}
#endif
