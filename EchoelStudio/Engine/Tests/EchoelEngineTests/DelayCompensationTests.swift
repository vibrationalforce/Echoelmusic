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

/// An insert that passes its input through, reports a latency, and counts the frames it ran.
private final class CountedInsert: HostedProcessor, @unchecked Sendable {
    let sampleRate: Double = 48_000
    let insert: InsertID? = nil
    let parameterRanges: [UInt64: ClosedRange<Float>] = [:]
    let isBypassed = false
    let latencyFrames: Int
    private(set) var processed = 0

    init(latency: Int) { latencyFrames = latency }

    func schedule(address: UInt64, value: Float, offset: Int, ramp: Int) {}
    func process(frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>) { processed += frames }
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
        XCTAssertEqual(mismatches(plainAlone, uncompensated, latency: 0), 0,
                       "the plain track plays exactly as before: the export drops the 85 frames it waits")

        let window = (beat + 4_800)..<(beat + 40_000)
        // Without compensation the plain track would play 85 frames ahead of the clipped one.
        let ahead = (window.lowerBound + clipperLatency)..<(window.upperBound + clipperLatency)
        XCTAssertGreaterThan(correlation(clippedAlone[window], plainAlone[window]), 0.98, "compensated: in phase")
        XCTAssertLessThan(correlation(clippedAlone[window], uncompensated[ahead]), -0.9,
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
        XCTAssertEqual(mismatches(dry, before, latency: 0), 0,
                       "the dry sound waits the return's chain, and the export drops that wait")
        let window = (beat + 4_800)..<(beat + 40_000)
        let ahead = (window.lowerBound + clipperLatency)..<(window.upperBound + clipperLatency)
        XCTAssertGreaterThan(correlation(dry[window], wet[window]), 0.98, "dry and return meet in phase")
        XCTAssertLessThan(correlation(before[ahead], wet[window]), -0.9, "a dry sound that did not wait would cancel")
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
    /// runs sample by sample, so each plays the same — the device `total` frames later, which the
    /// export drops so its file starts on the song's first sample.
    func testALiveRenderInAnyBlockSizePlaysWhatTheExportPlays() throws {
        let song = try tones(["Clipped", "Plain"])
        let exported = export(song, effects: [song.tracks[0]: [clipper()]])
        let total = clipperLatency
        for block in [256, 333, 4_096] {
            let engine = EngineCore(sampleRate: rate)
            engine.setClickEnabled(false)
            var slots = SlotAssigner(capacity: engine.slotCapacity)
            slots.update(for: song.project)
            engine.publish(EngineSnapshot(plan: PlaybackPlan(compiling: song.project), project: song.project, slots: slots.slots,
                                          sampleRate: rate, generation: 1, samples: song.samples,
                                          effects: [song.tracks[0]: [clipper()]]))
            engine.play()
            var left = [Float](repeating: 0, count: exported.count + total)
            var right = [Float](repeating: 0, count: exported.count + total)
            var start = 0
            while start < left.count {
                let count = Swift.min(block, left.count - start)
                left.withUnsafeMutableBufferPointer { (l: inout UnsafeMutableBufferPointer<Float>) in
                    right.withUnsafeMutableBufferPointer { (r: inout UnsafeMutableBufferPointer<Float>) in
                        guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                        engine.render(frameCount: count, left: lp + start, right: rp + start)
                    }
                }
                start += count
            }
            var worst: Float = 0
            for (live, file) in zip(left[total...], exported) { worst = Swift.max(worst, Swift.abs(live - file)) }
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

        let capped = DelayLine(delay: 100)
        XCTAssertEqual(capped.takeOver(old, upTo: 10), 10, "no more than it may copy")
        let expectedCapped: [Float] = [Float](repeating: 0, count: 90) + (991...1_000).map { (value: Int) -> Float in Float(value) }
        XCTAssertEqual(run(capped, [Float](repeating: 0, count: 100), block: 100), expectedCapped,
                       "the newest 10 frames, silence before them")
    }

    /// The swap pairs each new line with the old one on the main thread, and copies within one
    /// budget on the render thread, whatever the latencies.
    func testASnapshotsNewLinesTakeOverOnlyFromTheLinesTheyWereMadeAgainst() throws {
        let song = try tones(["Clipped", "Plain"])
        let clipped = song.tracks[0], plain = song.tracks[1]
        let late = LateInsert(latency: 85)
        let first = snapshot(song.project, effects: [clipped: [late]])
        let lines = CompensationLines(first, reusing: nil)
        let at = try XCTUnwrap(first.audioLanes.firstIndex { $0.track == plain })
        let held = try XCTUnwrap(lines.audioPre[at])
        _ = run(held, (0..<1_000).map { (index: Int) -> Float in Float(index + 1) }, block: 256)

        late.latency = 40
        let next = snapshot(song.project, effects: [clipped: [late]])
        let shorter = CompensationLines(next, reusing: lines)
        shorter.takeOver(from: lines)
        let line = try XCTUnwrap(shorter.audioPre[at])
        XCTAssertEqual(run(line, [Float](repeating: 0, count: 40), block: 40), (961...1_000).map { (value: Int) -> Float in Float(value) },
                       "the new line plays on from the old one")

        let elsewhere = CompensationLines(next, reusing: lines)
        elsewhere.takeOver(from: CompensationLines(first, reusing: nil))
        let unpaired = try XCTUnwrap(elsewhere.audioPre[at])
        XCTAssertTrue(unpaired.isDrained, "made against other lines: it starts silent")
    }

    /// A muted track that waits in a delay line keeps its line playing, so when it is unmuted its
    /// fader rises over that sound: no step from silence to the tone at full level.
    func testUnmutingATrackThatWaitsInALineFadesInWithoutAClick() throws {
        var song = try tones(["Clipped", "Plain"])
        let clipped = song.tracks[0], plain = song.tracks[1]
        try Command.setMute(clipped, true).apply(to: &song.project)
        var muted = song.project
        try Command.setMute(plain, true).apply(to: &muted)
        let unmuteAt = beat + 4_800, length = beat + 9_600
        let samples = song.samples, sampleRate = rate, unmuted = song.project
        for block in [64, 128] {
            let engine = EngineCore(sampleRate: rate)
            engine.setClickEnabled(false)
            var slots = SlotAssigner(capacity: engine.slotCapacity)
            slots.update(for: song.project)
            let assigned = slots.slots
            let publish = { (project: Project, generation: UInt64) in
                engine.publish(EngineSnapshot(plan: PlaybackPlan(compiling: project), project: project, slots: assigned,
                                              sampleRate: sampleRate, generation: generation, samples: samples,
                                              effects: [clipped: [LateInsert(latency: 85)]]))
            }
            publish(muted, 1)
            engine.play()
            var left = [Float](repeating: 0, count: length)
            var right = [Float](repeating: 0, count: length)
            var start = 0
            while start < length {
                if start == unmuteAt { publish(unmuted, 2) }
                let count = Swift.min(block, length - start)
                left.withUnsafeMutableBufferPointer { (l: inout UnsafeMutableBufferPointer<Float>) in
                    right.withUnsafeMutableBufferPointer { (r: inout UnsafeMutableBufferPointer<Float>) in
                        guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                        engine.render(frameCount: count, left: lp + start, right: rp + start)
                    }
                }
                start += count
            }
            XCTAssertTrue(left[..<unmuteAt].allSatisfy { (sample: Float) -> Bool in sample == 0 }, "block \(block): muted")
            let largestStep = { (range: Range<Int>) -> Float in
                var worst: Float = 0
                for index in range { worst = Swift.max(worst, Swift.abs(left[index] - left[index - 1])) }
                return worst
            }
            let steady = largestStep((length - 2_048)..<length)
            XCTAssertGreaterThan(steady, 0.01, "block \(block): the tone plays after the unmute")
            XCTAssertLessThan(largestStep(unmuteAt..<(length - 2_048)), 1.3 * steady,
                              "block \(block): the unmute fades in, it does not step")
        }
    }

    // MARK: - Changes while the song plays

    /// One edit published while the live core plays: before the block that starts at `at`.
    private struct Publish {
        var at: Int
        var project: Project
        var effects: [TrackID: [any HostedProcessor]]
        var master: [any HostedProcessor] = []
        var prepare: () -> Void = {}
    }

    /// The live core playing `song` from frame `playAt` in blocks of `block`: each publish is made
    /// before the block that starts at its frame (every `at` lies on a block boundary), so two at
    /// one frame both reach the core before it renders again.
    private func playLive(_ song: Tones, _ publishes: [Publish], length: Int, block: Int, playAt: Int = 0,
                          seekTo: Int? = nil) -> [Float] {
        let engine = EngineCore(sampleRate: rate)
        engine.setClickEnabled(false)
        var slots = SlotAssigner(capacity: engine.slotCapacity)
        slots.update(for: song.project)
        let assigned = slots.slots
        var left = [Float](repeating: 0, count: length)
        var right = [Float](repeating: 0, count: length)
        var generation: UInt64 = 0
        var next = 0
        var start = 0
        while start < length {
            while next < publishes.count, publishes[next].at <= start {
                let due = publishes[next]
                XCTAssertEqual(due.at % block, 0, "a publish lands on a block boundary")
                due.prepare()
                generation += 1
                engine.publish(EngineSnapshot(plan: PlaybackPlan(compiling: due.project), project: due.project,
                                              slots: assigned, sampleRate: rate, generation: generation,
                                              samples: song.samples, effects: due.effects, masterEffects: due.master))
                next += 1
            }
            if start == playAt {
                if let seekTo { engine.seek(toSample: Int64(seekTo)) }
                engine.play()
            }
            let count = Swift.min(block, length - start)
            left.withUnsafeMutableBufferPointer { (l: inout UnsafeMutableBufferPointer<Float>) in
                right.withUnsafeMutableBufferPointer { (r: inout UnsafeMutableBufferPointer<Float>) in
                    guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                    engine.render(frameCount: count, left: lp + start, right: rp + start)
                }
            }
            start += count
        }
        return left
    }

    /// Two edits published before the render thread takes either: the second is made against the
    /// lines the render thread plays, not against the first, which it skips — so the track that
    /// waits plays on through the change instead of falling silent for its whole new wait.
    func testTwoSnapshotsPublishedBeforeOneRenderNeverSilenceATrackThatWaits() throws {
        var song = try tones(["Late", "Plain"])
        let lateTrack = song.tracks[0], plain = song.tracks[1]
        try Command.setMute(lateTrack, true).apply(to: &song.project)
        var quieter = song.project
        try Command.setVolume(.track(plain), db: -1).apply(to: &quieter)
        let change = beat + 4_800, length = beat + 9_600
        for block in [64, 128] {
            let late = LateInsert(latency: 85)
            let effects: [TrackID: [any HostedProcessor]] = [lateTrack: [late]]
            let live = playLive(song, [
                Publish(at: 0, project: song.project, effects: effects),
                Publish(at: change, project: song.project, effects: effects, prepare: { late.latency = 40 }),
                Publish(at: change, project: quieter, effects: effects),
            ], length: length, block: block)
            var silentRun = 0
            var longest = 0
            for sample in live[change..<(change + 2_048)] {
                silentRun = Swift.abs(sample) < 1e-7 ? silentRun + 1 : 0
                longest = Swift.max(longest, silentRun)
            }
            XCTAssertGreaterThan(peak(live[(length - 2_048)..<length]), 0.1, "block \(block): the tone plays")
            XCTAssertLessThan(longest, 16, "block \(block): the track that waits plays on through both edits")
        }
    }

    /// The left side of an export of `project` with these inserts.
    private func exportOf(_ project: Project, _ song: Tones, effects: [TrackID: [any HostedProcessor]]) -> [Float] {
        OfflineRender.render(project, sampleRate: rate, tailSeconds: 0.5, ringOutSeconds: 0, samples: song.samples,
                             effects: effects).left
    }

    /// The steepest step between two neighbouring samples in `range`.
    private func steepestStep(_ samples: [Float], _ range: Range<Int>) -> Float {
        var worst: Float = 0
        for index in range where index > 0 && index < samples.count {
            worst = Swift.max(worst, Swift.abs(samples[index] - samples[index - 1]))
        }
        return worst
    }

    /// The largest difference between `live` over `from..<end` and `file` played `shift` frames
    /// earlier.
    private func worstDifference(_ live: [Float], from: Int, to end: Int, _ file: [Float], shift: Int) -> Float {
        var worst: Float = 0
        for index in from..<Swift.min(end, live.count) {
            let at = index - shift
            guard at >= 0, at < file.count else { continue }
            worst = Swift.max(worst, Swift.abs(live[index] - file[at]))
        }
        return worst
    }

    /// A latency that arrives while the song plays: the track that now waits holds what it played,
    /// then glides to its new wait — no silence, no step — and plays on as the export plays it.
    func testAnInsertWithLatencyAddedWhilePlayingNeverStepsTheTrackThatNowWaits() throws {
        var song = try tones(["Late", "Plain"])
        let lateTrack = song.tracks[0]
        try Command.setMute(lateTrack, true).apply(to: &song.project)
        let change = beat + 4_800, length = beat + 9_600
        let file = exportOf(song.project, song, effects: [lateTrack: [LateInsert(latency: 85)]])
        var renders: [[Float]] = []
        for block in [64, 128] {
            let live = playLive(song, [
                Publish(at: 0, project: song.project, effects: [:]),
                Publish(at: change, project: song.project, effects: [lateTrack: [LateInsert(latency: 85)]]),
            ], length: length, block: block)
            let steady = Swift.max(steepestStep(live, (change - 2_048)..<change), steepestStep(live, (length - 2_048)..<length))
            XCTAssertGreaterThan(steady, 0.01, "block \(block): the tone plays")
            XCTAssertLessThan(steepestStep(live, change..<(length - 2_048)), 1.3 * steady, "block \(block): no step")
            XCTAssertLessThan(worstDifference(live, from: change + 2_048, to: length, file, shift: 85), 1e-6,
                              "block \(block): then it waits 85 frames, as the export plays it")
            renders.append(live)
        }
        XCTAssertLessThan(worstDifference(renders[0], from: 0, to: length, renders[1], shift: 0), 1e-6, "any block size")
    }

    /// A latency that leaves while the song plays: the track that waited glides back to no wait.
    func testAnInsertWithLatencyRemovedWhilePlayingNeverStepsTheTrackThatWaited() throws {
        var song = try tones(["Late", "Plain"])
        let lateTrack = song.tracks[0]
        try Command.setMute(lateTrack, true).apply(to: &song.project)
        let change = beat + 4_800, length = beat + 9_600
        let file = exportOf(song.project, song, effects: [:])
        var renders: [[Float]] = []
        for block in [64, 128] {
            let live = playLive(song, [
                Publish(at: 0, project: song.project, effects: [lateTrack: [LateInsert(latency: 85)]]),
                Publish(at: change, project: song.project, effects: [:]),
            ], length: length, block: block)
            let steady = Swift.max(steepestStep(live, (change - 2_048)..<change), steepestStep(live, (length - 2_048)..<length))
            XCTAssertGreaterThan(steady, 0.01, "block \(block): the tone plays")
            XCTAssertLessThan(steepestStep(live, change..<(length - 2_048)), 1.3 * steady, "block \(block): no step")
            XCTAssertLessThan(worstDifference(live, from: change + 2_048, to: length, file, shift: 0), 1e-6,
                              "block \(block): then it waits for nothing")
            renders.append(live)
        }
        XCTAssertLessThan(worstDifference(renders[0], from: 0, to: length, renders[1], shift: 0), 1e-6, "any block size")
    }

    /// A latency that changes while the song plays — shorter, longer, and shorter with a fader
    /// moved in the same block — glides the track that waits from one wait to the other.
    func testALatencyThatChangesWhilePlayingGlidesTheTrackThatWaits() throws {
        var song = try tones(["Late", "Plain"])
        let lateTrack = song.tracks[0], plain = song.tracks[1]
        try Command.setMute(lateTrack, true).apply(to: &song.project)
        var quieter = song.project
        try Command.setVolume(.track(plain), db: -1).apply(to: &quieter)
        let change = beat + 4_800, length = beat + 9_600
        let cases: [(from: Int, to: Int, fader: Bool)] = [(85, 40, false), (40, 85, false), (85, 40, true)]
        for (from, to, fader) in cases {
            let late = LateInsert(latency: from)
            let effects: [TrackID: [any HostedProcessor]] = [lateTrack: [late]]
            var publishes = [Publish(at: 0, project: song.project, effects: effects),
                             Publish(at: change, project: song.project, effects: effects, prepare: { late.latency = to })]
            if fader { publishes.append(Publish(at: change, project: quieter, effects: effects)) }
            let live = playLive(song, publishes, length: length, block: 64)
            let file = exportOf(fader ? quieter : song.project, song, effects: [lateTrack: [LateInsert(latency: to)]])
            let label = fader ? "\(from) to \(to) with a fader move" : "\(from) to \(to)"
            let steady = Swift.max(steepestStep(live, (change - 2_048)..<change), steepestStep(live, (length - 2_048)..<length))
            XCTAssertGreaterThan(steady, 0.01, label)
            // While a longer line fills, the old wait plays exactly — not the new line's silence.
            let before = exportOf(song.project, song, effects: [lateTrack: [LateInsert(latency: from)]])
            XCTAssertLessThan(worstDifference(live, from: change, to: change + Swift.max(0, to - from), before, shift: from), 1e-6,
                              "\(label): the old wait holds while the new line fills")
            var silentRun = 0
            var longest = 0
            for sample in live[change..<(change + 2_048)] {
                silentRun = Swift.abs(sample) < 1e-7 ? silentRun + 1 : 0
                longest = Swift.max(longest, silentRun)
            }
            XCTAssertLessThan(longest, 16, "\(label): no silence")
            XCTAssertLessThan(steepestStep(live, change..<(length - 2_048)), 1.3 * steady, "\(label): no step")
            XCTAssertLessThan(worstDifference(live, from: change + 2_048, to: length, file, shift: to), 1e-6,
                              "\(label): then it waits \(to) frames")
        }
    }

    /// Five latencies a block apart: one still holding is dropped unheard, the ones that come while
    /// the mix glides wait for it, and the mix settles on the last — without a step.
    func testFiveLatencyChangesInARowWhilePlayingNeverStepAndSettleOnTheLast() throws {
        var song = try tones(["Late", "Plain"])
        let lateTrack = song.tracks[0]
        try Command.setMute(lateTrack, true).apply(to: &song.project)
        let change = beat + 4_800, length = beat + 9_600
        let file = exportOf(song.project, song, effects: [lateTrack: [LateInsert(latency: 85)]])
        let latencies = [85, 40, 120, 0, 85]
        for block in [32, 64] {
            let late = LateInsert(latency: 0)
            let effects: [TrackID: [any HostedProcessor]] = [lateTrack: [late]]
            var publishes = [Publish(at: 0, project: song.project, effects: effects)]
            for (step, latency) in latencies.enumerated() {
                publishes.append(Publish(at: change + 64 * step, project: song.project, effects: effects,
                                         prepare: { late.latency = latency }))
            }
            let live = playLive(song, publishes, length: length, block: block)
            let steady = Swift.max(steepestStep(live, (change - 2_048)..<change), steepestStep(live, (length - 2_048)..<length))
            XCTAssertGreaterThan(steady, 0.01, "block \(block): the tone plays")
            XCTAssertLessThan(steepestStep(live, change..<(length - 2_048)), 1.3 * steady, "block \(block): no step")
            XCTAssertLessThan(worstDifference(live, from: change + 2_048, to: length, file, shift: 85), 1e-6,
                              "block \(block): it settles on the last latency")
        }
    }

    /// A return that gets a latency while playing: the track's dry sound and the other return,
    /// which now wait for it, glide to their wait together.
    func testAReturnThatGetsALatencyWhilePlayingGlidesTheSoundsThatWaitForIt() throws {
        var song = try tones(["Voice"])
        let voice = song.tracks[0], verb = TrackID(), room = TrackID()
        try Command.addTrack(id: verb, name: "Verb", kind: .returnTrack, index: nil).apply(to: &song.project)
        try Command.addTrack(id: room, name: "Room", kind: .returnTrack, index: nil).apply(to: &song.project)
        try Command.setSend(track: voice, to: verb, db: 0).apply(to: &song.project)
        try Command.setSend(track: voice, to: room, db: 0).apply(to: &song.project)
        let change = beat + 4_800, length = beat + 9_600
        let file = exportOf(song.project, song, effects: [verb: [LateInsert(latency: 85)]])
        var renders: [[Float]] = []
        for block in [64, 128] {
            let live = playLive(song, [
                Publish(at: 0, project: song.project, effects: [:]),
                Publish(at: change, project: song.project, effects: [verb: [LateInsert(latency: 85)]]),
            ], length: length, block: block)
            let steady = Swift.max(steepestStep(live, (change - 2_048)..<change), steepestStep(live, (length - 2_048)..<length))
            XCTAssertGreaterThan(steady, 0.01, "block \(block): the tone plays")
            XCTAssertLessThan(steepestStep(live, change..<(length - 2_048)), 1.3 * steady, "block \(block): no step")
            XCTAssertLessThan(worstDifference(live, from: change + 2_048, to: length, file, shift: 85), 1e-6,
                              "block \(block): then they wait 85 frames, as the export plays them")
            renders.append(live)
        }
        XCTAssertLessThan(worstDifference(renders[0], from: 0, to: length, renders[1], shift: 0), 1e-6, "any block size")
    }

    /// The switch alone: its old path exactly until the glide, the raised cosine across it, its new
    /// path exactly after — at any block size.
    func testASwitchPlaysItsOldPathUntilTheGlideAndItsNewPathAfterAtAnyBlockSize() {
        let curve = UnsafeMutablePointer<Float>.allocate(capacity: Crossover.rampFrames)
        defer { curve.deallocate() }
        for step in 0..<Crossover.rampFrames { (curve + step).initialize(to: Crossover.gain(step)) }
        let scratchLeft = UnsafeMutablePointer<Float>.allocate(capacity: 1_024)
        let scratchRight = UnsafeMutablePointer<Float>.allocate(capacity: 1_024)
        defer {
            scratchLeft.deallocate()
            scratchRight.deallocate()
        }
        let primer = (0..<1_000).map { (index: Int) -> Float in Float(index + 1) }
        let input = (0..<600).map { (index: Int) -> Float in Float(1_001 + index) }
        let holdFrames = 100
        for block in [1, 7, 64, 333] {
            let old = DelayLine(delay: 40)
            _ = run(old, primer, block: 256)
            let change = PathSwitch(new: DelayLine(delay: 85), settledOld: old, predecessor: -1)
            var budget = CompensationLines.takeOverFrames
            XCTAssertEqual(change.arm(after: nil, holding: false, budget: &budget), 45,
                           "block \(block): 40 of the new line's 85 frames come from the old one")
            var crossover = Crossover()
            crossover.hold(atLeast: holdFrames)
            var left = input
            var right = input.map { (sample: Float) -> Float in -sample }
            var start = 0
            while start < input.count {
                let count = Swift.min(block, input.count - start)
                let window = crossover.window(frames: count)
                left.withUnsafeMutableBufferPointer { (l: inout UnsafeMutableBufferPointer<Float>) in
                    right.withUnsafeMutableBufferPointer { (r: inout UnsafeMutableBufferPointer<Float>) in
                        guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                        change.render(left: lp + start, right: rp + start, frames: count, window: window, curve: curve,
                                      scratchLeft: scratchLeft, scratchRight: scratchRight)
                    }
                }
                _ = crossover.advance(count)
                start += count
            }
            XCTAssertTrue(crossover.isIdle, "block \(block): the glide is over")
            var worst: Float = 0
            for index in 0..<input.count {
                // The 40 line plays 961, 962 …; the 85 line, once it holds real sound, 916, 917 ….
                let oldPath = Float(961 + index), newPath = Float(916 + index)
                let expected: Float
                if index < holdFrames {
                    expected = oldPath
                } else if index < holdFrames + Crossover.rampFrames {
                    expected = oldPath + (newPath - oldPath) * Crossover.gain(index - holdFrames)
                } else {
                    expected = newPath
                }
                worst = Swift.max(worst, Swift.abs(left[index] - expected), Swift.abs(right[index] + expected))
            }
            XCTAssertLessThan(worst, 0.01, "block \(block)")
        }
    }

    /// A latency added while stopped: the change crosses over in silence before Play, so Play in
    /// the middle of the tone plays what the export plays there, from the end of its start fade.
    func testALatencyAddedWhileStoppedPlaysWhatTheExportPlaysFromTheFirstSound() throws {
        var song = try tones(["Late", "Plain"])
        let lateTrack = song.tracks[0]
        try Command.setMute(lateTrack, true).apply(to: &song.project)
        let playAt = 2_560, length = 2_560 + 9_600, from = beat + 4_800
        let file = exportOf(song.project, song, effects: [lateTrack: [LateInsert(latency: 85)]])
        let live = playLive(song, [
            Publish(at: 0, project: song.project, effects: [:]),
            Publish(at: 512, project: song.project, effects: [lateTrack: [LateInsert(latency: 85)]]),
        ], length: length, block: 64, playAt: playAt, seekTo: from)
        XCTAssertGreaterThan(peak(live[(length - 2_048)..<length]), 0.1, "the tone plays")
        // Song frame `from + k` is heard at `playAt + 85 + k`; the start fades in over 128 frames,
        // and a crossover still holding at Play would glide until `playAt + 426` (the insert's
        // warm-up of 170, then the ramp).
        XCTAssertLessThan(worstDifference(live, from: playAt + 85 + 160, to: length, file, shift: playAt + 85 - from), 1e-6,
                          "it waits 85 frames from the first sound after Play, as the export plays it")
    }

    /// A latency that arrives while the track is silent: once it sounds, it plays what the export
    /// plays.
    func testATrackSilentWhenALatencyArrivesPlaysWhatTheExportPlaysOnceItSounds() throws {
        var song = try tones(["Late", "Plain"])
        let lateTrack = song.tracks[0]
        try Command.setMute(lateTrack, true).apply(to: &song.project)
        let length = beat + 9_600
        let file = exportOf(song.project, song, effects: [lateTrack: [LateInsert(latency: 85)]])
        let live = playLive(song, [
            Publish(at: 0, project: song.project, effects: [:]),
            Publish(at: 4_800, project: song.project, effects: [lateTrack: [LateInsert(latency: 85)]]),
        ], length: length, block: 64)
        XCTAssertGreaterThan(peak(live[(length - 2_048)..<length]), 0.1, "the tone plays")
        XCTAssertLessThan(worstDifference(live, from: 6_848, to: length, file, shift: 85), 1e-6,
                          "from its first sound it waits 85 frames, as the export plays it")
    }

    /// An edit that comes while the mix glides waits for the glide and is heard right after it.
    func testAMuteSentWhileTheMixGlidesIsHeardRightAfterTheGlide() throws {
        var song = try tones(["Late", "Plain"])
        let lateTrack = song.tracks[0], plain = song.tracks[1]
        try Command.setMute(lateTrack, true).apply(to: &song.project)
        var silent = song.project
        try Command.setMute(plain, true).apply(to: &silent)
        let change = beat + 4_800, length = beat + 9_600
        let effects: [TrackID: [any HostedProcessor]] = [lateTrack: [LateInsert(latency: 85)]]
        let live = playLive(song, [
            Publish(at: 0, project: song.project, effects: [:]),
            Publish(at: change, project: song.project, effects: effects),
            Publish(at: change + 256, project: silent, effects: effects),
        ], length: length, block: 64)
        XCTAssertGreaterThan(peak(live[(change - 2_048)..<change]), 0.1, "the tone played")
        XCTAssertLessThan(peak(live[(change + 1_024)..<length]), 1e-6, "the mute is heard right after the glide")
    }

    /// A fader moved while the crossover holds: the box carries the switch that is crossing, so the
    /// glide goes on and the track settles on its new wait at its new level.
    func testAFaderMovedWhileALatencyChangeHoldsCarriesTheChangeOn() throws {
        var song = try tones(["Late", "Plain"])
        let lateTrack = song.tracks[0], plain = song.tracks[1]
        try Command.setMute(lateTrack, true).apply(to: &song.project)
        var quieter = song.project
        try Command.setVolume(.track(plain), db: -1).apply(to: &quieter)
        let change = beat + 4_800, length = beat + 9_600
        let effects: [TrackID: [any HostedProcessor]] = [lateTrack: [LateInsert(latency: 85)]]
        let file = exportOf(quieter, song, effects: effects)
        let live = playLive(song, [
            Publish(at: 0, project: song.project, effects: [:]),
            Publish(at: change, project: song.project, effects: effects),
            Publish(at: change + 64, project: quieter, effects: effects),
        ], length: length, block: 64)
        let steady = Swift.max(steepestStep(live, (change - 2_048)..<change), steepestStep(live, (length - 2_048)..<length))
        XCTAssertGreaterThan(steady, 0.01, "the tone plays")
        XCTAssertLessThan(steepestStep(live, change..<(length - 2_048)), 1.3 * steady, "no step")
        XCTAssertLessThan(worstDifference(live, from: change + 2_048, to: length, file, shift: 85), 1e-6,
                          "it waits 85 frames at its new level, as the export plays it")
    }

    /// A latency added and taken away again while the crossover still holds: nobody heard the new
    /// wait, so nothing changes at all.
    func testALatencyUndoneWhileItsChangeHoldsChangesNothing() throws {
        var song = try tones(["Late", "Plain"])
        let lateTrack = song.tracks[0]
        try Command.setMute(lateTrack, true).apply(to: &song.project)
        let change = beat + 4_800, length = beat + 9_600
        let file = exportOf(song.project, song, effects: [:])
        let live = playLive(song, [
            Publish(at: 0, project: song.project, effects: [:]),
            Publish(at: change, project: song.project, effects: [lateTrack: [LateInsert(latency: 85)]]),
            Publish(at: change + 64, project: song.project, effects: [:]),
        ], length: length, block: 64)
        XCTAssertGreaterThan(peak(live[(length - 2_048)..<length]), 0.1, "the tone plays")
        XCTAssertLessThan(worstDifference(live, from: 0, to: length, file, shift: 0), 1e-6,
                          "the song plays as if nothing had changed")
    }

    /// Two waits on one lane changing in one crossover — a track's latency, then a return's while
    /// the first change still holds — cross over in series: click-free, and settled on both.
    func testTwoWaitsInSeriesChangingInOneCrossoverNeverStep() throws {
        var song = try tones(["Late", "Voice"])
        let lateTrack = song.tracks[0], voice = song.tracks[1], verb = TrackID()
        try Command.setMute(lateTrack, true).apply(to: &song.project)
        try Command.addTrack(id: verb, name: "Verb", kind: .returnTrack, index: nil).apply(to: &song.project)
        try Command.setSend(track: voice, to: verb, db: -6).apply(to: &song.project)
        let change = beat + 4_800, length = beat + 9_600
        let first: [TrackID: [any HostedProcessor]] = [lateTrack: [LateInsert(latency: 85)]]
        let both: [TrackID: [any HostedProcessor]] = [lateTrack: [LateInsert(latency: 85)], verb: [LateInsert(latency: 85)]]
        let file = exportOf(song.project, song, effects: both)
        let total = snapshot(song.project, effects: both).compensation.total
        XCTAssertGreaterThan(total, 85, "the two waits add up")
        let live = playLive(song, [
            Publish(at: 0, project: song.project, effects: [:]),
            Publish(at: change, project: song.project, effects: first),
            Publish(at: change + 64, project: song.project, effects: both),
        ], length: length, block: 64)
        let steady = Swift.max(steepestStep(live, (change - 2_048)..<change), steepestStep(live, (length - 2_048)..<length))
        XCTAssertGreaterThan(steady, 0.01, "the tone plays")
        XCTAssertLessThan(steepestStep(live, change..<(length - 2_048)), 1.3 * steady, "no step")
        XCTAssertLessThan(worstDifference(live, from: change + 2_048, to: length, file, shift: total), 1e-6,
                          "it settles on both waits, as the export plays them")
    }

    // MARK: - A latent insert itself, while the song plays

    /// Echoel's Tape effect on an insert chain: it plays 288 frames behind at 48 kHz.
    private func tape() -> LatentKernelInsert {
        LatentKernelInsert(EffectKernel(effect: .tape, sampleRate: rate))
    }

    /// The steepest step after `change` against the steepest of the steady tone before it and at
    /// the end: below 1.3 times means no click.
    private func stepsSmoothly(_ live: [Float], change: Int, length: Int, _ label: String) {
        let steady = Swift.max(steepestStep(live, (change - 2_048)..<change), steepestStep(live, (length - 2_048)..<length))
        XCTAssertGreaterThan(steady, 0.01, "\(label): the tone plays")
        XCTAssertLessThan(steepestStep(live, change..<(length - 2_048)), 1.3 * steady, "\(label): no step")
    }

    /// A latent insert that arrives on a playing track: the track plays dry while the effect warms
    /// up, then glides into it, on the same sample as its twin that now waits — no step, in phase.
    func testATrackThatGetsALatentInsertWhilePlayingGlidesIntoItInStepWithItsTwin() throws {
        let song = try tones(["Clipped", "Plain"])
        let clipped = song.tracks[0], plain = song.tracks[1]
        let change = beat + 4_800, length = beat + 14_400
        let alone = export(song, effects: [clipped: [clipper()]], isolating: plain)
        let window = (change + 2_048)..<(change + 6_144)
        var renders: [[Float]] = []
        for block in [64, 128] {
            let live = playLive(song, [
                Publish(at: 0, project: song.project, effects: [:]),
                Publish(at: change, project: song.project, effects: [clipped: [clipper()]]),
            ], length: length, block: block)
            stepsSmoothly(live, change: change, length: length, "block \(block)")
            XCTAssertGreaterThan(peak(live[window]), 1.95 * peak(alone[window]), "block \(block): in phase, the sum doubles")
            renders.append(live)
        }
        XCTAssertLessThan(worstDifference(renders[0], from: 0, to: length, renders[1], shift: 0), 1e-6, "any block size")
    }

    /// A latent insert taken off a playing track: it plays on under the glide back to the dry
    /// sound, in step with its twin that stops waiting.
    func testATrackWhoseLatentInsertIsRemovedWhilePlayingGlidesOutOfItInStepWithItsTwin() throws {
        let song = try tones(["Clipped", "Plain"])
        let clipped = song.tracks[0]
        let change = beat + 4_800, length = beat + 9_600
        let file = export(song, effects: [:])
        var renders: [[Float]] = []
        for block in [64, 128] {
            let live = playLive(song, [
                Publish(at: 0, project: song.project, effects: [clipped: [clipper()]]),
                Publish(at: change, project: song.project, effects: [:]),
            ], length: length, block: block)
            stepsSmoothly(live, change: change, length: length, "block \(block)")
            XCTAssertLessThan(worstDifference(live, from: change + 2_048, to: length, file, shift: 0), 1e-6,
                              "block \(block): then both play dry, as the export plays them")
            renders.append(live)
        }
        XCTAssertLessThan(worstDifference(renders[0], from: 0, to: length, renders[1], shift: 0), 1e-6, "any block size")
    }

    /// Tape added while playing never clicks: when it stays, when it is taken off again while its
    /// change still holds (then nobody heard it, and nothing changes), and when it is taken off
    /// while the mix glides into it (then the removal waits for the glide).
    func testTapeAddedWhilePlayingNeverClicksEvenWhenTheEditIsUndoneInItsHoldOrItsGlide() throws {
        let song = try tones(["Taped", "Plain"])
        let taped = song.tracks[0]
        let change = beat + 4_800, length = beat + 9_600
        XCTAssertEqual(tape().latencyFrames, 288, "Tape plays 6 ms behind at 48 kHz")
        XCTAssertEqual(PathSwitch.warmUp(for: tape()), 576, "held for twice that")
        let file = export(song, effects: [:])
        for block in [64, 128] {
            let live = playLive(song, [
                Publish(at: 0, project: song.project, effects: [:]),
                Publish(at: change, project: song.project, effects: [taped: [tape()]]),
            ], length: length, block: block)
            stepsSmoothly(live, change: change, length: length, "added, block \(block)")
        }
        for block in [64, 128] {
            let undone = playLive(song, [
                Publish(at: 0, project: song.project, effects: [:]),
                Publish(at: change, project: song.project, effects: [taped: [tape()]]),
                Publish(at: change + 256, project: song.project, effects: [:]),
            ], length: length, block: block)
            XCTAssertLessThan(worstDifference(undone, from: 0, to: length, file, shift: 0), 1e-6,
                              "taken off while it holds, block \(block): the song plays as if nothing had changed")
        }
        let gliding = tape()
        let late = playLive(song, [
            Publish(at: 0, project: song.project, effects: [:]),
            Publish(at: change, project: song.project, effects: [taped: [gliding]]),
            Publish(at: change + 640, project: song.project, effects: [:]),
        ], length: length, block: 64)
        stepsSmoothly(late, change: change, length: length, "taken off while it glides")
        XCTAssertLessThan(worstDifference(late, from: change + 2_048, to: length, file, shift: 0), 1e-6,
                          "taken off while it glides: then both play dry")
    }

    /// One latent insert replaced by another of the same latency: no line moves, and the track
    /// glides from the one to the other once the new one has warmed up.
    func testALatentInsertReplacedByAnEqualOneWhilePlayingGlidesWithoutAStep() throws {
        let song = try tones(["Clipped", "Plain"])
        let clipped = song.tracks[0], plain = song.tracks[1]
        let change = beat + 4_800, length = beat + 14_400
        let alone = export(song, effects: [clipped: [clipper()]], isolating: plain)
        let window = (change + 2_048)..<(change + 6_144)
        for block in [64, 128] {
            let live = playLive(song, [
                Publish(at: 0, project: song.project, effects: [clipped: [clipper()]]),
                Publish(at: change, project: song.project, effects: [clipped: [clipper()]]),
            ], length: length, block: block)
            stepsSmoothly(live, change: change, length: length, "block \(block)")
            XCTAssertGreaterThan(peak(live[window]), 1.95 * peak(alone[window]), "block \(block): still in phase")
        }
    }

    /// The hold before a new latent insert is heard: its latency, and as much again up to a tenth
    /// of a second — exactly, the old sound before it and the new wait after the glide.
    func testANewLatentInsertIsHeardAfterTwiceItsLatencyAndATenthOfASecondAtMost() throws {
        var song = try tones(["Late", "Plain"])
        let lateTrack = song.tracks[0]
        try Command.setMute(lateTrack, true).apply(to: &song.project)
        let change = beat + 4_800
        let undelayed = exportOf(song.project, song, effects: [:])
        for latency in [2_000, 6_000] {
            let hold = latency + Swift.min(latency, 4_800)
            XCTAssertEqual(PathSwitch.warmUp(for: LateInsert(latency: latency)), hold)
            let length = change + hold + Crossover.rampFrames + 2_048
            let delayed = exportOf(song.project, song, effects: [lateTrack: [LateInsert(latency: latency)]])
            let live = playLive(song, [
                Publish(at: 0, project: song.project, effects: [:]),
                Publish(at: change, project: song.project, effects: [lateTrack: [LateInsert(latency: latency)]]),
            ], length: length, block: 64)
            XCTAssertLessThan(worstDifference(live, from: change, to: change + hold, undelayed, shift: 0), 1e-6,
                              "\(latency): the old sound, exactly, while the insert warms up")
            XCTAssertLessThan(worstDifference(live, from: change + hold + Crossover.rampFrames, to: length, delayed, shift: latency),
                              1e-6, "\(latency): then the new wait, exactly")
        }
    }

    /// A latent insert added to the master while playing glides in without a step or a dip.
    func testALatentInsertAddedToTheMasterWhilePlayingGlidesIntoItWithoutAStep() throws {
        let song = try tones(["Solo"])
        let change = beat + 4_800, length = beat + 14_400
        var renders: [[Float]] = []
        for block in [64, 128] {
            let live = playLive(song, [
                Publish(at: 0, project: song.project, effects: [:]),
                Publish(at: change, project: song.project, effects: [:], master: [clipper()]),
            ], length: length, block: block)
            stepsSmoothly(live, change: change, length: length, "block \(block)")
            XCTAssertGreaterThan(peak(live[(change + 2_048)..<(change + 6_144)]), 0.98 * peak(live[(change - 4_096)..<change]),
                                 "block \(block): no loss of level")
            renders.append(live)
        }
        XCTAssertLessThan(worstDifference(renders[0], from: 0, to: length, renders[1], shift: 0), 1e-6, "any block size")
    }

    /// Faders moved again and again beside a latent insert that stays: no crossover starts, so
    /// the mix never dips and never steps.
    func testAFaderMovedWhileALatentInsertPlaysNeverDipsOrSteps() throws {
        let song = try tones(["Clipped", "Plain"])
        let clipped = song.tracks[0], plain = song.tracks[1]
        var quieter = song.project
        try Command.setVolume(.track(plain), db: -1).apply(to: &quieter)
        let change = beat + 4_800, length = beat + 9_600
        for block in [64, 128] {
            let effects: [TrackID: [any HostedProcessor]] = [clipped: [clipper()]]
            var publishes = [Publish(at: 0, project: song.project, effects: effects)]
            for step in 0..<12 {
                publishes.append(Publish(at: change + 256 * step, project: step % 2 == 0 ? quieter : song.project, effects: effects))
            }
            let live = playLive(song, publishes, length: length, block: block)
            stepsSmoothly(live, change: change, length: length, "block \(block)")
            let reference = peak(live[(change - 2_048)..<change])
            var start = change
            while start < change + 4_096 {
                XCTAssertGreaterThan(peak(live[start..<(start + 128)]), 0.9 * reference, "block \(block): no dip at \(start)")
                start += 128
            }
        }
    }

    /// A quick run of edits — one latent insert replaced by another, then the first switched on
    /// again while the change still holds — never runs an insert twice in one block: the chain
    /// switches at once instead.
    func testAnInsertNeverRunsTwiceInABlockWhenItComesBackWhileItsReplacementHolds() throws {
        var song = try tones(["Late", "Plain"])
        let lateTrack = song.tracks[0]
        try Command.setMute(lateTrack, true).apply(to: &song.project)
        let change = beat + 4_800, length = beat + 9_600
        let first = CountedInsert(latency: 85), second = CountedInsert(latency: 85)
        let live = playLive(song, [
            Publish(at: 0, project: song.project, effects: [lateTrack: [first]]),
            Publish(at: change, project: song.project, effects: [lateTrack: [second]]),
            Publish(at: change + 64, project: song.project, effects: [lateTrack: [first, second]]),
        ], length: length, block: 64)
        XCTAssertGreaterThan(peak(live[(length - 2_048)..<length]), 0.1, "the tone plays")
        XCTAssertLessThanOrEqual(first.processed, length, "the first insert runs each frame once at most")
        XCTAssertLessThanOrEqual(second.processed, length - change, "the second, from its arrival on")
    }

    /// Two latent inserts on one chain while a long change elsewhere still holds: the first taken
    /// off, then put back while the second is taken off. The one coming back cancels its own
    /// leaving and the other glides out in its own slot — the chain never steps.
    func testAnInsertPutBackWhileItsNeighbourLeavesInTheSameHoldNeverSteps() throws {
        var song = try tones(["Clipped", "Late"])
        let clipped = song.tracks[0], lateTrack = song.tracks[1]
        try Command.setMute(lateTrack, true).apply(to: &song.project)
        let change = beat + 4_800, length = change + 8_000 + Crossover.rampFrames + 4_096
        let first = clipper(), second = clipper()
        let long = LateInsert(latency: 4_000)
        let live = playLive(song, [
            Publish(at: 0, project: song.project, effects: [clipped: [first, second]]),
            Publish(at: change, project: song.project, effects: [clipped: [second], lateTrack: [long]]),
            Publish(at: change + 64, project: song.project, effects: [clipped: [first], lateTrack: [long]]),
        ], length: length, block: 64)
        stepsSmoothly(live, change: change, length: length, "put back while its neighbour leaves")
    }

    /// Two latent inserts on one chain while a long change elsewhere still holds: the first taken
    /// off, then the second too. The first, still leaving, keeps its place before the second, so
    /// the held sound stays exactly what it was — the chain never steps.
    func testAnInsertStillLeavingKeepsItsPlaceWhenTheInsertAfterItLeavesToo() throws {
        var song = try tones(["Clipped", "Late"])
        let clipped = song.tracks[0], lateTrack = song.tracks[1]
        try Command.setMute(lateTrack, true).apply(to: &song.project)
        let change = beat + 4_800, length = change + 8_000 + Crossover.rampFrames + 4_096
        let first = clipper(), second = clipper()
        let long = LateInsert(latency: 4_000)
        let live = playLive(song, [
            Publish(at: 0, project: song.project, effects: [clipped: [first, second]]),
            Publish(at: change, project: song.project, effects: [clipped: [second], lateTrack: [long]]),
            Publish(at: change + 64, project: song.project, effects: [lateTrack: [long]]),
        ], length: length, block: 64)
        stepsSmoothly(live, change: change, length: length, "both taken off in one hold")
    }
}
