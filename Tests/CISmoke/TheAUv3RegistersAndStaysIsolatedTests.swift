// TheAUv3RegistersAndStaysIsolatedTests.swift
// Echoel — #1385. Blocking bundle. SOURCE-TEXT SCAN (`Tests/CISmoke/CLAUDE.md` §1): it proves
// what the build files and the sources SAY, never that anything loads in a host.
//
// ⭐ WHY THIS FILE EXISTS. The AUv3 instrument extension was deleted 2026-07-24 by the
// pure-instrument verdict and restored 2026-09-20 on a founder ask ("Ultraauv3 … no Juce").
// Restoring it was cheap — it was always pure Swift, and every type it calls still exists.
// What is NOT cheap is the set of invariants that made it work, each of which was learned by
// shipping a broken build and reading a device log. They live in four different files, none of
// which a compiler checks, and a two-month gap already proved that nobody remembers them.
//
// ⚠️ THE RESTORE RE-ARMED A LATENT DEFECT IN CODE THAT DID NOT CHANGE, and that is the general
// lesson worth more than this target: `EchoelCellular` became test-only with #167 (its only
// instantiator, `DrumSynthVoice`, was deleted), so for two months nothing ran `evolve1D()` on a
// render thread. It carried `cellsPrev = cells` — a copy-on-write malloc + memcpy + free, on the
// audio thread, ~8× per second. The AU is now its ONE production caller. **Reviving a caller
// re-arms every latent defect in everything it calls, and the callee's diff is empty.** Claim 5
// pins the repair.
//
// ⚠️ WHAT MUST NOT BE READ INTO THIS (#364). It does NOT forbid cutting the AUv3 again — that is
// the founder's call and he has made it once already. It forbids cutting it HALFWAY, or growing
// it in the one direction that silently costs its whole value. Every message names what to move
// in the same commit.
//
// ⛔ AND IT IS NOT "THE PLUGIN WORKS" (#367). It cannot be. Nothing here proves the extension
// INSTANTIATES: `EchoelmusicAUv3.entitlements` records that it once returned -3000
// invalidComponentID in every host, and that question is open — `FOUNDER_DEVICE_SESSION.md` §2b.
// A guard that implied otherwise would be the more expensive error, because the host claim is a
// 2.3 rejection in the App Store text and three cycles (#158, #192, #184) were already spent
// removing it.
//
// ⚠️ HONEST GRADING. No local Swift toolchain (§0). **Six claims, NINE assertion statements** —
// of which THREE are `XCTFail` re-anchor paths (claims 1, 3 and 5, taken only if the anchor
// itself has moved) and one (claim 3) runs its single assertion over four needles. Driven in
// Python against the working tree plus **nine mutants, all RED** — including the three that
// rewrote the first draft of claim 1 (see its body). ⛔ This paragraph
// said "seven" in its first draft, counted from the file's shape instead of from a `grep`; the
// sample guard I copied the form from warns in its own header that three gradings in this bundle
// miscounted the same way in one week. Measured: `grep -c "XCTAssert\|XCTFail"` → 9.
// Each was transcribed in Python against today's tree and every needle re-derived by `grep`
// first. All nine are green on today's tree: **0 regression catches, 9 COUNTERWEIGHTS (#343)** —
// this guard exists to make the NEXT change conscious, not to report a defect already fixed.

import XCTest

final class TheAUv3RegistersAndStaysIsolatedTests: XCTestCase {

    private func repoRoot() throws -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }

    private func text(_ relative: String) throws -> String {
        try String(contentsOf: try repoRoot().appendingPathComponent(relative), encoding: .utf8)
    }

    // 1 — THE REGISTRATION LAW. Paid for with a device log (2026-07-16, build 2382: "ownAUv3
    // false"): iOS's pluginkit registers audio components ONLY when `AudioComponents` sits under
    // `NSExtension → NSExtensionAttributes`. It sat directly under `NSExtension` before, so the
    // extension was embedded, signed, shipped — and invisible to every host including our own
    // scan. There is no error message for this; it simply never appears.
    func testTheAudioComponentsSitUnderExtensionAttributes() throws {
        // ⛔ THE FIRST VERSION OF THIS CLAIM WAS "`AudioComponents` appears somewhere AFTER the
        // string `NSExtensionAttributes`", and a mutant proved it worthless before this file was
        // committed: renaming the key to `AudioComponentsXX` left it GREEN, because the needle is
        // a substring of the corruption. It also tested ORDER when the law is NESTING — a sibling
        // key at the wrong indent would have passed. The law is an indentation relationship, so
        // the check has to be one (#367: a needle that cannot fail is not a check).
        let lines = try text("project.yml").split(separator: "\n", omittingEmptySubsequences: false)
                                           .map(String.init)
        func indent(_ l: String) -> Int { l.prefix { $0 == " " }.count }

        guard let attrIdx = lines.firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == "NSExtensionAttributes:"
        }) else {
            return XCTFail("""
            project.yml has no `NSExtensionAttributes:` key. That is the REGISTRATION LAW and it \
            fails SILENTLY: iOS's pluginkit registers audio components ONLY when `AudioComponents` \
            sits under `NSExtension → NSExtensionAttributes`. With the key gone the plugin builds, \
            embeds and signs — and never appears in any host, with no error anywhere. Paid for \
            with a device log (2026-07-16, build 2382: "ownAUv3 false"). Keep \
            Resources/EchoelmusicAUv3/Info.plist byte-identical: XcodeGen regenerates it from \
            project.yml, so the committed copy exists only to make the shipping values greppable.
            """)
        }
        let attrIndent = indent(lines[attrIdx])

        // Walk forward only while still INSIDE the attributes block: the first non-blank line
        // indented at or left of the key ends it.
        var found = false
        var i = attrIdx + 1
        while i < lines.count {
            let line = lines[i]
            let bare = line.trimmingCharacters(in: .whitespaces)
            if bare.isEmpty || bare.hasPrefix("#") { i += 1; continue }
            if indent(line) <= attrIndent { break }
            if bare == "AudioComponents:" { found = true; break }
            i += 1
        }
        XCTAssertTrue(found, """
        `AudioComponents:` is not nested inside the `NSExtensionAttributes:` block in project.yml \
        — it is missing, renamed, or sat back up as a sibling under `NSExtension` directly. That \
        is the exact 2026-07-16 "ownAUv3 false" defect: the extension ships and is invisible to \
        every host, including our own scan. The comparison is on INDENTATION on purpose; an \
        order-only or substring check passes on a renamed key (measured — the first draft of this \
        assertion did).
        """)
    }

    // 2 — THE -3000 LAW. The entitlements file is deliberately EMPTY. An App-Group entitlement
    // the App ID `com.echoelmusic.app.auv3` does not actually carry in the portal makes iOS
    // REFUSE to launch the appex: the component registers, hosts list it, and instantiating
    // returns -3000 invalidComponentID everywhere. The AU does not need the group — the shared
    // vitals read degrades cleanly to "the host set the parameters".
    func testTheEntitlementsCarryNoAppGroup() throws {
        let ents = try text("EchoelmusicAUv3.entitlements")
        XCTAssertFalse(ents.contains("<key>com.apple.security.application-groups</key>"), """
        The AUv3 entitlements declare App Groups again. Unless the App ID \
        com.echoelmusic.app.auv3 has been granted that capability in the developer portal FIRST, \
        this is the -3000 invalidComponentID gate: the plugin will register and then fail to \
        instantiate in every host, persistently, across clean builds. The file's own comment \
        carries the full history — read it before re-adding the key, and if the capability HAS \
        been granted, say so there in the same commit.
        """)
    }

    // 3 — THE ISOLATION THAT IS THE WHOLE POINT. The extension compiles `Sources/Echoelmusic/DSP`
    // plus exactly three Foundation-only `Core/` files. That is what makes it dependency-free,
    // fast to build, and what re-enforces the DSP layer's Foundation-only discipline as a BUILD
    // error rather than a style rule. Adding `Studio/` (the obvious move when someone wants a
    // nicer plugin UI) costs all three at once — and the compiler will happily let them.
    func testTheExtensionCompilesOnlyItsIsolatedSourceSet() throws {
        let project = try text("project.yml")
        // ⚠️ `range(of:)` takes the FIRST hit, and `  EchoelmusicAUv3:` occurs TWICE in this
        // file — once as a target, once as a scheme. This works because `targets:` precedes
        // `schemes:` and, in both blocks, AUv3 precedes Widgets. That is two assumptions, so
        // they are written down rather than relied on silently: if either ordering changes, this
        // claim reads the wrong block and must be re-anchored, not deleted.
        guard let block = project.range(of: "  EchoelmusicAUv3:\n"),
              let next = project.range(of: "\n  EchoelmusicWidgets:",
                                       range: block.upperBound..<project.endIndex) else {
            return XCTFail("Cannot bound the EchoelmusicAUv3 target block in project.yml — "
                           + "re-anchor this walk rather than skipping it (#454).")
        }
        let body = String(project[block.upperBound..<next.lowerBound])
        let code = body.split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }
            .joined(separator: "\n")
        for forbidden in ["Sources/Echoelmusic/Studio", "Sources/Echoelmusic/Sequencer",
                          "Sources/Echoelmusic/Views", "Sources/Echoelmusic/Audio"] {
            XCTAssertFalse(code.contains(forbidden), """
            The AUv3 target compiles \(forbidden). The extension's source set is DSP/ plus three
            Foundation-only Core/ files ON PURPOSE. Widening it is what a session does when it
            wants EchoelValueField in the plugin UI — and it trades away the dependency-free
            build, the fast isolated compile, and the build-level enforcement of the DSP layer's
            Foundation-only rule. If this is genuinely wanted, extract the needed type into a
            Foundation/SwiftUI-only file first and add THAT, and move the exemption note in
            CLAUDE.md's EchoelValueField paragraph in the same commit.
            """)
        }
    }

    // 4 — an extension nobody embeds ships nothing, and nothing says so at build time.
    func testTheExtensionIsEmbeddedInTheApp() throws {
        let project = try text("project.yml")
        let embedded = project.split(separator: "\n").contains {
            $0.trimmingCharacters(in: .whitespaces) == "- target: EchoelmusicAUv3"
        }
        XCTAssertTrue(embedded, """
        The app target no longer lists `- target: EchoelmusicAUv3` in its `dependencies:`, so the \
        .appex is built but never embedded — the plugin simply does not exist on the device, with \
        no error anywhere. Note the precedent two lines above it in that file: EchoelmusicWatch \
        has been commented out for months over a broken embed phase, which is exactly how an \
        un-embedded target hides. If the AUv3 was cut deliberately, take the target, the scheme, \
        the compile_scheme line in testflight.yml and ContentPipeline/CLAIMS.md §1 with it.
        """)
    }

    // 5 — the audio-thread repair the restore made necessary. See the file header.
    func testTheCellularEvolutionAllocatesNothingOnTheRenderThread() throws {
        let cellular = try text("Sources/Echoelmusic/DSP/EchoelCellular.swift")
        guard let evolve = cellular.range(of: "private func evolve1D() {") else {
            return XCTFail("`evolve1D()` is gone from EchoelCellular — re-anchor this claim "
                           + "rather than skipping it (#454); the allocation law still applies "
                           + "to whatever replaced it.")
        }
        let body = String(cellular[evolve.upperBound...].prefix(4000))
        let code = body.split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        XCTAssertFalse(code.contains("cellsPrev = cells"), """
        `cellsPrev = cells` is back inside evolve1D(). It gives the [UInt8] buffer a SECOND owner, \
        so the next `cells[i] = …` copy-on-writes: one malloc, one memcpy, one free — on the \
        AUDIO THREAD, at the evolution rate (~8×/s with the AUv3's settings, and it scales with \
        `evolutionRate`, a public var). malloc takes the zone lock; a render thread blocking on a \
        lock held by a lower-priority thread is a priority inversion, i.e. an audible click that \
        no unit test reproduces. `cellsPrev` has NO reader anywhere — the store buys nothing. \
        This became reachable only when #1385 made the AUv3 this file's one production caller.
        """)
    }

    // 6 — the frame ceiling is clamped on the CONTRACT, not on the data. Clamping only the data
    // leaves samples above the scratch size EXACTLY as the host handed them over — stale audio or
    // uninitialised memory — and returns noErr while doing it.
    func testTheFrameCeilingIsClampedOnTheContract() throws {
        let au = try text("Sources/EchoelmusicAUv3/EchoelmusicAudioUnit.swift")
        XCTAssertTrue(au.contains("override var maximumFramesToRender"), """
        The AUv3 no longer overrides `maximumFramesToRender`. The render scratch is a fixed 4096 \
        frames and the render block writes only what fits; without the override a host is free to \
        ask for more (an offline bounce is the realistic case) and every sample past 4096 is \
        returned to the host unwritten — a loud periodic burst of garbage at the block boundary, \
        invisible in the simulator at 512 frames. If you raise the ceiling instead, raise \
        RenderScratch AND EchoelDDSP's reverbFrameBuffer/reverbWetBuffer in lockstep: that file \
        records having already shipped this bug once, at 2048.
        """)
    }
}
