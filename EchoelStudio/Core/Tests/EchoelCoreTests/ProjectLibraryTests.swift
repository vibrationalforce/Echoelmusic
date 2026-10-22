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

    /// A renamed song takes the first free spelling of its new name, with its own package counted
    /// as free: "Beat 2" called "Beat" again stays where it is while another song holds "Beat".
    func testARenameTakesAFreeNameAndKeepsItsOwn() throws {
        for name in ["Beat", "Beat", "Pad"] {
            try library.write(try song(name), to: library.newURL(for: name))
        }
        let own = directory.appendingPathComponent("Beat 2.echoel")
        XCTAssertEqual(library.renamedURL(for: "Beat", from: own), own, "its own spelling, with its number")
        XCTAssertEqual(library.renamedURL(for: "Pad", from: own).lastPathComponent, "Pad 2.echoel", "past another song")
        XCTAssertEqual(library.renamedURL(for: "Lead/Line", from: own).lastPathComponent, "Lead-Line.echoel")
        XCTAssertEqual(library.renamedURL(for: "Night", from: own).lastPathComponent, "Night.echoel")
    }

    /// The package moves whole — the document and the audio beside it — and nothing stays at the
    /// old name. A name the package already spells moves nothing.
    func testARenameMovesThePackageWithItsMedia() throws {
        let url = library.newURL(for: "Beat")
        try library.write(try song("Beat"), to: url)
        let media = url.appendingPathComponent("Media", isDirectory: true)
        try FileManager.default.createDirectory(at: media, withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: media.appendingPathComponent("take.wav"))

        let moved = try library.rename(url, to: "Night Drive")
        XCTAssertEqual(moved.lastPathComponent, "Night Drive.echoel")
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), "no folder left at the old name")
        XCTAssertEqual(try library.read(moved).tempo, 93)
        XCTAssertEqual(try Data(contentsOf: moved.appendingPathComponent("Media/take.wav")), Data([1, 2, 3]),
                       "its media came along")
        XCTAssertEqual(try library.list().map(\.name), ["Night Drive"])
        XCTAssertEqual(try library.rename(moved, to: "Night Drive"), moved, "the same name moves nothing")
        XCTAssertThrowsError(try library.rename(directory.appendingPathComponent("x.txt"), to: "Y"))
    }

    /// A change of case only leaves one package, spelled the new way — also where the volume
    /// holds "beat" and "Beat" as one name, which a plain free-name search would have turned into
    /// "Beat 2".
    func testACaseOnlyRenameKeepsOnePackage() throws {
        let url = library.newURL(for: "beat")
        try library.write(try song("beat"), to: url)
        let moved = try library.rename(url, to: "Beat")
        XCTAssertEqual(moved.lastPathComponent, "Beat.echoel")
        XCTAssertEqual(try library.list().map(\.name), ["Beat"])
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertEqual(names, ["Beat.echoel"], "no in-between name left behind")
        XCTAssertEqual(try library.read(moved).tempo, 93)
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

    /// A song handed on is its document and the media it names, nothing more: a file the song
    /// does not use stays behind, one it names but lacks is reported, and the copy opens as the
    /// song when another library adopts it.
    func testASharedCopyHoldsTheDocumentAndTheMediaTheSongNames() throws {
        let outside = FileManager.default.temporaryDirectory.appendingPathComponent("share-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: outside) }
        var project = try song("Night Drive")
        let take = MediaFile(name: "Take", path: "Media/take.wav", frameCount: 3, sampleRate: 48_000)
        let gone = MediaFile(name: "Gone", path: "Media/gone.wav", frameCount: 3, sampleRate: 48_000)
        try Command.addMedia(take).apply(to: &project)
        try Command.addMedia(gone).apply(to: &project)
        let package = library.newURL(for: project.name)
        try library.write(project, to: package)
        let media = package.appendingPathComponent("Media", isDirectory: true)
        try FileManager.default.createDirectory(at: media, withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: media.appendingPathComponent("take.wav"))
        try Data([9]).write(to: media.appendingPathComponent("recording.wav"))

        let target = outside.appendingPathComponent("Night Drive.echoel", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try Data([7]).write(to: target.appendingPathComponent("stale.txt"))
        let missing = try ProjectLibrary.shareableCopy(of: project, mediaIn: package, at: target)
        XCTAssertEqual(missing, ["Gone"])
        let held: [String] = try FileManager.default.subpathsOfDirectory(atPath: target.path).sorted()
        XCTAssertEqual(held, ["Media", "Media/take.wav", ProjectLibrary.documentName],
                       "no take in progress, no file from an earlier copy")
        XCTAssertEqual(try Data(contentsOf: target.appendingPathComponent("Media/take.wav")), Data([1, 2, 3]))

        let other = ProjectLibrary(directory: outside.appendingPathComponent("Other", isDirectory: true))
        let adopted = try other.adopt(target)
        XCTAssertEqual(try other.read(adopted), project)
        XCTAssertEqual(try Data(contentsOf: adopted.appendingPathComponent("Media/take.wav")), Data([1, 2, 3]))

        let bare = try ProjectLibrary.shareableCopy(of: project, mediaIn: nil, at: target)
        XCTAssertEqual(bare, ["Take", "Gone"], "without a package every file is missing")
        XCTAssertEqual(try ProjectLibrary(directory: outside).read(target), project)
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
