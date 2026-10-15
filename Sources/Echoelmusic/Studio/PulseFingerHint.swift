// PulseFingerHint.swift
// Echoel — Kandidat A (c), founder 2026-10-15 after the deep audit: the pulse needed knowledge that
// only a guide card held ("Lay a finger on the back camera" was written nowhere a player looks).
// The header pill shows a two-word label; this line says the WHOLE sentence on the instrument,
// directly under its first line, while the camera is reading and the pulse is not yet locked.
//
// ⭐ THE PRECEDENCE IS THE PILL'S (`PulseMonitorMiniLive` in `HeaderMonitors`), so the two can never
// give different advice: a stalled camera (iOS holds it, frames not flowing) says how to recover
// first — no finger can fix that (#1014); a denied camera says so unless another source (a strap)
// is already delivering; otherwise the placement cue.
// Locked says nothing: the hint retires only after a real measurement.
//
// ⚠️ ONE STEADY SENTENCE, NOT THE LIVE CUE. The placement cue changes with the analyzer (hold
// still · press gently · finding …); a full sentence that follows it would resize this slot at
// that rate. So a sentence appears only when it is LATCHED (`cueWarrantsFullHintOnScreen`: a
// stall, no light, too bright held 4 s — the pill's own rule, #569), and otherwise the one
// instruction that is always right while unlocked: where the finger goes (`.coverLens`).
//
// ⚠️ FREEZE LAW (10.76.41/50): this is a LEAF. It reads the ~10 Hz publisher in its OWN body;
// `EchoelStudioView.startControlRow` only constructs it, exactly like `AudioDegradedRow`.

#if canImport(SwiftUI)
import SwiftUI

struct PulseFingerHint: View {
    @Environment(CameraRPPGBioPublisher.self) private var cameraRPPG
    @Environment(EngineBus.self) private var bus

    /// The sentence to show, or nil for none. Pure, so the precedence is testable without a view.
    nonisolated static func sentence(cameraLive: Bool, framesFlowing: Bool, recoveryHint: String?,
                                     permissionDenied: Bool, otherSourceLive: Bool, cue: PulseCue,
                                     cueIsLatched: Bool) -> String? {
        if cameraLive, !framesFlowing, let recoveryHint { return recoveryHint }
        if permissionDenied, !otherSourceLive { return PulseCue.cameraDenied.fullHint }
        guard cameraLive, cue != .locked else { return nil }
        return cueIsLatched ? cue.fullHint : PulseCue.coverLens.fullHint
    }

    var body: some View {
        if let line = Self.sentence(cameraLive: cameraRPPG.isRunning,
                                    framesFlowing: cameraRPPG.framesFlowing,
                                    recoveryHint: cameraRPPG.recoveryState.userHint,
                                    permissionDenied: cameraRPPG.permissionDenied,
                                    otherSourceLive: bus.freshBio() != nil,
                                    cue: cameraRPPG.acquisitionCue,
                                    cueIsLatched: cameraRPPG.cueWarrantsFullHintOnScreen) {
            HStack(alignment: .firstTextBaseline, spacing: EchoelTheme.spaceS) {
                Image(systemName: "hand.point.up.left")
                    .accessibilityHidden(true)
                Text(line)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(EchoelTheme.font(12))
            .foregroundStyle(EchoelTheme.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }
}
#endif
