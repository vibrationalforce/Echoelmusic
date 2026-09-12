import XCTest
@testable import Echoelmusic

/// #1275 (G1 of `scratchpads/PLAN_GENRE_WELT_2026-09-11.md`) — the genre taxonomy gains a SHELF
/// level, and the picker iterates it. Four rubrics for thirty-six genres meant one section header
/// covered seventeen of them and another ("Acoustic & Global") covered six unrelated traditions;
/// at the only level a player reads, the founder's "logisch sortiert" had stopped being true.
///
/// WHAT THIS FILE IS ACTUALLY FOR, and it is not tidiness: **the doorless-genre trap moved with
/// the iteration root.** `WorkspaceView`'s Genre picker used to loop `Category.allCases`; it now
/// loops `Subcategory.allCases`. A genre in `offered` whose shelf that loop never reaches is
/// invisible in exactly the way a genre outside `offered` is — built, filed, unreachable. Claim 3
/// pins the set equality against the NEW root, so the trap cannot reopen without a red.
///
/// ⚠️ WHY `.chant` IS NOT IN `Category` even though the plan names nine rubrics: every genre it
/// would hold is still unwritten, so the case would ship with an empty shelf. Claims 4 forbid
/// that in general rather than naming `.chant` — a rule beats a note, and this one fires the day
/// anyone adds an empty rubric or an empty shelf, whichever comes first.
///
/// SOURCE-TEXT SCAN in claim 7 only; everything else runs the real types.
///
/// ⚠️ HONEST GRADING — TRANSCRIBED (§0), and the parent comparison is WORTHLESS here, which is
/// said plainly rather than dressed up: every claim names `MusicStyle.Subcategory`, a type that
/// does not exist on `41ea657`, so the file does not COMPILE there. "Red on the parent" would
/// only prove the type is new. **The grading that counts is MUTANT-DRIVEN**: the transcription
/// was run against this tree (all green) and against seven deliberately wrong versions of it —
///   M1 a genre filed on two shelves            → claim 1 red
///   M2 a shelf whose parent contradicts its genres → claim 6 red (the split it causes)
///   M3 a genre filed nowhere                   → claim 1 red (a Swift COMPILE error too)
///   M4 an empty rubric (`.chant` added early)  → claim 4 red
///   M5 a rubric's shelves split across the menu → claim 6 red
///   M6 a `default:` arm in the filing switch   → claims 1, 4 and 7 red
///   M7 a shelf title of 26 characters          → claim 5 red
///   M8 `category` hand-written as its own switch again → claim 7's derivation loop red
/// — i.e. every claim that is not vacuous was shown to fail on the wrong tree before commit.
/// ⚠️ The Python transcription numbers the derivation loop separately as "claim 8"; in Swift it
/// lives inside `testTheFilingSwitchHasNoDefaultArm`, because it guards the same thing: the one
/// filing cabinet.
final class GenreSubcategoryTests: XCTestCase {

    private static let source = "Sources/Echoelmusic/Sequencer/MusicStyle.swift"

    /// Claim 1 — the shelves PARTITION the enum: every genre on exactly one, none left over.
    ///
    /// ⚠️ VACUOUS WHILE THE DERIVATION HOLDS, AND SAID SO RATHER THAN LEFT TO LOOK STRONG (#806).
    /// `Subcategory.genres` filters `MusicStyle.allCases` through a TOTAL switch, so today these
    /// two assertions cannot fail: the compiler already refuses an unfiled genre and a switch
    /// cannot return two shelves. What they catch is the version of this file where somebody
    /// "optimises" `genres` back into a hand-written array per shelf — the exact shape that stood
    /// here before #1275 and that `MusicStyleTests` existed to police. Claim 7 pins the
    /// derivation itself, so the pair is honest: claim 7 keeps claim 1 vacuous, and claim 1
    /// catches the day it stops being.
    func testTheShelvesPartitionEveryGenre() {
        let filed = MusicStyle.Subcategory.allCases.flatMap(\.genres)
        XCTAssertEqual(Set(filed), Set(MusicStyle.allCases), """
            a genre is on no shelf (or a shelf claims a genre twice over). The picker iterates \
            the shelves, so an unfiled genre is invisible even when it is in `offered` — the \
            doorless-genre shape, one level down from where this repo last found it (#1275)
            """)
        XCTAssertEqual(filed.count, MusicStyle.allCases.count,
                       "a genre stands on two shelves — it would appear twice in the picker (#1275)")
    }

    /// Claim 2 — the three derived views agree: a shelf's parent, a genre's category, and a
    /// rubric's genre list. They used to be three hand-written lists; this asserts the
    /// derivation actually collapsed them.
    ///
    /// ⚠️ Same vacuity as claim 1 and for the same reason — `category` IS `subcategory.parent`
    /// today, so the first loop compares a value with itself. It is kept because the
    /// hand-written form is what this slice removed, and removing a guard at the moment its
    /// subject becomes structural is how the next re-hand-writing goes unnoticed.
    func testTheDerivedViewsAgree() {
        for shelf in MusicStyle.Subcategory.allCases {
            for style in shelf.genres {
                XCTAssertEqual(style.category, shelf.parent, """
                    \(style.rawValue) sits on shelf `\(shelf.rawValue)` (parent \
                    \(shelf.parent.rawValue)) but reports category \(style.category.rawValue) — \
                    `category` must be `subcategory.parent` and nothing else (#1275)
                    """)
            }
        }
        for rubric in MusicStyle.Category.allCases {
            XCTAssertEqual(Set(rubric.genres), Set(rubric.subcategories.flatMap(\.genres)),
                           "`\(rubric.rawValue).genres` is not the union of its shelves — a second hand-written list came back (#416/#1275)")
        }
        XCTAssertEqual(Set(MusicStyle.Category.allCases.flatMap(\.genres)), Set(MusicStyle.allCases),
                       "the rubrics no longer cover the enum (#1275)")
    }

    /// Claim 3 — THE DOORLESS TRAP, on the new root. Everything `offered` must be reachable by
    /// walking the shelves, and walking the shelves must not surface anything that is not.
    func testEveryOfferedGenreIsReachableFromAShelf() {
        let reachable = MusicStyle.Subcategory.allCases.flatMap(\.offeredGenres)
        XCTAssertEqual(Set(reachable), Set(MusicStyle.offered), """
            the picker's iteration root and the roster disagree. `WorkspaceView` loops \
            `Subcategory.allCases` and renders `offeredGenres`, so a genre in `offered` that no \
            shelf lists is built, curated IN, and invisible — and one listed that is not offered \
            would be a phantom row (#1275)
            """)
        XCTAssertEqual(reachable.count, Set(reachable).count,
                       "a genre is offered from two shelves — it would show twice in the picker (#1275)")
    }

    /// Claim 4 — no empty shelf and no empty rubric. This is the rule that keeps `.chant` out
    /// until it has a genre, and it is written as a rule rather than a note on purpose: an empty
    /// drawer reads as a promise to the next session and shows nothing to the player.
    func testNoRubricAndNoShelfIsEmpty() {
        for shelf in MusicStyle.Subcategory.allCases {
            XCTAssertFalse(shelf.genres.isEmpty, """
                shelf `\(shelf.rawValue)` holds no genre. The picker skips it, so nothing looks \
                wrong — and the next session reads the enum and plans from a drawer that is \
                empty. Add the case together with its first genre (#1275)
                """)
        }
        for rubric in MusicStyle.Category.allCases {
            XCTAssertFalse(rubric.subcategories.isEmpty,
                           "rubric `\(rubric.rawValue)` has no shelf — same defect one level up (#1275)")
        }
    }

    /// Claim 5 — the headers are renderable: ASCII, short, unique, non-empty. A menu section
    /// header truncates long before a row does, and the String Catalog does not exist yet, so
    /// whatever stands here becomes the key every other language translates from.
    func testTheHeadersAreShortAsciiAndUnique() {
        var seen = Set<String>()
        for shelf in MusicStyle.Subcategory.allCases {
            let title = shelf.title
            XCTAssertFalse(title.isEmpty, "\(shelf.rawValue) has no title")
            XCTAssertTrue(title.allSatisfy { $0.isASCII },
                          "`\(title)` is not ASCII — it would become a non-ASCII catalog key (#1275)")
            XCTAssertLessThanOrEqual(title.count, 22,
                                     "`\(title)` is \(title.count) characters; a menu section header truncates (#1275)")
            XCTAssertTrue(seen.insert(title).inserted, "two shelves are both titled `\(title)` (#1275)")
        }
        for rubric in MusicStyle.Category.allCases {
            XCTAssertTrue(rubric.title.allSatisfy { $0.isASCII }, "`\(rubric.title)` is not ASCII")
            XCTAssertTrue(seen.insert(rubric.title).inserted,
                          "a rubric and a shelf are both titled `\(rubric.title)` — two headers, one name (#1275)")
        }
    }

    /// Claim 6 — order: the contemplative identity leads, and every rubric's shelves are
    /// CONTIGUOUS. `Category.subcategories` filters `allCases`, so a shelf declared out of place
    /// would split its own rubric across the menu without any other claim noticing.
    func testTheOrderLeadsCalmAndKeepsEachRubricTogether() {
        XCTAssertEqual(MusicStyle.Subcategory.allCases.first?.parent, .meditative,
                       "the first shelf is no longer contemplative — a fresh install opens on the calm identity (#1275)")
        XCTAssertEqual(MusicStyle.Category.allCases.first, .meditative,
                       "the first rubric is no longer `.meditative` (#1275)")
        var order: [MusicStyle.Category] = []
        for shelf in MusicStyle.Subcategory.allCases where order.last != shelf.parent {
            order.append(shelf.parent)
        }
        XCTAssertEqual(order.count, Set(order).count, """
            a rubric's shelves are not contiguous in `Subcategory.allCases`: \
            \(order.map(\.rawValue).joined(separator: " → ")). The picker renders them in this \
            order, so the rubric would appear twice with other headers in between (#1275)
            """)
    }

    /// Claim 7 — SOURCE SCAN: the filing switch stays exhaustive. The compiler cannot pin its own
    /// absence, and this is the guard that actually costs nothing to keep: with no `default:`,
    /// a new genre does not build until someone files it. A dictionary would compile with a
    /// genre missing and fall back at runtime — the doorless trap, one level deeper.
    func testTheFilingSwitchHasNoDefaultArm() throws {
        let code = SourceText.codeOnly(try text(Self.source))
        let marker = "public var subcategory: Subcategory {"
        let hits = code.components(separatedBy: marker).count - 1
        guard hits == 1, let start = code.range(of: marker) else {
            throw XCTSkip("anchor `\(marker)` occurs \(hits)× — re-anchor before trusting a zero (#408)")
        }
        // Walk to the member's own closing brace rather than guessing a length (#884).
        var depth = 1
        var i = start.upperBound
        var scoped = ""
        while i < code.endIndex, depth > 0 {
            let c = code[i]
            if c == "{" { depth += 1 }
            if c == "}" { depth -= 1; if depth == 0 { break } }
            scoped.append(c)
            i = code.index(after: i)
        }
        XCTAssertFalse(scoped.contains("default:"), """
            `MusicStyle.subcategory` gained a `default:` arm. The exhaustiveness IS the guard: \
            without it a new genre does not compile until it is filed, and with it a new genre \
            silently lands on whatever the default says — filed, offered, and on the wrong shelf \
            (#1275)
            """)
        XCTAssertTrue(scoped.contains("switch self"),
                      "`subcategory` is no longer a switch. A `[MusicStyle: Subcategory]` dictionary compiles with a genre missing and falls back at runtime — the same trap, deeper (#1275)")

        // THE DERIVATIONS — this is what makes claims 1 and 2 vacuous, and therefore what has to
        // be pinned in their place. One filing cabinet, three readers; a second hand-written list
        // anywhere here is the pre-#1275 shape coming back (#416).
        for derivation in ["public var category: Category { subcategory.parent }",
                           "MusicStyle.allCases.filter { $0.subcategory == self }",
                           "subcategories.flatMap(\.genres)",
                           "Subcategory.allCases.filter { $0.parent == self }"] {
            XCTAssertTrue(code.contains(derivation), """
                the derivation `\(derivation)` is gone from `MusicStyle.swift`. A genre is filed \
                ONCE, in `subcategory`; `category`, `Subcategory.genres`, `Category.genres` and \
                `Category.subcategories` all read it. A hand-written list in any of them can \
                disagree with the filing, and claims 1 and 2 exist for exactly that day (#1275)
                """)
        }
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
