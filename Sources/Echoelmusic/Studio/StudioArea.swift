import Foundation

/// DMMW Phase 1 (founder 2026-09-29): the five top-level AREAS of the instrument — the main
/// navigation one level above the chip strip.
///
/// WHY A LAYER ABOVE THE CHIPS AND NOT A REPLACEMENT. The strip holds nine chips in signal
/// order and overflows a phone (#291/#607); as a flat list it answers "which panel?" but not
/// "where am I in the work?". An area names the job — compose, perform, look, find, set up —
/// and selects that job's home plate. Nothing is hidden: every chip stays in the strip, in
/// its order (#572 — the founder rejected a strip with chips taken away; the lever is
/// emphasis, not absence), and the strip keeps being the precise selector.
///
/// Membership (which plate belongs to which area) lives on `StudioMenu` itself as an
/// EXHAUSTIVE switch in `EchoelStudioView`, so a new plate cannot compile without choosing
/// an area. This type stays pure so the blocking bundle can drive it.
///
/// ⚠️ NO NEW MODAL. Four areas select a plate (the chip idiom, zero presentation
/// modifiers). `library` opens the project library through the EXISTING `showOpen` slot —
/// the same flag the "open" chrome door and the Open tile set (black-screen law).
enum StudioArea: String, CaseIterable, Identifiable, Sendable {
    case compose, perform, visuals, library, settings

    var id: String { rawValue }

    /// The visible label — the founder's own words for the five areas.
    var label: String {
        switch self {
        case .compose:  return "Compose"
        case .perform:  return "Perform"
        case .visuals:  return "Visuals"
        case .library:  return "Library"
        case .settings: return "Settings"
        }
    }

    /// What the button does, spoken. Names the plate it opens, because the plate's chip is
    /// what lights up underneath — a VoiceOver user must be able to connect the two (#482:
    /// the spoken name of a door lists what it actually reaches).
    var spokenHint: String {
        switch self {
        case .compose:  return "Tempo, variations and mood. Opens the Tempo panel. The arrangement is the Piece stage."
        case .perform:  return "The piece's scenes, sound, effects, mix, master and body input. Opens the Sound panel."
        case .visuals:  return "The visual field you play with your fingers. Opens the Field panel."
        case .library:  return "Your saved pieces. Opens the piece list."
        case .settings: return "Loop length, place in the name, default sound and diagnostics. Opens the Save and Export panel."
        }
    }

    /// `true` when choosing the area selects a plate on the front panel (and can therefore
    /// show as selected); `false` for the one area that opens a sheet instead.
    var selectsPlate: Bool { self != .library }
}
