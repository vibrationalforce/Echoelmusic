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
// ⭐ FREEZE LAW: this file reads TWO `@AppStorage` keys (the stage and, since S2, the piece's
// plate — both written on a tap) and nothing else — no bio, meter, playhead or engine. Both types here are ANCESTORS of Picker hosts, so a
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
// ⭐ DAW SHELL S2 (founder 2026-10-02, inbox E18 „Ja, so bauen"): the seam ABOVE the stage is
// gone; the switcher at the BOTTOM (`shellSwitcher`) holds five entries — Arrange · Mixer ·
// Instrument · Browse · Project. Four of them show the piece with a different plate
// (`PieceView`, its own persisted key) and one the instrument; `ShellTab` projects the two keys,
// so nothing here stores a third truth. Everything below about the stage still holds.
//
// ⭐ ONE DOOR (slice F, founder 2026-10-01 „Vermeide das es mehrfache Wege zu einem Bereich
// gibt"): the switcher is the only control that takes the player to the Piece stage. The
// Instrument's Workstation chip — since 2b-i a plate that only pointed here — is retired, and
// `TheWorkstationHasADoorTests` claims A and B hold both halves. "New piece" still lands here as
// the end of a flow it started, not as a door.

/// The shell under the control bar: the stage area, and the switcher at the bottom. Mounted by
/// `SurfaceHost` as the whole surface.
@MainActor
struct StageShell: View {
    @AppStorage(StudioDefaultKeys.stage.key)
    private var stageRaw = StudioDefaultKeys.stage.value.rawValue
    /// DAW shell S2 — the plate the piece shows. Cold: a tap on the switcher writes it.
    @AppStorage(StudioDefaultKeys.pieceView.key)
    private var pieceRaw = StudioDefaultKeys.pieceView.value.rawValue

    private var stage: StudioStage {
        StudioStage(rawValue: stageRaw) ?? StudioDefaultKeys.stage.value
    }

    private var pieceView: PieceView {
        PieceView(rawValue: pieceRaw) ?? StudioDefaultKeys.pieceView.value
    }

    var body: some View {
        VStack(spacing: 0) {
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
            shellSwitcher
        }
    }

    /// DAW shell S2 (founder 2026-10-02, inbox E18): the bottom switcher — Arrange · Mixer ·
    /// Instrument · Browse · Project, every entry at every level (E19). Each entry is an icon AND
    /// its word, at least the 44-pt tap height by NAME (`EchoelTheme.controlTapHeight`), the
    /// current one in the accent colour and `.isSelected` to VoiceOver — never colour alone. A named choice, not a number, so no
    /// `EchoelValueField`. Solid surface with a 1-px top border (Uncodixfy: no blur, no glass).
    /// It replaces the „Piece | Instrument" seam that stood ABOVE the stage, and the Arrange and
    /// Mix tiles of the piece's tab row: one door per area, all in one place.
    private var shellSwitcher: some View {
        let current = ShellTab.current(stage: stage, piece: pieceView)
        return HStack(spacing: 0) {
            ForEach(ShellTab.allCases) { tab in
                switcherButton(tab, isActive: tab == current)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
        .background(EchoelTheme.surface.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle().fill(EchoelTheme.border).frame(height: 1)
        }
        // The chrome's Dynamic Type cap (the head's own): past it five words cannot share a row.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Views")
    }

    private func switcherButton(_ tab: ShellTab, isActive: Bool) -> some View {
        Button {
            select(tab)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: Self.symbol(for: tab))
                    .font(EchoelTheme.font(18, .regular))
                Text(tab.label)
                    .font(EchoelTheme.font(11, .semibold))
                    .lineLimit(1)
                    .allowsTightening(true)
            }
            .foregroundStyle(isActive ? EchoelTheme.accent : EchoelTheme.dim)
            .frame(maxWidth: .infinity, minHeight: EchoelTheme.controlTapHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.label)
        .accessibilityHint(tab.spokenHint)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    /// One tap writes the two persisted keys `ShellTab` projects — the plate first, so the piece
    /// never draws one frame of its previous plate when the stage turns to it.
    private func select(_ tab: ShellTab) {
        if let piece = tab.pieceView { pieceRaw = piece.rawValue }
        stageRaw = tab.stage.rawValue
    }

    /// SF Symbols for the switcher — here, not on `ShellTab`, because that enum's file returns
    /// only catalogued words (`TheChromeSpeaksOneLanguageTests` claim 3).
    private static func symbol(for tab: ShellTab) -> String {
        switch tab {
        case .arrange:    return "rectangle.split.3x1"
        case .mixer:      return "slider.vertical.3"
        case .instrument: return "waveform.path"
        case .browse:     return "folder"
        case .project:    return "doc.text"
        }
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
