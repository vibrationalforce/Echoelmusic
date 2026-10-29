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

    /// Each write that changes the song keeps the version before it beside the document, and a
    /// damaged document opens as that version — said so, so the caller can tell the musician.
    func testADamagedDocumentOpensAsTheVersionOneSaveBack() throws {
        let url = library.newURL(for: "Loop")
        var project = try song("Loop")
        try library.write(project, to: url)
        let previous = url.appendingPathComponent(ProjectLibrary.previousDocumentName)
        XCTAssertFalse(FileManager.default.fileExists(atPath: previous.path), "a first write has nothing to keep")
        try Command.setTempo(bpm: 128).apply(to: &project)
        try library.write(project, to: url)
        try library.write(project, to: url)
        XCTAssertEqual(try ProjectCodec.decode(Data(contentsOf: previous)).tempo, 93,
                       "the copy is the version before the change, and writing the same song again keeps it")
        XCTAssertEqual(try library.readRecovering(url), ProjectLibrary.Recovered(project: project, fromPrevious: false))

        try Data("{\"formatVersion\": 1, \"trac".utf8).write(to: url.appendingPathComponent(ProjectLibrary.documentName))
        XCTAssertThrowsError(try library.read(url), "a plain read still refuses it")
        let recovered = try library.readRecovering(url)
        XCTAssertTrue(recovered.fromPrevious)
        XCTAssertEqual(recovered.project.tempo, 93)
        XCTAssertEqual(try library.list().map(\.name), ["Loop"], "the song stays in the list")

        // The next write replaces the damaged document and leaves the copy alone: a copy is only
        // ever a song that opens.
        try library.write(recovered.project, to: url)
        XCTAssertEqual(try library.read(url).tempo, 93)
        XCTAssertEqual(try ProjectCodec.decode(Data(contentsOf: previous)).tempo, 93)
    }

    /// A newer Echoel's song is not damaged, and the copy must not stand in for it: the next save
    /// would write the older song over the newer. Without a usable copy the document's own error
    /// comes back, so the caller still tells a newer song from a damaged one.
    func testANewerSongIsNeverReplacedByItsCopy() throws {
        let url = library.newURL(for: "Loop")
        var project = try song("Loop")
        try library.write(project, to: url)
        try Command.setTempo(bpm: 128).apply(to: &project)
        try library.write(project, to: url)
        let document = url.appendingPathComponent(ProjectLibrary.documentName)
        let today = "\"formatVersion\" : \(Project.currentFormatVersion)"
        let json = try XCTUnwrap(String(data: Data(contentsOf: document), encoding: .utf8))
        XCTAssertTrue(json.contains(today), "the encoder's spacing changed; the replacement would not land")
        try Data(json.replacingOccurrences(of: today, with: "\"formatVersion\" : 99").utf8).write(to: document)
        XCTAssertThrowsError(try library.readRecovering(url)) {
            XCTAssertEqual($0 as? ProjectCodec.DecodeError, .newerFormat(found: 99, supported: Project.currentFormatVersion))
        }

        try Data("not a song".utf8).write(to: document)
        try Data("nor this".utf8).write(to: url.appendingPathComponent(ProjectLibrary.previousDocumentName))
        XCTAssertThrowsError(try library.readRecovering(url)) {
            XCTAssertNotNil($0 as? DecodingError, "the document's own error, not the copy's")
        }
    }

    func testNamesAreMadeSafeForFiles() {
        XCTAssertEqual(ProjectLibrary.fileName(for: "a/b:c"), "a-b-c")
        XCTAssertEqual(ProjectLibrary.fileName(for: "  ...  "), "Untitled")
        XCTAssertEqual(ProjectLibrary.fileName(for: "Ünïcode ♪"), "Ünïcode ♪")
        XCTAssertEqual(ProjectLibrary.fileName(for: String(repeating: "x", count: 300)).count, 100)
    }

    /// A file name is limited in bytes, not in characters: a name the door takes (128 characters)
    /// can hold far more bytes than a file name may have when its characters carry many scalars.
    /// The stem stays within its budget, and such a song can still be written and renamed.
    func testAFileNameStaysWithinTheFileSystemLimit() throws {
        let marked = String(repeating: "e\u{301}\u{302}\u{303}\u{304}", count: 100)   // 100 characters, 900 bytes
        let tones = String(repeating: "\u{1F44B}\u{1F3FD}", count: 100)               // a waving hand with a skin tone
        let zalgo = "a" + String(repeating: "\u{301}", count: 300)                    // one character, 601 bytes
        for name in [marked, tones] {
            let stem = ProjectLibrary.fileName(for: name)
            XCTAssertLessThanOrEqual(stem.utf8.count, ProjectLibrary.stemByteLimit)
            XCTAssertFalse(stem.isEmpty)
        }
        XCTAssertEqual(ProjectLibrary.fileName(for: zalgo), "Untitled", "a character too big for any file name keeps nothing")
        let url = library.newURL(for: marked)
        try library.write(try song(marked), to: url)
        let moved = try library.rename(url, to: tones)
        XCTAssertNotEqual(moved.lastPathComponent, url.lastPathComponent)
        XCTAssertEqual(try library.list().count, 1)
        XCTAssertEqual(try library.read(moved).name, marked)
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

    /// A change of case whose second step fails, and whose way back fails because another song
    /// took the old name meanwhile (the earlier songs' import reserves names off the main thread),
    /// reports the package under the name in between, its media with it, and leaves the other
    /// song alone. Asking only whether the old name exists sent the next write into that song.
    /// The way back is the real move: the import reserves an EMPTY folder, which POSIX rename(2)
    /// would replace, so the guard holds only while the move refuses a name that is taken.
    func testAStrandedRenameIsFoundByItsPackageNotItsOldName() throws {
        let url = library.newURL(for: "beat")
        try library.write(try song("beat"), to: url)
        let media = url.appendingPathComponent("Media", isDirectory: true)
        try FileManager.default.createDirectory(at: media, withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: media.appendingPathComponent("take.wav"))
        var step = 0
        do {
            _ = try library.rename(url, to: "Beat", moving: { (source: URL, destination: URL) in
                step += 1
                if step == 2 {
                    // Another song reserves the old name, so the second step fails and the way
                    // back finds the name taken.
                    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
                    throw CocoaError(.fileWriteFileExists)
                }
                try FileManager.default.moveItem(at: source, to: destination)
            })
            XCTFail("a rename that cannot land and cannot go back throws")
        } catch let stranded as ProjectLibrary.RenameStranded {
            let stem = stranded.url.deletingPathExtension().lastPathComponent
            XCTAssertTrue(ProjectLibrary.isBetweenStem(stem), "under the name in between: \(stem)")
            XCTAssertEqual(try Data(contentsOf: stranded.url.appendingPathComponent("Media/take.wav")), Data([1, 2, 3]))
            XCTAssertEqual(try library.read(stranded.url).tempo, 93)
            let other: [String] = try FileManager.default.contentsOfDirectory(atPath: url.path)
            XCTAssertEqual(other, [], "the other song's folder is untouched")
        }
    }

    /// A change of case whose second step fails but whose way back works leaves the package as it
    /// was, under its old name, and the error says why.
    func testACaseRenameThatGoesBackLeavesThePackageAsItWas() throws {
        let url = library.newURL(for: "beat")
        try library.write(try song("beat"), to: url)
        var step = 0
        XCTAssertThrowsError(try library.rename(url, to: "Beat", moving: { (source: URL, destination: URL) in
            step += 1
            guard step != 2 else { throw CocoaError(.fileWriteNoPermission) }
            try FileManager.default.moveItem(at: source, to: destination)
        })) { error in
            XCTAssertFalse(error is ProjectLibrary.RenameStranded, "back where it was, nothing is stranded")
        }
        let names: [String] = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertEqual(names, ["beat.echoel"])
        XCTAssertEqual(try library.read(url).tempo, 93)
    }

    /// The name in between that a change of case writes is known again — so a song left there
    /// takes its own name at the next write — and no name anyone would choose is taken for one.
    func testTheNameInBetweenIsKnownAgain() {
        let written = ProjectLibrary.betweenStem(for: "beat 2")
        XCTAssertTrue(ProjectLibrary.isBetweenStem(written), written)
        let chosen: [String] = ["beat", "Beat renaming", "renaming 1A2B3C4D", "beat renaming 1A2B3C4",
                                "beat renaming 1A2B3C4DE", "beat renaming XYZ12345", "beat renaming 1a2b3c4d"]
        for stem in chosen {
            XCTAssertFalse(ProjectLibrary.isBetweenStem(stem), stem)
        }
    }

    /// Three new songs are told apart on screen as they are in the Open list; a rename shows at
    /// once (audit 2026-10-23).
    func testANewSongIsTitledByItsFileNameAndARenamedOneByItsName() {
        XCTAssertEqual(ProjectLibrary.title(name: "New Song", stem: "New Song 3"), "New Song 3")
        XCTAssertEqual(ProjectLibrary.title(name: "New Song", stem: "New Song"), "New Song")
        XCTAssertEqual(ProjectLibrary.title(name: "Beat", stem: "New Song 3"), "Beat", "renamed, before the package moves")
        XCTAssertEqual(ProjectLibrary.title(name: "Beat", stem: nil), "Beat")
        XCTAssertEqual(ProjectLibrary.title(name: "New Song", stem: "New Song Remix"), "New Song", "only the library's number")
        XCTAssertEqual(ProjectLibrary.title(name: "A/B", stem: "A-B 2"), "A-B 2", "the number follows the file-safe name")
        XCTAssertEqual(ProjectLibrary.title(name: "A/B", stem: "A-B"), "A/B", "the song keeps its own spelling")
    }

    /// A song renamed in the Files app while it is open is found under its new name, media and
    /// all; one deleted there is found nowhere, so nothing writes it again under the old name as if
    /// it were still there (audit 2026-10-23).
    func testASongRenamedOutsideIsFoundByItsPackageAndADeletedOneIsNot() throws {
        let url = library.newURL(for: "Beat")
        try library.write(try song("Beat"), to: url)
        let identity = try XCTUnwrap(ProjectLibrary.identity(of: url))
        try library.write(try song("Other"), to: library.newURL(for: "Other"))

        let renamed = directory.appendingPathComponent("Beat Final.echoel")
        try FileManager.default.moveItem(at: url, to: renamed)
        XCTAssertEqual(library.package(identity)?.lastPathComponent, "Beat Final.echoel")
        XCTAssertEqual(ProjectLibrary.identity(of: renamed), identity, "a rename keeps the package what it is")

        try library.write(try song("Beat"), to: renamed)
        XCTAssertEqual(library.package(identity)?.lastPathComponent, "Beat Final.echoel",
                       "writing the document again keeps the package")

        try FileManager.default.removeItem(at: renamed)
        XCTAssertNil(library.package(identity))
        XCTAssertNil(ProjectLibrary.identity(of: renamed))
    }

    /// What an open song's package became outside, each case once: never written, in place,
    /// renamed, deleted, deleted and its name taken by another song, deleted and its folder made
    /// again by a take (second night review, 2026-10-23).
    func testAnOpenSongsPackageIsFoundWhereverTheFilesAppLeftIt() throws {
        let fresh = library.newURL(for: "New Song")
        XCTAssertEqual(library.whereabouts(of: fresh, identity: nil), .inPlace,
                       "a new song before its first write was never anywhere to be moved from")

        let url = library.newURL(for: "A")
        try library.write(try song("A"), to: url)
        let identity = try XCTUnwrap(ProjectLibrary.identity(of: url))
        let other = library.newURL(for: "B")
        try library.write(try song("B"), to: other)
        XCTAssertEqual(library.whereabouts(of: url, identity: identity), .inPlace)

        let renamed = directory.appendingPathComponent("A Final.echoel")
        try FileManager.default.moveItem(at: url, to: renamed)
        guard case .renamed(let found) = library.whereabouts(of: url, identity: identity) else {
            return XCTFail("a renamed package is found by what it is")
        }
        XCTAssertEqual(found.lastPathComponent, "A Final.echoel")

        // Moved out of the library rather than deleted: the package lives on elsewhere, so no new
        // file can take its number on a file system that reuses them.
        let outside = directory.deletingLastPathComponent().appendingPathComponent("outside-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: outside) }
        try FileManager.default.moveItem(at: renamed, to: outside.appendingPathComponent("A Final.echoel"))
        XCTAssertEqual(library.whereabouts(of: url, identity: identity), .gone)

        // Another song renamed to the gone one's name.
        try FileManager.default.moveItem(at: other, to: url)
        guard case .nameTaken(let free) = library.whereabouts(of: url, identity: identity) else {
            return XCTFail("another song's package under the name is not the open song")
        }
        XCTAssertEqual(free.lastPathComponent, "A 2.echoel")

        // A take made the folder again, without a document.
        try FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(at: url.appendingPathComponent("Media"), withIntermediateDirectories: true)
        XCTAssertEqual(library.whereabouts(of: url, identity: identity), .gone)
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
