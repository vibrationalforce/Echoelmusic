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
        /// The sample a sampler lane plays. The snapshot holds the reference, so the buffer
        /// lives exactly as long as a snapshot that can still reach the render thread.
        public let sample: SampleBuffer?
    }

    /// An audio track: its regions, each resolved to the buffer it plays and to output samples.
    public struct AudioLane: Sendable {
        public let track: TrackID
        public let gainLeft: Float
        public let gainRight: Float
        /// Sorted by `startSample`. Overlapping regions both sound.
        public let regions: [Region]
    }

    /// An audio region in output samples. The buffer is held by the snapshot, as for samplers.
    public struct Region: Sendable {
        public let startSample: Int64
        /// One past the last output sample the region writes.
        public let endSample: Int64
        public let buffer: SampleBuffer
        /// First frame of the buffer that plays, and how many play.
        public let offset: Double
        public let length: Double
        /// Buffer frames per output sample: the file plays at its own speed at any output rate.
        public let step: Double
    }

    /// Rises with every published snapshot; the render thread re-seeks when it changes.
    public let generation: UInt64
    public let time: TimeConversion
    public let timeSignature: TimeSignature
    public let lanes: [Lane]
    public let audioLanes: [AudioLane]
    /// One past the last output sample any audio region writes; 0 without audio.
    public let audioEnd: Int64

    /// `samples` holds the loaded buffer of every media file a sampler track may play; a
    /// file that is missing or not yet loaded leaves its track silent.
    public init(plan: PlaybackPlan, project: Project, slots: [TrackID: Int], sampleRate: Double, generation: UInt64,
                samples: [MediaID: SampleBuffer] = [:]) {
        self.generation = generation
        time = TimeConversion(tempoMap: plan.tempoMap, sampleRate: sampleRate)
        timeSignature = project.timeSignature
        let anySolo = project.tracks.contains { $0.mixer.isSoloed }
        let master = project.master
        let conversion = TimeConversion(tempoMap: plan.tempoMap, sampleRate: sampleRate)
        audioLanes = project.tracks.filter { $0.kind == .audio }.map { track in
            let audible = !track.mixer.isMuted && (!anySolo || track.mixer.isSoloed)
            let (left, right) = audible ? Self.gains(track: track.mixer, master: master) : (0, 0)
            let regions = track.regions.compactMap { region in
                Self.resolve(region, samples: samples, time: conversion, sampleRate: sampleRate)
            }
            return AudioLane(track: track.id, gainLeft: left, gainRight: right, regions: regions)
        }
        audioEnd = audioLanes.flatMap(\.regions).map(\.endSample).max() ?? 0
        lanes = plan.tracks.compactMap { events in
            guard let slot = slots[events.track], let track = project.track(events.track) else { return nil }
            let audible = !track.mixer.isMuted && (!anySolo || track.mixer.isSoloed)
            let (left, right) = audible ? Self.gains(track: track.mixer, master: master) : (0, 0)
            return Lane(track: events.track, slot: slot, events: events.events, gainLeft: left, gainRight: right,
                        patch: SynthPatch(track.instrument), device: track.instrument.device,
                        sample: track.instrument.device == .sampler ? track.instrument.sample.flatMap { samples[$0] } : nil)
        }
    }

    /// Nil when the file is not loaded or nothing of the region falls inside the loaded file
    /// (the file on disk may be shorter than when it was measured).
    static func resolve(_ region: AudioRegion, samples: [MediaID: SampleBuffer], time: TimeConversion,
                        sampleRate: Double) -> Region? {
        guard let buffer = samples[region.media], sampleRate > 0, sampleRate.isFinite else { return nil }
        let length = Swift.min(region.length, buffer.frameCount - region.offset)
        guard region.offset >= 0, length > 0 else { return nil }
        let step = buffer.sampleRate / sampleRate
        let start = time.sample(at: region.start)
        let end = start + Int64((Double(length) / step).rounded(.up))
        return Region(startSample: start, endSample: end, buffer: buffer, offset: Double(region.offset),
                      length: Double(length), step: step)
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
