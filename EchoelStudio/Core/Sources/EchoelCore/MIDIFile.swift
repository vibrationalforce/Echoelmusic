import Foundation

/// A song as a Standard MIDI File (format 1), for any other DAW or notation program: a first
/// track with the song name, its tempo map and time signature, then one track per instrument
/// track with what the arrangement plays — the same notes the engine plays, overlaps resolved
/// the same way. Muted tracks are written too, as every DAW does; the receiver decides.
public enum MIDIFile {
    /// Ticks per quarter note in the file: the document's own resolution, so nothing is rounded.
    public static let division = UInt16(MusicalTime.ticksPerQuarter)

    public static func data(for project: Project) -> Data {
        let instrumentTracks = project.tracks.filter { $0.kind == .instrument }
        var out = Data()
        out.append(contentsOf: Array("MThd".utf8))
        append32(6, to: &out)
        append16(1, to: &out)
        append16(UInt16(Swift.min(instrumentTracks.count + 1, Int(UInt16.max))), to: &out)
        append16(division, to: &out)
        chunk(conductor(project), to: &out)
        var melodic = 0
        for track in instrumentTracks.prefix(Int(UInt16.max) - 1) {
            // General MIDI: drums play on channel 10; the others take 1–16 in turn around it.
            let channel: UInt8
            if track.instrument.device == .drums {
                channel = 9
            } else {
                let next = melodic % 15
                channel = UInt8(next < 9 ? next : next + 1)
                melodic += 1
            }
            chunk(events(of: track, channel: channel), to: &out)
        }
        return out
    }

    /// One timed event before it is written: its tick and its bytes after the delta time.
    struct Event {
        let tick: Tick
        let bytes: [UInt8]
    }

    static func conductor(_ project: Project) -> [Event] {
        var events = [Event(tick: 0, bytes: meta(0x03, Array(project.name.utf8)))]
        let signature = project.timeSignature
        let power = UInt8(Swift.max(0, Int(Foundation.log2(Double(Swift.max(1, signature.denominator))).rounded())))
        events.append(Event(tick: 0, bytes: meta(0x58, [UInt8(clamping: signature.numerator), power, 24, 8])))
        for segment in project.tempoMap.segments {
            let micros = UInt32(Swift.min(Swift.max((60_000_000 / segment.bpm).rounded(), 1), 0xFF_FFFF))
            events.append(Event(tick: segment.startTick,
                                bytes: meta(0x51, [UInt8(micros >> 16 & 0xFF), UInt8(micros >> 8 & 0xFF), UInt8(micros & 0xFF)])))
        }
        return events
    }

    static func events(of track: Track, channel: UInt8) -> [Event] {
        var events = [Event(tick: 0, bytes: meta(0x03, Array(track.name.utf8)))]
        for event in PlaybackPlan.events(from: PlaybackPlan.noteIntervals(of: track)) {
            let pitch = event.pitch & 0x7F
            switch event.kind {
            case .noteOn(let velocity):
                events.append(Event(tick: event.tick, bytes: [0x90 | channel, pitch, Swift.max(1, velocity & 0x7F)]))
            case .noteOff:
                events.append(Event(tick: event.tick, bytes: [0x80 | channel, pitch, 0x40]))
            }
        }
        return events
    }

    /// Writes `events` as one MTrk chunk in tick order (stable, so a meta event stays before a
    /// note at the same tick), closed with End of Track.
    static func chunk(_ events: [Event], to out: inout Data) {
        let ordered = events.enumerated().sorted {
            $0.element.tick != $1.element.tick ? $0.element.tick < $1.element.tick : $0.offset < $1.offset
        }
        var body: [UInt8] = []
        var last: Tick = 0
        for (_, event) in ordered {
            let tick = Swift.max(event.tick, last)
            body += variableLength(UInt32(clamping: tick - last))
            body += event.bytes
            last = tick
        }
        body += [0x00, 0xFF, 0x2F, 0x00]
        out.append(contentsOf: Array("MTrk".utf8))
        append32(UInt32(clamping: body.count), to: &out)
        out.append(contentsOf: body)
    }

    static func meta(_ type: UInt8, _ payload: [UInt8]) -> [UInt8] {
        [0xFF, type] + variableLength(UInt32(clamping: payload.count)) + payload
    }

    /// A MIDI variable-length quantity: seven bits per byte, most significant first, every byte
    /// but the last with its top bit set. The format holds at most 28 bits.
    static func variableLength(_ value: UInt32) -> [UInt8] {
        var value = Swift.min(value, 0x0FFF_FFFF)
        var bytes = [UInt8(value & 0x7F)]
        value >>= 7
        while value > 0 {
            bytes.insert(UInt8(value & 0x7F) | 0x80, at: 0)
            value >>= 7
        }
        return bytes
    }

    private static func append32(_ value: UInt32, to out: inout Data) {
        out.append(contentsOf: [UInt8(value >> 24 & 0xFF), UInt8(value >> 16 & 0xFF), UInt8(value >> 8 & 0xFF), UInt8(value & 0xFF)])
    }

    private static func append16(_ value: UInt16, to out: inout Data) {
        out.append(contentsOf: [UInt8(value >> 8), UInt8(value & 0xFF)])
    }
}
