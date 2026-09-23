//
//  AudioTranspose.swift
//  Echoelmusic — Sequencer
//
//  Pitch (#165, founder 2026-09-23, "all tasks"): an AUDIO track's parts, up or down in whole
//  semitones, tempo unchanged. Decided here, applied by `AudioLanePlayer` + `TimelineAudioSink`,
//  written through `TimelineStore.setLaneTranspose` — the `AudioWarp` seam shape.
//
//  ⭐ PER TRACK, NOT PER PART. It reuses the persisted `TimelineLane.transposeSemitones` and its
//  one writer, so no schema changes; the Warp switch is per track for the same reason. A
//  per-part pitch would need a new persisted `TimelineRegion` field and is not built.
//
//  ⭐ THE NODE IS THE ONE THAT ALREADY EXISTS. `TimelineAudioSink` routes a warped part through
//  player → `AVAudioUnitTimePitch` → master. A transposed part now takes the same chain, with
//  the transpose added to the node's `pitch` (on top of the Tape trajectory, when a Tape plan
//  lets pitch ride). Untransposed, unwarped playback keeps the plain, uncolored node —
//  bit-identical to before.
//
//  ⚠️ `nodeCentsLimit` is the node's documented `pitch` range (−2400…+2400 cents), stated ONCE;
//  the semitone range is derived from it. The store's ±48 is the MIDI voice's clamp and is
//  left alone — the audio path clamps tighter, so a legacy value above ±24 plays at ±24.
//
//  ⚠️ CHANGES ONLY WHILE STOPPED. Turning pitch on for the first time needs the chain attached
//  at PRIME time; attaching mid-song pauses the whole engine (`AudioLanePlayer.prime`, review
//  HIGH 2). The Workstation disables the field while the song plays — the Warp switch's rule.
//
//  ⚠️ NOT PROMISED: sample-tight timing. The time-pitch node adds processing delay that the
//  plain node does not, and nothing compensates it — the situation a warped part is in today.
//  Whether the offset is audible is a device question (WorkstationView NEEDS-FOUNDER-VERIFY).
//
//  No undo step: lane fields sit outside the region undo history by design (TimelineStore).
//

import Foundation

public enum AudioTranspose {

    /// `AVAudioUnitTimePitch.pitch` accepts −2400…+2400 cents — the node's range, stated once.
    public static let nodeCentsLimit: Double = 2400

    /// Whole semitones the audio path plays: ±24, derived from the node (#416).
    public static var semitoneRange: ClosedRange<Int> {
        let limit = Int(nodeCentsLimit / 100)
        return -limit...limit
    }

    /// The same range as the field's value domain.
    public static var fieldRange: ClosedRange<Double> {
        Double(semitoneRange.lowerBound)...Double(semitoneRange.upperBound)
    }

    public static func clamped(_ semitones: Int) -> Int {
        Swift.min(Swift.max(semitones, semitoneRange.lowerBound), semitoneRange.upperBound)
    }

    /// A field value as whole semitones. `Int(_:)` traps on NaN/±inf, so a non-finite value
    /// is 0 and the Double is clamped BEFORE the conversion.
    public static func semitones(fromField value: Double) -> Int {
        guard value.isFinite else { return 0 }
        let bounded = Swift.min(Swift.max(value.rounded(), fieldRange.lowerBound), fieldRange.upperBound)
        return clamped(Int(bounded))
    }

    /// The pitch the ENGINE plays for this lane: audio, non-bio lanes only, clamped.
    public static func semitones(laneID: UUID, in document: TimelineDocument) -> Int {
        guard let lane = document.lanes.first(where: { $0.id == laneID }),
              lane.kind == .audio, !lane.isBio else { return 0 }
        return clamped(lane.transposeSemitones)
    }

    /// True when a part must play through the time-pitch chain instead of the plain node.
    public static func needsTimePitchChain(plan: StretchPlan, semitones: Int) -> Bool {
        plan.rate != 1.0 || clamped(semitones) != 0
    }

    /// The node's `pitch`: the Tape trajectory (only when the plan lets pitch ride) plus the
    /// transpose, clamped to the node's range.
    public static func nodePitchCents(plan: StretchPlan, semitones: Int) -> Float {
        let tape = plan.preservesPitch ? 0 : StretchPlan.tapePitchCents(forRate: plan.rate)
        let total = tape + Double(clamped(semitones)) * 100
        guard total.isFinite else { return 0 }
        return Float(Swift.min(Swift.max(total, -nodeCentsLimit), nodeCentsLimit))
    }

    /// The field calls this and nothing else; the write is the store's.
    @MainActor
    public static func setPitch(_ semitones: Int, laneID: UUID, timeline: TimelineStore) {
        guard let lane = timeline.document.lanes.first(where: { $0.id == laneID }),
              lane.kind == .audio, !lane.isBio else { return }
        let next = clamped(semitones)
        guard lane.transposeSemitones != next else { return }   // no persist on a no-op
        timeline.setLaneTranspose(id: laneID, next)
    }
}
