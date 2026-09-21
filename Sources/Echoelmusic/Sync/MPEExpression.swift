// MPEExpression.swift
// Echoel — body → ROLI-style "5D" MPE expression, as a PURE, unit-tested value type
// (no CoreMIDI, so it builds + tests everywhere). The body is the controller: the
// three CONTINUOUS MPE per-note dimensions are driven by bio —
//   • Slide (CC74, brightness)  ← coherence   (servo: coherent = clearer/brighter)
//   • Press (channel pressure)  ← breath depth (inhale swells the note)
//   • Glide (pitch bend)        ← HRV          (a small, living pitch drift)
// plus Strike (note-on velocity) and Lift (note-off velocity) carried by the note
// events themselves. This is the encoder/mapping core; wiring it into the CoreMIDI
// MPE output path (MIDIOutput) is a separate, iOS-gated slice.

import Foundation

public struct MPEExpression: Equatable, Sendable {
    /// Slide / timbre, MIDI CC74 value 0…127.
    public var slideCC74: UInt8
    /// Press / channel pressure (aftertouch) 0…127.
    public var pressure: UInt8
    /// Glide / per-note pitch bend, normalized −1…+1 (maps onto the MPE bend range).
    public var bend: Float

    public init(slideCC74: UInt8, pressure: UInt8, bend: Float) {
        self.slideCC74 = slideCC74
        self.pressure = pressure
        self.bend = Swift.max(-1, Swift.min(1, bend))
    }

    static func clamp01(_ x: Float) -> Float { Swift.min(1, Swift.max(0, x)) }
    private static func u7(_ x: Float) -> UInt8 { UInt8(Swift.max(0, Swift.min(127, (x * 127).rounded()))) }

    /// Map a bio snapshot to continuous 5D expression. HRV drives only a SMALL
    /// living drift: `bendCents` of audible bend within the synth's `bendRangeSemitones`
    /// (MPE default ±48), so the pitch stays musical, never a wild bend.
    public static func from(coherence: Float, breathDepth: Float, hrvNormalized: Float,
                            bendCents: Float = 50, bendRangeSemitones: Float = 48) -> MPEExpression {
        let slide = u7(clamp01(coherence))
        let press = u7(clamp01(breathDepth))
        let range = Swift.max(1, bendRangeSemitones)
        let drift = (clamp01(hrvNormalized) * 2 - 1) * (bendCents / 100) / range   // −1…1, tiny
        return MPEExpression(slideCC74: slide, pressure: press, bend: drift)
    }

    /// The ONE way a BODY becomes MPE expression — and the one place the App Store
    /// 5.1.3 source gate is asked about it.
    ///
    /// ⭐ THIS IS `BioPeek.egressible(from:)`'s SHAPE, deliberately, down to the
    /// signature (`ColabPayload.swift`). That is the #511/#186 lesson applied to the
    /// fourth egress surface: take the FRAME, not three loose Floats, so the rule is
    /// applied by the thing that PROJECTS, never by whoever remembers to ask. Three
    /// `Float`s carry no provenance, so `from(coherence:breathDepth:hrvNormalized:)`
    /// below had nothing to check — exactly the position `sendBio` was in before it
    /// stopped taking a `BioPeek`.
    ///
    /// ⛔ WHY IT WAS MISSING, stated plainly so it is not re-read as a shipped breach.
    /// `EngineBus.usableBio()` filters on FRESHNESS ONLY — it never looks at
    /// `frame.source` — so a `.healthKit`/`.watch`/`.oura` frame reached this mapping
    /// and left as CC74 / channel pressure / pitch bend over CoreMIDI, while the OSC,
    /// ADM-OSC, Art-Net, sACN and Multipeer paths all consulted the policy. MIDI was
    /// the one surface that did not. It sat behind THREE default-off switches (the
    /// `midi.out` route, `midi.out.mpe`, `midi.out.expression`) and carried
    /// `.derived`-class values, never `.clinical` — so: a missing privacy gate on an
    /// opt-in egress path, not a leak in anyone's shipped build.
    ///
    /// ⚠️ WHAT IS DELIBERATELY NOT GATED HERE, because over-gating ordinary music is
    /// its own defect: a note whose VELOCITY was musically shaped by the body is a
    /// creative result, not a measurement. It has passed through generation, scale
    /// quantisation, `noteExpression` and the lane gain; no reading is recoverable
    /// from it. The same holds for note selection. Only the three CONTINUOUS
    /// dimensions above are one map away from the sensor, and only they are refused.
    ///
    /// ⚠️ THE MIDI CLOCK IS A SEPARATE, UNRESOLVED QUESTION and is NOT decided by this
    /// function — see `MIDIOutput.setClockTempo`. Under `.flowFree` its BPM follows the
    /// pulse, and the OSC path withholds exactly that (`OSCSender.sendMusicIfFresh`,
    /// `bodyMayEgress`). Suppressing clock updates is not the same move as returning
    /// nil here: the pulse train keeps running, so a withheld tempo DESYNCS the
    /// receiver rather than silencing a value. Different failure story ⇒ different
    /// slice, founder-decided.
    ///
    /// - Returns: nil when this body's source may not leave the device, which the
    ///   caller already treats as "no body" — a plain note-on, unchanged behaviour.
    public static func egressible(from frame: BioSampleFrame) -> MPEExpression? {
        guard BioEgressPolicy.allowsEgress(frame.source) else { return nil }
        // Press should SWELL through the breath, not saw-reset at the cycle wrap:
        // shape the 0…1 phase into a smooth hump (0 at the cycle ends, 1 mid-breath).
        let breathSwell = Float(sin(Double(frame.breathPhase) * .pi))
        // Both fields neutral-for-sound: this type declares its own no-body state as
        // slide 64 / bend 0 (`.neutral`), and the raw 0s contradict it in opposite
        // directions. Coherence 0 sends CC74 0 (darkest timbre). And
        // `drift = (hrv·2−1)·(bendCents/100)/range` puts hrv 0 at the negative end of
        // the drift's own range — not a pinned −1 bend, but −0.0104 normalized, which
        // the receiver expands over ±48 semitones to exactly −50 cents. So every note
        // left a quarter-tone flat for the whole pre-measurement window.
        return from(coherence: frame.coherenceForSound,
                    breathDepth: breathSwell,
                    hrvNormalized: frame.hrvForSound)
    }

    /// Neutral 5D state: slide centred (CC74 = 64, the MPE initial-value
    /// convention), no pressure, no bend. The base a per-note override lands on
    /// when no body is present.
    public static let neutral = MPEExpression(slideCC74: 64, pressure: 0, bend: 0)

    /// #58 S6 — mix a note's fixed OVERRIDES over the live bio-derived expression.
    /// Per dimension: a SET override wins; an unset one falls through to `bio`
    /// (or to `.neutral` when there is no body). Both nil / transparent override
    /// ⇒ exactly today's behaviour (`bio` passes through, including nil — a
    /// transparent override never conjures an expression out of nothing).
    public static func merging(bio: MPEExpression?, override note: NoteMPE?) -> MPEExpression? {
        guard let note, !note.isTransparent else { return bio }
        let base = bio ?? .neutral
        return MPEExpression(
            slideCC74: note.slide.map { u7(clamp01($0)) } ?? base.slideCC74,
            pressure: note.pressure.map { u7(clamp01($0)) } ?? base.pressure,
            bend: note.bend ?? base.bend)
    }

    /// 14-bit pitch-bend bytes (lsb, msb) for a normalized −1…+1 value. Centre (0) →
    /// 8192 = (lsb 0, msb 64); −1 → 0; +1 → 16383.
    public static func pitchBend14(_ normalized: Float) -> (lsb: UInt8, msb: UInt8) {
        let clamped = Swift.max(-1, Swift.min(1, normalized))
        let value = Swift.max(0, Swift.min(16383, Int(((Double(clamped) + 1) * 0.5 * 16383).rounded())))
        return (UInt8(value & 0x7F), UInt8((value >> 7) & 0x7F))
    }

    /// MPE lower-zone MEMBER channel (1-based 2…16) for the n-th simultaneous note,
    /// round-robin so each voice's per-note bend/pressure/CC74 don't collide. The
    /// Master/Manager channel is 1. `memberCount` is the zone size (default 15 = full).
    public static func memberChannel(noteIndex: Int, memberCount: Int = 15) -> Int {
        let m = Swift.max(1, Swift.min(15, memberCount))
        return 2 + (Swift.max(0, noteIndex) % m)        // 2 … (1 + m)
    }

    // MARK: - MIDI 2.0 / UMP bridge (the high-res home for 5D expression)

    /// CC index for Slide / timbre (brightness), CC74 — the MPE convention.
    public static let slideCCIndex: UInt8 = 74

    /// The full MIDI 2.0 UMP word-pairs that express this 5D state for ONE sounding
    /// note on a single channel — no 15-channel MPE workaround needed because MIDI
    /// 2.0 carries per-note Glide + per-note Slide:
    ///   • Note On (opcode 0x9)            ← Strike (16-bit velocity)
    ///   • Per-note Pitch Bend (0x6)       ← Glide  (`bend`, centre = no drift)
    ///   • Per-note Controller (0x1, CC74) ← Slide  (`slideCC74`, brightness)
    ///   • Channel Pressure (0xD)          ← Press  (`pressure`)
    /// Pure: returns the words; the CoreMIDI ._2_0 transport just sends them.
    public func midi2NoteOnMessages(channel: UInt8, note: UInt8, strike: Float,
                                    group: UInt8 = 0) -> [(UInt32, UInt32)] {
        let vel16 = UInt16(Swift.max(0, Swift.min(65_535, (strike * 65_535).rounded())))
        // Reuse the tested 14-bit centre mapping, then widen to a 32-bit MIDI-2.0
        // bend so centre (no drift) lands exactly on 0x8000_0000.
        let pb = MPEExpression.pitchBend14(bend)
        let bend14 = (UInt16(pb.msb) << 7) | UInt16(pb.lsb)
        return [
            UMPEncoder.note2On(channel: channel, note: note, velocity16: vel16, group: group),
            UMPEncoder.perNotePitchBend2(channel: channel, note: note,
                                         value32: UMPEncoder.bend14to32(bend14), group: group),
            UMPEncoder.perNoteController2(channel: channel, note: note, index: MPEExpression.slideCCIndex,
                                          value32: UMPEncoder.cc7to32(slideCC74), group: group),
            UMPEncoder.channelPressure2(channel: channel,
                                        value32: UMPEncoder.cc7to32(pressure), group: group)
        ]
    }
}
