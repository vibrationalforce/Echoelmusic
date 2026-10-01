#if canImport(SwiftUI)
import SwiftUI

// StageShell.swift
// Echoel — the seam between the two STAGES of the workspace (founder 2026-09-30, decisions 2 + 3
// of the interface audit; then „Du entscheidest alles … im Vordergrund eine DMMW"):
//
//   Piece       → `ArrangeStage`: `WorkstationView` standing free — tracks, parts, scenes,
//                 import, the media library. The DEFAULT stage: a fresh install opens here.
//   Instrument  → `EchoelStudioView`: the bio-generative front panel with its start row, area
//                 row and chip strip, exactly as before.
//
// ⛔ THE INSTRUMENT IS HIDDEN, NEVER UNMOUNTED. The audit doc planned this seam as "a sibling
// switch inside SurfaceHost"; measured against the code, that would kill the music:
// `EchoelStudioView` carries `.onDisappear { stopEverything(reason: "unmount") … }`, and it
// hosts the Save alert and the Open sheet that `WorkstationProjectRow` opens through the chrome
// door. An `if/else` would end the pulse session and the take on every switch to the piece, and
// take the project doors with it. So the studio is ALWAYS in the tree: on the Piece stage it is
// transparent, hit-testing off and hidden from VoiceOver, while `ArrangeStage` is mounted on top
// of it. Its identity — and every live bio / camera / transport session under it — is stable
// across the switch (the H7 invariant `SurfaceHost` used to state for itself).
//
// ⭐ FREEZE LAW: this file reads ONE `@AppStorage` (the stage, written on a tap) and nothing
// else — no bio, meter, playhead or engine. Both types here are ANCESTORS of Picker hosts, so a
// hot read would rebuild the whole instrument ten times a second (10.76.50); the ancestor scan
// in `TheMenuHostReadsNoHotStateTests` covers both.
//
// ⭐ BLACK-SCREEN LAW: no presentation modifier lives here — no `.sheet`, `.alert`,
// `.fullScreenCover`, `.fileImporter`. The studio's chain stays where it is (11 on its body).
// The Workstation's own `.fileImporter` stays on ITS leaf; this file is on that leaf's ancestor
// path (`TheWorkstationImportsAudioTests`, #W1) and must never carry one.
//
// ⭐ WHO ELSE WRITES THE STAGE (slice 2b): the studio, in `showStage(_:)`, on two user actions —
// a plate door posted from the piece ("sound", "bio") turns the Instrument stage, because a plate
// opened in a hidden studio is a button that does nothing; "New piece" turns the Piece stage. And
// Safe Mode, at the instrument, after a crash. `reopensWorkstation` is gone: this key IS the
// relaunch memory, and the instrument's untouched plate is Sound.
//
// ⚠️ TRANSITIONAL, on purpose (slice 2b-i): the Instrument stage still carries a "Workstation"
// CHIP, whose plate is now only a door to this stage — never a second `WorkstationView`. The chip
// stays because `.deploy/release` sends the founder along "Workstation-Chip" and is founder-gated
// (`TheDeployNoteNamesRealDoorsTests` claim 2 reads the whole note); slice 2b-ii retires it
// together with that note.

/// The seam. Mounted by `SurfaceHost` as the whole surface.
@MainActor
struct StageShell: View {
    @AppStorage(StudioDefaultKeys.stage.key)
    private var stageRaw = StudioDefaultKeys.stage.value.rawValue

    private var stage: StudioStage {
        StudioStage(rawValue: stageRaw) ?? StudioDefaultKeys.stage.value
    }

    var body: some View {
        VStack(spacing: 0) {
            stageSeam
            Divider().overlay(EchoelTheme.border)
            ZStack {
                // ALWAYS mounted — see the header. Hidden three ways on the Piece stage:
                // invisible, untouchable, unspoken.
                EchoelStudioView()
                    .opacity(stage == .instrument ? 1 : 0)
                    .allowsHitTesting(stage == .instrument)
                    .accessibilityHidden(stage != .instrument)
                if stage == .piece {
                    ArrangeStage()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Two words sharing one row, 44 pt tall, the chosen one filled — the `M`/`S` switch grammar
    /// of the track rows. A named choice, not a number, so no `EchoelValueField`.
    private var stageSeam: some View {
        HStack(spacing: 6) {
            ForEach(StudioStage.allCases) { candidate in
                stageButton(candidate)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(EchoelTheme.bg)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Stage")
    }

    private func stageButton(_ candidate: StudioStage) -> some View {
        let isActive = candidate == stage
        return Button {
            stageRaw = candidate.rawValue
        } label: {
            Text(candidate.label)
                .font(EchoelTheme.font(13, .semibold))
                .foregroundStyle(isActive ? EchoelTheme.onPrimary : EchoelTheme.text)
                .frame(maxWidth: .infinity, minHeight: EchoelTheme.controlTapHeight)
                .background(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                    .fill(isActive ? EchoelTheme.text : EchoelTheme.fill))
                .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                    .strokeBorder(isActive ? Color.clear : EchoelTheme.border, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(candidate.label)
        .accessibilityHint(candidate.spokenHint)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

/// The Piece stage: the workstation standing free. Nothing is computed here — everything the
/// arrangement knows lives in `WorkstationView`, and its `.fileImporter` stays on that leaf (#W1).
/// The size contract is the one `SurfaceHost` states: fill, then clip.
///
/// A3 (Workstation redesign, founder 2026-10-01): the SCROLL lives inside `WorkstationView` now,
/// so its transport can stay pinned under the plate while the song scrolls. This stage only
/// stacks the tuning status above it.
///
/// Above the arrangement sits `PieceTuningStatus` (slice 2c): the tuning warning the instrument's
/// Sound plate shows, on the stage a fresh install actually opens — the piece's transport plays
/// the same retuned voices. A leaf, a sibling of the arrangement, hidden entirely at 12-TET + 440.
@MainActor
struct ArrangeStage: View {
    var body: some View {
        VStack(spacing: 8) {
            PieceTuningStatus()
            WorkstationView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(EchoelTheme.bg)
    }
}
#endif
