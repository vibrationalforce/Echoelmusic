import Foundation
import XCTest
@testable import EchoelCore

/// A song file comes from outside: AirDrop, Files, another app, a sync service, a damaged disk.
/// Whatever its bytes, opening it either gives a song that passes every rule or a thrown error —
/// never a crash, never a song that breaks a rule, never a path out of its package
/// (team SAFE 2026-11-04).
final class SongFileRobustnessTests: XCTestCase {
    /// SplitMix64: the same mutations on every machine, so a failure is the same failure each run.
    private struct Random {
        var seed: UInt64
        mutating func next() -> UInt64 {
            seed &+= 0x9E37_79B9_7F4A_7C15
            var z = seed
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }

        mutating func below(_ bound: Int) -> Int {
            bound <= 0 ? 0 : Int(next() % UInt64(bound))
        }
    }

    private func song() throws -> Project {
        var project = Project(name: "Robust")
        let track = TrackID(), clip = ClipID(), scene = SceneID()
        let commands: [Command] = [
            .setTempo(bpm: 124),
            .addTrack(id: track, name: "Lead", kind: .instrument, index: nil),
            .createClip(track: track, id: clip, name: "Hook", length: 1_920),
            .addNotes(clip, [Note(pitch: 64, velocity: 90, start: 0, length: 480),
                             Note(pitch: 67, velocity: 80, start: 480, length: 480)]),
            .placeClip(track: track, id: PlacementID(), clip: clip, start: 0),
            .addScene(id: scene, name: "A", index: nil),
            .setSlot(track: track, scene: scene, clip: clip),
            .addMedia(MediaFile(name: "Kick", path: "Media/kick.wav", frameCount: 48_000, sampleRate: 48_000)),
        ]
        for command in commands { try command.apply(to: &project) }
        return project
    }

    /// What every opened file must satisfy: refused, or a song every rule holds for.
    private func assertRefusedOrValid(_ data: Data, _ label: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let project = try? ProjectCodec.decode(data) else { return }
        XCTAssertNoThrow(try project.validate(), label, file: file, line: line)
        for media in project.media {
            XCTAssertTrue(MediaFile.isSafePath(media.path), "\(label): \(media.path)", file: file, line: line)
        }
    }

    // MARK: - Damaged bytes

    /// Cut short, bytes flipped, bytes inserted, a stretch deleted — two thousand times.
    func testADamagedDocumentIsRefusedOrStillAValidSong() throws {
        let valid = try ProjectCodec.encode(song())
        var random = Random(seed: 0x5AFE_5AFE)
        for round in 0..<2_000 {
            var bytes = [UInt8](valid)
            switch round % 4 {
            case 0:
                bytes = Array(bytes.prefix(random.below(bytes.count)))
            case 1:
                for _ in 0...random.below(8) where !bytes.isEmpty {
                    bytes[random.below(bytes.count)] = UInt8(truncatingIfNeeded: random.next())
                }
            case 2:
                let garbage: [UInt8] = (0..<(1 + random.below(16))).map { (_: Int) -> UInt8 in
                    UInt8(truncatingIfNeeded: random.next())
                }
                bytes.insert(contentsOf: garbage, at: random.below(bytes.count + 1))
            default:
                let start = random.below(bytes.count)
                let end = Swift.min(bytes.count, start + 1 + random.below(64))
                bytes.removeSubrange(start..<end)
            }
            assertRefusedOrValid(Data(bytes), "round \(round)")
        }
    }

    /// Not a song at all, or a song in the wrong shape: thrown, every one.
    func testMalformedJSONIsRefused() {
        let samples: [String] = [
            "", " ", "{", "}", "[]", "null", "true", "\"song\"", "42",
            "\u{FEFF}{", "{\"formatVersion\": }",
            "{\"formatVersion\": \"2\"}",
            "{\"formatVersion\": 2}",
            "{\"formatVersion\": 2.5}",
            "{\"formatVersion\": 99999999999999999999999999}",
            "{\"formatVersion\": -1}",
            "{\"formatVersion\": 2, \"name\": \"x\", \"tempo\": 1e999}",
            "{\"formatVersion\": 2, \"name\": \"x\", \"tempo\": NaN}",
            "{\"formatVersion\": 2, \"tracks\": {}}",
            "{\"formatVersion\": 2, \"tracks\": [null]}",
        ]
        for sample in samples {
            XCTAssertThrowsError(try ProjectCodec.decode(Data(sample.utf8)), sample)
        }
        let binary = Data((0..<4_096).map { (index: Int) -> UInt8 in UInt8(truncatingIfNeeded: index &* 31 &+ 7) })
        XCTAssertThrowsError(try ProjectCodec.decode(binary))
    }

    /// Nesting two thousand deep where a name belongs: refused by the parser, not by the stack.
    func testDeeplyNestedJSONIsRefused() {
        let depth = 2_000
        let nested = String(repeating: "[", count: depth) + String(repeating: "]", count: depth)
        let document = "{\"formatVersion\": 2, \"name\": \(nested)}"
        XCTAssertThrowsError(try ProjectCodec.decode(Data(document.utf8)))
    }

    // MARK: - Huge

    /// Larger than a song document can be: refused by its size, before a byte of it is parsed.
    func testADocumentOverTheSizeLimitIsRefusedBeforeItIsParsed() throws {
        var data = try ProjectCodec.encode(song())
        data.append(Data(repeating: 0x20, count: ProjectCodec.maximumDocumentBytes + 1 - data.count))
        XCTAssertEqual(data.count, ProjectCodec.maximumDocumentBytes + 1)
        XCTAssertThrowsError(try ProjectCodec.decode(data)) { error in
            XCTAssertEqual(error as? ProjectCodec.DecodeError, .tooLarge(bytes: ProjectCodec.maximumDocumentBytes + 1))
        }
        data.removeLast()
        XCTAssertNoThrow(try ProjectCodec.decode(data), "at the limit, trailing white space, still the song")
    }

    /// On disk, the size is read from the file system: a document claiming gigabytes is refused
    /// without reading it, and the copy one save back is held to the same limit.
    func testAPackageWithAHugeDocumentIsRefusedWithoutReadingIt() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("robust-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = ProjectLibrary(directory: directory)
        let url = library.newURL(for: "Huge")
        try library.write(song(), to: url)
        let document = url.appendingPathComponent(ProjectLibrary.documentName)
        let handle = try FileHandle(forWritingTo: document)
        // Sparse: the file system reports the size, the disk holds almost nothing.
        try handle.truncate(atOffset: UInt64(ProjectCodec.maximumDocumentBytes) * 32)
        try handle.close()
        XCTAssertThrowsError(try library.read(url)) { error in
            guard case .tooLarge = error as? ProjectCodec.DecodeError else { return XCTFail("\(error)") }
        }
        XCTAssertThrowsError(try library.readRecovering(url), "no previous copy to fall back on")
    }

    /// Fifty thousand scenes that share one id: refused by the rule against duplicates, whole.
    func testAHugeArrayOfDuplicatesIsRefused() throws {
        var project = try song()
        let scene = try XCTUnwrap(project.scenes.first)
        project.scenes = Array(repeating: scene, count: 50_000)
        let data = try ProjectCodec.encode(project)
        XCTAssertLessThan(data.count, ProjectCodec.maximumDocumentBytes)
        XCTAssertThrowsError(try ProjectCodec.decode(data)) { error in
            guard case .invalidContent = error as? ProjectCodec.DecodeError else { return XCTFail("\(error)") }
        }
    }

    // MARK: - Paths out of the package

    /// Every spelling of a way out of `Media/`, written into the document by hand: refused at
    /// open, and never resolved to a file.
    func testAMediaPathThatLeavesThePackageIsRefused() throws {
        let package = URL(fileURLWithPath: "/songs/Song.echoel", isDirectory: true)
        let escapes = [
            "../../etc/passwd", "/etc/passwd", "Media/../../x.wav", "Media/../project.json", "Media/./x.wav",
            "Media//x.wav", "Media/", "Media", "media/x.wav", "Other/x.wav", "Media\\..\\..\\x.wav", "./Media/x.wav",
            "Media/x\u{0}.wav", "Media/x\n.wav", "Media/\u{7F}.wav", "~/x.wav",
        ]
        for path in escapes {
            var project = try song()
            project.media[0].path = path
            let data = try ProjectCodec.encode(project)
            XCTAssertThrowsError(try ProjectCodec.decode(data), path) { error in
                guard case .invalidContent = error as? ProjectCodec.DecodeError else { return XCTFail("\(path): \(error)") }
            }
            XCTAssertNil(project.media[0].url(in: package), path)
        }
        XCTAssertNotNil(MediaFile(name: "x", path: "Media/%2e%2e/x.wav", frameCount: 1, sampleRate: 48_000).url(in: package),
                        "percent signs are a file name here, not an escape: it stays inside")
    }

    /// A crafted package may hold a link under `Media/` pointing out of it — the path reads as
    /// inside, the file is elsewhere. Neither a linked file nor a linked folder resolves.
    func testALinkInsideThePackageDoesNotResolve() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("links-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: root) }
        let outside = root.appendingPathComponent("outside.wav")
        let package = root.appendingPathComponent("Song.echoel", isDirectory: true)
        let media = package.appendingPathComponent(MediaFile.directory, isDirectory: true)
        try fileManager.createDirectory(at: media, withIntermediateDirectories: true)
        try Data("secret".utf8).write(to: outside)
        try Data("sound".utf8).write(to: media.appendingPathComponent("real.wav"))
        try fileManager.createSymbolicLink(at: media.appendingPathComponent("link.wav"), withDestinationURL: outside)
        try fileManager.createSymbolicLink(at: media.appendingPathComponent("folder"), withDestinationURL: root)

        func file(_ path: String) -> MediaFile { MediaFile(name: "x", path: path, frameCount: 1, sampleRate: 48_000) }
        XCTAssertEqual(file("Media/real.wav").url(in: package)?.lastPathComponent, "real.wav")
        XCTAssertNotNil(file("Media/new.wav").url(in: package), "a file about to be imported resolves")
        XCTAssertNil(file("Media/link.wav").url(in: package), "a linked file")
        XCTAssertNil(file("Media/folder/outside.wav").url(in: package), "a file under a linked folder")

        let linkedMedia = root.appendingPathComponent("Linked.echoel", isDirectory: true)
        try fileManager.createDirectory(at: linkedMedia, withIntermediateDirectories: true)
        try fileManager.createSymbolicLink(at: linkedMedia.appendingPathComponent(MediaFile.directory), withDestinationURL: root)
        XCTAssertNil(file("Media/outside.wav").url(in: linkedMedia), "the Media folder itself a link")
    }
}
