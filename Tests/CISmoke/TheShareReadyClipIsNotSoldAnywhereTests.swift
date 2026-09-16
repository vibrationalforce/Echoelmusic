// TheShareReadyClipIsNotSoldAnywhereTests.swift
// Echoel — #1318. Blocking bundle. Claims 1–3 are FILE-CONTENT SCANS over copy
// (`Tests/CISmoke/CLAUDE.md` §1): they prove what the text says, never what the app does.
// Claim 4 is the one that scans BEHAVIOUR-bearing code, and even it is a source-text scan —
// it pins the premise (no video writer exists) that makes claims 1–2 correct rather than
// merely tidy. Whether the shipped app feels honest to a reader is a DEVICE PROBE and is
// named here as open.
//
// ⭐ WHY THIS FILE EXISTS, AND THE SYMPTOM IS NOT THE DEFECT. The symptom was one sentence:
// the in-app Learn guide's "See it" entry still ended "You can record it as a share-ready
// video." — a capability #1304 deleted on 2026-09-12 ("Kein Video Capture"). The DEFECT is
// that the same phrase family stood unguarded in THREE different copy surfaces at once
// (`Sources/Echoelmusic/Studio/LearnLibrary.swift`, `docs/overview.html`,
// `docs/dev/APP_STORE_LISTING_v1.md`) while THREE separate guards each held their own
// hand-typed needle list — and not one of the three lists could match it:
//
//   · `TheStoreTextClaimsOnlyWhatShipsTests` reads `fastlane/metadata/**` and nothing else.
//     Its #1304 needles are "video capture", "video recording", "record the visual" and
//     "share-ready mp4"; none is a substring of "record it as a share-ready video".
//   · `WebsitePagesAreFindableAndHonestTests` bans PRESENT-TENSE selling spellings over
//     `docs/*.html`, among them the ADJECTIVE form "recordable as a share-ready clip" —
//     which is exactly one word away from `overview.html`'s VERB form "you can record as a
//     share-ready clip", and `docs/dev/**` is not in its page set at all.
//   · `TheGuideNamesOnlyRealControlsTests` reads the Learn corpus, but only to assert that
//     controls it NAMES still EXIST. It carries no retracted-capability scan whatsoever, so
//     the in-app copy — the most reachable of the three, behind a live door — was in no such
//     scan at any point.
//
// The repair is therefore not a fourth hand-typed list. It is ONE list (`soldAsVideo`) run
// over ALL FOUR copy surfaces (#416: one definition per decision). Three lists that each
// almost match are how a claim survives three guards.
//
// ⚠️ WHY THE BAN IS ON THE VIDEO NOUN, NOT ON "share-ready" (#364). `EchoelStudioView.swift`
// legitimately says "share-ready file" about the WAV/MIDI export, which ships. Banning the
// bare phrase would forbid correct work the next time someone writes an honest export
// sentence. What is banned is "share-ready" paired with a video artifact — a video, a clip,
// an mp4 — because no such artifact can be produced. Claim 3 pins that scoping by asserting
// the legitimate audio spelling is still there: a tree that "fixed" this by purging the
// phrase everywhere goes red.
//
// ⚠️ ONE STRING IS DELIBERATELY SHARED WITH ANOTHER GUARD. "share-ready mp4" also sits in
// `TheStoreTextClaimsOnlyWhatShipsTests`'s #1304 list. That is not the two-spellings defect
// #416 names: the other guard reads ONLY `fastlane/metadata/**`, so for the three corpora it
// never opens this is the sole coverage. Removing it here would reopen the hole for the
// published site and for the in-app guide.
//
// ⚠️ THE LEARN CORPUS IS READ THROUGH `SourceText.codeOnly` ON PURPOSE (#453/#460/#477, and
// #491). A comment in that file already records an earlier retraction and says it could not
// quote the wording it was retracting, because the guard scanning it read the whole file.
// Blanking comments makes a retraction able to name what it retracts without becoming the
// offence — so #1318's tombstone quotes the deleted sentence verbatim.
//
// ⚠️ WHY `docs/dev/APP_STORE_LISTING_v1.md` IS NAMED BY PATH while the other three corpora
// are derived from their directories (#768/#769). `docs/dev/` also holds deliberate history
// — `DMMW_ARCHITECTURE.md` is superseded-but-kept, `BROADCAST_HAISHINKIT_FINISH.md` plans an
// unlinked dependency — where a struck phrase may legitimately appear in a record of what
// was cut. Scanning that whole directory would forbid correct work. The listing draft is
// different in kind: it is the text a session pastes INTO `fastlane/metadata/**`, and it had
// already drifted from it (the shipped metadata never carried this sentence).
//
// ⚠️ HONEST GRADING. No local Swift toolchain (§0). **11 assertions across four claims** —
// stated rather than left to be counted (claim 1 = 2, claim 2 = 2, claim 3 = 4, claim 4 = 3).
// All eleven were transcribed in Python and driven against BOTH trees. On the PARENT tree
// (`016c5b3`) **2 assertions are red** and they cover **three distinct false sentences** in
// three files — three findings, not one absence counted three times (#486 does not apply:
// these are independent sentences, not one missing symbol seen from several angles). On
// today's tree all 11 are green. The other 9 are COUNTERWEIGHTS (#343): they pin that the
// corpora are still the real corpora, that the honest audio spelling survives, that the
// site's denials still stand, and that no video writer has returned — so claims 1–2 can
// never be a vacuous green on a tree that deleted the copy instead of correcting it.
//
// ⚠️ THE STRIPPER IS LOAD-BEARING, AND IT IS MEASURED (§2 — three slices in a row claimed
// this without measuring and had to retract). Each needle was counted raw vs. stripped on both
// trees. Claim 1: **TRAGEND, 1 of 4 verdicts flips** — "share-ready video" is present raw and
// absent stripped on today's tree, because #1318's tombstone in `LearnLibrary.swift` quotes the
// sentence it deleted. Claim 4: **TRAGEND, 1 of 3 flips**, and that one is this slice's own
// doing too — the same tombstone names `AVCaptureMovieFileOutput` while explaining that no such
// thing exists. Without `SourceText.codeOnly` this guard would be red on its own retraction.
//
// ⚠️ WHAT GOES RED IF VIDEO EVER RETURNS. Claim 4, by design. A tree that re-adds a video
// writer must re-word this guard in the SAME commit — the ban would then be forbidding
// correct work (#364), and the copy would need to say what ships. The message says so.
import XCTest

final class TheShareReadyClipIsNotSoldAnywhereTests: XCTestCase {

    /// The phrase family, defined ONCE for every copy surface (#416).
    ///
    /// Lower-cased; every corpus is lower-cased before matching, so a capitalised spelling
    /// in a heading cannot slip past.
    private static let soldAsVideo = [
        "share-ready video",
        "share-ready clip",
        "share-ready mp4",
        "teilbares video",
    ]

    private static let learnPath = "Sources/Echoelmusic/Studio/LearnLibrary.swift"
    private static let listingDraftPath = "docs/dev/APP_STORE_LISTING_v1.md"

    // MARK: - claim 1 — the in-app guide

    /// The Learn guide renders unconditionally behind a live door, which makes it the most
    /// reachable copy in the product and the one surface that was in no scan at all.
    func testTheInAppGuideSellsNoShareReadyVideo() throws {
        let code = SourceText.codeOnly(try text(Self.learnPath))
        XCTAssertTrue(code.contains("id: \"guide.see\""), """
            ANCHOR MISSING: \(Self.learnPath) no longer declares the `guide.see` entry, so the \
            scan below would pass over a file that lost the thing it guards (#454). If the \
            entry was renamed, re-point this anchor in the SAME commit.
            """)
        let offenders = Self.offenders(in: [(Self.learnPath, code)])
        XCTAssertTrue(offenders.isEmpty, """
            The in-app Learn guide sells a capability #1304 removed: \
            \(offenders.joined(separator: ", ")).

            Nothing under `Sources/` can write a video — the only `AVAssetWriter` is in \
            `Audio/SingleExport.swift` with `mediaType: .audio` (claim 4 pins this). Delete \
            the sentence; do not soften it. A user reads this text inside the app, which is a \
            worse place for a false claim than the store listing, because it is read AFTER \
            they went looking for the button.
            """)
    }

    // MARK: - claim 2 — everything a reader or a reviewer sees

    /// The published site, the submitted store metadata, and the draft the metadata is
    /// pasted from — one list over all three, plus the in-app guide above.
    func testNoPublishedSurfaceSellsAShareReadyVideo() throws {
        var corpus = try publishedPages()
        corpus += try storeMetadata()
        corpus.append((Self.listingDraftPath, try text(Self.listingDraftPath)))
        XCTAssertGreaterThanOrEqual(corpus.count, 20, """
            Only \(corpus.count) copy files were read; `docs/` alone holds twenty-odd pages \
            and `fastlane/metadata/` two locales. A scan this thin would report "clean" \
            because it opened almost nothing — a measurement that can silently return LESS \
            than the truth is not a measurement.
            """)
        let offenders = Self.offenders(in: corpus)
        XCTAssertTrue(offenders.isEmpty, """
            A published or submitted surface sells a capability this repo removed: \
            \(offenders.joined(separator: ", ")).

            Video recording went with #1304 (founder 2026-09-12) and video editing with #121 \
            Slice 3; RTMP was never linked. On the App Store a false capability claim is a 2.3 \
            rejection, and #184 already removed twelve of them from this text. Say what ships: \
            `docs/architecture.html` has the wording the rest of the site follows.
            """)
    }

    // MARK: - claim 3 — counterweights: the ban is scoped, the denials still stand

    /// Four premises without which claims 1–2 would be green on a tree that deleted the copy
    /// rather than correcting it, or that purged the honest sentence along with the false one.
    func testTheBanIsScopedToVideoAndTheDenialsSurvive() throws {
        XCTAssertTrue(try text("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
            .contains("share-ready file"), """
            The WAV/MIDI export's own "share-ready file" wording is gone. That spelling is \
            LEGITIMATE — the export ships — and this assertion exists so the ban above stays \
            scoped to the video nouns instead of eating the honest sentence with them (#364).
            """)
        XCTAssertTrue(try text("docs/architecture.html").contains("never captured"), """
            `docs/architecture.html` no longer carries the denial the rest of the site is \
            worded against. A ban on the false claim is worth nothing if the pages can satisfy \
            it by saying nothing at all.
            """)
        XCTAssertTrue(try text("docs/faq.html").contains("Video is not part of Echoelmusic"), """
            The FAQ's flat statement that video is not part of Echoelmusic is gone. Same \
            reason as the architecture denial: silence must not be a way to pass this file.
            """)
        XCTAssertTrue(SourceText.codeOnly(try text(Self.learnPath))
            .contains("The picture breathes with you"), """
            The `guide.see` entry lost its body. The correct repair for #1318 was to delete ONE \
            sentence, not the entry — the visual IS live and playable, and the guide is where a \
            newcomer learns that.
            """)
    }

    // MARK: - claim 4 — the premise: nothing here can write a video

    /// This is what makes claims 1–2 a statement about the product rather than about tidiness.
    func testNothingUnderSourcesCanWriteAVideo() throws {
        let files = try sourceSwiftFiles()
        XCTAssertGreaterThan(files.count, 200, """
            Only \(files.count) Swift files were walked under `Sources/`; the tree holds well \
            over three hundred, so an "absent" verdict here would be vacuous.
            """)
        var offenders: [String] = []
        for file in files {
            let code = SourceText.codeOnly(file.text)
            for needle in ["AVCaptureMovieFileOutput", "RPScreenRecorder",
                           "AVAssetWriterInput(mediaType: .video"] where code.contains(needle) {
                offenders.append("\(file.path): \(needle)")
            }
        }
        XCTAssertTrue(offenders.isEmpty, """
            `Sources/` constructs a video writer again: \(offenders.joined(separator: ", ")).

            That is not a failure of this guard — it is this guard asking for a decision. If \
            video recording came back on purpose, the copy must say so and THIS FILE must be \
            re-worded in the SAME commit, because its ban would now be forbidding correct work \
            (#364). If it came back by accident, it is the founder's call (#1304: "Kein Video \
            Capture").
            """)
        XCTAssertTrue(try text("Sources/Echoelmusic/Audio/SingleExport.swift")
            .contains("AVAssetWriterInput(mediaType: .audio"), """
            `SingleExport` no longer declares an AUDIO writer input. The whole premise of this \
            file is that the one `AVAssetWriter` in the tree writes audio; if that moved, \
            re-anchor here rather than letting claim 4 pass on a file that changed shape.
            """)
    }

    // MARK: - matching

    private static func offenders(in corpus: [(path: String, text: String)]) -> [String] {
        var out: [String] = []
        for file in corpus {
            let flat = file.text.lowercased()
            for needle in soldAsVideo where flat.contains(needle) {
                out.append("\(file.path): \"\(needle)\"")
            }
        }
        return out
    }

    // MARK: - corpora (three derived from directories, one named — see the header)

    private func repoRoot() throws -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let fm = FileManager.default
        guard fm.fileExists(atPath: root.appendingPathComponent("docs").path),
              fm.fileExists(atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("repo tree not present under \(root.path)")
        }
        return root
    }

    private func text(_ relative: String) throws -> String {
        let url = try repoRoot().appendingPathComponent(relative)
        guard let body = try? String(contentsOf: url, encoding: .utf8),
              !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            XCTFail("ANCHOR MISSING: \(relative) could not be read or is empty — a missing "
                    + "anchor is a finding, not a pass (#454).")
            return ""
        }
        return body
    }

    private func publishedPages() throws -> [(path: String, text: String)] {
        let dir = try repoRoot().appendingPathComponent("docs")
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        var out: [(path: String, text: String)] = []
        for name in names.sorted() where name.hasSuffix(".html") {
            let rel = "docs/\(name)"
            out.append((path: rel, text: try text(rel)))
        }
        return out
    }

    private func storeMetadata() throws -> [(path: String, text: String)] {
        let base = try repoRoot().appendingPathComponent("fastlane/metadata")
        let fm = FileManager.default
        let locales = (try? fm.contentsOfDirectory(atPath: base.path)) ?? []
        var out: [(path: String, text: String)] = []
        for locale in locales.sorted() {
            let localePath = base.appendingPathComponent(locale).path
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: localePath, isDirectory: &isDirectory),
                  isDirectory.boolValue else { continue }
            let leaves = (try? fm.contentsOfDirectory(atPath: localePath)) ?? []
            for leaf in leaves.sorted() where leaf.hasSuffix(".txt") {
                let rel = "fastlane/metadata/\(locale)/\(leaf)"
                out.append((path: rel, text: try text(rel)))
            }
        }
        return out
    }

    private func sourceSwiftFiles() throws -> [(path: String, text: String)] {
        let base = try repoRoot().appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(atPath: base.path) else { return [] }
        var out: [(path: String, text: String)] = []
        for case let rel as String in walker where rel.hasSuffix(".swift") {
            guard let body = try? String(contentsOf: base.appendingPathComponent(rel),
                                         encoding: .utf8) else { continue }
            out.append((path: "Sources/\(rel)", text: body))
        }
        return out
    }
}
