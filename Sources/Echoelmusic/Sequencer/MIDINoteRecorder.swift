// MIDINoteRecorder.swift
// Per-track MIDI record (B20) — the PURE half: turn timestamped note-on/off events
// into Notes for a recorded MelodyClip.
//
// The device TakeRecorder carries each CoreMIDI packet's `timeStamp` (mach host
// time), converts it host→sample→song-tick via `RecordAnchor`, and feeds this
// recorder `noteOn`/`noteOff` at absolute ticks. This core keeps the open-note map
// and emits `Note`s whose ticks are RELATIVE to the anchor (clip-local, 0 = record
// start) — exactly how a MelodyClip stores its notes. Unquantized (sub-step precise);
// the caller may quantize afterwards. Pure value logic — no CoreMIDI, no engine — so
// the open/close/re-trigger contract is unit-tested on every platform.

import Foundation

/// Accumulates note-on/off events into completed `Note`s (clip-relative ticks).
public struct MIDINoteRecorder: Sendable {

    /// Song-absolute tick where recording started; note-ons before it are ignored,
    /// and completed notes are stored relative to it (0 = the take's first tick).
    public let anchorTick: Int
    /// Role stamped on every recorded note (the lane's voice role).
    public let role: NoteRole
    /// Minimum note length so a note-off at (or before) its note-on still sounds.
    public let minLengthTicks: Int

    private struct OpenNote { let startTick: Int; let velocity: Float }
    /// An open note is named by its CHANNEL and its pitch (Ultraplan-MPE1, 2026-10-16): an MPE
    /// controller plays each note on its own member channel, so two notes of one pitch can be
    /// held at once. Keyed by pitch alone, the second note-on closed the first as a re-trigger
    /// and the first note-off then closed the second — one short note where two were played.
    private struct Key: Hashable, Comparable {
        let channel: Int, pitch: Int
        static func < (a: Key, b: Key) -> Bool { (a.pitch, a.channel) < (b.pitch, b.channel) }
    }
    private var open: [Key: OpenNote] = [:]
    private var completed: [Note] = []

    public init(anchorTick: Int = 0, role: NoteRole = .harmony, minLengthTicks: Int = 1) {
        self.anchorTick = max(0, anchorTick)
        self.role = role
        self.minLengthTicks = max(1, minLengthTicks)
    }

    /// Notes still held down (awaiting a note-off).
    public var openCount: Int { open.count }
    /// Notes closed so far.
    public var noteCount: Int { completed.count }

    /// A note-on at a song-absolute tick. `velocity` is normalized [0..1]; a velocity
    /// `<= 0` is treated as a note-OFF (MIDI running-status convention). Ignored before
    /// the anchor. Re-triggering a pitch already open ON THE SAME CHANNEL closes the previous
    /// note first; the same pitch on another channel is a second note. `channel` defaults to 0,
    /// so a single-channel caller keeps the old behaviour exactly.
    public mutating func noteOn(pitch: Int, velocity: Float, atTick tick: Int, channel: Int = 0) {
        let key = Key(channel: channel, pitch: pitch)
        guard velocity > 0 else { closeNote(key, atTick: tick); return }
        guard tick >= anchorTick else { return }
        if open[key] != nil { closeNote(key, atTick: tick) }   // re-trigger
        open[key] = OpenNote(startTick: tick, velocity: velocity)
    }

    /// A note-off at a song-absolute tick. Closes the open note of that pitch ON THAT CHANNEL (if
    /// any); a note-off without a matching note-on is ignored.
    public mutating func noteOff(pitch: Int, atTick tick: Int, channel: Int = 0) {
        closeNote(Key(channel: channel, pitch: pitch), atTick: tick)
    }

    /// Close every still-open note at `tick` (end of the take). Deterministic order.
    public mutating func flushOpen(atTick tick: Int) {
        for key in open.keys.sorted() { closeNote(key, atTick: tick) }
    }

    /// Completed notes, sorted by start tick then pitch (deterministic).
    public func notes() -> [Note] {
        completed.sorted {
            $0.startTick != $1.startTick ? $0.startTick < $1.startTick : $0.pitch < $1.pitch
        }
    }

    /// Build a MelodyClip from the completed notes (still-open notes are NOT flushed —
    /// call `flushOpen(atTick:)` at record-stop first if you want them included).
    public func melody() -> MelodyClip { MelodyClip(notes: notes()) }

    private mutating func closeNote(_ key: Key, atTick tick: Int) {
        guard let on = open.removeValue(forKey: key) else { return }
        let pitch = key.pitch
        let relStart = max(0, on.startTick - anchorTick)
        let length = max(minLengthTicks, tick - on.startTick)
        completed.append(Note(pitch: pitch, startTick: relStart, lengthTicks: length,
                              velocity: on.velocity, role: role))
    }
}
