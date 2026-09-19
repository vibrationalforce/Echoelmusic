// StretchMode.swift
// Echoelmusic — Sequencer
//
// The selectable algorithm/character for the Echoel stretch engine. ONE enum chosen
// per clip (and, over time, per sampler voice / loop / video-sound) — the single facade
// every time-stretch consumer routes through, so quality/character choice is uniform
// app-wide. Each case names a FREE, App-Store-clean executor; the paid/copyleft engines
// surveyed in the #54 deep-research (every zplane élastique tier, Rubber Band GPL,
// SoundTouch LGPL) are excluded by the zero-paid-dependency rule and are NOT cases here.
//
// Pure value type — no AVFoundation. The executor that actually renders each mode lives
// on the audio graph (an AVAudioUnit node); this enum only declares intent.

import Foundation

public enum StretchMode: String, CaseIterable, Codable, Sendable {
    /// Apple spectral phase-vocoder (`AVAudioUnitTimePitch`): tempo conforms, PITCH
    /// PRESERVED. The clean, transparent-ish default. LIVE (wired since #54 Slice A).
    case clean
    /// Tape/turntable character: tempo AND pitch move together. WIRED — rendered on the
    /// same `AVAudioUnitTimePitch` node by compensating pitch to ride the tempo
    /// (`pitch = 1200·log₂(rate)`, see `StretchPlan.tapePitchCents`), so zero graph change.
    /// (An authentic-resampling `AVAudioUnitVarispeed` variant with tape grit is a later
    /// refinement; this delivers the defining pitch-follows-tempo behaviour now.)
    case tape
    /// In-house WSOLA transient-preserving (Ableton "Beats"-style): best on
    /// drums/loops, patent-free own code (`EchoelWSOLA`). Executors: OFFLINE
    /// pre-render in the editor preview (AudioClipPlayer) AND on the timeline
    /// (TimelineAudioSink, prime-time per-region render; grid-aligned region
    /// starts — an off-grid/stepless placement enters as "mid-region" and plays
    /// the honest Clean chain). Per-consumer `capabilities` on
    /// `StretchPlan.resolve` stay the truth mechanism.
    /// ⛔ #1230 RETRACTED THE WHOLE "Executors: … (AudioClipPlayer) AND … (TimelineAudioSink …)"
    /// SENTENCE ABOVE, AND ONLY HALF OF IT WAS FALSE. Its evidence was
    /// `git grep -n "EchoelWSOLA(" -- Sources` → 0 — but `EchoelWSOLA` is this file's
    /// FILENAME, never a declared type. The type is `WSOLAStretcher`, so that needle returns
    /// 0 for EVERY possible state of the repo, forever (`.claude/rules/context.md` §2: a
    /// parser that matches nothing is a finding, never a pass). Re-measured #1376:
    ///
    ///     $ git grep -n "WSOLAStretcher(" -- Sources
    ///     Sequencer/AudioClipPlayer.swift:118   ← dead file: zero callers, zero tests
    ///     Sequencer/AudioClipPlayer.swift:180   ← dead
    ///     Sequencer/TimelineAudioSink.swift:184 ← LIVE
    ///
    /// · `AudioClipPlayer` half: the retraction was RIGHT. The editor preview went with the
    ///   piano roll (#475) and nothing constructs that player any more.
    /// · `TimelineAudioSink` half: the retraction was WRONG. `AudioLanePlayer:308` resolves a
    ///   region with `capabilities: .timelineCapabilities`, and on `plan.mode == .beats,
    ///   plan.rate != 1.0` calls `sink.prepareBeats(…)`, which renders through
    ///   `WSOLAStretcher().stretchMultichannel(…)` in a prime-time `Task.detached`. Every
    ///   link is production code; `TimelineAudioSink` itself is injected at
    ///   `EchoelmusicApp.swift:1127`.
    ///
    /// So this is the #527 shape — the CHAIN runs, the DATA has no producer (nothing creates
    /// an audio-bearing `TimelineRegion` today) — not an unwired core. `isImplemented` below
    /// stays `true` ON PURPOSE for exactly that reason: regions persist `stretchMode`, so a
    /// flip is a document question, not a tidy-up. A beats-stretch FEATURE still needs a
    /// producer for audio regions; the stretcher itself is already reachable.
    ///
    /// ⭐ LAW: when a claim has TWO carriers, measure them SEPARATELY. A needle spelled with a
    /// name neither carrier bears returns the same nothing for both, and the retraction is
    /// then as coarse as its instrument. Full derivation: `memory/LEDGER_COUNTS.md` §AA.
    case beats
    /// Signalsmith Stretch (MIT C++): highest transient fidelity — FOUNDER-GATED
    /// dependency (first C++ in the tree, contained bridge). Executor: approved slice only.
    case studio

    /// Human label for the picker.
    public var displayName: String {
        switch self {
        case .clean:  return "Clean"
        case .tape:   return "Tape"
        case .beats:  return "Beats"
        case .studio: return "Studio"
        }
    }

    /// One-line character description (UI subtitle / tap-to-learn).
    public var characterHint: String {
        switch self {
        case .clean:  return "Pitch preserved — transparent (Apple spectral)."
        case .tape:   return "Pitch follows tempo — tape/turntable feel."
        case .beats:  return "Transient-locked — best on drums & loops."
        case .studio: return "Highest-fidelity transient stretch (Signalsmith)."
        }
    }

    /// Whether pitch is held constant when the tempo is stretched. Only `.tape` lets
    /// pitch move with tempo; the rest are pitch-preserving. NOTE: this is the RAW mode's
    /// property — for what actually renders, read it off `effectiveMode` or (preferably)
    /// take `StretchPlan.resolve(...).preservesPitch`, which already applies the `.clean`
    /// fallback for modes the CALLING CONSUMER can't execute. Configuring an executor
    /// off the raw value would mis-set pitch for a mode that consumer doesn't render.
    public var preservesPitch: Bool { self != .tape }

    /// Executors wired in AT LEAST ONE consumer today. UI MUST offer only these
    /// (a mode no consumer executes would be a lying selector). Which consumer
    /// actually renders a mode is decided per call via `StretchPlan.resolve`'s
    /// `capabilities` — a consumer that can't execute a mode gets the honest
    /// `.clean` fallback, never silence, never a broken control.
    public var isImplemented: Bool {
        switch self {
        case .clean, .tape: return true      // tape = pitch-follows-tempo on the spectral node
        case .beats:        return true      // ⚠️ #1376: WSOLAStretcher IS constructed (TimelineAudioSink:184); the DATA has no producer — see the case doc
        case .studio:       return false     // Signalsmith — founder-gated dependency slice
        }
    }

    /// The BASE capability set — what every realtime consumer (timeline lanes,
    /// audition sink) executes on the always-in-chain spectral node.
    public static let baseCapabilities: Set<StretchMode> = [.clean, .tape]
    /// The editor-preview consumer's set: it can additionally pre-render Beats
    /// offline (`AudioClipPlayer` — no realtime constraint on the audition path).
    /// ⚠️ #1376: `AudioClipPlayer` has ZERO callers and zero tests, so this set has no live
    /// consumer today. Kept, not deleted: it is the shape a re-doored preview would take,
    /// and `previewCapabilities` names the only other place `.beats` was ever meant to run.
    public static let previewCapabilities: Set<StretchMode> = [.clean, .tape, .beats]
    /// The TIMELINE executor's set (Beats-Executor slice): `TimelineAudioSink`
    /// pre-renders Beats regions offline at PRIME time (transport parked) and
    /// schedules the buffer at rate 1 on the plain node; a region whose buffer
    /// is not ready (prepared window mismatch, memory cap, mid-song live edit)
    /// falls back to the Clean warp chain at play time — honest, never silent.
    public static let timelineCapabilities: Set<StretchMode> = [.clean, .tape, .beats]

    /// The mode the BASE (realtime) path renders: itself when base-capable, else
    /// the `.clean` baseline. Kept for callers without a capability context;
    /// prefer `StretchPlan.resolve(..., capabilities:)`.
    public var effectiveMode: StretchMode { StretchMode.baseCapabilities.contains(self) ? self : .clean }

    /// The subset a picker should show today (implemented in ≥1 consumer).
    public static var selectable: [StretchMode] { allCases.filter(\.isImplemented) }
}
