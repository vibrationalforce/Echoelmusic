import Foundation
import XCTest
@testable import EchoelCore

/// The instrument-pack catalogue is an untrusted document: it is read whole or refused whole, and
/// each pack is then checked on its own, so one bad pack never takes the others with it.
final class InstrumentPackTests: XCTestCase {
    private let policy = InstrumentPackPolicy.recommended
    private let digest = String(repeating: "ab", count: 32)

    private func file(_ path: String, bytes: Int = 1_000) -> InstrumentPackFile {
        InstrumentPackFile(path: path, url: "https://raw.githubusercontent.com/owner/packs/main/felt/" + path,
                           bytes: bytes, sha256: digest)
    }

    private func pack(_ id: String = "echoel.felt-piano", licence: String = "CC0-1.0",
                      files: [InstrumentPackFile]? = nil, mapping: String = "felt.sfz") -> InstrumentPackEntry {
        InstrumentPackEntry(id: id, name: "Felt Piano", category: "keys", licence: licence, author: "Echoel",
                            version: 1, mapping: mapping,
                            files: files ?? [file("felt.sfz"), file("samples/c4.wav"), file("samples/c5.wav")])
    }

    private func json(_ manifest: InstrumentPackManifest) throws -> Data {
        try JSONEncoder().encode(manifest)
    }

    func testACatalogueOfGoodPacksIsAcceptedWhole() throws {
        let manifest = InstrumentPackManifest(packs: [pack(), pack("echoel.nylon-guitar", licence: "CC-BY-4.0")])
        let read = try InstrumentPackManifest.decode(try json(manifest))
        XCTAssertEqual(read.undecodable, 0)
        XCTAssertEqual(read.manifest, manifest)
        let checked = read.manifest.checked(by: policy)
        XCTAssertEqual(checked.accepted.map(\.id), ["echoel.felt-piano", "echoel.nylon-guitar"])
        XCTAssertTrue(checked.refused.isEmpty)
        XCTAssertEqual(checked.accepted[0].kind, .keys)
        XCTAssertEqual(checked.accepted[0].totalBytes, 3_000)
    }

    func testAPackThatDoesNotDecodeFallsOutAlone() throws {
        let good = String(decoding: try JSONEncoder().encode(pack()), as: UTF8.self)
        let text = "{\"schema\":1,\"packs\":[" + good + ",{\"id\":\"broken\"}," + good + "]}"
        let read = try InstrumentPackManifest.decode(Data(text.utf8))
        XCTAssertEqual(read.undecodable, 1)
        XCTAssertEqual(read.manifest.packs.count, 2)
        // Of two packs with one id the first stays.
        let checked = read.manifest.checked(by: policy)
        XCTAssertEqual(checked.accepted.count, 1)
        XCTAssertEqual(checked.refused, [InstrumentPackRefusal(id: "echoel.felt-piano", problem: .duplicateID)])
    }

    func testADocumentThatIsNoCatalogueIsRefusedWhole() throws {
        XCTAssertThrowsError(try InstrumentPackManifest.decode(Data("not json".utf8))) {
            XCTAssertEqual($0 as? InstrumentPackError, .notACatalogue)
        }
        XCTAssertThrowsError(try InstrumentPackManifest.decode(Data("{\"schema\":1}".utf8))) {
            XCTAssertEqual($0 as? InstrumentPackError, .notACatalogue)
        }
        let later = InstrumentPackManifest(schema: 2, packs: [pack()])
        XCTAssertThrowsError(try InstrumentPackManifest.decode(try json(later))) {
            XCTAssertEqual($0 as? InstrumentPackError, .unsupportedSchema(2))
        }
        let huge = Data(repeating: 0x20, count: InstrumentPackManifest.maximumBytes + 1)
        XCTAssertThrowsError(try InstrumentPackManifest.decode(huge)) {
            XCTAssertEqual($0 as? InstrumentPackError, .tooLarge)
        }
    }

    func testOnlyTheAllowedLicencesAreOffered() {
        for licence in ["CC0-1.0", "CC-BY-4.0"] {
            XCTAssertNil(policy.problem(with: pack(licence: licence)), licence)
        }
        // NC forbids selling a song, SA forces its licence on the song, ND forbids changing the sound.
        for licence in ["CC-BY-NC-4.0", "CC-BY-SA-4.0", "CC-BY-ND-4.0", "GPL-3.0-only", "cc0-1.0", ""] {
            XCTAssertEqual(policy.problem(with: pack(licence: licence)), .licenceNotAllowed(licence), licence)
        }
    }

    func testAPathMustStayInsideThePack() {
        for path in ["../felt.wav", "/felt.wav", "samples//c4.wav", "samples\\c4.wav", "samples/./c4.wav",
                     "samples/../../c4.wav", "c4\u{0}.wav", "file:c4.wav", "", String(repeating: "a", count: 197) + ".wav",
                     "samples/", "samples/.hidden.wav", " c4.wav", "samples /c4.wav", "c4.wav.", "a%2Fb.wav", "~c4.wav",
                     "c4*.wav", "fl\u{00E9}te.wav", "c4\u{FF0E}wav", "a\u{0301}.wav"] {
            let files = [file("felt.sfz"), file(path)]
            XCTAssertEqual(policy.problem(with: pack(files: files)), .badPath(path), path)
        }
        XCTAssertTrue(InstrumentPackPolicy.isSafePath("samples/Felt Piano/c4.wav"))
        XCTAssertTrue(InstrumentPackPolicy.isSafePath("Layers (soft)/C#4_v1+2, take 'a' & b.wav"))
        XCTAssertTrue(InstrumentPackPolicy.isSafePath(String(repeating: "a", count: 196) + ".wav"), "200 bytes is the most")
        XCTAssertEqual(policy.problem(with: pack(files: [file("felt.sfz"), file("run.sh")])), .badExtension("run.sh"))
        XCTAssertEqual(policy.problem(with: pack(files: [file("felt.sfz"), file("samples/c4")])), .badExtension("samples/c4"))
        XCTAssertEqual(policy.problem(with: pack(files: [file("felt.sfz"), file("C4.wav"), file("c4.WAV")])),
                       .duplicatePath("c4.WAV"), "one name per file whatever the case")
        // A file never stands where another path needs a folder, in either order.
        XCTAssertEqual(policy.problem(with: pack(files: [file("felt.sfz"), file("s.wav"), file("s.wav/c4.wav")])),
                       .duplicatePath("s.wav/c4.wav"))
        XCTAssertEqual(policy.problem(with: pack(files: [file("felt.sfz"), file("s.wav/c4.wav"), file("S.wav")])),
                       .duplicatePath("S.wav"))
        XCTAssertEqual(policy.problem(with: pack(files: [file("felt.sfz"), file("felt.sfz/x.wav")])),
                       .duplicatePath("felt.sfz/x.wav"), "the zone map is a file, not a folder")
        XCTAssertEqual(InstrumentPackPolicy.folders(of: "a/b/c.wav"), ["a", "a/b"])
        XCTAssertNil(policy.problem(with: pack(files: [file("felt.sfz"), file("a/c4.wav"), file("a/b/c5.wav")])),
                     "two files may share a folder")
    }

    func testAFileComesOnlyOverHTTPSFromTheNamedHost() {
        let base = "raw.githubusercontent.com/owner/packs/main/c4.wav"
        for url in ["http://" + base, "ftp://" + base, "https://user@" + base, "https://user:pw@" + base,
                    "https://raw.githubusercontent.com:8443/owner/c4.wav", "https://example.com/c4.wav",
                    "https://raw.githubusercontent.com", "https://raw.githubusercontent.com.example.com/c4.wav", "c4.wav",
                    "https://raw.githubusercontent.com/", "https://" + base + "?token=1", "https://" + base + "#part",
                    "https://raw.githubusercontent.com/owner/c 4.wav", "https://raw.githubusercontent.com/owner\\c4.wav",
                    "https://raw%2Egithubusercontent.com/owner/c4.wav", "https://raw.githubusercontent.com/owner/c4.wav\n"] {
            var bad = file("samples/c4.wav")
            bad.url = url
            XCTAssertEqual(policy.problem(with: pack(files: [file("felt.sfz"), bad])), .urlNotAllowed(url), url)
        }
        XCTAssertTrue(policy.isAllowedURL("https://RAW.githubusercontent.com:443/owner/c4.wav"), "host case and the standard port")
        let plain = "https://" + base
        XCTAssertEqual(policy.allowedURL(plain)?.absoluteString, plain, "the URL to fetch is the one that was checked")
        XCTAssertTrue(policy.isAllowedURL("https://raw.githubusercontent.com/owner/Felt%20Piano%20C%234.wav"), "a path may be percent-encoded")
    }

    func testSizesAndChecksumsAreWhatTheyClaim() {
        XCTAssertEqual(policy.problem(with: pack(files: [file("felt.sfz"), file("c4.wav", bytes: 0)])), .badSize("c4.wav"))
        XCTAssertEqual(policy.problem(with: pack(files: [file("felt.sfz"), file("c4.wav", bytes: -1)])), .badSize("c4.wav"))
        XCTAssertEqual(policy.problem(with: pack(files: [file("felt.sfz"), file("c4.wav", bytes: policy.maximumFileBytes + 1)])),
                       .badSize("c4.wav"))
        let many = (0..<5).map { file("s\($0).wav", bytes: policy.maximumFileBytes) } + [file("felt.sfz")]
        XCTAssertEqual(policy.problem(with: pack(files: many)), .packTooLarge)
        let overflowing = InstrumentPackEntry(id: "echoel.huge", name: "Huge", category: "keys", licence: "CC0-1.0",
                                              author: "Echoel", version: 1, mapping: "felt.sfz",
                                              files: [file("a.wav", bytes: Int.max), file("b.wav", bytes: Int.max)])
        XCTAssertEqual(overflowing.totalBytes, Int.max)
        for sha in [String(repeating: "a", count: 63), String(repeating: "g", count: 64), ""] {
            var bad = file("c4.wav")
            bad.sha256 = sha
            XCTAssertEqual(policy.problem(with: pack(files: [file("felt.sfz"), bad])), .badChecksum("c4.wav"), sha)
        }
        var upper = file("c4.wav")
        upper.sha256 = String(repeating: "AB", count: 32)
        XCTAssertNil(policy.problem(with: pack(files: [file("felt.sfz"), upper])))
        XCTAssertEqual(upper.checksum, digest, "compared in lowercase")
    }

    func testThePackItselfNamesItsIdentityAndItsZoneMap() {
        for id in ["ab", "Echoel.piano", "1piano", "echoel..piano", "echoel.piano.", "echoel.piano-", "echoel/piano",
                   "echoel piano", String(repeating: "a", count: 65)] {
            XCTAssertEqual(policy.problem(with: pack(id)), .badID, id)
        }
        var unnamed = pack()
        unnamed.name = "   "
        XCTAssertEqual(policy.problem(with: unnamed), .badName)
        for hidden in ["Felt\u{200B}Piano", "Felt\u{202E}Piano", "Felt\u{3164}Piano", "Felt\nPiano", String(repeating: "a", count: 65)] {
            var disguised = pack()
            disguised.name = hidden
            XCTAssertEqual(policy.problem(with: disguised), .badName, hidden.unicodeScalars.map { String($0.value, radix: 16) }.joined(separator: " "))
        }
        var accented = pack()
        accented.name = "Flöte, weich"
        XCTAssertNil(policy.problem(with: accented), "a name may be in any script; only what is hidden is refused")
        var noAuthor = pack()
        noAuthor.author = ""
        XCTAssertEqual(policy.problem(with: noAuthor), .missingAuthor)
        var badVersion = pack()
        badVersion.version = 0
        XCTAssertEqual(policy.problem(with: badVersion), .badVersion)
        XCTAssertEqual(policy.problem(with: pack(files: [])), .noFiles)
        XCTAssertEqual(policy.problem(with: pack(mapping: "missing.sfz")), .mappingMissing)
        XCTAssertEqual(policy.problem(with: pack(mapping: "samples/c4.wav")), .mappingMissing, "the map is .sfz or .json")
        XCTAssertEqual(policy.problem(with: pack(mapping: "Felt.SFZ")), .mappingMissing, "named exactly as its file is")
        XCTAssertNil(policy.problem(with: pack(files: [file("map.json"), file("c4.wav")], mapping: "map.json")))
        var other = pack()
        other.category = "theremins"
        XCTAssertEqual(other.kind, .other, "an unknown category word reads as other")
        let tooMany = (0...policy.maximumFiles).map { file("s\($0).wav") }
        XCTAssertEqual(policy.problem(with: pack(files: tooMany)), .tooManyFiles)
    }
}
