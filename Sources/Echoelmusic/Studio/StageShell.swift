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
// Instrument · Browse · Piece. Four of them show the piece with a different plate
// (`PieceView`, its own persisted key) and one the instrument; `ShellTab` projects the two keys,
// so nothing here stores a third truth. Everything below about the stage still holds.
//
// ⭐ ONE DOOR (slice F, founder 2026-10-01 „Vermeide das es mehrfache Wege zu einem Bereich
// gibt"): the switcher is the only control that takes the player to the Piece stage. The
// Instrument's Workstation chip — since 2b-i a plate that only pointed here — is retired, and
// `TheWorkstationHasADoorTests` claims A and B hold both halves. "New piece" still lands here as
// the end of a flow it started, not as a door.
//
// ⭐ DAW SHELL S8a (2026-10-02, E18 plan row „Querformat"): IN LANDSCAPE THE SWITCHER IS A RAIL.
// On an iPhone held sideways the screen is ~400 pt tall, and the header, the plate's own bars and
// a bottom switcher left the arrangement about a quarter of it. So when the vertical size class is
// compact (the same test the Workstation's side-by-side detail uses), the same five buttons stand
// in a column on the LEADING edge — leading because the visual card docks bottom-TRAILING — and
// the stage gets the full height. `ShellLayout` does the placing; the body keeps one shape, the
// stage first and the switcher second, so nothing branches above the stage. Portrait is unchanged.
// The size class is an environment value that changes on rotation, never a hot state.

/// The shell under the control bar: the stage area, and the switcher at the bottom. Mounted by
/// `SurfaceHost` as the whole surface.
@MainActor
struct StageShell: View {
    @AppStorage(StudioDefaultKeys.stage.key)
    private var stageRaw = StudioDefaultKeys.stage.value.rawValue
    /// DAW shell S2 — the plate the piece shows. Cold: a tap on the switcher writes it.
    @AppStorage(StudioDefaultKeys.pieceView.key)
    private var pieceRaw = StudioDefaultKeys.pieceView.value.rawValue
    /// S8a: compact height = a phone held sideways. Changes on rotation only.
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// S8a: the switcher stands as a rail on the leading edge when the height is scarce.
    private var railMode: Bool { verticalSizeClass == .compact }

    private var stage: StudioStage {
        StudioStage(rawValue: stageRaw) ?? StudioDefaultKeys.stage.value
    }

    private var pieceView: PieceView {
        PieceView(rawValue: pieceRaw) ?? StudioDefaultKeys.pieceView.value
    }

    var body: some View {
        ShellLayout(rail: railMode) {
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
    /// Instrument · Browse · Piece, every entry at every level (E19). Each entry is an icon AND
    /// its word, at least the 44-pt tap height by NAME (`EchoelTheme.controlTapHeight`), the
    /// current one in the accent colour and `.isSelected` to VoiceOver — never colour alone. A named choice, not a number, so no
    /// `EchoelValueField`. Solid surface with a 1-px top border (Uncodixfy: no blur, no glass).
    /// It replaces the „Piece | Instrument" seam that stood ABOVE the stage, and the Arrange and
    /// Mix tiles of the piece's tab row: one door per area, all in one place.
    ///
    /// S8a: in landscape the same buttons stand in a column (`railMode`), the border moves to the
    /// rail's trailing side and the surface runs under the leading safe area instead of the bottom
    /// one. The rail's own text cap is tighter, so five entries keep fitting the ~270 pt a phone
    /// leaves under its header when held sideways.
    private var shellSwitcher: some View {
        let current = ShellTab.current(stage: stage, piece: pieceView)
        let rail = railMode
        let entries = rail ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 0))
        return entries {
            ForEach(ShellTab.allCases) { tab in
                switcherButton(tab, isActive: tab == current)
            }
        }
        // The rail is a COLUMN, not a stack of five: it fills the height the layout proposes, so
        // its surface and its trailing border run to the bottom edge (review of S8a, MED). In
        // portrait `nil` leaves the bar at its natural height.
        .frame(maxHeight: rail ? .infinity : nil, alignment: .top)
        .padding(.horizontal, 4)
        .padding(.top, 2)
        .background(EchoelTheme.surface.ignoresSafeArea(edges: rail ? .leading : .bottom))
        .overlay(alignment: rail ? .trailing : .top) {
            if rail {
                Rectangle().fill(EchoelTheme.border).frame(width: 1)
            } else {
                Rectangle().fill(EchoelTheme.border).frame(height: 1)
            }
        }
        // The rail's own cap: five entries must fit the ~270 pt a sideways phone leaves.
        .dynamicTypeSize(...(rail ? DynamicTypeSize.xxxLarge : DynamicTypeSize.accessibility5))
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

/// DAW shell S8a — the shell's two children placed by orientation: the stage fills, the switcher
/// takes its own size. Portrait: the switcher at the bottom, its natural height (what the old
/// `VStack` did). Landscape (`rail`): the switcher at the LEADING edge, its natural width clamped
/// to 56…96 pt, the stage beside it at full height. Anything but exactly two children is stacked
/// over the whole bounds rather than dropped.
private struct ShellLayout: Layout {
    var rail: Bool

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews,
                       cache: inout ()) {
        guard subviews.count == 2 else {
            for child in subviews {
                child.place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(bounds.size))
            }
            return
        }
        let stage = subviews[0]
        let switcher = subviews[1]
        if rail {
            let ideal = switcher.sizeThatFits(ProposedViewSize(width: nil, height: bounds.height)).width
            let width = min(min(max(ideal, 56), 96), bounds.width)
            switcher.place(at: bounds.origin, anchor: .topLeading,
                           proposal: ProposedViewSize(width: width, height: bounds.height))
            stage.place(at: CGPoint(x: bounds.minX + width, y: bounds.minY), anchor: .topLeading,
                        proposal: ProposedViewSize(width: bounds.width - width, height: bounds.height))
        } else {
            let ideal = switcher.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil)).height
            let height = min(max(ideal, 0), bounds.height)
            stage.place(at: bounds.origin, anchor: .topLeading,
                        proposal: ProposedViewSize(width: bounds.width, height: bounds.height - height))
            switcher.place(at: CGPoint(x: bounds.minX, y: bounds.maxY - height), anchor: .topLeading,
                           proposal: ProposedViewSize(width: bounds.width, height: height))
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
