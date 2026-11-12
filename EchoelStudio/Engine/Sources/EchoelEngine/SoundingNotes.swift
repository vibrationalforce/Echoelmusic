/// What sounds in each slot's instrument and who started it: the pitches a live key holds and the
/// pitches the sequencer started and has not ended. A seek, a jump or the loop's wrap while the
/// song plays on reads it to end only the sequencer's notes in a slot where a key is held live,
/// instead of sending all notes off there (`EngineCore.releaseNotesAfterMove`). Whenever that is
/// not provably enough, `keepsLiveNotes` is false and the slot is swept as before.
///
/// Render thread only. Everything is allocated in `init`; every method is bit arithmetic on that
/// storage, guarded by the slot's range, so the render thread calls them freely. No stored static.
final class SoundingNotes {
    struct Slot {
        /// Pitches a live note-on put into the instrument and no live note-off has ended.
        var liveLow: UInt64 = 0
        var liveHigh: UInt64 = 0
        /// Pitches the sequencer started and has not ended: what it still owes a note-off for.
        var owedLow: UInt64 = 0
        var owedHigh: UInt64 = 0
        /// The sequencer sent a controller or a bend since the slot was last swept: its pedal or
        /// wheel may be off rest, and only all notes off puts them back.
        var sequencerMoved = false
        /// The last live sustain pedal (controller 64) was down.
        var livePedal = false
        /// A sequenced note ended while the live pedal was down: the instrument still holds it,
        /// parked under the pedal, although it is no longer owed.
        var parkedUnderPedal = false
    }

    private let slots: UnsafeMutablePointer<Slot>
    let count: Int

    init(slots count: Int) {
        self.count = Swift.max(count, 1)
        slots = .allocate(capacity: self.count)
        slots.initialize(repeating: Slot(), count: self.count)
    }

    deinit {
        slots.deinitialize(count: count)
        slots.deallocate()
    }

    /// A live key reached the slot's instrument.
    func liveDown(_ slot: Int, _ pitch: UInt8) {
        guard slot >= 0, slot < count else { return }
        let words = Self.setting(slots[slot].liveLow, slots[slot].liveHigh, pitch, true)
        slots[slot].liveLow = words.low
        slots[slot].liveHigh = words.high
    }

    /// A live key let go (a note-off, or a note-on at velocity 0).
    func liveUp(_ slot: Int, _ pitch: UInt8) {
        guard slot >= 0, slot < count else { return }
        let words = Self.setting(slots[slot].liveLow, slots[slot].liveHigh, pitch, false)
        slots[slot].liveLow = words.low
        slots[slot].liveHigh = words.high
    }

    /// A live all notes off (123) or all sound off (120): no live key holds anything there.
    func liveCleared(_ slot: Int) {
        guard slot >= 0, slot < count else { return }
        slots[slot].liveLow = 0
        slots[slot].liveHigh = 0
    }

    /// The live sustain pedal went down or up. Up lets every parked note go, so nothing is parked.
    func setLivePedal(_ slot: Int, down: Bool) {
        guard slot >= 0, slot < count else { return }
        slots[slot].livePedal = down
        if !down { slots[slot].parkedUnderPedal = false }
    }

    /// The sequencer started a note in the slot.
    func sequencedOn(_ slot: Int, _ pitch: UInt8) {
        guard slot >= 0, slot < count else { return }
        let words = Self.setting(slots[slot].owedLow, slots[slot].owedHigh, pitch, true)
        slots[slot].owedLow = words.low
        slots[slot].owedHigh = words.high
    }

    /// The sequencer ended a note in the slot. Under the live pedal the instrument parks it.
    func sequencedOff(_ slot: Int, _ pitch: UInt8) {
        guard slot >= 0, slot < count else { return }
        let words = Self.setting(slots[slot].owedLow, slots[slot].owedHigh, pitch, false)
        slots[slot].owedLow = words.low
        slots[slot].owedHigh = words.high
        if slots[slot].livePedal { slots[slot].parkedUnderPedal = true }
    }

    /// The sequencer sent the slot a controller or a bend.
    func sequencerMovedControllers(_ slot: Int) {
        guard slot >= 0, slot < count else { return }
        slots[slot].sequencerMoved = true
    }

    /// All notes off reached the slot (or its devices were reset): nothing sounds there and
    /// nothing is owed.
    func swept(_ slot: Int) {
        guard slot >= 0, slot < count else { return }
        slots[slot] = Slot()
    }

    /// The pitches the sequencer still owes a note-off for, as two 64-bit words (0…63, 64…127).
    func owed(_ slot: Int) -> (low: UInt64, high: UInt64) {
        guard slot >= 0, slot < count else { return (0, 0) }
        return (slots[slot].owedLow, slots[slot].owedHigh)
    }

    /// Whether a move may end only the sequencer's notes here: a key is held live, the sequencer
    /// moved no controller since the last sweep, and the live pedal does not hold a sequenced note
    /// (one still sounding, or one that ended under it).
    func keepsLiveNotes(_ slot: Int) -> Bool {
        guard slot >= 0, slot < count else { return false }
        let state = slots[slot]
        let held = state.liveLow != 0 || state.liveHigh != 0
        let owes = state.owedLow != 0 || state.owedHigh != 0
        return held && !state.sequencerMoved && !(state.livePedal && (owes || state.parkedUnderPedal))
    }

    /// Two 64-bit words of pitches with `pitch` (masked to 0…127) set or cleared.
    private static func setting(_ low: UInt64, _ high: UInt64, _ pitch: UInt8,
                                _ on: Bool) -> (low: UInt64, high: UInt64) {
        let note = pitch & 0x7F
        let bit: UInt64 = 1 << UInt64(note & 63)
        if note < 64 { return (on ? low | bit : low & ~bit, high) }
        return (low, on ? high | bit : high & ~bit)
    }
}
