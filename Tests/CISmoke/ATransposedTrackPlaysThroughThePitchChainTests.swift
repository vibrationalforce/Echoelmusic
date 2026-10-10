// ATransposedTrackPlaysThroughThePitchChainTests.swift
// Echoel — #165 (founder 2026-09-23, "all tasks"): an audio track's parts can play higher or
// lower in whole semitones, tempo unchanged.
//
// WHAT KIND OF GUARD THIS IS (§1). Claims 1–5 are END-TO-END BEHAVIOUR over the public,
// Foundation-only `AudioTranspose`, `StretchPlan` and `TimelineDocument`. Claims 6–7 are
// END-TO-END over `AudioLanePlayer` with a test-local spy sink — the coordinator that decides
// which chain a part plays through; no AVFoundation, no store. Claims 8–10 are SOURCE-TEXT
// SCANS of the device sink, the one store caller and the surface. Whether a transposed part
// SOUNDS right, and whether the pitch node's delay is audible, are DEVICE questions:
// NEEDS-FOUNDER-VERIFY (36)–(43) in `Studio/WorkstationView.swift`.
//
// HONEST GRADING (§3). `AudioTranspose` and `AudioRegionSink.setTranspose` are created by this
// commit, so the file does not compile against the parent and NO assertion has a verdict
// there — every behavioural claim is a FORWARD guard. Graded by TRANSCRIPTION: the cents
// arithmetic re-driven in Python (tape 1200·log2(4) = 2400; +12 on top clamps to 2400), and the
// prime → start event order read off `AudioLanePlayer.prime`/`start`. The scans were driven
// against the worktree (present) and the parent (absent — ONE absence, #486).
//
// COUNTERWEIGHTS (#343): claim 1 (untransposed, unwarped playback keeps the plain node), the
// transpose-0 halves of claims 6 and 7 (today's warp and Beats gates are unchanged), and claim
// 5's MIDI and bio lanes (the audio path never reads their transpose).
//
// ⭐ GMMW AE-10b (2026-10-08) — A PART'S PITCH IS PLAYED AS TRACK + PART. Claims 11–12 are
// END-TO-END over `AudioTranspose.semitones(for:in:)` and the spy coordinator; claim 13 is a
// SOURCE-TEXT SCAN that the player asks that one function, at every place it decides a pitch.
// Grading against the parent `220d641`: `semitones(for:in:)` does not exist there, so the
// file does not compile and no assertion has a verdict (one absence, #486); transcribed in
// Python instead — 11 and 12 are FORWARD, 13 is a REGRESSION guard in its absence half (the
// parent's prime and start ask the TRACK alone, three sites) and FORWARD in its presence half.
// Claims 1–10 are unchanged and stay green: every part they build is at pitch 0, where the sum
// IS the track's pitch. Stripper `SourceText.codeOnly` for claim 13: PROPHYLAKTISCH — 0 of its
// 6 verdicts (3 needles × 2 trees) flip between raw and stripped text.
// AE-10 review fix: claim 14 (END-TO-END, spy) and claim 15 (SOURCE, inside claim 8's method)
// are REGRESSION guards against `c8069e1`, where a prime while playing asked `warped: true` for
// a pitch-only part and `play` attached a missing chain unconditionally — the mid-song attach
// an Undo could reach. Transcribed: the spy order by hand off `prime`/`start`; both needles
// absent on `c8069e1`, present here.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class ATransposedTrackPlaysThroughThePitchChainTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar

    /// 1. COUNTERWEIGHT — the golden path: no warp, no transpose → the plain node.
    func testAnUntransposedUnwarpedPartKeepsThePlainNode() {
        XCTAssertFalse(AudioTranspose.needsTimePitchChain(plan: .unstretched, semitones: 0))
        XCTAssertEqual(AudioTranspose.nodePitchCents(plan: .unstretched, semitones: 0), 0)
    }

    /// 2. A transpose alone routes through the chain and sets the node's pitch in cents.
    func testATransposeAloneSetsTheNodePitch() {
        XCTAssertTrue(AudioTranspose.needsTimePitchChain(plan: .unstretched, semitones: 7))
        XCTAssertEqual(AudioTranspose.nodePitchCents(plan: .unstretched, semitones: 7), 700)
        XCTAssertEqual(AudioTranspose.nodePitchCents(plan: .unstretched, semitones: -12), -1200)
    }

    /// 3. With a warp: Clean holds pitch so only the transpose remains; Tape adds its own
    /// trajectory — the engine's own function (#416) — and the sum is clamped to the node.
    func testTheTransposeStacksOnTheWarpPlan() {
        let clean = StretchPlan.resolve(mode: .clean, warpEnabled: true, nativeBPM: 100,
                                        projectBPM: 125,
                                        capabilities: StretchMode.timelineCapabilities)
        XCTAssertNotEqual(clean.rate, 1.0, "premise: the fixture is actually warped")
        XCTAssertEqual(AudioTranspose.nodePitchCents(plan: clean, semitones: 5), 500)

        let fastTape = StretchPlan(rate: 4, preservesPitch: false, mode: .tape)
        XCTAssertEqual(AudioTranspose.nodePitchCents(plan: fastTape, semitones: 12),
                       Float(AudioTranspose.nodeCentsLimit),
                       "tape 2400 plus 1200 must clamp to the node's range")
        let tape = StretchPlan(rate: 1.25, preservesPitch: false, mode: .tape)
        XCTAssertEqual(AudioTranspose.nodePitchCents(plan: tape, semitones: 0),
                       Float(StretchPlan.tapePitchCents(forRate: 1.25)), accuracy: 0.001)
    }

    /// 4. The range is derived from the node, and the field can never trap.
    func testTheRangeIsTheNodesAndTheFieldCannotTrap() {
        XCTAssertEqual(AudioTranspose.semitoneRange.upperBound * 100,
                       Int(AudioTranspose.nodeCentsLimit))
        XCTAssertEqual(AudioTranspose.semitoneRange.lowerBound,
                       -AudioTranspose.semitoneRange.upperBound)
        XCTAssertEqual(AudioTranspose.clamped(99), AudioTranspose.semitoneRange.upperBound)
        XCTAssertEqual(AudioTranspose.clamped(-99), AudioTranspose.semitoneRange.lowerBound)
        XCTAssertEqual(AudioTranspose.semitones(fromField: .nan), 0)
        XCTAssertEqual(AudioTranspose.semitones(fromField: .infinity), 0)
        XCTAssertEqual(AudioTranspose.semitones(fromField: -.infinity), 0)
        XCTAssertEqual(AudioTranspose.semitones(fromField: 3.6), 4)
        XCTAssertEqual(AudioTranspose.semitones(fromField: 1e12),
                       AudioTranspose.semitoneRange.upperBound)
    }

    /// 5. Only a plain AUDIO lane's transpose reaches the audio path.
    func testOnlyAnAudioLanesTransposeIsPlayed() {
        var midi = TimelineLane(name: "Keys", kind: .midi)
        midi.transposeSemitones = 7
        var bio = TimelineLane(name: "Body", kind: .audio, isBio: true)
        bio.transposeSemitones = 7
        var audio = TimelineLane(name: "Audio 1", kind: .audio)
        audio.transposeSemitones = 7
        var legacy = TimelineLane(name: "Audio 2", kind: .audio)
        legacy.transposeSemitones = 40
        let doc = TimelineDocument(lanes: [midi, bio, audio, legacy])
        XCTAssertEqual(AudioTranspose.semitones(laneID: midi.id, in: doc), 0)
        XCTAssertEqual(AudioTranspose.semitones(laneID: bio.id, in: doc), 0)
        XCTAssertEqual(AudioTranspose.semitones(laneID: UUID(), in: doc), 0)
        XCTAssertEqual(AudioTranspose.semitones(laneID: audio.id, in: doc), 7)
        XCTAssertEqual(AudioTranspose.semitones(laneID: legacy.id, in: doc),
                       AudioTranspose.semitoneRange.upperBound,
                       "a legacy store value above the node's range plays clamped")
    }

    // MARK: - The coordinator, end to end

    private enum Event: Equatable {
        case preload(warped: Bool)
        case transpose(Int)
        case play
        case beats
    }

    @MainActor
    private final class Spy: AudioRegionSink {
        var events: [Event] = []
        func play(url: URL, fromSeconds: Double, lengthSeconds: Double, gain: Float,
                  stretch: StretchPlan) { events.append(.play) }
        func stop() {}
        func preload(url: URL, warped: Bool) { events.append(.preload(warped: warped)) }
        func prepareBeats(url: URL, fromSeconds: Double, lengthSeconds: Double, rate: Double) {
            events.append(.beats)
        }
        func setTranspose(_ semitones: Int) { events.append(.transpose(semitones)) }
    }

    private func primed(transpose: Int, part: Int = 0, mode: StretchMode = .clean,
                        warped: Bool = false) -> [Event] {
        var lane = TimelineLane(name: "Audio 1", kind: .audio)
        lane.transposeSemitones = transpose
        let clipID = UUID()
        let region = TimelineRegion(laneID: lane.id, clipID: clipID, startTick: 0,
                                    lengthTicks: 4 * Self.bar, warpEnabled: warped,
                                    stretchMode: mode, transposeSemitones: part)
        let doc = TimelineDocument(lanes: [lane], regions: [region])
        let spy = Spy()
        let url = URL(fileURLWithPath: "/tmp/loop.wav")
        let player = AudioLanePlayer(makeSink: { spy },
                                     resolveURL: { $0 == clipID ? url : nil },
                                     resolveNativeBPM: { _ in 100 })
        player.prime(in: doc, atTick: 0, bpm: 120)
        return spy.events
    }

    /// 6. A transposed lane attaches the chain at PRIME time and hands the sink its pitch
    /// before the part plays. Counterweight: at 0 the unwarped part preloads the plain path.
    func testATransposedLaneIsPrimedForTheChainAndPitchedBeforePlay() {
        XCTAssertEqual(primed(transpose: 5), [.preload(warped: true), .transpose(5), .play])
        XCTAssertEqual(primed(transpose: 0), [.preload(warped: false), .transpose(0), .play],
                       "an untransposed, unwarped lane must keep today's plain path")
    }

    /// 7. A transposed Beats part skips the pre-render — its buffer plays on the plain node
    /// and could not be pitched. Counterweight: at 0 it is pre-rendered exactly once.
    func testATransposedBeatsPartIsNotPreRendered() {
        XCTAssertFalse(primed(transpose: 3, mode: .beats, warped: true).contains(.beats))
        XCTAssertEqual(primed(transpose: 0, mode: .beats, warped: true).filter { $0 == .beats }.count, 1)
    }

    // MARK: - AE-10b: a part's pitch is played as track + part

    /// 11. The sink is handed the SUM, and prime attaches the chain for it. Counterweights: a
    /// part that cancels its track sums to 0 and keeps today's plain path and Beats buffer.
    func testThePartsPitchIsPlayedOnTopOfTheTracks() {
        XCTAssertEqual(primed(transpose: 5, part: 2), [.preload(warped: true), .transpose(7), .play])
        XCTAssertEqual(primed(transpose: 0, part: 3), [.preload(warped: true), .transpose(3), .play],
                       "a part's own pitch alone must attach the chain at prime time, never mid-song")
        XCTAssertEqual(primed(transpose: 5, part: -5), [.preload(warped: false), .transpose(0), .play],
                       "a part that cancels its track plays on the plain node, bit-identical to no pitch")
        XCTAssertFalse(primed(transpose: 0, part: 3, mode: .beats, warped: true).contains(.beats),
                       "a part-pitched Beats part must not take the un-pitched buffer")
        XCTAssertEqual(primed(transpose: 5, part: -5, mode: .beats, warped: true)
                        .filter { $0 == .beats }.count, 1,
                       "a Beats part whose pitches cancel keeps its pre-rendered buffer")
    }

    /// 12. The one place the two meet: the track half as its field shows it, the sum held to
    /// the range, a hand-set extreme cannot overflow, and a MIDI or bio track plays no pitch.
    func testTheSumIsTheTracksShownPitchPlusThePartsHeldToTheRange() {
        let top = AudioTranspose.semitoneRange.upperBound
        var legacy = TimelineLane(name: "Audio 2", kind: .audio)
        legacy.transposeSemitones = top + 16
        var audio = TimelineLane(name: "Audio 1", kind: .audio)
        audio.transposeSemitones = top - 4
        var midi = TimelineLane(name: "Keys", kind: .midi)
        midi.transposeSemitones = 7
        var bio = TimelineLane(name: "Body", kind: .audio, isBio: true)
        bio.transposeSemitones = 7
        let doc = TimelineDocument(lanes: [legacy, audio, midi, bio])
        func part(on lane: TimelineLane, _ semitones: Int) -> TimelineRegion {
            TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: 0, lengthTicks: Self.bar,
                           transposeSemitones: semitones)
        }
        XCTAssertEqual(AudioTranspose.semitones(for: part(on: legacy, -10), in: doc), top - 10,
                       "a legacy track above the range counts as the pitch its field shows")
        XCTAssertEqual(AudioTranspose.semitones(for: part(on: audio, 10), in: doc), top,
                       "the sum is held to the range the node can play")
        XCTAssertEqual(AudioTranspose.semitones(for: part(on: audio, 0), in: doc),
                       AudioTranspose.semitones(laneID: audio.id, in: doc),
                       "a part at 0 plays exactly its track's pitch — today's behaviour")
        var extreme = part(on: audio, 0)
        extreme.transposeSemitones = Int.max
        XCTAssertEqual(AudioTranspose.semitones(for: extreme, in: doc), top, "a hand-set Int.max cannot overflow the sum")
        XCTAssertEqual(AudioTranspose.semitones(for: part(on: midi, 5), in: doc), 0)
        XCTAssertEqual(AudioTranspose.semitones(for: part(on: bio, 5), in: doc), 0)
        let stray = TimelineRegion(laneID: UUID(), clipID: UUID(), startTick: 0, lengthTicks: Self.bar,
                                   transposeSemitones: 5)
        XCTAssertEqual(AudioTranspose.semitones(for: stray, in: doc), 0, "a part without a track plays no pitch")
    }

    /// 13. The player asks the one function wherever it decides a pitch — the chain to attach,
    /// the Beats bypass, and what the sink plays — and no longer asks the track alone. A second
    /// spelling there would let prime and start disagree about a part, which is a mid-song
    /// attach (review HIGH 2) or an unpitched Beats buffer.
    func testThePlayerAsksTheOneSumEverywhere() throws {
        let player = try code("Sources/Echoelmusic/Sequencer/AudioLanePlayer.swift")
        XCTAssertEqual(player.components(separatedBy: "AudioTranspose.semitones(for: region, in: doc)").count - 1, 4,
                       "prime's chain question, prime's Beats bypass, start's setTranspose and the grain's pitch bypass (GA-10c, `grainToPlay`) each ask the sum")
        XCTAssertFalse(player.contains("semitones(laneID:"),
                       "the player asks the TRACK's pitch alone again — a part's own pitch would go unheard")
        let start = try XCTUnwrap(body(of: "private func start(", in: player), "ANCHOR MISSING: start")
        XCTAssertTrue(start.contains("lane.setTranspose(AudioTranspose.semitones(for: region, in: doc))"),
                      "the sink must be handed the part's sum right before it plays")
    }

    /// 14. AE-10 review (MED): a pitch ALONE asks for the chain only in the prime that STARTS
    /// playback. A re-prime while the piece plays (a structure edit — an Undo that pitched a part)
    /// must not ask, because attaching a chain then pauses the whole engine (review HIGH 2); the
    /// sink plays the part unpitched until the next Play (claim 15). Counterweights: a WARPED
    /// part still asks on every prime (its lazy attach is unchanged), and after a stop the next
    /// start asks again.
    func testOnlyTheStartingPrimeAsksForAPitchOnlyChain() {
        func reprimed(part: Int, warped: Bool) -> (start: [Event], playing: [Event], restart: [Event]) {
            let lane = TimelineLane(name: "Audio 1", kind: .audio)
            let clipID = UUID()
            let region = TimelineRegion(laneID: lane.id, clipID: clipID, startTick: 0,
                                        lengthTicks: 4 * Self.bar, warpEnabled: warped,
                                        transposeSemitones: part)
            let doc = TimelineDocument(lanes: [lane], regions: [region])
            let spy = Spy()
            let url = URL(fileURLWithPath: "/tmp/loop.wav")
            let player = AudioLanePlayer(makeSink: { spy },
                                         resolveURL: { $0 == clipID ? url : nil },
                                         resolveNativeBPM: { _ in 100 })
            player.prime(in: doc, atTick: 0, bpm: 120)
            let start = spy.events
            spy.events = []
            player.prime(in: doc, atTick: 0, bpm: 120)   // a structure edit while playing
            let playing = spy.events
            spy.events = []
            player.stopAll()
            player.prime(in: doc, atTick: 0, bpm: 120)   // the next Play
            return (start, playing, spy.events)
        }
        let pitched = reprimed(part: 5, warped: false)
        XCTAssertEqual(pitched.start, [.preload(warped: true), .transpose(5), .play],
                       "the starting prime attaches the chain for a pitched part")
        XCTAssertEqual(pitched.playing, [.preload(warped: false), .transpose(5), .play],
                       "a prime while playing must not ask for a pitch-only chain — a mid-song attach pauses the engine")
        XCTAssertEqual(pitched.restart, [.preload(warped: true), .transpose(5), .play],
                       "after a stop the next start asks again")
        let warpOnly = reprimed(part: 0, warped: true)
        XCTAssertEqual(warpOnly.playing.first, .preload(warped: true),
                       "a WARPED part keeps asking on every prime — this rule is about pitch alone")
    }

    // MARK: - Source scans

    /// 8. The device sink decides the route through `AudioTranspose`, and the Beats shortcut
    /// is bypassed while transposed.
    func testTheSinkRoutesThroughTheDecision() throws {
        let sink = try code("Sources/Echoelmusic/Sequencer/TimelineAudioSink.swift")
        XCTAssertTrue(sink.contains("AudioTranspose.needsTimePitchChain("))
        // 15. AE-10 review (MED): `play` never ATTACHES a chain needed only for a pitch — it uses
        // one the starting prime attached, else the plain node — while a warped plan keeps its
        // lazy attach. The coordinator half is claim 14.
        XCTAssertTrue(sink.contains("let chain = stretch.rate != 1.0 ? ensureWarpChain(for: key) : warpChains[key] {"),
                      "a pitch-only part reached mid-song would attach a chain and pause the engine")
        let player = try code("Sources/Echoelmusic/Sequencer/AudioLanePlayer.swift")
        XCTAssertTrue(player.contains("|| (pitched && mayRewire)"),
                      "prime asks for a pitch-only chain only when it starts playback")
        XCTAssertTrue(sink.contains("AudioTranspose.nodePitchCents("))
        let beats = try XCTUnwrap(sink.range(of: "stretch.mode == .beats"),
                                  "ANCHOR MISSING: the Beats shortcut")
        let open = try XCTUnwrap(sink.range(of: "{", range: beats.upperBound..<sink.endIndex))
        XCTAssertTrue(sink[beats.lowerBound..<open.lowerBound].contains("transposeSemitones == 0"),
                      "a transposed Beats part must not take the un-pitched buffer")
    }

    /// 9. `setLaneTranspose` is reached from outside the store only through the seam.
    func testTheStoreIsWrittenOnlyThroughTheSeam() throws {
        var callers: [String] = []
        let root = try repoRoot().appendingPathComponent("Sources")
        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        while let url = files?.nextObject() as? URL {
            guard url.pathExtension == "swift",
                  !url.path.hasSuffix("Core/TimelineStore.swift"),
                  let text = try? String(contentsOf: url, encoding: .utf8),
                  SourceText.codeOnly(text).contains("setLaneTranspose(") else { continue }
            callers.append(url.lastPathComponent)
        }
        XCTAssertEqual(callers, ["AudioTranspose.swift"],
                       "`setLaneTranspose` must be reached only through `AudioTranspose` — found \(callers)")
    }

    /// 10. The surface: one call to the seam, the one numeric control with a stated grid,
    /// unavailable while the song plays (the Warp switch's rule and reason).
    func testTheSurfaceUsesTheOneFieldAndIsDisabledWhilePlaying() throws {
        let view = try code("Sources/Echoelmusic/Studio/WorkstationView.swift")
        XCTAssertEqual(view.components(separatedBy: "AudioTranspose.setPitch(").count - 1, 1)
        let field = try XCTUnwrap(body(of: "private func pitchField(", in: view),
                                  "ANCHOR MISSING: pitchField")
        for needle in ["EchoelValueField(", "range: AudioTranspose.fieldRange", "decimals: 0",
                       ".disabled(playing)"] {
            XCTAssertTrue(field.contains(needle), "pitchField lost `\(needle)`")
        }
        XCTAssertFalse(field.contains("Slider("))
        XCTAssertFalse(field.contains("Stepper("))
    }

    // MARK: - Source helpers

    private func repoRoot() throws -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func code(_ relative: String) throws -> String {
        let url = try repoRoot().appendingPathComponent(relative)
        // #1240: only a missing TREE may skip; an unreadable file that exists is a red.
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("\(relative) is not present — this guard inspects source text (#454)")
        }
        let text = try String(contentsOf: url, encoding: .utf8)
        return SourceText.codeOnly(text)
    }

    /// The brace-matched body of the first declaration starting with `signature`.
    private func body(of signature: String, in text: String) -> String? {
        guard let start = text.range(of: signature),
              let open = text[start.upperBound...].firstIndex(of: "{") else { return nil }
        var depth = 0
        var index = open
        while index < text.endIndex {
            switch text[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return String(text[open...index]) }
            default: break
            }
            index = text.index(after: index)
        }
        return nil
    }
}
