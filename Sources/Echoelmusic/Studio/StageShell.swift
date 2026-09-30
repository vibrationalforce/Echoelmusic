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
// ⚠️ TRANSITIONAL, on purpose (slice 2a): the Instrument stage still carries the old
// "Workstation" chip and panel, so the arrangement is reachable there too. Slice 2b retires that
// chip and folds `reopensWorkstation` into this stage key; until then
// `EchoelStudioView.workstationPanel` mounts NO second `WorkstationView` while the Piece stage
// is showing — one arrangement on screen, one in the tree.

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
    /// of the track rows. A named choice, not a number, so no `EchoelValueField`. Deliberately
    /// NOT the underline grammar of the area row inside the instrument: the two rows answer
    /// different questions ("which stage?" / "which job in the instrument?") and would read as
    /// one navigation if they looked alike.
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

/// The Piece stage: the workstation standing free, in its own scroll. Nothing is computed here —
/// everything the arrangement knows lives in `WorkstationView`, and its `.fileImporter` stays on
/// that leaf (#W1). The size contract is the one `SurfaceHost` states: fill, then clip.
@MainActor
struct ArrangeStage: View {
    var body: some View {
        ScrollView {
            WorkstationView()
                .padding(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(EchoelTheme.bg)
    }
}
#endif
