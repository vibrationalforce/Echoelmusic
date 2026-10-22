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
        /// The loaded Audio Unit a plugin lane plays, held like the sample.
        public let unit: (any HostedInstrument)?
        /// The track's insert effects, in order, held like the unit.
        public let inserts: [any HostedProcessor]
        public let sends: [SendTap]
        /// First interface channel of the pair the lane plays on, or −1 for the master mix.
        public let output: Int
        /// The track's clips as loops, for the session.
        public let clips: [PlaybackPlan.ClipEvents]
        /// Changes exactly when the track's notes or clips change. The render thread releases a
        /// lane's sounding notes only then, so a fader ride never cuts a held chord.
        public let eventsRevision: UInt64
        /// Set when automation moves the lane's level or pan (or the master's): the gains above
        /// are then only the value at the playhead.
        public let mix: MovingMix?
        /// Synth parameters the song automates on this track.
        public let patchLanes: [PatchAutomation]
    }

    /// A synth parameter and its lane, compiled for the render thread.
    public struct PatchAutomation: Sendable {
        public let field: PatchField
        public let lane: AutomationLane
        /// A choice (the waveform) holds each point's value until the next; a number moves
        /// between points.
        public let holds: Bool

        public init(field: PatchField, lane: AutomationLane) {
            self.field = field
            self.lane = lane
            holds = field.parameter.taper == .stepped
        }

        /// The lane's value at `position`, the way the field takes it. Render-safe.
        public func value(atPosition position: Double) -> Double? {
            holds ? lane.heldValue(atPosition: position) : lane.value(atPosition: position)
        }
    }

    /// A hosted unit's parameter and its lane, compiled for the render thread: the lane holds
    /// 0…1 of the parameter's travel, `range` is the unit's own.
    public struct UnitAutomation: Sendable {
        public let unit: any ParameterScheduling
        public let address: UInt64
        public let range: ClosedRange<Float>
        public let lane: AutomationLane

        /// The unit's value for the lane at a fractional tick, or nil for a lane without points.
        public func value(at position: Double) -> Float? {
            guard let travel = lane.value(atPosition: position) else { return nil }
            let n = Float(travel.isFinite ? Swift.min(Swift.max(travel, 0), 1) : 0)
            return range.lowerBound + n * (range.upperBound - range.lowerBound)
        }
    }

    /// The master's strip and the lanes that move it.
    public struct MasterMix: Sendable {
        public let strip: MixerStrip
        public let volume: AutomationLane?
        public let pan: AutomationLane?
    }

    /// A track's gains that move with automation. Pure, render-safe.
    public struct MovingMix: GainCurve {
        public let strip: MixerStrip
        public let volume: AutomationLane?
        public let pan: AutomationLane?
        /// Nil when the lane skips the master (its own output pair, or a send's pre-master tap).
        public let master: MasterMix?

        public func gains(at position: Double) -> (Float, Float) {
            var track = strip
            if let value = volume?.value(atPosition: position) { track.volumeDB = value }
            if let value = pan?.value(atPosition: position) { track.pan = value }
            var bus = MixerStrip()
            if let master {
                bus = master.strip
                if let value = master.volume?.value(atPosition: position) { bus.volumeDB = value }
                if let value = master.pan?.value(atPosition: position) { bus.pan = value }
            }
            return EngineSnapshot.gains(track: track, master: bus)
        }
    }

    /// A send whose level, or whose track's level, moves.
    public struct MovingSend: GainCurve {
        public let mix: MovingMix
        public let levelDB: Double
        public let level: AutomationLane?

        public func gains(at position: Double) -> (Float, Float) {
            let (left, right) = mix.gains(at: position)
            let send = EngineSnapshot.linear(level?.value(atPosition: position) ?? levelDB)
            return (left * send, right * send)
        }
    }

    /// Where a track's post-fader signal also goes: return bus `bus`, at these gains.
    public struct SendTap: Sendable {
        public let bus: Int
        public let gainLeft: Float
        public let gainRight: Float
        public let moving: MovingSend?
    }

    /// A return track: its own bus, effects and fader. Solo does not silence it — the soloed
    /// track's sends must still be heard through it. A soloed return plays in place: every other
    /// track's own output goes quiet, but what it sends to that return still arrives.
    public struct ReturnLane: Sendable {
        public let track: TrackID
        public let bus: Int
        public let gainLeft: Float
        public let gainRight: Float
        public let inserts: [any HostedProcessor]
        public let output: Int
        public let mix: MovingMix?
    }

    /// An audio track: its regions, each resolved to the buffer it plays and to output samples.
    public struct AudioLane: Sendable {
        public let track: TrackID
        /// The session slot the track's clips launch in, or −1 without one.
        public internal(set) var slot: Int
        /// The track's audio clips with their buffers, for the session.
        public let loops: [AudioLoop]
        public let gainLeft: Float
        public let gainRight: Float
        /// Sorted by `startSample`. Overlapping regions both sound.
        public let regions: [Region]
        public let inserts: [any HostedProcessor]
        public let sends: [SendTap]
        public let output: Int
        public let mix: MovingMix?
        /// The interface input the lane plays through its strip, or −1.
        public let monitor: Int
    }

    /// An audio clip resolved to its buffer: `length` buffer frames from `offset` each pass of
    /// `loopLength` ticks.
    public struct AudioLoop: Sendable {
        public let clip: ClipID
        public let buffer: SampleBuffer
        public let offset: Double
        public let length: Double
        public let step: Double
        public let loopLength: Tick
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
    public private(set) var lanes: [Lane]
    public private(set) var audioLanes: [AudioLane]
    public private(set) var returns: [ReturnLane]
    /// One past the last output sample any audio region writes; 0 without audio.
    public let audioEnd: Int64
    /// Some lane automates a synth parameter.
    public let automatesPatches: Bool
    /// The song's lanes on parameters of loaded, playing units. A lane on a unit that is not
    /// loaded, bypassed, or does not have that parameter (another version) does nothing.
    public let unitAutomation: [UnitAutomation]
    /// The master's loaded, active insert effects in order, run on the master pair after
    /// everything is mixed into it.
    public let masterEffects: [any HostedProcessor]

    /// `samples` holds the loaded buffer of every media file a sampler track may play; a
    /// file that is missing or not yet loaded leaves its track silent.
    /// `units` holds the loaded Audio Unit of every plugin track, at this sample rate; a plugin
    /// track without one (still loading, missing on this device) stays silent.
    /// `effects` holds each track's loaded insert effects in order; one prepared for another
    /// rate is left out.
    /// `revisions` numbers each track's events (`EventRevisions`); without one, every snapshot
    /// counts as an edit of the track.
    public init(plan: PlaybackPlan, project: Project, slots: [TrackID: Int], sampleRate: Double, generation: UInt64,
                samples: [MediaID: SampleBuffer] = [:], units: [TrackID: any HostedInstrument] = [:],
                effects: [TrackID: [any HostedProcessor]] = [:], outputChannels: Int = 2,
                revisions: [TrackID: UInt64] = [:], monitoring: [TrackID: Int] = [:],
                masterEffects: [any HostedProcessor] = []) {
        let inserts = { (track: TrackID) in (effects[track] ?? []).filter { $0.sampleRate == sampleRate } }
        let masterChain = masterEffects.filter { $0.sampleRate == sampleRate }
        self.masterEffects = masterChain
        self.generation = generation
        time = TimeConversion(tempoMap: plan.tempoMap, sampleRate: sampleRate)
        timeSignature = project.timeSignature
        let anySolo = project.tracks.contains { $0.mixer.isSoloed }
        let master = project.master
        let conversion = TimeConversion(tempoMap: plan.tempoMap, sampleRate: sampleRate)
        /// A track on its own pair skips the master; a pair this device lacks falls back to it.
        let route = { (track: Track) -> (output: Int, master: MixerStrip) in
            guard let output = track.output, output >= 2, output + 1 < outputChannels else { return (-1, master) }
            return (output, MixerStrip())
        }
        let automation = Dictionary(project.automation.map { ($0.target, $0) }, uniquingKeysWith: { first, _ in first })
        let masterMix = MasterMix(strip: master, volume: automation[.masterVolume], pan: automation[.masterPan])
        let masterMoves = masterMix.volume != nil || masterMix.pan != nil
        /// Nil when nothing moves the track's gains, so the render thread keeps the fixed ones.
        let moving = { (track: Track, throughMaster: Bool) -> MovingMix? in
            let volume = automation[.volume(track.id)], pan = automation[.pan(track.id)]
            guard volume != nil || pan != nil || (throughMaster && masterMoves) else { return nil }
            return MovingMix(strip: track.mixer, volume: volume, pan: pan, master: throughMaster ? masterMix : nil)
        }
        let returnTracks = project.tracks.filter { $0.kind == .returnTrack }
        var busOf: [TrackID: Int] = [:]
        for (index, track) in returnTracks.enumerated() { busOf[track.id] = index }
        returns = returnTracks.enumerated().map { index, track in
            let (output, into) = route(track)
            let (left, right) = track.mixer.isMuted ? (0, 0) : Self.gains(track: track.mixer, master: into)
            return ReturnLane(track: track.id, bus: index, gainLeft: left, gainRight: right, inserts: inserts(track.id),
                              output: output, mix: track.mixer.isMuted ? nil : moving(track, output < 0))
        }
        let soloedReturns = Set(returnTracks.filter(\.mixer.isSoloed).map(\.id))
        /// Post-fader, post-pan: the track's own gains (without the master) times the send level.
        /// A track silenced by someone else's solo still feeds a soloed return; a muted one feeds none.
        let sends = { (track: Track, audible: Bool) -> [SendTap] in
            guard !track.mixer.isMuted, audible || !soloedReturns.isEmpty else { return [] }
            let (left, right) = Self.gains(track: track.mixer, master: MixerStrip())
            return track.sends.compactMap { send in
                guard let bus = busOf[send.target], audible || soloedReturns.contains(send.target) else { return nil }
                let level = Self.linear(send.levelDB)
                let lane = automation[.send(track.id, to: send.target)]
                let pre = moving(track, false)
                guard level > 0 || lane != nil else { return nil }
                let movingSend = lane != nil || pre != nil
                    ? MovingSend(mix: pre ?? MovingMix(strip: track.mixer, volume: nil, pan: nil, master: nil),
                                 levelDB: send.levelDB, level: lane)
                    : nil
                return SendTap(bus: bus, gainLeft: left * level, gainRight: right * level, moving: movingSend)
            }
        }
        audioLanes = project.tracks.filter { $0.kind == .audio }.map { track in
            let audible = !track.mixer.isMuted && (!anySolo || track.mixer.isSoloed)
            let (output, into) = route(track)
            let (left, right) = audible ? Self.gains(track: track.mixer, master: into) : (0, 0)
            let regions = track.regions.compactMap { region in
                Self.resolve(region, samples: samples, time: conversion, sampleRate: sampleRate)
            }
            let loops = track.clips.compactMap { clip -> AudioLoop? in
                guard let audio = clip.audio, let buffer = samples[audio.media], sampleRate > 0, sampleRate.isFinite else { return nil }
                let length = Swift.min(audio.length, buffer.frameCount - audio.offset)
                guard audio.offset >= 0, length > 0 else { return nil }
                return AudioLoop(clip: clip.id, buffer: buffer, offset: Double(audio.offset), length: Double(length),
                                 step: buffer.sampleRate / sampleRate, loopLength: clip.length)
            }
            return AudioLane(track: track.id, slot: slots[track.id] ?? -1, loops: loops,
                             gainLeft: left, gainRight: right, regions: regions,
                             inserts: inserts(track.id), sends: sends(track, audible), output: output,
                             mix: audible ? moving(track, output < 0) : nil,
                             monitor: monitoring[track.id].flatMap { (0..<InputMonitor.channelLimit).contains($0) ? $0 : nil } ?? -1)
        }
        audioEnd = audioLanes.flatMap(\.regions).map(\.endSample).max() ?? 0
        let compiled = plan.tracks.compactMap { events -> Lane? in
            guard let slot = slots[events.track], let track = project.track(events.track) else { return nil }
            let audible = !track.mixer.isMuted && (!anySolo || track.mixer.isSoloed)
            let (output, into) = route(track)
            let (left, right) = audible ? Self.gains(track: track.mixer, master: into) : (0, 0)
            var patchLanes: [PatchAutomation] = []
            if track.instrument.device == .synth {
                for parameter in SynthParameter.all {
                    guard let lane = automation[ParameterAddress(.track(track.id), parameter.key)],
                          let field = PatchField(parameter.key) else { continue }
                    patchLanes.append(PatchAutomation(field: field, lane: lane))
                }
            }
            return Lane(track: events.track, slot: slot, events: events.events, gainLeft: left, gainRight: right,
                        patch: SynthPatch(track.instrument), device: track.instrument.device,
                        sample: track.instrument.device == .sampler ? track.instrument.sample.flatMap { samples[$0] } : nil,
                        unit: track.instrument.device == .plugin ? units[events.track].flatMap { $0.sampleRate == sampleRate ? $0 : nil } : nil,
                        inserts: inserts(events.track), sends: sends(track, audible), output: output,
                        clips: events.clips, eventsRevision: revisions[events.track] ?? generation,
                        mix: audible ? moving(track, output < 0) : nil, patchLanes: patchLanes)
        }
        lanes = compiled
        automatesPatches = compiled.contains { !$0.patchLanes.isEmpty }
        unitAutomation = project.automation.compactMap { lane -> UnitAutomation? in
            if lane.target.owner == .master, let parameter = lane.target.key.pluginParameter,
               case .insert(let insert) = parameter.unit {
                guard let unit = masterChain.first(where: { $0.insert == insert && !$0.isBypassed }),
                      let range = unit.parameterRanges[parameter.address], range.upperBound > range.lowerBound,
                      range.lowerBound.isFinite, range.upperBound.isFinite else { return nil }
                return UnitAutomation(unit: unit, address: parameter.address, range: range, lane: lane)
            }
            guard case .track(let id) = lane.target.owner, let parameter = lane.target.key.pluginParameter,
                  let track = project.track(id) else { return nil }
            let unit: (any ParameterScheduling)?
            switch parameter.unit {
            case .instrument:
                unit = track.kind == .instrument && track.instrument.device == .plugin
                    ? units[id].flatMap { $0.sampleRate == sampleRate ? $0 : nil } : nil
            case .insert(let insert):
                unit = inserts(id).first { $0.insert == insert && !$0.isBypassed }
            }
            guard let unit, let range = unit.parameterRanges[parameter.address], range.upperBound > range.lowerBound,
                  range.lowerBound.isFinite, range.upperBound.isFinite else { return nil }
            return UnitAutomation(unit: unit, address: parameter.address, range: range, lane: lane)
        }
    }

    /// This snapshot without lanes whose slot is outside `0..<capacity` and without return
    /// buses beyond `returnCapacity` (and the sends into them).
    func limited(toSlots capacity: Int, returnCapacity: Int = .max) -> EngineSnapshot {
        var copy = self
        copy.lanes.removeAll { $0.slot < 0 || $0.slot >= capacity }
        for index in copy.audioLanes.indices where copy.audioLanes[index].slot >= capacity {
            copy.audioLanes[index].slot = -1
        }
        copy.returns.removeAll { $0.bus < 0 || $0.bus >= returnCapacity }
        return copy
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

    /// Frees the slots of tracks that are gone and assigns free slots to new tracks in track
    /// order — instrument tracks first, then audio tracks, whose slot holds only their session
    /// clip. An instrument needs its slot to sound at all, an audio track only to launch clips,
    /// so an instrument without a slot takes one from the last audio track holding one; the
    /// capacity matches the instrument limit, so every instrument a song may have plays,
    /// whatever order the tracks were made in. An audio track left without a slot still plays
    /// its regions.
    public mutating func update(for project: Project) {
        let instruments = project.tracks.filter { $0.kind == .instrument }.map(\.id)
        let audio = project.tracks.filter { $0.kind == .audio }.map(\.id)
        let alive = Set(instruments + audio)
        slots = slots.filter { alive.contains($0.key) }
        var used = Set(slots.values)
        for id in instruments where slots[id] == nil {
            if let free = (0..<capacity).first(where: { !used.contains($0) }) {
                slots[id] = free
                used.insert(free)
            } else if let donor = audio.last(where: { slots[$0] != nil }), let slot = slots[donor] {
                slots[donor] = nil
                slots[id] = slot
            } else {
                break
            }
        }
        for id in audio where slots[id] == nil {
            guard let free = (0..<capacity).first(where: { !used.contains($0) }) else { break }
            slots[id] = free
            used.insert(free)
        }
    }
}

/// Numbers each instrument track's compiled events, raising a track's number only when its
/// notes or clips differ from the last plan. Main thread only.
public struct EventRevisions: Sendable {
    private var last: [TrackID: PlaybackPlan.TrackEvents] = [:]
    private var numbers: [TrackID: UInt64] = [:]
    private var counter: UInt64 = 0

    public init() {}

    public mutating func update(for plan: PlaybackPlan) -> [TrackID: UInt64] {
        var alive: [TrackID: PlaybackPlan.TrackEvents] = [:]
        for track in plan.tracks {
            alive[track.track] = track
            if last[track.track] != track || numbers[track.track] == nil {
                counter += 1
                numbers[track.track] = counter
            }
        }
        last = alive
        numbers = numbers.filter { alive[$0.key] != nil }
        return numbers
    }
}

/// Gains that move over song time. Pure and render-safe.
public protocol GainCurve: Sendable {
    /// The gains at a fractional tick.
    func gains(at position: Double) -> (Float, Float)
}
