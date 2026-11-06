import EchoelCore
import Foundation

/// Plugin delay compensation (WS-PDC): how many frames each lane of a snapshot waits, so that
/// everything leaving the engine lines up whatever latency its instruments and effects bring.
/// Pure; compiled with the snapshot on the main thread from latencies read there
/// (`HostedProcessor.latencyFrames`, `HostedInstrument.latencyFrames`), never on the render thread.
///
/// The model — three meeting points, in the order the signal reaches them:
/// 1. **Tracks.** A track's chain latency is its instrument's (a plugin) plus its active inserts'.
///    Every track, instrument or audio, waits `delay` = the longest track chain − its own, at the
///    end of its chain and BEFORE its fader and its send taps. A send taps after the chain, so
///    without this a return's input would be late by the sending track's latency; with it every
///    send reaches every return in time with every other.
/// 2. **Returns.** A return adds its inserts' latency on top of what its sends bring. Every return
///    waits the longest return chain − its own, after its chain; and every track's own output —
///    not its sends — waits that longest return chain too (`directDelay`, after the send taps), so
///    the dry track meets its reverb at the master. Only returns some send feeds count: a return
///    nothing feeds is silent at its input, and its latency would delay every track for nothing.
/// 3. **Outputs.** The master's effects delay only what passes through them; a track or return on
///    its own output pair waits the master's latency as well, so every interface output lines up.
///
/// A muted or soloed-away track still counts in 1: muting a track never moves the others in time.
/// `total` is how late the engine plays behind its sources.
///
/// `EngineCore` applies the plan on the render thread through one `DelayLine` per wait
/// (`CompensationLines`, made with the snapshot on the main thread): instrument tracks — built-in
/// or plugin, arrangement or session — audio tracks — regions, session clips and a monitored input
/// alike — their sends, the returns, and lanes on their own output pair, spatialized or not.
/// Not lined up with it yet: the metronome's click and what goes out as MIDI (clock, notes,
/// timecode) play `total` frames ahead of the mix, and an export starts `total` frames late
/// without growing by them.
public struct DelayCompensation: Equatable, Sendable {
    /// What a track brings: its chain latency, the return buses its sends feed, and whether it
    /// plays on its own output pair instead of the master.
    public struct TrackChain: Equatable, Sendable {
        public var track: TrackID
        public var latency: Int
        public var buses: [Int]
        public var ownOutput: Bool

        public init(track: TrackID, latency: Int, buses: [Int] = [], ownOutput: Bool = false) {
            self.track = track
            self.latency = latency
            self.buses = buses
            self.ownOutput = ownOutput
        }
    }

    /// What a return brings: its bus, its chain latency, and whether it plays on its own pair.
    public struct ReturnChain: Equatable, Sendable {
        public var track: TrackID
        public var bus: Int
        public var latency: Int
        public var ownOutput: Bool

        public init(track: TrackID, bus: Int, latency: Int, ownOutput: Bool = false) {
            self.track = track
            self.bus = bus
            self.latency = latency
            self.ownOutput = ownOutput
        }
    }

    /// A track's compensation: `delay` after its chain, before fader and sends; `directDelay`
    /// on its own output only, after the send taps.
    public struct TrackDelay: Equatable, Sendable {
        public let track: TrackID
        public let latency: Int
        public let delay: Int
        public let directDelay: Int
    }

    /// A return's compensation: `delay` after its chain, before its fader.
    public struct ReturnDelay: Equatable, Sendable {
        public let track: TrackID
        public let bus: Int
        public let latency: Int
        public let delay: Int
    }

    /// The most one unit is compensated for, in frames (two seconds at 48 kHz): a conformer that
    /// reports more counts as this, so the delay lines sized from the plan stay bounded.
    public static let maximumUnitLatency = 96_000

    public let tracks: [TrackDelay]
    public let returns: [ReturnDelay]
    /// The longest track chain, the longest return chain some send feeds, and the master's.
    public let trackLatency: Int
    public let returnLatency: Int
    public let masterLatency: Int

    /// Nothing to compensate.
    public static let none = DelayCompensation(tracks: [], returns: [], master: 0)

    public init(tracks: [TrackChain], returns: [ReturnChain], master: Int) {
        let longestTrack = tracks.map { Self.clean($0.latency) }.max() ?? 0
        let fed = Set(tracks.flatMap(\.buses))
        let longestReturn = returns.filter { fed.contains($0.bus) }.map { Self.clean($0.latency) }.max() ?? 0
        let masterFrames = Self.clean(master)
        self.tracks = tracks.map { (chain: TrackChain) -> TrackDelay in
            let own = Self.clean(chain.latency)
            return TrackDelay(track: chain.track, latency: own, delay: longestTrack - own,
                              directDelay: longestReturn + (chain.ownOutput ? masterFrames : 0))
        }
        self.returns = returns.map { (chain: ReturnChain) -> ReturnDelay in
            let own = Self.clean(chain.latency)
            return ReturnDelay(track: chain.track, bus: chain.bus, latency: own,
                               delay: Swift.max(0, longestReturn - own) + (chain.ownOutput ? masterFrames : 0))
        }
        trackLatency = longestTrack
        returnLatency = longestReturn
        masterLatency = masterFrames
    }

    /// How late the engine plays behind its sources, in frames.
    public var total: Int { trackLatency + returnLatency + masterLatency }

    /// The longest wait any one delay line holds: what a line sized from this plan must take.
    public var longestDelay: Int {
        Swift.max(tracks.map { Swift.max($0.delay, $0.directDelay) }.max() ?? 0, returns.map(\.delay).max() ?? 0)
    }

    /// No lane waits.
    public var isEmpty: Bool { longestDelay == 0 }

    public func delay(of track: TrackID) -> TrackDelay? {
        tracks.first { $0.track == track }
    }

    public func delay(ofReturn bus: Int) -> ReturnDelay? {
        returns.first { $0.bus == bus }
    }

    /// A chain's latency: its units' in order, each counted from 0 to `maximumUnitLatency`.
    public static func chain(_ units: [Int]) -> Int {
        units.reduce(0) { (sum: Int, unit: Int) -> Int in sum + Swift.min(Swift.max(unit, 0), maximumUnitLatency) }
    }

    /// A lane's latency as the plan takes it: never negative, and bounded (64 units at the most
    /// each one may count for), so no sum of them overflows.
    private static func clean(_ frames: Int) -> Int {
        Swift.min(Swift.max(frames, 0), maximumUnitLatency * 64)
    }
}
