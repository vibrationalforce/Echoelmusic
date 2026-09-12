// TheEmptyInputStateNamesTheDeviceTests.swift
// Echoel — #1296 (device finding on v10.79.470, build 2590).
//
// WHAT THIS GUARDS. The founder plugged an Apogee HypeMiC into the phone over USB, put his
// wired headphones into the mic's own jack, opened the Audio-input door and reported:
// "Apogee hypemic wird in dieser Version nicht erkannt". The hardware was fine and the code
// was behaving as designed: `AudioInputManager.refresh()` reads
// `AVAudioSession.availableInputs`, iOS publishes that list only while the session is
// `.playAndRecord`, and the door opens against the `.playback` default (the deliberate #298
// trade — claiming the record route on sheet-open would raise `.defaultToSpeaker` and could
// change the output route audibly mid-performance). So the list was empty for EVERY input,
// not for this one — but the empty state said nothing about the device, and "not listed"
// reads as "not recognised".
//
// ⭐ THE REPAIR IS INFORMATION, NOT ROUTE SURGERY. The manager already knew the device's
// name: the headphones hang off the HypeMiC, so the USB box IS the current OUTPUT route, and
// `refresh()` has stored `outputRouteName` since the Bluetooth-latency work. #1296 adds the
// matching `outputKind` (same pure classifier) and lets the empty state say the name. Zero
// change to any audio route, zero new `RecordRouteOwner` case, so the #299 owner Set and the
// eleven guards that read it are untouched.
//
// ⚠️ WHY THE KIND GATE IS `.usb || .wired` AND NOT "non-empty name". The built-in speaker is
// always a route and naming it ("Echoel can see Speaker") would be noise, not help. Bluetooth
// is excluded on purpose too: an A2DP headset does carry a mic, but it is the ~150–250 ms
// latency wall the footer of that same sheet warns about, so inviting the user toward it as a
// monitoring input would contradict the neighbouring copy. USB and wired external gear is the
// class that physically carries a usable input — that is the class worth naming.
//
// ⚠️ LIMIT — SOURCE-TEXT SCAN (§1). Nothing here runs AVAudioSession, renders the sheet or
// proves the founder's HypeMiC enumerates once monitoring engages. Whether the sentence is
// legible and whether the device then appears in the list is a DEVICE probe; the marker for
// it sits at the read site. This file proves the wiring exists and the copy is honest.
//
// ⚠️ HONEST GRADING (#433/#464) — transcribed in Python against the parent (422ba9a) and this
// tree. 9 assertions in 4 tests: claims 1 (3) + 2 (2) + 3 (1) + 4 (3). Against the PARENT,
// claims 1–3 are red as ONE finding (#486) — six needles naming lines born with this commit,
// all FORWARD, no regression claimed. Claim 4's three are COUNTERWEIGHTS, green on BOTH trees:
// they pin the three pre-existing empty-state branches, which the new branches must not
// displace.
//
// ⛔ A FIRST DRAFT OF THIS HEADER CLAIMED `SourceText.codeOnly` WAS LOAD-BEARING HERE — that
// both new sentences are quoted in the doc comments beside them, so a raw scan would green
// claim 2 from prose alone. MEASURED, that is FALSE: every needle below carries its `return "`
// prefix, which no comment has, and 0 of 18 verdicts (9 claims × 2 trees) flip raw-vs-stripped.
// The stripper is PROPHYLAKTISCH here (#453), not load-bearing. Recorded rather than quietly
// deleted because the wrong version is the one a next session would have copied into the next
// copy guard — and it fails in the reassuring direction, crediting a defence that is not doing
// the work. All seven mutations below were driven and each reddened exactly its own claim.
//
// ⛔ THE `+`-CHAIN LAW TRAVELS WITH THIS SLICE. `AudioInputPickerView.emptyStateText` carries
// a standing ⛔ note: ONE LITERAL PER BRANCH, NOT A `+` CHAIN — a message assembled with `+`
// inside a ternary is the type-checker hazard that turned the blocking gate red on `3379bb3`.
// The two new branches obey it: each is one literal with one `\(...)` interpolation, which
// costs the solver nothing comparable. Claim 2 pins them whole, so a later "just append a
// hint" edit has to face the law instead of sliding past it.

import Foundation
import XCTest

final class TheEmptyInputStateNamesTheDeviceTests: XCTestCase {

    private static let manager = "Sources/Echoelmusic/Audio/AudioInputManager.swift"
    private static let picker = "Sources/Echoelmusic/Studio/AudioInputPickerView.swift"

    /// The two sentences, verbatim. If either changes, change it in the view AND here in the
    /// same commit — they are the whole point of the slice.
    private static let seenLine =
        "return \"Echoel can see \\(externalRouteName). Turn on live monitoring above to use it as an input — iOS only publishes inputs while the mic is in use.\""
    private static let anomalyLine =
        "return \"Echoel plays through \\(externalRouteName) but iOS is not offering it as an input. Unplug and replug the device, then switch monitoring off and on again.\""

    // MARK: - claim 1 — the manager classifies the OUTPUT route, both platform branches

    func testTheManagerPublishesTheOutputKind() throws {
        let code = try source(Self.manager)
        XCTAssertTrue(code.contains("public private(set) var outputKind: AudioInputKind = .other"), """
            `AudioInputManager.outputKind` is gone or changed shape. It is the only thing that \
            lets the empty state tell an external interface apart from the built-in speaker — \
            without it the view can either name every route (naming "Speaker" is noise) or name \
            none (the #1296 finding). `.other` is the right default: nothing routed yet.
            """)
        XCTAssertTrue(code.contains("AudioInputClassifier.classify(portTypeRaw: $0.portType.rawValue).kind"), """
            `refresh()` no longer classifies the first OUTPUT port. The kind MUST come from the \
            same pure mapper the inputs use — a second, hand-rolled port-type switch is how the \
            wired-headset case was mis-classified before #596 (the real rawValue is \
            "MicrophoneWired", not the guessed names). One classifier, one truth.
            """)
        XCTAssertEqual(code.components(separatedBy: "outputKind = .other").count - 1, 1, """
            The macOS/`#else` reset of `outputKind` is missing or duplicated. Every other \
            published property in that branch is reset (`available`, `selectedID`, \
            `outputRouteName`, `outputIsHighLatency`); a stale kind there would let a \
            previously-seen USB name survive into a route that no longer exists.
            """)
    }

    // MARK: - claim 2 — the sheet names the device, in both empty-state situations

    func testTheEmptyStateNamesTheConnectedDevice() throws {
        let code = try source(Self.picker)
        XCTAssertTrue(code.contains(Self.seenLine), """
            The monitoring-OFF empty state stopped naming the connected device. This is the \
            exact sentence the #1296 finding asks for: the founder saw an anonymous empty list \
            with a HypeMiC plugged in and concluded the device was not recognised. Keep it ONE \
            literal (the ⛔ `+`-chain law at the read site) and change it here in the same commit.
            """)
        XCTAssertTrue(code.contains(Self.anomalyLine), """
            The monitoring-ON empty state stopped naming the device. That branch is a genuine \
            anomaly — the session IS `.playAndRecord` there and this view re-reads after the \
            toggle and on every route change — so it must give HARDWARE advice (replug), never \
            "turn on monitoring above", which is already on.
            """)
    }

    // MARK: - claim 3 — and only for the class that can carry an input

    func testOnlyExternalRoutesAreNamed() throws {
        let code = try source(Self.picker)
        XCTAssertTrue(code.contains("guard inputs.outputKind == .usb || inputs.outputKind == .wired else { return \"\" }"), """
            `externalRouteName` lost its kind gate. Widening it to "any non-empty route name" \
            would print "Echoel can see Speaker" on a bare phone — noise where the sentence is \
            supposed to be evidence. Widening it to Bluetooth would invite the user toward the \
            ~150–250 ms wall that this same sheet's footer warns against, two lines apart.
            """)
    }

    // MARK: - claim 4 (COUNTERWEIGHTS, #343) — the three branches that were already right

    func testThePreExistingEmptyStateBranchesSurvive() throws {
        let code = try source(Self.picker)
        XCTAssertTrue(code.contains("return \"No input is available on the current route.\""), """
            The plain monitoring-ON line is gone. It is still the correct sentence when NO \
            external route is present — the #1296 branches are additions beside it, not a \
            replacement for it.
            """)
        XCTAssertTrue(code.contains("return \"The microphone is not available to Echoel. Allow microphone access in Settings, then switch monitoring on.\""), """
            The #601b permission-denied line is gone. It must keep winning over the new \
            device-naming branch: with the mic refused, "turn on live monitoring above" is an \
            unfulfillable loop whatever hardware is plugged in.
            """)
        XCTAssertTrue(code.contains("return \"Turn on live monitoring above to list the available inputs. iOS only publishes them while the mic is in use.\""), """
            The default monitoring-OFF line is gone. It is the fallback when nothing external \
            is routed, and it carries the one fact that explains every empty list here — iOS \
            publishes inputs only while the mic is in use.
            """)
    }

    // MARK: - source access (§0/§2 — one stripper, skip on no tree, FAIL on a moved anchor)

    private struct AnchorMissing: Error { let reason: String }

    private func source(_ relativePath: String) throws -> String {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        let path = root.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AnchorMissing(reason: """
                \(relativePath) is missing while the tree is present — renamed or moved. \
                Re-anchor this scan; do not let it skip (#454).
                """)
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }
}
