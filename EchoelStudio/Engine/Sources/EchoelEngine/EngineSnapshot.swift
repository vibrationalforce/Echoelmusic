import EchoelCore
import EchoelDSP
import Foundation

/// Everything the render thread needs for one state of the project, compiled on the main
/// thread: the timeline, and per instrument track its synth slot, its note events and its
/// mix gains. Rebuilding one is cheap — the event arrays are shared with the plan, not
/// copied — so a fader move publishes a new snapshot without recompiling any notes.
public struct EngineSnapshot: Sendable {
    public struct Lane: Sendable {
        public let track: TrackID
        public let slot: Int
        public let events: [PlaybackPlan.NoteEvent]
        public let gainLeft: Float
        public let gainRight: Float
        public let patch: SynthPatch
        /// Which instrument in the slot plays the events.
        public let device: InstrumentDevice
    }

    /// Rises with every published snapshot; the render thread re-seeks when it changes.
    public let generation: UInt64
    public let time: TimeConversion
    public let timeSignature: TimeSignature
    public let lanes: [Lane]

    public init(plan: PlaybackPlan, project: Project, slots: [TrackID: Int], sampleRate: Double, generation: UInt64) {
        self.generation = generation
        time = TimeConversion(tempoMap: plan.tempoMap, sampleRate: sampleRate)
        timeSignature = project.timeSignature
        let anySolo = project.tracks.contains { $0.mixer.isSoloed }
        let master = project.master
        lanes = plan.tracks.compactMap { events in
            guard let slot = slots[events.track], let track = project.track(events.track) else { return nil }
            let audible = !track.mixer.isMuted && (!anySolo || track.mixer.isSoloed)
            let (left, right) = audible ? Self.gains(track: track.mixer, master: master) : (0, 0)
            return Lane(track: events.track, slot: slot, events: events.events, gainLeft: left, gainRight: right,
                        patch: SynthPatch(track.instrument), device: track.instrument.device)
        }
    }

    /// Track fader × master fader; constant-power track pan, master pan as a balance.
    static func gains(track: MixerStrip, master: MixerStrip) -> (Float, Float) {
        let level = linear(track.volumeDB) * linear(master.volumeDB)
        let pan = Float(track.pan.isFinite ? Swift.min(Swift.max(track.pan, -1), 1) : 0)
        let angle = (pan + 1) * Float.pi / 4
        let balance = Float(master.pan.isFinite ? Swift.min(Swift.max(master.pan, -1), 1) : 0)
        let left = level * cosf(angle) * Swift.min(1, 1 - balance)
        let right = level * sinf(angle) * Swift.min(1, 1 + balance)
        return (left, right)
    }

    /// The fader floor is silence, not −144 dB of leakage.
    static func linear(_ db: Double) -> Float {
        guard db.isFinite, db > MixerStrip.volumeRange.lowerBound else { return 0 }
        return Float(Foundation.pow(10, Swift.min(db, MixerStrip.volumeRange.upperBound) / 20))
    }
}

/// Gives each instrument track a synth slot that stays the same while the track exists, so
/// ringing voices survive edits. Main thread only.
public struct SlotAssigner: Sendable {
    public let capacity: Int
    public private(set) var slots: [TrackID: Int] = [:]

    public init(capacity: Int) {
        self.capacity = Swift.max(0, capacity)
    }

    /// Frees the slots of tracks that are gone and assigns free slots to new instrument
    /// tracks, in track order. Tracks beyond `capacity` get none and stay silent.
    public mutating func update(for project: Project) {
        let instruments = project.tracks.filter { $0.kind == .instrument }.map(\.id)
        let alive = Set(instruments)
        slots = slots.filter { alive.contains($0.key) }
        var used = Set(slots.values)
        for id in instruments where slots[id] == nil {
            guard let free = (0..<capacity).first(where: { !used.contains($0) }) else { break }
            slots[id] = free
            used.insert(free)
        }
    }
}
