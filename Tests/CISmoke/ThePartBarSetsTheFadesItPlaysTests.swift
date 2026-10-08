// ThePartBarSetsTheFadesItPlaysTests.swift
// Echoel — the selected AUDIO part's fade-in and fade-out are set on the part bar and drawn on
// the canvas as they are heard (audio editor W4c, founder 2026-10-08: "Die klassische DAW Audio
// Editing View fehlt mir noch.").
//
// WHY: W4a gave a part fade lengths, W4b plays them, and nothing could set them —
// `TimelineStore.setRegionFades` had no caller. These are the door: two `EchoelValueField`s in
// BEATS (the part's own unit, so no tempo is needed to show or write them), each offering only
// what the other fade leaves, and the ramps drawn over the waveform.
//
// THE CLAIMS, AND WHICH KIND EACH IS (Tests/CISmoke/CLAUDE.md §1):
// 1. END-TO-END — `PartFades.lengths`: an audio part's fades AS THEY PLAY (an overlong stored
//    pair shows what is heard, "in wins"); nil for a MIDI part (its player never fades a part,
//    #164), a bio track's part, and a part that is gone.
// 2. END-TO-END — the units: beats ↔ ticks keeps every tick of a 16-beat part; junk beats are no
//    fade; a value past every tick holds instead of trapping; each range is what the other fade
//    leaves, down to a zero-width range.
// 3. END-TO-END — the pair stays as typed: on a 0.01-beat grid over the whole fade-in range (and
//    its off-grid top), the store's own rule (`FadeEnvelope.effective`) keeps both lengths
//    exactly; on the REAL store each field's release is ONE undo step, and an unchanged release
//    records nothing.
// 4. END-TO-END — the canvas: the window's fades are fractions of the part at ANY tempo, the
//    drawn level matches the PLAYER's plan (`AudioRegionPlayback.fadePlan`) at every 1/64 of an
//    unwarped and a warped part, and a part without fades draws at full level.
// 5. SOURCE-TEXT SCAN — the bar mounts the fields only behind `PartFades.lengths`, once; each
//    field drags a draft, writes once on release through `setRegionFades` (the leaf's two
//    writes), clears both drafts when the stored fades move; the bar is the one caller; the
//    canvas asks the one rule; the leaf draws the ramps before the file has landed and scales
//    every column; the four catalog keys say themselves.
// 6. COUNTERWEIGHT (#343) — the player still hands each part its plan, so the door moves sound.
//
// GRADING (§0/§3, no Swift toolchain in a web session): the file names `PartFades` and
// `AudioWindow.fadeLevel`, which this commit creates, so it does NOT COMPILE against the parent —
// no assertion has a verdict there (one absence, #486). Claims 1–4 are transcribed in Python
// against the work tree's arithmetic; claim 5 is a FORWARD guard, driven with the `code_only`
// port against the work tree, every anchor unique; claim 6 is a COUNTERWEIGHT, green on both
// trees. How the fields feel on glass, how a fade sounds and how the ramp reads at a small zoom
// are a DEVICE PROBE and open.

import XCTest
@testable import Echoelmusic

@MainActor
final class ThePartBarSetsTheFadesItPlaysTests: XCTestCase {

    private static let bar = "Sources/Echoelmusic/Studio/SelectedPartBar.swift"
    private static let canvas = "Sources/Echoelmusic/Studio/ArrangeCanvasView.swift"
    private static let leaf = "Sources/Echoelmusic/Studio/AudioPartWaveform.swift"
    private static let lanes = "Sources/Echoelmusic/Sequencer/AudioLanePlayer.swift"
    private static let catalog = "Sources/Echoelmusic/Resources/Localizable.xcstrings"

    private var restore: [() -> Void] = []

    override func tearDown() async throws {
        for undo in restore.reversed() { undo() }
        restore.removeAll()
        try await super.tearDown()
    }

    // MARK: 1 — which parts offer fades, and what they show

    func testOnlyAnAudioPartOffersItsFadesAsTheyPlay() {
        let beat = TimelineTime.ticksPerBeat
        let audio = TimelineLane(name: "Loop", kind: .audio)
        let keys = TimelineLane(name: "Keys", kind: .midi)
        let body = TimelineLane(name: "Body", kind: .audio, isBio: true)
        let faded = TimelineRegion(laneID: audio.id, clipID: UUID(), startTick: 0, lengthTicks: 16 * beat,
                                   fadeInTicks: 2 * beat, fadeOutTicks: 4 * beat)
        let overlong = TimelineRegion(laneID: audio.id, clipID: UUID(), startTick: 16 * beat,
                                      lengthTicks: 16 * beat, fadeInTicks: 10 * beat, fadeOutTicks: 10 * beat)
        let notes = TimelineRegion(laneID: keys.id, clipID: UUID(), startTick: 0, lengthTicks: 16 * beat,
                                   fadeInTicks: 2 * beat)
        let curve = TimelineRegion(laneID: body.id, clipID: UUID(), startTick: 0, lengthTicks: 16 * beat,
                                   fadeInTicks: 2 * beat)
        let document = TimelineDocument(lanes: [audio, keys, body], regions: [faded, overlong, notes, curve])
        XCTAssertEqual(PartFades.lengths(of: faded.id, in: document),
                       PartFades.Lengths(fadeInTicks: 2 * beat, fadeOutTicks: 4 * beat, lengthTicks: 16 * beat),
                       "an audio part shows the fades it plays")
        XCTAssertEqual(PartFades.lengths(of: overlong.id, in: document),
                       PartFades.Lengths(fadeInTicks: 10 * beat, fadeOutTicks: 6 * beat, lengthTicks: 16 * beat),
                       "a stored pair that does not fit shows what is HEARD — the fade-in wins, the fade-out gets the rest")
        XCTAssertNil(PartFades.lengths(of: notes.id, in: document),
                     "a MIDI part's player never fades a part — a field there would move nothing")
        XCTAssertNil(PartFades.lengths(of: curve.id, in: document), "a bio curve is not a part to fade")
        XCTAssertNil(PartFades.lengths(of: UUID(), in: document), "a part that is gone has no fades")
    }

    // MARK: 2 — beats on the glass, ticks in the store

    func testTheFieldsSpeakBeatsAndKeepEveryTick() {
        let beat = TimelineTime.ticksPerBeat
        var lost: [Int] = []
        for ticks in 0...(16 * beat) where PartFades.ticks(fromBeats: PartFades.beats(fromTicks: ticks)) != ticks {
            lost.append(ticks)
        }
        XCTAssertEqual(lost, [], "a tick that does not survive beats and back is a fade the field cannot show")
        XCTAssertEqual(PartFades.beats(fromTicks: beat), 1)
        XCTAssertEqual(PartFades.ticks(fromBeats: 1), beat)
        XCTAssertEqual(PartFades.ticks(fromBeats: 0.5), beat / 2)
        let noFade: [Double] = [0, -1, -.infinity, .nan, .infinity]
        for beats in noFade {
            XCTAssertEqual(PartFades.ticks(fromBeats: beats), 0, "\(beats) beats is no fade")
        }
        XCTAssertEqual(PartFades.ticks(fromBeats: 1e300), Int.max, "past every tick holds — never a trap")

        let pair = PartFades.Lengths(fadeInTicks: 2 * beat, fadeOutTicks: 4 * beat, lengthTicks: 16 * beat)
        XCTAssertEqual(PartFades.inRange(pair), 0...12, "the fade-in may take what the fade-out leaves")
        XCTAssertEqual(PartFades.outRange(pair), 0...14, "the fade-out may take what the fade-in leaves")
        let whole = PartFades.Lengths(fadeInTicks: 16 * beat, fadeOutTicks: 0, lengthTicks: 16 * beat)
        XCTAssertEqual(PartFades.inRange(whole), 0...16)
        XCTAssertEqual(PartFades.outRange(whole), 0...0, "a fade-in over the whole part leaves the fade-out no room")
    }

    // MARK: 3 — the pair stays as typed; one release, one undo step

    func testAReleaseIsOneStepAndNeverShortensTheOtherFade() {
        let beat = TimelineTime.ticksPerBeat
        // The rule, on the field's own 0.01-beat grid and at an off-grid top (5000 ticks).
        for pair in [PartFades.Lengths(fadeInTicks: 2 * beat, fadeOutTicks: 4 * beat, lengthTicks: 16 * beat),
                     PartFades.Lengths(fadeInTicks: 0, fadeOutTicks: 2_680, lengthTicks: 7_680)] {
            let top = PartFades.inRange(pair).upperBound
            let steps: [Int] = Array(0...Int((top * 100).rounded(.down)))
            let grid: [Double] = steps.map { step in Double(step) / 100 } + [top]
            var changed: [Double] = []
            for value in grid {
                let fadeIn = PartFades.ticks(fromBeats: value)
                let kept = FadeEnvelope.effective(fadeIn: Double(fadeIn), fadeOut: Double(pair.fadeOutTicks),
                                                  duration: Double(pair.lengthTicks))
                if kept.fadeIn != Double(fadeIn) || kept.fadeOut != Double(pair.fadeOutTicks) { changed.append(value) }
            }
            XCTAssertEqual(changed, [], """
                a fade-in the field offers is changed by the store's rule at \(changed) beats — the \
                field would show one pair and the part would play another
                """)
        }

        let timeline = TimelineStore()
        let original = timeline.document
        restore.append { timeline.replaceDocument(original) }
        let audio = TimelineLane(name: "Loop", kind: .audio)
        let part = TimelineRegion(laneID: audio.id, clipID: UUID(), startTick: 0, lengthTicks: 16 * beat,
                                  fadeInTicks: 2 * beat, fadeOutTicks: 4 * beat)
        timeline.replaceDocument(TimelineDocument(lanes: [audio], regions: [part]))
        func now() -> PartFades.Lengths? { PartFades.lengths(of: part.id, in: timeline.document) }
        guard let start = now() else { return XCTFail("an audio part offers its fades") }
        XCTAssertFalse(timeline.canUndo, "a replaced song starts with no history")

        // The fade-in field's release, as `commitIn` writes it, at the top of its range.
        timeline.setRegionFades(id: part.id, fadeInTicks: PartFades.ticks(fromBeats: PartFades.inRange(start).upperBound),
                                fadeOutTicks: start.fadeOutTicks)
        XCTAssertEqual(now(), PartFades.Lengths(fadeInTicks: 12 * beat, fadeOutTicks: 4 * beat, lengthTicks: 16 * beat),
                       "the fade-in takes all the room it was offered and the fade-out stays")
        timeline.undo()
        XCTAssertEqual(now(), start, "ONE undo step puts it back")
        XCTAssertFalse(timeline.canUndo, "and it was exactly one")

        // The fade-out field's release, as `commitOut` writes it.
        timeline.setRegionFades(id: part.id, fadeInTicks: start.fadeInTicks,
                                fadeOutTicks: PartFades.ticks(fromBeats: PartFades.outRange(start).upperBound))
        XCTAssertEqual(now(), PartFades.Lengths(fadeInTicks: 2 * beat, fadeOutTicks: 14 * beat, lengthTicks: 16 * beat))
        timeline.undo()
        XCTAssertEqual(now(), start)
        XCTAssertFalse(timeline.canUndo)

        timeline.setRegionFades(id: part.id, fadeInTicks: PartFades.ticks(fromBeats: 2), fadeOutTicks: start.fadeOutTicks)
        XCTAssertFalse(timeline.canUndo, "a release that changes nothing records nothing")
    }

    // MARK: 4 — the canvas draws what the ear hears

    func testTheCanvasDrawsTheFadesThePlayerPlays() {
        let beat = TimelineTime.ticksPerBeat
        let clip = Clip(name: "Loop", kind: .audio, mediaRef: "loop.wav")
        let faded = TimelineRegion(laneID: UUID(), clipID: clip.id, startTick: 0, lengthTicks: 16 * beat,
                                   contentOffsetSeconds: 1.5, fadeInTicks: 4 * beat, fadeOutTicks: 8 * beat)
        let tempi: [Double] = [60, 90, 120]
        for bpm in tempi {
            guard let window = ArrangeCanvas.audioWindow(for: faded, clip: clip, bpm: bpm) else {
                XCTFail("an audio part at \(bpm) has a window")
                continue
            }
            XCTAssertEqual(window.fadeIn, 0.25, accuracy: 1e-12, "a quarter of the part at \(bpm) — the fade is tempo-free")
            XCTAssertEqual(window.fadeOut, 0.5, accuracy: 1e-12)
        }
        guard let window = ArrangeCanvas.audioWindow(for: faded, clip: clip, bpm: 120) else {
            return XCTFail("an audio part at 120 has a window")
        }
        let levels: [(Double, Double)] = [(0, 0), (0.125, 0.5), (0.25, 1), (0.5, 1), (0.75, 0.5), (1, 0)]
        for (fraction, level) in levels {
            XCTAssertEqual(window.fadeLevel(atFraction: fraction), level, accuracy: 1e-12, "level at \(fraction)")
        }

        let overlong = TimelineRegion(laneID: UUID(), clipID: clip.id, startTick: 0, lengthTicks: 16 * beat,
                                      fadeInTicks: 20 * beat, fadeOutTicks: 3 * beat)
        let held = ArrangeCanvas.audioWindow(for: overlong, clip: clip, bpm: 120)
        XCTAssertEqual(held?.fadeIn, 1, "a fade-in past the part is drawn over the whole part")
        XCTAssertEqual(held?.fadeOut, 0, "and leaves the fade-out nothing — as it plays")

        let bare = TimelineRegion(laneID: UUID(), clipID: clip.id, startTick: 0, lengthTicks: 16 * beat)
        guard let plain = ArrangeCanvas.audioWindow(for: bare, clip: clip, bpm: 120) else {
            return XCTFail("a part without fades has a window")
        }
        XCTAssertEqual(plain.fadeIn, 0)
        XCTAssertEqual(plain.fadeOut, 0)
        for step in 0...8 {
            XCTAssertEqual(plain.fadeLevel(atFraction: Double(step) / 8), 1, "a part without fades is drawn at full level")
        }

        // Drawn = heard: the canvas level against the player's own plan, unwarped and warped.
        let warpedClip = Clip(name: "Loop", kind: .audio, mediaRef: "loop.wav", nativeBPM: 60)
        let warped = TimelineRegion(laneID: UUID(), clipID: warpedClip.id, startTick: 0, lengthTicks: 16 * beat,
                                    contentOffsetSeconds: 0.5, warpEnabled: true,
                                    fadeInTicks: 3 * beat, fadeOutTicks: 5 * beat)
        for (region, source) in [(faded, clip), (warped, warpedClip)] {
            let rate = StretchPlan.resolve(mode: region.stretchMode, warpEnabled: region.warpEnabled,
                                           nativeBPM: source.nativeBPM, projectBPM: 120,
                                           capabilities: StretchMode.timelineCapabilities).rate
            if region.warpEnabled {
                XCTAssertNotEqual(rate, 1, "premise: the warped part is really stretched at 120")
            }
            guard let heard = AudioRegionPlayback.fadePlan(for: region, bpm: 120, stretchRate: rate),
                  let drawn = ArrangeCanvas.audioWindow(for: region, clip: source, bpm: 120) else {
                XCTFail("a faded part has a plan and a window")
                continue
            }
            for step in 0...64 {
                let fraction = Double(step) / 64
                XCTAssertEqual(drawn.fadeLevel(atFraction: fraction),
                               heard.gain(atMediaSeconds: heard.partStart + fraction * heard.duration),
                               accuracy: 1e-9, "drawn and heard part at \(fraction) of the part (rate \(rate))")
            }
        }
    }

    // MARK: 5 — the door, its one writer, and the drawing

    func testTheFieldsDraftAndWriteOnceThroughTheStore() throws {
        let code = try source(Self.bar)
        guard let bodyStart = code.range(of: "var body: some View {"),
              let trims = code.range(of: "private struct Trims {", range: bodyStart.upperBound..<code.endIndex),
              let leaf = code.range(of: "private struct PartFadeFields: View {") else {
            return XCTFail("ANCHOR MISSING: the part bar's body or `PartFadeFields` (#454)")
        }
        let body = String(code[bodyStart.upperBound..<trims.lowerBound])
        guard let gate = body.range(of: "if let fades = PartFades.lengths(of: regionID, in: document) {"),
              let mount = body.range(of: "PartFadeFields(regionID: regionID, lengths: fades)") else {
            return XCTFail("the bar no longer mounts the fade fields behind `PartFades.lengths`")
        }
        XCTAssertLessThan(gate.lowerBound, mount.lowerBound, "the fields appear only for a part that can fade")
        XCTAssertEqual(code.components(separatedBy: "PartFadeFields(").count - 1, 1, "mounted once")

        // The leaf's OWN struct, to its column-0 close: AE-10c's `PartPitchField` follows it and
        // reads `player.` on purpose, which the open slice would have read as this leaf's (#408).
        let afterLeaf = code[leaf.upperBound...]
        let fields = String(afterLeaf[..<(afterLeaf.range(of: "\n}\n")?.lowerBound ?? afterLeaf.endIndex)])
        guard let first = fields.range(of: "EchoelValueField(label: \"Fade in\","),
              let second = fields.range(of: "EchoelValueField(label: \"Fade out\",", range: first.upperBound..<fields.endIndex),
              let shown = fields.range(of: "private var shownIn: Double {", range: second.upperBound..<fields.endIndex),
              let commitIn = fields.range(of: "private func commitIn() {", range: shown.upperBound..<fields.endIndex),
              let commitOut = fields.range(of: "private func commitOut() {", range: commitIn.upperBound..<fields.endIndex) else {
            return XCTFail("the leaf no longer offers \"Fade in\" then \"Fade out\" and commits through `commitIn` / `commitOut`")
        }
        let fadeIn = String(fields[first.upperBound..<second.lowerBound])
        let rest = String(fields[second.upperBound..<shown.lowerBound])
        for needle in ["value: Binding(get: { shownIn }, set: { draftIn = $0 }),", "range: PartFades.inRange(lengths),",
                       "unit: \"beats\",", "onCommit: { commitIn() })"] {
            XCTAssertTrue(fadeIn.contains(needle), "the fade-in field lost `\(needle)`")
        }
        for needle in ["value: Binding(get: { shownOut }, set: { draftOut = $0 }),", "range: PartFades.outRange(lengths),",
                       "unit: \"beats\",", "onCommit: { commitOut() })", ".onChange(of: lengths) { _, _ in",
                       "draftIn = nil", "draftOut = nil"] {
            XCTAssertTrue(rest.contains(needle), "the fade-out field or the draft reset lost `\(needle)`")
        }
        for call in [fadeIn, rest] {
            XCTAssertFalse(call.contains("setRegionFades("),
                           "the drag writes a DRAFT — a write per step would stack an undo step per value crossed")
            XCTAssertFalse(call.contains("onChange:"),
                           "`onChange` fires per drag event — routed to the store, every value crossed is a write")
        }
        let inBody = String(fields[commitIn.upperBound..<commitOut.lowerBound])
        let outBody = String(fields[commitOut.upperBound...])
        XCTAssertTrue(inBody.contains("timeline.setRegionFades(id: regionID, fadeInTicks: PartFades.ticks(fromBeats: value),"))
        XCTAssertTrue(inBody.contains("fadeOutTicks: lengths.fadeOutTicks)"), "the fade-in's release writes the fade-out back as it stands")
        XCTAssertTrue(outBody.contains("timeline.setRegionFades(id: regionID, fadeInTicks: lengths.fadeInTicks,"),
                      "the fade-out's release writes the fade-in back as it stands")
        XCTAssertTrue(outBody.contains("fadeOutTicks: PartFades.ticks(fromBeats: value))"))
        XCTAssertEqual(fields.components(separatedBy: "setRegionFades(").count - 1, 2, "one write per release, two fields")
        for banned in ["Slider(", "Stepper(", "player."] {
            XCTAssertFalse(fields.contains(banned), """
                the fade leaf contains `\(banned)` — one control (`EchoelValueField`), and no tempo: the \
                fields speak beats, the part's own unit
                """)
        }

        let callers = try sourceFiles { $0.contains(".setRegionFades(") }
        XCTAssertEqual(callers, [Self.bar], """
            `setRegionFades` is called from \(callers). The part bar is its one door; a second surface \
            writing a part's fades is a second editor of one value.
            """)
    }

    func testTheCanvasAsksTheOneRuleAndDrawsTheRamps() throws {
        let canvas = try source(Self.canvas)
        guard let window = canvas.range(of: "struct AudioWindow: Equatable, Sendable {"),
              let level = canvas.range(of: "func fadeLevel(atFraction fraction: Double) -> Double {", range: window.upperBound..<canvas.endIndex),
              let pure = canvas.range(of: "nonisolated static func audioWindow(for region: TimelineRegion, clip: Clip?,"),
              let pureEnd = canvas.range(of: "struct ArrangeCanvasView: View {", range: pure.upperBound..<canvas.endIndex) else {
            return XCTFail("ANCHOR MISSING: `AudioWindow.fadeLevel` or `audioWindow(for:)` (#454)")
        }
        XCTAssertTrue(canvas[level.upperBound...].prefix(160)
                        .contains("FadeEnvelope.gain(atElapsed: fraction, duration: 1, fadeIn: fadeIn, fadeOut: fadeOut)"),
                      "the canvas asks the one fade rule (#416) — a second copy would draw a fade nobody hears")
        let builder = String(canvas[pure.upperBound..<pureEnd.lowerBound])
        XCTAssertTrue(builder.contains("FadeEnvelope.effective(fadeIn: Double(region.fadeInTicks),"),
                      "the window holds the fades as they play, the player's own rule")

        let leaf = try source(Self.leaf)
        guard let canvasStart = leaf.range(of: "Canvas { context, size in"),
              let ramps = leaf.range(of: "Self.drawRamps(window, in: &context, size: size, tint: tint)",
                                     range: canvasStart.upperBound..<leaf.endIndex),
              let landed = leaf.range(of: "guard let overview else { return }", range: canvasStart.upperBound..<leaf.endIndex),
              let loop = leaf.range(of: "for (index, column) in columns.enumerated() {", range: landed.upperBound..<leaf.endIndex),
              let scaled = leaf.range(of: "window.fadeLevel(atFraction: (Double(index) + 0.5) / Double(columns.count))",
                                      range: loop.upperBound..<leaf.endIndex),
              let draw = leaf.range(of: "private nonisolated static func drawRamps(") else {
            return XCTFail("ANCHOR MISSING: the waveform's ramps or its column loop (#454)")
        }
        XCTAssertLessThan(ramps.lowerBound, landed.lowerBound, "the ramps are drawn while the file is still being read")
        XCTAssertLessThan(loop.lowerBound, scaled.lowerBound)
        for needle in ["CGFloat(column.max) * level * mid", "CGFloat(column.min) * level * mid", "CGFloat(column.rms) * level * mid"] {
            XCTAssertTrue(leaf.contains(needle), "every column is drawn at the level its fades leave it: `\(needle)` is gone")
        }
        let drawing = String(leaf[draw.upperBound...])
        XCTAssertTrue(drawing.contains("guard size.width > 0, size.height > 0, window.fadeIn > 0 || window.fadeOut > 0 else { return }"),
                      "a part without fades draws no ramp")
        XCTAssertTrue(drawing.contains("context.stroke(ramps, with: .color(tint), lineWidth: Self.rampWidth)"))
    }

    func testTheFourNewWordsAreInTheCatalog() throws {
        let url = Self.root.appendingPathComponent(Self.catalog)
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let strings = json?["strings"] as? [String: Any] ?? [:]
        XCTAssertGreaterThan(strings.count, 100, "the catalog read as \(strings.count) keys — the wrong file")
        let keys = ["Fade in", "Fade out",
                    "How long the part rises from silence at its start. The two fades share the part; each can use what the other leaves.",
                    "How long the part falls to silence at its end. The two fades share the part; each can use what the other leaves."]
        for key in keys {
            let entry = strings[key] as? [String: Any]
            let english = ((entry?["localizations"] as? [String: Any])?["en"] as? [String: Any])?["stringUnit"] as? [String: Any]
            XCTAssertEqual(english?["value"] as? String, key, "the catalog lacks `\(key)` or says something else")
        }
        let bar = try source(Self.bar)
        for hint in keys.suffix(2) {
            XCTAssertTrue(bar.contains("hint: String(localized: \"\(hint)\"),"), "the field's hint is no longer the catalog key")
        }
    }

    // MARK: 6 — counterweight: the fades the door sets are played

    func testThePlayerStillHandsEachPartItsFades() throws {
        let player = try source(Self.lanes)
        XCTAssertTrue(player.contains("lane.setFades(AudioRegionPlayback.fadePlan(for: region, bpm: bpm, stretchRate: plan.rate))"), """
            `AudioLanePlayer.start` no longer hands each part its fade plan (W4b) — the fields would then set \
            fades nobody hears, a door to nothing (#164).
            """)
    }

    // MARK: helpers

    private static var root: URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return root
    }

    private func source(_ relativePath: String) throws -> String {
        let text = try String(contentsOf: Self.root.appendingPathComponent(relativePath), encoding: .utf8)
        return SourceText.codeOnly(text)
    }

    /// The `Sources/` files whose code (comments stripped) satisfies `matches`, repo-relative, sorted.
    private func sourceFiles(_ matches: (String) -> Bool) throws -> [String] {
        let base = Self.root.appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(atPath: base.path) else {
            XCTFail("cannot enumerate Sources/ — a scan that saw nothing is not a pass")
            return []
        }
        var hits: [String] = []
        var seen = 0
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            seen += 1
            guard let text = try? String(contentsOf: base.appendingPathComponent(relative), encoding: .utf8) else {
                continue
            }
            if matches(SourceText.codeOnly(text)) { hits.append("Sources/" + relative) }
        }
        XCTAssertGreaterThan(seen, 200, "the walk saw \(seen) files — the wrong directory")
        return hits.sorted()
    }
}
