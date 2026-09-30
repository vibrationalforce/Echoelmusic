import Foundation

/// The two STAGES of the workspace — the layer ABOVE the instrument's area row (founder
/// 2026-09-30, interface-audit decisions 2 + 3, then „Du entscheidest alles … im Vordergrund
/// eine DMMW"): the **Piece** (the workstation — tracks, parts, scenes, import, the media
/// library) and the **Instrument** (the bio-generative front panel with its areas and chips).
///
/// WHY A LAYER ABOVE THE AREA ROW AND NOT A SIXTH AREA. `StudioArea` names the jobs INSIDE the
/// instrument and selects a plate of the chip strip; every area lives in `EchoelStudioView`'s
/// scroll, under its start row, as a dropdown panel. The piece is not a panel of the
/// instrument — the instrument is a device on one of the piece's tracks (decision 3). So the
/// piece stands BESIDE the instrument, not inside it, and it stands FIRST: a fresh install
/// opens on the piece (`StudioDefaultKeys.stage`).
///
/// Pure and Foundation-only so the blocking bundle can drive it
/// (`TheArrangeStageIsTheFrontStageTests`). The raw values are PERSISTED — rename a label,
/// never a case.
public enum StudioStage: String, CaseIterable, Identifiable, Sendable {
    case piece, instrument
    public var id: String { rawValue }

    /// The visible word. Glossary (decision 4): Stück · Spur · Teil · Szene — "Piece" is the
    /// glossary word for the whole, and it names the stage rather than an action ("Arrange"),
    /// because the transport already says "Play" and a cognitively loaded reader must never
    /// meet two "Play"s on one screen.
    public var label: String {
        switch self {
        case .piece:      return String(localized: "Piece")
        case .instrument: return String(localized: "Instrument")
        }
    }

    /// Spoken (#482: a door names what it reaches).
    public var spokenHint: String {
        switch self {
        case .piece:
            return String(localized: "Your piece: its tracks, parts and scenes, import and the media library.")
        case .instrument:
            return String(localized: "The instrument you play with your body: sound, effects, mix, mood and the visual field.")
        }
    }
}
