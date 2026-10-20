import XCTest
@testable import EchoelCore

final class ProjectLibraryTests: XCTestCase {
    private var directory: URL!
    private var library: ProjectLibrary!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("lib-\(UUID().uuidString)")
        library = ProjectLibrary(directory: directory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func song(_ name: String) throws -> Project {
        var project = Project(name: name)
        let track = TrackID()
        try Command.addTrack(id: track, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        try Command.setTempo(bpm: 93).apply(to: &project)
        return project
    }

    func testASongWritesAndReadsBackIdentically() throws {
        let project = try song("Night Drive")
        let url = library.newURL(for: project.name)
        try library.write(project, to: url)
        XCTAssertEqual(url.lastPathComponent, "Night Drive.echoel")
        XCTAssertEqual(try library.read(url), project)
    }

    func testNewNamesNeverOverwriteAnExistingSong() throws {
        let first = library.newURL(for: "Song")
        try library.write(try song("Song"), to: first)
        let second = library.newURL(for: "Song")
        XCTAssertEqual(second.lastPathComponent, "Song 2.echoel")
        try library.write(try song("Song"), to: second)
        XCTAssertEqual(library.newURL(for: "Song").lastPathComponent, "Song 3.echoel")
    }

    func testListingShowsOnlySongsNewestFirst() throws {
        XCTAssertEqual(try library.list(), [])
        let older = library.newURL(for: "A")
        try library.write(try song("A"), to: older)
        let newer = library.newURL(for: "B")
        try library.write(try song("B"), to: newer)
        let past = Date(timeIntervalSinceNow: -3_600)
        try FileManager.default.setAttributes([.modificationDate: past],
                                              ofItemAtPath: older.appendingPathComponent(ProjectLibrary.documentName).path)
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("Not a song"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("Empty.echoel"), withIntermediateDirectories: true)
        XCTAssertEqual(try library.list().map(\.name), ["B", "A"])
    }

    func testOverwritingKeepsOnePackage() throws {
        let url = library.newURL(for: "Loop")
        var project = try song("Loop")
        try library.write(project, to: url)
        try Command.setTempo(bpm: 128).apply(to: &project)
        try library.write(project, to: url)
        XCTAssertEqual(try library.read(url).tempo, 128)
        XCTAssertEqual(try library.list().count, 1)
    }

    func testNamesAreMadeSafeForFiles() {
        XCTAssertEqual(ProjectLibrary.fileName(for: "a/b:c"), "a-b-c")
        XCTAssertEqual(ProjectLibrary.fileName(for: "  ...  "), "Untitled")
        XCTAssertEqual(ProjectLibrary.fileName(for: "Ünïcode ♪"), "Ünïcode ♪")
        XCTAssertEqual(ProjectLibrary.fileName(for: String(repeating: "x", count: 300)).count, 100)
    }

    func testReadingSomethingElseFailsClearly() throws {
        let folder = directory.appendingPathComponent("Nope.echoel")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        XCTAssertThrowsError(try library.read(folder)) { error in
            XCTAssertEqual(error as? ProjectLibrary.LibraryError, .notAPackage(folder))
        }
        XCTAssertThrowsError(try library.delete(directory.appendingPathComponent("x.txt")))
    }

    func testDeleteRemovesTheSong() throws {
        let url = library.newURL(for: "Gone")
        try library.write(try song("Gone"), to: url)
        try library.delete(url)
        XCTAssertEqual(try library.list(), [])
    }

    /// A song from elsewhere joins the library whole, a second time under a new name, and one
    /// already in the library opens where it is (E4).
    func testASongFromOutsideIsCopiedInWithItsMediaAndOneInsideStaysWhereItIs() throws {
        let outside = FileManager.default.temporaryDirectory.appendingPathComponent("out-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: outside) }
        let elsewhere = ProjectLibrary(directory: outside)
        let project = try song("Night Drive")
        let source = elsewhere.newURL(for: project.name)
        try elsewhere.write(project, to: source)
        let media = source.appendingPathComponent("Media", isDirectory: true)
        try FileManager.default.createDirectory(at: media, withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: media.appendingPathComponent("take.wav"))

        let adopted = try library.adopt(source)
        XCTAssertEqual(adopted.lastPathComponent, "Night Drive.echoel")
        XCTAssertEqual(try library.read(adopted), project)
        XCTAssertEqual(try Data(contentsOf: adopted.appendingPathComponent("Media/take.wav")), Data([1, 2, 3]),
                       "its media came along")
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path), "the original stays where it was")
        XCTAssertEqual(try library.adopt(adopted), adopted, "a song in the library opens in place")
        XCTAssertEqual(try library.list().count, 1)
        XCTAssertEqual(try library.adopt(source).lastPathComponent, "Night Drive 2.echoel", "never over the first")
    }

    func testADamagedSongFromOutsideIsRefusedBeforeAnythingIsCopied() throws {
        let outside = FileManager.default.temporaryDirectory.appendingPathComponent("out-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: outside) }
        let broken = outside.appendingPathComponent("Broken.echoel", isDirectory: true)
        try FileManager.default.createDirectory(at: broken, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: broken.appendingPathComponent(ProjectLibrary.documentName))
        XCTAssertThrowsError(try library.adopt(broken))
        XCTAssertThrowsError(try library.adopt(outside.appendingPathComponent("notes.txt")))
        XCTAssertEqual(try library.list(), [], "nothing came in")
    }

    func testASongInTheInboxMovesInAndLeavesNoCopy() throws {
        let inbox = ProjectLibrary(directory: directory.appendingPathComponent("Inbox", isDirectory: true))
        let source = inbox.newURL(for: "Sent")
        try inbox.write(try song("Sent"), to: source)
        let adopted = try library.adopt(source)
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path), "moved out of the Inbox")
        XCTAssertEqual(try library.read(adopted).name, "Sent")
        XCTAssertEqual(try library.list().map(\.name), ["Sent"])
    }
}
