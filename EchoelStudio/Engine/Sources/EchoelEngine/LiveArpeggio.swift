import EchoelCore

/// A track's arpeggiator as the render thread reads it: plain values only, so copying one never
/// retains or frees anything (`Arpeggio` stores its names as strings). Compiled on the main thread
/// into each snapshot lane; nil while the track's arpeggiator is off.
public struct ArpSettings: Equatable, Sendable {
    public let step: Tick
    public let order: ArpOrder
    public let octaves: Int
    public let gate: Double
    public let latch: Bool
    public let seed: UInt32

    public init(_ arpeggio: Arpeggio) {
        step = Swift.max(arpeggio.stepTicks, 1)
        order = arpeggio.order
        octaves = Swift.min(Swift.max(arpeggio.octaves, Arpeggio.octaveRange.lowerBound), Arpeggio.octaveRange.upperBound)
        gate = arpeggio.gate.isFinite ? Swift.min(Swift.max(arpeggio.gate, Arpeggio.gateRange.lowerBound), 1) : 0.5
        latch = arpeggio.latch
        seed = UInt32(clamping: arpeggio.seed)
    }
}

/// The keys played live into each slot whose track arpeggiates, and where each slot's phrase
/// stands. Everything is allocated in `init`; every method is arithmetic on that storage, so the
/// render thread calls them freely. Times are ticks of the clock the engine schedules on: the
/// song's while it plays, a free-running one at the song's tempo while it is stopped.
final class LiveArpeggiators {
    /// Keys one slot holds at most; a key past them is not taken up.
    static let capacity = 16

    struct Slot {
        var settings: ArpSettings?
        var count = 0
        /// Keys physically down, as 128 bits — with latch the held list outlives them.
        var downLow: UInt64 = 0
        var downHigh: UInt64 = 0
        var step = 0
        /// The next step's start, or nil while no phrase runs.
        var next: Tick?
        /// A phrase starts or must find the grid again in the clock the next chunk runs on.
        var needsAnchor = false
        var sounding = -1
        var off: Tick = 0
    }

    private let slots: UnsafeMutablePointer<Slot>
    private let pitches: UnsafeMutablePointer<UInt8>
    private let velocities: UnsafeMutablePointer<UInt8>
    let count: Int

    init(slots count: Int) {
        self.count = Swift.max(count, 1)
        slots = .allocate(capacity: self.count)
        slots.initialize(repeating: Slot(), count: self.count)
        pitches = .allocate(capacity: self.count * Self.capacity)
        pitches.initialize(repeating: 0, count: self.count * Self.capacity)
        velocities = .allocate(capacity: self.count * Self.capacity)
        velocities.initialize(repeating: 0, count: self.count * Self.capacity)
    }

    deinit {
        slots.deinitialize(count: count)
        slots.deallocate()
        pitches.deallocate()
        velocities.deallocate()
    }

    subscript(slot: Int) -> Slot {
        get { slots[slot] }
        set { slots[slot] = newValue }
    }

    func isOn(_ slot: Int) -> Bool { slot >= 0 && slot < count && slots[slot].settings != nil }

    /// New settings for a slot. Returns the pitch that must stop sounding now, or −1: a slot
    /// switched off lets go of its keys.
    func configure(_ slot: Int, _ settings: ArpSettings?) -> Int {
        guard slot >= 0, slot < count, slots[slot].settings != settings else { return -1 }
        var state = slots[slot]
        state.settings = settings
        var stop = -1
        if settings == nil {
            stop = state.sounding
            state = Slot()
        } else if !state.latch, state.count > 0 {
            // A latch switched off lets go of keys no longer down.
            keepOnlyDown(slot, &state)
        }
        slots[slot] = state
        return stop
    }

    /// A key down. Starts a phrase when none runs; with latch, a key on released keys starts a new chord.
    func press(_ slot: Int, pitch: UInt8, velocity: UInt8) {
        guard isOn(slot) else { return }
        var state = slots[slot]
        let latch = state.settings?.latch ?? false
        if latch, state.downLow == 0, state.downHigh == 0 { state.count = 0 }
        setDown(&state, pitch, true)
        let base = slot * Self.capacity
        var present = false
        for i in 0..<state.count where pitches[base + i] == pitch {
            present = true
            velocities[base + i] = velocity
        }
        if !present, state.count < Self.capacity {
            pitches[base + state.count] = pitch
            velocities[base + state.count] = velocity
            state.count += 1
        }
        if state.next == nil, state.count > 0 {
            state.step = 0
            state.needsAnchor = true
        }
        slots[slot] = state
    }

    /// A key up. Without latch the key leaves the phrase; the last key ends it (the sounding step
    /// keeps its gate).
    func release(_ slot: Int, pitch: UInt8) {
        guard isOn(slot) else { return }
        var state = slots[slot]
        setDown(&state, pitch, false)
        if !state.latch {
            remove(slot, &state, pitch)
            if state.count == 0 {
                state.next = nil
                state.needsAnchor = false
            }
        }
        slots[slot] = state
    }

    /// All notes off: the keys and the phrase go; returns the pitch to stop, or −1.
    func clear(_ slot: Int) -> Int {
        guard slot >= 0, slot < count else { return -1 }
        let stop = slots[slot].sounding
        let settings = slots[slot].settings
        slots[slot] = Slot()
        slots[slot].settings = settings
        return stop
    }

    /// The step's note: one held key, by pitch or as pressed, raised by its octave.
    func pick(_ slot: Int) -> (pitch: UInt8, velocity: UInt8)? {
        let state = slots[slot]
        guard let settings = state.settings, state.count > 0 else { return nil }
        let choice = ArpPattern.pick(step: state.step, count: state.count, octaves: settings.octaves,
                                     order: settings.order, seed: settings.seed)
        let base = slot * Self.capacity
        var at = choice.index
        if !settings.order.usesPlayedOrder {
            // The key of that rank among the held ones; they are distinct, so ranks are too.
            for i in 0..<state.count {
                var below = 0
                for j in 0..<state.count where pitches[base + j] < pitches[base + i] { below += 1 }
                if below == choice.index {
                    at = i
                    break
                }
            }
        }
        let pitch = ArpPattern.pitch(Int(pitches[base + at]), octave: choice.octave)
        return (UInt8(pitch), velocities[base + at])
    }

    /// Every running phrase finds the grid again in the next chunk's clock (a start, a stop, a seek).
    func reanchorAll() {
        for slot in 0..<count where slots[slot].next != nil || slots[slot].needsAnchor {
            slots[slot].next = nil
            slots[slot].needsAnchor = slots[slot].count > 0
        }
    }

    private func setDown(_ state: inout Slot, _ pitch: UInt8, _ down: Bool) {
        let bit: UInt64 = 1 << UInt64(pitch & 63)
        if pitch < 64 {
            state.downLow = down ? state.downLow | bit : state.downLow & ~bit
        } else {
            state.downHigh = down ? state.downHigh | bit : state.downHigh & ~bit
        }
    }

    private func isDown(_ state: Slot, _ pitch: UInt8) -> Bool {
        let bit: UInt64 = 1 << UInt64(pitch & 63)
        return pitch < 64 ? state.downLow & bit != 0 : state.downHigh & bit != 0
    }

    private func remove(_ slot: Int, _ state: inout Slot, _ pitch: UInt8) {
        let base = slot * Self.capacity
        var i = 0
        while i < state.count {
            if pitches[base + i] == pitch {
                for j in i..<(state.count - 1) {
                    pitches[base + j] = pitches[base + j + 1]
                    velocities[base + j] = velocities[base + j + 1]
                }
                state.count -= 1
            } else {
                i += 1
            }
        }
    }

    private func keepOnlyDown(_ slot: Int, _ state: inout Slot) {
        let base = slot * Self.capacity
        var i = 0
        while i < state.count {
            let pitch = pitches[base + i]
            if isDown(state, pitch) { i += 1 } else { remove(slot, &state, pitch) }
        }
        if state.count == 0 {
            state.next = nil
            state.needsAnchor = false
        }
    }
}

extension LiveArpeggiators.Slot {
    var latch: Bool { settings?.latch ?? false }
}
