// EveryHiddenSurfaceIsInTheStatusRegisterTests.swift
// Echoel — founder 2026-09-23: "Vermeide dass Sachen versteckt bleiben oder verloren gehen."
//
// `docs/dev/FEATURE_STATUS.md` is the three-bucket register (reachable · built-but-hidden ·
// struck). This guard makes ONE of its buckets impossible to forget: a SwiftUI `View` that is
// declared somewhere under `Sources/` and constructed NOWHERE must be named, in backticks, in
// that register. Unreachable is not itself a defect (several surfaces are parked on purpose);
// unreachable AND unwritten-down is — that is how a working screen becomes a lost one.
//
// ⚠️ IT FORBIDS NOTHING (#364). Parking a view is legal, re-dooring it is legal, deleting it is
// legal. The only red is "a view became unreachable and the register did not move with it", and
// the message names the one line to add.
//
// ⚠️ WHAT IT CANNOT SEE — stated here and in the register's own "Grenzen" section:
// · a view built only by ANOTHER unreachable view (`BreathGuideView` inside `BioSourceView`) —
//   the #947 transitive hop; `scripts/doctor.py --section C` reports those;
// · a view that is built but behind a flag nothing sets (`MeditationView`);
// · a function without a button (`importMIDI` since #W1).
// Those are in the register by hand.
//
// ⚠️ "Constructed" is a TEXT fact: an identifier followed by `(`, `{` or a generic clause, on a
// line that does not DECLARE that name. A mention in a comment does not count (`codeOnly`).
// A name inside a string literal would count — none does today.
//
// HONEST GRADING (§0/§3). No local Swift toolchain. All three claims were transcribed in Python
// (`doctor._code_only` standing in for `SourceText.codeOnly`) and driven against both trees:
// · worktree: 370 files, 97 views, 9 never constructed, all 9 named in the register → green.
// · parent (`dd2493e4e`): the register file does not exist → claim 1 is red by ANCHOR ABSENCE,
//   one finding (#486); claim 3 likewise. Both are FORWARD guards over a file this commit
//   creates — not regressions.
// · claim 2 is a COUNTERWEIGHT (#343) on literal fixtures, green on both trees; it is what makes
//   a green claim 1 mean something — the detector provably sees a construction, a trailing-
//   closure construction, and ignores a comment and an `extension` line.
// SOURCE-TEXT SCAN (§1). Nothing here renders a view.

import Foundation
import XCTest

final class EveryHiddenSurfaceIsInTheStatusRegisterTests: XCTestCase {

    private static let register = "docs/dev/FEATURE_STATUS.md"

    /// Claim 1 — every View that nothing constructs is written down in the register.
    func testEveryUnbuiltViewIsNamedInTheStatusRegister() throws {
        let root = try Self.repoRoot()
        let sources = root.appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(at: sources,
                                                          includingPropertiesForKeys: nil) else {
            return XCTFail("could not walk \(sources.path)")
        }
        var texts: [String] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            texts.append(text)
        }
        let result = try Self.hiddenViews(in: texts)

        // Non-vacuity (#454): an empty walk would make every later line vacuously green.
        XCTAssertGreaterThan(texts.count, 250, "only \(texts.count) Swift files read — the walk failed")
        XCTAssertGreaterThan(result.declared, 50,
                             "only \(result.declared) View declarations found — the scanner is broken")

        let registerText = try String(contentsOf: root.appendingPathComponent(Self.register),
                                      encoding: .utf8)
        XCTAssertFalse(registerText.isEmpty, "ANCHOR MISSING: \(Self.register) is empty (#454).")
        let missing = result.hidden.filter { !registerText.contains("`\($0)`") }
        let listing = missing.joined(separator: ", ")
        XCTAssertTrue(missing.isEmpty, """
        These SwiftUI views are declared but constructed NOWHERE under Sources/, and \
        \(Self.register) does not name them: \(listing). A view with no door is allowed; a view \
        with no door that nobody wrote down is how a working screen gets lost. Add a row to \
        section 2a of the register (what it does · why it is hidden · what a door would cost), \
        or give it a door, in the SAME commit.
        """)
    }

    /// Claim 2 — the detector is not blind. Literal fixtures, so no rename in Sources/ can
    /// turn this red (#364).
    func testTheDetectorSeesAConstructionAndIgnoresAComment() throws {
        let a = """
        struct Alpha: View { var body: some View { Beta() } }
        struct Beta: View { var body: some View { Text("x") } }
        // Alpha()
        extension Alpha { }
        """
        let first = try Self.hiddenViews(in: [a])
        XCTAssertEqual(first.declared, 2)
        XCTAssertEqual(first.hidden, ["Alpha"],
                       "a comment or an `extension` line was read as a construction, or `Beta()` was not")

        // A multi-line literal (the same form as `a` above) on purpose: the one-line spelling
        // read as a Sources/ needle to `doctor.py` section B ("declared nowhere") — a fixture
        // for this guard's own detector, never a claim about the app.
        let decl = """
        struct Gamma: View, Equatable { var body: some View { EmptyView() } }
        """
        XCTAssertEqual(try Self.hiddenViews(in: [decl]).hidden, ["Gamma"],
                       "a View conforming to a second protocol was not recognised as a View")
        XCTAssertEqual(try Self.hiddenViews(in: [decl, "let v = Gamma { }"]).hidden, [],
                       "a trailing-closure construction was not recognised")
    }

    /// Claim 3 — the register names this guard, so a reader of the register finds the rule.
    func testTheRegisterNamesItsGuard() throws {
        let text = try String(contentsOf: try Self.repoRoot().appendingPathComponent(Self.register),
                              encoding: .utf8)
        XCTAssertTrue(text.contains("EveryHiddenSurfaceIsInTheStatusRegisterTests.swift"),
                      "\(Self.register) no longer names the guard that keeps its section 2a honest")
    }

    // MARK: - Detector

    private static func hiddenViews(in texts: [String]) throws -> (hidden: [String], declared: Int) {
        let declRE = try NSRegularExpression(
            pattern: #"\bstruct\s+([A-Z][A-Za-z0-9_]*)\s*(?:<[^>{]*>)?\s*:\s*(?:[A-Za-z0-9_.]+\s*,\s*)*View\b"#)
        let useRE = try NSRegularExpression(
            pattern: #"(?<![A-Za-z0-9_.])([A-Z][A-Za-z0-9_]*)[ \t]*(?:<[^>()\n]*>)?[ \t]*[({]"#)
        let keywordRE = try NSRegularExpression(
            pattern: #"\b(?:struct|extension|class|enum|protocol|actor)\s+([A-Z][A-Za-z0-9_]*)"#)

        var declared = Set<String>()
        var built = Set<String>()
        for text in texts {
            let code = SourceText.codeOnly(text)
            declared.formUnion(captures(declRE, in: code))
            for line in code.components(separatedBy: "\n") {
                let declaredHere = Set(captures(keywordRE, in: line))
                for name in captures(useRE, in: line) where !declaredHere.contains(name) {
                    built.insert(name)
                }
            }
        }
        return (declared.subtracting(built).sorted(), declared.count)
    }

    private static func captures(_ re: NSRegularExpression, in text: String) -> [String] {
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap {
            $0.numberOfRanges > 1 && $0.range(at: 1).location != NSNotFound
                ? ns.substring(with: $0.range(at: 1)) : nil
        }
    }

    private static func repoRoot() throws -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
}
