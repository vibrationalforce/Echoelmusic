import Foundation

/// The two STAGES of the workspace — the layer ABOVE the instrument's chip strip (founder
/// 2026-09-30, interface-audit decisions 2 + 3, then „Du entscheidest alles … im Vordergrund
/// eine DMMW"): the **Piece** (the workstation — tracks, parts, scenes, import, the media
/// library) and the **Instrument** (the bio-generative front panel with its chips).
///
/// WHY A STAGE AND NOT A PLATE OF THE INSTRUMENT. A chip selects a plate inside the
/// instrument; every plate lives in `EchoelStudioView`'s scroll, under its start row, as a
/// dropdown panel. The piece is not a panel of the instrument — the instrument is a device on
/// one of the piece's tracks (decision 3). So the piece stands BESIDE the instrument, not
/// inside it, and it stands FIRST: a fresh install opens on the piece
/// (`StudioDefaultKeys.stage`). (An area row sat between the two from 2026-09-29 to
/// 2026-10-01; it is gone — four of its five buttons were second doors to chips.)
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

    /// A3b (workstation redesign, founder 2026-10-01) — whether the HEAD (`ProjectHeader`) carries
    /// the transport, Play / Stop and Record, on this stage. Not on the Piece stage: there the bar
    /// pinned under the arrangement carries the same Play / Stop (`ProjectPlayStopButton`), and
    /// `StageShell` mounts the arrangement on the Piece stage ONLY — so on every stage exactly one
    /// of the two is on screen. Pure, so the blocking bundle drives it
    /// (`ThePieceStageHasOnePlayTests`).
    public var headCarriesTransport: Bool { self != .piece }

    /// DAW shell S7a (founder 2026-10-02, „Ja, so bauen" — one control bar on top): whether the
    /// ONE Play starts the INSTRUMENT on this stage. On the Instrument stage the instrument is what
    /// is in front, so the head's Play plays it — the plate's own ▶ went with S7a, because two
    /// Plays on one screen is the confusion the founder named three times
    /// (`OneStartControlTests`). On the Piece stage the Play plays the piece. A separate name from
    /// `headCarriesTransport`, though equal today: WHERE the transport sits and WHAT its Play
    /// starts are two decisions, and a third stage would have to answer both.
    public var playStartsTheInstrument: Bool { self == .instrument }

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

/// What the PIECE stage shows (DAW shell S2, founder 2026-10-02, inbox E18 „Ja, so bauen"): the
/// arrangement, the mixer, the browser (the sounds, the media library and the photo/video seeds) or the
/// project (the song's settings, its light look, export — Save and Open are the ≡ menu's since S3). One persisted choice, written only by the bottom switcher
/// (`StageShell.shellSwitcher`), read by `WorkspaceView`'s piece plate (`WorkstationView`).
///
/// ⭐ WHY A SECOND KEY AND NOT MORE CASES ON `StudioStage`. The stage decides what is MOUNTED on
/// top — the instrument is always in the tree, the piece stands over it or does not. Four of the
/// five switcher entries show the same mounted thing (the piece) with a different plate; folding
/// them into `StudioStage` would make every stage reader (`showStage`, Safe Mode, the head's
/// transport rule) learn four names for "the piece". So the stage keeps its two cases and this
/// enum says which plate the piece shows; `ShellTab` is the pure projection of the pair.
///
/// Raw values are PERSISTED — rename a label, never a case.
public enum PieceView: String, CaseIterable, Identifiable, Sendable {
    case arrange, mixer, browse, project
    public var id: String { rawValue }
}

/// The five entries of the bottom switcher (DAW shell S2): Arrange · Mixer · Instrument ·
/// Browse · Piece — the order the founder approved (E18; the fifth word since H18). A pure projection of the two
/// persisted keys: `stage` + `pieceView` say what a tap writes, `current(stage:piece:)` says
/// which entry is lit. There is no third stored truth, so the switcher can never disagree with
/// what is on screen.
///
/// ⭐ EVERY ENTRY AT EVERY LEVEL (E19 „Nur im Detail"): no entry hides behind `SkillLevel`. A
/// view that disappears with the level is a door nobody finds; the level thins FIELDS inside a
/// view, never the views.
public enum ShellTab: String, CaseIterable, Identifiable, Sendable {
    case arrange, mixer, instrument, browse, project
    public var id: String { rawValue }

    /// The stage a tap on this entry shows.
    public var stage: StudioStage { self == .instrument ? .instrument : .piece }

    /// The plate a tap on this entry shows on the piece, or nil for the instrument — which
    /// leaves the piece's last plate untouched, so returning to the piece returns to it.
    public var pieceView: PieceView? {
        switch self {
        case .arrange:    return .arrange
        case .mixer:      return .mixer
        case .instrument: return nil
        case .browse:     return .browse
        case .project:    return .project
        }
    }

    /// The lit entry for the two persisted keys — the inverse of `stage` + `pieceView`.
    public static func current(stage: StudioStage, piece: PieceView) -> ShellTab {
        guard stage == .piece else { return .instrument }
        switch piece {
        case .arrange: return .arrange
        case .mixer:   return .mixer
        case .browse:  return .browse
        case .project: return .project
        }
    }

    /// The visible word — one word each, the DAW vocabulary (Ableton, FL Studio Mobile).
    public var label: String {
        switch self {
        case .arrange:    return String(localized: "Arrange")
        case .mixer:      return String(localized: "Mixer")
        case .instrument: return String(localized: "Instrument")
        case .browse:     return String(localized: "Browse")
        case .project:    return String(localized: "Piece")
        }
    }

    /// Spoken (#482: a door names what it reaches).
    public var spokenHint: String {
        switch self {
        case .arrange:
            return String(localized: "Your piece: its tracks, parts and scenes.")
        case .mixer:
            return String(localized: "Every sounding track's level, pan, mute and solo.")
        case .instrument:
            return StudioStage.instrument.spokenHint
        case .browse:
            return String(localized: "The sounds, the media library and the photo and video that shape the visual.")
        case .project:
            // GMMW P1-4: what the plate holds. Save and Open left it with S3 — they are the ≡ menu's.
            return String(localized: "The piece's key, scale, tuning, note names and tempo mode, its light look, and its export as MIDI or audio.")
        }
    }
}

/// GMMW P1-2 — the Browse plate's three shelves (founder 2026-10-08: „vermeide
/// Unübersichtlichkeit", „Orientiere dich an den Bigplayern"). Every DAW browser asks for the
/// category first and then lists it; the plate stacked the sounds, the media library and the two
/// cards that shape the visual in one scroll. One shelf at a time, behind a segmented row; the
/// words are the cards' own headings ("Sounds", "Media Library", "… to Visuals").
/// View state, not persisted: the plate opens on the sounds.
enum BrowseShelf: String, CaseIterable, Identifiable, Sendable {
    case sounds, media, visuals

    /// The shelf the plate shows first.
    static let opening = BrowseShelf.sounds

    var id: String { rawValue }

    /// The segment's word.
    var title: String {
        switch self {
        case .sounds: return String(localized: "Sounds")
        case .media: return String(localized: "Media")
        case .visuals: return String(localized: "Visuals")
        }
    }
}
