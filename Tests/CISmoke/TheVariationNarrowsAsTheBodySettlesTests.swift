// TheVariationNarrowsAsTheBodySettlesTests.swift
// Echoel — the G3 variation axis obeys the body's polarity and cannot reach a genre's identity.
//
// KIND: MIXED. Claims 1–3 and 6 are BEHAVIOUR on the pure `IdiomControl` maths; claims 4–5 are a
// SOURCE-TEXT SCAN.
//
// ⭐ WHY THIS FILE IS NOT VACUOUS TODAY, even though every genre resolves to `nil`. `IdiomControl`
// is a pure value type: an envelope can be BUILT here and its selection exercised, so the law
// this slice ships — a settled body gets the genre's own answer, an unsettled one gets the
// breadth — is measurable before any genre claims it. That matters because the polarity is the
// easiest thing in this design to get backwards, it reads plausible either way, and the wrong
// direction would reproduce the exact complaint that started the work (#81/#125: "erst eine
// individuelle Variation und dann klingt plötzlich alles gleich"). `genreAnchorCount` carries
// the same polarity for the same reason; this is its second surface, not a new idea.
//
// ⛔ THE NEGATIVE PIN IS THE OTHER HALF, and it is the one a future batch will push against.
// Three `HarmonicProfile` fields are FORBIDDEN to a variant: `arpeggiated` and `sustained` are
// what make a Fläche a Fläche — a "variation" that flips either has replaced the genre rather
// than performed it — and `leadDensity` would wake the five sleeping lead paths that
// `LeadRoleAbsenceTests` keeps asleep. An envelope carries roots, register and cells and must
// never grow a fourth field that reaches a profile. The scan below is on the TYPES, so it goes
// red on the commit that adds such a field rather than on the one that first uses it.
//
// ⚠️ HONEST GRADING (§0/§3): every claim is a REGRESSION on the parent for its named reason —
// `GenreIdiom.swift` does not exist there, so the file does not compile against that tree at
// all. That is ONE absence (#486), and it is why the transcription grades these against the
// worktree only and says so rather than reporting six findings.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheVariationNarrowsAsTheBodySettlesTests: XCTestCase {

    private static let idiomFile = "Sources/Echoelmusic/Sequencer/GenreIdiom.swift"
    private static let composerFile = "Sources/Echoelmusic/Sequencer/BioComposer.swift"

    /// Four legal entry points, written in the genre's own order of canonicity — index 0 is the
    /// answer a settled body must always hear.
    private static let fourWide = VariationEnvelope(rootOffsets: [0, 1, 2, 3],
                                                    registerDrift: -1...1,
                                                    cellChoices: [0, 1])

    private func control(_ idiom: GenreIdiom, amount: Float, seed: UInt64) -> IdiomControl {
        IdiomControl(idiom: idiom, envelope: Self.fourWide, seed: seed, amount: amount)
    }

    // MARK: - claim 1 (BEHAVIOUR) — a settled body hears the canonical option

    /// `amount` at the floor with four options opens a window of `ceil(4 × 0.25) = 1`, i.e. only
    /// index 0. Swept over many seeds because a single seed landing on 0 would prove nothing.
    func testASettledBodyAlwaysGetsTheGenresOwnAnswer() {
        for seed in UInt64(0)..<UInt64(400) {
            let c = control(.modalDrift, amount: 0.25, seed: seed &* 0x9E37)
            XCTAssertEqual(c.rootOffset, 0, """
                At the variation floor the take reached past the genre's own first answer \
                (seed \(seed)). A settling body is exactly the state in which a listener \
                judges whether the genre is itself — this polarity being backwards is the \
                #81/#125 complaint, rebuilt.
                """)
        }
    }

    // MARK: - claim 2 (BEHAVIOUR) — an unsettled body can reach the whole envelope

    /// The counterweight to claim 1 (#343/#367): if the window never widened, claim 1 would be
    /// green for the wrong reason and the axis would be decoration.
    func testAnUnsettledBodyReachesEveryLegalOption() {
        var seen = Set<Int>()
        for seed in UInt64(0)..<UInt64(400) {
            seen.insert(control(.modalDrift, amount: 1.0, seed: seed &* 0x9E37).rootOffset)
        }
        XCTAssertEqual(seen, Set(Self.fourWide.rootOffsets), """
            At full amount the selection reached only \(seen.sorted()) of \
            \(Self.fourWide.rootOffsets). Either the window stopped widening or the hash \
            collapses — both make the envelope narrower than the genre declared it, which is \
            invisible until someone counts.
            """)
    }

    // MARK: - claim 3 (BEHAVIOUR) — `.fixed` and the still envelope never move

    func testFixedAndStillNeverMove() {
        for seed in UInt64(0)..<UInt64(200) {
            XCTAssertEqual(control(.fixed, amount: 1.0, seed: seed).rootOffset, 0,
                           "`.fixed` moved at full amount — unmovingness IS the quality of the genres given it")
            XCTAssertEqual(control(.fixed, amount: 1.0, seed: seed).cellIndex, 0,
                           "`.fixed` chose a different cell")
            let still = IdiomControl(idiom: .modalDrift, envelope: .still, seed: seed, amount: 1.0)
            XCTAssertEqual(still.rootOffset, 0, "the still envelope moved its root")
            XCTAssertEqual(still.registerOffset, 0, "the still envelope moved its register")
            XCTAssertEqual(still.cellIndex, 0, "the still envelope changed its cell")
        }
    }

    // MARK: - claim 4 (SOURCE SCAN) — the polarity is written the way it is measured

    func testThePolarityAndItsFounderQuestionAreInTheSource() throws {
        let code = try source(Self.composerFile)
        XCTAssertTrue(code.contains("amount: Swift.max(varyFloor, 1 - coh)"), """
            The bio → variation mapping has changed shape. `max(varyFloor, 1 - coherence)` is \
            the `genreAnchorCount` polarity; inverting it makes a calm body hear the widest \
            variation, which is the founder complaint this axis exists to answer.
            """)
        let raw = try rawSource(Self.composerFile)
        guard let decl = raw.range(of: "static let varyFloor: Float") else {
            throw AnchorMissing(reason: "`varyFloor` is gone — re-anchor (#454)")
        }
        let around = String(raw[..<decl.lowerBound].suffix(900))
        XCTAssertTrue(around.contains("NEEDS-FOUNDER-VERIFY"), """
            `varyFloor` has lost its founder marker. It is the ONE value on this axis no test \
            can decide — how much a take may differ from the canonical one when the body is \
            perfectly settled — and `scripts/founder-verify.py` prints the ask from that \
            marker. Without it the question silently leaves the queue.
            """)
    }

    // MARK: - claim 5 (SOURCE SCAN) — the three forbidden fields

    func testAVariantCannotReachAProfileField() throws {
        let code = try source(Self.idiomFile)
        for field in ["arpeggiated", "sustained", "leadDensity"] {
            XCTAssertFalse(code.contains(field), """
                `GenreIdiom.swift` now names `\(field)` in CODE. An envelope carries roots, \
                register and cells. `arpeggiated` and `sustained` are what make a Fläche a \
                Fläche, so a variant that flips either has replaced the genre instead of \
                performing it; `leadDensity` would wake the five lead paths \
                `LeadRoleAbsenceTests` keeps asleep. If a batch genuinely needs one of these, \
                that is a founder decision and a plan change, not a field.
                """)
        }
        XCTAssertTrue(code.contains("var idiomProfile: GenreIdiomProfile?"), """
            The genre table is gone from `GenreIdiom.swift`. G5…G15 add an arm to that switch; \
            if it has been collapsed to a bare `return nil` the next batch has nowhere obvious \
            to add one, which is how a table gets rebuilt in a second place.
            """)
    }

    // MARK: - claim 6 (BEHAVIOUR) — a non-finite amount is not a trap

    /// The NaN law (CLAUDE.md): `max(x, y)` passes NaN through, and `Int(_:)` on a NaN traps.
    /// `amount` reaches here from `1 - coherence`, and coherence is a live measurement.
    func testANonFiniteAmountResolvesToStillness() {
        for bad in [Float.nan, Float.infinity, -Float.infinity, Float(-1)] {
            let c = control(.modalDrift, amount: bad, seed: 0xD00D)
            XCTAssertTrue(c.amount.isFinite, "amount \(bad) survived into the control")
            XCTAssertEqual(c.rootOffset, 0, "a non-finite amount must resolve to the canonical option")
        }
    }

    // MARK: - source access (§0/§2)

    private struct AnchorMissing: Error { let reason: String }

    private func rawSource(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path)
        else { throw XCTSkip("source tree not present under \(root.path)") }
        let path = root.appendingPathComponent(relativePath)
        guard let text = try? String(contentsOf: path, encoding: .utf8) else {
            throw AnchorMissing(reason: "\(relativePath) is missing — re-anchor, do not skip (#454)")
        }
        return text
    }

    private func source(_ relativePath: String) throws -> String {
        SourceText.codeOnly(try rawSource(relativePath))
    }
}
