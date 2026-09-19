//
//  TheNoteRefusesANonFiniteVelocityTests.swift
//  Echoelmusic — CISmoke (BLOCKING bundle)
//
//  WHY THIS EXISTS (#1378). `MIDIOutput.noteOn(pitch:velocity:expression:)` computed
//
//      let vel = UInt8(max(1, min(127, Int(velocity * 127))))
//
//  with the clamp BEHIND its own conversion. `Int(_:)` from a non-finite floating-point value
//  is a TRAP in Swift, not a saturating cast, so a NaN or ±inf velocity crashed exactly one
//  paren before the guard written to contain it. This is the #1374 shape at the next type over,
//  found by sweeping the whole class after that slice: of 24 places where a Float PARAMETER of
//  a type reaches an `Int(…)` conversion, 23 were already sound — guarded before the
//  conversion, or using a NaN-safe helper, or relying on `max(0, x)` / `min(1, x)` argument
//  order — and this was the one that was not.
//
//  ⚠️ REORDERING WOULD NOT HAVE FIXED IT. `min(max(v, lo), hi)` passes NaN straight through
//  (CLAUDE.md: "Argument order in max/min decides NaN behaviour"), so the repair has to be a
//  finiteness TEST, not a range test. That is why claim 1 pins `isFinite` and not a reordering.
//
//  ⚠️ AND IT IS A REFUSAL, NOT A CLAMP. Turning a broken velocity into 1 or 127 would put a
//  wrong note on an external rig and report success — the #630b defect (a clamped NaN yields a
//  plausible-looking wrong result reported as a success). Dropping the note leaves the rig
//  where it was.
//
//  ⚠️ NOT REACHABLE TODAY, and that is deliberately not the argument. All four production call
//  paths bound the value first. But the method is PUBLIC and takes a `Float`: the guard belongs
//  at the TYPE, not at today's callers. A fix that is true for one caller is not true for the
//  type (#1374).
//
//  GRADED BY TRANSCRIPTION (`Tests/CISmoke/CLAUDE.md` §0).
//

import XCTest

final class TheNoteRefusesANonFiniteVelocityTests: XCTestCase {

    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        // `try`, not `try?` — a moved file must fail loudly rather than pass vacuously (#454).
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    // MARK: - Claim 1 — the finiteness guard precedes the conversion

    func testTheVelocityGuardComesBeforeItsConversion() throws {
        let src = try source("Sources/Echoelmusic/Audio/MIDIOutput.swift")
        let code = SourceText.codeOnly(src)

        guard let guardAt = code.range(of: "guard velocity.isFinite else {") else {
            return XCTFail("""
                `guard velocity.isFinite else {` is gone from `MIDIOutput`.
                Without it, `Int(velocity * 127)` traps on NaN/±inf. If the clamp moved to a
                different shape, re-anchor this claim on the new one — do not delete it: the
                method is public and takes a Float, so the type still owes the guarantee.
                """)
        }
        guard let convertAt = code.range(of: "Int(velocity * 127)") else {
            return XCTFail("""
                `Int(velocity * 127)` is gone. If the conversion was replaced by a saturating
                or NaN-safe form (e.g. `clamped(to:)` from `Core/FloatingPointClamp.swift`),
                that is a BETTER fix than the guard — say so here and retire claim 1.
                """)
        }
        XCTAssertTrue(guardAt.lowerBound < convertAt.lowerBound, """
            The finiteness guard now sits AFTER `Int(velocity * 127)`. That is the exact defect
            #1378 repaired: a clamp behind its own conversion protects nothing, because the trap
            fires during the conversion.
            """)
    }

    // MARK: - Claim 2 — the guard precedes the side effect it must prevent

    /// The first draft of #1378 put the guard after `allocateChannel(for:)` — the same ordering
    /// error one level up. `allocateChannel` PUSHES onto `channelForPitch`, so a refused note
    /// would leave a member channel reserved for a voice that never sounds, and the matching
    /// `noteOff` would pop it and emit a note-off for a note nobody played.
    func testTheGuardComesBeforeTheChannelAllocation() throws {
        let code = SourceText.codeOnly(try source("Sources/Echoelmusic/Audio/MIDIOutput.swift"))
        guard let guardAt = code.range(of: "guard velocity.isFinite else {"),
              let allocAt = code.range(of: "let ch = allocateChannel(for: pitch)") else {
            return XCTFail("""
                One of the two anchors is gone (`guard velocity.isFinite` / \
                `let ch = allocateChannel(for: pitch)`). Re-anchor rather than skip (#454) — \
                the ORDER of these two is the claim.
                """)
        }
        XCTAssertTrue(guardAt.lowerBound < allocAt.lowerBound, """
            `allocateChannel(for: pitch)` now runs BEFORE the velocity guard. A refused note
            would then hold a member-channel reservation for a voice that never sounds, and the
            matching note-off would release a note nobody played. A guard belongs before the
            side effect it is meant to prevent.
            """)
    }

    // MARK: - Claim 3 — refusal, and it does not flood

    func testTheRefusalIsLoggedOnceAndTheNoteIsDropped() throws {
        let code = SourceText.codeOnly(try source("Sources/Echoelmusic/Audio/MIDIOutput.swift"))

        XCTAssertTrue(code.contains("hasRefusedNonFiniteVelocity"), """
            The one-shot latch is gone. `noteOn` runs PER NOTE and a bad velocity almost never
            arrives once; `logOutcome` writes both `os_log` AND an unbuffered breadcrumb, so an
            unlatched log here floods the diag file that `scripts/diag-ladder.py` reads.
            """)
        XCTAssertFalse(code.contains("velocity = 0"), """
            Something now rewrites `velocity` instead of refusing the note. A clamped NaN puts a
            wrong note on an external rig and reports success — the #630b defect. Refuse.
            """)
    }

    // MARK: - Claim 4 — the identical twin keeps its guard too

    /// `FloatingVisualWindow.recTimeString(_:)` and `SessionView.clock(_:)` are the same
    /// function in two homes; until #1378 only one carried the guard (#456).
    func testBothElapsedTimeFormattersGuardTheirConversion() throws {
        for (path, fn) in [("Sources/Echoelmusic/Studio/FloatingVisualWindow.swift", "recTimeString"),
                           ("Sources/Echoelmusic/Studio/SessionView.swift", "clock")] {
            let code = SourceText.codeOnly(try source(path))
            guard let at = code.range(of: "func \(fn)(") else {
                XCTFail("`\(fn)` is gone from \(path) — re-anchor or retire this half of the claim.")
                continue
            }
            let window = String(code[at.lowerBound...].prefix(260))
            XCTAssertTrue(window.contains("isFinite"), """
                `\(fn)` in \(path) converts an elapsed time with `Int(…)` and no finiteness
                guard. Its twin has one; a law that lives in two homes has to move in both
                (#456). Today's callers make it latent, not safe — clamp at the function.
                """)
        }
    }
}
