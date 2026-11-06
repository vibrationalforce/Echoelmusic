import EchoelCore
import EchoelDSP
@testable import EchoelKernels
import XCTest
@testable import EchoelEngine

/// An insert that passes its input through and reports a latency the test sets.
private final class LateInsert: HostedProcessor, @unchecked Sendable {
    let sampleRate: Double
    let insert: InsertID? = nil
    let parameterRanges: [UInt64: ClosedRange<Float>] = [:]
    var latency: Int
    var isBypassed = false
    var latencyFrames: Int { latency }

    init(latency: Int, sampleRate: Double = 48_000) {
        self.latency = latency
        self.sampleRate = sampleRate
    }

    func schedule(address: UInt64, value: Float, offset: Int, ramp: Int) {}
    func process(frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>) {}
}

/// A plugin instrument that plays nothing and reports a latency.
private final class LateInstrument: HostedInstrument, @unchecked Sendable {
    let sampleRate: Double = 48_000
    let parameterRanges: [UInt64: ClosedRange<Float>] = [:]
    let latencyFrames: Int

    init(latency: Int) { latencyFrames = latency }

    func schedule(address: UInt64, value: Float, offset: Int, ramp: Int) {}
    func noteOn(pitch: UInt8, velocity: UInt8, offset: Int) {}
    func noteOff(pitch: UInt8, offset: Int) {}
    func control(status: UInt8, _ data1: UInt8, _ data2: UInt8, offset: Int) {}
    func allNotesOff(offset: Int) {}
    func render(frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>,
                gainLeft: Float, gainRight: Float) {}
}

/// One of Echoel's effect kernels on an insert chain, reporting its latency as its Audio Unit does.
private final class LatentKernelInsert: HostedProcessor, @unchecked Sendable {
    let kernel: EffectKernel
    let isBypassed = false
    let insert: InsertID? = nil
    let parameterRanges: [UInt64: ClosedRange<Float>] = [:]
    var sampleRate: Double { kernel.sampleRate }
    var latencyFrames: Int { PluginLatency.frames(seconds: kernel.latencySeconds, sampleRate: kernel.sampleRate) }

    init(_ kernel: EffectKernel) { self.kernel = kernel }

    func schedule(address: UInt64, value: Float, offset: Int, ramp: Int) {}

    func process(frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>) {
        kernel.process(left: left, right: right, frames: frames)
    }
}

/// Plugin delay compensation (WS-PDC): slice 1, the plan of how long each lane waits; slice 2, the
/// render waiting it.
final class DelayCompensationTests: XCTestCase {
    private let rate = 48_000.0

    // MARK: - The plan

    func testWithoutLatencyNothingWaits() {
        let a = TrackID(), b = TrackID(), verb = TrackID()
        let plan = DelayCompensation(tracks: [.init(track: a, latency: 0, buses: [0]), .init(track: b, latency: 0)],
                                     returns: [.init(track: verb, bus: 0, latency: 0)], master: 0)
        XCTAssertTrue(plan.isEmpty)
        XCTAssertEqual(plan.total, 0)
        XCTAssertEqual(plan.longestDelay, 0)
        XCTAssertEqual(plan.tracks.map(\.delay), [0, 0])
        XCTAssertEqual(plan.tracks.map(\.directDelay), [0, 0])
        XCTAssertEqual(plan.returns.map(\.delay), [0])
        XCTAssertEqual(DelayCompensation.none.total, 0)
    }

    func testOneLateTrackDelaysEveryOtherTrackByItsLatency() {
        let tuned = TrackID(), drums = TrackID(), bass = TrackID()
        let plan = DelayCompensation(tracks: [.init(track: drums, latency: 0), .init(track: tuned, latency: 912),
                                              .init(track: bass, latency: 0)], returns: [], master: 0)
        XCTAssertEqual(plan.delay(of: tuned)?.delay, 0, "the late track waits for nobody")
        XCTAssertEqual(plan.delay(of: drums)?.delay, 912)
        XCTAssertEqual(plan.delay(of: bass)?.delay, 912)
        XCTAssertEqual(plan.trackLatency, 912)
        XCTAssertEqual(plan.total, 912)
        XCTAssertEqual(plan.longestDelay, 912)
        // Each track's chain plus its wait is the same for all: they line up.
        XCTAssertEqual(Set(plan.tracks.map { $0.latency + $0.delay }), [912])
    }

    func testASendReachesItsReturnInTimeAndTheDryTrackWaitsForTheReturnChain() {
        let tuned = TrackID(), dry = TrackID(), verb = TrackID(), room = TrackID()
        let plan = DelayCompensation(tracks: [.init(track: tuned, latency: 912, buses: [0]),
                                              .init(track: dry, latency: 0, buses: [0, 1])],
                                     returns: [.init(track: verb, bus: 0, latency: 85), .init(track: room, bus: 1, latency: 0)],
                                     master: 0)
        // Stage 1: the sends tap after the wait, so both reach the returns at 912.
        XCTAssertEqual(plan.delay(of: dry)?.delay, 912)
        XCTAssertEqual(plan.delay(of: tuned)?.delay, 0)
        // Stage 2: the late return's chain (85) is waited for by the other return and by every
        // track's own output.
        XCTAssertEqual(plan.delay(ofReturn: 0)?.delay, 0)
        XCTAssertEqual(plan.delay(ofReturn: 1)?.delay, 85)
        XCTAssertEqual(plan.tracks.map(\.directDelay), [85, 85])
        XCTAssertEqual(plan.total, 997)
        // Every path to the master arrives at the same frame.
        for track in plan.tracks {
            XCTAssertEqual(track.latency + track.delay + track.directDelay, plan.total, "dry path")
        }
        for back in plan.returns {
            XCTAssertEqual(plan.trackLatency + back.latency + back.delay, plan.total, "return path")
        }
    }

    func testAReturnNothingFeedsDelaysNoTrack() {
        let a = TrackID(), verb = TrackID()
        let plan = DelayCompensation(tracks: [.init(track: a, latency: 0)],
                                     returns: [.init(track: verb, bus: 0, latency: 912)], master: 0)
        XCTAssertEqual(plan.returnLatency, 0)
        XCTAssertEqual(plan.delay(of: a)?.directDelay, 0)
        XCTAssertTrue(plan.isEmpty)
    }

    func testALaneOnItsOwnPairWaitsForTheMastersEffects() {
        let mixed = TrackID(), outboard = TrackID(), verb = TrackID()
        let plan = DelayCompensation(tracks: [.init(track: mixed, latency: 0, buses: [0]),
                                              .init(track: outboard, latency: 0, ownOutput: true)],
                                     returns: [.init(track: verb, bus: 0, latency: 0, ownOutput: true)], master: 85)
        XCTAssertEqual(plan.delay(of: mixed)?.directDelay, 0, "the master's effects delay it already")
        XCTAssertEqual(plan.delay(of: outboard)?.directDelay, 85)
        XCTAssertEqual(plan.delay(ofReturn: 0)?.delay, 85)
        XCTAssertEqual(plan.total, 85)
    }

    func testANegativeOrHugeLatencyIsBounded() {
        XCTAssertEqual(DelayCompensation.chain([-5, 10]), 10)
        XCTAssertEqual(DelayCompensation.chain([Int.max, Int.max]), 2 * DelayCompensation.maximumUnitLatency)
        let a = TrackID(), b = TrackID()
        let plan = DelayCompensation(tracks: [.init(track: a, latency: -40), .init(track: b, latency: 10)], returns: [], master: -3)
        XCTAssertEqual(plan.delay(of: a)?.delay, 10)
        XCTAssertEqual(plan.masterLatency, 0)
    }

    func testAUnitsLatencyInFramesIsRoundedAndBounded() {
        XCTAssertEqual(PluginLatency.frames(seconds: 0.019, sampleRate: 48_000), 912)
        XCTAssertEqual(PluginLatency.frames(seconds: 85.0 / 48_000, sampleRate: 48_000), 85)
        XCTAssertEqual(PluginLatency.frames(seconds: .nan, sampleRate: 48_000), 0)
        XCTAssertEqual(PluginLatency.frames(seconds: -1, sampleRate: 48_000), 0)
        XCTAssertEqual(PluginLatency.frames(seconds: 0.01, sampleRate: .infinity), 0)
        XCTAssertEqual(PluginLatency.frames(seconds: 30, sampleRate: 48_000), 48_000, "one second at the most")
    }

    // MARK: - The snapshot

    private func snapshot(_ project: Project, effects: [TrackID: [any HostedProcessor]],
                          masterEffects: [any HostedProcessor] = [], units: [TrackID: any HostedInstrument] = [:],
                          slots: [TrackID: Int] = [:], outputChannels: Int = 2) -> EngineSnapshot {
        EngineSnapshot(plan: PlaybackPlan(compiling: project), project: project, slots: slots, sampleRate: rate,
                       generation: 1, units: units, effects: effects, outputChannels: outputChannels,
                       masterEffects: masterEffects)
    }

    func testTheSnapshotReadsEachInsertsLatencyAndALatencyThatChangesRebuildsThePlan() throws {
        var project = Project(tempo: 120)
        let tuned = TrackID(), drums = TrackID()
        try Command.addTrack(id: tuned, name: "Vocal", kind: .audio, index: nil).apply(to: &project)
        try Command.addTrack(id: drums, name: "Drums", kind: .audio, index: nil).apply(to: &project)
        let pitch = LateInsert(latency: 912)
        let first = snapshot(project, effects: [tuned: [pitch, LateInsert(latency: 0)]])
        XCTAssertEqual(first.compensation.delay(of: drums)?.delay, 912)
        XCTAssertEqual(first.compensation.delay(of: tuned)?.delay, 0)

        pitch.latency = 85
        let second = snapshot(project, effects: [tuned: [pitch]])
        XCTAssertEqual(second.compensation.delay(of: drums)?.delay, 85, "the next snapshot asks the unit again")
        XCTAssertNotEqual(first.compensation, second.compensation)

        pitch.isBypassed = true
        let third = snapshot(project, effects: [tuned: [pitch]])
        XCTAssertTrue(third.compensation.isEmpty, "a bypassed insert is skipped, and so is its latency")

        let otherRate = snapshot(project, effects: [tuned: [LateInsert(latency: 912, sampleRate: 44_100)]])
        XCTAssertTrue(otherRate.compensation.isEmpty, "an insert left out of the chain brings no latency")
    }

    func testTheSnapshotCompensatesSendsReturnsAndTheMaster() throws {
        var project = Project(tempo: 120)
        let tuned = TrackID(), dry = TrackID(), verb = TrackID(), outboard = TrackID()
        try Command.addTrack(id: tuned, name: "Vocal", kind: .audio, index: nil).apply(to: &project)
        try Command.addTrack(id: dry, name: "Guitar", kind: .audio, index: nil).apply(to: &project)
        try Command.addTrack(id: outboard, name: "Click", kind: .audio, index: nil).apply(to: &project)
        try Command.addTrack(id: verb, name: "Reverb", kind: .returnTrack, index: nil).apply(to: &project)
        try Command.setSend(track: dry, to: verb, db: 0).apply(to: &project)
        try Command.setOutput(outboard, channel: 2).apply(to: &project)
        let shot = snapshot(project, effects: [tuned: [LateInsert(latency: 912)], verb: [LateInsert(latency: 85)]],
                            masterEffects: [LateInsert(latency: 64)], outputChannels: 4)
        let plan = shot.compensation
        XCTAssertEqual(plan.delay(of: dry)?.delay, 912, "its send reaches the return in time with the vocal")
        XCTAssertEqual(plan.delay(of: dry)?.directDelay, 85, "its dry sound waits for the reverb's chain")
        XCTAssertEqual(plan.delay(of: tuned)?.directDelay, 85)
        XCTAssertEqual(plan.delay(of: outboard)?.directDelay, 85 + 64, "its own pair waits for the master's effects")
        XCTAssertEqual(plan.delay(ofReturn: 0)?.delay, 0)
        XCTAssertEqual(plan.total, 912 + 85 + 64)
    }

    func testAMuteASoloOrASendAtSilenceNeverMovesTheOtherTracksInTime() throws {
        var project = Project(tempo: 120)
        let vox = TrackID(), gtr = TrackID(), verb = TrackID()
        try Command.addTrack(id: vox, name: "Vocal", kind: .audio, index: nil).apply(to: &project)
        try Command.addTrack(id: gtr, name: "Guitar", kind: .audio, index: nil).apply(to: &project)
        try Command.addTrack(id: verb, name: "Reverb", kind: .returnTrack, index: nil).apply(to: &project)
        try Command.setSend(track: vox, to: verb, db: 0).apply(to: &project)
        let effects: [TrackID: [any HostedProcessor]] = [verb: [LateInsert(latency: 85)]]
        XCTAssertEqual(snapshot(project, effects: effects).compensation.delay(of: gtr)?.directDelay, 85)

        var muted = project
        try Command.setMute(vox, true).apply(to: &muted)
        let mutedPlan = snapshot(muted, effects: effects).compensation
        XCTAssertEqual(mutedPlan.delay(of: gtr)?.directDelay, 85, "muting the only sender keeps the guitar where it was")
        XCTAssertEqual(mutedPlan.total, 85)

        var soloed = project
        try Command.setSolo(gtr, true).apply(to: &soloed)
        XCTAssertEqual(snapshot(soloed, effects: effects).compensation.delay(of: gtr)?.directDelay, 85,
                       "soloing another track keeps it where it was")

        var silent = project
        try Command.setSend(track: vox, to: verb, db: MixerStrip.volumeRange.lowerBound).apply(to: &silent)
        XCTAssertEqual(snapshot(silent, effects: effects).compensation.delay(of: gtr)?.directDelay, 85,
                       "a send pulled to silence keeps it where it was")

        var removed = project
        try Command.setSend(track: vox, to: verb, db: nil).apply(to: &removed)
        XCTAssertEqual(snapshot(removed, effects: effects).compensation.delay(of: gtr)?.directDelay, 0,
                       "without any send the return is fed by nothing and delays no one")
    }

    func testAPluginInstrumentsLatencyCountsInItsTracksChain() throws {
        var project = Project(tempo: 120)
        let keys = TrackID(), drums = TrackID()
        let plugin = PluginComponent(type: PluginComponent.code("aumu"), subtype: PluginComponent.code("Late"),
                                     manufacturer: PluginComponent.code("Test"), name: "Late", manufacturerName: "Test")
        try Command.addTrack(id: keys, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        try Command.setInstrumentPlugin(keys, plugin).apply(to: &project)
        try Command.addTrack(id: drums, name: "Drums", kind: .audio, index: nil).apply(to: &project)
        var slots = SlotAssigner(capacity: 8)
        slots.update(for: project)
        let shot = snapshot(project, effects: [keys: [LateInsert(latency: 36)]], units: [keys: LateInstrument(latency: 64)],
                            slots: slots.slots)
        XCTAssertEqual(shot.compensation.delay(of: keys)?.latency, 100)
        XCTAssertEqual(shot.compensation.delay(of: drums)?.delay, 100)
    }

    // MARK: - The render

    /// One beat at 120 BPM, in frames: where each test region starts.
    private let beat = 24_000
    /// The multiband clipper's latency at 48 kHz.
    private let clipperLatency = 85
    /// A tone half a period off at the clipper's latency: 85 frames are one and a half periods, so
    /// a track left 85 frames ahead of its twin cancels it instead of doubling it.
    private var tone: Double { rate * 1.5 / 85 }

    private struct Tones {
        var project: Project
        var tracks: [TrackID]
        var media: MediaFile
        var buffer: SampleBuffer
        var samples: [MediaID: SampleBuffer] { [media.id: buffer] }
    }

    /// One audio track per name, each playing the same second of `tone` from the song's second beat.
    private func tones(_ names: [String]) throws -> Tones {
        var project = Project(tempo: 120)
        let media = MediaFile(name: "Tone", path: "Media/tone.wav", frameCount: 48_000, sampleRate: rate)
        try Command.addMedia(media).apply(to: &project)
        var tracks: [TrackID] = []
        for name in names {
            let track = TrackID()
            try Command.addTrack(id: track, name: name, kind: .audio, index: nil).apply(to: &project)
            try Command.placeAudio(track: track, id: RegionID(), media: media.id, start: MusicalTime.ticksPerQuarter)
                .apply(to: &project)
            tracks.append(track)
        }
        let hertz = tone, sampleRate = rate
        let wave = (0..<48_000).map { (index: Int) -> Float in
            let phase = 2 * Double.pi * hertz * Double(index) / sampleRate
            return Float(0.25 * sin(phase))
        }
        let buffer = try XCTUnwrap(SampleBuffer(samples: wave, sampleRate: rate))
        return Tones(project: project, tracks: tracks, media: media, buffer: buffer)
    }

    /// The multiband clipper at Mix 0: only its dry sound, which it keeps aligned with what it
    /// clips — 85 frames late, through its crossovers' allpass (low 40 Hz, high 10 kHz).
    private func clipper() -> LatentKernelInsert {
        let kernel = EffectKernel(effect: .multibandClipper, sampleRate: rate)
        kernel.setParameter(1, 40)        // low crossover, Hz
        kernel.setParameter(2, 10_000)    // high crossover, Hz
        kernel.setParameter(8, 0)         // mix
        return LatentKernelInsert(kernel)
    }

    private func export(_ song: Tones, effects: [TrackID: [any HostedProcessor]], isolating: TrackID? = nil) -> [Float] {
        OfflineRender.render(song.project, sampleRate: rate, tailSeconds: 0.5, ringOutSeconds: 0, samples: song.samples,
                             effects: effects, isolating: isolating).left
    }

    private func correlation(_ a: ArraySlice<Float>, _ b: ArraySlice<Float>) -> Double {
        var ab = 0.0, aa = 0.0, bb = 0.0
        for (x, y) in zip(a, b) {
            ab += Double(x) * Double(y)
            aa += Double(x) * Double(x)
            bb += Double(y) * Double(y)
        }
        guard aa > 0, bb > 0 else { return 0 }
        return ab / (aa * bb).squareRoot()
    }

    private func peak(_ samples: ArraySlice<Float>) -> Float {
        samples.reduce(Float(0)) { (loudest: Float, sample: Float) -> Float in Swift.max(loudest, Swift.abs(sample)) }
    }

    /// How many frames of `delayed` differ from `original` played `latency` frames earlier — the
    /// first `latency` frames count unless they are silence.
    private func mismatches(_ delayed: [Float], _ original: [Float], latency: Int) -> Int {
        var count = 0
        for index in 0..<Swift.min(latency, delayed.count) where delayed[index] != 0 { count += 1 }
        for index in latency..<Swift.min(delayed.count, original.count + latency) where delayed[index] != original[index - latency] {
            count += 1
        }
        return count
    }

    func testTwoIdenticalTracksStayInPhaseBehindAMultibandClipper() throws {
        let song = try tones(["Clipped", "Plain"])
        let clipped = song.tracks[0], plain = song.tracks[1]
        XCTAssertEqual(clipper().latencyFrames, clipperLatency)
        let effects = { () -> [TrackID: [any HostedProcessor]] in [clipped: [self.clipper()]] }
        let clippedAlone = export(song, effects: effects(), isolating: clipped)
        let plainAlone = export(song, effects: effects(), isolating: plain)
        let both = export(song, effects: effects())
        // No latency anywhere: the plain track as it played before compensation.
        let uncompensated = export(song, effects: [:], isolating: plain)
        XCTAssertEqual(plainAlone.count, uncompensated.count)
        XCTAssertEqual(mismatches(plainAlone, uncompensated, latency: clipperLatency), 0,
                       "the plain track plays exactly as before, 85 frames later")

        let window = (beat + 4_800)..<(beat + 40_000)
        XCTAssertGreaterThan(correlation(clippedAlone[window], plainAlone[window]), 0.98, "compensated: in phase")
        XCTAssertLessThan(correlation(clippedAlone[window], uncompensated[window]), -0.9,
                          "without compensation the two would cancel")
        XCTAssertGreaterThan(peak(both[window]), 1.95 * peak(plainAlone[window]), "the sum doubles")
    }

    func testATracksDrySoundWaitsForTheClipperOnItsReturnAndItsSendArrivesInTime() throws {
        var song = try tones(["Voice"])
        let voice = song.tracks[0], verb = TrackID()
        try Command.addTrack(id: verb, name: "Return", kind: .returnTrack, index: nil).apply(to: &song.project)
        try Command.setSend(track: voice, to: verb, db: 0).apply(to: &song.project)
        let effects = { () -> [TrackID: [any HostedProcessor]] in [verb: [self.clipper()]] }
        let dry = export(song, effects: effects(), isolating: voice)
        let wet = export(song, effects: effects(), isolating: verb)
        let before = export(song, effects: [:], isolating: voice)
        XCTAssertEqual(mismatches(dry, before, latency: clipperLatency), 0, "the dry sound waits the return's chain")
        let window = (beat + 4_800)..<(beat + 40_000)
        XCTAssertGreaterThan(correlation(dry[window], wet[window]), 0.98, "dry and return meet in phase")
        XCTAssertLessThan(correlation(before[window], wet[window]), -0.9)
    }

    func testWithoutLatencyTheMixIsTheSameSampleForSample() throws {
        var song = try tones(["A", "B"])
        let verb = TrackID()
        try Command.addTrack(id: verb, name: "Return", kind: .returnTrack, index: nil).apply(to: &song.project)
        try Command.setSend(track: song.tracks[0], to: verb, db: -6).apply(to: &song.project)
        let bare = OfflineRender.render(song.project, sampleRate: rate, tailSeconds: 0.5, ringOutSeconds: 0, samples: song.samples)
        let effects: [TrackID: [any HostedProcessor]] = [song.tracks[0]: [LateInsert(latency: 0)], verb: [LateInsert(latency: 0)]]
        let passed = OfflineRender.render(song.project, sampleRate: rate, tailSeconds: 0.5, ringOutSeconds: 0,
                                          samples: song.samples, effects: effects)
        XCTAssertEqual(bare.left, passed.left)
        XCTAssertEqual(bare.right, passed.right)
        XCTAssertTrue(CompensationLines(snapshot(song.project, effects: effects), reusing: nil).entries.isEmpty,
                      "no line at all")
    }

    /// The export renders in blocks of 4,096; the device in whatever it asks for. Every delay line
    /// runs sample by sample, so each plays the same.
    func testALiveRenderInAnyBlockSizePlaysWhatTheExportPlays() throws {
        let song = try tones(["Clipped", "Plain"])
        let exported = export(song, effects: [song.tracks[0]: [clipper()]])
        for block in [256, 333, 4_096] {
            let engine = EngineCore(sampleRate: rate)
            engine.setClickEnabled(false)
            var slots = SlotAssigner(capacity: engine.slotCapacity)
            slots.update(for: song.project)
            engine.publish(EngineSnapshot(plan: PlaybackPlan(compiling: song.project), project: song.project, slots: slots.slots,
                                          sampleRate: rate, generation: 1, samples: song.samples,
                                          effects: [song.tracks[0]: [clipper()]]))
            engine.play()
            var left = [Float](repeating: 0, count: exported.count)
            var right = [Float](repeating: 0, count: exported.count)
            var start = 0
            while start < exported.count {
                let count = Swift.min(block, exported.count - start)
                left.withUnsafeMutableBufferPointer { (l: inout UnsafeMutableBufferPointer<Float>) in
                    right.withUnsafeMutableBufferPointer { (r: inout UnsafeMutableBufferPointer<Float>) in
                        guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                        engine.render(frameCount: count, left: lp + start, right: rp + start)
                    }
                }
                start += count
            }
            var worst: Float = 0
            for (live, file) in zip(left, exported) { worst = Swift.max(worst, Swift.abs(live - file)) }
            XCTAssertLessThan(worst, 1e-6, "block \(block)")
        }
    }

    func testALineIsHandedOnWhileItsDelayStaysAndMadeAnewWhenItChanges() throws {
        var song = try tones(["Clipped", "Plain"])
        let clipped = song.tracks[0], plain = song.tracks[1]
        let late = LateInsert(latency: 85)
        let first = snapshot(song.project, effects: [clipped: [late]])
        let lines = CompensationLines(first, reusing: nil)
        let at = try XCTUnwrap(first.audioLanes.firstIndex { $0.track == plain })
        let own = try XCTUnwrap(first.audioLanes.firstIndex { $0.track == clipped })
        XCTAssertEqual(lines.audioPre[at]?.delay, 85)
        XCTAssertNil(lines.audioPre[own], "the late track waits for nobody")
        XCTAssertNil(lines.audioDirect[at], "no return, no wait after the sends")

        try Command.setVolume(.track(plain), db: -6).apply(to: &song.project)
        let louder = CompensationLines(snapshot(song.project, effects: [clipped: [late]]), reusing: lines)
        XCTAssertTrue(louder.audioPre[at] === lines.audioPre[at], "a fader move keeps the line and what it holds")

        late.latency = 40
        let shorter = CompensationLines(snapshot(song.project, effects: [clipped: [late]]), reusing: louder)
        XCTAssertEqual(shorter.audioPre[at]?.delay, 40)
        XCTAssertFalse(shorter.audioPre[at] === louder.audioPre[at])
    }

    private func run(_ line: DelayLine, _ input: [Float], block: Int) -> [Float] {
        var left = input
        var right = input.map { (sample: Float) -> Float in -sample }
        var start = 0
        while start < input.count {
            let count = Swift.min(block, input.count - start)
            left.withUnsafeMutableBufferPointer { (l: inout UnsafeMutableBufferPointer<Float>) in
                right.withUnsafeMutableBufferPointer { (r: inout UnsafeMutableBufferPointer<Float>) in
                    guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                    line.process(left: lp + start, right: rp + start, frames: count)
                }
            }
            start += count
        }
        XCTAssertEqual(right, left.map { (sample: Float) -> Float in -sample }, "both sides alike")
        return left
    }

    func testADelayLineDelaysByItsFramesAtAnyBlockSize() {
        let input = (0..<1_000).map { (index: Int) -> Float in Float(index + 1) }
        for block in [1, 7, 64, 1_000] {
            let out = run(DelayLine(delay: 85), input, block: block)
            XCTAssertTrue(out.prefix(85).allSatisfy { (sample: Float) -> Bool in sample == 0 }, "block \(block)")
            XCTAssertEqual(Array(out.dropFirst(85)), Array(input.prefix(1_000 - 85)), "block \(block)")
        }
    }

    func testANewDelayPlaysOnFromWhatTheOldLineHeld() {
        let input = (0..<1_000).map { (index: Int) -> Float in Float(index + 1) }
        let old = DelayLine(delay: 85)
        _ = run(old, input, block: 333)
        XCTAssertFalse(old.isDrained)

        let shorter = DelayLine(delay: 40)
        shorter.takeOver(old)
        let expectedShorter: [Float] = (961...1_000).map { (value: Int) -> Float in Float(value) }
        XCTAssertEqual(run(shorter, [Float](repeating: 0, count: 40), block: 16), expectedShorter, "its newest 40 frames")
        XCTAssertTrue(shorter.isDrained, "40 silent frames later it holds silence")

        let longer = DelayLine(delay: 100)
        longer.takeOver(old)
        let expectedLonger: [Float] = [Float](repeating: 0, count: 15) + (916...1_000).map { (value: Int) -> Float in Float(value) }
        XCTAssertEqual(run(longer, [Float](repeating: 0, count: 100), block: 100), expectedLonger,
                       "all 85 it held, after silence for the 15 frames it never had")

        let cleared = DelayLine(delay: 85)
        cleared.takeOver(old)
        cleared.clear()
        XCTAssertTrue(cleared.isDrained)
        XCTAssertEqual(run(cleared, [Float](repeating: 0, count: 85), block: 85), [Float](repeating: 0, count: 85))
    }
}
