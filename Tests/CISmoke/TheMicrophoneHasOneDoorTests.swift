import XCTest

/// #1247 — THE MICROPHONE HAS EXACTLY ONE DOOR AGAIN, BY FOUNDER ASK.
///
/// 2026-09-11: *"Ist es möglich nochmal mein Vorhaben mit dem Audio Input sauber aufzusetzen?"*
/// — microphone/interface → the picture at concerts and clubs, and the voice through
/// harmonizer, granular and tune-to-key, modulated by the body. The plan is
/// `scratchpads/PLAN_AUDIO_INPUT_2026-09-11.md`; this slice (S2) is the DOOR: the Master
/// panel's "Audio input" button sets the existing `showInput` slot (slot reuse — the body
/// chain stays at 14 presentation modifiers). Nothing else changed in the monitor path.
///
/// ⚠️ THE HISTORY THIS GUARD CARRIES FORWARD. #1024 (2026-09-06) removed all THREE doors on
/// the founder's order — *"das mit dem Audio Input Monitoren klappt immer noch nicht also
/// fliegt das raus"* — because the monitor path had never once been confirmed audible on a
/// device (the `isInputConnToConverter` crash family, then the #1022 session refusal). The
/// founder's second sentence was about the PATTERN (*"erst wird munter drauf los programmiert
/// und dann verhäddert es sich"*), so #1024 took doors, not the machine, and this file (then
/// `TheMicrophoneHasNoDoorTests`) pinned "no setter". #1247 restores ONE door and nothing of
/// the machine — the two untried hypotheses in `AudioEngine.swift` (#5 `prepare()`, #6 connect
/// on the running engine) are their own slices, so the next device log stays decidable.
///
/// WHAT IS PINNED NOW. Exactly ONE `showInput = true` in `EchoelStudioView`, inside
/// `masterPanel` (claim 1). The sheet, the picker, the engine and the non-persisted flag
/// survive (claims 2–4, unchanged from #1024 — they were counterweights then and still are).
/// The claim register keeps the three monitor rows STRUCK until a `VERIFIED-` date stands on
/// the monitor path (claim 5): a door is not a device confirmation, and a caption about a
/// stage that crashes is the 2.3 class. The Mix-board strip and the plug-in banner stay
/// doorless (claim 6) — the founder asked for the feature, not for the strip.
///
/// ⛔ #364: this guard forbids neither a second door nor closing this one. Either is a
/// founder decision; its failure messages name the prose homes that move with it.
///
/// ⚠️ HONEST GRADING — TRANSCRIBED (§0) against the parent (`4bdee8d`) and this tree: claim 1
/// RED on the parent (zero setters), GREEN here; claims 2–5 GREEN on both; claim 6 GREEN on
/// both. `code(_:)` strips line comments only (the file's own reader, kept — §2 #453 says do
/// not add a second stripper): PROPHYLAKTISCH, measured — 0 of 6 verdicts flip raw vs.
/// stripped on either tree (no comment in `EchoelStudioView` quotes the setter needle).
final class TheMicrophoneHasOneDoorTests: XCTestCase {

    // MARK: - 1. Exactly one door opens the microphone sheet — the Master panel's

    func testTheInputSheetHasExactlyOneSetterInTheMasterPanel() throws {
        let view = try code("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        XCTAssertEqual(occurrences(of: "showInput = true", in: view), 1, """
            `showInput` has \(occurrences(of: "showInput = true", in: view)) setters; #1247 \
            restored exactly ONE (the Master panel's "Audio input" door). Zero means the door \
            went again — a founder decision, and these prose homes move in the SAME commit:
              · CLAUDE.md, the "Vokal-Kette" paragraph (it says the one door is back)
              · CLAUDE.md, the doorless register (FeedbackGuard/AudioInputPicker entry)
              · CLAUDE.md, the "NOW WIRED" FeedbackGuard line
              · ContentPipeline/CLAIMS.md, the four monitor rows (claim 5 below)
              · this guard's own header
            Two or more means a second door — legitimate, but then claim 6 (strip and banner \
            stay doorless) is the one to re-read before relaxing this number.
            """)
        let master = view.components(separatedBy: "private var masterPanel: some View")
        XCTAssertEqual(master.count, 2, "`masterPanel` must be declared exactly once (#408 anchor)")
        let body = master.count == 2 ? master[1] : ""
        let doorIndex = body.range(of: "masterDoorButton(\"Audio input\"")?.lowerBound
        let setterIndex = body.range(of: "showInput = true")?.lowerBound
        XCTAssertNotNil(doorIndex, "the Master panel no longer carries the \"Audio input\" door (#1247)")
        XCTAssertNotNil(setterIndex, "the setter is not in `masterPanel` — the door moved; move this claim with it (#1247)")
        if let d = doorIndex, let s = setterIndex {
            XCTAssertLessThan(d, s, "the setter must belong to the \"Audio input\" button (#1247)")
        }
    }

    // MARK: - 2. COUNTERWEIGHT — the removal really was doors-only

    /// Without this, claim 1 would also pass on a tree where somebody "cleaned up" by deleting
    /// the sheet and the picker — which is a far bigger, far less reversible change than the
    /// one the founder asked for.
    func testTheSheetAndThePickerStillExist() throws {
        let view = try code("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        XCTAssertEqual(occurrences(of: ".sheet(isPresented: $showInput)", in: view), 1, """
            The `showInput` sheet slot is gone. #1024 removed DOORS, deliberately keeping the \
            slot as setter-less headroom under the 10.76.34 presentation ceiling (like \
            `showMeditation`). Deleting the slot turns a reversible removal into a rebuild.
            """)
        let root = try repoRoot()
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: root.appendingPathComponent(
                    "Sources/Echoelmusic/Studio/AudioInputPickerView.swift").path),
            """
            `AudioInputPickerView.swift` is gone. It carries the input picker, the tune \
            presets, the harmony voices and the granular texture — #1024 took its doors, not \
            the file. Deleting it is a separate decision the founder has not taken.
            """)
    }

    // MARK: - 3. COUNTERWEIGHT — the engine is untouched

    func testTheMonitoringEngineIsStillThere() throws {
        let engine = try code("Sources/Echoelmusic/Audio/AudioEngine.swift")
        for symbol in ["func setInputMonitoring", "isInputMonitoring"] {
            XCTAssertGreaterThan(occurrences(of: symbol, in: engine), 0, """
                `\(symbol)` left `AudioEngine`. #1024 is a UI removal; the audio graph was \
                deliberately not touched, so that re-dooring stays three call sites and so \
                that the #1022 session repair — which matters for the sample rate and the \
                session activation, not only for the microphone — keeps its subject.
                """)
        }
    }

    // MARK: - 4. The flag that made this safe to remove has not become persisted

    /// If a later change starts persisting `isInputMonitoring`, removing the switch stops \
    /// being harmless: a user could be left monitoring with no control to stop it.
    func testMonitoringIsStillNotPersisted() throws {
        let engine = try code("Sources/Echoelmusic/Audio/AudioEngine.swift")
        XCTAssertTrue(engine.contains("isInputMonitoring = false"), """
            `isInputMonitoring` no longer starts `false` in its declaration. The safety of \
            #1024 rests on the microphone being OFF at every launch; if this value now comes \
            from storage, a user can be stranded with monitoring on and no switch (#1024).
            """)
    }

    // MARK: - helpers

    // MARK: - 5. The marketing-claim register may not authorise what no device confirmed

    /// ⭐ #1038 — THE FILE THE SWEEP FORGOT. `ContentPipeline/CLAIMS.md` is not documentation;
    /// CLAUDE.md instructs a session to read it BEFORE writing any script, caption or hashtag,
    /// so a row standing there is a licence to publish. Three rows kept their licence for
    /// three weeks after the door under them was removed.
    ///
    /// ⛔ THIS CLAIM FORBIDS NOTHING (#364). Since #1247 it is anchored to the DEVICE, not to
    /// the door: the rows stay struck until a `VERIFIED-` date stands on `setInputMonitoring`
    /// (`python3 scripts/founder-verify.py` prints the open asks). Un-strike them in the same
    /// commit as that date and relax this claim then. The rows are deliberately not deleted
    /// either way; a struck row with its reason is what stops the claim being re-invented.
    func testTheClaimRegisterStrikesTheMonitorRowsUntilADeviceConfirmsThem() throws {
        let register = try rawFile("ContentPipeline/CLAIMS.md")

        // The struck form, as the file's own convention writes it.
        let struck = ["~~**Harmoniestimmen auf deiner Stimme**",
                      "~~**Granular-Textur auf deiner Stimme**",
                      "~~**Feedback-Schutz, der Pfeifen VERHINDERT"]
        let unstruck = struck.filter { !register.contains($0) }
        XCTAssertTrue(unstruck.isEmpty, """
            `ContentPipeline/CLAIMS.md` no longer strikes: \(unstruck.joined(separator: " · ")).

            Every one of these sits ONLY in the monitor path. #1247 gave it a door again, but \
            no device has confirmed it audible (the `isInputConnToConverter` crash family). \
            Un-strike the rows ONLY in the commit that writes a `VERIFIED-` date on the \
            monitor path, and pull the CLAUDE.md paragraphs listed in claim 1 along (#456). \
            Until then a standing row is a licence to write a caption about a stage that may \
            crash, which is the 2.3 class.
            """)

        // COUNTERWEIGHT (#367): a negative that a rename or a deletion would satisfy is not a
        // measurement. The rows must still BE there, struck — and the MUSIC-path harmonizer,
        // which #1024 never touched, must still be claimable.
        XCTAssertTrue(register.contains("Nicht mit dem MUSIK-Harmonizer verwechseln"), """
            The note separating the MUSIC-path harmonizer from the monitor one is gone from \
            `ContentPipeline/CLAIMS.md`. Without it the next reader strikes both, and the App \
            Store release note "third and fifth harmony voices above the melody" — which is \
            TRUE and describes the FX-panel harmonizer — starts looking like an overclaim.
            """)
    }

    // MARK: - 6. COUNTERWEIGHT — the strip and the banner stay doorless

    /// #1247 restored the Master door only. The Mix-board strip (206 lines, its own
    /// 15 Hz-observer hazard) and the plug-in invitation banner stay unmounted; if either
    /// returns, the #1024 obituaries in `EchoelStudioView` name the laws it must obey.
    func testTheStripAndTheBannerStayUnmounted() throws {
        let view = try code("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        XCTAssertEqual(occurrences(of: "micMixStrip", in: view), 0,
                       "the Mix-board microphone strip is back — re-read the #1024 obituary's three laws and `TheVoiceIsOnTheBoardTests`' retirement (#1247)")
        XCTAssertEqual(occurrences(of: "PlugInInviteRow(", in: view), 0,
                       "the plug-in invitation banner is mounted again — restore `ThePlugInInvitesButNeverArmsTests`' pre-#1024 claim in the same commit (#1247)")
    }

    private func repoRoot() throws -> URL {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path)
        else { throw XCTSkip("source tree not present under \(root.path)") }
        return root
    }

    /// Raw file text. `code(_:)` strips SWIFT comments and would mangle Markdown, where `//`
    /// appears inside every URL — the one-stripper rule (#453) says add a reader, not a second
    /// stripper. Named `rawFile` to match the other guards that read a non-Swift file, and
    /// because `code(_:)` already holds a local `let text`: a `text(_:)` method beside it
    /// compiles, but two spellings of the same word one line apart is how a later edit picks
    /// the wrong one.
    private func rawFile(_ relativePath: String) throws -> String {
        try String(contentsOf: try repoRoot().appendingPathComponent(relativePath), encoding: .utf8)
    }

    private func code(_ relativePath: String) throws -> String {
        let text = try String(contentsOf: try repoRoot().appendingPathComponent(relativePath),
                              encoding: .utf8)
        return text.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }
}
