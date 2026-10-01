//
//  MIDIFileImporter.swift
//  Echoelmusic — Sequencer
//
//  Reads a Standard MIDI File (Type 0 or 1) into melodic `Note`s for the piano
//  roll — the inverse of MIDIFileExporter, completing the "bring your DAW MIDI
//  into Echoel" loop. Pure value logic (Foundation only) so it is unit-testable
//  in CI (round-trips against the exporter).
//
//  Note timing is mapped from the file's own PPQ division onto `Note.ticksPerQuarter`
//  (480), so an imported clip sits sample-tight on Echoel's grid regardless of the
//  source resolution. Note-on (status 0x9n, velocity > 0) opens a note; the matching
//  note-off (0x8n, or 0x9n velocity 0) on the same channel+pitch closes it. Running
//  status, meta and SysEx events are handled/skipped. Percussion channel 10 is
//  excluded by default (those are drum hits, not melody).
//
//  ⚠️ WHAT IT READS PAST (B6b-0, 2026-10-01). Pitch bend, pressure (channel and polyphonic) and
//  controller changes are SKIPPED, not kept: no field of `Note` or `Clip` holds a controller
//  value over time, and no player would send one. `NoteMPE` is NOT that field — it is one
//  value per note, read only by the piano roll's MIDI-out merge, on an MPE bend range of ±48
//  semitones; a file's bend (usually ±2) written there would replay 24× too wide. So
//  `parse(from:)` COUNTS what it skips, per channel, and the import SAYS it. Only MOVEMENT is
//  counted, never set-up, because almost every exported file opens with set-up messages and a
//  sentence that fires on every file is a blanket disclaimer: a bend at centre, a pressure of 0,
//  a controller's FIRST value (volume, pan, effect sends), bank select, data entry and RPN/NRPN
//  (CC 0, 6, 32, 38, 96…101), and channel mode (CC 120…127) are not counted. Program changes are
//  skipped, not counted. A starting volume or pan is therefore read past AND unsaid — recorded here.
//
//  ⭐ THE SUSTAIN PEDAL IS APPLIED, NOT READ PAST (B6b-1, 2026-10-01). CC 64 is the one controller
//  a listener hears as a wrong note LENGTH, and it needs no new field: it folds into `lengthTicks`,
//  the way a DAW's "apply sustain" does. After the walk, a note RELEASED while its channel's pedal
//  is down (value 64 or above; the state at the release tick includes pedal events AT that tick)
//  ends at that channel's first pedal-up AT OR AFTER the release, or at the next note-on of the
//  SAME pitch on that channel if that comes first. A pedal-up AT the release tick lets the note go
//  there even when a press follows it on that tick — a pedal CHANGE, which notation exports write
//  at every chord change; reading only the last event of that tick would ring the old chord into
//  the new one. The re-strike law: two same-pitch notes cannot overlap on one channel,
//  and the roll's `noteOff(pitch:)` releases every voice of a pitch. A pedal never lifted ends the
//  note at the channel's last note-off or pedal event, so the pedal never reaches past a tick the
//  channel itself wrote (never to a distant End of Track). A length only ever GROWS, so a file
//  without a pedal reads exactly as before. The fold runs AFTER the walk because a Type-1 file may
//  keep its pedal on another TRACK than its notes, and tracks are walked one after another, not
//  merged in time; the lookups are binary searches, so a 2 MB file stays O(n log n) on the main
//  actor. `sustained` counts, per channel, the notes whose `Note` length the fold made longer —
//  measured after the PPQ map, so a one-tick growth that rounds away is not counted.
//
//  ⚠️ PAIRING, MEASURED (B6b-1) and unchanged by the fold: a note-off is 0x8n, or 0x9n at velocity
//  0, running status included, matched on channel + pitch. A second note-on of a pitch that is
//  still OPEN replaces the first, so the first note is LOST — unsaid today, recorded here.
//
//  ⚠️ HARDENED FOR ARBITRARY FILES (S2, 2026-09-23), because the Workstation's "Import MIDI"
//  hands this parser whatever a user picks. Three shapes of a malformed file used to hang the
//  main actor or trap: a variable-length quantity with more than four bytes wrapped `<<` into a
//  NEGATIVE length and walked the read index backwards (endless loop); a running `absTick`
//  could overflow on `+=`; and `fileTick * 480` could overflow in `mapTicks`. Now a VLQ is at
//  most FOUR bytes (the SMF maximum, 0x0FFF_FFFF — never negative), and the running tick is
//  clamped to `maxFileTick`, so every product stays far inside `Int`. Every loop pass consumes
//  at least one byte, so a track always terminates. Meta and SysEx events no longer latch
//  running status (the SMF rule), so a stray data byte after one cannot become a phantom meta.
//

import Foundation

public enum MIDIFileImporter {

    /// The running tick's ceiling: 2^40 file ticks. A four-byte delta adds at most 2^28, and
    /// `mapTicks` multiplies by `Note.ticksPerQuarter` (480 < 2^9), so nothing reaches 2^50.
    static let maxFileTick = 1 << 40

    public enum ImportError: Error, Sendable, Equatable {
        case notAMIDIFile
        case truncated
        case unsupportedDivision   // SMPTE timecode division (negative) — not supported
    }

    /// Parse SMF `data` into melodic notes. `includeChannel10` keeps GM percussion
    /// (usually unwanted for the melodic roll). Notes come back sorted by start.
    public static func notes(from data: [UInt8], includeChannel10: Bool = false) throws -> [Note] {
        try channelNotes(from: data)
            .filter { includeChannel10 || $0.channel != 9 }    // ch10 == index 9
            .map(\.note)
            .sorted { $0.startTick != $1.startTick ? $0.startTick < $1.startTick : $0.pitch < $1.pitch }
    }

    /// Parse SMF `data` into (channel, note) pairs — the shared parse used by both
    /// the melodic `notes(...)` and the drum-grid extraction. Channel is the 0-based
    /// MIDI channel (9 == GM percussion / "channel 10").
    public static func channelNotes(from data: [UInt8]) throws -> [(channel: Int, note: Note)] {
        try parse(from: data).notes
    }

    /// The channel messages one parse read past without keeping (B6b-0), counted so the import
    /// can SAY what it left out. Nothing here is stored in a part, and nothing plays it. The
    /// sustain pedal is NOT here: since B6b-1 it is applied to note lengths (`parse`'s `sustained`).
    public struct DroppedExpression: Sendable, Equatable {
        /// Pitch-bend messages (0xEn) away from centre (0x2000).
        public var pitchBends = 0
        /// Pressure messages above 0: channel (0xDn) and polyphonic (0xAn) aftertouch.
        public var pressures = 0
        /// Controller CHANGES: a value that differs from the same controller's earlier value on
        /// the same channel. CC 1…119 except 6, 32, 38 and 96…101 (set-up, not movement) and 64
        /// (the sustain pedal, applied to note lengths since B6b-1).
        public var controllers = 0

        public init() {}

        /// True when the file moved pitch bend, pressure, or a controller other than the pedal.
        public var hasBendPressureOrControllers: Bool {
            pitchBends > 0 || pressures > 0 || controllers > 0
        }

        /// Add `other`'s counts to these — how the import sums the channels with notes in the part.
        public mutating func add(_ other: DroppedExpression) {
            pitchBends += other.pitchBends
            pressures += other.pressures
            controllers += other.controllers
        }
    }

    /// The ONE walk over a file: its (channel, note) pairs with the sustain pedal folded into
    /// their lengths (B6b-1, see the header), what it read past, and how many notes the pedal
    /// lengthened — the last two indexed by the 0-based channel (always 16 entries).
    /// `channelNotes(from:)` is this without the counts.
    public static func parse(from data: [UInt8]) throws
        -> (notes: [(channel: Int, note: Note)], dropped: [DroppedExpression], sustained: [Int]) {
        var p = 0
        func need(_ n: Int) throws { if p + n > data.count { throw ImportError.truncated } }
        func u16(_ i: Int) -> Int { (Int(data[i]) << 8) | Int(data[i + 1]) }
        func u32(_ i: Int) -> Int {
            (Int(data[i]) << 24) | (Int(data[i + 1]) << 16) | (Int(data[i + 2]) << 8) | Int(data[i + 3])
        }

        // Header: "MThd" len=6 format ntracks division.
        try need(14)
        guard data[0] == 0x4D, data[1] == 0x54, data[2] == 0x68, data[3] == 0x64 else {
            throw ImportError.notAMIDIFile
        }
        let division = u16(12)
        guard division & 0x8000 == 0, division > 0 else { throw ImportError.unsupportedDivision }
        let filePPQ = division
        p = 8 + u32(4)   // skip to first chunk after the header body

        struct Open { var startTick: Int; var velocity: Float }
        /// A paired note in FILE ticks — mapped onto `Note.ticksPerQuarter` only after the fold.
        struct Closed { var channel: Int; var pitch: Int; var startTick: Int; var endTick: Int; var velocity: Float }
        var open: [Int: Open] = [:]        // key = channel*128 + pitch
        var closed: [Closed] = []
        var dropped = [DroppedExpression](repeating: DroppedExpression(), count: 16)
        var lastController = [Int](repeating: -1, count: 16 * 128)   // channel*128 + number
        var pedals = [[(tick: Int, down: Bool)]](repeating: [], count: 16)   // CC 64, walk order
        var strikes: [Int: [Int]] = [:]    // key = channel*128 + pitch → every note-on tick

        @inline(__always) func mapTicks(_ fileTick: Int) -> Int {
            // Scale the file's PPQ to Note.ticksPerQuarter (round to nearest).
            (fileTick * Note.ticksPerQuarter + filePPQ / 2) / filePPQ
        }

        while p + 8 <= data.count {
            let isTrack = data[p] == 0x4D && data[p+1] == 0x54 && data[p+2] == 0x72 && data[p+3] == 0x6B
            let len = u32(p + 4)
            let bodyStart = p + 8
            let bodyEnd = min(data.count, bodyStart + len)
            p = bodyEnd
            guard isTrack else { continue }   // skip unknown chunks

            var i = bodyStart
            var absTick = 0
            var running: UInt8 = 0

            // At most FOUR bytes (SMF), so the value is 0…0x0FFF_FFFF and never negative.
            func readVLQ() -> Int {
                var value = 0
                for _ in 0..<4 {
                    guard i < bodyEnd else { break }
                    let b = data[i]; i += 1
                    value = (value << 7) | Int(b & 0x7F)
                    if b & 0x80 == 0 { break }
                }
                return value
            }

            while i < bodyEnd {
                absTick = Swift.min(absTick + readVLQ(), Self.maxFileTick)
                guard i < bodyEnd else { break }
                var status = data[i]
                if status & 0x80 != 0 { i += 1 } else { status = running }   // running status
                // Only channel messages latch running status; meta/SysEx cancel it (SMF).
                if status >= 0x80, status < 0xF0 { running = status } else if status >= 0xF0 { running = 0 }

                let hi = status & 0xF0
                let chan = Int(status & 0x0F)

                switch hi {
                case 0x80, 0x90:                      // note off / note on
                    guard i + 1 < bodyEnd else { i = bodyEnd; break }
                    let pitch = Int(data[i]); let vel = Int(data[i + 1]); i += 2
                    let key = chan * 128 + pitch
                    let isOn = (hi == 0x90 && vel > 0)
                    if isOn {
                        open[key] = Open(startTick: absTick, velocity: Float(vel) / 127.0)
                        strikes[key, default: []].append(absTick)
                    } else if let o = open.removeValue(forKey: key) {
                        closed.append(Closed(channel: chan, pitch: pitch, startTick: o.startTick,
                                             endTick: absTick, velocity: o.velocity))
                    }
                case 0xA0:                             // polyphonic pressure — counted, not kept
                    if i + 1 < bodyEnd, data[i + 1] & 0x7F > 0 { dropped[chan].pressures += 1 }
                    i += 2
                case 0xB0:                             // controller — counted, not kept
                    if i + 1 < bodyEnd {
                        // Masked: a malformed data byte must not index past the table.
                        let number = Int(data[i] & 0x7F), value = Int(data[i + 1] & 0x7F)
                        switch number {
                        case 64:                       // the pedal — applied after the walk (B6b-1)
                            pedals[chan].append((tick: absTick, down: value >= 64))
                        case 0, 6, 32, 38, 96...101, 120...127:
                            break                      // set-up and channel mode, not movement
                        default:
                            let slot = chan * 128 + number
                            if lastController[slot] >= 0, lastController[slot] != value {
                                dropped[chan].controllers += 1
                            }
                            lastController[slot] = value
                        }
                    }
                    i += 2
                case 0xE0:                             // pitch bend — counted, not kept
                    if i + 1 < bodyEnd {
                        let lsb = Int(data[i] & 0x7F), msb = Int(data[i + 1] & 0x7F)
                        if (msb << 7) + lsb != 0x2000 { dropped[chan].pitchBends += 1 }   // centre is set-up
                    }
                    i += 2
                case 0xC0:                             // program change — skipped, not counted
                    i += 1
                case 0xD0:                             // channel pressure — counted, not kept
                    if i < bodyEnd, data[i] & 0x7F > 0 { dropped[chan].pressures += 1 }
                    i += 1
                case 0xF0:                             // meta / sysex
                    if status == 0xFF {                // meta: type + VLQ len + bytes
                        guard i < bodyEnd else { break }
                        i += 1                         // meta type
                        let mlen = readVLQ()
                        i = min(bodyEnd, i + mlen)
                    } else {                           // sysex: VLQ len + bytes
                        let slen = readVLQ()
                        i = min(bodyEnd, i + slen)
                    }
                default:
                    i = bodyEnd                          // unknown — bail this track
                }
            }
        }

        // B6b-1 — the pedal folded into note LENGTHS (the header gives the law and why it runs
        // here). Per channel: pedal events in tick order (ties keep the walk order — Swift's sort
        // is not stable, so the offset rides along), the lift ticks alone, and the channel's last
        // note-off or pedal event, which is where a pedal never lifted lets go.
        var channelEnd = [Int](repeating: 0, count: 16)
        for c in closed { channelEnd[c.channel] = Swift.max(channelEnd[c.channel], c.endTick) }
        var pedalTicks = [[Int]](repeating: [], count: 16)
        var pedalDown = [[Bool]](repeating: [], count: 16)
        var liftTicks = [[Int]](repeating: [], count: 16)
        for channel in 0..<16 where !pedals[channel].isEmpty {
            let ordered = pedals[channel].enumerated()
                .sorted { ($0.element.tick, $0.offset) < ($1.element.tick, $1.offset) }
                .map { $0.element }
            pedalTicks[channel] = ordered.map { $0.tick }
            pedalDown[channel] = ordered.map { $0.down }
            liftTicks[channel] = ordered.filter { !$0.down }.map { $0.tick }
            channelEnd[channel] = Swift.max(channelEnd[channel], pedalTicks[channel].last ?? 0)
        }
        let sortedStrikes = strikes.mapValues { $0.sorted() }
        var sustained = [Int](repeating: 0, count: 16)
        var out: [(channel: Int, note: Note)] = []
        out.reserveCapacity(closed.count)
        for c in closed {
            var endTick = c.endTick
            let seen = countAtOrBefore(c.endTick, in: pedalTicks[c.channel])
            if seen > 0, pedalDown[c.channel][seen - 1] {             // pedal down at the release
                // The first lift AT or after the release — a lift on the release tick lets the
                // note go there even when a press follows it on that tick (a pedal change).
                let lifts = liftTicks[c.channel]
                let nextLift = countBefore(c.endTick, in: lifts)
                var held = nextLift < lifts.count ? lifts[nextLift] : channelEnd[c.channel]
                // Re-strike: the first note-on of this pitch at or after the release — never the
                // note's own (a zero-length note starts AT its release).
                let restrikes = sortedStrikes[c.channel * 128 + c.pitch] ?? []
                let next = countBefore(Swift.max(c.startTick + 1, c.endTick), in: restrikes)
                if next < restrikes.count { held = Swift.min(held, restrikes[next]) }
                endTick = Swift.max(endTick, held)
            }
            let startT = mapTicks(c.startTick)
            let lenT = max(1, mapTicks(endTick) - startT)
            if lenT > max(1, mapTicks(c.endTick) - startT) { sustained[c.channel] += 1 }
            out.append((channel: c.channel,
                        note: Note(pitch: c.pitch, startTick: startT,
                                   lengthTicks: lenT, velocity: c.velocity)))
        }

        return (notes: out, dropped: dropped, sustained: sustained)
    }

    /// How many of the ascending `ticks` are at or before `tick` — also the index of the first
    /// one after it (B6b-1). A binary search, so the pedal fold stays O(n log n).
    private static func countAtOrBefore(_ tick: Int, in ticks: [Int]) -> Int {
        var low = 0
        var high = ticks.count
        while low < high {
            let mid = low + (high - low) / 2
            if ticks[mid] <= tick { low = mid + 1 } else { high = mid }
        }
        return low
    }

    /// How many of the ascending `ticks` are before `tick` — the index of the first one at or
    /// after it (B6b-1): the next lift, and the next re-strike.
    private static func countBefore(_ tick: Int, in ticks: [Int]) -> Int {
        var low = 0
        var high = ticks.count
        while low < high {
            let mid = low + (high - low) / 2
            if ticks[mid] < tick { low = mid + 1 } else { high = mid }
        }
        return low
    }

    public static func notes(from data: Data, includeChannel10: Bool = false) throws -> [Note] {
        try notes(from: [UInt8](data), includeChannel10: includeChannel10)
    }

    // MARK: - Drum grid (GM channel 10 → BeatPlayer's 8-track / 16-step grid)

    /// Echoel drum-track index for a General-MIDI percussion note, or nil if it has
    /// no slot (it folds into "Perc"). Tracks: 0 Kick · 1 Snare · 2 ClosedHat ·
    /// 3 OpenHat · 4 Clap · 5 Perc · (6 Bass / 7 LeadFX are not GM drums).
    public static func drumTrack(forGM note: Int) -> Int {
        switch note {
        case 35, 36:            return 0   // bass drums → Kick
        case 38, 40, 37:        return 1   // snares + side stick → Snare
        case 42, 44:            return 2   // closed / pedal hat → ClosedHat
        case 46:                return 3   // open hat → OpenHat
        case 39:                return 4   // hand clap → Clap
        default:                return 5   // toms / cymbals / aux perc → Perc
        }
    }

    /// Build BeatPlayer's (steps, accents) grid from a SMF's channel-10 notes,
    /// folded onto the first 16-step bar. `trackCount`/`stepCount` size the grid.
    /// Accents mark hard hits (velocity ≥ 0.85). Empty (no ch10 hits) → all-false.
    public static func drumGrid(from data: [UInt8], trackCount: Int = 8, stepCount: Int = 16)
        throws -> (steps: [[Bool]], accents: [[Bool]]) {
        var steps = [[Bool]](repeating: [Bool](repeating: false, count: stepCount), count: trackCount)
        var accents = [[Bool]](repeating: [Bool](repeating: false, count: stepCount), count: trackCount)
        for (channel, note) in try channelNotes(from: data) where channel == 9 {
            let step = note.startStep
            guard step >= 0, step < stepCount else { continue }   // first bar only
            let track = drumTrack(forGM: note.pitch)
            guard track >= 0, track < trackCount else { continue }
            steps[track][step] = true
            if note.velocity >= 0.85 { accents[track][step] = true }
        }
        return (steps, accents)
    }

    public static func drumGrid(from data: Data, trackCount: Int = 8, stepCount: Int = 16)
        throws -> (steps: [[Bool]], accents: [[Bool]]) {
        try drumGrid(from: [UInt8](data), trackCount: trackCount, stepCount: stepCount)
    }
}
